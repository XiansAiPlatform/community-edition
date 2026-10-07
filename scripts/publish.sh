#!/bin/bash

# XiansAi Platform Multi-Repository Publishing Script
# This script coordinates publishing across all XiansAi repositories:
# - XiansAi.Server (Docker Hub)
# - XiansAi.Lib (NuGet)
# - XiansAi.Otel.Lib (NuGet)
# - sdk-web-typescript (npm)
# - agent-studio (Docker Hub)
# - XiansAi.Docs (GitHub Pages)
#
# After these publish, run ./scripts/release.sh to create the community edition release.

set -e

# Configuration
REPOS_CONFIG=(
    # Format: "repo_path|repo_name|artifact_type|registry_url"
    "../XiansAi.Server|XiansAi.Server|docker|hub.docker.com/r/99xio/xiansai-server"
    "../XiansAi.Lib|XiansAi.Lib|nuget|nuget.org/packages/XiansAi.Lib"
    "../XiansAi.Otel.Lib|XiansAi.Otel.Lib|nuget|nuget.org/packages/XiansAi.Otel.Lib"
    "../sdk-web-typescript|sdk-web-typescript|npm|npmjs.com/package/@99xio/xians-sdk-typescript"
    "../agent-studio|agent-studio|docker|hub.docker.com/r/99xio/agent-studio"
    "../XiansAi.Docs|XiansAi.Docs|docs|xiansaiplatform.github.io/XiansAi.Docs"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

log_repo() {
    echo -e "${CYAN}[REPO]${NC} $1"
}

# Show usage
show_help() {
    cat << EOF
XiansAi Platform Multi-Repository Publishing Script

Usage: $0 [OPTIONS] VERSION

This script coordinates publishing across all XiansAi repositories by:
1. Fetching origin/main in each repository
2. Creating the version tag on that commit (not the local checkout)
3. Pushing the tag to trigger GitHub Actions workflows
4. Preparing for community edition release

OPTIONS:
    -h, --help          Show this help message
    -d, --dry-run       Perform a dry run without making changes
    -f, --force         Skip confirmation prompts
    --skip-validation   Skip repository validation checks

VERSION:
    Version number in semantic versioning format (e.g., v2.1.0, v2.1.0-beta.1)

EXAMPLES:
    $0 v2.1.0                    # Publish all artifacts for v2.1.0
    $0 v2.1.0 --dry-run          # Test the publishing process

REPOSITORIES:
    XiansAi.Server      → Docker Hub (99xio/xiansai-server)
    XiansAi.Lib         → NuGet (XiansAi.Lib)
    XiansAi.Otel.Lib    → NuGet (XiansAi.Otel.Lib)
    sdk-web-typescript  → npm (@99xio/xians-sdk-typescript)
    agent-studio        → Docker Hub (99xio/agent-studio)
    XiansAi.Docs        → GitHub Pages (xiansaiplatform.github.io/XiansAi.Docs)

WORKFLOW:
    1. Run this script to publish all artifacts
    2. Run ./scripts/workflow-monitor.sh to wait for GitHub Actions to complete
    3. Run ./scripts/release.sh to create community edition release

EOF
}

# Validate version format
validate_version() {
    local version=$1
    if [[ ! $version =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9\.-]+)?$ ]]; then
        log_error "Invalid version format: $version"
        log_error "Expected format: vMAJOR.MINOR.PATCH[-prerelease]"
        log_error "Examples: v2.1.0, v2.1.0-beta.1, v2.1.0-rc.1"
        exit 1
    fi
}

# Check if repository exists and is accessible
check_repository() {
    local repo_path=$1
    local repo_name=$2
    
    if [[ ! -d "$repo_path" ]]; then
        log_error "Repository not found: $repo_path"
        log_error "Please ensure $repo_name is cloned at the correct location"
        return 1
    fi
    
    if [[ ! -d "$repo_path/.git" ]]; then
        log_error "Not a git repository: $repo_path"
        return 1
    fi
    
    # Local edits are not part of the release. The tag is placed on origin/main.
    cd "$repo_path"
    if [[ -n $(git status --porcelain) ]]; then
        log_warning "$repo_name has uncommitted changes on $(git branch --show-current). They are not included; the tag is placed on origin/main."
    fi

    cd - >/dev/null
    return 0
}

# Validate all repositories
validate_repositories() {
    log_step "Validating repositories..."
    
    for repo_config in "${REPOS_CONFIG[@]}"; do
        IFS='|' read -r repo_path repo_name artifact_type registry_url <<< "$repo_config"
        
        log_info "Checking $repo_name at $repo_path..."
        
        if ! check_repository "$repo_path" "$repo_name"; then
            if [[ "$SKIP_VALIDATION" != "true" ]]; then
                exit 1
            else
                log_warning "Skipping validation for $repo_name (--skip-validation enabled)"
            fi
        else
            log_success "$repo_name is ready"
        fi
    done
    
    log_success "Repository validation completed"
}

# Move the local main branch to origin/main when that is a fast-forward.
# The checked-out branch is left alone when it is not main.
sync_local_main() {
    local repo_name=$1

    if ! git show-ref --verify --quiet refs/heads/main; then
        git branch main origin/main
        log_info "Created local main in $repo_name at origin/main"
        return 0
    fi

    if ! git merge-base --is-ancestor main origin/main; then
        log_warning "Local main in $repo_name has commits that are not on origin/main. Left local main unchanged."
        return 0
    fi

    if [[ "$(git branch --show-current)" == "main" ]]; then
        if git merge --ff-only origin/main; then
            log_info "Fast-forwarded local main in $repo_name to origin/main"
        else
            log_warning "Could not fast-forward the checked-out main branch in $repo_name. The tag still points at origin/main."
        fi
        return 0
    fi

    git branch -f main origin/main
    log_info "Updated local main in $repo_name to origin/main"
}

# Delete an existing version tag locally and on origin when the caller agrees.
# Returns 0 to continue, 2 when the existing tag should be kept.
remove_existing_tag() {
    local repo_name=$1
    local version=$2
    local local_exists=false
    local remote_exists=false

    if git show-ref --verify --quiet "refs/tags/$version"; then
        local_exists=true
    fi
    if git ls-remote --exit-code --tags origin "refs/tags/$version" >/dev/null 2>&1; then
        remote_exists=true
    fi

    if [[ "$local_exists" == false && "$remote_exists" == false ]]; then
        return 0
    fi

    log_warning "Tag $version already exists in $repo_name"
    if [[ "$FORCE" != "true" ]]; then
        read -p "Delete and recreate tag on origin/main? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warning "Skipping $repo_name (tag exists)"
            return 2
        fi
    fi

    if [[ "$local_exists" == true ]]; then
        git tag -d "$version"
    fi
    if [[ "$remote_exists" == true ]]; then
        git push origin --delete "$version"
    fi
    return 0
}

# Create and push a tag pointing at the latest origin/main commit.
tag_repository() {
    local repo_path=$1
    local repo_name=$2
    local version=$3
    local target
    local short_target
    local branch
    local remove_status

    log_repo "Tagging $repo_name with $version at origin/main..."

    cd "$repo_path"

    log_info "Fetching origin/main for $repo_name..."
    git fetch origin +main:refs/remotes/origin/main

    if ! git rev-parse --verify --quiet origin/main >/dev/null; then
        log_error "origin/main not found in $repo_name"
        cd - >/dev/null
        return 1
    fi

    target=$(git rev-parse origin/main)
    short_target=$(git rev-parse --short "$target")
    branch=$(git branch --show-current)

    if [[ "$(git rev-parse HEAD)" != "$target" ]]; then
        log_warning "$repo_name local HEAD ($(git rev-parse --short HEAD), branch $branch) is not origin/main ($short_target). Tagging origin/main."
    else
        log_info "$repo_name local HEAD matches origin/main ($short_target)"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would fast-forward local main when possible and tag origin/main ($short_target) as $version"
        cd - >/dev/null
        return 0
    fi

    sync_local_main "$repo_name"

    remove_status=0
    remove_existing_tag "$repo_name" "$version" || remove_status=$?
    if [[ "$remove_status" -eq 2 ]]; then
        cd - >/dev/null
        return 0
    fi
    if [[ "$remove_status" -ne 0 ]]; then
        cd - >/dev/null
        return 1
    fi

    git tag -a "$version" "$target" -m "Release $version"
    git push origin "$version"

    cd - >/dev/null
    log_success "Tagged $repo_name origin/main ($short_target) as $version"
}

# Get GitHub Actions run URL for monitoring
get_workflow_url() {
    local repo_name=$1
    local version=$2
    
    case "$repo_name" in
        "XiansAi.Server")
            echo "https://github.com/XiansAiPlatform/XiansAi.Server/actions/workflows/dockerhub-deploy.yml"
            ;;
        "XiansAi.Lib")
            echo "https://github.com/XiansAiPlatform/XiansAi.Lib/actions/workflows/nuget-publish.yml"
            ;;
        "XiansAi.Otel.Lib")
            echo "https://github.com/XiansAiPlatform/XiansAi.Otel.Lib/actions/workflows/nuget-publish.yml"
            ;;
        "sdk-web-typescript")
            echo "https://github.com/XiansAiPlatform/sdk-web-typescript/actions/workflows/publish-npm.yml"
            ;;
        "agent-studio")
            echo "https://github.com/XiansAiPlatform/agent-studio/actions/workflows/dockerhub-deploy.yml"
            ;;
        "XiansAi.Docs")
            echo "https://github.com/XiansAiPlatform/XiansAi.Docs/actions/workflows/deploy.yml"
            ;;
        *)
            echo "https://github.com/XiansAiPlatform/$repo_name/actions"
            ;;
    esac
}

# Display publishing summary
show_publishing_summary() {
    local version=$1
    
    echo
    echo "=============================================="
    echo "📦 Publishing Summary for $version"
    echo "=============================================="
    echo
    
    for repo_config in "${REPOS_CONFIG[@]}"; do
        IFS='|' read -r repo_path repo_name artifact_type registry_url <<< "$repo_config"
        
        case "$artifact_type" in
            "docker")
                echo "🐳 $repo_name → https://$registry_url:$version"
                ;;
            "nuget")
                echo "📦 $repo_name → https://$registry_url/$version"
                ;;
            "npm")
                echo "📦 $repo_name → https://$registry_url/v/$version"
                ;;
            "docs")
                echo "📚 $repo_name → https://$registry_url"
                ;;
        esac
    done
    
    echo
    echo "GitHub Actions Workflows:"
    for repo_config in "${REPOS_CONFIG[@]}"; do
        IFS='|' read -r repo_path repo_name artifact_type registry_url <<< "$repo_config"
        echo "  $repo_name: $(get_workflow_url "$repo_name" "$version")"
    done
    
    echo
    echo "=============================================="
    echo "🎯 Next Steps:"
    echo "=============================================="
    echo "1. Monitor workflows: ./scripts/workflow-monitor.sh $version"
    echo "2. Verify all artifacts are published successfully"
    echo "3. Run: ./scripts/release.sh $version"
    echo "4. Update community documentation if needed"
    echo
}

# Verify published artifacts (basic checks)
verify_artifacts() {
    local version=$1
    
    log_step "Artifact verification (basic checks)..."
    
    # Remove 'v' prefix for version checks
    local clean_version=${version#v}
    
    log_info "Note: Full verification requires the artifacts to be published"
    log_info "This performs basic availability checks only"
    
    # Docker Hub images (can check via API)
    log_info "Docker images will be available at:"
    echo "  - docker pull 99xio/xiansai-server:$version"
    echo "  - docker pull 99xio/agent-studio:$version"
    
    # NuGet packages (can check via API)
    log_info "NuGet packages will be available at:"
    echo "  - dotnet add package XiansAi.Lib --version $clean_version"
    echo "  - dotnet add package XiansAi.Otel.Lib --version $clean_version"
    
    # npm package (can check via API) 
    log_info "npm package will be available at:"
    echo "  - npm install @99xio/xians-sdk-typescript@$clean_version"
    
    echo
    log_info "Run the following commands to verify after publication:"
    echo
    echo "# Check Docker images"
    echo "docker manifest inspect 99xio/xiansai-server:$version"
    echo "docker manifest inspect 99xio/agent-studio:$version"
    echo
    echo "# Check NuGet package"
    echo "curl -s https://api.nuget.org/v3-flatcontainer/xiansai.lib/index.json | grep '$clean_version'"
    echo
    echo "# Check npm package"
    echo "npm view @99xio/xians-sdk-typescript@$clean_version"
}

# Main publishing function
main() {
    local version=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            -f|--force)
                FORCE="true"
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION="true"
                shift
                ;;
            v*.*.*)
                version=$1
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Check if version is provided
    if [[ -z "$version" ]]; then
        log_error "Version is required"
        show_help
        exit 1
    fi
    
    # Validate inputs
    validate_version "$version"
    
    # Show publishing information
    echo "================================================"
    echo "🚀 XiansAi Platform Multi-Repository Publishing"
    echo "================================================"
    echo "Version: $version"
    echo "Dry run: ${DRY_RUN:-false}"
    echo "Force: ${FORCE:-false}"
    echo "Skip validation: ${SKIP_VALIDATION:-false}"
    echo "================================================"
    echo
    
    # Confirmation
    if [[ "$FORCE" != "true" && "$DRY_RUN" != "true" ]]; then
        echo "This will tag origin/main in each repository and trigger publishing."
        echo "Local checkouts are updated to that commit. Unpushed local commits are not tagged."
        echo
        read -p "Proceed with publishing? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Publishing cancelled"
            exit 1
        fi
    fi
    
    # Execute publishing steps
    validate_repositories
    
    echo
    log_step "Tagging repositories..."
    
    for repo_config in "${REPOS_CONFIG[@]}"; do
        IFS='|' read -r repo_path repo_name artifact_type registry_url <<< "$repo_config"
        tag_repository "$repo_path" "$repo_name" "$version"
    done
    
    log_success "All repositories tagged successfully!"
    
    # Show verification info
    verify_artifacts "$version"
    
    # Show summary
    show_publishing_summary "$version"
    
    log_success "Publishing process completed!"
    log_info "Monitor workflows with './scripts/workflow-monitor.sh $version', then run './scripts/release.sh $version' when ready."
}

# Run main function
main "$@"

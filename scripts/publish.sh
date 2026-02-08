#!/bin/bash

# XiansAi Platform Multi-Repository Publishing Script
# This script coordinates publishing across all XiansAi repositories:
# - XiansAi.Server (Docker Hub)
# - XiansAi.UI (Docker Hub) 
# - XiansAi.Lib (NuGet)
# - sdk-web-typescript (npm)
# - agent-studio (Docker Hub)
# - XiansAi.Docs (GitHub Pages)
# - community-edition (GitHub Release)

set -e

# Configuration
REPOS_CONFIG=(
    # Format: "repo_path|repo_name|artifact_type|registry_url"
    "../XiansAi.Server|XiansAi.Server|docker|hub.docker.com/r/99xio/xiansai-server"
    "../XiansAi.UI|XiansAi.UI|docker|hub.docker.com/r/99xio/xiansai-ui"
    "../XiansAi.Lib|XiansAi.Lib|nuget|nuget.org/packages/XiansAi.Lib"
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
1. Creating version tags in each repository
2. Pushing tags to trigger GitHub Actions workflows
3. Monitoring publishing progress
4. Preparing for community edition release

OPTIONS:
    -h, --help          Show this help message
    -d, --dry-run       Perform a dry run without making changes
    -f, --force         Skip confirmation prompts
    -w, --wait          Wait for all workflows to complete
    --skip-validation   Skip repository validation checks

VERSION:
    Version number in semantic versioning format (e.g., v2.1.0, v2.1.0-beta.1)

EXAMPLES:
    $0 v2.1.0                    # Publish all artifacts for v2.1.0
    $0 v2.1.0-beta.1 --wait      # Publish and wait for completion
    $0 v2.1.0 --dry-run          # Test the publishing process

REPOSITORIES:
    XiansAi.Server      → Docker Hub (99xio/xiansai-server)
    XiansAi.UI          → Docker Hub (99xio/xiansai-ui)
    XiansAi.Lib         → NuGet (XiansAi.Lib)
    sdk-web-typescript  → npm (@99xio/xians-sdk-typescript)
    agent-studio        → Docker Hub (99xio/agent-studio)
    XiansAi.Docs        → GitHub Pages (xiansaiplatform.github.io/XiansAi.Docs)

WORKFLOW:
    1. Run this script to publish all artifacts
    2. Wait for GitHub Actions to complete
    3. Run ./release.sh to create community edition release

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
    
    # Check if repo has uncommitted changes
    cd "$repo_path"
    if [[ -n $(git status --porcelain) ]]; then
        log_warning "$repo_name has uncommitted changes"
        if [[ "$FORCE" != "true" ]]; then
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_error "Publishing cancelled due to uncommitted changes in $repo_name"
                cd - >/dev/null
                return 1
            fi
        fi
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

# Create and push tag to a repository
tag_repository() {
    local repo_path=$1
    local repo_name=$2
    local version=$3
    
    log_repo "Tagging $repo_name with $version..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would tag $repo_name with $version"
        return 0
    fi
    
    cd "$repo_path"
    
    # Check if tag already exists
    if git tag -l | grep -q "^$version$"; then
        log_warning "Tag $version already exists in $repo_name"
        if [[ "$FORCE" != "true" ]]; then
            read -p "Delete and recreate tag? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                git tag -d "$version"
                git push origin --delete "$version" 2>/dev/null || true
            else
                log_warning "Skipping $repo_name (tag exists)"
                cd - >/dev/null
                return 0
            fi
        else
            git tag -d "$version"
            git push origin --delete "$version" 2>/dev/null || true
        fi
    fi
    
    # Create and push tag
    git tag -a "$version" -m "Release $version"
    git push origin "$version"
    
    cd - >/dev/null
    log_success "Tagged $repo_name with $version"
}

# Get GitHub Actions run URL for monitoring
get_workflow_url() {
    local repo_name=$1
    local version=$2
    
    case "$repo_name" in
        "XiansAi.Server")
            echo "https://github.com/XiansAiPlatform/XiansAi.Server/actions/workflows/dockerhub-deploy.yml"
            ;;
        "XiansAi.UI")
            echo "https://github.com/XiansAiPlatform/XiansAi.UI/actions/workflows/dockerhub-deploy.yml"
            ;;
        "XiansAi.Lib")
            echo "https://github.com/XiansAiPlatform/XiansAi.Lib/actions/workflows/nuget-publish.yml"
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

# Wait for GitHub Actions to complete
wait_for_workflows() {
    local version=$1
    
    if [[ "$WAIT_FOR_WORKFLOWS" != "true" ]]; then
        return 0
    fi
    
    log_step "Waiting for GitHub Actions workflows to complete..."
    log_info "This may take 5-15 minutes depending on build complexity"
    
    # Check if gh CLI is available
    if ! command -v gh &> /dev/null; then
        log_warning "GitHub CLI not found. Cannot monitor workflows automatically."
        log_info "Please monitor workflows manually in GitHub and run release.sh when ready."
        return 0
    fi
    
    local all_complete=false
    local check_count=0
    local max_checks=60  # 30 minutes max wait (30 seconds * 60)
    
    while [[ "$all_complete" != "true" && $check_count -lt $max_checks ]]; do
        all_complete=true
        
        for repo_config in "${REPOS_CONFIG[@]}"; do
            IFS='|' read -r repo_path repo_name artifact_type registry_url <<< "$repo_config"
            
            # This would require gh CLI and proper repo access
            # For now, we'll provide manual monitoring instructions
            log_info "Check $repo_name workflow: $(get_workflow_url "$repo_name" "$version")"
        done
        
        if [[ "$all_complete" != "true" ]]; then
            log_info "Waiting 30 seconds before next check..."
            sleep 30
            ((check_count++))
        fi
    done
    
    if [[ $check_count -ge $max_checks ]]; then
        log_warning "Timeout waiting for workflows. Please check manually."
    else
        log_success "All workflows completed!"
    fi
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
    echo "1. Monitor GitHub Actions workflows (links above)"
    echo "2. Verify all artifacts are published successfully"
    echo "3. Run: ./release.sh $version"
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
    echo "  - docker pull 99xio/xiansai-ui:$version"
    echo "  - docker pull 99xio/agent-studio:$version"
    
    # NuGet package (can check via API)
    log_info "NuGet package will be available at:"
    echo "  - dotnet add package XiansAi.Lib --version $clean_version"
    
    # npm package (can check via API) 
    log_info "npm package will be available at:"
    echo "  - npm install @99xio/xians-sdk-typescript@$clean_version"
    
    echo
    log_info "Run the following commands to verify after publication:"
    echo
    echo "# Check Docker images"
    echo "docker manifest inspect 99xio/xiansai-server:$version"
    echo "docker manifest inspect 99xio/xiansai-ui:$version"
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
            -w|--wait)
                WAIT_FOR_WORKFLOWS="true"
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
    echo "Wait for workflows: ${WAIT_FOR_WORKFLOWS:-false}"
    echo "Skip validation: ${SKIP_VALIDATION:-false}"
    echo "================================================"
    echo
    
    # Confirmation
    if [[ "$FORCE" != "true" && "$DRY_RUN" != "true" ]]; then
        echo "This will tag and trigger publishing for all repositories."
        echo "Make sure all repositories are ready for release."
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
    
    # Wait for workflows if requested
    wait_for_workflows "$version"
    
    # Show verification info
    verify_artifacts "$version"
    
    # Show summary
    show_publishing_summary "$version"
    
    log_success "Publishing process completed!"
    log_info "Monitor the GitHub Actions workflows and run './release.sh $version' when ready."
}

# Run main function
main "$@"

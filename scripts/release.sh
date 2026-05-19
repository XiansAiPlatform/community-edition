#!/bin/bash

# XiansAi Platform Community Edition Release Script
# This script automates the release process including:
# - Version validation and tagging
# - Release notes generation
# - GitHub release creation
# - Docker image validation

set -e

# Configuration
REPO_OWNER="${GITHUB_REPOSITORY_OWNER:-XiansAiPlatform}"
REPO_NAME="${GITHUB_REPOSITORY_NAME:-community-edition}"
RELEASES_DIR="./releases"
CHANGELOG_FILE="CHANGELOG.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Download assets from other repositories
download_external_assets() {
    local version=$1
    local assets_dir="./release-assets"
    
    if [[ "$INCLUDE_ASSETS" != "true" ]]; then
        log_info "Skipping external assets download (use --include-assets to enable)"
        return
    fi
    
    log_info "Downloading assets from related repositories..."
    
    # Create temporary assets directory
    mkdir -p "$assets_dir"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would download assets for version $version from: $ASSETS_REPOS"
        return
    fi
    
    # Convert comma-separated repos to array
    IFS=',' read -ra REPO_ARRAY <<< "$ASSETS_REPOS"
    
    for repo in "${REPO_ARRAY[@]}"; do
        repo=$(echo "$repo" | xargs) # trim whitespace
        repo_name=$(basename "$repo")
        
        if download_repo_assets "$repo" "$version" "$assets_dir"; then
            log_success "Downloaded $repo_name assets"
        else
            log_warning "Could not download $repo_name assets (release may not exist yet)"
        fi
    done
}

# Download assets from a specific repository
download_repo_assets() {
    local repo=$1
    local version=$2
    local assets_dir=$3
    local repo_assets_dir="$assets_dir/$(basename $repo)"
    
    mkdir -p "$repo_assets_dir"
    
    # Check if release exists
    if ! gh release view "$version" --repo "$repo" &>/dev/null; then
        return 1
    fi
    
    # Download all assets from the release
    gh release download "$version" --repo "$repo" --dir "$repo_assets_dir" 2>/dev/null || return 1
    
    # Also create a manifest file for this repo
    echo "Repository: $repo" > "$repo_assets_dir/MANIFEST.txt"
    echo "Version: $version" >> "$repo_assets_dir/MANIFEST.txt"
    echo "Downloaded: $(date)" >> "$repo_assets_dir/MANIFEST.txt"
    echo "Assets:" >> "$repo_assets_dir/MANIFEST.txt"
    find "$repo_assets_dir" -type f ! -name "MANIFEST.txt" -exec basename {} \; >> "$repo_assets_dir/MANIFEST.txt"
    
    return 0
}

# Clean up temporary assets
cleanup_assets() {
    local assets_dir="./release-assets"
    
    if [[ -d "$assets_dir" ]]; then
        log_info "Cleaning up temporary assets directory"
        rm -rf "$assets_dir"
    fi
}

# Show usage
show_help() {
    cat << EOF
XiansAi Platform Release Script

Usage: $0 [OPTIONS] VERSION

OPTIONS:
    -h, --help          Show this help message
    -d, --dry-run       Perform a dry run without making changes
    -f, --force         Skip confirmation prompts
    --draft             Create a draft release
    --prerelease        Mark as pre-release
    --no-github         Skip GitHub release creation
    --include-assets    Download and include assets from related repositories
    --assets-repos      Comma-separated list of repos to download assets from
                        (default: XiansAiPlatform/XiansAi.Server,XiansAiPlatform/XiansAi.UI,XiansAiPlatform/XiansAi.Lib,XiansAiPlatform/XiansAi.Otel.Lib,XiansAiPlatform/sdk-web-typescript)

VERSION:
    Version number in semantic versioning format (e.g., v2.1.0, v2.1.0-beta.1)

EXAMPLES:
    $0 v2.1.0                    # Create a stable release
    $0 v2.1.0-beta.1 --prerelease  # Create a pre-release
    $0 v2.1.0 --dry-run          # Test the release process
    $0 v2.1.0 --draft            # Create a draft release
    $0 v2.1.0 --include-assets   # Include assets from related repositories
    $0 v2.1.0 --include-assets --assets-repos "org/repo1,org/repo2"  # Custom repos

REQUIREMENTS:
    - Git repository with clean working directory
    - GitHub CLI (gh) installed and authenticated
    - Docker installed for image validation
    - Release notes file in ./releases/VERSION.md

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check git status
    if [[ -n $(git status --porcelain) ]]; then
        log_error "Working directory is not clean. Please commit or stash changes."
        exit 1
    fi
    
    # Check if we're on main branch
    current_branch=$(git branch --show-current)
    if [[ "$current_branch" != "main" ]]; then
        log_warning "Not on main branch (current: $current_branch)"
        if [[ "$FORCE" != "true" ]]; then
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_error "Release cancelled"
                exit 1
            fi
        fi
    fi
    
    # Check GitHub CLI
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed. Please install it from https://cli.github.com/"
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_warning "Docker is not installed. Skipping Docker image validation."
    fi
    
    # Check if already authenticated with GitHub
    if ! gh auth status &> /dev/null; then
        log_error "Not authenticated with GitHub. Run 'gh auth login' first."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Check if release notes exist
check_release_notes() {
    local version=$1
    local notes_file="$RELEASES_DIR/${version}.md"
    
    if [[ ! -f "$notes_file" ]]; then
        log_error "Release notes not found: $notes_file"
        log_info "Please create release notes using: ./create-release-notes.sh $version"
        exit 1
    fi
    
    log_success "Release notes found: $notes_file"
}

# Validate Docker images
validate_docker_images() {
    local version=$1
    log_info "Validating Docker images for version $version..."
    
    if command -v docker &> /dev/null; then
        # Test if the platform starts with the new version
        log_info "Testing platform startup with version $version..."
        if ./start-all.sh -v "$version" --test 2>/dev/null; then
            log_success "Docker images validated successfully"
            ./stop-all.sh >/dev/null 2>&1 || true
        else
            log_warning "Could not validate Docker images (they might not be published yet)"
        fi
    fi
}

# Create git tag
create_git_tag() {
    local version=$1
    local tag_message="Release $version"
    
    log_info "Creating git tag: $version"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create tag: $version"
        return
    fi
    
    git tag -a "$version" -m "$tag_message"
    git push origin "$version"
    
    log_success "Git tag created and pushed"
}

# Create GitHub release
create_github_release() {
    local version=$1
    local notes_file="$RELEASES_DIR/${version}.md"
    local release_args=()
    local assets_dir="./release-assets"
    
    log_info "Creating GitHub release: $version"
    
    # Build release arguments
    release_args+=("--title" "XiansAi Platform $version")
    release_args+=("--notes-file" "$notes_file")
    
    if [[ "$DRAFT" == "true" ]]; then
        release_args+=("--draft")
    fi
    
    if [[ "$PRERELEASE" == "true" ]]; then
        release_args+=("--prerelease")
    fi
    
    # Add assets if they exist
    if [[ -d "$assets_dir" ]]; then
        # Find all files in assets directory (excluding MANIFEST.txt files)
        while IFS= read -r -d '' asset_file; do
            if [[ $(basename "$asset_file") != "MANIFEST.txt" ]]; then
                release_args+=("$asset_file")
            fi
        done < <(find "$assets_dir" -type f -print0 2>/dev/null)
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create GitHub release with args: ${release_args[*]}"
        if [[ -d "$assets_dir" ]]; then
            log_info "[DRY RUN] Would upload assets from: $assets_dir"
            find "$assets_dir" -type f ! -name "MANIFEST.txt" -exec echo "  - {}" \;
        fi
        return
    fi
    
    gh release create "$version" "${release_args[@]}"
    
    log_success "GitHub release created: https://github.com/$REPO_OWNER/$REPO_NAME/releases/tag/$version"
    
    # Upload additional manifest files separately if needed
    if [[ -d "$assets_dir" ]]; then
        find "$assets_dir" -name "MANIFEST.txt" -exec gh release upload "$version" {} \; 2>/dev/null || true
        log_success "Assets uploaded from related repositories"
    fi
}

# Update changelog
update_changelog() {
    local version=$1
    local notes_file="$RELEASES_DIR/${version}.md"
    local temp_changelog=$(mktemp)
    
    log_info "Updating CHANGELOG.md"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would update CHANGELOG.md"
        return
    fi
    
    # Create changelog header
    echo "# Changelog" > "$temp_changelog"
    echo "" >> "$temp_changelog"
    echo "All notable changes to the XiansAi Platform Community Edition will be documented in this file." >> "$temp_changelog"
    echo "" >> "$temp_changelog"
    echo "The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)," >> "$temp_changelog"
    echo "and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)." >> "$temp_changelog"
    echo "" >> "$temp_changelog"
    
    # Add current release
    echo "## [$version] - $(date +%Y-%m-%d)" >> "$temp_changelog"
    echo "" >> "$temp_changelog"
    cat "$notes_file" >> "$temp_changelog"
    echo "" >> "$temp_changelog"
    
    # Append existing changelog if it exists
    if [[ -f "$CHANGELOG_FILE" ]]; then
        # Skip the header of existing changelog
        tail -n +8 "$CHANGELOG_FILE" >> "$temp_changelog" 2>/dev/null || true
    fi
    
    mv "$temp_changelog" "$CHANGELOG_FILE"
    git add "$CHANGELOG_FILE"
    
    log_success "CHANGELOG.md updated"
}

# Main release function
main() {
    local version=""
    
    # Default configuration
    INCLUDE_ASSETS="false"
    ASSETS_REPOS="XiansAiPlatform/XiansAi.Server,XiansAiPlatform/XiansAi.UI,XiansAiPlatform/XiansAi.Lib,XiansAiPlatform/XiansAi.Otel.Lib,XiansAiPlatform/sdk-web-typescript"
    
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
            --draft)
                DRAFT="true"
                shift
                ;;
            --prerelease)
                PRERELEASE="true"
                shift
                ;;
            --no-github)
                NO_GITHUB="true"
                shift
                ;;
            --include-assets)
                INCLUDE_ASSETS="true"
                shift
                ;;
            --assets-repos)
                ASSETS_REPOS="$2"
                shift 2
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
    
    # Show release information
    echo "======================================"
    echo "XiansAi Platform Release: $version"
    echo "======================================"
    echo "Repository: $REPO_OWNER/$REPO_NAME"
    echo "Draft: ${DRAFT:-false}"
    echo "Pre-release: ${PRERELEASE:-false}"
    echo "Dry run: ${DRY_RUN:-false}"
    echo "Include assets: ${INCLUDE_ASSETS:-false}"
    if [[ "$INCLUDE_ASSETS" == "true" ]]; then
        echo "Asset repositories: $ASSETS_REPOS"
    fi
    echo "======================================"
    echo
    
    # Confirmation
    if [[ "$FORCE" != "true" && "$DRY_RUN" != "true" ]]; then
        read -p "Proceed with release? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Release cancelled"
            exit 1
        fi
    fi
    
    # Execute release steps
    check_prerequisites
    check_release_notes "$version"
    validate_docker_images "$version"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        update_changelog "$version"
        git commit -m "chore: update changelog for $version" || true
    fi
    
    create_git_tag "$version"
    
    if [[ "$NO_GITHUB" != "true" ]]; then
        download_external_assets "$version"
        create_github_release "$version"
    fi
    
    log_success "Release $version completed successfully!"
    log_info "Release URL: https://github.com/$REPO_OWNER/$REPO_NAME/releases/tag/$version"
    
    # Clean up temporary files
    cleanup_assets
}

# Run main function
main "$@"

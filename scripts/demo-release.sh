#!/bin/bash

# XiansAi Platform Release Demo Script
# This script demonstrates the complete release workflow

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_step() {
    echo -e "${PURPLE}[DEMO STEP]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

show_help() {
    cat << EOF
XiansAi Platform Release Demo

This script demonstrates the complete release workflow using dry-run mode.

Usage: $0 [VERSION]

VERSION: Optional version to use for demo (default: v2.1.0-demo)

EXAMPLES:
    $0                    # Demo with v2.1.0-demo
    $0 v2.2.0-demo       # Demo with custom version

NOTE: This script runs in dry-run mode and won't make actual changes.

EOF
}

main() {
    local version=${1:-v2.1.0-demo}
    
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi
    
    echo "=============================================="
    echo "🎯 XiansAi Platform Release Workflow Demo"
    echo "=============================================="
    echo "Version: $version"
    echo "Mode: DRY RUN (no actual changes)"
    echo "=============================================="
    echo
    
    log_step "Step 1: Creating release notes template"
    echo "Command: ./scripts/create-release-notes.sh $version"
    if [[ -f "./releases/${version}.md" ]]; then
        log_info "Release notes already exist for $version"
    else
        log_info "Would create: ./releases/${version}.md"
        log_info "You would then edit this file with actual release information"
    fi
    echo
    
    log_step "Step 2: Publishing artifacts across all repositories"
    echo "Command: ./scripts/publish.sh $version --dry-run"
    log_info "This would:"
    echo "  📋 Validate all repositories (XiansAi.Server, XiansAi.Lib, sdk-web-typescript)"
    echo "  🏷️  Create version tags in each repository"
    echo "  🚀 Push tags to trigger GitHub Actions workflows"
    echo "  📦 Publish: Docker images, NuGet packages, npm packages"
    echo
    
    log_step "Step 3: Monitoring workflow progress"
    echo "Command: ./scripts/workflow-monitor.sh $version"
    log_info "This would:"
    echo "  👀 Monitor GitHub Actions workflows across all repositories"
    echo "  ⏱️  Wait for all publishing workflows to complete (up to 30 minutes)"
    echo "  ✅ Verify all artifacts are published successfully"
    echo "  📊 Report any failures with detailed logs"
    echo
    
    log_step "Step 4: Creating community edition release"
    echo "Command: ./release.sh $version --dry-run"
    log_info "This would:"
    echo "  📝 Update CHANGELOG.md with release notes"
    echo "  🏷️  Create git tag for community-edition repository"
    echo "  🐙 Create GitHub release with release notes"
    echo "  🔗 Provide release URL for sharing"
    echo
    
    log_step "Complete workflow commands:"
    echo "=========================================="
    echo -e "${YELLOW}# Complete release workflow${NC}"
    echo "./scripts/create-release-notes.sh $version"
    echo "# Edit ./releases/${version}.md with actual changes"
    echo "./scripts/publish.sh $version"
    echo "./scripts/workflow-monitor.sh $version"
    echo "./release.sh $version"
    echo
    echo -e "${YELLOW}# Or simplified one-liner (for experienced maintainers):${NC}"
    echo "./scripts/publish.sh $version && ./scripts/workflow-monitor.sh $version && ./release.sh $version"
    echo
    
    log_step "Available artifacts after release:"
    echo "=========================================="
    local clean_version=${version#v}
    echo "🐳 Docker Images:"
    echo "   docker pull 99xio/xiansai-server:$version"
    echo
    echo "📦 NuGet Package:"
    echo "   dotnet add package XiansAi.Lib --version $clean_version"
    echo
    echo "📦 npm Package:"
    echo "   npm install @99xio/xians-sdk-typescript@$clean_version"
    echo
    echo "🐙 GitHub Release:"
    echo "   https://github.com/XiansAiPlatform/community-edition/releases/tag/$version"
    echo
    
    log_step "Testing the workflow:"
    echo "=========================================="
    echo "To test this workflow safely:"
    echo
    echo "1. Create release notes:"
    echo "   ./scripts/create-release-notes.sh $version"
    echo
    echo "2. Test publishing (dry-run):"
    echo "   ./scripts/publish.sh $version --dry-run"
    echo
    echo "3. Test release creation (dry-run):"
    echo "   ./release.sh $version --dry-run"
    echo
    
    log_success "Demo complete! The XiansAi Platform release workflow coordinates"
    log_success "publishing across 5 repositories with a single command."
    echo
    log_info "For more information, see:"
    echo "  📖 docs/RELEASE_GUIDE.md"
    echo "  🤝 CONTRIBUTING.md"
    echo "  📋 ./scripts/publish.sh --help"
    echo "  🔍 ./scripts/workflow-monitor.sh --help"
    echo "  🚀 ./release.sh --help"
}

main "$@" 
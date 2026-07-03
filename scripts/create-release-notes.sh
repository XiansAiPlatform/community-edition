#!/bin/bash

# Release Notes Template Generator
# This script creates a template for release notes

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
RELEASES_DIR="./releases"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

show_help() {
    cat << EOF
Release Notes Template Generator

Usage: $0 VERSION

Creates a release notes template file for the specified version.

EXAMPLES:
    $0 v2.1.0        # Create template for stable release
    $0 v2.1.0-beta.1 # Create template for beta release

The template will be created at: ./releases/VERSION.md
EOF
}

create_template() {
    local version=$1
    local notes_file="$RELEASES_DIR/${version}.md"
    local is_prerelease=false
    
    # Check if it's a prerelease
    if [[ $version =~ -[a-zA-Z] ]]; then
        is_prerelease=true
    fi
    
    # Create releases directory if it doesn't exist
    mkdir -p "$RELEASES_DIR"
    
    # Create the template
    cat > "$notes_file" << EOF
### 🚀 New Features

- **Feature Name**: Brief description of the new feature
- **Another Feature**: Description with more details about implementation

### 🔧 Improvements

- **Performance**: Describe performance improvements
- **UI/UX**: User interface and experience enhancements
- **Developer Experience**: Improvements for developers using the platform

### 🐛 Bug Fixes

- Fixed issue with [component] causing [problem]
- Resolved [specific bug] that affected [functionality]
- Corrected [issue] in [area] functionality

$(if [[ "$is_prerelease" != "true" ]]; then
cat << 'STABLE_EOF'
### ⚠️ Breaking Changes

- **API Changes**: Description of any breaking API changes
- **Configuration**: Any configuration file changes required
- **Database**: Schema changes or migration requirements

### 📋 Migration Guide

#### From vX.X.X to $version

1. **Step 1**: Detailed migration step
   \`\`\`bash
   # Example commands
   ./stop-all.sh
   ./reset-all.sh -f
   \`\`\`

2. **Step 2**: Additional migration instructions
   \`\`\`bash
   # Update configuration
   # Edit server/.env.local
   \`\`\`

STABLE_EOF
fi)

### 🔒 Security Updates

- Updated dependencies with security patches
- Enhanced security configurations
- Improved authentication and authorization

### 📚 Documentation

- Updated README with new features
- Enhanced API documentation
- Added troubleshooting guides

### 🏗️ Infrastructure

- **Docker**: Updated Docker images and configurations
- **Database**: Database improvements and optimizations
- **Monitoring**: Enhanced monitoring and health checks

### 📦 Dependencies

- Updated major dependencies to latest versions
- Security patches for all components
- Performance improvements in dependencies

$(if [[ "$is_prerelease" == "true" ]]; then
cat << 'BETA_EOF'
### 🧪 Beta Features (Experimental)

- **Feature A**: Experimental feature description
- **Feature B**: Another beta feature requiring testing

### ⚠️ Beta Limitations

- This is a pre-release version for testing purposes
- Some features may be incomplete or unstable
- Not recommended for production use
- Breaking changes may occur in future beta releases

### 🧪 Testing Instructions

1. **Setup**: How to set up the beta version
2. **Testing**: What to test and how to report issues
3. **Feedback**: Where to provide feedback

BETA_EOF
fi)

### 📝 Known Issues

- List any known issues or limitations
- Workarounds for common problems
- Issues being tracked for future releases

### 🎯 What's Next

- Planned features for next release
- Roadmap items in progress
- Community feature requests being considered

---

**Full Changelog**: https://github.com/XiansAiPlatform/community-edition/compare/vPREVIOUS...${version}
**Docker Images**: Available with tag \`${version}\`
**Documentation**: See updated documentation in repository

<!-- 
INSTRUCTIONS FOR EDITING THIS TEMPLATE:
1. Replace placeholder text with actual changes
2. Remove sections that don't apply to this release
3. Add specific version numbers and dates where needed
4. Include links to relevant PRs, issues, or documentation
5. Test all code examples and commands
6. Review for clarity and completeness before release
-->
EOF
    
    log_success "Release notes template created: $notes_file"
    log_info "Please edit the template with actual release information before running ./scripts/release.sh"
    
    # Open in editor if available
    if command -v code &> /dev/null; then
        log_info "Opening in VS Code..."
        code "$notes_file"
    elif [[ -n "$EDITOR" ]]; then
        log_info "Opening in $EDITOR..."
        $EDITOR "$notes_file"
    fi
}

main() {
    local version=""
    
    # Parse arguments
    case "$1" in
        -h|--help|"")
            show_help
            exit 0
            ;;
        v*.*.*)
            version=$1
            ;;
        *)
            echo "Error: Invalid version format: $1"
            show_help
            exit 1
            ;;
    esac
    
    create_template "$version"
}

main "$@" 
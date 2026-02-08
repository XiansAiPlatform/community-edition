#!/bin/bash

# GitHub Actions Workflow Monitor
# This script monitors workflow runs across multiple repositories

set -e

# Configuration
REPOS=(
    "XiansAiPlatform/XiansAi.Server"
    "XiansAiPlatform/XiansAi.UI"
    "XiansAiPlatform/XiansAi.Lib"
    "XiansAiPlatform/sdk-web-typescript"
    "XiansAiPlatform/agent-studio"
    "XiansAiPlatform/XiansAi.Docs"
)

WORKFLOWS=(
    "dockerhub-deploy.yml"
    "dockerhub-deploy.yml"
    "nuget-publish.yml"
    "publish-npm.yml"
    "dockerhub-deploy.yml"
    "deploy.yml"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

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

show_help() {
    cat << EOF
GitHub Actions Workflow Monitor

Usage: $0 [OPTIONS] VERSION

Monitor GitHub Actions workflows across XiansAi repositories for a specific version.

OPTIONS:
    -h, --help          Show this help message
    -t, --timeout MINS  Timeout in minutes (default: 30)
    -i, --interval SECS Polling interval in seconds (default: 30)
    --show-logs         Show workflow logs for failed runs
    --no-jq             Skip JSON parsing (basic monitoring only)
    --debug             Show debug information including raw workflow data

VERSION:
    Version tag to monitor (e.g., v2.1.0)

EXAMPLES:
    $0 v2.1.0                    # Monitor workflows for v2.1.0
    $0 v2.1.0 --timeout 45      # Monitor with 45 minute timeout
    $0 v2.1.0 --show-logs       # Show logs for failed workflows
    $0 v2.1.0 --no-jq           # Monitor without JSON parsing

REQUIREMENTS:
    - GitHub CLI (gh) installed and authenticated
    - jq installed for detailed monitoring (optional with --no-jq)

EOF
}

# Check if GitHub CLI is available and authenticated
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed"
        log_info "Install from: https://cli.github.com/"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        log_error "Not authenticated with GitHub"
        log_info "Run: gh auth login"
        exit 1
    fi
}

# Check if jq is available
check_jq() {
    if ! command -v jq &> /dev/null; then
        log_warning "jq is not installed - using basic monitoring mode"
        log_info "For detailed monitoring, install jq:"
        echo "  macOS: brew install jq"
        echo "  Ubuntu/Debian: sudo apt-get install jq"
        echo "  CentOS/RHEL: sudo yum install jq"
        echo "  Or use --no-jq flag to skip this warning"
        echo
        return 1
    fi
    return 0
}

# Get workflow runs for a specific tag (with jq)
get_workflow_runs_jq() {
    local repo=$1
    local workflow=$2
    local version=$3
    
    # Try gh run list first, fallback to API if it fails
    local runs
    runs=$(gh run list \
        --repo "$repo" \
        --workflow "$workflow" \
        --limit 10 \
        --json "databaseId,status,conclusion,createdAt,headBranch,event,displayTitle" 2>/dev/null)
    
    # If gh run list fails or returns empty, try direct API call
    if [[ $? -ne 0 || -z "$runs" || "$runs" == "[]" ]]; then
        if [[ "$DEBUG" == "true" ]]; then
            echo "gh run list failed, trying direct API call..." >&2
        fi
        runs=$(gh api "repos/$repo/actions/workflows/$workflow/runs" --jq '.workflow_runs[0:10] | map({databaseId: .id, status: .status, conclusion: .conclusion, createdAt: .created_at, headBranch: .head_branch, event: .event, displayTitle: .display_title})' 2>/dev/null)
    fi
    
    if [[ $? -ne 0 || -z "$runs" ]]; then
        echo "[]"
        return
    fi
    
    # Filter for runs that match our version tag
    # Handle both headBranch (camelCase) and head_branch (snake_case) field names
    echo "$runs" | jq --arg version "$version" '.[] | select((.headBranch // .head_branch) == $version or ((.displayTitle // .display_title // "") | contains($version)))' 2>/dev/null || echo "[]"
}

# Check individual workflow status (basic mode)
check_workflow_status_basic() {
    local repo=$1
    local workflow=$2
    local version=$3
    local repo_name=$(basename "$repo")
    
    log_info "Checking $repo_name workflow (basic mode)..."
    
    # Try to get basic workflow information
    local runs
    runs=$(gh run list --repo "$repo" --workflow "$workflow" --limit 5 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        echo "❌ $repo_name: Unable to access repository or workflow"
        return 1
    fi
    
    if [[ -z "$runs" ]]; then
        echo "⏳ $repo_name: No recent workflow runs found"
        return 2  # Not started/unknown
    fi
    
    # Basic parsing - look for version in recent runs
    if echo "$runs" | grep -q "$version"; then
        if echo "$runs" | grep "$version" | grep -q "completed.*success"; then
            echo "✅ $repo_name: Recent workflow appears successful"
            return 0  # Success
        elif echo "$runs" | grep "$version" | grep -q "completed.*failure"; then
            echo "❌ $repo_name: Recent workflow appears to have failed"
            return 1  # Failed
        elif echo "$runs" | grep "$version" | grep -q "in_progress"; then
            echo "🔄 $repo_name: Workflow appears to be running"
            return 2  # In progress
        else
            echo "🔄 $repo_name: Workflow status unclear - check manually"
            return 2  # In progress
        fi
    else
        echo "⏳ $repo_name: No workflow runs found for $version"
        return 2  # Not started
    fi
}

# Check individual workflow status (with jq)
check_workflow_status_jq() {
    local repo=$1
    local workflow=$2
    local version=$3
    local repo_name=$(basename "$repo")
    
    log_info "Checking $repo_name workflow..."
    
    local runs
    runs=$(get_workflow_runs_jq "$repo" "$workflow" "$version")
    
    if [[ $? -ne 0 ]]; then
        echo "❌ $repo_name: Unable to access repository or workflow"
        return 1
    fi
    
    # Debug output
    if [[ "$DEBUG" == "true" ]]; then
        log_info "Raw workflow runs for $repo_name (via API):"
        gh api "repos/$repo/actions/workflows/$workflow/runs" --jq '.workflow_runs[0:3] | .[] | {id: .id, status: .status, conclusion: .conclusion, head_branch: .head_branch, event: .event, display_title: .display_title}' 2>/dev/null || echo "Failed to get raw API data"
        log_info "Filtered runs for version $version:"
        echo "$runs" | jq '.' 2>/dev/null || echo "Failed to parse filtered data"
    fi
    
    if [[ "$runs" == "[]" || -z "$runs" ]]; then
        echo "⏳ $repo_name: No workflow runs found for $version"
        return 2  # Not started
    fi
    
    # Parse the first (most recent) matching run
    local status conclusion run_id
    status=$(echo "$runs" | jq -r 'if type == "array" then .[0].status else .status end' 2>/dev/null)
    conclusion=$(echo "$runs" | jq -r 'if type == "array" then .[0].conclusion else .conclusion end' 2>/dev/null)
    run_id=$(echo "$runs" | jq -r 'if type == "array" then (.[0].databaseId // .[0].database_id) else (.databaseId // .database_id) end' 2>/dev/null)
    
    # Handle parsing errors
    if [[ -z "$status" || "$status" == "null" ]]; then
        echo "❓ $repo_name: Unable to parse workflow status"
        return 2
    fi
    
    case "$status" in
        "completed")
            case "$conclusion" in
                "success")
                    echo "✅ $repo_name: Workflow completed successfully"
                    return 0  # Success
                    ;;
                "failure")
                    echo "❌ $repo_name: Workflow failed"
                    if [[ "$SHOW_LOGS" == "true" && -n "$run_id" && "$run_id" != "null" ]]; then
                        log_info "Fetching logs for failed workflow..."
                        gh run view "$run_id" --repo "$repo" --log 2>/dev/null || true
                    fi
                    return 1  # Failed
                    ;;
                "cancelled")
                    echo "🚫 $repo_name: Workflow was cancelled"
                    return 1  # Failed
                    ;;
                "skipped")
                    echo "⏭️ $repo_name: Workflow was skipped"
                    return 2  # Neutral
                    ;;
                *)
                    echo "❓ $repo_name: Workflow completed with status: $conclusion"
                    return 1  # Failed
                    ;;
            esac
            ;;
        "in_progress")
            echo "🔄 $repo_name: Workflow is running..."
            return 2  # In progress
            ;;
        "queued")
            echo "⏳ $repo_name: Workflow is queued..."
            return 2  # In progress
            ;;
        "requested")
            echo "📝 $repo_name: Workflow was requested..."
            return 2  # In progress
            ;;
        *)
            echo "❓ $repo_name: Unknown workflow status: $status"
            return 2  # Unknown
            ;;
    esac
}

# Monitor all workflows
monitor_workflows() {
    local version=$1
    local timeout_mins=${TIMEOUT:-30}
    local interval_secs=${INTERVAL:-30}
    local max_iterations=$((timeout_mins * 60 / interval_secs))
    local iteration=0
    
    # Determine monitoring mode
    local use_jq=true
    if [[ "$NO_JQ" == "true" ]] || ! check_jq; then
        use_jq=false
        log_info "Using basic monitoring mode (without jq)"
    fi
    
    log_info "Monitoring workflows for version: $version"
    log_info "Timeout: ${timeout_mins} minutes, Check interval: ${interval_secs} seconds"
    echo
    
    while [[ $iteration -lt $max_iterations ]]; do
        local all_success=true
        local any_failed=false
        local any_running=false
        
        echo "=========================================="
        echo "Workflow Status Check #$((iteration + 1))"
        echo "=========================================="
        
        for i in "${!REPOS[@]}"; do
            local repo="${REPOS[$i]}"
            local workflow="${WORKFLOWS[$i]}"
            
            if [[ "$use_jq" == "true" ]]; then
                check_workflow_status_jq "$repo" "$workflow" "$version"
            else
                check_workflow_status_basic "$repo" "$workflow" "$version"
            fi
            local result=$?
            
            case $result in
                0)  # Success
                    ;;
                1)  # Failed
                    all_success=false
                    any_failed=true
                    ;;
                2)  # In progress or not started
                    all_success=false
                    any_running=true
                    ;;
            esac
        done
        
        echo
        
        if [[ "$any_failed" == "true" ]]; then
            log_error "Some workflows have failed!"
            return 1
        elif [[ "$all_success" == "true" ]]; then
            log_success "All workflows completed successfully! 🎉"
            return 0
        elif [[ "$any_running" == "true" ]]; then
            log_info "Workflows still running, waiting ${interval_secs} seconds..."
            sleep "$interval_secs"
            ((iteration++))
        fi
    done
    
    log_warning "Timeout reached after ${timeout_mins} minutes"
    log_info "Some workflows may still be running. Check manually:"
    
    for i in "${!REPOS[@]}"; do
        local repo="${REPOS[$i]}"
        echo "  https://github.com/${repo}/actions"
    done
    
    return 2
}

# Show workflow URLs
show_workflow_urls() {
    local version=$1
    
    echo "GitHub Actions Workflow URLs:"
    echo "=============================="
    
    for i in "${!REPOS[@]}"; do
        local repo="${REPOS[$i]}"
        local workflow="${WORKFLOWS[$i]}"
        local repo_name=$(basename "$repo")
        
        echo "$repo_name: https://github.com/${repo}/actions/workflows/${workflow}"
    done
    echo
}

# Main function
main() {
    local version=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -i|--interval)
                INTERVAL="$2"
                shift 2
                ;;
            --show-logs)
                SHOW_LOGS="true"
                shift
                ;;
            --no-jq)
                NO_JQ="true"
                shift
                ;;
            --debug)
                DEBUG="true"
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
    
    if [[ -z "$version" ]]; then
        log_error "Version is required"
        show_help
        exit 1
    fi
    
    # Validate version format
    if [[ ! $version =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9\.-]+)?$ ]]; then
        log_error "Invalid version format: $version"
        exit 1
    fi
    
    check_gh_cli
    show_workflow_urls "$version"
    monitor_workflows "$version"
    
    local result=$?
    
    case $result in
        0)
            log_success "All workflows completed successfully!"
            log_info "You can now run: ./release.sh $version"
            ;;
        1)
            log_error "Some workflows failed. Please check the logs and fix issues."
            ;;
        2)
            log_warning "Monitoring timed out. Check workflows manually."
            ;;
    esac
    
    exit $result
}

main "$@" 
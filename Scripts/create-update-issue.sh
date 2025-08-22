#!/bin/bash

# create-update-issue.sh - GitHub issue creation script for failed formula updates
# This script creates GitHub issues when formula updates fail, providing detailed context and troubleshooting information

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ISSUE_LABELS="bug,homebrew,formula-update,automated"
readonly DEFAULT_ASSIGNEE="beriberikix"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Global variables
WORKFLOW_RUN=""
EVENT_TYPE=""
FAILURE_STAGE=""
VERSION=""
ARCHIVE_URL=""
SHA256=""
ERROR_MESSAGE=""
DRY_RUN=false
VERBOSE=false

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  INFO:${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}✅ SUCCESS:${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $*" >&2
}

log_error() {
    echo -e "${RED}❌ ERROR:${NC} $*" >&2
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}🔍 DEBUG:${NC} $*" >&2
    fi
}

# Usage function
usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Create GitHub issues for failed formula updates with detailed context and troubleshooting information.

REQUIRED OPTIONS:
    --workflow-run URL          GitHub Actions workflow run URL
    --event-type TYPE          Event type (repository_dispatch, workflow_dispatch, etc.)
    --failure-stage STAGE      Stage where failure occurred

OPTIONAL OPTIONS:
    --version VERSION          Release version that failed to update
    --archive-url URL          GitHub source archive URL
    --sha256 CHECKSUM         SHA256 checksum
    --error-message MSG        Specific error message
    --dry-run                 Preview issue content without creating
    --verbose                 Enable verbose output
    --help                    Show this help message

FAILURE STAGES:
    payload-extraction        Failed to extract dispatch payload
    binary-validation        Binary download or validation failed
    formula-update           Formula file update failed
    formula-validation       Updated formula validation failed
    git-operations           Git commit/push operations failed
    workflow-timeout         Workflow exceeded time limits
    dependency-failure       Missing dependencies or tools
    unknown                  Unspecified or unexpected failure

EXAMPLES:
    # Create issue for formula update failure
    $SCRIPT_NAME \\
        --workflow-run "https://github.com/beriberikix/homebrew-usbipd-mac/actions/runs/123456789" \\
        --event-type "repository_dispatch" \\
        --failure-stage "formula-validation" \\
        --version "v1.2.3" \\
        --error-message "Ruby syntax error in formula"

    # Dry run to preview issue content
    $SCRIPT_NAME \\
        --workflow-run "https://github.com/beriberikix/homebrew-usbipd-mac/actions/runs/123456789" \\
        --event-type "repository_dispatch" \\
        --failure-stage "binary-validation" \\
        --dry-run

EXIT CODES:
    0    Success
    1    General error
    2    Invalid arguments
    3    GitHub CLI error
    4    Issue creation failed
EOF
}

# Validate inputs
validate_workflow_url() {
    local url="$1"
    if [[ ! "$url" =~ ^https://github\.com/.+/actions/runs/[0-9]+$ ]]; then
        log_error "Invalid workflow run URL format: $url"
        return 1
    fi
    return 0
}

validate_failure_stage() {
    local stage="$1"
    local valid_stages=(
        "payload-extraction"
        "binary-validation"
        "formula-update"
        "formula-validation"
        "git-operations"
        "workflow-timeout"
        "dependency-failure"
        "unknown"
    )
    
    for valid_stage in "${valid_stages[@]}"; do
        if [[ "$stage" == "$valid_stage" ]]; then
            return 0
        fi
    done
    
    log_error "Invalid failure stage: $stage"
    log_error "Valid stages: ${valid_stages[*]}"
    return 1
}

# Check dependencies
check_dependencies() {
    log_debug "Checking dependencies"
    
    if ! command -v gh >/dev/null 2>&1; then
        log_error "GitHub CLI (gh) is required but not found"
        log_error "Install it from: https://cli.github.com/"
        return 1
    fi
    
    # Check if authenticated
    if ! gh auth status >/dev/null 2>&1; then
        log_error "GitHub CLI is not authenticated"
        log_error "Run: gh auth login"
        return 1
    fi
    
    log_debug "All dependencies found and configured"
    return 0
}

# Generate issue title based on failure stage
generate_issue_title() {
    local stage="$1"
    local version="${2:-unknown}"
    local timestamp=$(date -u +"%Y-%m-%d %H:%M UTC")
    
    case "$stage" in
        "payload-extraction")
            echo "Formula Update Failed: Payload Extraction Error ($version) - $timestamp"
            ;;
        "binary-validation")
            echo "Formula Update Failed: Binary Validation Error ($version) - $timestamp"
            ;;
        "formula-update")
            echo "Formula Update Failed: Formula File Update Error ($version) - $timestamp"
            ;;
        "formula-validation")
            echo "Formula Update Failed: Formula Validation Error ($version) - $timestamp"
            ;;
        "git-operations")
            echo "Formula Update Failed: Git Operations Error ($version) - $timestamp"
            ;;
        "workflow-timeout")
            echo "Formula Update Failed: Workflow Timeout ($version) - $timestamp"
            ;;
        "dependency-failure")
            echo "Formula Update Failed: Dependency Error ($version) - $timestamp"
            ;;
        *)
            echo "Formula Update Failed: Unknown Error ($version) - $timestamp"
            ;;
    esac
}

# Generate troubleshooting section based on failure stage
generate_troubleshooting_section() {
    local stage="$1"
    
    case "$stage" in
        "payload-extraction")
            cat << 'EOF'
## Troubleshooting Steps

### Immediate Actions
1. **Verify dispatch payload format**: Check that the repository dispatch event contains all required fields
2. **Validate JSON structure**: Ensure the client payload is valid JSON with proper escaping
3. **Check event type**: Verify the event type matches `formula_update`

### Investigation Steps
1. Review the workflow logs for the payload extraction step
2. Check the source repository's dispatch sending logic
3. Validate the repository dispatch action configuration
4. Verify the GITHUB_TOKEN permissions for receiving dispatch events

### Prevention
- Add payload validation before sending dispatch events
- Implement payload schema validation in the workflow
- Add retry logic for malformed payloads
EOF
            ;;
        "binary-validation")
            cat << 'EOF'
## Troubleshooting Steps

### Immediate Actions
1. **Check archive accessibility**: Verify the GitHub archive URL is accessible
2. **Validate SHA256 checksum**: Confirm the expected checksum matches the actual archive
3. **Network connectivity**: Ensure the runner can access GitHub's download servers

### Investigation Steps
1. Manually download the archive URL and verify checksum
2. Check if the release exists and is published
3. Verify the metadata generation process in the source repository
4. Review network connectivity and GitHub status

### Prevention
- Add retry logic for network failures
- Implement checksum verification in the source repository
- Add archive accessibility validation before dispatch
- Monitor GitHub's service status
EOF
            ;;
        "formula-update")
            cat << 'EOF'
## Troubleshooting Steps

### Immediate Actions
1. **Check formula file syntax**: Verify the formula file is valid Ruby
2. **Validate update patterns**: Ensure the sed patterns match the formula structure
3. **File permissions**: Confirm write access to the formula file

### Investigation Steps
1. Review the formula file structure and update patterns
2. Check for unexpected formula format changes
3. Validate the backup and restore mechanism
4. Test the update script with known good values

### Prevention
- Add pre-update formula syntax validation
- Implement more robust pattern matching
- Add comprehensive formula structure validation
- Test updates against formula file variations
EOF
            ;;
        "formula-validation")
            cat << 'EOF'
## Troubleshooting Steps

### Immediate Actions
1. **Ruby syntax check**: Run `ruby -c Formula/usbipd-mac.rb` to check syntax
2. **Validate updated values**: Ensure version and SHA256 were correctly updated
3. **Check formula structure**: Verify all required Homebrew formula components

### Investigation Steps
1. Compare the updated formula against the original
2. Check for unreplaced placeholders or malformed substitutions
3. Validate the Ruby syntax and Homebrew formula requirements
4. Review the rollback mechanism if validation failed

### Prevention
- Enhance formula validation with comprehensive checks
- Add pre-validation of substitution patterns
- Implement progressive validation stages
- Add formula linting and structure validation
EOF
            ;;
        "git-operations")
            cat << 'EOF'
## Troubleshooting Steps

### Immediate Actions
1. **Check git status**: Verify repository state and staging area
2. **Validate git configuration**: Ensure user.name and user.email are set
3. **Repository permissions**: Confirm write access to the repository

### Investigation Steps
1. Review git repository status and any uncommitted changes
2. Check for merge conflicts or repository state issues
3. Validate git authentication and permissions
4. Verify branch protection rules and requirements

### Prevention
- Add git repository state validation before operations
- Implement proper error handling for git commands
- Add retry logic for transient git failures
- Validate git configuration before operations
EOF
            ;;
        "workflow-timeout")
            cat << 'EOF'
## Troubleshooting Steps

### Immediate Actions
1. **Check workflow duration**: Review the workflow execution time
2. **Identify bottlenecks**: Determine which step caused the timeout
3. **Resource constraints**: Check for runner resource limitations

### Investigation Steps
1. Analyze workflow logs for performance bottlenecks
2. Review network latency and download speeds
3. Check for resource contention or runner limitations
4. Validate timeout configurations and limits

### Prevention
- Optimize workflow steps for performance
- Add configurable timeout values
- Implement progress monitoring and early termination
- Add resource usage monitoring and alerts
EOF
            ;;
        "dependency-failure")
            cat << 'EOF'
## Troubleshooting Steps

### Immediate Actions
1. **Check tool availability**: Verify all required tools are installed
2. **Version compatibility**: Ensure tool versions meet requirements
3. **Installation process**: Review dependency installation steps

### Investigation Steps
1. Review the dependency installation process
2. Check for version conflicts or compatibility issues
3. Validate package availability and installation sources
4. Test dependency installation in isolation

### Prevention
- Add comprehensive dependency checking
- Implement version pinning for critical tools
- Add fallback installation methods
- Monitor dependency availability and updates
EOF
            ;;
        *)
            cat << 'EOF'
## Troubleshooting Steps

### Immediate Actions
1. **Review workflow logs**: Check the complete workflow execution logs
2. **Identify error stage**: Determine where the failure occurred
3. **Check recent changes**: Review any recent changes to the workflow or scripts

### Investigation Steps
1. Analyze the complete workflow execution
2. Check for environmental changes or updates
3. Review error messages and stack traces
4. Validate the workflow configuration and setup

### Prevention
- Add comprehensive error handling and logging
- Implement better error classification and reporting
- Add monitoring and alerting for workflow failures
- Regular testing of the complete workflow
EOF
            ;;
    esac
}

# Generate recovery actions based on failure stage
generate_recovery_actions() {
    local stage="$1"
    
    case "$stage" in
        "payload-extraction"|"binary-validation"|"workflow-timeout"|"dependency-failure")
            cat << 'EOF'
## Recovery Actions

### Automatic Recovery
- **Workflow Retry**: Re-run the failed workflow after addressing the underlying issue
- **Manual Trigger**: Use workflow_dispatch to manually trigger the formula update

### Manual Recovery
- **Manual Formula Update**: Use the manual update script as a fallback:
  ```bash
  cd /path/to/homebrew-usbipd-mac
  ./Scripts/manual-update.sh --version [VERSION] --verbose
  ```

### Verification
1. Verify the formula update completed successfully
2. Test the updated formula with `brew install --build-from-source usbipd-mac`
3. Confirm the version matches the intended release
EOF
            ;;
        "formula-update"|"formula-validation"|"git-operations")
            cat << 'EOF'
## Recovery Actions

### Automatic Recovery
- **Rollback Applied**: If rollback is enabled, the formula should be restored to the previous version
- **Clean State**: Verify the repository is in a clean state before retry

### Manual Recovery
- **Manual Formula Update**: Use the manual update script with known good values:
  ```bash
  cd /path/to/homebrew-usbipd-mac
  ./Scripts/manual-update.sh --version [VERSION] --verbose
  ```
- **Manual Git Operations**: Complete git operations manually if needed:
  ```bash
  git add Formula/usbipd-mac.rb
  git commit -m "feat: update formula to [VERSION]"
  git push origin main
  ```

### Verification
1. Verify the formula syntax with `ruby -c Formula/usbipd-mac.rb`
2. Test the formula with `brew install --build-from-source usbipd-mac`
3. Confirm git repository state is clean
4. Validate the formula version matches the release
EOF
            ;;
        *)
            cat << 'EOF'
## Recovery Actions

### Investigation Required
- **Manual Review**: Manual investigation and intervention required
- **Log Analysis**: Review complete workflow logs for specific error details

### Manual Recovery
- **Manual Formula Update**: Use the manual update script as a safe fallback:
  ```bash
  cd /path/to/homebrew-usbipd-mac
  ./Scripts/manual-update.sh --version [VERSION] --dry-run  # Preview first
  ./Scripts/manual-update.sh --version [VERSION]           # Apply if preview looks good
  ```

### Contact
- **Maintainer Review**: This failure type may require maintainer intervention
- **Workflow Investigation**: Consider updating the workflow to handle this scenario
EOF
            ;;
    esac
}

# Generate issue body
generate_issue_body() {
    local workflow_run="$1"
    local event_type="$2"
    local failure_stage="$3"
    local version="${4:-unknown}"
    local archive_url="${5:-unknown}"
    local sha256="${6:-unknown}"
    local error_message="${7:-No specific error message provided}"
    
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    local issue_id=$(date +%s)
    
    cat << EOF
<!-- Formula Update Failure Report -->
<!-- Issue ID: $issue_id -->
<!-- Generated automatically by formula update workflow -->

## Formula Update Failure Report

**🔴 FAILURE DETECTED**: The automated formula update process has failed and requires attention.

### Failure Details

| Field | Value |
|-------|--------|
| **Failure Stage** | \`$failure_stage\` |
| **Event Type** | \`$event_type\` |
| **Version** | \`$version\` |
| **Timestamp** | $timestamp |
| **Workflow Run** | [View Logs]($workflow_run) |

### Release Information

| Field | Value |
|-------|--------|
| **Archive URL** | \`$archive_url\` |
| **SHA256** | \`${sha256:0:16}...\` |

### Error Information

\`\`\`
$error_message
\`\`\`

### Impact

- ❌ **Formula Update**: The Homebrew formula was not updated to version \`$version\`
- ❌ **User Installation**: Users cannot install the latest version via Homebrew
- ⚠️ **Manual Intervention**: Manual formula update may be required

$(generate_troubleshooting_section "$failure_stage")

$(generate_recovery_actions "$failure_stage")

### Workflow Information

- **Workflow Run**: [View Full Logs]($workflow_run)
- **Repository**: beriberikix/homebrew-usbipd-mac
- **Event Type**: $event_type
- **Automation**: Repository Dispatch Formula Update

### Next Steps

1. **🔍 Investigate**: Review the workflow logs and error details above
2. **🛠️ Fix**: Address the underlying issue based on troubleshooting steps
3. **🔄 Retry**: Re-run the workflow or use manual recovery
4. **✅ Verify**: Confirm the formula update completes successfully
5. **📝 Document**: Update this issue with resolution details

### Automation Context

This issue was created automatically by the formula update workflow when a failure was detected. The issue contains diagnostic information to help identify and resolve the problem quickly.

- **Created by**: Automated Formula Update Workflow
- **Timestamp**: $timestamp
- **Issue ID**: $issue_id

---

**Note**: This is an automated issue. Please update with resolution details and close when the formula update is successfully completed.
EOF
}

# Create GitHub issue
create_github_issue() {
    local title="$1"
    local body="$2"
    
    log_info "Creating GitHub issue..."
    log_debug "Issue title: $title"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY-RUN: Would create GitHub issue with the following content:"
        echo
        echo "=========================================="
        echo "TITLE: $title"
        echo "=========================================="
        echo
        echo "$body"
        echo
        echo "=========================================="
        echo "LABELS: $ISSUE_LABELS"
        echo "ASSIGNEE: $DEFAULT_ASSIGNEE"
        echo "=========================================="
        log_success "DRY-RUN: Issue preview completed"
        return 0
    fi
    
    # Create temporary file for issue body
    local body_file=$(mktemp)
    echo "$body" > "$body_file"
    
    # Create the issue
    local issue_url
    if issue_url=$(gh issue create \
        --title "$title" \
        --body-file "$body_file" \
        --label "$ISSUE_LABELS" \
        --assignee "$DEFAULT_ASSIGNEE" 2>&1); then
        
        rm -f "$body_file"
        log_success "GitHub issue created successfully"
        log_info "Issue URL: $issue_url"
        echo "$issue_url"
        return 0
    else
        local error_output="$issue_url"
        rm -f "$body_file"
        log_error "Failed to create GitHub issue"
        log_error "Error: $error_output"
        return 4
    fi
}

# Main function
main() {
    local title body
    
    log_info "Starting issue creation process..."
    
    # Check dependencies
    check_dependencies || return 3
    
    # Validate inputs
    validate_workflow_url "$WORKFLOW_RUN" || return 2
    validate_failure_stage "$FAILURE_STAGE" || return 2
    
    # Generate issue content
    title=$(generate_issue_title "$FAILURE_STAGE" "$VERSION")
    body=$(generate_issue_body "$WORKFLOW_RUN" "$EVENT_TYPE" "$FAILURE_STAGE" "$VERSION" "$ARCHIVE_URL" "$SHA256" "$ERROR_MESSAGE")
    
    log_debug "Generated issue title: $title"
    log_debug "Generated issue body length: ${#body} characters"
    
    # Create the issue
    if create_github_issue "$title" "$body"; then
        log_success "Issue creation completed successfully"
        return 0
    else
        log_error "Issue creation failed"
        return 4
    fi
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --workflow-run)
                WORKFLOW_RUN="$2"
                shift 2
                ;;
            --event-type)
                EVENT_TYPE="$2"
                shift 2
                ;;
            --failure-stage)
                FAILURE_STAGE="$2"
                shift 2
                ;;
            --version)
                VERSION="$2"
                shift 2
                ;;
            --archive-url)
                ARCHIVE_URL="$2"
                shift 2
                ;;
            --sha256)
                SHA256="$2"
                shift 2
                ;;
            --error-message)
                ERROR_MESSAGE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 2
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "$WORKFLOW_RUN" ]]; then
        log_error "Missing required argument: --workflow-run"
        exit 2
    fi
    
    if [[ -z "$EVENT_TYPE" ]]; then
        log_error "Missing required argument: --event-type"
        exit 2
    fi
    
    if [[ -z "$FAILURE_STAGE" ]]; then
        log_error "Missing required argument: --failure-stage"
        exit 2
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "================================================================"
    echo "GitHub Issue Creation Script for Formula Update Failures"
    echo "================================================================"
    echo
    
    parse_arguments "$@"
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Configuration:"
        log_info "  • Workflow Run: $WORKFLOW_RUN"
        log_info "  • Event Type: $EVENT_TYPE"
        log_info "  • Failure Stage: $FAILURE_STAGE"
        log_info "  • Version: ${VERSION:-unspecified}"
        log_info "  • Archive URL: ${ARCHIVE_URL:-unspecified}"
        log_info "  • SHA256: ${SHA256:0:16:-unspecified}..."
        log_info "  • Error Message: ${ERROR_MESSAGE:-unspecified}"
        log_info "  • Dry Run: $DRY_RUN"
        echo
    fi
    
    main
    exit_code=$?
    
    echo
    echo "================================================================"
    if [[ $exit_code -eq 0 ]]; then
        log_success "Issue creation process completed successfully!"
    else
        log_error "Issue creation process failed with exit code: $exit_code"
    fi
    echo "================================================================"
    
    exit $exit_code
fi
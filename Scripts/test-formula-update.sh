#!/bin/bash

# test-formula-update.sh
# Validation script for tap repository workflow
# Tests formula update workflow with mock dispatch events

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_TEMP_DIR=""
ORIGINAL_FORMULA=""
TEST_RESULTS=()
EXIT_CODE=0

# Cleanup function
cleanup() {
    if [[ -n "${TEST_TEMP_DIR}" && -d "${TEST_TEMP_DIR}" ]]; then
        rm -rf "${TEST_TEMP_DIR}"
    fi
    
    # Restore original formula if backup exists
    if [[ -n "${ORIGINAL_FORMULA}" && -f "${ORIGINAL_FORMULA}" ]]; then
        local formula_file="${REPO_ROOT}/Formula/usbipd-mac.rb"
        if [[ -f "${formula_file}.test-backup" ]]; then
            mv "${formula_file}.test-backup" "${formula_file}"
            echo -e "${YELLOW}Restored original formula file${NC}"
        fi
    fi
}

trap cleanup EXIT

# Logging functions
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

record_test_result() {
    local test_name="$1"
    local result="$2"
    local details="${3:-}"
    
    TEST_RESULTS+=("${test_name}:${result}:${details}")
    
    if [[ "$result" == "PASS" ]]; then
        log_success "✓ ${test_name}"
    else
        log_error "✗ ${test_name}: ${details}"
        EXIT_CODE=1
    fi
}

# Setup test environment
setup_test_environment() {
    log_info "Setting up test environment..."
    
    TEST_TEMP_DIR=$(mktemp -d)
    log_info "Test directory: ${TEST_TEMP_DIR}"
    
    # Backup original formula
    local formula_file="${REPO_ROOT}/Formula/usbipd-mac.rb"
    if [[ -f "${formula_file}" ]]; then
        cp "${formula_file}" "${formula_file}.test-backup"
        ORIGINAL_FORMULA="${formula_file}"
        log_info "Backed up original formula file"
    else
        log_error "Formula file not found: ${formula_file}"
        exit 1
    fi
    
    # Check required scripts exist
    local required_scripts=(
        "validate-binary.sh"
        "update-formula-from-dispatch.sh"
        "create-update-issue.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "${SCRIPT_DIR}/${script}" ]]; then
            log_error "Required script not found: ${script}"
            exit 1
        fi
    done
    
    log_success "Test environment setup complete"
}

# Create mock dispatch payload
create_mock_payload() {
    local version="$1"
    local binary_url="$2"
    local sha256="$3"
    
    cat > "${TEST_TEMP_DIR}/mock_payload.json" << EOF
{
  "action": "formula_update",
  "client_payload": {
    "version": "${version}",
    "binary_url": "${binary_url}",
    "sha256": "${sha256}",
    "release_notes": "Test release for validation",
    "prerelease": false
  }
}
EOF
}

# Create mock binary for testing
create_mock_binary() {
    local binary_path="$1"
    local content="$2"
    
    mkdir -p "$(dirname "${binary_path}")"
    echo -n "${content}" > "${binary_path}"
}

# Test 1: Valid formula update workflow
test_valid_formula_update() {
    log_info "Testing valid formula update workflow..."
    
    local test_version="v99.99.99"
    local test_content="mock binary content for testing"
    local test_sha256=$(echo -n "${test_content}" | shasum -a 256 | cut -d' ' -f1)
    local test_binary="${TEST_TEMP_DIR}/usbipd-v99.99.99-macos"
    local test_url="file://${test_binary}"
    
    # Create mock binary
    create_mock_binary "${test_binary}" "${test_content}"
    
    # Create mock payload
    create_mock_payload "${test_version}" "${test_url}" "${test_sha256}"
    
    # Test binary validation
    if "${SCRIPT_DIR}/validate-binary.sh" "${test_url}" "${test_sha256}" > "${TEST_TEMP_DIR}/validate.log" 2>&1; then
        record_test_result "Binary validation (valid)" "PASS"
    else
        record_test_result "Binary validation (valid)" "FAIL" "$(cat "${TEST_TEMP_DIR}/validate.log")"
        return
    fi
    
    # Test formula update
    export GITHUB_EVENT_PATH="${TEST_TEMP_DIR}/mock_payload.json"
    if "${SCRIPT_DIR}/update-formula-from-dispatch.sh" > "${TEST_TEMP_DIR}/update.log" 2>&1; then
        record_test_result "Formula update (valid)" "PASS"
        
        # Verify formula was updated
        if grep -q "${test_version}" "${REPO_ROOT}/Formula/usbipd-mac.rb"; then
            record_test_result "Formula version update" "PASS"
        else
            record_test_result "Formula version update" "FAIL" "Version not found in formula"
        fi
        
        if grep -q "${test_sha256}" "${REPO_ROOT}/Formula/usbipd-mac.rb"; then
            record_test_result "Formula SHA256 update" "PASS"
        else
            record_test_result "Formula SHA256 update" "FAIL" "SHA256 not found in formula"
        fi
    else
        record_test_result "Formula update (valid)" "FAIL" "$(cat "${TEST_TEMP_DIR}/update.log")"
    fi
}

# Test 2: Invalid binary checksum
test_invalid_checksum() {
    log_info "Testing invalid binary checksum handling..."
    
    local test_version="v88.88.88"
    local test_content="different content"
    local wrong_sha256="0000000000000000000000000000000000000000000000000000000000000000"
    local test_binary="${TEST_TEMP_DIR}/usbipd-v88.88.88-macos"
    local test_url="file://${test_binary}"
    
    # Create mock binary
    create_mock_binary "${test_binary}" "${test_content}"
    
    # Test binary validation should fail
    if ! "${SCRIPT_DIR}/validate-binary.sh" "${test_url}" "${wrong_sha256}" > "${TEST_TEMP_DIR}/validate_fail.log" 2>&1; then
        record_test_result "Binary validation (invalid checksum)" "PASS"
    else
        record_test_result "Binary validation (invalid checksum)" "FAIL" "Should have failed checksum validation"
    fi
}

# Test 3: Missing binary
test_missing_binary() {
    log_info "Testing missing binary handling..."
    
    local test_url="file://${TEST_TEMP_DIR}/nonexistent-binary"
    local test_sha256="1234567890abcdef"
    
    # Test binary validation should fail
    if ! "${SCRIPT_DIR}/validate-binary.sh" "${test_url}" "${test_sha256}" > "${TEST_TEMP_DIR}/missing.log" 2>&1; then
        record_test_result "Binary validation (missing binary)" "PASS"
    else
        record_test_result "Binary validation (missing binary)" "FAIL" "Should have failed for missing binary"
    fi
}

# Test 4: Malformed payload
test_malformed_payload() {
    log_info "Testing malformed payload handling..."
    
    # Create malformed payload
    cat > "${TEST_TEMP_DIR}/malformed_payload.json" << EOF
{
  "action": "formula_update",
  "client_payload": {
    "version": "invalid version format",
    "binary_url": "not-a-url"
  }
}
EOF
    
    export GITHUB_EVENT_PATH="${TEST_TEMP_DIR}/malformed_payload.json"
    if ! "${SCRIPT_DIR}/update-formula-from-dispatch.sh" > "${TEST_TEMP_DIR}/malformed.log" 2>&1; then
        record_test_result "Formula update (malformed payload)" "PASS"
    else
        record_test_result "Formula update (malformed payload)" "FAIL" "Should have failed for malformed payload"
    fi
}

# Test 5: Formula rollback mechanism
test_formula_rollback() {
    log_info "Testing formula rollback mechanism..."
    
    # Create a scenario that should trigger rollback
    local original_content=$(cat "${REPO_ROOT}/Formula/usbipd-mac.rb")
    
    # Temporarily break the formula update script by creating invalid environment
    export GITHUB_EVENT_PATH="/nonexistent/path"
    
    if ! "${SCRIPT_DIR}/update-formula-from-dispatch.sh" > "${TEST_TEMP_DIR}/rollback.log" 2>&1; then
        # Check if original formula is intact
        local current_content=$(cat "${REPO_ROOT}/Formula/usbipd-mac.rb")
        if [[ "${original_content}" == "${current_content}" ]]; then
            record_test_result "Formula rollback mechanism" "PASS"
        else
            record_test_result "Formula rollback mechanism" "FAIL" "Formula was modified despite failure"
        fi
    else
        record_test_result "Formula rollback mechanism" "FAIL" "Script should have failed with invalid environment"
    fi
}

# Test 6: Ruby syntax validation
test_ruby_syntax_validation() {
    log_info "Testing Ruby syntax validation..."
    
    local formula_file="${REPO_ROOT}/Formula/usbipd-mac.rb"
    
    # Test current formula syntax
    if ruby -c "${formula_file}" > "${TEST_TEMP_DIR}/syntax.log" 2>&1; then
        record_test_result "Ruby syntax validation" "PASS"
    else
        record_test_result "Ruby syntax validation" "FAIL" "$(cat "${TEST_TEMP_DIR}/syntax.log")"
    fi
}

# Test 7: Error handling and issue creation
test_error_handling() {
    log_info "Testing error handling and issue creation..."
    
    # Test issue creation script exists and has executable permissions
    local issue_script="${SCRIPT_DIR}/create-update-issue.sh"
    if [[ -x "${issue_script}" ]]; then
        record_test_result "Issue creation script accessibility" "PASS"
    else
        record_test_result "Issue creation script accessibility" "FAIL" "Script not executable"
    fi
    
    # Test issue creation with mock data (dry run)
    if command -v gh >/dev/null 2>&1; then
        # Only test if gh CLI is available
        export DRY_RUN=true
        if "${issue_script}" "Test error" "validation" "v99.99.99" "Test error details" > "${TEST_TEMP_DIR}/issue.log" 2>&1; then
            record_test_result "Issue creation (dry run)" "PASS"
        else
            record_test_result "Issue creation (dry run)" "FAIL" "$(cat "${TEST_TEMP_DIR}/issue.log")"
        fi
    else
        log_warning "GitHub CLI not available, skipping issue creation test"
        record_test_result "Issue creation (dry run)" "SKIP" "GitHub CLI not available"
    fi
}

# Test 8: GitHub Actions workflow file validation
test_workflow_validation() {
    log_info "Testing GitHub Actions workflow file validation..."
    
    local workflow_file="${REPO_ROOT}/.github/workflows/formula-update.yml"
    if [[ -f "${workflow_file}" ]]; then
        # Basic YAML syntax check
        if command -v yamllint >/dev/null 2>&1; then
            if yamllint "${workflow_file}" > "${TEST_TEMP_DIR}/workflow.log" 2>&1; then
                record_test_result "Workflow YAML syntax" "PASS"
            else
                record_test_result "Workflow YAML syntax" "FAIL" "$(cat "${TEST_TEMP_DIR}/workflow.log")"
            fi
        else
            log_warning "yamllint not available, skipping YAML validation"
            record_test_result "Workflow YAML syntax" "SKIP" "yamllint not available"
        fi
        
        # Check for required triggers
        if grep -q "repository_dispatch" "${workflow_file}"; then
            record_test_result "Workflow repository_dispatch trigger" "PASS"
        else
            record_test_result "Workflow repository_dispatch trigger" "FAIL" "Missing repository_dispatch trigger"
        fi
        
        # Check for formula_update event type
        if grep -q "formula_update" "${workflow_file}"; then
            record_test_result "Workflow formula_update event type" "PASS"
        else
            record_test_result "Workflow formula_update event type" "FAIL" "Missing formula_update event type"
        fi
    else
        record_test_result "Workflow file existence" "FAIL" "Workflow file not found"
    fi
}

# Generate test report
generate_test_report() {
    log_info "Generating test report..."
    
    local report_file="${TEST_TEMP_DIR}/test_report.txt"
    local passed=0
    local failed=0
    local skipped=0
    
    {
        echo "========================================="
        echo "Tap Repository Workflow Validation Report"
        echo "========================================="
        echo "Generated: $(date)"
        echo "Repository: ${REPO_ROOT}"
        echo ""
        echo "Test Results:"
        echo "-------------"
        
        for result in "${TEST_RESULTS[@]}"; do
            IFS=':' read -r test_name status details <<< "$result"
            case "$status" in
                "PASS") 
                    echo "✓ ${test_name}"
                    ((passed++))
                    ;;
                "FAIL") 
                    echo "✗ ${test_name}: ${details}"
                    ((failed++))
                    ;;
                "SKIP") 
                    echo "- ${test_name}: ${details}"
                    ((skipped++))
                    ;;
            esac
        done
        
        echo ""
        echo "Summary:"
        echo "--------"
        echo "Total tests: $((passed + failed + skipped))"
        echo "Passed: ${passed}"
        echo "Failed: ${failed}"
        echo "Skipped: ${skipped}"
        echo ""
        
        if [[ ${failed} -eq 0 ]]; then
            echo "🎉 All tests passed! The tap repository workflow is ready for production."
        else
            echo "❌ ${failed} test(s) failed. Please review and fix issues before deploying."
        fi
    } | tee "${report_file}"
    
    # Copy report to repository root for persistence
    cp "${report_file}" "${REPO_ROOT}/tap-workflow-test-report.txt"
    log_info "Test report saved to: ${REPO_ROOT}/tap-workflow-test-report.txt"
}

# Main execution
main() {
    echo "========================================="
    echo "Tap Repository Workflow Validation"
    echo "========================================="
    echo ""
    
    setup_test_environment
    
    # Run all tests
    test_valid_formula_update
    test_invalid_checksum
    test_missing_binary
    test_malformed_payload
    test_formula_rollback
    test_ruby_syntax_validation
    test_error_handling
    test_workflow_validation
    
    # Generate report
    generate_test_report
    
    echo ""
    if [[ ${EXIT_CODE} -eq 0 ]]; then
        log_success "All tests completed successfully!"
    else
        log_error "Some tests failed. Check the report for details."
    fi
    
    exit ${EXIT_CODE}
}

# Handle command line arguments
case "${1:-}" in
    "--help"|"-h")
        echo "Usage: $0 [--help]"
        echo ""
        echo "Validates the tap repository workflow by testing:"
        echo "  - Formula update process with mock dispatch events"
        echo "  - Binary download and checksum verification"
        echo "  - Error handling and rollback mechanisms"
        echo "  - GitHub Actions workflow configuration"
        echo ""
        echo "Options:"
        echo "  --help, -h    Show this help message"
        exit 0
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
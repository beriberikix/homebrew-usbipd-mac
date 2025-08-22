#!/bin/bash

# validate-binary.sh - Binary download and validation script for Homebrew formula updates
# This script downloads and validates release binaries before formula updates

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEMP_DIR=$(mktemp -d)
readonly MAX_RETRIES=3
readonly TIMEOUT_SECONDS=300
readonly MAX_FILE_SIZE_MB=100

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Global variables
ARCHIVE_URL=""
EXPECTED_SHA256=""
VERBOSE=false
DRY_RUN=false
OUTPUT_FILE=""

# Cleanup function
cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Trap cleanup on exit
trap cleanup EXIT

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $*" >&2
    fi
}

# Usage function
usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Binary download and validation script for Homebrew formula updates.

OPTIONS:
    --archive-url URL       GitHub source archive URL to validate
    --expected-sha256 HASH  Expected SHA256 checksum
    --output-file FILE      Save downloaded file to specific path
    --verbose               Enable verbose output
    --dry-run              Perform validation without downloading
    --help                 Show this help message

EXAMPLES:
    # Validate a release archive
    $SCRIPT_NAME \\
        --archive-url "https://github.com/beriberikix/usbipd-mac/archive/v1.2.3.tar.gz" \\
        --expected-sha256 "abc123..." \\
        --verbose

    # Dry run validation (URL format checking only)
    $SCRIPT_NAME \\
        --archive-url "https://github.com/beriberikix/usbipd-mac/archive/v1.2.3.tar.gz" \\
        --expected-sha256 "abc123..." \\
        --dry-run

ENVIRONMENT VARIABLES:
    VALIDATE_BINARY_TIMEOUT    Download timeout in seconds (default: 300)
    VALIDATE_BINARY_MAX_SIZE   Maximum file size in MB (default: 100)
    VALIDATE_BINARY_RETRIES    Maximum retry attempts (default: 3)

EXIT CODES:
    0    Success
    1    General error
    2    Invalid arguments
    3    Download failed
    4    Validation failed
    5    Security check failed
EOF
}

# Validate URL format
validate_url() {
    local url="$1"
    
    log_verbose "Validating URL format: $url"
    
    # Check if URL is from GitHub
    if [[ ! "$url" =~ ^https://github\.com/.+/archive/.+\.tar\.gz$ ]]; then
        log_error "Invalid URL format. Must be a GitHub archive URL."
        log_error "Expected format: https://github.com/owner/repo/archive/version.tar.gz"
        return 1
    fi
    
    # Extract components
    local repo_path
    repo_path=$(echo "$url" | sed 's|https://github.com/||' | sed 's|/archive/.*||')
    local archive_name
    archive_name=$(echo "$url" | sed 's|.*/archive/||')
    
    log_verbose "Repository path: $repo_path"
    log_verbose "Archive name: $archive_name"
    
    # Validate repository path format
    if [[ ! "$repo_path" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
        log_error "Invalid repository path format: $repo_path"
        return 1
    fi
    
    # Validate archive name format
    if [[ ! "$archive_name" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+.*\.tar\.gz$ ]]; then
        log_error "Invalid archive name format: $archive_name"
        return 1
    fi
    
    log_success "URL format validation passed"
    return 0
}

# Validate SHA256 format
validate_sha256() {
    local sha256="$1"
    
    log_verbose "Validating SHA256 format: ${sha256:0:16}..."
    
    if [[ ! "$sha256" =~ ^[a-fA-F0-9]{64}$ ]]; then
        log_error "Invalid SHA256 format. Must be 64 hexadecimal characters."
        return 1
    fi
    
    log_success "SHA256 format validation passed"
    return 0
}

# Download file with retry logic
download_with_retry() {
    local url="$1"
    local output_path="$2"
    local attempt=1
    
    log_info "Downloading archive from: $url"
    log_verbose "Output path: $output_path"
    log_verbose "Max retries: $MAX_RETRIES"
    log_verbose "Timeout: ${TIMEOUT_SECONDS}s"
    
    while [[ $attempt -le $MAX_RETRIES ]]; do
        log_verbose "Download attempt $attempt/$MAX_RETRIES"
        
        if curl -fsSL \
            --max-time "$TIMEOUT_SECONDS" \
            --connect-timeout 30 \
            --retry 2 \
            --retry-delay 5 \
            --retry-max-time 60 \
            --user-agent "homebrew-usbipd-mac-validator/1.0" \
            --output "$output_path" \
            "$url"; then
            
            log_success "Download completed successfully"
            return 0
        else
            log_warning "Download attempt $attempt failed"
            if [[ $attempt -eq $MAX_RETRIES ]]; then
                log_error "All download attempts failed"
                return 3
            fi
            
            # Wait before retry with exponential backoff
            local wait_time=$((2 ** attempt))
            log_verbose "Waiting ${wait_time}s before retry..."
            sleep "$wait_time"
        fi
        
        ((attempt++))
    done
    
    return 3
}

# Validate file size
validate_file_size() {
    local file_path="$1"
    local max_size_bytes=$((MAX_FILE_SIZE_MB * 1024 * 1024))
    
    if [[ ! -f "$file_path" ]]; then
        log_error "File not found: $file_path"
        return 1
    fi
    
    local file_size
    file_size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null)
    
    log_verbose "File size: $file_size bytes"
    log_verbose "Maximum allowed size: $max_size_bytes bytes"
    
    if [[ $file_size -gt $max_size_bytes ]]; then
        log_error "File size ($file_size bytes) exceeds maximum allowed size ($max_size_bytes bytes)"
        return 4
    fi
    
    log_success "File size validation passed"
    return 0
}

# Verify SHA256 checksum
verify_checksum() {
    local file_path="$1"
    local expected_sha256="$2"
    
    log_info "Verifying SHA256 checksum..."
    log_verbose "Expected: $expected_sha256"
    
    local actual_sha256
    if command -v shasum >/dev/null 2>&1; then
        actual_sha256=$(shasum -a 256 "$file_path" | cut -d' ' -f1)
    elif command -v sha256sum >/dev/null 2>&1; then
        actual_sha256=$(sha256sum "$file_path" | cut -d' ' -f1)
    else
        log_error "No SHA256 utility found (shasum or sha256sum required)"
        return 4
    fi
    
    log_verbose "Actual:   $actual_sha256"
    
    if [[ "$actual_sha256" != "$expected_sha256" ]]; then
        log_error "SHA256 checksum mismatch!"
        log_error "Expected: $expected_sha256"
        log_error "Actual:   $actual_sha256"
        return 4
    fi
    
    log_success "SHA256 checksum verification passed"
    return 0
}

# Basic security checks
perform_security_checks() {
    local file_path="$1"
    
    log_info "Performing basic security checks..."
    
    # Check file type
    local file_type
    if command -v file >/dev/null 2>&1; then
        file_type=$(file "$file_path")
        log_verbose "File type: $file_type"
        
        # Ensure it's a gzip archive
        if [[ ! "$file_type" =~ (gzip|tar) ]]; then
            log_warning "File does not appear to be a gzip/tar archive: $file_type"
        fi
    else
        log_verbose "file command not available, skipping file type check"
    fi
    
    # Check for suspicious file sizes (too small could indicate placeholder files)
    local file_size
    file_size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null)
    
    if [[ $file_size -lt 1024 ]]; then
        log_warning "File is very small ($file_size bytes), may be a placeholder"
    fi
    
    log_success "Basic security checks completed"
    return 0
}

# Main validation function
validate_binary() {
    local download_path="$TEMP_DIR/archive.tar.gz"
    
    # Pre-download validation
    log_info "Starting binary validation process..."
    
    validate_url "$ARCHIVE_URL" || return 2
    validate_sha256 "$EXPECTED_SHA256" || return 2
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_success "Dry run completed - URL and SHA256 format validation passed"
        return 0
    fi
    
    # Download the file
    download_with_retry "$ARCHIVE_URL" "$download_path" || return 3
    
    # Post-download validation
    validate_file_size "$download_path" || return 4
    verify_checksum "$download_path" "$EXPECTED_SHA256" || return 4
    perform_security_checks "$download_path" || return 5
    
    # Copy to output file if specified
    if [[ -n "$OUTPUT_FILE" ]]; then
        log_info "Copying validated file to: $OUTPUT_FILE"
        cp "$download_path" "$OUTPUT_FILE"
        log_success "File copied successfully"
    fi
    
    log_success "Binary validation completed successfully"
    return 0
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --archive-url)
                ARCHIVE_URL="$2"
                shift 2
                ;;
            --expected-sha256)
                EXPECTED_SHA256="$2"
                shift 2
                ;;
            --output-file)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
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
    if [[ -z "$ARCHIVE_URL" ]]; then
        log_error "Missing required argument: --archive-url"
        exit 2
    fi
    
    if [[ -z "$EXPECTED_SHA256" ]]; then
        log_error "Missing required argument: --expected-sha256"
        exit 2
    fi
}

# Apply environment variable overrides
apply_env_overrides() {
    if [[ -n "${VALIDATE_BINARY_TIMEOUT:-}" ]]; then
        readonly TIMEOUT_SECONDS="$VALIDATE_BINARY_TIMEOUT"
        log_verbose "Using custom timeout: ${TIMEOUT_SECONDS}s"
    fi
    
    if [[ -n "${VALIDATE_BINARY_MAX_SIZE:-}" ]]; then
        readonly MAX_FILE_SIZE_MB="$VALIDATE_BINARY_MAX_SIZE"
        log_verbose "Using custom max file size: ${MAX_FILE_SIZE_MB}MB"
    fi
    
    if [[ -n "${VALIDATE_BINARY_RETRIES:-}" ]]; then
        readonly MAX_RETRIES="$VALIDATE_BINARY_RETRIES"
        log_verbose "Using custom max retries: $MAX_RETRIES"
    fi
}

# Main function
main() {
    log_info "Binary validation script starting..."
    
    parse_arguments "$@"
    apply_env_overrides
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_verbose "Configuration:"
        log_verbose "  Archive URL: $ARCHIVE_URL"
        log_verbose "  Expected SHA256: ${EXPECTED_SHA256:0:16}..."
        log_verbose "  Output file: ${OUTPUT_FILE:-"(none)"}"
        log_verbose "  Verbose mode: $VERBOSE"
        log_verbose "  Dry run: $DRY_RUN"
        log_verbose "  Timeout: ${TIMEOUT_SECONDS}s"
        log_verbose "  Max file size: ${MAX_FILE_SIZE_MB}MB"
        log_verbose "  Max retries: $MAX_RETRIES"
    fi
    
    validate_binary
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "Binary validation completed successfully!"
    else
        log_error "Binary validation failed with exit code: $exit_code"
    fi
    
    exit $exit_code
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
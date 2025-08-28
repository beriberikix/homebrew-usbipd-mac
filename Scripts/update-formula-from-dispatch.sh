#!/bin/bash

# update-formula-from-dispatch.sh - Formula update script for repository dispatch events
# This script processes repository dispatch payloads and updates Homebrew formula files
#
# NOTE: This script focuses on basic formula updates. For updates that need to preserve
# or add shell completion functionality, use update-formula-with-completions.sh instead.

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly FORMULA_FILE="Formula/usbip.rb"
readonly BACKUP_SUFFIX=".backup"
readonly TEMP_DIR=$(mktemp -d)

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Global variables
VERSION=""
BINARY_URL=""
SHA256=""
DRY_RUN=false
VERBOSE=false
SKIP_COMMIT=false
ROLLBACK_ON_FAILURE=true

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
    echo -e "${BLUE}ℹ️  INFO:${NC} $@" >&2
}

log_success() {
    echo -e "${GREEN}✅ SUCCESS:${NC} $@" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $@" >&2
}

log_error() {
    echo -e "${RED}❌ ERROR:${NC} $@" >&2
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${PURPLE}🔍 DEBUG:${NC} $@" >&2
    fi
}

log_step() {
    echo -e "${CYAN}🔄 STEP:${NC} $@" >&2
}

# Usage function
usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Formula update script for processing repository dispatch events.

OPTIONS:
    --version VERSION       Release version (e.g., v1.2.3)
    --binary-url URL        GitHub binary download URL
    --sha256 CHECKSUM      SHA256 checksum of the archive
    --dry-run              Preview changes without modifying files
    --skip-commit          Skip git commit after formula update
    --no-rollback          Don't rollback on validation failure
    --verbose              Enable verbose output
    --help                 Show this help message

EXAMPLES:
    # Update formula from dispatch payload
    $SCRIPT_NAME \
        --version "v1.2.3" \
        --binary-url "https://github.com/beriberikix/usbipd-mac/releases/download/v1.2.3/usbipd-v1.2.3-macos" \
        --sha256 "abc123..."

    # Dry run to preview changes
    $SCRIPT_NAME \
        --version "v1.2.3" \
        --binary-url "https://github.com/beriberikix/usbipd-mac/releases/download/v1.2.3/usbipd-v1.2.3-macos" \
        --sha256 "abc123..." \
        --dry-run

EXIT CODES:
    0    Success
    1    General error
    2    Invalid arguments
    3    Validation failed
    4    Formula update failed
    5    Git operations failed
EOF
}

# Validate inputs
validate_version() {
    local version="$1"
    if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$ ]]; then
        log_error "Invalid version format: $version"
        log_error "Version must follow semantic versioning (vX.Y.Z or vX.Y.Z-suffix)"
        return 1
    fi
    return 0
}

validate_binary_url() {
    local url="$1"
    if [[ ! "$url" =~ ^https://github\.com/.+/releases/download/.+/.+ ]]; then
        log_error "Invalid binary URL format: $url"
        log_error "Must be a GitHub binary download URL"
        return 1
    fi
    return 0
}

validate_sha256() {
    local sha256="$1"
    if [[ ! "$sha256" =~ ^[a-fA-F0-9]{64}$ ]]; then
        log_error "Invalid SHA256 format: $sha256"
        log_error "Must be 64 hexadecimal characters"
        return 1
    fi
    return 0
}

# Check dependencies
check_dependencies() {
    log_step "Checking dependencies"
    
    local missing_deps=()
    local required_tools=("git" "ruby" "sed" "grep")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_deps+=("$tool")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        return 1
    fi
    
    log_success "All dependencies found"
    return 0
}

# Backup formula file
create_backup() {
    local formula_file="$1"
    local backup_file="$formula_file$BACKUP_SUFFIX"
    
    log_step "Creating backup of formula file"
    
    if [[ ! -f "$formula_file" ]]; then
        log_error "Formula file not found: $formula_file"
        return 1
    fi
    
    cp "$formula_file" "$backup_file"
    log_success "Backup created: $backup_file"
    return 0
}

# Update formula file
update_formula_file() {
    local formula_file="$1"
    local version="$2"
    local archive_url="$3"
    local sha256="$4"
    local dry_run="$5"
    
    if [[ "$dry_run" == "true" ]]; then
        log_step "Previewing formula changes (dry-run mode)"
    else
        log_step "Updating formula file"
    fi
    
    # Validate formula file exists
    if [[ ! -f "$formula_file" ]]; then
        log_error "Formula file not found: $formula_file"
        return 1
    fi
    
    log_info "Formula update details:"
    log_info "  • Version: $version"
    log_info "  • Binary URL: $archive_url"
    log_info "  • SHA256: ${sha256:0:16}..."
    
    if [[ "$dry_run" == "true" ]]; then
        # Create temporary file for preview
        local temp_formula="$TEMP_DIR/formula-preview.rb"
        cp "$formula_file" "$temp_formula"
        
        # Apply substitutions to temp file - use more flexible patterns
        sed -i.bak -E "s|/releases/download/v[0-9.]+(-[^/]*)?/usbipd-v[0-9.]+(-[^\"]*)?-macos|/releases/download/$version/usbipd-$version-macos|g" "$temp_formula"
        sed -i.bak -E "s|/releases/download/v[0-9.]+(-[^/]*)?/USBIPDSystemExtension\.systemextension\.tar\.gz|/releases/download/$version/USBIPDSystemExtension.systemextension.tar.gz|g" "$temp_formula"
        sed -i.bak -E "s|version \"[0-9.]+(-[^\"]*)?\"| version \"${version#v}\"|g" "$temp_formula"
        # Download checksums for system extension SHA256
        CHECKSUMS_URL="https://github.com/beriberikix/usbipd-mac/releases/download/$version/checksums-${version}.sha256"
        if CHECKSUMS_CONTENT=$(curl -sL "$CHECKSUMS_URL" 2>/dev/null); then
            SYSEXT_SHA256=$(echo "$CHECKSUMS_CONTENT" | grep "USBIPDSystemExtension.systemextension.tar.gz" | cut -d' ' -f1)
            if [[ -n "$SYSEXT_SHA256" && "$SYSEXT_SHA256" =~ ^[a-f0-9]{64}$ ]]; then
                # Update both checksums in preview with specific targeting
                sed -i.bak "/^[[:space:]]*url /,/^[[:space:]]*sha256 / { /^[[:space:]]*sha256 / s/sha256 \"[a-f0-9]\{64\}\"/sha256 \"$sha256\"/; }" "$temp_formula"
                sed -i.bak "/resource \"systemextension\"/,/end/ { /sha256/ s/sha256 \"[a-f0-9]\{64\}\"/sha256 \"$SYSEXT_SHA256\"/; }" "$temp_formula"
            else
                sed -i.bak "0,/sha256 \"[a-f0-9]\{64\}\"/s//sha256 \"$sha256\"/" "$temp_formula"
            fi
        else
            sed -i.bak "0,/sha256 \"[a-f0-9]\{64\}\"/s//sha256 \"$sha256\"/" "$temp_formula"
        fi
        sed -i.bak -E "s|bin.install \"usbipd-v[0-9.]+(-[^\"]*)?-macos\"|bin.install \"usbipd-$version-macos\"|g" "$temp_formula"
        
        # Show differences
        log_info "DRY-RUN: Would make the following changes:"
        echo
        echo "--- Current Formula (relevant lines) ---"
        grep -E "(version|sha256|url)" "$formula_file" | head -5 || echo "No matching lines found"
        echo
        echo "--- Proposed Changes (relevant lines) ---"
        grep -E "(version|sha256|url)" "$temp_formula" | head -5 || echo "No matching lines found"
        echo
        
        log_success "DRY-RUN: Preview completed. No files were modified."
        return 0
    fi
    
    # Create backup before modifying
    create_backup "$formula_file" || return 1
    
    # Apply actual updates to formula file
    log_debug "Applying formula updates"
    
    # Update version in binary download URL - use more flexible patterns
    sed -i.tmp -E "s|/releases/download/v[0-9.]+(-[^/]*)?/usbipd-v[0-9.]+(-[^\"]*)?-macos|/releases/download/$version/usbipd-$version-macos|g" "$formula_file"
    
    # Update system extension URL
    sed -i.tmp -E "s|/releases/download/v[0-9.]+(-[^/]*)?/USBIPDSystemExtension\.systemextension\.tar\.gz|/releases/download/$version/USBIPDSystemExtension.systemextension.tar.gz|g" "$formula_file"
    
    # Update version field (remove 'v' prefix for Homebrew)
    sed -i.tmp -E "s|version \"[0-9.]+(-[^\"]*)?\"| version \"${version#v}\"|g" "$formula_file"
    
    # Download checksums and extract system extension SHA256
    CHECKSUMS_URL="https://github.com/beriberikix/usbipd-mac/releases/download/$version/checksums-${version}.sha256"
    log_debug "Downloading checksums from: $CHECKSUMS_URL"
    
    if CHECKSUMS_CONTENT=$(curl -sL "$CHECKSUMS_URL"); then
        SYSEXT_SHA256=$(echo "$CHECKSUMS_CONTENT" | grep "USBIPDSystemExtension.systemextension.tar.gz" | cut -d' ' -f1)
        log_debug "Found system extension SHA256: $SYSEXT_SHA256"
        
        if [[ -n "$SYSEXT_SHA256" && "$SYSEXT_SHA256" =~ ^[a-f0-9]{64}$ ]]; then
            # Update main binary checksum (outside of resource block)
            sed -i.tmp "/^[[:space:]]*url /,/^[[:space:]]*sha256 / { /^[[:space:]]*sha256 / s/sha256 \"[a-f0-9]\{64\}\"/sha256 \"$sha256\"/; }" "$formula_file"
            # Update system extension checksum (inside resource block)  
            sed -i.tmp "/resource \"systemextension\"/,/end/ { /sha256/ s/sha256 \"[a-f0-9]\{64\}\"/sha256 \"$SYSEXT_SHA256\"/; }" "$formula_file"
            log_debug "Updated both main binary and system extension checksums"
        else
            log_warning "Invalid or missing system extension SHA256, updating only main binary checksum"
            # Update only the main binary checksum (first occurrence)
            sed -i.tmp "0,/sha256 \"[a-f0-9]\{64\}\"/s//sha256 \"$sha256\"/" "$formula_file"
        fi
    else
        log_warning "Failed to download checksums file, updating only main binary checksum"
        sed -i.tmp "s|sha256 \"[a-f0-9]\{64\}\"|sha256 \"$sha256\"|g" "$formula_file"
    fi
    
    # Update binary filename in install section
    sed -i.tmp -E "s|bin.install \"usbipd-v[0-9.]+(-[^\"]*)?-macos\"|bin.install \"usbipd-$version-macos\"|g" "$formula_file"
    
    # Clean up temporary files
    rm -f "$formula_file.tmp"
    
    log_success "Formula file updated successfully"
    return 0
}

# Validate updated formula
validate_formula() {
    local formula_file="$1"
    local expected_version="$2"
    local expected_sha256="$3"
    
    log_step "Validating updated formula"
    
    local validation_errors=0
    
    # Ruby syntax validation
    log_debug "Validating Ruby syntax"
    if ruby -c "$formula_file" >/dev/null 2>&1; then
        log_success "Ruby syntax is valid"
    else
        log_error "Formula has Ruby syntax errors:"
        ruby -c "$formula_file" 2>&1 | sed 's/^/  /'
        ((validation_errors++))
    fi
    
    # Check for required components
    log_debug "Validating formula structure"
    
    local required_patterns=(
        "class.*Formula"
        "desc.*\""
        "homepage.*\""
        "url.*\""
        "version.*\""
        "sha256.*\""
        "def install"
    )
    
    local pattern_names=(
        "Formula class definition"
        "Description field"
        "Homepage field"
        "URL field"
        "Version field"
        "SHA256 field"
        "Install method"
    )
    
    for i in "${!required_patterns[@]}"; do
        local pattern="${required_patterns[i]}"
        local name="${pattern_names[i]}"
        if grep -q "$pattern" "$formula_file"; then
            log_debug "✓ Found: $name"
        else
            log_error "✗ Missing: $name"
            ((validation_errors++))
        fi
    done
    
    # Verify updated values
    log_debug "Verifying formula content updates"
    
    # Check for version without 'v' prefix (Homebrew format)
    local expected_version_clean="${expected_version#v}"
    if grep -q "version \"$expected_version_clean\"" "$formula_file"; then
        log_debug "✓ Version $expected_version_clean found in formula"
    else
        log_error "✗ Version $expected_version_clean not found in updated formula"
        ((validation_errors++))
    fi
    
    if grep -q "sha256 \"$expected_sha256\"" "$formula_file"; then
        log_debug "✓ SHA256 checksum found in formula"
    else
        log_error "✗ SHA256 checksum not found in updated formula"
        ((validation_errors++))
    fi
    
    if grep -q "releases/download/$expected_version/usbipd-$expected_version-macos" "$formula_file"; then
        log_debug "✓ Binary URL with version $expected_version found"
    else
        log_error "✗ Binary URL with version $expected_version not found"
        ((validation_errors++))
    fi
    
    # Check for unreplaced placeholders
    log_debug "Checking for unreplaced placeholders"
    local placeholders=(
        "VERSION_PLACEHOLDER"
        "SHA256_PLACEHOLDER"
        "{{VERSION}}"
        "{{SHA256}}"
        "{{CHECKSUM}}"
    )
    
    local placeholders_found=false
    for placeholder in "${placeholders[@]}"; do
        if grep -q "$placeholder" "$formula_file"; then
            log_warning "Found unreplaced placeholder: $placeholder"
            ((validation_errors++))
            placeholders_found=true
        fi
    done
    
    if [[ $validation_errors -gt 0 ]]; then
        log_error "Formula validation failed with $validation_errors error(s)"
        
        # Rollback on validation failure if enabled
        if [[ "$ROLLBACK_ON_FAILURE" == "true" ]]; then
            local backup_file="$formula_file$BACKUP_SUFFIX"
            if [[ -f "$backup_file" ]]; then
                log_warning "Rolling back formula due to validation failure"
                cp "$backup_file" "$formula_file"
                log_success "Formula rolled back to previous version"
            fi
        fi
        
        return 3
    fi
    
    log_success "Formula validation passed"
    return 0
}

# Git operations
commit_changes() {
    local formula_file="$1"
    local version="$2"
    local skip_commit="$3"
    
    if [[ "$skip_commit" == "true" ]]; then
        log_info "Skipping git commit (--skip-commit specified)"
        return 0
    fi
    
    log_step "Committing changes to git repository"
    
    # Check if there are changes to commit
    if git diff --quiet "$formula_file"; then
        log_warning "No changes detected in formula file"
        return 0
    fi
    
    # Configure git if needed
    if [[ -z "$(git config user.name 2>/dev/null || true)" ]]; then
        git config user.name "github-actions[bot]"
        git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
        log_debug "Configured git user for commit"
    fi
    
    # Add formula file to staging
    git add "$formula_file"
    log_debug "Added $formula_file to git staging area"
    
    # Create commit
    local commit_message="feat: update formula to $version

Automated formula update from repository dispatch event.
- Updated version to $version
- Updated SHA256 checksum
- Updated binary download URL

🤖 Generated with repository dispatch workflow"
    
    if git commit -m "$commit_message"; then
        log_success "Changes committed successfully"
        log_info "Commit message: feat: update formula to $version"
        
        # Push changes to remote repository
        log_debug "Pushing changes to remote repository..."
        if git push origin main; then
            log_success "Changes pushed to remote repository"
            return 0
        else
            log_error "Failed to push changes to remote repository"
            log_error "Commit was created locally but not pushed"
            return 6
        fi
    else
        log_error "Failed to commit changes"
        return 5
    fi
}

# Main update function
update_formula() {
    log_info "Starting formula update process..."
    
    # Validate inputs
    validate_version "$VERSION" || return 2
    validate_binary_url "$BINARY_URL" || return 2
    validate_sha256 "$SHA256" || return 2
    
    # Check dependencies
    check_dependencies || return 1
    
    # Display configuration
    log_info "Configuration:"
    log_info "  • Version: $VERSION"
    log_info "  • Binary URL: $BINARY_URL"
    log_info "  • SHA256: ${SHA256:0:16}..."
    log_info "  • Formula file: $FORMULA_FILE"
    log_info "  • Dry run: $DRY_RUN"
    log_info "  • Skip commit: $SKIP_COMMIT"
    log_info "  • Rollback on failure: $ROLLBACK_ON_FAILURE"
    echo
    
    # Update the formula
    if ! update_formula_file "$FORMULA_FILE" "$VERSION" "$BINARY_URL" "$SHA256" "$DRY_RUN"; then
        log_error "Formula update failed"
        return 4
    fi
    
    # Skip validation and commit for dry runs
    if [[ "$DRY_RUN" == "true" ]]; then
        log_success "Dry run completed successfully"
        return 0
    fi
    
    # Validate the updated formula
    if ! validate_formula "$FORMULA_FILE" "$VERSION" "$SHA256"; then
        log_error "Formula validation failed"
        return 3
    fi
    
    # Commit changes
    if ! commit_changes "$FORMULA_FILE" "$VERSION" "$SKIP_COMMIT"; then
        log_error "Git commit failed"
        return 5
    fi
    
    log_success "Formula update completed successfully!"
    log_info "✅ Summary:"
    log_info "  • Formula updated to $VERSION"
    log_info "  • Validation passed"
    if [[ "$SKIP_COMMIT" != "true" ]]; then
        log_info "  • Changes committed to repository"
    fi
    log_info "  • Backup created: $FORMULA_FILE$BACKUP_SUFFIX"
    
    return 0
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                VERSION="$2"
                shift 2
                ;; 
            --binary-url)
                BINARY_URL="$2"
                shift 2
                ;; 
            --sha256)
                SHA256="$2"
                shift 2
                ;; 
            --dry-run)
                DRY_RUN=true
                shift
                ;; 
            --skip-commit)
                SKIP_COMMIT=true
                shift
                ;; 
            --no-rollback)
                ROLLBACK_ON_FAILURE=false
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
    if [[ -z "$VERSION" ]]; then
        log_error "Missing required argument: --version"
        exit 2
    fi
    
    if [[ -z "$BINARY_URL" ]]; then
        log_error "Missing required argument: --binary-url"
        exit 2
    fi
    
    if [[ -z "$SHA256" ]]; then
        log_error "Missing required argument: --sha256"
        exit 2
    fi
}

# Error handler
handle_error() {
    local exit_code=$?
    local line_number=$1
    
    log_error "Script failed on line $line_number with exit code $exit_code"
    
    # Attempt to rollback formula file if a backup exists
    local formula_file="/Users/jberi/code/homebrew-usbipd-mac/Formula/usbip.rb" # Use absolute path for consistency
    local backup_file="${formula_file}${BACKUP_SUFFIX}"
    if [[ -f "${backup_file}" ]]; then
        log_warning "Attempting to restore formula from backup: ${backup_file}"
        cp "${backup_file}" "${formula_file}"
        log_success "Formula restored from backup."
    fi

    # Clean up any staged git changes
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        if ! git diff --quiet --exit-code; then
            log_warning "Uncommitted changes detected. Attempting to reset git repository."
            git reset --hard HEAD
            git clean -fd
            log_success "Git repository reset to clean state."
        fi
    fi
    
    echo
    echo "🛠️ Troubleshooting:"
    echo "  • Check the formula file syntax with: ruby -c $FORMULA_FILE"
    echo "  • Verify git repository status with: git status"
    echo "  • Review backup file if available: $FORMULA_FILE$BACKUP_SUFFIX"
    echo "  • Run with --verbose for detailed debugging output"
    echo "  • Use --dry-run to preview changes without modifications"
    
    cleanup
    exit $exit_code
}

# Set up error handling
trap 'handle_error $LINENO' ERR

# Main function
main() {
    echo "================================================================"
    echo "Formula Update Script for Repository Dispatch Events"
    echo "================================================================"
    echo
    
    parse_arguments "$@"
    
    # Change to script directory to ensure relative paths work
    cd "$SCRIPT_DIR/.."
    log_debug "Working directory: $(pwd)"
    
    update_formula
    local exit_code=$?
    
    echo
    echo "================================================================"
    if [[ $exit_code -eq 0 ]]; then
        log_success "Formula update completed successfully!"
    else
        log_error "Formula update failed with exit code: $exit_code"
    fi
    echo "================================================================"
    
    exit $exit_code
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

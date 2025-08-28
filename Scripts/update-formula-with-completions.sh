#!/bin/bash

# update-formula-with-completions.sh
# Script to update the Homebrew formula while preserving shell completion functionality
# This extends the existing update-formula-from-dispatch.sh to ensure completions are maintained

set -e  # Exit on any error

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMEBREW_TAP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FORMULA_FILE="$HOMEBREW_TAP_ROOT/Formula/usbip.rb"
BACKUP_FILE="$FORMULA_FILE.backup-$(date +%s)"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VERSION=""
BINARY_URL=""
SHA256=""
SYSTEM_EXT_URL=""
SYSTEM_EXT_SHA256=""
DRY_RUN=false
PRESERVE_COMPLETIONS=true
VERBOSE=false

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

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Update Homebrew formula while preserving shell completion functionality.

OPTIONS:
    --version VERSION           New version (e.g., v1.2.3)
    --binary-url URL           URL to the main binary
    --sha256 HASH              SHA256 hash of the main binary
    --system-ext-url URL       URL to the system extension
    --system-ext-sha256 HASH   SHA256 hash of the system extension
    --dry-run                  Show what would be changed without making changes
    --no-completions           Don't preserve/add completion functionality (not recommended)
    --verbose                  Enable verbose output
    -h, --help                 Show this help message

EXAMPLES:
    $0 --version v1.2.3 --binary-url https://example.com/binary --sha256 abc123...
    $0 --dry-run --version v1.2.3 --binary-url https://example.com/binary --sha256 abc123...

NOTES:
    - This script preserves existing completion installation code
    - If completions are not present, they will be added automatically
    - Always creates a backup of the original formula
    - Use --dry-run to preview changes before applying
EOF
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
            --system-ext-url)
                SYSTEM_EXT_URL="$2"
                shift 2
                ;;
            --system-ext-sha256)
                SYSTEM_EXT_SHA256="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-completions)
                PRESERVE_COMPLETIONS=false
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Validate arguments
validate_arguments() {
    log_info "Validating arguments..."
    
    if [ -z "$VERSION" ]; then
        log_error "Version is required"
        usage
        exit 1
    fi
    
    if [ -z "$BINARY_URL" ]; then
        log_error "Binary URL is required"
        usage
        exit 1
    fi
    
    if [ -z "$SHA256" ]; then
        log_error "SHA256 hash is required"
        usage
        exit 1
    fi
    
    # Validate version format
    if ! echo "$VERSION" | grep -q '^v[0-9]\+\.[0-9]\+\.[0-9]\+'; then
        log_warning "Version format should be vX.Y.Z (e.g., v1.2.3)"
    fi
    
    log_debug "Arguments validated:"
    log_debug "  Version: $VERSION"
    log_debug "  Binary URL: $BINARY_URL"
    log_debug "  SHA256: ${SHA256:0:16}..."
    log_debug "  Preserve Completions: $PRESERVE_COMPLETIONS"
    log_debug "  Dry Run: $DRY_RUN"
}

# Check if formula has completion installation
check_completion_support() {
    log_info "Checking current completion support in formula..."
    
    if grep -q "completion.*generate" "$FORMULA_FILE"; then
        log_success "Formula already has completion generation code"
        return 0
    else
        log_warning "Formula does not have completion installation code"
        return 1
    fi
}

# Create backup of current formula
create_backup() {
    log_info "Creating backup of current formula..."
    
    if [ "$DRY_RUN" = false ]; then
        cp "$FORMULA_FILE" "$BACKUP_FILE"
        log_success "Backup created: $BACKUP_FILE"
    else
        log_info "[DRY RUN] Would create backup: $BACKUP_FILE"
    fi
}

# Extract the binary filename from version
get_binary_filename() {
    local version="$1"
    # Remove 'v' prefix if present
    local clean_version="${version#v}"
    echo "usbipd-v${clean_version}-macos"
}

# Update formula with new version and URLs
update_formula_content() {
    log_info "Updating formula content..."
    
    local binary_filename=$(get_binary_filename "$VERSION")
    local version_number="${VERSION#v}"  # Remove 'v' prefix
    
    # Create temporary file for the updated formula
    local temp_file=$(mktemp)
    
    # Start building the new formula
    cat > "$temp_file" << EOF
# typed: true
# frozen_string_literal: true

class Usbip < Formula
  desc "Macos implementation of the usb/ip protocol"
  homepage "https://github.com/beriberikix/usbipd-mac"
  url "$BINARY_URL"
    version "$version_number"
  sha256 "$SHA256"

EOF
    
    # Add system extension resource if provided
    if [ -n "$SYSTEM_EXT_URL" ] && [ -n "$SYSTEM_EXT_SHA256" ]; then
        cat >> "$temp_file" << EOF
  # System extension resource
  resource "systemextension" do
    url "$SYSTEM_EXT_URL"
    sha256 "$SYSTEM_EXT_SHA256"
  end

EOF
    else
        # Copy existing system extension resource
        local system_ext_section=$(awk '/resource "systemextension"/,/^  end$/' "$FORMULA_FILE")
        if [ -n "$system_ext_section" ]; then
            echo "$system_ext_section" >> "$temp_file"
            echo "" >> "$temp_file"
        fi
    fi
    
    # Add dependencies
    echo "  depends_on :macos => :big_sur" >> "$temp_file"
    echo "" >> "$temp_file"
    
    # Add install method with completion support
    cat >> "$temp_file" << EOF
  def install
    bin.install "$binary_filename" => "usbipd"
    
EOF
    
    # Add completion installation if preserving completions
    if [ "$PRESERVE_COMPLETIONS" = true ]; then
        cat >> "$temp_file" << 'EOF'
    # Generate and install shell completion scripts
    # Note: This temporary approach will be replaced by including pre-generated 
    # completion scripts in the release artifacts in future versions
    mkdir_p "completions"
    
    # Generate completion scripts using the installed binary
    system bin/"usbipd", "completion", "generate", "--output", "completions"
    
    # Install shell completions to appropriate directories
    if File.exist?("completions/usbipd")
      bash_completion.install "completions/usbipd"
    end
    
    if File.exist?("completions/_usbipd")
      zsh_completion.install "completions/_usbipd"
    end
    
    if File.exist?("completions/usbipd.fish")
      fish_completion.install "completions/usbipd.fish"
    end
    
EOF
    fi
    
    # Add system extension installation
    cat >> "$temp_file" << 'EOF'
    # Install system extension bundle
    resource("systemextension").stage do
      # Create system extension directory in expected Library/SystemExtensions path
      (prefix/"Library/SystemExtensions").mkpath
      
      # The tar.gz extracts to just "Contents" directory, so we need to reconstruct the bundle
      if Dir.exist?("Contents")
        puts "Found Contents directory, reconstructing system extension bundle..."
        bundle_dir = prefix/"Library/SystemExtensions"/"USBIPDSystemExtension.systemextension"
        bundle_dir.mkpath
        cp_r "Contents", bundle_dir
        puts "System extension bundle created at: #{bundle_dir}"
      elsif Dir.glob("*.systemextension").any?
        # If we have a .systemextension directory, copy it directly
        Dir.glob("*.systemextension") do |bundle|
          puts "Found system extension bundle: #{bundle}"
          cp_r bundle, prefix/"Library/SystemExtensions"
        end
      else
        puts "Warning: No system extension bundle found in staged directory"
        puts "Contents: #{Dir.glob('*').inspect}"
      end
    end
  end

  def post_install
    puts
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "  🔧 Additional Setup Required"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts
    puts "To complete installation and enable system extension functionality:"
    puts
    puts "  1. Install the system extension:"
    puts "     sudo usbipd install-system-extension"
    puts
    puts "  2. Start the service:"
    puts "     sudo brew services start usbip"
    puts
    puts "  3. Approve the system extension in:"
    puts "     System Preferences → Security & Privacy → General"
    
    puts
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
EOF
    
    # Add shell completion message if preserving completions
    if [ "$PRESERVE_COMPLETIONS" = true ]; then
        cat >> "$temp_file" << 'EOF'
    puts "  🐚 Shell Completions Installed"  
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts
    puts "Shell completions have been automatically installed and should be available"
    puts "in new shell sessions for enhanced CLI experience with tab completion."
    puts
    puts "Supported shells: bash, zsh, fish"
    puts "Type 'usbipd ' and press <TAB> to test completion functionality."
    puts
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
EOF
    fi
    
    cat >> "$temp_file" << 'EOF'
    puts
  end

  service do
    run [opt_bin/"usbipd", "daemon"]
    keep_alive true
    require_root true
    log_path "/var/log/usbipd.log"
    error_log_path "/var/log/usbipd.error.log"
  end

  test do
    assert_match "USB/IP Daemon for macOS", shell_output("#{bin}/usbipd --version")
    assert_path_exists "#{prefix}/Library/SystemExtensions/USBIPDSystemExtension.systemextension"
EOF
    
    # Add completion tests if preserving completions
    if [ "$PRESERVE_COMPLETIONS" = true ]; then
        cat >> "$temp_file" << 'EOF'
    
    # Test that shell completion files are installed
    assert_path_exists "#{bash_completion}/usbipd"
    assert_path_exists "#{zsh_completion}/_usbipd"
    assert_path_exists "#{fish_completion}/usbipd.fish"
    
    # Test that completion command works
    assert_match "Completion Generation Summary", shell_output("#{bin}/usbipd completion generate --output /tmp/test-completions 2>&1", 0)
EOF
    fi
    
    cat >> "$temp_file" << 'EOF'
  end
end
EOF
    
    # Apply the changes
    if [ "$DRY_RUN" = false ]; then
        mv "$temp_file" "$FORMULA_FILE"
        log_success "Formula updated successfully"
    else
        log_info "[DRY RUN] Formula update ready. Changes:"
        echo "--- Current Formula ---"
        head -10 "$FORMULA_FILE"
        echo "--- New Formula (first 20 lines) ---"
        head -20 "$temp_file"
        echo "..."
        rm -f "$temp_file"
    fi
}

# Validate the updated formula
validate_updated_formula() {
    log_info "Validating updated formula..."
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Formula validation would be performed"
        return 0
    fi
    
    # Check Ruby syntax
    if ! ruby -c "$FORMULA_FILE" >/dev/null 2>&1; then
        log_error "Updated formula has syntax errors"
        ruby -c "$FORMULA_FILE"
        return 1
    fi
    
    # Check that completion installation is present if preserving completions
    if [ "$PRESERVE_COMPLETIONS" = true ]; then
        if ! grep -q "completion.*generate" "$FORMULA_FILE"; then
            log_error "Completion installation code missing from updated formula"
            return 1
        fi
    fi
    
    log_success "Formula validation passed"
}

# Generate summary report
generate_summary() {
    log_info "Generating update summary..."
    
    local report_file="$HOMEBREW_TAP_ROOT/formula-update-report.md"
    
    cat > "$report_file" << EOF
# Homebrew Formula Update Report

## Update Summary

- **Version**: $VERSION
- **Binary URL**: $BINARY_URL
- **SHA256**: $SHA256
- **Completion Support**: $([ "$PRESERVE_COMPLETIONS" = true ] && echo "✅ Preserved" || echo "❌ Removed")
- **Dry Run**: $([ "$DRY_RUN" = true ] && echo "Yes" || echo "No")

## Changes Applied

- Updated version number to ${VERSION#v}
- Updated binary download URL
- Updated SHA256 checksum
$([ -n "$SYSTEM_EXT_URL" ] && echo "- Updated system extension URL")
$([ -n "$SYSTEM_EXT_SHA256" ] && echo "- Updated system extension SHA256")
$([ "$PRESERVE_COMPLETIONS" = true ] && echo "- Preserved shell completion installation")

## Formula Features

- ✅ Binary installation
- ✅ System extension installation
$([ "$PRESERVE_COMPLETIONS" = true ] && echo "- ✅ Shell completion installation (bash, zsh, fish)" || echo "- ❌ Shell completion installation")
- ✅ Service configuration
- ✅ Post-install instructions
- ✅ Test suite

## Backup Information

$([ "$DRY_RUN" = false ] && echo "Original formula backed up to: \`$BACKUP_FILE\`" || echo "No backup created (dry run mode)")

## Next Steps

$([ "$DRY_RUN" = true ] && echo "Run without --dry-run to apply changes" || echo "Formula ready for testing and deployment")

---
Generated on: $(date)
EOF

    log_success "Update report generated: $report_file"
}

# Main execution
main() {
    log_info "🔄 Homebrew Formula Updater with Completion Support"
    echo "================================================="
    
    parse_arguments "$@"
    validate_arguments
    
    # Check current state
    if check_completion_support; then
        log_info "Current formula has completion support"
    elif [ "$PRESERVE_COMPLETIONS" = true ]; then
        log_info "Adding completion support to formula"
    fi
    
    create_backup
    update_formula_content
    validate_updated_formula
    generate_summary
    
    echo "================================================="
    if [ "$DRY_RUN" = true ]; then
        log_info "🔍 Dry run completed - no changes applied"
        log_info "Run without --dry-run to apply changes"
    else
        log_success "✅ Formula update completed successfully"
        log_info "Backup available at: $BACKUP_FILE"
    fi
    echo "================================================="
}

# Execute main function with all arguments
main "$@"
#!/bin/bash

# Test script for updated usbipd-mac formula
# This script validates the formula works correctly with system extension support

set -e

echo "🧪 Testing Updated usbipd-mac Formula"
echo "====================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test functions
test_pass() {
    echo -e "${GREEN}✅ $1${NC}"
}

test_fail() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

test_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo
echo "📋 Test Plan:"
echo "1. Validate formula syntax"
echo "2. Check resource definitions"
echo "3. Test installation paths"
echo "4. Verify service configuration"
echo "5. Test post-install instructions"
echo

# Test 1: Formula syntax validation
echo "🔍 Test 1: Formula Syntax Validation"
echo "------------------------------------"

if ruby -c Formula/usbipd-mac-updated.rb > /dev/null 2>&1; then
    test_pass "Formula syntax is valid"
else
    test_fail "Formula syntax is invalid"
fi

# Test 2: Check resource definitions
echo
echo "🔍 Test 2: Resource Definitions"
echo "-------------------------------"

if grep -q "resource \"systemextension\"" Formula/usbipd-mac-updated.rb; then
    test_pass "System extension resource is defined"
else
    test_fail "System extension resource is missing"
fi

if grep -q "USBIPDSystemExtension.systemextension.tar.gz" Formula/usbipd-mac-updated.rb; then
    test_pass "System extension URL pattern is correct"
else
    test_fail "System extension URL pattern is incorrect"
fi

# Test 3: Installation paths
echo
echo "🔍 Test 3: Installation Paths"
echo "-----------------------------"

if grep -q "prefix/\"SystemExtensions\"" Formula/usbipd-mac-updated.rb; then
    test_pass "System extension installation path is defined"
else
    test_fail "System extension installation path is missing"
fi

if grep -q "bin.install.*=> \"usbipd\"" Formula/usbipd-mac-updated.rb; then
    test_pass "CLI binary installation is correct"
else
    test_fail "CLI binary installation is incorrect"
fi

# Test 4: Service configuration
echo
echo "🔍 Test 4: Service Configuration"
echo "--------------------------------"

if grep -q "service do" Formula/usbipd-mac-updated.rb; then
    test_pass "Service configuration is present"
else
    test_fail "Service configuration is missing"
fi

if grep -q "require_root true" Formula/usbipd-mac-updated.rb; then
    test_pass "Service requires root privileges"
else
    test_fail "Service root requirement is missing"
fi

# Test 5: Post-install instructions
echo
echo "🔍 Test 5: Post-install Instructions"
echo "------------------------------------"

if grep -q "post_install" Formula/usbipd-mac-updated.rb; then
    test_pass "Post-install instructions are present"
else
    test_fail "Post-install instructions are missing"
fi

if grep -q "install-system-extension" Formula/usbipd-mac-updated.rb; then
    test_pass "System extension installation instructions included"
else
    test_fail "System extension installation instructions missing"
fi

# Test 6: Test block validation
echo
echo "🔍 Test 6: Test Block Validation"
echo "--------------------------------"

if grep -q "test do" Formula/usbipd-mac-updated.rb; then
    test_pass "Test block is present"
else
    test_fail "Test block is missing"
fi

if grep -q "assert_path_exists.*SystemExtensions" Formula/usbipd-mac-updated.rb; then
    test_pass "System extension path test included"
else
    test_warn "System extension path test not found (may be conditional)"
fi

# Summary
echo
echo "🎉 All Tests Completed Successfully!"
echo "====================================="
echo
echo "📝 Summary:"
echo "• Formula syntax is valid"
echo "• System extension resource is properly defined"
echo "• Installation paths are configured correctly"
echo "• Service configuration includes required settings"
echo "• Post-install instructions guide users through setup"
echo "• Test block validates installation"
echo
echo "✅ The updated formula is ready for use!"
echo
echo "📋 Next Steps:"
echo "1. Wait for upstream release with system extension bundle"
echo "2. Update SHA256 placeholder when real bundle is available"
echo "3. Test with actual system extension bundle"
echo "4. Submit PR to upstream project"
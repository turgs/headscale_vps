#!/bin/bash
#
# validate_scripts.sh - Basic validation of script functionality
#
# This script performs basic checks on the provisioning scripts
# without actually running them on a server
#

set -uo pipefail
# Note: Not using -e to allow test failures without script exit

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

print_test() {
    echo -n "  Testing: $1 ... "
}

print_pass() {
    echo -e "${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}✗ FAIL${NC}"
    [[ -n "${1:-}" ]] && echo -e "    ${RED}Error: $1${NC}"
    ((TESTS_FAILED++))
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Validating Scripts"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test 1: Check all scripts exist
print_test "All required scripts exist"
if [[ -f provision_vps.sh ]] && [[ -f test_setup.sh ]] && [[ -f setup_exit_node.sh ]]; then
    print_pass
else
    print_fail "Missing script files"
fi

# Test 2: Check scripts are executable
print_test "Scripts are executable"
if [[ -x provision_vps.sh ]] && [[ -x test_setup.sh ]] && [[ -x setup_exit_node.sh ]]; then
    print_pass
else
    print_fail "Scripts not executable"
fi

# Test 3: Bash syntax check
print_test "provision_vps.sh syntax"
if bash -n provision_vps.sh 2>/dev/null; then
    print_pass
else
    print_fail "Syntax error in provision_vps.sh"
fi

print_test "test_setup.sh syntax"
if bash -n test_setup.sh 2>/dev/null; then
    print_pass
else
    print_fail "Syntax error in test_setup.sh"
fi

print_test "setup_exit_node.sh syntax"
if bash -n setup_exit_node.sh 2>/dev/null; then
    print_pass
else
    print_fail "Syntax error in setup_exit_node.sh"
fi

# Test 4: Check help options work
print_test "provision_vps.sh --help"
if bash provision_vps.sh --help 2>/dev/null | grep -q "Usage:"; then
    print_pass
else
    print_fail "Help option not working"
fi

# Test 5: Check configuration files exist
print_test "Configuration files exist"
if [[ -f docker-compose.yml ]] && [[ -f config/headscale-config.yaml ]] && [[ -f config/deploy.yml ]]; then
    print_pass
else
    print_fail "Missing configuration files"
fi

# Test 6: Validate docker-compose.yml syntax
print_test "docker-compose.yml syntax"
if command -v docker &>/dev/null; then
    if docker compose -f docker-compose.yml config >/dev/null 2>&1; then
        print_pass
    else
        print_fail "docker-compose.yml has syntax errors"
    fi
else
    echo -e "${YELLOW}⊘ SKIP (Docker not installed)${NC}"
fi

# Test 7: Check documentation exists
print_test "Documentation files exist"
if [[ -f README.md ]] && [[ -f QUICKSTART.md ]] && [[ -f LICENSE ]]; then
    print_pass
else
    print_fail "Missing documentation files"
fi

# Test 8: Check for common security issues
print_test "No hardcoded secrets in scripts"
if ! grep -rE "(password|secret|token)=['\"]?[^'\"\$]+" provision_vps.sh setup_exit_node.sh 2>/dev/null | grep -v "DEPLOY_PASSWORD=\"\""; then
    print_pass
else
    print_fail "Possible hardcoded secrets found"
fi

# Test 9: Check scripts use set -e for error handling
print_test "Scripts have error handling"
if grep -q "set -e" provision_vps.sh && grep -q "set -e" test_setup.sh; then
    print_pass
else
    print_fail "Scripts missing error handling"
fi

# Test 10: Verify functions are defined before use
print_test "provision_vps.sh function definitions"
if grep -q "^main()" provision_vps.sh && grep -q "^parse_args()" provision_vps.sh; then
    print_pass
else
    print_fail "Missing function definitions"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✅ All validation tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some validation tests failed.${NC}"
    exit 1
fi

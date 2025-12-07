#!/bin/bash
#
# test_1password_helper.sh - Unit tests for 1password-helper.sh
#
# These tests verify the helper functions work correctly without actually
# connecting to 1Password or SSH servers.
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

print_test() {
    echo -n "Test: $1 ... "
}

print_pass() {
    echo -e "${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}✗ FAIL${NC}"
    echo "  Error: $1"
    ((TESTS_FAILED++))
}

# Test 1: Script has valid bash syntax
test_script_syntax() {
    print_test "Script syntax validation"
    
    if bash -n "$REPO_ROOT/scripts/1password-helper.sh" 2>/dev/null; then
        print_pass
    else
        print_fail "Invalid bash syntax"
    fi
}

# Test 2: Script can be sourced
test_script_sourcing() {
    print_test "Script sourcing"
    
    local result
    result=$(bash -c "source '$REPO_ROOT/scripts/1password-helper.sh' 2>&1 && type check_1password_cli 2>&1" || echo "FAIL")
    
    if [[ "$result" != "FAIL" ]] && [[ "$result" == *"is a function"* ]]; then
        print_pass
    else
        print_fail "Failed to source script or functions not exported"
    fi
}

# Test 3: check_1password_cli detects missing op command
test_check_1password_cli_missing() {
    print_test "check_1password_cli detects missing 'op'"
    
    # Create a temporary script that simulates missing 'op'
    local result
    result=$(bash -c "
        source '$REPO_ROOT/scripts/1password-helper.sh'
        # Override command to simulate missing op
        command() { [[ \$1 == '-v' ]] && shift; [[ \$1 == 'op' ]] && return 1 || return 0; }
        check_1password_cli 2>&1
    " || echo "EXPECTED_FAILURE")
    
    if [[ "$result" == "EXPECTED_FAILURE" ]] || [[ "$result" == *"not installed"* ]]; then
        print_pass
    else
        print_fail "Should detect missing op command"
    fi
}

# Test 4: check_sshpass detects missing sshpass command
test_check_sshpass_missing() {
    print_test "check_sshpass detects missing 'sshpass'"
    
    local result
    result=$(bash -c "
        source '$REPO_ROOT/scripts/1password-helper.sh'
        # Override command to simulate missing sshpass
        command() { [[ \$1 == '-v' ]] && shift; [[ \$1 == 'sshpass' ]] && return 1 || return 0; }
        check_sshpass 2>&1
    " || echo "EXPECTED_FAILURE")
    
    if [[ "$result" == "EXPECTED_FAILURE" ]] || [[ "$result" == *"not installed"* ]]; then
        print_pass
    else
        print_fail "Should detect missing sshpass command"
    fi
}

# Test 5: Environment variables are used correctly
test_environment_variables() {
    print_test "Environment variables override defaults"
    
    local result
    result=$(bash -c "
        export OP_ITEM_NAME='Custom Item'
        export OP_FIELD_NAME='custom field'
        source '$REPO_ROOT/scripts/1password-helper.sh'
        echo \"\$OP_ITEM_NAME|\$OP_FIELD_NAME\"
    ")
    
    if [[ "$result" == "Custom Item|custom field" ]]; then
        print_pass
    else
        print_fail "Environment variables not respected (got: $result)"
    fi
}

# Test 6: Default environment variables
test_default_environment_variables() {
    print_test "Default environment variables"
    
    local result
    result=$(bash -c "
        source '$REPO_ROOT/scripts/1password-helper.sh'
        echo \"\$OP_ITEM_NAME|\$OP_FIELD_NAME\"
    ")
    
    if [[ "$result" == "BinaryLane VPN Headscale Tailscale|root Password" ]]; then
        print_pass
    else
        print_fail "Default values incorrect (got: $result)"
    fi
}

# Test 7: provision_vps_1password.sh has valid syntax
test_provision_script_syntax() {
    print_test "provision_vps_1password.sh syntax"
    
    if bash -n "$REPO_ROOT/provision_vps_1password.sh" 2>/dev/null; then
        print_pass
    else
        print_fail "Invalid bash syntax"
    fi
}

# Test 8: provision_vps_1password.sh shows help
test_provision_script_help() {
    print_test "provision_vps_1password.sh --help"
    
    local result
    result=$("$REPO_ROOT/provision_vps_1password.sh" --help 2>&1 || true)
    
    if [[ "$result" == *"Usage:"* ]] && [[ "$result" == *"1Password"* ]]; then
        print_pass
    else
        print_fail "Help output incomplete"
    fi
}

# Test 9: Verify security warnings are present in script
test_security_warnings_present() {
    print_test "Security warnings in helper script"
    
    local warnings_count
    warnings_count=$(grep -c "⚠️.*Warning" "$REPO_ROOT/scripts/1password-helper.sh" || echo 0)
    
    if [[ $warnings_count -ge 3 ]]; then
        print_pass
    else
        print_fail "Expected at least 3 security warnings, found $warnings_count"
    fi
}

# Test 10: Verify documentation exists
test_documentation_exists() {
    print_test "1PASSWORD_SETUP.md exists"
    
    if [[ -f "$REPO_ROOT/1PASSWORD_SETUP.md" ]]; then
        print_pass
    else
        print_fail "Documentation file missing"
    fi
}

# Main test runner
main() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  1Password Helper Script Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Run all tests
    test_script_syntax
    test_script_sourcing
    test_check_1password_cli_missing
    test_check_sshpass_missing
    test_environment_variables
    test_default_environment_variables
    test_provision_script_syntax
    test_provision_script_help
    test_security_warnings_present
    test_documentation_exists
    
    # Summary
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Test Results"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Total:  $((TESTS_PASSED + TESTS_FAILED))"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some tests failed${NC}"
        exit 1
    fi
}

main "$@"

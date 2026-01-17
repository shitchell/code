#!/usr/bin/env bash
#
# test_errors.sh - Tests for the errors.sh library

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the test helpers
source "$SCRIPT_DIR/../test_helpers.sh"

# Source the library being tested
source "$SCRIPT_DIR/../../lib/errors.sh"

# Test error-init function
function test_error_init() {
    # Test basic initialization
    error-init
    assert_equals "$ERROR_HANDLER_SET" "1" "error-init should set ERROR_HANDLER_SET"

    # Reset for next test
    ERROR_HANDLER_SET=0
    trap - ERR

    # Test strict mode initialization
    local old_e=$(set +o | grep errexit)
    local old_u=$(set +o | grep nounset)
    local old_p=$(set +o | grep pipefail)

    error-init strict
    assert_equals "$ERROR_EXIT_ON_ERROR" "1" "error-init strict should set ERROR_EXIT_ON_ERROR"

    # Check that strict mode is enabled
    set +o | grep -q "set -o errexit" && local e_set=1 || local e_set=0
    set +o | grep -q "set -o nounset" && local u_set=1 || local u_set=0
    set +o | grep -q "set -o pipefail" && local p_set=1 || local p_set=0

    assert_equals "$e_set" "1" "error-init strict should enable errexit"
    assert_equals "$u_set" "1" "error-init strict should enable nounset"
    assert_equals "$p_set" "1" "error-init strict should enable pipefail"

    # Restore original settings
    eval "$old_e"
    eval "$old_u"
    eval "$old_p"
    trap - ERR
}

# Test error-handler function
function test_error_handler() {
    # Define a custom handler
    function my_custom_handler() {
        echo "CUSTOM: $1 $2"
    }

    # Test setting a valid handler
    error-handler my_custom_handler
    assert_equals "$?" "0" "error-handler should succeed with valid function"
    assert_equals "$ERROR_HANDLER_SET" "1" "error-handler should set ERROR_HANDLER_SET"

    # Test setting an invalid handler
    local output=$(error-handler nonexistent_function 2>&1)
    assert_equals "$?" "1" "error-handler should fail with invalid function"
    assert_contains "$output" "does not exist" "error-handler should report missing function"

    # Clean up
    unset -f my_custom_handler
    trap - ERR
}

# Test throw function
function test_throw() {
    # Test throw in a subshell to avoid exiting the test
    local output
    local exit_code

    # Test basic throw
    output=$( (throw "Test error" 2>&1) 2>&1 || echo "EXIT:$?")
    assert_contains "$output" "ERROR: Test error" "throw should output error message"
    assert_contains "$output" "EXIT:1" "throw should exit with code 1 by default"

    # Test throw with custom exit code
    output=$( (throw "Custom error" 42 2>&1) 2>&1 || echo "EXIT:$?")
    assert_contains "$output" "ERROR: Custom error" "throw should output custom error"
    assert_contains "$output" "EXIT:42" "throw should exit with custom code"

    # Test throw with stack trace disabled
    ERROR_TRACE_ENABLED=0
    output=$( (throw "No trace" 2>&1) 2>&1 || true)
    assert_not_contains "$output" "Stack trace:" "throw should not show trace when disabled"
    ERROR_TRACE_ENABLED=1
}

# Test try-catch-endtry blocks
function test_try_catch() {
    local result=""

    # Test successful command in try block
    try
        result="success"
    catch
        result="caught"
    endtry

    assert_equals "$result" "success" "try-catch should not catch when no error"

    # Test failing command in try block
    result=""
    try
        false  # This command fails
        result="should not reach here"
    catch
        result="caught error"
    endtry

    assert_equals "$result" "caught error" "try-catch should catch errors"

    # Test nested try-catch blocks
    local outer=""
    local inner=""

    try
        outer="outer try"
        try
            false
            inner="should not reach"
        catch
            inner="inner caught"
        endtry
    catch
        outer="outer caught"
    endtry

    assert_equals "$outer" "outer try" "Outer try should succeed"
    assert_equals "$inner" "inner caught" "Inner catch should catch error"

    # Test error state in catch block
    ERROR_CODE=0
    ERROR_MESSAGE=""

    try
        false
    catch
        local saved_code=$ERROR_CODE
    endtry

    assert_not_equals "$saved_code" "0" "ERROR_CODE should be set in catch block"
}

# Test stack-trace function
function test_stack_trace() {
    # Function to create a call stack
    function level3() {
        stack-trace
    }

    function level2() {
        level3
    }

    function level1() {
        level2
    }

    # Capture stack trace output
    local output=$(level1 2>&1)

    assert_contains "$output" "Stack trace:" "stack-trace should show header"
    assert_contains "$output" "level3" "stack-trace should show level3"
    assert_contains "$output" "level2" "stack-trace should show level2"
    assert_contains "$output" "level1" "stack-trace should show level1"

    # Clean up
    unset -f level1 level2 level3
}

# Test error-reset function
function test_error_reset() {
    # Set error state
    ERROR_CODE=42
    ERROR_MESSAGE="Test error"
    ERROR_SOURCE="test.sh"
    ERROR_LINE=100

    # Reset
    error-reset

    assert_equals "$ERROR_CODE" "0" "error-reset should clear ERROR_CODE"
    assert_equals "$ERROR_MESSAGE" "" "error-reset should clear ERROR_MESSAGE"
    assert_equals "$ERROR_SOURCE" "" "error-reset should clear ERROR_SOURCE"
    assert_equals "$ERROR_LINE" "0" "error-reset should clear ERROR_LINE"
}

# Test error-info function
function test_error_info() {
    # Set known error state
    ERROR_CODE=123
    ERROR_MESSAGE="Info test"
    ERROR_SOURCE="info.sh"
    ERROR_LINE=456

    # Capture output
    local output=$(error-info)

    assert_contains "$output" "Error State Information:" "error-info should show header"
    assert_contains "$output" "ERROR_CODE: 123" "error-info should show ERROR_CODE"
    assert_contains "$output" "ERROR_MESSAGE: Info test" "error-info should show ERROR_MESSAGE"
    assert_contains "$output" "ERROR_SOURCE: info.sh" "error-info should show ERROR_SOURCE"
    assert_contains "$output" "ERROR_LINE: 456" "error-info should show ERROR_LINE"
}

# Test error handler integration
function test_error_handler_integration() {
    # Initialize error handling
    error-init

    # Function that will trigger an error
    function trigger_error() {
        false  # This will trigger the error handler
        echo "Should not reach here"
    }

    # Capture error handler output in a subshell
    local output=$( (trigger_error 2>&1) 2>&1 || true)

    assert_contains "$output" "ERROR:" "Error handler should trigger on false"
    assert_not_contains "$output" "Should not reach here" "Execution should stop after error"

    # Clean up
    unset -f trigger_error
    trap - ERR
}

# Test custom error handler
function test_custom_error_handler() {
    # Variable to track if custom handler was called
    local handler_called=0

    # Define custom handler
    function test_handler() {
        handler_called=1
        echo "CUSTOM_HANDLER: exit_code=$1 command=$2"
    }

    # Set up error handling with custom handler
    error-init
    error-handler test_handler

    # Trigger error in subshell
    local output=$( (false 2>&1) 2>&1 || true)

    assert_contains "$output" "CUSTOM_HANDLER:" "Custom handler should be called"
    assert_contains "$output" "exit_code=1" "Custom handler should receive exit code"
    assert_contains "$output" "command=false" "Custom handler should receive command"

    # Clean up
    unset -f test_handler
    trap - ERR
}

# Test try-catch with multiple commands
function test_try_catch_multiple() {
    local step=""

    try
        step="step1"
        true  # succeeds
        step="step2"
        false  # fails
        step="step3"  # should not reach
    catch
        step="${step}_caught"
    endtry

    assert_equals "$step" "step2_caught" "Should catch at failed command"
}

# Test try-catch preserves exit codes
function test_try_catch_exit_codes() {
    local caught_code=0

    try
        exit 42  # Special exit code
    catch
        caught_code=$ERROR_CODE
    endtry

    assert_equals "$caught_code" "42" "Should preserve exit code in ERROR_CODE"
}

# Run all tests
run_tests "test_error_init" \
          "test_error_handler" \
          "test_throw" \
          "test_try_catch" \
          "test_stack_trace" \
          "test_error_reset" \
          "test_error_info" \
          "test_error_handler_integration" \
          "test_custom_error_handler" \
          "test_try_catch_multiple" \
          "test_try_catch_exit_codes"
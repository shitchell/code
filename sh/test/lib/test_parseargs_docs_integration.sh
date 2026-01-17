#!/usr/bin/env bash
# Test the integration between parseargs.sh and docs.sh

# Source the libraries
source "$(dirname "$0")/../../lib/include.sh"
include-source 'docs.sh'
include-source 'parseargs.sh'

# Test function with comprehensive docstring
function test-command() {
    : 'Test command for parseargs/docs integration

        This is a test command that demonstrates how parseargs can
        automatically extract argument definitions from function docstrings.

        @usage
            test-command [options] <input_file> <output_file> [<extra_files>...]

        @option -v/--verbose
            Enable verbose output

        @option -q/--quiet
            Suppress all output

        @option -f/--force
            Force overwrite of existing files

        @option -n/--dry-run
            Show what would be done without doing it

        @option -c/--config <file>
            Configuration file to use

        @option -j/--jobs <number>
            Number of parallel jobs (default: 1)

        @arg <input_file>
            The input file to process

        @arg <output_file>
            The output file to create

        @optarg <extra_files>
            Additional files to process

        @stdout
            Progress information and results

        @stderr
            Error messages and warnings

        @return 0
            Success

        @return 1
            General error

        @return 2
            Invalid arguments
    '
    echo "test-command called with args: $@"
}

# Test 1: Basic docstring extraction
echo "=== Test 1: Basic docstring extraction ==="
docs-generate-help test-command --format plain
echo

# Test 2: Configure parseargs from docstring
echo "=== Test 2: Configure parseargs from docstring ==="
parseargs-init --from-function test-command
parseargs-show-help
echo

# Test 3: Parse actual arguments using docstring config
echo "=== Test 3: Parse arguments with docstring config ==="
parseargs-init --from-function test-command
parseargs-parse -v --config test.conf input.txt output.txt extra1.txt extra2.txt
echo "Parsed options:"
for key in "${!PARSEARGS_OPTS[@]}"; do
    echo "  $key = ${PARSEARGS_OPTS[$key]}"
done
echo "Parsed positional args: ${PARSEARGS_POSARGS[@]}"
echo

# Test 4: Help display with docstring
echo "=== Test 4: Help display test ==="
parseargs-init --from-function test-command
parseargs-parse --help 2>/dev/null || true
echo

# Test 5: Test with a simpler function
function simple-function() {
    : 'A simple test function

        @usage
            simple-function [--debug] <name>

        @option --debug
            Enable debug mode

        @arg <name>
            The name to greet
    '
    echo "Hello, $1!"
}

echo "=== Test 5: Simple function test ==="
parseargs-init --from-function simple-function
parseargs-show-help
echo

# Test 6: Verify manual configuration still works
echo "=== Test 6: Manual configuration test ==="
parseargs-init
parseargs-set-prog-name "manual-test"
parseargs-set-help "Manually configured parser"
parseargs-add-flag "-t/--test" --help "Test flag"
parseargs-add-parameter "-i/--input" --help "Input file" --required
parseargs-add-positional "output" --help "Output file"
parseargs-show-help
echo

# Test 7: Mixed docstring and manual configuration
echo "=== Test 7: Mixed configuration test ==="
parseargs-init --from-function simple-function
parseargs-add-flag "-x/--extra" --help "Extra flag added manually"
parseargs-show-help
echo

echo "All tests completed!"
#!/usr/bin/env bash
# Example: Using parseargs with docs.sh integration

# Source the libraries
source "$(dirname "$0")/../lib/include.sh"
include-source 'docs.sh'
include-source 'parseargs.sh'

# Define the main function with a comprehensive docstring
function file-processor() {
    : 'Process files with various transformations

        This utility processes text files by applying various transformations
        such as converting case, removing duplicates, or sorting lines.

        @usage
            file-processor [options] <input_file> [<output_file>]

        @option -u/--uppercase
            Convert text to uppercase

        @option -l/--lowercase
            Convert text to lowercase

        @option -s/--sort
            Sort lines alphabetically

        @option -r/--reverse
            Reverse the order of lines

        @option -d/--remove-duplicates
            Remove duplicate lines

        @option -n/--line-numbers
            Add line numbers to output

        @option -o/--output <file>
            Output file (default: stdout)

        @option -b/--backup
            Create backup of output file if it exists

        @option -v/--verbose
            Enable verbose output

        @option -h/--help
            Show this help message

        @arg <input_file>
            The file to process

        @optarg <output_file>
            Output file (alternative to -o option)

        @stdin
            If input_file is "-", read from stdin

        @stdout
            Processed text (if no output file specified)

        @stderr
            Error messages and verbose output

        @return 0
            Success

        @return 1
            File not found or read error

        @return 2
            Write error

        @return 3
            Invalid arguments
    '

    # The actual implementation would go here
    echo "Processing files..."
    echo "Options:"
    for key in "${!PARSEARGS_OPTS[@]}"; do
        echo "  $key = ${PARSEARGS_OPTS[$key]}"
    done
    echo "Input file: ${PARSEARGS_POSARGS[0]}"
    [[ ${#PARSEARGS_POSARGS[@]} -ge 2 ]] && echo "Output file: ${PARSEARGS_POSARGS[1]}"
}

# Main script
main() {
    # Initialize parseargs from the function's docstring
    parseargs-init --from-function file-processor

    # Parse command line arguments
    parseargs-parse "$@" || exit $?

    # Access parsed arguments
    local input_file="${PARSEARGS_POSARGS[0]}"
    local output_file="${PARSEARGS_POSARGS[1]:-${PARSEARGS_OPTS[output]:-/dev/stdout}}"

    # Check verbose flag
    if [[ "${PARSEARGS_OPTS[verbose]}" == "true" ]]; then
        echo "Verbose mode enabled" >&2
        echo "Input: $input_file" >&2
        echo "Output: $output_file" >&2
    fi

    # Validate input file
    if [[ "$input_file" != "-" && ! -f "$input_file" ]]; then
        echo "Error: Input file not found: $input_file" >&2
        exit 1
    fi

    # Create backup if requested
    if [[ "${PARSEARGS_OPTS[backup]}" == "true" && -f "$output_file" ]]; then
        cp "$output_file" "${output_file}.bak"
        [[ "${PARSEARGS_OPTS[verbose]}" == "true" ]] && echo "Created backup: ${output_file}.bak" >&2
    fi

    # Process the file (simplified example)
    local content
    if [[ "$input_file" == "-" ]]; then
        content=$(cat)
    else
        content=$(cat "$input_file")
    fi

    # Apply transformations based on options
    if [[ "${PARSEARGS_OPTS[uppercase]}" == "true" ]]; then
        content=$(echo "$content" | tr '[:lower:]' '[:upper:]')
    elif [[ "${PARSEARGS_OPTS[lowercase]}" == "true" ]]; then
        content=$(echo "$content" | tr '[:upper:]' '[:lower:]')
    fi

    if [[ "${PARSEARGS_OPTS[sort]}" == "true" ]]; then
        content=$(echo "$content" | sort)
    fi

    if [[ "${PARSEARGS_OPTS[reverse]}" == "true" ]]; then
        content=$(echo "$content" | tac)
    fi

    if [[ "${PARSEARGS_OPTS[remove_duplicates]}" == "true" ]]; then
        content=$(echo "$content" | sort -u)
    fi

    if [[ "${PARSEARGS_OPTS[line_numbers]}" == "true" ]]; then
        content=$(echo "$content" | nl -b a)
    fi

    # Output the result
    if [[ "$output_file" == "/dev/stdout" ]]; then
        echo "$content"
    else
        echo "$content" > "$output_file"
        [[ "${PARSEARGS_OPTS[verbose]}" == "true" ]] && echo "Output written to: $output_file" >&2
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
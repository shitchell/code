#!/usr/bin/env bash
#
# Test script for clipboard utilities (clip.exe, clipin.exe, clipout.exe)
# Tests basic copy/paste, special characters, multiline content, and various formats

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIP="${SCRIPT_DIR}/clip.exe"
CLIPIN="${SCRIPT_DIR}/clipin.exe"
CLIPOUT="${SCRIPT_DIR}/clipout.exe"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

## Counters ####################################################################

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

## Helper functions ############################################################

log_test()  { echo -e "${BLUE}[TEST]${NC} $1"; }
log_pass()  { echo -e "${GREEN}[PASS]${NC} $1"; ((TESTS_PASSED++)); }
log_fail()  { echo -e "${RED}[FAIL]${NC} $1"; [[ -n "${2:-}" ]] && echo -e "       $2"; ((TESTS_FAILED++)); }
log_skip()  { echo -e "${YELLOW}[SKIP]${NC} $1"; ((TESTS_SKIPPED++)); }
log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }

assert_eq() {
    local expected="$1" actual="$2" test_name="$3"
    ((TESTS_RUN++))
    if [[ "${expected}" == "${actual}" ]]; then
        log_pass "${test_name}"
    else
        log_fail "${test_name}" "Expected: '${expected}'\n       Actual:   '${actual}'"
    fi
}

assert_contains() {
    local haystack="$1" needle="$2" test_name="$3"
    ((TESTS_RUN++))
    if [[ "${haystack}" == *"${needle}"* ]]; then
        log_pass "${test_name}"
    else
        log_fail "${test_name}" "Expected to contain: '${needle}'\n       Actual: '${haystack:0:100}...'"
    fi
}

assert_not_empty() {
    local value="$1" test_name="$2"
    ((TESTS_RUN++))
    if [[ -n "${value}" ]]; then
        log_pass "${test_name}"
    else
        log_fail "${test_name}" "Expected non-empty value"
    fi
}

## Pre-flight checks ###########################################################

check_prerequisites() {
    log_info "Checking prerequisites..."
    local missing=()
    [[ ! -x "${CLIP}" ]] && missing+=("clip.exe")
    [[ ! -x "${CLIPIN}" ]] && missing+=("clipin.exe")
    [[ ! -x "${CLIPOUT}" ]] && missing+=("clipout.exe")
    command -v powershell.exe &>/dev/null || missing+=("powershell.exe")

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}Missing prerequisites:${NC} ${missing[*]}"
        exit 1
    fi
    log_info "All prerequisites found"
    echo
}

## Tests #######################################################################

test_clipout_basic() {
    log_info "Testing clipout.exe basic functionality..."

    powershell.exe -command "Set-Clipboard -Value 'clipout_test_value'"
    local result
    result=$("${CLIPOUT}")
    assert_contains "${result}" "clipout_test_value" "clipout.exe: reads clipboard content"
}

test_clipin_basic() {
    log_info "Testing clipin.exe basic functionality..."

    # Test with argument
    local test_value="clipin_arg_$$"
    "${CLIPIN}" "${test_value}"
    local result
    result=$("${CLIPOUT}")
    assert_contains "${result}" "${test_value}" "clipin.exe: sets clipboard via argument"

    # Test piping content
    local test_value2="clipin_pipe_$$"
    echo "${test_value2}" | "${CLIPIN}"
    result=$("${CLIPOUT}")
    assert_contains "${result}" "${test_value2}" "clipin.exe: sets clipboard via pipe"
}

test_clipin_append() {
    log_info "Testing clipin.exe append mode..."

    local val1="first_$$"
    local val2="second_$$"
    "${CLIPIN}" "${val1}"
    "${CLIPIN}" --append "${val2}"
    local result
    result=$("${CLIPOUT}")
    assert_contains "${result}" "${val1}" "clipin.exe --append: preserves first value"
    assert_contains "${result}" "${val2}" "clipin.exe --append: appends second value"
}

test_clip_copy() {
    log_info "Testing clip.exe copy mode..."

    local test_value="clip_value_$$"
    "${CLIP}" --value "${test_value}"
    local result
    result=$("${CLIPOUT}")
    assert_contains "${result}" "${test_value}" "clip.exe --value: sets clipboard"

    # Test with pipe
    local test_value2="clip_pipe_$$"
    echo "${test_value2}" | "${CLIP}"
    result=$("${CLIPOUT}")
    assert_contains "${result}" "${test_value2}" "clip.exe: sets clipboard via pipe"
}

test_clip_paste() {
    log_info "Testing clip.exe paste mode..."

    local test_value="clip_paste_$$"
    "${CLIPIN}" "${test_value}"
    local result
    result=$("${CLIP}" --paste)
    assert_contains "${result}" "${test_value}" "clip.exe --paste: reads clipboard"

    result=$("${CLIP}" --get)
    assert_contains "${result}" "${test_value}" "clip.exe --get: reads clipboard (alias)"
}

test_special_characters() {
    log_info "Testing special characters..."

    # Single quotes
    local sq_test="it's a test with 'quotes'"
    "${CLIPIN}" "${sq_test}"
    local result
    result=$("${CLIPOUT}")
    assert_contains "${result}" "it" "clipin.exe: handles single quotes"

    # Double quotes
    local dq_test='test with "double quotes"'
    "${CLIPIN}" "${dq_test}"
    result=$("${CLIPOUT}")
    assert_contains "${result}" "double" "clipin.exe: handles double quotes"

    # Backticks
    local bt_test='test with `backticks`'
    "${CLIPIN}" "${bt_test}"
    result=$("${CLIPOUT}")
    assert_contains "${result}" "backticks" "clipin.exe: handles backticks"

    # Dollar signs
    local ds_test='$variable and ${braces}'
    "${CLIPIN}" "${ds_test}"
    result=$("${CLIPOUT}")
    assert_contains "${result}" "variable" "clipin.exe: handles dollar signs"
}

test_multiline() {
    log_info "Testing multiline content..."

    local nl_test=$'line1\nline2\nline3'
    echo "${nl_test}" | "${CLIPIN}"
    local result
    result=$("${CLIPOUT}")
    assert_contains "${result}" "line1" "clipin.exe: handles multiline (line1)"
    assert_contains "${result}" "line2" "clipin.exe: handles multiline (line2)"
    assert_contains "${result}" "line3" "clipin.exe: handles multiline (line3)"
}

test_large_content() {
    log_info "Testing large content..."

    # Generate ~5KB of content
    local large_content
    large_content=$(printf 'x%.0s' {1..5000})
    echo "${large_content}" | "${CLIPIN}"
    local result
    result=$("${CLIPOUT}")
    local result_len=${#result}
    ((TESTS_RUN++))
    if [[ ${result_len} -ge 4500 ]]; then
        log_pass "clipin.exe: handles large content (${result_len} chars)"
    else
        log_fail "clipin.exe: handles large content" "Expected ~5000 chars, got ${result_len}"
    fi
}

test_empty_clipboard() {
    log_info "Testing empty clipboard handling..."

    powershell.exe -command "Set-Clipboard -Value ''" 2>/dev/null || true
    local result
    result=$("${CLIPOUT}" 2>&1) || true
    ((TESTS_RUN++))
    log_pass "clipout.exe: handles empty clipboard gracefully"
}

test_clipin_echo() {
    log_info "Testing clipin.exe --echo option..."

    local test_value="echo_test_$$"
    local result
    result=$("${CLIPIN}" --echo "${test_value}")
    assert_contains "${result}" "${test_value}" "clipin.exe --echo: echoes clipboard after set"
}

test_file_input() {
    log_info "Testing file input..."

    local tmpfile
    tmpfile=$(mktemp)
    local test_content="file_content_$$"
    echo "${test_content}" > "${tmpfile}"
    "${CLIP}" --file "${tmpfile}"
    local result
    result=$("${CLIPOUT}")
    rm -f "${tmpfile}"
    assert_contains "${result}" "${test_content}" "clip.exe --file: reads from file"
}

test_help_output() {
    log_info "Testing help output..."

    local result
    result=$("${CLIP}" --help 2>&1) || true
    assert_contains "${result}" "usage" "clip.exe --help: shows usage"

    result=$("${CLIPIN}" --help 2>&1) || true
    assert_contains "${result}" "usage" "clipin.exe --help: shows usage"

    result=$("${CLIP}" -h 2>&1) || true
    assert_contains "${result}" "usage" "clip.exe -h: shows short usage"

    result=$("${CLIPIN}" -h 2>&1) || true
    assert_contains "${result}" "usage" "clipin.exe -h: shows short usage"
}

## Format Tests ################################################################

# Helper to set rich text clipboard with both HTML and plain text
set_rich_clipboard() {
    local html="$1"
    local text="$2"
    powershell.exe -command "
Add-Type -AssemblyName System.Windows.Forms
\$html = @'
Version:0.9
StartHTML:00000097
EndHTML:ENDHTML_PLACEHOLDER
StartFragment:00000131
EndFragment:ENDFRAG_PLACEHOLDER
<html><body>
<!--StartFragment-->${html}<!--EndFragment-->
</body></html>
'@
# Calculate proper offsets
\$endFrag = \$html.IndexOf('<!--EndFragment-->') + 131
\$endHtml = \$html.Length + 97 + 50
\$html = \$html -replace 'ENDHTML_PLACEHOLDER', \$endHtml.ToString('D8')
\$html = \$html -replace 'ENDFRAG_PLACEHOLDER', \$endFrag.ToString('D8')
\$dataObj = New-Object System.Windows.Forms.DataObject
\$dataObj.SetData([System.Windows.Forms.DataFormats]::Html, \$html)
\$dataObj.SetData([System.Windows.Forms.DataFormats]::Text, '${text}')
[System.Windows.Forms.Clipboard]::SetDataObject(\$dataObj, \$true)
"
}

test_output_formats() {
    log_info "Testing output formats..."

    # Set up rich clipboard with HTML
    set_rich_clipboard '<b>Bold</b> and <i>italic</i>' 'Bold and italic'

    local result

    # Test --text format
    result=$("${CLIP}" --paste --text)
    assert_contains "${result}" "Bold" "clip.exe --text: extracts plain text"

    # Test --html format
    result=$("${CLIP}" --paste --html)
    assert_contains "${result}" "<b>Bold</b>" "clip.exe --html: extracts HTML"
    assert_contains "${result}" "<i>italic</i>" "clip.exe --html: preserves HTML tags"

    # Test --raw format
    "${CLIPIN}" "raw_test_value"
    result=$("${CLIP}" --paste --raw)
    assert_contains "${result}" "raw_test" "clip.exe --raw: returns raw content"
}

test_markdown_output() {
    log_info "Testing markdown output (requires pandoc)..."

    if ! command -v pandoc &>/dev/null; then
        ((TESTS_RUN++))
        log_skip "clip.exe --md: pandoc not installed"
        return
    fi

    # Set up rich clipboard with HTML
    set_rich_clipboard '<h1>Header</h1><p>Paragraph with <strong>bold</strong></p>' 'Header Paragraph with bold'

    local result
    result=$("${CLIP}" --paste --md 2>&1) || true

    # Markdown should have # for header and ** for bold
    assert_contains "${result}" "Header" "clip.exe --md: converts HTML to markdown (header)"
}

test_file_type_detection() {
    log_info "Testing file type detection..."

    local tmpdir
    tmpdir=$(mktemp -d)

    # Test text file
    echo "plain text content" > "${tmpdir}/test.txt"
    local filetype
    filetype=$(file -b --mime-type "${tmpdir}/test.txt")
    assert_contains "${filetype}" "text" "file detection: identifies text file"

    # Test script file
    echo '#!/bin/bash' > "${tmpdir}/test.sh"
    echo 'echo "hello"' >> "${tmpdir}/test.sh"
    filetype=$(file -b --mime-type "${tmpdir}/test.sh")
    assert_contains "${filetype}" "text" "file detection: identifies shell script as text"

    # Test binary file (create a simple one)
    printf '\x00\x01\x02\x03' > "${tmpdir}/test.bin"
    filetype=$(file -b --mime-type "${tmpdir}/test.bin")
    ((TESTS_RUN++))
    if [[ "${filetype}" != *"text"* ]]; then
        log_pass "file detection: identifies binary file as non-text"
    else
        log_fail "file detection: identifies binary file" "Expected non-text, got ${filetype}"
    fi

    rm -rf "${tmpdir}"
}

test_syntax_highlighting() {
    log_info "Testing syntax highlighting (requires pygmentize)..."

    if ! command -v pygmentize &>/dev/null; then
        ((TESTS_RUN++))
        log_skip "syntax highlighting: pygmentize not installed"
        return
    fi

    local tmpfile
    tmpfile=$(mktemp --suffix=.py)
    echo 'print("hello world")' > "${tmpfile}"

    # Test that pygmentize can process the file
    local result
    result=$(pygmentize -l python -f html "${tmpfile}" 2>&1)
    assert_contains "${result}" "span" "pygmentize: generates HTML with spans"
    assert_contains "${result}" "print" "pygmentize: preserves code content"

    rm -f "${tmpfile}"
}

test_rich_text_roundtrip() {
    log_info "Testing rich text clipboard roundtrip..."

    # This tests the full flow: HTML -> clipboard -> read back
    local test_html='<span style="color:red">Red Text</span>'
    set_rich_clipboard "${test_html}" "Red Text"

    # Read back as HTML
    local html_result
    html_result=$("${CLIP}" --paste --html)
    assert_contains "${html_result}" "Red" "rich text roundtrip: HTML preserved"

    # Read back as text
    local text_result
    text_result=$("${CLIP}" --paste --text)
    assert_contains "${text_result}" "Red Text" "rich text roundtrip: plain text extracted"
}

## New Input Format Tests ######################################################

test_input_format_text() {
    log_info "Testing --format text input..."

    local test_value="format_text_$$"
    echo "${test_value}" | "${CLIP}" --format text
    local result
    result=$("${CLIPOUT}")
    assert_contains "${result}" "${test_value}" "clip.exe --format text: copies plain text"
}

test_input_format_html() {
    log_info "Testing --format html input..."

    local test_html='<b>Bold HTML</b>'
    echo "${test_html}" | "${CLIP}" --format html

    # Should be readable as HTML
    local html_result
    html_result=$("${CLIP}" --paste --html)
    assert_contains "${html_result}" "<b>Bold" "clip.exe --format html: copies as rich text (HTML)"

    # Should also have plain text fallback
    local text_result
    text_result=$("${CLIP}" --paste --text)
    assert_contains "${text_result}" "Bold" "clip.exe --format html: has plain text fallback"
}

test_input_format_markdown() {
    log_info "Testing --format markdown input (requires pandoc)..."

    if ! command -v pandoc &>/dev/null; then
        ((TESTS_RUN++))
        log_skip "clip.exe --format markdown: pandoc not installed"
        return
    fi

    local tmpfile
    tmpfile=$(mktemp --suffix=.md)
    cat > "${tmpfile}" << 'EOF'
# Test Header

This is **bold** and *italic* text.

- Item 1
- Item 2
EOF

    "${CLIP}" --file "${tmpfile}" --format markdown

    # Should be readable as HTML (converted from markdown)
    local html_result
    html_result=$("${CLIP}" --paste --html)
    assert_contains "${html_result}" "Test Header" "clip.exe --format markdown: converts header"
    assert_contains "${html_result}" "bold" "clip.exe --format markdown: converts bold"

    rm -f "${tmpfile}"
}

test_input_format_csv() {
    log_info "Testing --format csv input..."

    local tmpfile
    tmpfile=$(mktemp --suffix=.csv)
    cat > "${tmpfile}" << 'EOF'
Name,Age,City
Alice,30,NYC
Bob,25,LA
EOF

    "${CLIP}" --file "${tmpfile}" --format csv

    # Should be readable as CSV
    local csv_result
    csv_result=$("${CLIP}" --paste --csv)
    assert_contains "${csv_result}" "Name" "clip.exe --format csv: preserves header"
    assert_contains "${csv_result}" "Alice" "clip.exe --format csv: preserves data"
    assert_contains "${csv_result}" "NYC" "clip.exe --format csv: preserves values"

    # Should also be readable as text
    local text_result
    text_result=$("${CLIP}" --paste --text)
    assert_contains "${text_result}" "Alice" "clip.exe --format csv: has text fallback"

    rm -f "${tmpfile}"
}

test_input_format_auto() {
    log_info "Testing --format auto detection..."

    local tmpdir
    tmpdir=$(mktemp -d)

    # Test auto-detection of markdown
    cat > "${tmpdir}/test.md" << 'EOF'
# Auto Header
Some text
EOF

    if command -v pandoc &>/dev/null; then
        "${CLIP}" --file "${tmpdir}/test.md"  # auto should detect .md
        local md_result
        md_result=$("${CLIP}" --paste --html)
        assert_contains "${md_result}" "Auto Header" "clip.exe --format auto: detects .md files"
    else
        ((TESTS_RUN++))
        log_skip "clip.exe --format auto (.md): pandoc not installed"
    fi

    # Test auto-detection of csv
    cat > "${tmpdir}/test.csv" << 'EOF'
Col1,Col2
Val1,Val2
EOF

    "${CLIP}" --file "${tmpdir}/test.csv"  # auto should detect .csv
    local csv_result
    csv_result=$("${CLIP}" --paste --csv)
    assert_contains "${csv_result}" "Col1" "clip.exe --format auto: detects .csv files"

    # Test that plain text files stay as text
    echo "plain text file" > "${tmpdir}/test.txt"
    "${CLIP}" --file "${tmpdir}/test.txt"
    local txt_result
    txt_result=$("${CLIPOUT}")
    assert_contains "${txt_result}" "plain text" "clip.exe --format auto: plain text stays plain"

    rm -rf "${tmpdir}"
}

test_highlight_flag() {
    log_info "Testing --highlight flag (requires pygmentize)..."

    if ! command -v pygmentize &>/dev/null; then
        ((TESTS_RUN++))
        log_skip "clip.exe --highlight: pygmentize not installed"
        return
    fi

    local tmpfile
    tmpfile=$(mktemp --suffix=.py)
    cat > "${tmpfile}" << 'EOF'
def hello():
    print("Hello, World!")
EOF

    "${CLIP}" --file "${tmpfile}" --highlight

    # Should have syntax highlighting in HTML
    local html_result
    html_result=$("${CLIP}" --paste --html)
    assert_contains "${html_result}" "<pre style" "clip.exe --highlight: generates styled pre block"
    assert_contains "${html_result}" "color:" "clip.exe --highlight: has syntax coloring"
    assert_contains "${html_result}" "def" "clip.exe --highlight: preserves code"

    # Plain text should still work
    local text_result
    text_result=$("${CLIP}" --paste --text)
    assert_contains "${text_result}" "hello" "clip.exe --highlight: has plain text fallback"

    rm -f "${tmpfile}"
}

test_highlight_with_lang() {
    log_info "Testing --lang flag for explicit language..."

    if ! command -v pygmentize &>/dev/null; then
        ((TESTS_RUN++))
        log_skip "clip.exe --lang: pygmentize not installed"
        return
    fi

    # Use a file without extension, but specify language
    local tmpfile
    tmpfile=$(mktemp)
    echo 'SELECT * FROM users WHERE id = 1;' > "${tmpfile}"

    "${CLIP}" --file "${tmpfile}" --lang sql

    local html_result
    html_result=$("${CLIP}" --paste --html)
    assert_contains "${html_result}" "<pre style" "clip.exe --lang: generates styled pre block"
    assert_contains "${html_result}" "color:" "clip.exe --lang sql: uses specified language"

    rm -f "${tmpfile}"
}

test_highlight_stdin() {
    log_info "Testing --highlight with stdin..."

    if ! command -v pygmentize &>/dev/null; then
        ((TESTS_RUN++))
        log_skip "clip.exe --highlight stdin: pygmentize not installed"
        return
    fi

    echo 'console.log("hello");' | "${CLIP}" --highlight --lang javascript

    local html_result
    html_result=$("${CLIP}" --paste --html)
    assert_contains "${html_result}" "<pre style" "clip.exe --highlight stdin: generates styled pre block"
    assert_contains "${html_result}" "color:" "clip.exe --highlight stdin: has syntax coloring"
    assert_contains "${html_result}" "console" "clip.exe --highlight stdin: preserves content"
}

test_binary_file_rejection() {
    log_info "Testing binary file rejection..."

    local tmpfile
    tmpfile=$(mktemp)
    printf '\x00\x01\x02\x03\x89PNG' > "${tmpfile}"

    local result
    result=$("${CLIP}" --file "${tmpfile}" 2>&1) || true
    ((TESTS_RUN++))
    if [[ "${result}" == *"binary"* ]] || [[ "${result}" == *"cannot copy"* ]]; then
        log_pass "clip.exe: rejects binary files with error message"
    else
        log_fail "clip.exe: rejects binary files" "Expected error about binary file, got: ${result}"
    fi

    rm -f "${tmpfile}"
}

test_language_detection() {
    log_info "Testing language auto-detection..."

    local tmpdir
    tmpdir=$(mktemp -d)

    if ! command -v pygmentize &>/dev/null; then
        ((TESTS_RUN++))
        log_skip "language detection: pygmentize not installed"
        rm -rf "${tmpdir}"
        return
    fi

    # Test Python detection
    echo 'print("hello")' > "${tmpdir}/test.py"
    "${CLIP}" --file "${tmpdir}/test.py" --highlight
    local py_result
    py_result=$("${CLIP}" --paste --html)
    assert_contains "${py_result}" "<pre style" "language detection: .py generates styled pre"
    assert_contains "${py_result}" "color:" "language detection: .py -> python"

    # Test Bash detection
    echo '#!/bin/bash' > "${tmpdir}/test.sh"
    echo 'echo "hello"' >> "${tmpdir}/test.sh"
    "${CLIP}" --file "${tmpdir}/test.sh" --highlight
    local sh_result
    sh_result=$("${CLIP}" --paste --html)
    assert_contains "${sh_result}" "<pre style" "language detection: .sh generates styled pre"
    assert_contains "${sh_result}" "color:" "language detection: .sh -> bash"

    # Test shebang detection for extensionless file
    echo '#!/usr/bin/env python3' > "${tmpdir}/myscript"
    echo 'print("hi")' >> "${tmpdir}/myscript"
    "${CLIP}" --file "${tmpdir}/myscript" --highlight
    local shebang_result
    shebang_result=$("${CLIP}" --paste --html)
    assert_contains "${shebang_result}" "<pre style" "language detection: shebang generates styled pre"
    assert_contains "${shebang_result}" "color:" "language detection: shebang detection"

    rm -rf "${tmpdir}"
}

## Summary #####################################################################

print_summary() {
    echo
    echo "========================================"
    echo "Test Summary"
    echo "========================================"
    echo -e "Tests run:     ${TESTS_RUN}"
    echo -e "Tests passed:  ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests failed:  ${RED}${TESTS_FAILED}${NC}"
    echo -e "Tests skipped: ${YELLOW}${TESTS_SKIPPED}${NC}"
    echo "========================================"
    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        echo -e "${RED}SOME TESTS FAILED${NC}"
        return 1
    else
        echo -e "${GREEN}ALL TESTS PASSED${NC}"
        return 0
    fi
}

## Main ########################################################################

main() {
    echo "========================================"
    echo "Clipboard Utilities Test Suite"
    echo "========================================"
    echo

    check_prerequisites

    # Basic functionality tests
    test_clipout_basic; echo
    test_clipin_basic; echo
    test_clipin_append; echo
    test_clip_copy; echo
    test_clip_paste; echo
    test_special_characters; echo
    test_multiline; echo
    test_large_content; echo
    test_empty_clipboard; echo
    test_clipin_echo; echo
    test_file_input; echo
    test_help_output; echo

    # Output format tests
    test_output_formats; echo
    test_markdown_output; echo
    test_file_type_detection; echo
    test_syntax_highlighting; echo
    test_rich_text_roundtrip; echo

    # Input format tests
    test_input_format_text; echo
    test_input_format_html; echo
    test_input_format_markdown; echo
    test_input_format_csv; echo
    test_input_format_auto; echo

    # Syntax highlighting tests
    test_highlight_flag; echo
    test_highlight_with_lang; echo
    test_highlight_stdin; echo
    test_language_detection; echo

    # Error handling
    test_binary_file_rejection

    print_summary
}

main "$@"

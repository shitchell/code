#!/usr/bin/env bash
#
# Play with bash types, setting up one of each available bash type + a couple
# that aren't strictly bash "types" but are still useful (e.g.: using `true` as
# a boolean type, even though it's just a command that always returns 0).
#
# The `declare` help documents the following types:
# $ help declare
#     -a        to make NAMEs indexed arrays (if supported)
#     -A        to make NAMEs associative arrays (if supported)
#     -i        to make NAMEs have the `integer' attribute
#     -l        to convert the value of each NAME to lower case on assignment
#     -n        make NAME a reference to the variable named by its value
#     -r        to make NAMEs readonly
#     -t        to make NAMEs have the `trace' attribute
#     -u        to convert the value of each NAME to upper case on assignment
#     -x        to make NAMEs export

# include-source shell
include-source colors.sh

# Set up a few variables of each builtin bash type
declare -a my_arr=(one two three "foo bar" $'hello\nworld')
declare -A my_map=([name]="John Smith" [age]=23 ["date of birth"]="2029-01-01")
declare -i my_int=42
declare -l my_lwr="Hello World"
declare -n my_ref=my_int
declare -r my_rdo="Hello World"
declare -t my_trc="Hello World"
declare -u my_upr="Hello World"
declare -x my_exp="Hello World"
declare -- my_str="Hello World"

# Set up a couple of "types" that aren't strictly bash types
declare -- my_str_int="42"
declare -- my_str_bool="true"
declare -- my_str_float="3.14"
declare -- my_str_null=""

# Some combos
declare -xi my_exp_int=42
declare -xr my_exp_rdo="Hello World"
declare -rt my_exp_trc="Hello World"
declare -xt my_exp_exp="Hello World"
declare -ua my_upr_arr=(one two three)

# And a couple more just to see how they're output in `declare -p`
declare -- my_str_multiline='Hello
World'

# Print out the variables
echo "# ${S_BOLD}declare -p${S_RESET}:"
declare -p my_arr my_map my_int my_lwr my_ref my_rdo my_trc my_upr my_exp my_str
declare -p my_exp_int my_exp_rdo my_exp_trc my_exp_exp my_upr_arr
declare -p my_str_int my_str_bool my_str_float my_str_null my_str_multiline
echo

# Print out the values of the variables
echo "# ${S_BOLD}Builtin Values${S_RESET}:"
echo "my_arr:           ${my_arr[@]}"
echo "my_map (keys):    ${!my_map[@]}"
echo "my_map (values):  ${my_map[@]}"
echo "my_int:           ${my_int}"
echo "my_lwr:           ${my_lwr}"
echo "my_ref:           ${my_ref}"
echo "my_rdo:           ${my_rdo}"
echo "my_trc:           ${my_trc}"
echo "my_upr:           ${my_upr}"
echo "my_exp:           ${my_exp}"
echo "my_str:           ${my_str}"
echo

echo "# ${S_BOLD}Combo Values${S_RESET}:"
echo "my_exp_int:       ${my_exp_int}"
echo "my_exp_rdo:       ${my_exp_rdo}"
echo "my_exp_trc:       ${my_exp_trc}"
echo "my_exp_exp:       ${my_exp_exp}"
echo "my_upr_arr:       ${my_upr_arr[@]}"
echo

echo "# ${S_BOLD}Inferred Values${S_RESET}:"
echo "my_str_int:       ${my_str_int}"
echo "my_str_bool:      ${my_str_bool}"
echo "my_str_float:     ${my_str_float}"
echo "my_str_null:      ${my_str_null}"
echo "my_str_multiline: ${my_str_multiline}"

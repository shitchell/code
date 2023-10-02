# Define a function for returning AssetSuite configuration settings
# @usage as-config [<properties file>] <property name>
# @example as-config server.mode
# @example as-config server.mode
function as-config() {
    # Default values
    local key="$"
    local num_results=""
    local do_sort=false
    local runtime_properties_dir="${RUNTIME_PROPERTIES_PATH:-/abb/assetsuite/runtime_config/properties/}"
    local value

    # Process arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            -d|--properties-dir)
                runtime_properties_dir="$2"
                shift 2
                ;;
            -n|--num-results)
                # Check if the value is a number
                if [[ ! "$2" =~ ^[0-9]+$ ]]; then
                    echo "ERROR: The value '$2' is not a number" >&2
                    return 1
                fi
                num_results="$2"
                shift 2
                ;;
            -s|--sort)
                do_sort=true
                shift
                ;;
            *)
                key="$1"
                shift
                ;;
        esac
    done
    
    # Check if the env path exists
    if [[ ! -d "${runtime_properties_dir}" ]]; then
        echo "ERROR: The configuration directory '${runtime_properties_dir}' does not exist" >&2
        return 1
    fi

    # Get the key value(s)
    readarray -t values < <(
        grep --color=never -hRoP "^${key}\s*=\s*.*" "${runtime_properties_dir}"
    )

    # If ${num_results} is not set, set it to the number of values found
    [[ -z "${num_results}" || ${num_results} -gt ${#values[@]} ]] && num_results="${#values[@]}"
    local return_values=()
    for (( i=0; i<${num_results}; i++ )); do
        return_values+=("${values[$i]}")
    done

    if [[ ${#return_values[@]} -eq 1 ]]; then
        # If we are only returning one value, return it without the key
        value="${return_values[0]}"
        value="${value#*=}"
        # Trim leading and trailing whitespace
        value="${value#"${value%%[![:space:]]*}"}"
        echo "${value}"
    elif [[ ${#return_values[@]} -gt 1 ]]; then
        # If we are returning multiple values, return them as an array
        if ${do_sort}; then
            # Sort the values
            printf "%s\n" "${return_values[@]}" | sort | uniq
        else
            printf "%s\n" "${return_values[@]}"
        fi
    else
        return 1
    fi
}

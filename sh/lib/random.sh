# @description Generate <n> random bits
# @usage generate-random-bits [n]
# @attribution https://unix.stackexchange.com/a/157837/538359
function generate-random-bits() {
	local n=${1} rnd=${RANDOM} rnd_bitlen=15
	
	# Verify n is an integer
	if ! [[ "${n}" =~ ^[0-9]+ ]]; then
		echo "error: arg must be an integer" >&2
		return 1
	fi

	# Add more $RANDOM bits to rnd until 
 	while (( rnd_bitlen < n )); do
		rnd=$(( rnd<<15|RANDOM ))
		let rnd_bitlen+=15
	done

	echo $(( rnd>>(rnd_bitlen-n) ))
}

# @description Generate a random number in a range
# @usage random-int
# @usage random-int <max>
# @usage random-int <min> <max>
function random-int() {
    local min=0
    local max=100
    local range
    local num
    
    # If 1 arg is given, set it to the max
    if [[ ${#} -eq 1 ]]; then
        max="${1}"
    elif [[ ${#} -eq 2 ]]; then
        min="${1}"
        max="${2}"
    else
        echo "usage: random-int [[<min>] <max>]" >&2
        return 1
    fi

    # Generate a random number that has enough digits to be in the range
    range=$(( max - min ))
    while [[ ${num} -lt ${range} ]]; do
        num="${num}${RANDOM#0}"
    done

    # Mod the number to be in the range
    num=$(( num % range ))

    # Add the min to the result
    echo $(( num + min ))
}

# @description Pick a random item from a list
# @usage random-choice <arg1> [<arg2> ...]
function random-choice() {
    local args=( "${@}" )
    local index

    case ${#args[@]} in
        0)
            echo "usage: random-choice <arg1> [<arg2> ...]" >&2
            return 1
            ;;
        1)
            echo "${args[0]}"
            ;;
        *)
            index=$(random-int ${#args[@]})
            echo "${args[${index}]}"
            ;;
    esac
}

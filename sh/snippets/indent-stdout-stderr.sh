{
	echo "hello stdout"
	echo "hello stderr" >&2
} 1> >(sed 's/^/  /') 2> >(sed 's/^/  /' >&2)

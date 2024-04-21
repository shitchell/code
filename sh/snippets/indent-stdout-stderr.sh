{ echo "hello stdout"; echo "hello stderr" >&2; } \
    1> >(sed 's/^/  out: /') \
    2> >(sed 's/^/  err: /' >&2)

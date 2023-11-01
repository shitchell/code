awk -v DEBUG="${DEBUG}" '
    # a debug function
    function debug(msg) {
        if (DEBUG == "true" || DEBUG == 1) {
            # Print a timestamp, the file line number, and the message
            printf("[%s] (LN%03d)  %s\n", strftime("%Y-%m-%d %H:%M:%S"), NR, msg) > "/dev/stderr"
        }
    }
'
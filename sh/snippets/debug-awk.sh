awk -v DEBUG="${DEBUG}" -v DEBUG_LOG="${DEBUG_LOG}" '
    # a debug function
    function debug(msg) {
        if (DEBUG == "true" || DEBUG == 1 || DEBUG_LOG) {
            # Determine the log file
            logfile="/dev/stderr"
            if (DEBUG_LOG) {
              logfile=DEBUG_LOG
            }

            # Print a timestamp, the file line number, and the message
            printf("[%s] (LN%03d)  %s\n", strftime("%Y-%m-%d %H:%M:%S"), NR, msg) > logfile
        }
    }
'

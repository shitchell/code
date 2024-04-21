awk -v pipe=$([[ -t 1 ]] && echo y) -v dim=$'\033[2m' -v rst=$'\033[0m' \
    -v DEBUG="${DEBUG}" -v DEBUG_LOG="${DEBUG_LOG}" '
    # a debug function
    function debug(msg) {
        if (DEBUG == "true" || DEBUG == 1 || DEBUG_LOG) {
            # Determine the log file
            logfile="/dev/stderr"
            if (DEBUG_LOG) {
              logfile=DEBUG_LOG
            }

            # Print a timestamp, the file line number, and the message
            printf("%s[%s] (%s:LN%03d)  %s%s\n",
                   dim, strftime("%Y-%m-%d %H:%M:%S"), FILENAME, NR, msg, rst) > logfile
            fflush();
        }
    }
    {
        debug("this is a debug statement");
        print;
    }
' "${@}"

# minor POC
echo "1:23:40" \
    | awk '{
        if ($0 ~ /^[0-9]+:/) {
            hours = gensub(/(([0-9]+):)?([0-9]+:)?([0-9]+)?/, "\\2", "g");
            minutes = gensub(/([0-9]+:)?(([0-9]+):)?([0-9]+)?/, "\\3", "g");
            seconds = gensub(/([0-9]+:)?([0-9]+:)?([0-9]+)?/, "\\3", "g");
            
            if (! minutes) {
                minutes = hours;
                hours = "";
            }
            
            print "hours = " hours;
            print "minutes = " minutes;
            print "seconds = " seconds;
        }
    }'

# convert 1:23:40 or 1:23 to 01:23:40 or 00:01:23
echo $'1:23:40\n1:23' \
    | awk '{
        if ($0 ~ /^[0-9]+:/) {
            hours = gensub(/(([0-9]+):)?([0-9]+:)?([0-9]+)?/, "\\2", "g");
            minutes = gensub(/([0-9]+:)?(([0-9]+):)?([0-9]+)?/, "\\3", "g");
            seconds = gensub(/([0-9]+:)?([0-9]+:)?([0-9]+)?/, "\\3", "g");
            
            if (! minutes) {
                minutes = hours;
                hours = "";
            }
            
            printf("hours = %02i\n", hours);
            printf("minutes = %02i\n", minutes);
            printf("seconds = %02i\n", seconds);
        }
    }'


# fix YT timestamps
echo $'1:23:40\nfoo bar\n1:23\nanother line' \
    | awk '
    BEGIN {
        first_line = 1;
    }
    {
        if ($0 ~ /^[0-9]+:/) {
            hours = gensub(/(([0-9]+):)?([0-9]+:)?([0-9]+)?/, "\\2", "g");
            minutes = gensub(/([0-9]+:)?(([0-9]+):)?([0-9]+)?/, "\\3", "g");
            seconds = gensub(/([0-9]+:)?([0-9]+:)?([0-9]+)?/, "\\3", "g");
            
            if (! minutes) {
                minutes = hours;
                hours = "";
            }
            
            timestamp = sprintf("%02i:%02i:%02i", hours, minutes, seconds);
            
            if (first_line) {
                first_line = "";
            } else {
                print "";
            }
            print timestamp;
        } else {
            print $0;
        }
    }'

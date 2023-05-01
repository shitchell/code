#!/bin/bash

month="${1:-$(date +"%Y-%m")}"

clipout \
  | awk -v month="${month}" '
      BEGIN {
        day = ""
      }

      # Extract the day of the week
      /---- [A-Za-z]{3} [0-9]{1,2} ----/ {
        day = gensub(/.*---- [A-Za-z]{3} ([0-9]{1,2}) ----.*/, "\\1", "1", $0);
      }

      # Extract the hour range and summary
      /[0-9]{4} - [0-9]{4}/ {
        start = gensub(/.{,5}?([0-9]{2})([0-9]{2}) -.*/, month "-" day " \\1:\\2", "1", $0);
        end = gensub(/.{,5}[0-9]{4} - ([0-9]{2})([0-9]{2}).*/, month "-" day " \\1:\\2", "1", $0);
        summary = gensub(/.{,5}[0-9]{4} - [0-9]{4}\s+(.*)/, "\\1", "1", $0);
        type = "";
        # Extract the type
        if (summary ~ /^\([A-Za-z]+\)/) {
          type = gensub(/^\(([^)]+)\).*/, "\\1", "1", summary);
          summary = gensub(/^\([^)]+\) /, "", "1", summary);
        }
        if (type == "iM") {
          type = "iMeet";
        } else if (type == "M") {
          type = "Meeting";
        } else if (type == "D") {
          type = "Development";
        } else if (type == "I") {
          type = "Investigation";
        } else if (type == "T") {
          type = "Toypaj";
        } else if (type == "R") {
          type = "Review";
        } else if (type == "S") {
          type = "Support";
        } else if (type == "Dep") {
          type = "Deployment";
        } else if (type == "dB") {
          type = "Debugging";
        } else if (type == "Doc") {
          type = "Documentation";
        }
        # Check for a description
        if (summary ~ /.*:.*/) {
          details = gensub(/^[^:]+: (.*)/, "\\1", "1", summary);
          summary = gensub(/^([^:]+):.*/, "\\1", "1", summary);
        } else {
          details = "";
        }
        print summary "\t" details "\t\t" type "\t" start "\t" end;
      }
      ' #| clipinout

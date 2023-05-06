for branch in Trinoor-Dev NHSS-Dev PreUAT Test Stage Main; do
    branch="AS9-${branch}"
    printf "\033[1m%17s\033[0m -> " "${branch}"
    date=$(
        git -c color.ui=always log --first-parent -m -1 origin/"${branch}" -- tailored/metadata/runtime/ui/VIEW/PassPortTIMI020-FANN-VIEW.xml
    )
    echo "${date}"
done

## This has been trumped by the updated code/sh/bin/git-md5 command:
git md5 \
    --format="%ad%x09%ref%x09%MD5" \
    origin/AS9-Trinoor-Dev \
    origin/AS9-NHSS-Dev \
    origin/AS9-PreUAT \
    origin/AS9-Test \
    origin/AS9-Main \
    -- "${filepath}" \
        | sed 's|origin/||' \
        | column -s $'\t' -t

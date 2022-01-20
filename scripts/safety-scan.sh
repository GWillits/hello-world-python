fail_action="${1:-"FAIL"}"
report="$(safety check -r requirements.txt --bare)"
num_results=$(echo -n "$report"| wc -w)
if [ $(($num_results)) -gt 0 ]
then
    echo  "$num_results package vulnerabilities discovered. Failing package scan test. Full report:"
    safety check -r requirements.txt --full-report
    if [ "$fail_action" = "FAIL" ]
    then
        echo "failed"
        exit 1
    fi
fi
exit 0

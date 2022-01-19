report="$(make safety-ci)"
num_results=$(echo -n "$report"| wc -w)
if [[ $(($num_results)) -gt 0 ]]
then
    echo  "$num_results package vulnerabilities discovered. Failing package scan test. Full report:"
    poetry run safety check --full-report
    exit 1
fi

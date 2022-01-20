fail_action="${1:-"FAIL"}"
user="${2:-"$(git log -n 1 --pretty=format:%an)"}"
email="${2:-"$(git log -n 1 --pretty=format:%ae)"}"
check_date=${3:-"$(date +'%m/%d/%Y : %X')"}
report="$(safety check -r requirements.txt --bare)"
num_results=$(echo -n "$report"| wc -w)
if [ $(($num_results)) -gt 0 ]
then
    echo  "$num_results package vulnerabilities discovered. Failing package scan test. Full report:"
    safety check -r requirements.txt --full-report
    safety check -r requirements.txt --full-report --json | jq  --arg DATE "$check_date" --arg USER "$user" --arg EMAIL "$email" '. += [{origin:{usr: $USER,email:$EMAIL,date: $DATE} }]' > insecure_report.json
    cat insecure_report.json | jq .
    if [ "$fail_action" = "FAIL" ]
    then
        exit 1
    fi
fi
exit 0

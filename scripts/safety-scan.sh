fail_action="${1:-"FAIL"}"
workspace="${2:-""}"
user="${3:-"$(git log -n 1 --pretty=format:%an)"}"
email="${4:-"$(git log -n 1 --pretty=format:%ae)"}"
check_date=${5:-"$(date +'%m/%d/%Y : %X')"}
check_date_str=${6:-"$(date +'%m.%d.%Y-%H.%M.%S')"}
num_results=$(echo -n "$(safety check -r requirements.txt --bare)"| wc -w)
mkdir -p $artifact_path
if [ $(($num_results)) -gt 0 ]; then
    echo  "$num_results package vulnerabilities discovered. Failing package scan test. Full report:"
    safety check -r requirements.txt --full-report
    # create report
    report_name="insecure_report_${check_date_str}"
    if  [ ! -z "${workspace}"]; then
        artifact_path="$workspace/.github-artifacts"
        jq   --null-input --arg DATE "$check_date" --arg USER "$user" --arg EMAIL "$email" '{origin:{usr: $USER,email:$EMAIL,date: $DATE}} ' | jq --argjson report "$(safety check -r requirements.txt --full-report --json)" '. + {report:$report}' > "${artifact_path}/${report_name}.json"
    fi
    if [ "$fail_action" = "FAIL" ]
    then
        exit 1
    fi
fi
exit 0

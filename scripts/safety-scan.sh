#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2086

#vars
fail_action="${1:-"FAIL"}"
workspace="${2:-"."}"
detail="${3:-"root-"}"
publish_artifacts="${4:-""}"
user="${5:-"$(git log -n 1 --pretty=format:%an)"}"
email="${6:-"$(git log -n 1 --pretty=format:%ae)"}"
check_date=${7:-"$(date +'%m/%d/%Y : %X')"}
check_date_str=${8:-"$(date +'%m.%d.%Y-%H.%M.%S')"}
# parse out those entries we want to ignore
ignores=""
num_ignored=0
while read -r ignored_package || [[ -n $ignored_package ]]; do 
    read -r ignored_code comment <<<"$(IFS="#"; echo "$ignored_package")"
    ignores="$ignores -i $ignored_code"
    ((num_ignored ++))
done <"$workspace/ignored-safety.txt"
num_results=$(safety check -r requirements.txt $ignores --bare | wc -w)

if [ $num_results -gt 0 ]; then
    echo  "$num_results package vulnerabilities discovered. Failing package scan test. Full report:"
    safety check -r requirements.txt --full-report
    # create report
    report_name="${detail}-insecure_report_${check_date_str}"
    if  [ "${publish_artifacts}" ]; then
    echo "publishing artifact ${artifact_path}/${report_name}.json"
        artifact_path="$workspace/.github-artifacts"
        mkdir -p "$artifact_path"
        jq   --null-input --arg DATE "$check_date" --arg USER "$user" --arg EMAIL "$email" '{origin:{usr: $USER,email:$EMAIL,date: $DATE}} ' \
        | jq --argjson report "$(safety check -r requirements.txt --full-report --json)" '. + {report:$report}' > "${artifact_path}/${report_name}.json"
    fi
    if [ "$fail_action" = "FAIL" ]
    then
        exit 1
    fi
    else 
        echo "No new vulnerabilities found. $num_ignored package(s) ignored from global ignore file"
fi
exit 0
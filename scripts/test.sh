fail_action="${1:-"FAIL"}"
if [ "$fail_action" = "FAIL" ]
then
    echo  "package vulnerabilities discovered. Failing package scan test. Full report:"
fi
#!/usr/bin/env bash
tool_check() {
	type -P curl >/dev/null 2>&1 || { echo "ERROR:  curl required and not found"; exit 1; }
	type -P jq >/dev/null 2>&1 || { echo "ERROR:  jq required and not found"; exit 1; }
}
exitScript() { # $1=EXIT_REASON $2=EXIT_DETAILS
	echo -e "$1: $2"
	if [ "$1" == "ERROR" ]; then
		echo -e "\nUSAGE: $(echo $0 | sed -E 's#^.*/##') API_KEY SERVICE_ID RULE_ID_OR_TAG RULE_STATUS"
		echo -e "       where RULE_IDS = RULE_STATUS = log | block | disabled"
		exit 1
	else
		exit 0
	fi
}
printOnSameLine () {
	printf "\r$(echo "$LAST_PRINT" | sed -E 's/./ /g')\r$1"
	LAST_PRINT="$1"
}
checkJson() { # $1=JSON_TO_BE_CHECKED
	TEMP="$(echo $1 | jq -c '.')"
	[[ (("$TEMP" =~ ^\[)&&("$TEMP" =~ \]$))||(("$TEMP" =~ ^\{)&&("$TEMP" =~ \}$)) ]] || exitScript "ERROR" "$2"
}
callApi() { # $1=API_KEY $2=HTTP_METHOD $3=API_PATH $4=JSON_DATA
	if [ "$#" -eq 3 ]; then
		OUTPUT=$(curl -q -s -g -X$2 -H "Fastly-Key: $1" "https://api.fastly.com$3")
	elif [ "$#" -eq 4 ]; then
		OUTPUT=$(curl -q -s -g -X$2 -H "Fastly-Key: $1" -H "Content-Type: application/vnd.api+json" -d "$4" "https://api.fastly.com$3")
	else
		exitScript "ERROR" "callApi expected 3 or 4 arguments and $# were found"
	fi
	checkJson "$OUTPUT" "API call \"$3\" failed"
	# The remaining lines are only relevant for paginated output
	CURRENT_PAGE=$(echo "$OUTPUT" | jq -r '.meta.current_page')
	NEXT_API_PATH=$(echo "$OUTPUT" | jq -r '.links.next' | sed -E 's/^https?:\/\/api\.fastly\.com//')
}
checkApiKey() {
	API_KEY=$1
	[[ "$API_KEY" =~ ^[0-9a-z]{32}$ ]] || exitScript "ERROR" "Unexpected Characters Found in API Key"
	callApi "$API_KEY" "GET" "/current_customer"
	TEMP=$(echo "$OUTPUT" | jq -r '.name')
	[ "$TEMP" == "null" ] && exitScript "ERROR" "Bad API Key specified"
	echo "INFO: Customer Name for Supplied API Key = \"$TEMP\""
}
checkServiceId() {
	SERVICE_ID=$1
	[[ "$SERVICE_ID" =~ ^[0-9a-zA-Z]{21,22}$ ]] || exitScript  "ERROR" "Unexpected Characters Found in Service ID"
	callApi "$API_KEY" "GET" "/service/$SERVICE_ID"
	TEMP=$(echo "$OUTPUT" | jq -r '.name')
	[ "$TEMP" == "null" ] && exitScript "ERROR" "Bad Service ID specified"
	echo "INFO: Service Name for Supplied Service ID = \"$TEMP\""
}
getWafId() {
	callApi "$API_KEY" "GET" "/service/$SERVICE_ID/details"
	TEMP=$(echo "$OUTPUT" | jq -r '.active_version.wafs[0].id')
	[ "$TEMP" == "null" ] && exitScript "ERROR" "No WAF Found in Active Configuration Version"
	WAF_ID="$TEMP"
	echo "INFO: WAF ID = \"$WAF_ID\""
}
checkRuleIdOrTag() {
	callApi "$API_KEY" "GET" "/wafs/rules?filter[rule_id]=$1"
	TEMP=$(echo "$OUTPUT" | jq -r '.meta.record_count')
	[ "$TEMP" -ne "0" ] && RULE_ID="$1" || RULE_ID=""
	callApi "$API_KEY" "GET" "/wafs/rules?filter[tags][name]=$1&page[size]=1"
	TEMP=$(echo "$OUTPUT" | jq -r '.meta.record_count')
	[ "$TEMP" -ne "0" ] && RULE_TAG="$1" || RULE_TAG=""
	[[ ("$RULE_ID" == "") && ("$RULE_TAG" == "") ]] && exitScript "ERROR" "Value \"$1\" is neither a Rule ID nor a Tag"
	# The following should never happen, but just in case...
	[[ ("$RULE_ID" != "") && ("$RULE_TAG" != "") ]] && exitScript "ERROR" "Value \"$1\" is both a Rule ID and a Tag"
	[ "$RULE_ID" != "" ] && echo "INFO: Argument \"$RULE_ID\" is a Rule ID"
	[ "$RULE_TAG" != "" ] && echo "INFO: Argument \"$RULE_TAG\" is a Rule Tag"
}
checkRuleStatus() {
	RULE_STATUS=$1
	[[ "$RULE_STATUS" =~ ^(log)|(block)|(disabled)$ ]] || exitScript "ERROR" "Bad Rule Status specified"
}
setRuleStatusById() {
	callApi "$API_KEY" "GET" "/service/$SERVICE_ID/wafs/$WAF_ID/rules/$RULE_ID/rule_status"
	TEMP=$(echo "$OUTPUT" | jq -r '.data.attributes.status')
	[ "$TEMP" != "null" ] && exitScript "INFO" "Rule ID \"$RULE_ID\" already in ruleset and set to \"$TEMP\""
	DATA="{\"data\":{\"attributes\":{\"status\":\"$RULE_STATUS\"},\"id\":\"$WAF_ID-$RULE_ID\",\"type\":\"rule_status\"}}"
	callApi "$API_KEY" "PATCH" "/service/$SERVICE_ID/wafs/$WAF_ID/rules/$RULE_ID/rule_status" "$DATA"
}
setRuleStatusByTag() {
	DATA="{\"data\":{\"attributes\":{\"status\":\"$RULE_STATUS\",\"name\":\"$RULE_TAG\",\"force\":true},\"type\":\"rule_status\"}}"
	callApi "$API_KEY" "POST" "/service/$SERVICE_ID/wafs/$WAF_ID/rule_statuses" "$DATA"
}
patchRuleset() {
	DATA="{\"data\":{\"id\":\"$WAF_ID\",\"type\":\"ruleset\"}}"
	callApi "$API_KEY" "PATCH" "/service/$SERVICE_ID/wafs/$WAF_ID/ruleset" "$DATA"
	HREF_LINK=$(echo "$OUTPUT" | jq -r '.links.related.href' | sed -E 's/^https?:\/\/api\.fastly\.com//')
	[ "$HREF_LINK" == "null" ] && exitScript "ERROR" "Bad result returned (.links.related.href value not found)"
}
checkUpdateStatuses() {
	ATTEMPT=0
	ELAPSED_TIME=0
	SLEEP_TIME=0
	MAX_TIME="300"
	STATUS=""
	WAIT_MSG="Waiting for \"update_statuses\" call to return \"complete\""
	while [ "$STATUS" != "complete" ]
	do
		[ "$SLEEP_TIME" -ne "0" ] && printOnSameLine "$WAIT_MSG (Attempt $ATTEMPT / Delay ${SLEEP_TIME}s)"
		sleep $SLEEP_TIME
		(( ELAPSED_TIME += SLEEP_TIME ))
		if [ "$ELAPSED_TIME" -lt "10" ]; then
			SLEEP_TIME="1"
		elif [ "$ELAPSED_TIME" -lt "60" ]; then
			SLEEP_TIME="5"
		elif [ "$ELAPSED_TIME" -lt "120" ]; then
			SLEEP_TIME="10"
		elif [ "$ELAPSED_TIME" -lt "$MAX_TIME" ]; then
			SLEEP_TIME="30"
		else
			printOnSameLine ""
			exitScript "ERROR" "\"update_statuses\" call failed to return \"complete\" within $MAX_TIME seconds" 
		fi
		callApi "$API_KEY" "GET" "$HREF_LINK"
		STATUS=$(echo "$OUTPUT" | jq -r '.data.attributes.status')
		(( ATTEMPT += 1 ))
	done
	printOnSameLine ""
}
### HERE THERE BE MAIN CODE ###
[ "$#" -ne 4 ] && exitScript "ERROR" "4 arguments expected, $# found"
tool_check
checkApiKey "$1"
checkServiceId "$2"
getWafId
checkRuleIdOrTag "$3"
checkRuleStatus "$4"
[ "$RULE_ID" != "" ] && setRuleStatusById
[ "$RULE_TAG" != "" ] && setRuleStatusByTag
patchRuleset
checkUpdateStatuses
[ "$RULE_ID" != "" ] && echo "INFO: WAF Rule with ID=\"$RULE_ID\" successfully set to \"$RULE_STATUS\""
[ "$RULE_TAG" != "" ] && echo "INFO: WAF Rule(s) with TAG=\"$RULE_TAG\" successfully set to \"$RULE_STATUS\""
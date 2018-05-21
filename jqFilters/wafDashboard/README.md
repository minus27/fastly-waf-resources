# WAF Dashboard `jq` Filter
This `jq` filter file takes the rule status information for a Fastly WAF object and extracts the following information:
* WAF status
* Counts of rules in the following categories:
 * OWASP Counter Rules (Rule ID = 9\*)
 * OWASP Threshold Rules (Rule ID = 101\*)
 * Trustwave SLR App-Specific Rules (Rule ID = 2\*)
 * Fastly Internal Rules (Rule ID = 2\* or 100\*)

## Requirements
- a Fastly WAF and the ability to query its rule statuses

## Installation
- Download the `wafDashboard.jq` and save it somewhere easy to access

## Usage
```
$ cat ~/.curlrc
-s
-g
-H "Fastly-Key: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
-H "Accept: application/vnd.api+json"
$ curl https://api.fastly.com/wafs/WAF_ID?include=rule_statuses | jq -rf wafDashboard.jq
WAF Status: Active
Total Active Rules: 422
OWASP Counter Rules:
	Enabled: 257
	Disabled: 0
	Total: 257
OWASP Threshold Rules:
	Blocking: 8
	Logging: 0
	Disabled: 1
	Total: 9
Trustwave SLR App-Specific Rules:
	Blocking: 152
	Logging: 0
	Disabled: 70
	Total: 222
Fastly Internal Rules:
	Blocking: 4
	Logging: 1
	Disabled: 0
	Total: 5
Total Rules: 493
$
```

### Additional Note(s)
- information on the API call can be found here:
https://docs.fastly.com/api/waf#waf_firewall_a052dd8302941b4b3885fdad2978bc0a
- the `curl` command line tool is required for API calls
- the `jq` command line tool is required for JSON data filtering

## To Do's
- None

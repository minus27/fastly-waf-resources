select(has("included")) |
"WAF Status: \(
	if (.data.attributes.disabled) == true then "Inactive" else "Active" end
)
Total Active Rules: \(
	[
		.included[] | select((.type == "rule_status") and (.attributes.status != "disabled"))
	] | length
)
OWASP Counter Rules:
\tEnabled: \(
	[
		.included[] | select((.type == "rule_status") and (.attributes.modsec_rule_id|startswith("9")) and (.attributes.status != "disabled"))
	] | length
)
\tDisabled: \(
	[
		.included[] | select((.type == "rule_status") and (.attributes.modsec_rule_id|startswith("9")) and (.attributes.status == "disabled"))
	] | length
)
\tTotal: \(
	[
		.included[] | select((.type == "rule_status") and (.attributes.modsec_rule_id|startswith("9")))
	] | length
)
OWASP Threshold Rules:
\tBlocking: \(
	[
		.included[] | select((.type == "rule_status") and (.attributes.modsec_rule_id|startswith("101")) and (.attributes.status == "block"))
	] | length
)
\tLogging: \(
	[
		.included[] | select((.type == "rule_status") and (.attributes.modsec_rule_id|startswith("101")) and (.attributes.status == "log"))
	] | length
)
\tDisabled: \(
	[
		.included[] | select((.type == "rule_status") and (.attributes.modsec_rule_id|startswith("101")) and (.attributes.status == "disabled"))
	] | length
)
\tTotal: \(
	[
		.included[] | select((.type == "rule_status") and (.attributes.modsec_rule_id|startswith("101")))
	] | length
)
Trustwave SLR App-Specific Rules:
\tBlocking: \(
	[
		.included[] | select((.type == "rule_status") and (.attributes.modsec_rule_id|startswith("2")) and (.attributes.status == "block"))
	] | length
)
\tLogging: \(
	[
		.included[] | select((.type == "rule_status") and (.attributes.modsec_rule_id|startswith("2")) and (.attributes.status == "log"))
	] | length
)
\tDisabled: \(
	[
		.included[] | select((.type == "rule_status") and (.attributes.modsec_rule_id|startswith("2")) and (.attributes.status == "disabled"))
	] | length
)
\tTotal: \(
	[
		.included[] | select((.type == "rule_status") and (.attributes.modsec_rule_id|startswith("2")))
	] | length
)
Fastly Internal Rules:
\tBlocking: \(
	[
		.included[] | select((.type == "rule_status") and (.attributes.modsec_rule_id|(startswith("4") or startswith("100"))) and (.attributes.status == "block"))
	] | length
)
\tLogging: \(
	[
		.included[] | select((.type == "rule_status") and (.attributes.modsec_rule_id|(startswith("4") or startswith("100"))) and (.attributes.status == "log"))
	] | length
)
\tDisabled: \(
	[
		.included[] | select((.type == "rule_status") and (.attributes.modsec_rule_id|(startswith("4") or startswith("100"))) and (.attributes.status == "disabled"))
	] | length
)
\tTotal: \(
	[
		.included[] | select((.type == "rule_status") and (.attributes.modsec_rule_id|(startswith("4") or startswith("100"))))
	] | length
)
Total Rules: \(
	.included | length
)"
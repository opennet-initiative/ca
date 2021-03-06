#!/bin/bash

#
# Opennet CSR Scripts 
# Mathias Mahnke, created 2013/12/29
# Opennet Admin Group <admin@opennet-initiative.de>
#

# stop on error and unset variables
set -eu

# config file
CSR_CFG=opennetcsr.cfg

# get current script dir
CSR_HOME="$(dirname $(readlink -f "$0"))"

# read variables
. "$CSR_HOME/$CSR_CFG"

# build CSR variables
CSR_JSON_FILES="$CSR_HOME/$CSR_UPLOADDIR/*.json"

# retrieve requested action 
ACTION=help
[ $# -gt 0 ] && ACTION="$1" && shift

#
case "$ACTION" in
	--public)
		OUTPUT_HIDE=true
		;;
	--private)
		OUTPUT_HIDE=false
		;;
	help|--help)
		echo "Usage: $(basename "$0")"
		echo "	--public   - generate public html page (exclude names and e-mail)"
		echo "	--private  - generate private html page (include names and e-mail)"
		echo "	help       - show this help"
		exit 0
		;;
	*)
		echo >&2 "Invalid action: $ACTION"
		"$0" >&2 help
		exit 1
		;;
 esac

# page header
echo "<html>"
echo "<head>"
echo "<title>Opennet CA - Certificate Signing Request Listing</title>"
echo "<script type=\"text/javascript\">"
echo "  function toggle(control) {"
echo "    var elem = document.getElementById(control);"
echo "    if(elem.style.display == \"none\") {"
echo "      elem.style.display = \"block\";"
echo "    } else {"
echo "      elem.style.display = \"none\";"
echo "    }"
echo "  }"
echo "</script>"
echo "</head>"
echo "<body>"
echo "<h1>Opennet Certification Authority</h1>"
echo "<h2>CSR Status</h2>"

# table header
echo "<table border=1 cellspacing=0 cellpadding=2>"
echo "<tr>"
echo "<th>No.</th>"
echo "<th>Status</th>"
echo "<th>CA</th>"
echo "<th>Timestamp</th>"
echo "<th>Node</th>"
echo "<th>Name</th>"
echo "<th>Advisor (opt)</th>"
echo "<th>Metadata</th>"
echo "<th>Action</th>"
echo "</tr>"

# calculate number of table rows
counter=$(( $(ls -l $CSR_JSON_FILES | grep -v ^l | wc -l) +1))

# table body
declare -A output
while read -r line
do
	# parse json fields
	IFS=":" data=($line)
	key=${data[0]}
	value=""
	[ "${#data[@]}" -gt 1 ] && value=${data[1]}
	value=$(sed -e 's/^[[:space:]]*//' <<<"$value")
	output["$key"]="${value##*( )}"
	# fill table
	case "$key" in
		"{") counter=$((counter -1)) && echo -e "<tr>\n<td>$counter</td>" && declare -A output
			;;
		"status") 
			case $value in
				"CSR"|"Error") output["action"]="<a href=\"csr_approve.php?${output["name"]}\">Approve CSR</a>"
					;;
				"Signed"|"RevokeError") output["action"]="<a href=\"revoke_approve.php?${output["name"]}\">Revoke Cert</a>"
					;;
				*) output["action"]=""
					;;
			esac
			;;
		"}") echo -e "<td>${output["status"]}</td>\n<td>${output["cn_filter"]}</td>\n</td>\n<td>$(date -d @"${output["upload_timestamp"]}" "+%Y-%m-%d")</td>\n<td>${output["subject_cn"]}</td>" && if "$OUTPUT_HIDE"; then echo -e "<td><i>hidden</i></td>\n<td><i>hidden</i></td>\n<td><i>hidden</i></td>\n<td><i>disabled</i></td>"; else echo -e "<td>${output["subject_o"]}</td>\n<td>${output["upload_advisor"]}</td>\n<td><a href=\"javascript:toggle('json_${output["name"]}')\"><small>(Show or hide JSON)</small></a><div id=\"json_${output["name"]}\" style=\"display:none\"><pre>$(jq --sort-keys . $CSR_HOME/$CSR_UPLOADDIR/${output["name"]}.csr.json)</pre></div></td>\n</td>\n<td>${output["action"]}</td>\n</tr>"; fi
			;;
	esac
done < <({ echo -n "["; for f in $CSR_JSON_FILES; do cat $f; echo -n ","; done; echo -n "]"; echo; } | sed 's/,]$/]/' | jq --sort-keys 'sort_by(.upload_timestamp) | reverse | .[]' | sed -e 's/"//g' -e 's/,$//' -e 's/  //g') 

# table footer
echo "</table>"

# page footer
cat <<-EOF
	<p>Last Update: $(date)</p>
	<p>Back to <a href="../">Opennet CA</a>.</p>
	<p><img src="/Opennet_logo_quer.gif"></p>
	</body>
	</html>
EOF

exit 0 

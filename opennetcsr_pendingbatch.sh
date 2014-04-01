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
	--list)
		MAIL=false
		;;
	--mail)
		MAIL=true
		;;
	help|--help)
		echo "Usage: $(basename "$0")"
		echo "  --list  - show pending signing/revoke requests (mail dry run)"
		echo "  --mail  - mail pending signing/revoke requests"
		echo "  help    - show this help"
		exit 0
		;;
	*)
		echo >&2 "Invalid action: $ACTION"
		"$0" >&2 help
		exit 1
		;;
	esac

# process action
counter=0
declare -A output
mailtext=""
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
		"{") 
			counter=$((counter +1)) && declare -A output
			;;
		"}")
			# process csr (any action)
			echo "Found ${output["name"]} (${output["cn_filter"]})"
			# prepare mailing (if action choosen)
			if "$MAIL"; then
				mailtext="$mailtext\n${output["name"]} (${output["status"]})" 
			fi
			;;
	esac
done < <({ echo -n "["; for f in $CSR_JSON_FILES; do cat $f; echo -n ","; done; echo -n "]"; echo; } | sed 's/,]$/]/' | jq 'sort_by(.upload_timestamp) | .[] | select(.status!="Signed" and .status!="Revoked")' | sed -e 's/"//g' -e 's/,$//' -e 's/  //g') 

# send mail
if "$MAIL"; then
	if [ "$counter" -gt 0 ]; then
		echo -n "Send mail to '$CSR_MAILTO'... "	
		mailtext="$CSR_MAILTEXT_PENDING\n$mailtext\n\nview: <$CSR_WEBINTERNAL>\n\n$CSR_MAILFOOTER"
		echo -e "$mailtext" | mailx -s "$CSR_MAILSUBJECT_PENDING" "$CSR_MAILTO" && echo "done." || "failed."
	else
		echo "No pending requests. No mail send."
	fi
fi

echo "$counter pending CSR processed"

exit 0 

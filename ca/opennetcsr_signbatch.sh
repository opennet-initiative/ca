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
		SIGN=false
		;;
	--sign)
		SIGN=true
		;;
	help|--help)
		echo "Usage: $(basename "$0")"
		echo "  --list  - show approved signing requests (sign dry run)"
		echo "  --sign  - sign approved signing requests"
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
			# start signing (if action choosen)
			if "$SIGN"; then
				echo -n "Signing... "
				signcmd="$CSR_CAPATH/${output["cn_filter"]}/sign_batch.sh"
				# invoke sign script, redirect output
				exec 3>&1
				error=false
				errmsg="$($signcmd ${output["name"]} ${output["upload_ccmail"]} 2>&1 1>&3)" || error=true
				exec 3>&-
				# filter first line of output and trimm
				errmsg="$(echo -e $errmsg | head -n1 | xargs)"
				timestamp=$(date +%s)
				# check for sign result, prepare new json vars
				if "$error";
				then
					echo "failed."
					echo "$errmsg (${output["name"]})">&2
					jqcmd=".status=\"Error\" | .error_message=\"$errmsg\" | .error_timestamp=\"$timestamp\""
					# send error via mail
					echo -n "Send mail to '$CSR_MAILTO'... "
					mailtext="$CSR_MAILTEXT_SIGN\n\nname: ${output["name"]}\nerror: $errmsg\n\n$CSR_MAILFOOTER" 
					echo -e "$mailtext" | mailx -s "$CSR_MAILSUBJECT_SIGN" "$CSR_MAILTO" && echo "done." || "failed."
				else
					echo "done."
					jqcmd=".status=\"Signed\" | .sign_message=\"$0\" | .sign_timestamp=\"$timestamp\""
				fi
				# report new status to csr-json file
				jsonfile="$CSR_CAPATH/${output["cn_filter"]}/csr/${output["name"]}.csr.json"
				umask 0002
				jq "$jqcmd" "$jsonfile" > "$jsonfile-$timestamp"
				chgrp www-data "$jsonfile-$timestamp"
				mv "$jsonfile-$timestamp" "$jsonfile"
			fi
			;;
	esac
done < <({ echo -n "["; for f in $CSR_JSON_FILES; do cat $f; echo -n ","; done; echo -n "]"; echo; } | sed 's/,]$/]/' | jq 'sort_by(.upload_timestamp) | .[] | select(.status=="Approved")' | sed -e 's/"//g' -e 's/,$//' -e 's/  //g') 

echo "$counter approved CSR processed"

exit 0 

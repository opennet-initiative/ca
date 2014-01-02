#!/bin/bash

#
# Opennet CA Scripts 
# Mathias Mahnke, created 2013/12/29
# Lars Kurse, modified 2013/12/30
# Opennet Admin Group <admin@opennet-initiative.de>
#

# stop on error and unset variables
set -eu

# config file
CA_CFG=opennetca.cfg

# get current script dir
CA_HOME="$(dirname $(readlink -f "$0"))"

# read variables
. "$CA_HOME/$CA_CFG"

# build CA variables
CA_BASE="$(basename $CA_HOME)"
CA_INDEX_FILE="$CA_HOME/$CA_INDEXFILE"

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
echo "<title>Opennet CA - Certificate Listing $CA_BASE</title>"
echo "</head>"
echo "<body>"
echo "<h1>Opennet Certification Authority</h1>"
echo "<h2>$CA_BASE CA</h2>"

# table header
echo "<table border=1 cellspacing=0 cellpadding=2>"
echo "<tr>"
echo "<th>No.</th>"
echo "<th>Status</th>"
echo "<th>Valid until</td>"
echo "<th>Serial</td>"
echo "<th>Name</td>"
echo "<th>Node</td>"
echo "<th>Mail</td>"
echo "</tr>"

# table body
counter=0
while read line           
do           
	counter=$((counter +1))
	# replace SPACE+/+SAPCE with single space
	input=${line// \/ / }
	# replace SPACE with html encoding
        input=${input// /&nbsp;}
	# replace TAB with / to pepare output array
	input=${input//	/\/}
	# populate output array by / delimiter
	output=(${input//\// })
	# prepare cert status 
	cert_status=${output[0]//V/Signed}
	cert_status=${cert_status//R/Revoked}
	# prepare cert valid
	if [ "$cert_status" == "Revoked" ]
	then
		cert_valid=${output[2]//Z/}
	else
		cert_valid=${output[1]//Z/}
	fi
	cert_valid="20${cert_valid:0:2}-${cert_valid:2:2}-${cert_valid:4:2}"
	# prepare cert diff in days
	cert_diff=$(((`date -u -d "${cert_valid}" "+%s"` - `date -u "+%s"`)/86400))
	# prepare cert serial
	if [ "$cert_status" == "Revoked" ]
	then
		cert_serial=${output[3]}
	else
		cert_serial=${output[2]}
	fi
	# prepare cert DN parts -> O / SN / mail
	cert_o=""
	cert_cn=""
	cert_mail=""
	for field in "${output[@]}"
	do
		if [[ "$field" =~ "=" ]]
		then
			data=(${field//=/ })
			key=${data[0]}
			value=${data[1]}
			case "$key" in
				O) cert_o="$value"
					;;
				CN) cert_cn="$value"
					;;
				emailAddress) cert_mail="$value"
					;;
			esac
		fi	
	done
	# generate html table output
	echo "<tr>"
	echo "<td>$counter</td>"
	echo "<td>$cert_status</td>"
	echo "<td>$cert_valid ($cert_diff days)</td>"
	echo "<td>$cert_serial</td>"
	echo "<td>$cert_cn</td>"
	if "$OUTPUT_HIDE"
	then
		echo "<td><i>hidden</i></td>"
		echo "<td><i>hidden</i></td>"
	else
		echo "<td>$cert_o</td>"
		echo "<td>$cert_mail</td>"
	fi
	echo "</tr>"
done <"$CA_INDEX_FILE"

# table footer
echo "</table>"

# page footer
cat <<-EOF
	<p>Last Update: $(date)</p>
	<p>Back to <a href="/">Opennet CA</a>.</p>
	<p><img src="Opennet_logo_quer.gif"></p>
	</body>
	</html>
EOF

exit 0


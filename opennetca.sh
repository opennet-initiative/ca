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
CA_LOG=opennetca.log

# get current script dir
CA_HOME="$(dirname $(readlink -f "$0"))"

# read variables
. "$CA_HOME/$CA_CFG"

# build CA directories variables
CA_BACKUP_DIR="$CA_HOME/$CA_BACKUPDIR"
CA_CSR_DIR="$CA_HOME/$CA_CSRDIR"
CA_CERT_DIR="$CA_HOME/$CA_CERTDIR"

# build CA files variables
CA_CONFIG_FILE="$CA_HOME/$CA_CONFIG"
CA_INDEX_FILE="$CA_HOME/$CA_INDEXFILE"
CA_SERIAL_FILE="$CA_HOME/$CA_SERIALFILE"
CA_CRL_FILE="$CA_HOME/$CA_CRLDIR/$CA_CRLNAME"

# generate random serial for CA_SERIAL_FILE
get_random_serial() {
	hexdump -n8 -e '/1 "%02X"' /dev/random
}

# parse CN from openssl subject string
get_cn_from_subject() {
	local subject="$1"
	# populate output array by / delimiter
	local output=(${subject//\// })
	# iterate array to find CN
	local field
	for field in "${output[@]}"
	do
		if [[ "$field" =~ "=" ]]
		then
			local data=(${field//=/ })
			local key="${data[0]}"
			# CN found, return the value
			[ "$key" = "CN" ] && echo "${data[1]}" && return
		fi
	done
	# CN not found, return empty string
	echo ""
}

# match string containment against array
match_string_array() {
	local string="$1"
	local stringarray="$2"
	# populate output array by / delimiter
        local output=(${stringarray// / })
	local field
        for field in "${output[@]}"
        do
		# string matched
		[[ "$string" =~ "$field" ]] && echo "matched $string to $field" && return 
	done
	# string unmatched
	echo "unmatched"
}

# copy timestamped file to CA_BACKUP_DIR 
backup_file() {
	local src_file="$1"
	local now="$(date "+%Y%m%d-%H%M%S")"
	# insert the current timestamp just before the dot of the file extension 
        # (foo.csr -> foo_20131231-235959.csr)
	local dest_file="$(basename "$src_file" | sed "s/\(\.[A-Za-z0-9]\+\)$/_$now\1/")"
	# non-critical error: source and target are identical (sed expression above failed?)
	[ "$src_file" = "$dest_file" ] && echo >&2 "Backup of file '$src_file' failed: invalid target file ($dest_file)" && return 0
	# non-critical error: the source file is missing
	[ ! -e "$src_file" ] && return 0
	cp "$src_file" "$CA_BACKUP_DIR/$dest_file"
}

# retrieve requested action 
ACTION=help
[ $# -gt 0 ] && ACTION="$1" && shift

# sign cert, revoke cert, generate crl or help
case "$ACTION" in
	sign)
		CSR_FILE="$CA_CSR_DIR/$1.csr"
		CERT_FILE="$CA_CERT_DIR/$1.crt"
		[ ! -e "$CSR_FILE" ] && echo >&2 "Error - CSR file not found: $CSR_FILE" && exit 2
		#[ -e "$CERT_FILE" ] && echo >&2 "Error - CRT file already exists: $CERT_FILE" && exit 3
		CSR_SUBJECT="$(openssl req -subject -noout -in $CSR_FILE)"
		CSR_CN="$(get_cn_from_subject $CSR_SUBJECT)"
		CSR_MATCH="$(match_string_array "$CSR_CN" "$CA_CSRCN")"
		echo "cn = $CSR_CN"
		echo "ca = $CA_CSRCN"
		echo "match = $CSR_MATCH"
		[ "$CSR_MATCH" = "unmatched" ] && echo >&2 "Error - CSR CN filter mismatch, found $CSR_CN, need $CA_CSRCN" && exit 4
		CERT_SERIAL="$(get_random_serial)"
		echo "$CERT_SERIAL" > "$CA_SERIAL_FILE"
		openssl ca -config "$CA_CONFIG_FILE" -in "$CSR_FILE" -out "$CERT_FILE"
		backup_file "$CSR_FILE"
		backup_file "$CERT_FILE"
		backup_file "$CA_INDEX_FILE"
		echo "$(date): $CA_CSR_DIR/$1.csr signed, serial $CERT_SERIAL" >> "$CA_HOME/$CA_LOG"
		;;
	revoke)
		CERT_FILE="$CA_CERT_DIR/$1.crt"
		[ ! -e "$CERT_FILE" ] && echo >&2 "Error - CRT file not found: $CERT_FILE" && exit 2
		echo "ATTENTION - this action can not been reverted."
		echo "Are you sure to revoke $CERT_FILE (yes/no)? "
		read REPLY
		[ "$REPLY" != "yes" ] && echo "Revocation aborted." && exit 0
		openssl ca -config "$CA_CONFIG_FILE" -revoke "$CERT_FILE"
		backup_file "$CERT_FILE"
		backup_file "$CA_INDEX_FILE"
		echo "$(date): $CA_CERT_DIR/$1.crt revoked" >> "$CA_HOME/$CA_LOG"	
		;;
	crl)
		openssl ca -config "$CA_CONFIG_FILE" -gencrl -out "$CA_CRL_FILE"
		backup_file "$CA_CRL_FILE"
		backup_file "$CA_INDEX_FILE"
		;;
	help|--help)
		echo "Usage: $(basename "$0")"
		echo "	sign CSR_NAME     - sign a certificate request"
		echo "	revoke CERT_NAME  - revoke a certificate"
		echo "	crl               - generate revocation list"
		echo "	help              - show this help"
		;;
	*)
		echo >&2 "Invalid action: $ACTION"
		"$0" >&2 help
		exit 1
		;;
 esac

exit 0


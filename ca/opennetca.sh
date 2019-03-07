#!/bin/bash

#
# Opennet CA Scripts 
# Mathias Mahnke, created 2013/12/29
# Lars Kurse, modified 2013/12/30
# Opennet Admin Group <admin@opennet-initiative.de>
#

# stop on error and unset variables
set -eu

# get current script dir
CA_HOME="$(dirname $(readlink -f "$0"))"

# config file
CA_CFG="$CA_HOME/opennetca.cfg"
CA_LOG="$CA_HOME/opennetca.log"

# read variables
. "$CA_CFG"

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
	local serial="*"
	# loop until valid serial found
	while [[ "$serial" =~ "*" ]]; do
		serial="$(hexdump -n8 -e '/1 "%02X"' /dev/random)"
	done
	echo "$serial"
}

# provide normalized openssl subject string
get_subject_from_openssl() {
	local file="$1"
  local command="$2"
	# get subject from file via openssl
	local input="$(openssl $command -subject -noout -in $file)"
	# normalize output (remove whitespaces, use / as delimiter)
	local norm="${input// = /=}"
	local output="${norm//, //}"
	echo "$output"
}

# provide normalized openssl request subject string from csr
get_subject_from_cert() {
  local cert="$1"
  # get subject from csr via openssql-req 
  local req_input="$(openssl  -subject -noout -in $cert)"
  # normalize output (remove whitespaces, use / as delimiter)
  local req_norm="${req_input// = /=}"
  local req_output="${req_norm//, //}"
  echo "$req_output"
}

# parse key-value from openssl subject string
get_key_from_subject() {
	local subject="$1"
	local searchkey="$2"
	# populate output array by / delimiter
	local output=(${subject//\// })
	# iterate array to find key
	local field
	for field in "${output[@]}"
	do
		if [[ "$field" =~ "=" ]]
		then
			local data=(${field//=/ })
			local key="${data[0]}"
			# key found, return the value
			[ "$key" = "$searchkey" ] && echo "${data[1]}" && return
		fi
	done
	# key not found, return empty string
	echo ""
}

# match string containment against array
match_string_in_array() {
	local string="$1"
	local stringarray="$2"
	# populate output array by / delimiter
	local output=(${stringarray// / })
	local field
	for field in "${output[@]}"
	do
		[[ "$string" =~ "$field" ]] && return 0 
	done
	return 1
}

# match string containment against file and return filtered lines
match_string_in_file() {
	local string="$1"
	local file="$2"
	local exclude="$3"
	local lines
	echo "$(grep -F "$string" "$file" | grep -v "$exclude")"
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

# compose and send out a mail with attachment
send_mail() {
	local from="$1"
	local to="$2"
	local cc="$3"
	local subject="$4"
	local message="$5"
	local file="$6"
	local filename="$(basename $file)"
	echo -n "Send mail to '$to'... "
	echo -e "$message" | EMAIL="$from" mutt -s "$subject" -a "$file" -c "$cc" -- "$to" && echo "done." || echo "failed."
}

# retrieve requested action 
ACTION=help
[ $# -gt 0 ] && ACTION="$1" && shift
# retrieve ccmail address if provided
CCMAIL=""
[ $# -gt 1 ] && CCMAIL="$2"

# sign cert, revoke cert, generate crl or help
case "$ACTION" in
	sign|sign_batch)
		CSR_FILE="$CA_CSR_DIR/$1.csr"
		CERT_FILE="$CA_CERT_DIR/$1.crt"
		[ ! -e "$CSR_FILE" ] && echo >&2 "Error - CSR file not found: $CSR_FILE" && exit 2
		CSR_SUBJECT="$(get_subject_from_openssl "$CSR_FILE" req)"
		CSR_CN="$(get_key_from_subject "$CSR_SUBJECT" "CN")"
		CSR_MAIL="$(get_key_from_subject "$CSR_SUBJECT" "emailAddress")"
		CSR_MATCH="$(match_string_in_file "=$CSR_CN" "$CA_INDEX_FILE" "^R")"
		[ -n "$CSR_MATCH" ] && echo -e >&2 "Error - CSR CN found in certificate list, revoke old cert first:\n$CSR_MATCH" && exit 3;
		[ -e "$CERT_FILE" ] && echo >&2 "Error - CRT file already exists: $CERT_FILE, same cert signed or revoked?; if new and unsigned check your CSR filename" && exit 4
		match_string_in_array "$CSR_CN" "$CA_CSRCN" || { echo >&2 "Error - CSR CN filter mismatch, found '$CSR_CN', need '$CA_CSRCN'" && exit 5; }
		CERT_SERIAL="$(get_random_serial)"
		echo "$CERT_SERIAL" > "$CA_SERIAL_FILE"
		BATCH_CMD=""
		[ "$ACTION" = "sign_batch" ] && BATCH_CMD="-batch"
		openssl ca $BATCH_CMD -config "$CA_CONFIG_FILE" -in "$CSR_FILE" -out "$CERT_FILE" || { echo >&2 "Error - Aborted OpenSSL Signing, Error Code $?" && rm "$CERT_FILE"; exit 6; }
		[ ! -s "$CERT_FILE" ] && echo >&2 "Error - Aborted OpenSSL Signing, CRT file is empty" && rm "$CERT_FILE" && exit 7
		backup_file "$CSR_FILE"
		backup_file "$CERT_FILE"
		backup_file "$CA_INDEX_FILE"
		echo "$(date): $CSR_FILE signed, cn $CSR_CN, serial $CERT_SERIAL, mail $CSR_MAIL" >> "$CA_LOG"
		send_mail "$CA_MAILFROM" "$CA_MAILTO, $CSR_MAIL" "$CCMAIL" "$CA_MAILSUBJECT: Certificate signed / Zertifikat signiert" "$CA_MAILSIGN\n\ncommonName: $CSR_CN\nserial: $CERT_SERIAL\n\n$CA_MAILFOOTER" "$CERT_FILE"
		;;
	revoke|revoke_batch)
		CERT_FILE="$CA_CERT_DIR/$1.crt"
		[ ! -e "$CERT_FILE" ] && echo >&2 "Error - CRT file not found: $CERT_FILE" && exit 2
		CERT_SUBJECT="$(get_subject_from_openssl "$CERT_FILE" x509)"
		CERT_CN="$(get_key_from_subject "$CERT_SUBJECT" "CN")"
		CERT_MAIL="$(get_key_from_subject "$CERT_SUBJECT" "emailAddress")"	
		CERT_SERIAL="$(openssl x509 -serial -noout -in $CERT_FILE)"
		CERT_SERIAL="${CERT_SERIAL##serial=}"
		if [ "$ACTION" = "revoke" ]
		then
			echo "ATTENTION - this action can not been reverted."
			echo "The file details are as follows"
			echo "filename     : $CERT_FILE"
			echo "commonName   : $CERT_CN"
			echo "emailAddress : $CERT_MAIL" 
			echo "serial       : $CERT_SERIAL"
			echo -n "Are you sure to revoke this certificate (yes/no)? "
			read REPLY
			[ "$REPLY" != "yes" ] && echo "Revocation aborted." && exit 0
		fi
		openssl ca -config "$CA_CONFIG_FILE" -revoke "$CERT_FILE"
		backup_file "$CERT_FILE"
		backup_file "$CA_INDEX_FILE"
		echo "$(date): $CERT_FILE revoked, cn $CERT_CN, serial $CERT_SERIAL, mail $CERT_MAIL" >> "$CA_LOG"
		send_mail "$CA_MAILFROM" "$CA_MAILTO, $CERT_MAIL" "$CCMAIL" "$CA_MAILSUBJECT: Certificate revoked / Zertifikat zurueckgezogen" "$CA_MAILREVOKE\n\ncommonName: $CERT_CN\nserial: $CERT_SERIAL\n\n$CA_MAILFOOTER" "$CERT_FILE"
		;;
	crl)
		openssl ca -config "$CA_CONFIG_FILE" -gencrl -out "$CA_CRL_FILE"
		backup_file "$CA_CRL_FILE"
		backup_file "$CA_INDEX_FILE"
		;;
	list)
		CERT_CN="CN=$1"
		echo -n "Searching for '$CERT_CN'... "
		CERT_REVOKED="$(match_string_in_file "$CERT_CN" "$CA_INDEX_FILE" "^V")"
		CERT_ACTIVE="$(match_string_in_file "$CERT_CN" "$CA_INDEX_FILE" "^R")"
		echo "done."
		[ -n "$CERT_REVOKED" ] && echo -e "Revoked certificates:\n$CERT_REVOKED" || echo "No revoked certificates found."
		[ -n "$CERT_ACTIVE" ] && echo -e "Active certificates:\n$CERT_ACTIVE" || echo "No active certificates found."
		;;
	help|--help)
		echo "Usage: $(basename "$0")"
		echo "	sign CSR_NAME [CCMAIL]       - sign a certificate request"
		echo "	sign_batch CSR_NAME [CCMAIL] - sign in batch mode (non interative)"
		echo "	revoke CERT_NAME [CCMAIL]    - revoke a certificate"
		echo "	crl                          - generate revocation list"
		echo "	list CERT_CN                 - list certs for common name"
		echo "	help                         - show this help"
		;;
	*)
		echo >&2 "Invalid action: $ACTION"
		"$0" >&2 help
		exit 1
		;;
 esac

exit 0


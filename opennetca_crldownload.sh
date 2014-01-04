#!/bin/bash

#
# Opennet CA CRL Download Script 
# Mathias Mahnke, created 2013/12/29
# Opennet Admin Group <admin@opennet-initiative.de>
#

# stop on error and unset variables
set -eu

# static script variables
CA_URL="http://ca.opennet-initiative.de"
CA_TMP=".tmp"

# retrieve script parameter
[ $# -ne 3 ] && echo "usage: $(basename "$0") <crl-name> <crl-dir> <ca-crt>" && exit 1
CA_CRLNAME="$1"
CA_CRLDIR="$2"
CA_CRTFILE="$3"
CA_CRLFILE="$CA_CRLDIR/$CA_CRLNAME"
CA_CRLFILETMP="$CA_CRLFILE$CA_TMP"
CA_CRLURL="$CA_URL/$CA_CRLNAME"

# check directory
[ ! -d "$CA_CRLDIR" ] && echo >&2 "Error: directory '$CA_CRLDIR' not exists" && exit 2
[ -e "$CA_CRLFILETMP" ] && echo >&2 "Error: temp file '$CA_CRLFILETMP' already exists" && exit 3
[ ! -e "$CA_CRTFILE" ] && echo >&2 "Error: cert file '$CA_CRTFILE' not exists" && exit 4

# download crl
echo -n "Download $CA_CRLURL... "
wget -q "$CA_CRLURL" -O "$CA_CRLFILETMP" || { echo && echo >&2 "Error: download of CRL file '$CA_CRLNAME' failed" && rm "$CA_CRLFILETMP"; exit 5; }
echo "done."

# verfiy crl
echo -n "Verify $CA_CRLNAME... "
openssl crl -in "$CA_CRLFILETMP" -CAfile "$CA_CRTFILE" -noout >/dev/null 2>&1 || { echo && echo >&2 "Error: CRL verify against CA '$CA_CRLFILE' failed" && rm "$CA_CRLFILETMP"; exit 6; }
echo "done."

# copy tmp file to final location
echo -n "Activate $CA_CRLNAME... "
mv "$CA_CRLFILETMP" "$CA_CRLFILE" || { echo && echo >&2 "Error: move of '$CA_CRLFILETMP' to '$CA_CRLFILE' failed" && rm "$CA_CRLFILETMP"; exit 7; }
echo "done."

# finish
echo "Finished."
exit 0


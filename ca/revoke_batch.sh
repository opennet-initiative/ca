#!/bin/sh

#
# Opennet CA Revoke OpenSSL Script File
# Mathias Mahnke, created 2013/12/29
# Opennet Admin Group <admin@opennet-initiative.de>
#

# stop on error and unset variables
set -eu

# get current script dir
CA_HOME="$(dirname $(readlink -f "$0"))"

# get optional parameter
PARAM=""
[ $# -gt 1 ] && PARAM="$2"

# execute sign method
"$CA_HOME/opennetca.sh" revoke_batch $1 $PARAM

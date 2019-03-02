#!/bin/sh

#
# Opennet CA List OpenSSL Script File
# Mathias Mahnke, created 2013/12/29
# Opennet Admin Group <admin@opennet-initiative.de>
#

# stop on error and unset variables
set -eu

# get current script dir
CA_HOME="$(dirname $(readlink -f "$0"))"

# execute sign method
"$CA_HOME/opennetca.sh" list $1

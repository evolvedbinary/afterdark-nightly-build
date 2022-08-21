#!/usr/bin/env bash

###
# Expects the Environment variables:
#   AD_REMOTE_SSH_USER    The username to use for the SSH connection
#   AD_REMOTE_SSH_HOST    The host to connect to by SSH
#   AD_SMB_OUTPUT_SERVER  The SMB server where build artifacts should be stored
###

set -e
#set -x

# Exit Codes
EXIT_OK=0
EXIT_MISSING_ENV_VAR=1


BUILD_FUSIONDB="YES"
BUILD_EXISTDB="NO"

function parse_args() {
	local args=($@)

	for (( i = 0; i < ${#args[@]}; i++ )); do
		local key="${args[$i]}"
		
		case $key in

			--existdb)
				BUILD_FUSIONDB="NO"
				BUILD_EXISTDB="YES"
				;;

			-h|--help)
				HELP="YES"
				;;

		esac

	done
}

# Prints out the command line usage instructions
function print_help() {
	echo "Usage: ssh.nightly.run.sh [options...]"
	echo " --existdb    Build eXist-db instead of FusionDB (default: no)"
	echo " --help       Show this help text"
}

parse_args $@
if [ -n "${HELP}" ]; then
	print_help
	exit $EXIT_OK
fi

# check for args and env variables
if [ "${BUILD_FUSIONDB}" == "YES" ]; then
	# fusiondb
	SOURCE_GIT_REPO="git@gitlab.com:adamretter/granite.git"
	SOURCE_GIT_BRANCH="collection-cache-fix-attempt4-mavenized"
	BUILD_DIR_NAME="fusiondb-nightly"
	DISPLAY_GIT_REPO="https://github.com/evolvedbinary/fusiondb-server"
	TABLE_FILE_NAME="fdb-table.html"
else
	# existdb
	SOURCE_GIT_REPO="git@github.com:eXist-db/exist.git"
	SOURCE_GIT_BRANCH="develop"
	BUILD_DIR_NAME="existdb-nightly"
	DISPLAY_GIT_REPO="https://github.com/eixst-db/exist"
	TABLE_FILE_NAME="edb-table.html"
fi

if [ -z "$AD_REMOTE_SSH_USER" ]; then
	echo "The AD_REMOTE_SSH_USER environment variable must be set"
	exit $EXIT_MISSING_ENV_VAR
fi

if [ -z "$AD_REMOTE_SSH_HOST" ]; then
	echo "The AD_REMOTE_SSH_HOST environment variable must be set"
	exit $EXIT_MISSING_ENV_VAR
fi

if [ -z "$AD_SMB_OUTPUT_SERVER" ]; then
	echo "The AD_SMB_OUTPUT_SERVER environment variable must be set"
	exit $EXIT_MISSING_ENV_VAR
fi

# determine the directory that this script is in
pushd `dirname $0` > /dev/null
SCRIPT_DIR=`pwd -P`
popd > /dev/null

# run the build on the remote SSH host
ssh $AD_REMOTE_SSH_USER@$AD_REMOTE_SSH_HOST 'export SOURCE_GIT_REPO='"'$SOURCE_GIT_REPO'"' SOURCE_GIT_BRANCH='"'$SOURCE_GIT_BRANCH'"' BUILD_DIR_NAME='"'$BUILD_DIR_NAME'"' AD_SMB_OUTPUT_SERVER='"'$AD_SMB_OUTPUT_SERVER'"'; ~/afterdark-nightly-build/ssh.receiver.nightly.sh'

# generate the HTML table rows
${SCRIPT_DIR}/generate-html-rows.sh --git-repo "${DISPLAY_GIT_REPO}" --output-dir "/www-data/www.evolvedbinary.com/afterdark/${BUILD_DIR_NAME}/" --link-prefix "afterdark/${BUILD_DIR_NAME}/" --output-file "/tmp/${TABLE_FILE_NAME}"

# update the webpage
${SCRIPT_DIR}/replace-html-rows.pl /www-data/www.evolvedbinary.com/afterdark.html "<!-- START ${BUILD_DIR_NAME} BUILD ITEMS -->" "<!-- END ${BUILD_DIR_NAME} BUILD ITEMS -->" "/tmp/${TABLE_FILE_NAME}" /tmp/afterdark.new.html

cp -v /tmp/afterdark.new.html /www-data/www.evolvedbinary.com/afterdark.html

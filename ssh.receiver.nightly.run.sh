#!/usr/bin/env bash

###
# Expects the Environment variables:
#   SOURCE_GIT_REPO         The git repository that contains the source code to build
#   SOURCE_GIT_BRANCH       The git branch of the repository to build
#   BUILD_DIR_NAME          The directory name for the build
#   AD_SMB_OUTPUT_SERVER    The SMB server where build artifacts should be stored
###

set -e
set -x

# Exit Codes
EXIT_OK=0
EXIT_MISSING_ENV_VAR=1

# check for env variables
if [ -z "$SOURCE_GIT_REPO" ]; then
	echo "The SOURCE_GIT_REPO environment variable must be set"
	exit $EXIT_MISSING_ENV_VAR
fi
if [ -z "$SOURCE_GIT_BRANCH" ]; then
	echo "The SOURCE_GIT_BRANCH environment variable must be set"
	exit $EXIT_MISSING_ENV_VAR
fi
if [ -z "$BUILD_DIR_NAME" ]; then
	echo "The BUILD_DIR_NAME environment variable must be set"
	exit $EXIT_MISSING_ENV_VAR
fi
if [ -z "$AD_SMB_OUTPUT_SERVER" ]; then
	echo "The AD_SMB_OUTPUT_SERVER environment variable must be set"
	exit $EXIT_MISSING_ENV_VAR
fi

export JAVA_HOME=$HOME/jdk8u252-full.jdk
export PATH=$HOME/jdk8u252-full.jdk/bin:$HOME/apache-maven-3.6.3/bin:$HOME/bin:$HOME/nsis/bin:$HOME/homebrew/bin:/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin

$HOME/afterdark-nightly-build/build.sh --cleanup --use-mailsend-go --mail-from sysops@evolvedbinary.com --rcpt-to sysops@evolvedbinary.com --git-repo "${SOURCE_GIT_REPO}" --git-branch "${SOURCE_GIT_BRANCH}" --build-dir "${HOME}/${BUILD_DIR_NAME}/dist/source" --output-dir "$HOME/${BUILD_DIR_NAME}/dist/target" --log-dir "${HOME}/${BUILD_DIR_NAME}" --smb-output-server "${AD_SMB_OUTPUT_SERVER}" --smb-output-server-creds-file $HOME/storage-box.creds --smb-output-basedir /backup --smb-output-dir "/${BUILD_DIR_NAME}" --unlock-mac-creds-file $HOME/mac.creds > $HOME/${BUILD_DIR_NAME}/${BUILD_DIR_NAME}-build.log 2>&1

#!/usr/bin/env bash

###
## Performs a SNAPSHOT build of eXist-db Maven artifacts
###

## Default paths. Can be overriden by command line
## args --build-dir and/or --output-dir
TMP_ROOT_DIR="/tmp/exist-nightly-build"
TMP_DIR="${TMP_ROOT_DIR}/mvn"
BUILD_DIR="${TMP_DIR}/source"
OUTPUT_DIR="${TMP_DIR}/target"
EXIST_BUILD_DIR="${TMP_ROOT_DIR}/dist/source"

MVN_GIT_REPO="git@github.com:eXist-db/mvn-repo.git"
MVN_GIT_BRANCH="master"

EXIST_SNAPSHOT_BASE="5.0.0"
MIGRATE_FROM_POM_VERSION="5.0.0-RC6"

## stop on first error!
set -e

## uncomment the line below for debugging this script!
#set -x 

# determine the directory that this script is in
pushd `dirname $0` > /dev/null
SCRIPT_DIR=`pwd -P`
popd > /dev/null

# parse command line args
for i in "$@"
do
case $i in
    -d|--build-dir)
    BUILD_DIR="$2"
    shift
    ;;
    -o|--output-dir)
    OUTPUT_DIR="$2"
    shift
    ;;
    -g|--git-repo)
    MVN_GIT_REPO="$2"
    shift
    ;;
    -b|--git-branch)
    MVN_GIT_BRANCH="$2"
    shift
    ;;
    -s|--git-stash)
    GIT_STASH="TRUE"
    shift
    ;;
    -e|--exist-build-dir)
    EXIST_BUILD_DIR="$2"
    shift
    ;;
    -f|--from-version)
    MIGRATE_FROM_POM_VERSION="$2"
    shift
    ;;
    *)  # unknown option
    shift
    ;;
esac
done

## sanity checks

# Locate JAVA_HOME (if not set in env)
if [ -z "${JAVA_HOME}" ]; then
  echo -e "\nNo JAVA_HOME environment variable found!"
  echo "Attempting to determine JAVA_HOME (if this fails you must manually set it)..."
  if [ "$(uname -s)" == "Darwin" ]; then
      java_bin=$(readlink `which java`)
  else
      java_bin=$(readlink -f `which java`)
  fi
  java_bin_dir=$(dirname "${java_bin}")
  JAVA_HOME=$(dirname "${java_bin_dir}")
  echo -e "Derived JAVA_HOME=${JAVA_HOME}\n"
fi

if [ ! -d "${JAVA_HOME}" ]; then
  echo -e "Error: JAVA_HOME directory does not exist!\n"
  echo -e "JAVA_HOME=${JAVA_HOME}\n"
  exit 2;
fi

REQUIRED_JAVA_VERSION=18
JAVA_VERSION="$($JAVA_HOME/bin/java -version 2>&1 | sed -n ';s/.* version "\(.*\)\.\(.*\)\..*"/\1\2/p;')"
if [ ! "$JAVA_VERSION" -eq $REQUIRED_JAVA_VERSION ]; then
  echo -e "Error: Building requires Java 1.8\n"
  echo -e "Found $($JAVA_HOME/bin/java -version)\n"
  exit 2
fi

# check that Maven 3.5.4 or later is available
if ! [ -x "$(command -v mvn)" ]; then
   echo -e "Error: Maven mvn binary not found on the PATH\n"
   exit 3 
fi

REQUIRED_MVN_VERSION=354
MVN_VERSION="$(mvn --version | head -n 1 | sed 's|Apache Maven \([0-9]*\)\.\([0-9]*\)\.\([0-9]*\).*|\1\2\3|')"
if [ ! "$MVN_VERSION" -ge $REQUIRED_MVN_VERSION ]; then
  echo -e "Error: Building requires Maven 3.5.4 or newer\n"
  echo -e "Found $(mvn --version | head -n 1)\n"
  exit 3
fi

if [ ! -d "$BUILD_DIR" ]; then
	# clone the source if we don't already have it
	mkdir -p $BUILD_DIR
	git clone $MVN_GIT_REPO --branch $MVN_GIT_BRANCH --single-branch $BUILD_DIR
	pushd $BUILD_DIR
	git checkout $MVN_GIT_BRANCH

else
	pushd ${BUILD_DIR}

	# update the source from the git repo
	if [ -n "${GIT_STASH}" ]; then
		git stash save "local build fixes"
	fi

	git fetch origin
	git checkout $MVN_GIT_BRANCH
	git rebase "origin/${MVN_GIT_BRANCH}"

	if [ -n "${GIT_STASH}" ]; then
		git stash pop
	fi
fi

# actually do the build

# hide the local.build.properties file
mv -v $EXIST_BUILD_DIR/local.build.properties $EXIST_BUILD_DIR/local.build.properties.BAK

# build exist-db from source
echo -e "Building eXist-db from source...\n"
./update.sh \
	--build-dir "${BUILD_DIR}" \
	--output-dir "${OUTPUT_DIR}" \
       	--exist-build-dir "${EXIST_BUILD_DIR}" \
	--tag "${EXIST_SNAPSHOT_BASE}" \
	--snapshot

# unhide the local.build.properties file
mv -v $EXIST_BUILD_DIR/local.build.properties.BAK $EXIST_BUILD_DIR/local.build.properties

# migrate the pom versions
SNAPSHOT_VERSION="$(cat $BUILD_DIR/SNAPSHOT)"
echo -e "Migrating eXist-db POMs from ${MIGRATE_FROM_POM_VERSION} to ${SNAPSHOT_VERSION}...\n"
./migrate-pom-versions.sh \
	--build-dir "${BUILD_DIR}" \
	--output-dir "${OUTPUT_DIR}" \
	--from-version "${MIGRATE_FROM_POM_VERSION}" \
	--to-version "${SNAPSHOT_VERSION}"
rm $BUILD_DIR/SNAPSHOT

# upload the snapshots
echo -e "Uploading the SNAPSHOT ${SNAPSHOT_VERSION}...\n"
./upload.sh \
	--output-dir "${OUTPUT_DIR}" \
	--snapshot \
	--artifact-version "${SNAPSHOT_VERSION}"

# delete the local copy of the snapshot
rm -rf "${OUTPUT_DIR}"

# restore the cwd
popd

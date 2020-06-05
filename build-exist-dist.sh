#!/usr/bin/env bash

###
## Performs a SNAPSHOT build of eXist-db dist artifacts
## and creates SHA256 checksums for them
###

## Default paths. Can be overriden by command line
## args --build-dir and/or --output-dir
BUILD_ROOT_DIR="/exist-nightly/dist"
BUILD_SRC_DIR="${BUILD_ROOT_DIR}/source"
BUILD_TARGET_DIR="${BUILD_ROOT_DIR}/target"

EXIST_GIT_REPO="git@github.com:eXist-db/exist.git"
EXIST_GIT_BRANCH="develop"

## stop on first error!
set -e

## uncomment the line below for debugging this script!
set -x

# determine the directory that this script is in
pushd `dirname $0` > /dev/null
SCRIPT_DIR=`pwd -P`
popd > /dev/null

TIMESTAMP="$(date +%Y%m%d%H%M%S)"

# parse command line args
for i in "$@"
do
case $i in
    -d|--build-dir)
    BUILD_SRC_DIR="$2"
    shift
    ;;
    -o|--output-dir)
    BUILD_TARGET_DIR="$2"
    shift
    ;;
    -g|--git-repo)
    EXIST_GIT_REPO="$2"
    shift
    ;;
    -b|--git-branch)
    EXIST_GIT_BRANCH="$2"
    shift
    ;;
    -r|--git-reset)
    GIT_RESET="TRUE"
    shift
    ;;
    -s|--git-stash)
    GIT_STASH="TRUE"
    shift
    ;;
    --skip-build)
    SKIP_BUILD="TRUE"
    shift
    ;;
    --skip-git-rev-check)
    SKIP_GIT_REV_CHECK="TRUE"
    shift
    ;;
    --timestamp)
    TIMESTAMP="$2"
    shift
    ;;
    *)  # unknown option
    shift
    ;;
esac
done

# like `cp` but adds a build label if the filename is a SNAPSHOT
# and adds a sha256 checksum file
cpbl() {
    local in_file=$1
    local out_dir=$2
    local out_file_name=$(basename $in_file)

    if [[ $in_file == *"SNAPSHOT-unix"* ]]; then
        out_file_name=${out_file_name/SNAPSHOT-unix/SNAPSHOT-unix+$TIMESTAMP}
    elif [[ $in_file == *"SNAPSHOT-win"* ]]; then
        out_file_name=${out_file_name/SNAPSHOT-win/SNAPSHOT-win+$TIMESTAMP}
    elif [[ $in_file == *"SNAPSHOT"* ]]; then
        out_file_name=${out_file_name/SNAPSHOT/SNAPSHOT+$TIMESTAMP}
    fi

    out_file=$out_dir/$out_file_name

    cp -v $in_file $out_file
    pushd $out_dir
    openssl sha256 -r $out_file_name > $out_file_name.sha256
    popd
}

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

# check that Maven 3.6.1 or later is available
if ! [ -x "$(command -v mvn)" ]; then
   echo -e "Error: Maven mvn binary not found on the PATH\n"
   exit 3
fi

REQUIRED_MVN_VERSION=361
MVN_VERSION="$(mvn --version | head -n 1 | sed 's|Apache Maven \([0-9]*\)\.\([0-9]*\)\.\([0-9]*\).*|\1\2\3|')"
if [ ! "$MVN_VERSION" -ge $REQUIRED_MVN_VERSION ]; then
  echo -e "Error: Building requires Maven 3.6.1 or newer\n"
  echo -e "Found $(mvn --version | head -n 1)\n"
  exit 3
fi

if [ ! -d "$BUILD_SRC_DIR" ]; then
	# clone the source if we don't already have it
	mkdir -p $BUILD_SRC_DIR
	git clone $EXIST_GIT_REPO --branch $EXIST_GIT_BRANCH --single-branch $BUILD_SRC_DIR
	pushd $BUILD_SRC_DIR
	git checkout $EXIST_GIT_BRANCH

else
	pushd ${BUILD_SRC_DIR}

	# clean any lingering artifacts from a previous build of the source code
	mvn clean

	# update the source from the git repo
	if [ -n "${GIT_STASH}" ]; then
		git stash save "local build fixes"
	fi

	git fetch origin
	git checkout $EXIST_GIT_BRANCH
	if [ -n "${GIT_RESET}" ]; then
		git reset --hard "origin/${EXIST_GIT_BRANCH}"
	else
		git rebase "origin/${EXIST_GIT_BRANCH}"
	fi

	if [ -n "${GIT_STASH}" ]; then
		git stash pop
	fi
fi

if [ ! -n "$SKIP_BUILD" ]; then

  CURRENT_REV=$(git rev-parse --short=7 HEAD)
  PREV_REV="NONE"
  if [ ! -n "$SKIP_GIT_REV_CHECK" ] && [[ -f ".nightly-build-prev-rev" ]]; then
    PREV_REV=$(<.nightly-build-prev-rev)
  fi

  if [[ $PREV_REV != $CURRENT_REV ]]; then

    # actually do the build and deploy of Maven artifacts
    # mvn -T 2C -Dlicense.skip=true -Dmdep.analyze.skip=true -Ddependency-check.skip=true -DskipTests -Dmaven.install.skip=true -Dbintray.skip=true package net.nicoulaj.maven.plugins:checksum-maven-plugin:1.8:artifacts deploy
    mvn -V -T 2C package deploy -Dlicense.skip=true -Dmdep.analyze.skip=true -DskipTests -Ddependency-check.skip=true -Ddocker=false -Dmaven.install.skip=true -Dbintray.skip=true -P !concurrency-stress-tests,!micro-benchmarks

    # copy the built artifacts to the output dir
    mkdir -p $BUILD_TARGET_DIR
    if [ -d "exist-installer" ]; then
      cpbl exist-installer/target/exist-installer-*.jar* $BUILD_TARGET_DIR
      cpbl exist-distribution/target/eXist-db-*.dmg* $BUILD_TARGET_DIR
      cpbl exist-distribution/target/exist-distribution-*.tar.bz2* $BUILD_TARGET_DIR
      cpbl exist-distribution/target/exist-distribution-*.zip* $BUILD_TARGET_DIR
    else
      cpbl fusiondb-server-distribution/fusiondb-server-nsis/target/fusiondb-server-*-setup.exe $BUILD_TARGET_DIR
      cpbl fusiondb-server-distribution/fusiondb-server-dmg/target/fusiondb-server-*.dmg $BUILD_TARGET_DIR
      cpbl fusiondb-server-distribution/fusiondb-server-archive/target/fusiondb-server-*-win.zip $BUILD_TARGET_DIR
      cpbl fusiondb-server-distribution/fusiondb-server-archive/target/fusiondb-server-*-unix.tar.bz2 $BUILD_TARGET_DIR
    fi

    # store the revision of the build (for next time...)
    echo "${CURRENT_REV}" > .nightly-build-prev-rev

  else
    echo -e "\n\nSkipping build (PREV_REV=${PREV_REV} and CURRENT_REV=${CURRENT_REV}, no changes!)...\n"
  fi

else
  echo -e "\n\nSkipping build (--skip-build was specified)...\n"
fi

# restore the cwd
popd

#!/usr/bin/env bash

###
## Performs a SNAPSHOT build of eXist-db dist artifacts
## and creates SHA256 checksums for them
###

## Default paths. Can be overriden by command line
## args --build-dir and/or --output-dir
TMP_DIR="/tmp/exist-nightly-build/dist"
BUILD_DIR="${TMP_DIR}/source"
OUTPUT_DIR="${TMP_DIR}/target"

EXIST_GIT_REPO="git@github.com:eXist-db/exist.git"
EXIST_GIT_BRANCH="develop"

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
    EXIST_GIT_REPO="$2"
    shift
    ;;
    -b|--git-branch)
    EXIST_GIT_BRANCH="$2"
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

# check there is a local.build.properties in the BUILD_DIR
# or one that we can copy there
if [ ! -f "${BUILD_DIR}/local.build.properties" ]; then
  if [ ! -f "${SCRIPT_DIR}/local.build.properties" ]; then
    echo -e "Error: Could not find a local.build.properties file\n"
    echo -e "Needed for setting keystore and izpack locations\n"
    exit 3;
  fi
fi

if [ ! -d "$BUILD_DIR" ]; then
	# clone the source if we don't already have it
	mkdir -p $BUILD_DIR
	git clone $EXIST_GIT_REPO --branch $EXIST_GIT_BRANCH --single-branch $BUILD_DIR
	pushd $BUILD_DIR
	git checkout $EXIST_GIT_BRANCH

	if [ ! -f "${BUILD_DIR}/local.build.properties" ]; then
		cp -v "${SCRIPT_DIR}/local.build.properties" "${BUILD_DIR}/local.build.properties"
	fi
else
	pushd ${BUILD_DIR}

	# clean any lignering artifacts from a previous build the source code
	./build.sh clean
	rm -rf extensions/modules/lib

        # reset any jars which were previously modified due to signing
        git checkout -- lib/
	git checkout -- tools/jetty/lib/

	# update the source from the git repo
	if [ -n "${GIT_STASH}" ]; then
		git stash save "local build fixes"
	fi

	git fetch origin
	git checkout $EXIST_GIT_BRANCH
	git rebase "origin/${EXIST_GIT_BRANCH}"

	if [ -n "${GIT_STASH}" ]; then
		git stash pop
	fi
fi

# check that the local.build.properties has a keystore set
set +e
grep -Eq "^keystore.file=.+$" "${BUILD_DIR}/local.build.properties"
GREP_STATUS=$?
set -e
if [ $GREP_STATUS -ne 0 ]; then
  echo -e "Error: local.build.properties does not set a keystore\n"
  echo -e "Needed for signing the artifacts\n"
  exit 3
fi

if [ ! -n "$SKIP_BUILD" ]; then
  # actually do the build
  ./build.sh jnlp-unsign-all all jnlp-sign-exist jnlp-sign-core jnlp-sign-exist-extensions
  ./build.sh installer app dist-war dist-bz2

  # generate checksums for the built artifacts
  for file in installer/eXist-db-setup-*.jar dist/eXist-db-*.dmg dist/exist-*.war dist/eXist-*.tar.bz2 ; do
    sha256sum --binary $file > $file.sha256
  done

  # move the built artifacts to the output dir
  mkdir -p $OUTPUT_DIR
  mv -v installer/eXist-db-setup-*.jar* dist/eXist-db-*.dmg* dist/exist-*.war* dist/eXist-*.tar.bz2* $OUTPUT_DIR
fi

# restore the cwd
popd

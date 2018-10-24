#!/usr/bin/env bash

###
## Performs a Nightly build of eXist-db dist and Maven artifacts
###

## Default paths. Can be overriden by command line
## args --build-dir and/or --output-dir
TMP_ROOT_DIR="/tmp/exist-nightly-build"
EXIST_TMP_DIR="${TMP_ROOT_DIR}/dist"
EXIST_BUILD_DIR="${EXIST_TMP_DIR}/source"
EXIST_OUTPUT_DIR="${EXIST_TMP_DIR}/target"
MVN_TMP_DIR="${TMP_ROOT_DIR}/mvn"
MVN_BUILD_DIR="${MVN_TMP_DIR}/source"
MVN_OUTPUT_DIR="${MVN_TMP_DIR}/target"

## stop on first error!
set -e

## uncomment the line below for debugging this script!
# set -x

# determine the directory that this script is in
pushd `dirname $0` > /dev/null
SCRIPT_DIR=`pwd -P`
popd > /dev/null

# parse command line args
for i in "$@"
do
  case $i in
    -f|--mail-from)
    MAIL_FROM="$2"
    shift
    ;;
    -t|--rcpt-to)
    RCPT_TO="$2"
    shift
    ;;
    -c|--cleanup)
    CLEANUP="TRUE"
    shift
    ;;
    *)  #unknown option
    shift
    ;;
  esac
done

function email_log {
  SUBJECT=$1
  EXIT_STATUS=$2
  LOG_FILE=$3
  LOG_FILE_NAME="$(basename $LOG_FILE)"

  sendmail -f $MAIL_FROM $RCPT_TO <<EOM
from: $MAIL_FROM
to: $RCPT_TO
subject: $SUBJECT

Script failed with exit code: $EXIT_STATUS.
Log file is attached!

$(cat $LOG_FILE | uuencode $LOG_FILE_NAME)

EOM

}

TIMESTAMP="$(date +%Y%m%d%H%M%S)"

mkdir -p $TMP_ROOT_DIR
pushd $SCRIPT_DIR

# cleanup old dist artifacts
if [ -n "${CLEANUP}" ]; then
  CLEAN_DIST_LOG="${TMP_ROOT_DIR}/cleanup-exist-dists.${TIMESTAMP}.log"
  echo -e "Cleaning up old eXist dist artifacts, log file: $CLEAN_DIST_LOG ...\n"
  set +e
  ${SCRIPT_DIR}/cleanup-exist-dists.sh --output-dir "$EXIST_OUTPUT_DIR" --days 15 > $CLEAN_DIST_LOG 2>&1
  CLEAN_DIST_STATUS=$?
  set -e
  if [ $CLEAN_DIST_STATUS -eq 0 ]; then
    echo -e "OK.\n"
    rm $CLEAN_DIST_LOG
  else
    echo -e "Error: Failed to cleanup eXist dist artifacts. status: $CLEAN_DIST_STATUS\n"
    if [ -n "${RCPT_TO}" ]; then
      email_log "Cleanup of eXist dist artifacts failed" $CLEAN_DIST_STATUS $CLEAN_DIST_LOG
    fi
    exit 4
  fi
fi

# build the dist artifacts
BUILD_DIST_LOG="${TMP_ROOT_DIR}/build-exist-dist.${TIMESTAMP}.log"
echo -e "Building eXist dist artifacts, log file: $BUILD_DIST_LOG ...\n"
set +e
${SCRIPT_DIR}/build-exist-dist.sh --build-dir "$EXIST_BUILD_DIR" --output-dir "$EXIST_OUTPUT_DIR" > $BUILD_DIST_LOG 2>&1
BUILD_DIST_STATUS=$?
set -e
if [ $BUILD_DIST_STATUS -eq 0 ]; then
  echo -e "OK.\n"
  rm $BUILD_DIST_LOG
else
  echo -e "Error: Failed to build eXist dist artifacts. status: $BUILD_DIST_STATUS\n"
  if [ -n "${RCPT_TO}" ]; then
    email_log "Building eXist dist artifacts failed" $BUILD_DIST_STATUS $BUILD_DIST_LOG
  fi
  exit 5
fi

# generate python html table for eXist dist artifacts
BUILD_DIST_HTML_LOG="${TMP_ROOT_DIR}/build-exist-dist-html.${TIMESTAMP}.log"
echo -e "Building eXist dist HTML table, log file: $BUILD_DIST_HTML_LOG ...\n"
set +e
${SCRIPT_DIR}/generate-exist-dist-html-table.py --build-dir "$EXIST_BUILD_DIR" --output-dir "$EXIST_OUTPUT_DIR" > $BUILD_DIST_HTML_LOG 2>&1
BUILD_DIST_HTML_STATUS=$?
set -e
if [ $BUILD_DIST_HTML_STATUS -eq 0 ]; then
  echo -e "OK.\n"
  rm $BUILD_DIST_HTML_LOG
else
  echo -e "Error: Failed to build eXist dist HTML table. status: $BUILD_DIST_HTML_STATUS\n"
  if [ -n "${RCPT_TO}" ]; then
    email_log "Building eXist dist HTML table failed" $BUILD_DIST_HTML_STATUS $BUILD_DIST_HTML_LOG
  fi
  exit 6
fi

# build the mvn artifacts
BUILD_MVN_LOG="${TMP_ROOT_DIR}/build-exist-mvn.${TIMESTAMP}.log"
echo -e "Building eXist mvn artifacts, log file: $BUILD_MVN_LOG ...\n"
set +e
${SCRIPT_DIR}/build-exist-mvn.sh --build-dir "$MVN_BUILD_DIR" --output-dir "$MVN_OUTPUT_DIR" --exist-build-dir "$EXIST_BUILD_DIR" > $BUILD_MVN_LOG 2>&1
BUILD_MVN_STATUS=$?
set -e
if [ $BUILD_MVN_STATUS -eq 0 ]; then
  echo -e "OK.\n"
  rm $BUILD_MVN_LOG
else
  echo -e "Error: Failed to build eXist mvn artifacts. status: $BUILD_MVN_STATUS\n"
  if [ -n "${RCPT_TO}" ]; then
    email_log "Building eXist mvn artifacts failed" $BUILD_MVN_STATUS $BUILD_MVN_LOG
  fi
  exit 7
fi

# restore the cwd
popd

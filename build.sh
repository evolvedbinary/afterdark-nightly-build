#!/usr/bin/env bash

###
## Performs a Nightly build of eXist-db dist and Maven artifacts
###

## Default paths. Can be overriden by command line
## args --log-dir, --exist-build-dir, --exist-output-dir,
## --mvn-build-dir and/or --mvn-output-dir
BUILD_ROOT_DIR="/exist-nightly"
LOG_DIR="${BUILD_ROOT_DIR}"
EXIST_BUILD_ROOT_DIR="${BUILD_ROOT_DIR}/dist"
EXIST_SRC_DIR="${EXIST_BUILD_ROOT_DIR}/source"
EXIST_TARGET_DIR="${EXIST_BUILD_ROOT_DIR}/target"

MAX_DAYS=8  # number of days to keep nightlies for

GENERATE_HTML_TABLE="TRUE"

## stop on first error!
set -e

## uncomment the line below for debugging this script!
 set -x

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
    --no-html-table)
    GENERATE_HTML_TABLE="FALSE"
    shift
    ;;
    --exist-git-repo)
    EXIST_GIT_REPO="$2"
    shift
    ;;
    --exist-git-branch)
    EXIST_GIT_BRANCH="$2"
    shift
    ;;
    --exist-skip-build)
    EXIST_SKIP_BUILD="TRUE"
    shift
    ;;
    --exist-build-dir)
    EXIST_SRC_DIR="$2"
    shift
    ;;
    --exist-output-dir)
    EXIST_TARGET_DIR="$2"
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
    --skip-git-rev-check)
    SKIP_GIT_REV_CHECK="TRUE"
    shift
    ;;
    --log-dir)
    LOG_DIR="$2"
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

  /usr/sbin/sendmail -f $MAIL_FROM $RCPT_TO <<EOM
from: $MAIL_FROM
to: $RCPT_TO
subject: $SUBJECT

Script failed with exit code: $EXIT_STATUS.
Log file is attached!

$(cat $LOG_FILE | uuencode $LOG_FILE_NAME)

EOM

}

TIMESTAMP="$(date +%Y%m%d%H%M%S)"

echo -e "Starting build at ${TIMESTAMP}...\n"

mkdir -p $EXIST_TARGET_DIR
pushd $SCRIPT_DIR

# count current dist artifacts
DIST_ARTIFACTS_COUNT=$(ls -1q $EXIST_TARGET_DIR/* | wc -l)

# build the dist artifacts
BUILD_DIST_LOG="${LOG_DIR}/build-exist-dist.${TIMESTAMP}.log"
echo -e "Building eXist dist artifacts, log file: $BUILD_DIST_LOG ...\n"
set +e
${SCRIPT_DIR}/build-exist-dist.sh \
	${EXIST_GIT_REPO:+ --git-repo "${EXIST_GIT_REPO}"} \
	${EXIST_GIT_BRANCH:+ --git-branch "${EXIST_GIT_BRANCH}"} \
	${EXIST_SKIP_BUILD:+ --skip-build} \
	${GIT_RESET:+ --git-reset} \
	${GIT_STASH:+ --git-stash} \
	${SKIP_GIT_REV_CHECK:+ --skip-git-rev-check} \
	--timestamp "$TIMESTAMP" \
	--build-dir "$EXIST_SRC_DIR" \
	--output-dir "$EXIST_TARGET_DIR" \
	> $BUILD_DIST_LOG 2>&1
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

# count again all the dist artifacts
UPDATED_DIST_ARTIFACTS_COUNT=$(ls -1q $EXIST_TARGET_DIR/* | wc -l)

# Only cleanup old artifacts and update the table if there are new dist artifacts
if [[ $DIST_ARTIFACTS_COUNT != $UPDATED_DIST_ARTIFACTS_COUNT ]]; then

  # cleanup old dist artifacts
  if [ -n "${CLEANUP}" ]; then
    CLEAN_DIST_LOG="${LOG_DIR}/cleanup-exist-dists.${TIMESTAMP}.log"
    echo -e "Cleaning up old eXist dist artifacts, log file: $CLEAN_DIST_LOG ...\n"
    set +e
    ${SCRIPT_DIR}/cleanup-exist-dists.sh \
            --output-dir "$EXIST_TARGET_DIR" \
            --days $MAX_DAYS \
            > $CLEAN_DIST_LOG 2>&1
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

  if [ "${GENERATE_HTML_TABLE}" = "TRUE" ]; then
    # generate python html table for eXist dist artifacts
    BUILD_DIST_HTML_LOG="${LOG_DIR}/build-exist-dist-html.${TIMESTAMP}.log"
    echo -e "Building eXist dist HTML table, log file: $BUILD_DIST_HTML_LOG ...\n"
    set +e
    ${SCRIPT_DIR}/generate-exist-dist-html-table.py \
    	--build-dir "$EXIST_SRC_DIR" \
    	--output-dir "$EXIST_TARGET_DIR" \
    	> $BUILD_DIST_HTML_LOG 2>&1
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
  fi

else
  echo -e "No new dist artifacts!\n"
fi

echo -e "Build complete.\n"

# restore the cwd
popd

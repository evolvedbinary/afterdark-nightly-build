#!/usr/bin/env bash

###
## Performs a Nightly build of FusionDB or eXist-db dist and Maven artifacts
###

## Default paths. Can be overriden by command line
## args --log-dir, --build-dir, --output-dir,
## --mvn-build-dir and/or --mvn-output-dir
BUILD_ROOT_DIR="/nightly"
LOG_DIR="${BUILD_ROOT_DIR}"
BUILD_ROOT_DIR="${BUILD_ROOT_DIR}/dist"
SRC_DIR="${BUILD_ROOT_DIR}/source"
TARGET_DIR="${BUILD_ROOT_DIR}/target"

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
    --git-repo)
    GIT_REPO="$2"
    shift
    ;;
    --git-branch)
    GIT_BRANCH="$2"
    shift
    ;;
    --skip-build)
    SKIP_BUILD="TRUE"
    shift
    ;;
    --build-dir)
    SRC_DIR="$2"
    shift
    ;;
    --output-dir)
    TARGET_DIR="$2"
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

mkdir -p $TARGET_DIR
pushd $SCRIPT_DIR

# count current dist artifacts
DIST_ARTIFACTS_COUNT=$(ls -1q $TARGET_DIR/* | wc -l)

# build the dist artifacts
BUILD_DIST_LOG="${LOG_DIR}/build-dist.${TIMESTAMP}.log"
echo -e "Building dist artifacts, log file: $BUILD_DIST_LOG ...\n"
set +e
${SCRIPT_DIR}/build-dist.sh \
	${GIT_REPO:+ --git-repo "${GIT_REPO}"} \
	${GIT_BRANCH:+ --git-branch "${GIT_BRANCH}"} \
	${SKIP_BUILD:+ --skip-build} \
	${GIT_RESET:+ --git-reset} \
	${GIT_STASH:+ --git-stash} \
	${SKIP_GIT_REV_CHECK:+ --skip-git-rev-check} \
	--timestamp "$TIMESTAMP" \
	--build-dir "$SRC_DIR" \
	--output-dir "$TARGET_DIR" \
	> $BUILD_DIST_LOG 2>&1
BUILD_DIST_STATUS=$?
set -e
if [ $BUILD_DIST_STATUS -eq 0 ]; then
  echo -e "OK.\n"
  rm $BUILD_DIST_LOG
else
  echo -e "Error: Failed to build  dist artifacts. status: $BUILD_DIST_STATUS\n"
  if [ -n "${RCPT_TO}" ]; then
    email_log "Building dist artifacts failed" $BUILD_DIST_STATUS $BUILD_DIST_LOG
  fi
  exit 5
fi

# count again all the dist artifacts
UPDATED_DIST_ARTIFACTS_COUNT=$(ls -1q $TARGET_DIR/* | wc -l)

# Only cleanup old artifacts and update the table if there are new dist artifacts
if [[ $DIST_ARTIFACTS_COUNT != $UPDATED_DIST_ARTIFACTS_COUNT ]]; then

  # cleanup old dist artifacts
  if [ -n "${CLEANUP}" ]; then
    CLEAN_DIST_LOG="${LOG_DIR}/cleanup-dists.${TIMESTAMP}.log"
    echo -e "Cleaning up old dist artifacts, log file: $CLEAN_DIST_LOG ...\n"
    set +e
    ${SCRIPT_DIR}/cleanup-dists.sh \
            --output-dir "$TARGET_DIR" \
            --days $MAX_DAYS \
            > $CLEAN_DIST_LOG 2>&1
    CLEAN_DIST_STATUS=$?
    set -e
    if [ $CLEAN_DIST_STATUS -eq 0 ]; then
      echo -e "OK.\n"
      rm $CLEAN_DIST_LOG
    else
      echo -e "Error: Failed to cleanup dist artifacts. status: $CLEAN_DIST_STATUS\n"
      if [ -n "${RCPT_TO}" ]; then
        email_log "Cleanup of dist artifacts failed" $CLEAN_DIST_STATUS $CLEAN_DIST_LOG
      fi
      exit 4
    fi
  fi

  if [ "${GENERATE_HTML_TABLE}" = "TRUE" ]; then
    # generate python html table for dist artifacts
    BUILD_DIST_HTML_LOG="${LOG_DIR}/build-dist-html.${TIMESTAMP}.log"
    echo -e "Building dist HTML table, log file: $BUILD_DIST_HTML_LOG ...\n"
    set +e
    ${SCRIPT_DIR}/generate-dist-html-table.py \
    	--build-dir "$SRC_DIR" \
    	--output-dir "$TARGET_DIR" \
    	> $BUILD_DIST_HTML_LOG 2>&1
    BUILD_DIST_HTML_STATUS=$?
    set -e
    if [ $BUILD_DIST_HTML_STATUS -eq 0 ]; then
      echo -e "OK.\n"
      rm $BUILD_DIST_HTML_LOG
    else
      echo -e "Error: Failed to build dist HTML table. status: $BUILD_DIST_HTML_STATUS\n"
      if [ -n "${RCPT_TO}" ]; then
        email_log "Building dist HTML table failed" $BUILD_DIST_HTML_STATUS $BUILD_DIST_HTML_LOG
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

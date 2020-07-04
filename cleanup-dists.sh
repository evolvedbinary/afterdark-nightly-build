#!/usr/bin/env bash

##
# Cleans up FusionDB or eXist-db dist artifacts that are more
# than NUMBER_TO_KEEP artifacts
##

## Defaults. Can be overriden by command line
## args --output-dir and/or --number-to-keep
BUILD_DIR="/nightly/dist"
OUTPUT_DIR="${BUILD_DIR}/target"
NUMBER_TO_KEEP=14

## stop on first error!
set -e

## uncomment the line below for debugging this script!
set -x

# parse command line args
for i in "$@"
do
  case $i in
    -n|--number-to-keep)
    NUMBER_TO_KEEP=$2
    shift
    ;;
    -o|--output-dir)
    OUTPUT_DIR="$2"
    shift
    ;;
    *)  #unknown option
    shift
    ;;
  esac
done

if [ -d "${OUTPUT_DIR}" ]; then

  # find unique builds from sha256 files (in descending order)
  SHA256_BUILD_FILES=$(find -E "${OUTPUT_DIR}" -regex ".+[0-9]{14}.sha256$" | sort -nr)
  SHA256_BUILD_FILES=($SHA256_BUILD_FILES)  # convert to array
  LENGTH=${#SHA256_BUILD_FILES[@]}

  echo "Found ${LENGTH} artifacts, keeping ${NUMBER_TO_KEEP}..."

  if [[ $LENGTH -gt $NUMBER_TO_KEEP ]] ; then
    TRIM_LENGTH=`expr $LENGTH - $NUMBER_TO_KEEP`
    OLD_SHA256_BUILD_FILES=(${SHA256_BUILD_FILES[@]:$NUMBER_TO_KEEP:TRIM_LENGTH})

    for OLD_SHA256_BUILD_FILE in ${OLD_SHA256_BUILD_FILES[@]}
    do
      TIMESTAMP="$(echo $OLD_SHA256_BUILD_FILE | sed -e 's/.*\([0-9]\{14\}\).sha256$/\1/g')"
      find "${OUTPUT_DIR}" -type f -name "*${TIMESTAMP}*" -exec rm -vf {} \;
    done
  fi

fi

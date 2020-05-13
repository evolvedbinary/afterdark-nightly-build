#!/usr/bin/env bash

##
# Cleans up eXist-db dist artifacts that are older than N days
##

## Defaults. Can be overriden by command line
## args --output-dir and/or --days
BUILD_DIR="/exist-nightly/dist"
OUTPUT_DIR="${BUILD_DIR}/target"
DAYS=15

## stop on first error!
set -e

## uncomment the line below for debugging this script!
set -x

# parse command line args
for i in "$@"
do
  case $i in
    -d|--days)
    DAYS=$2
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

## cleanup any nightly builds (.dmg, .jar, .zip, tar.bz2, .exe, .sha256 files) that are older than 2 weeks
if [ -d "${OUTPUT_DIR}" ]; then
  find $OUTPUT_DIR -mtime +$DAYS -type f \( -iname "*.dmg" -or -iname "*.jar" -or -iname "*.zip" -or -iname "*.tar.bz2" -or -iname "*.exe" -or -iname "*.sha256" \) -exec rm {} \;
fi

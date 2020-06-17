#!/usr/bin/env bash

set -e
set -x

## Default paths. Can be overriden by command line
## args --log-dir, --output-dir,
BUILD_ROOT_DIR="/nightly"
LOG_DIR="${BUILD_ROOT_DIR}"
BUILD_ROOT_DIR="${BUILD_ROOT_DIR}/dist"
TARGET_DIR="${BUILD_ROOT_DIR}/target"

# parse command line args
for i in "$@"
do
  case $i in
    --git-repo)
    GIT_REPO="$2"
    shift
    ;;
    --output-dir)
    TARGET_DIR="$2"
    shift
    ;;
    --link-prefix)
    LINK_PREFIX="$2"
    shift
    ;;
    --output-file)
    OUTPUT_FILE="$2"
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

pushd $TARGET_DIR

# generate table rows
TABLE_ROWS=()

# find unique builds from sha256 files
SHA256_BUILD_FILES=$(find . -regextype posix-egrep -regex ".+[0-9]{14}.sha256$")
for SHA256_BUILD_FILE in $SHA256_BUILD_FILES
do
  TIMESTAMP="$(echo $SHA256_BUILD_FILE | sed -e 's/.\+\([0-9]\{14\}\).sha256$/\1/g')"
  echo "Processing build ${TIMESTAMP}..."

  HTML_LINKS=()

  ARTIFACT_SUFFIXES=("deb" "rpm" "dmg" "exe" "jar" "tar.bz2" "zip")

  for ARTIFACT_SUFFIX in ${ARTIFACT_SUFFIXES[@]}
  do
    BUILD_FILE="$(find . -name \*$TIMESTAMP\* -and -name \*.$ARTIFACT_SUFFIX)"
    if [[ -n "${BUILD_FILE}" ]]; then
      HTML_LINK="<a href=\"${LINK_PREFIX}${BUILD_FILE/\.\//}\">${ARTIFACT_SUFFIX^^}</a>"
      HTML_LINKS+=("$HTML_LINK")
    fi
  done

  # Add sha256 file
  HTML_LINK="<a href=\"${LINK_PREFIX}${SHA256_BUILD_FILE/\.\//}\">(SHA 256)</a>"
  HTML_LINKS+=("$HTML_LINK")

  DATE="$(echo $TIMESTAMP | sed -e 's/^\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5/')"
  LABEL="$(echo $SHA256_BUILD_FILE | sed -e 's/\.\/\(fusiondb-server\|eXist-db\)-\([^+]\+\)+[0-9]\{14\}.sha256$/\2/')"
  REVISION_FILE="${SHA256_BUILD_FILE/.sha256/.revision}"
  REVISION=$(<$REVISION_FILE)
  APPROX_SIZE=$(du -h $TARGET_DIR*$TIMESTAMP*.dmg | cut -f 1)

TABLE_ROWS+=$(cat << EOM
<tr role="row">
  <td>${DATE} UTC</td>
  <td>${LABEL}</td>
  <td><a href="${GIT_REPO}/commit/${REVISION}">${REVISION}</a></td>
  <td>| $(for (( i = 0; i < ${#HTML_LINKS[@]}; i++ )); do if [[ $i -ne 0 ]]; then echo " | "; fi; echo "${HTML_LINKS[$i]}"; done) |</td>
  <td>~ ${APPROX_SIZE}</td>
</tr>
EOM
)

done

if [[ -n "${OUTPUT_FILE}" ]]; then
  echo "${TABLE_ROWS}" > $OUTPUT_FILE
else
  echo "${TABLE_ROWS}"
fi

popd

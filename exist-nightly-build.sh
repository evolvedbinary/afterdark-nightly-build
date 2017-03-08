#!/bin/bash

set -e
set -x 

pushd `dirname $0` > /dev/null
SCRIPTPATH=`pwd -P`
popd > /dev/null

export JAVA_HOME=/usr/lib/jvm/java-8-oracle

EXIST_NIGHTLY_SRC=/usr/local/exist-nightly-build
EXIST_NIGHTLY_DEST=/www-data/static.adamretter.org.uk/exist-nightly

if [ ! -d "$EXIST_NIGHTLY_SRC" ]; then
	mkdir -p $EXIST_NIGHTLY_SRC
	git clone https://github.com/exist-db/exist.git $EXIST_NIGHTLY_SRC
fi

cd $EXIST_NIGHTLY_SRC
./build.sh clean
rm -rf $EXIST_NIGHTLY_SRC/extensions/modules/lib

# ignore any jars which were previously modified due to signing
git checkout -- lib/

## stash can be used if we have any build changes locally
# git stash save "local build fixes"
git fetch origin
git rebase origin/develop
# git stash pop

./build.sh jnlp-unsign-all all jnlp-sign-exist jnlp-sign-core
./build.sh installer app
mv -v installer/eXist-db-setup-*.jar dist/eXist-db-*.dmg $EXIST_NIGHTLY_DEST

## cleanup any nightly builds (.dmg, .jar files) that are older than 2 months
find $EXIST_NIGHTLY_DEST -mtime +62 -type f \( -iname "*.dmg" -or -iname "*.jar" \) -exec rm {} \;

## generate HTML page
cp -v "${SCRIPTPATH}/index.html" $EXIST_NIGHTLY_DEST
python "${SCRIPTPATH}/generateHTML.py" $EXIST_NIGHTLY_DEST $EXIST_NIGHTLY_SRC

#!/bin/bash

set -e
set -x 
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
./build.sh installer installer-exe app
mv -v installer/eXist-db-setup-*.jar installer/eXist-db-setup-*.exe dist/eXist-db-*.dmg $EXIST_NIGHTLY_DEST

## cleanup any nightly builds (.dmg, .exe, .jar files) that are older than 2 months
find $EXIST_NIGHTLY_DEST -mtime +62 -type f \( -iname "*.exe" -or -iname "*.dmg" -or -iname "*.jar" \) -exec rm {} \;

## generate HTML page
cp index.html $EXIST_NIGHTLY_DEST
python generateHTML.py $EXIST_NIGHTLY_DEST

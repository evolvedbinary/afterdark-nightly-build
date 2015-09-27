#!/bin/bash

set -e

export JAVA_HOME=/usr/lib/jvm/java-8-oracle

EXIST_NIGHTLY_SRC=/usr/local/exist-nightly-build
EXIST_NIGHTLY_DEST=/www-data/static.adamretter.org.uk/exist-nightly

if [ ! -d "$EXIST_NIGHTLY_SRC" ]; then
	mkdir -p $EXIST_NIGHTLY_SRC
	git clone https://github.com/exist-db/exist.git $EXIST_NIGHTLY_SRC
fi

cd $EXIST_NIGHTLY_SRC
./build.sh clean

## stash can be used if we have any build changes locally
# git stash save "local build fixes"
git fetch origin
git rebase origin/develop
# git stash pop

./build.sh installer installer-exe app
mv -v installer/eXist-db-setup-*.jar installer/eXist-db-setup-*.exe dist/eXist-db-*.dmg $EXIST_NIGHTLY_DEST

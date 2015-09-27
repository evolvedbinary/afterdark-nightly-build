# exist-nightly-build
Scripts for performing a nightly build of eXist

## Prerequisites
1. Download and install IzPack 4.3.5

2. Download and install launch4j 3.5 (for creating Windows EXE builds)

Installing launch4j on a 64bit system requires some modifications as it ships with `windres` and `ld` in its bin folder for 32bit systems. On Ubuntu run:
sudo mv /usr/local/launch4j-3.5/bin/windres /usr/local/launch4j-3.5/bin/windres.bak
sudo mv /usr/local/launch4j-3.5/bin/ld /usr/local/launch4j-3.5/bin/ld.bak
sudo apt-get install binutils-mingw-w64-x86-64
sudo ln -s /usr/bin/x86_64-w64-mingw32-windres /usr/local/launch4j-3.5/bin/windres
sudo ln -s /usr/bin/x86_64-w64-mingw32-ld /usr/local/launch4j-3.5/bin/ld

3. Install mkfs.hfsplus (for creating Mac DMG builds)
sudo apt-get install hfsprogs

4. Create the file /usr/local/exist-nightly-build/local.build.properties:
```
izpack.dir = /usr/local/izpack-4.3.5
launch4j.dir = /usr/local/launch4j-3.5
```

5. Create the file /usr/local/exist-nightly-build/extensions/local/build.properties and enable the modules you wish to include in the build.

## Installing

1. Edit the settings at the top of exist-nightly-build.sh to reflect your system, e.g. 
```
export JAVA_HOME=/usr/lib/jvm/java-8-oracle

EXIST_NIGHTLY_SRC=/usr/local/exist-nightly-build
EXIST_NIGHTLY_DEST=/www-data/static.adamretter.org.uk/exist-nightly
```

2. Run it! ...or Can be scheduled from cron with something like:

0 4 * * * /home/some-user/exist-nightly-build/exist-nightly-build.sh >> /home/some-user/exist-nightly-build.log 2>&1

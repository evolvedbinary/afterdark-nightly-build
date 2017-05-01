# exist-nightly-build
Scripts for performing a nightly build of eXist

## Prerequisites
1. Download and install IzPack 4.3.5 (http://download.jboss.org/jbosstools/updates/requirements/izpack/4.3.5/IzPack-install-4.3.5.jar)

2. Install mkfs.hfsplus (for creating Mac DMG builds)
sudo apt-get install hfsprogs

3. Copy the file `exist-patches/local.build.properties` to `/usr/local/exist-nightly-build/local.build.properties` and modify appropriately:

4. Create the file `/usr/local/exist-nightly-build/extensions/local/build.properties` and enable the modules you wish to include in the build.

## Installing

1. Edit the settings at the top of `exist-nightly-build.sh` to reflect your system, e.g. 

```bash
export JAVA_HOME=/usr/lib/jvm/java-8-oracle

EXIST_NIGHTLY_SRC=/usr/local/exist-nightly-build
EXIST_NIGHTLY_DEST=/www-data/static.adamretter.org.uk/exist-nightly
```

2. Run it! ...or Can be scheduled from cron with something like:

```
0 4 * * * /home/some-user/exist-nightly-build/exist-nightly-build.sh >> /home/some-user/exist-nightly-build.log 2>&1
```

3. If you are running it via cron, creating the Mac DMG packages requires `sudo` access without promiting for a password as such you will need to make an entry in sudoers similar to:

```
YOUR-USERNAME-OF-CRON-USER ALL = NOPASSWD: /bin/mount, /bin/umount
```

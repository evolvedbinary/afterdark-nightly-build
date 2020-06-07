# Nightly Builds
Scripts for performing a nightly build of FusionDB or eXist-db dist and Maven artifacts.

You can find the nightly builds output from this script at: https://www.evolvedbinary.com/afterdark.html

## Requirements
1. JDK 8.
    e.g. `sudo apt-get instal openjdk-8-jdk`

2. Git tools.
    e.g. `sudo apt-get install git`

3. HFS+ filesystem support. Needed for building macOS DMG packages.
    e.g. `sudo apt-get install hfsprogs`

5. Maven 3.6.1 (or newer).
    1. Download from https://maven.apache.org/download.cgi and untar
    2. Add the `bin/` folder of the untarred folder to the `$PATH` environment variable.

6. Sendmail command (Optional - needed for email notifications).
    1. [nullmailer](https://github.com/bruceg/nullmailer) can be a good choice if you already have an SMTP relay server that you want to use.
    2. e.g. `sudo apt-get install rsyslog-gnutls rsyslog-gssapi nullmailer`
    3. Configure nullmailer's SMTP relay server in `/etc/nullmailer/remotes`.

7. uuencode command (Optional - needed for email attachment of log files).
    e.g. `sudo apt-get install sharutils`


## Setup
1. Clone this repository:

```bash
$ sudo git clone https://github.com/evolvedbinary/afterdark-nightly-build.git
```

2. Configuration options can be found in the top of each `.sh` and `.py` script.

## Use
1. You can test as a one-off by running:

```bash
./build.sh --cleanup --mail-from your-system@domain.com --rcpt-to you@domain.com
```

2. ...or Can be scheduled from cron with something like:

```
0 1 * * * HOME=/home/aretter . /home/aretter/.profile; HOME=/home/aretter /home/aretter/afterdark-nightly-build/build.sh --cleanup --mail-from sysops@evolvedbinary.com --rcpt-to sysops@evolvedbinary.com --no-html-table --git-repo git@github.com:evolvedbinary/fusiondb-server.git --git-branch fusiondb-develop --git-reset --build-dir /fusiondb-nightly/dist/source --output-dir /fusiondb-nightly/dist/target --log-dir /fusiondb-nightly > /home/aretter/fusiondb-nightly-build.log 2>&1

0 2 * * * HOME=/home/aretter . /home/aretter/.profile; HOME=/home/aretter /home/aretter/afterdark-nightly-build/build.sh --cleanup --mail-from sysops@evolvedbinary.com --rcpt-to sysops@evolvedbinary.com --git-repo git@github.com:eXist-db/exist.git --git-branch develop --build-dir /existdb-nightly/dist/source --output-dir /existdb-nightly/dist/target --log-dir /existdb-nightly > /home/aretter/exist-nightly-build.log 2>&1
```

**NOTE**: If you are running it via cron, creating the Mac DMG packages requires `sudo` access without promiting for a password as such you will need to make an entry in sudoers similar to:

```
YOUR-USERNAME-OF-CRON-USER ALL = NOPASSWD: /bin/mount, /bin/umount
```

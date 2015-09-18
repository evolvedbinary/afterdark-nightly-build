#!/bin/bash

# calls exist-build-nightly.sh and sends an email if it fails
/home/ubuntu/exist-nightly-build.sh

rc=$?
if [[ $rc != 0 ]] then
	# TODO install sendmail etc and email the log
	exit $rc
fi

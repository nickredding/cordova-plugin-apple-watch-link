#!/bin/bash
[ -d "multi target" ] && {  echo ""; echo  "ERROR: Directory multi target already exists"; echo ""; exit 1; }
mkdir watchtarget
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
cordova prepare ios
rsync -a platforms/ios watchtarget/platforms

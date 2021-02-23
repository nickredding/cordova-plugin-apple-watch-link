#!/bin/bash
[ -d "multi target" ] && {  echo ""; echo  "ERROR: Directory multi target already exists"; echo ""; exit 1; }
mkdir watchtarget
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
echo ""
echo "Created directory watchtarget"
echo ""
cordova prepare ios
rsync -a platforms/ios watchtarget/platforms
echo ""
echo "Copied platforms/ios to watchtarget"
echo ""

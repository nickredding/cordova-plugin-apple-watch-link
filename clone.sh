#!/bin/bash
[ -d "multi target" ] && {  echo ""; echo  "ERROR: Directory multi target already exists"; echo ""; exit 1; }
mkdir multitarget
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
rsync -a platforms/ios multitarget/platforms

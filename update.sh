#!/bin/bash
if [[ $1 = "" ]]; then  echo ""; echo "ERROR: specify project on command line"; echo ""; exit 1; fi
[ ! -d "platforms/ios/$1" ] && {  echo ""; echo  "ERROR: project $1 not found"; echo ""; exit 1; }
echo ""
echo "Updating project $1 in multitarget/platforms/ios"
echo ""
rsync -a  platforms/ios/CordovaLib multitarget/platforms/ios
rsync -a  platforms/ios/platform_www multitarget/platforms/ios
rsync -a  platforms/ios/$1/classes multitarget/platforms/ios/$1
rsync -a  platforms/ios/$1/Plugins multitarget/platforms/ios/$1
rsync -a  platforms/ios/$1/config.xml multitarget/platforms/ios/$1
rsync -a  platforms/ios/$1/main.m multitarget/platforms/ios/$1
rsync -a  platforms/ios/www multitarget/platforms/ios
rsync -a  platforms/ios/ios.json multitarget/platforms/ios/ios.json


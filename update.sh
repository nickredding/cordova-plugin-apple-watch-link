#!/bin/bash
if [[ $1 = "" ]]; then  echo ""; echo "ERROR: specify project on command line"; echo ""; exit 1; fi
if [[ $2 = "" ]]; then  echo ""; echo "ERROR: specify watch app extension name on command line"; echo ""; exit 1; fi
ext="watchtarget/platforms/ios/$2 Extension"
[ ! -d "platforms/ios/$1" ] && {  echo ""; echo  "ERROR: project $1 not found"; echo ""; exit 1; }
[ ! -d "$ext" ] && {  echo ""; echo  "ERROR: watch extension directory '$ext' not found"; echo ""; exit 1; }
echo ""
echo "Updating project $1 in watchtarget/platforms/ios"
echo ""
cordova prepare ios
rsync -a  platforms/ios/CordovaLib watchtarget/platforms/ios
rsync -a  platforms/ios/platform_www watchtarget/platforms/ios
rsync -a  platforms/ios/$1/classes watchtarget/platforms/ios/$1
rsync -a  platforms/ios/$1/Plugins watchtarget/platforms/ios/$1
rsync -a  platforms/ios/$1/config.xml watchtarget/platforms/ios/$1
rsync -a  platforms/ios/$1/main.m watchtarget/platforms/ios/$1
rsync -a  platforms/ios/www watchtarget/platforms/ios
rsync -a  platforms/ios/ios.json watchtarget/platforms/ios/ios.json
cp plugins/cordova-plugin-apple-watch-link/Extension/WatchLinkExtensionDelegate.swift "$ext"


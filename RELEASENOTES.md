## Release Notes

#### 1.0.0 (February 23, 2021)

* Initial release.

#### 1.0.1 (February 26, 2021)

* Bug fixes.
* Add direct messaging to test app.

#### 1.0.2 (March 3, 2021)

* Bug fixes.
* Added complication testing to the test app.

#### 1.0.4 (March 20, 2021)

* Bug fixes.

#### 1.0.5 (March 26, 2021)

* Bug fixes 
* Send session reset via user information transfer if watch app is in background

#### 1.0.6 (March 27, 2021)

* Bug fixes 

#### 1.0.7 (May 6,2021)

* Bug fixes 
* Added the function transferMessage to the iOS Javascript interface that wil transmit messages in background using user information transfer if the companion watch app is not reachable.
* Updated initialization code to prevent attempts to invoke Cordova callbacks while the app is in the process of reintializing the Javascript layer due to an app restart.
* Added support for maintaining the running state of the iOS companion app.

#### 1.0.8 (May 27,2021)

* Bug fixes 
* Removed support for maintaining the running state of the iOS companion app (it does not work reliably)
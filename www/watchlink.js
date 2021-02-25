/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at
 http://www.apache.org/licenses/LICENSE-2.0
 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
*/

/* global cordova */
    
/*

Apple watch communication plugin for Cordova.

Access as watchLink

*/

    
function watchLink() {
    var _watchLink = this;
    
    // Watch session initialization
    
    /*
    watchLink.initialized is true if initialization of the Swift layer is complete
    */
    _watchLink.initialized = false;
    
    var watchLinkReadyProcs = [];
    
    /*
    watchLink.ready(f) adds the function f to the list of functions
    to execute when initialization of the Swift layer is complete.
    */
    this.ready = function(f) {
        if (typeof f !== 'function') {
            _watchLink.errorLog('watchLink.ready: parameter is not a function: ' + typeof f);
            return;
        }
        watchLinkReadyProcs.push(f);
        if (_watchLink.initialized) {
            f();
        }
    };
      
    var lastTimestamp = 0;
    function newTimestamp() {
        var timestamp = (new Date()).getTime();
        if (timestamp <= lastTimestamp) {
            timestamp = lastTimestamp + 1;
        }
        lastTimestamp = timestamp;
        return timestamp;
    }
    
    // Watch availability
    
    /*
    watchLink availability states
    */
    _watchLink.watchUnavailable = false;
    _watchLink.watchAvailable = true;
    _watchLink.watchNotPaired = "NOTPAIRED";
    _watchLink.watchNotInstalled = "NOTINSTALLED";
    
    /*
    watchLink.available is the availability state.
    
        null: yet to be initialized
        watchLink.watchUnavailable: watch session is not available
        watchLink.watchAvailable: watch sesion is available, watch is paired and 
            watch companion app installed
        watchLink.watchNotPaired: watch sesion is available but watch is not paired to phone
        watchLink.watchNotInstalled: watch sesion is available but 
            watch companion app has not been installed
    */
    
    /*
    watchLink.available stores the current availability state
    */
    _watchLink.available = null;
    
    /*
    watchLink.availability updates and returns the current availability state of the 
    watch session. It is not normally required to call this since watchLink.available 
    is kept up to date.
    
        Parameter
            callback: function(availability)
            
    The callback parameter represents the current availability state
            
    Using the traditional Cordova callback method:
    
        watchLink.availability(
            function (availability) {
                ...
            });
        
    Using the Promise construct:
    
        watchLink.availability().then(
            function (availability) {
                ...
            });
    */
    
    _watchLink.availability = function(callback, error) {
        if (!_watchLink.initialized) {
            _watchLink.errorLog('watchLink.availability: watch session not initialized');
            if (callback === undefined && error === undefined) {
                return new Promise(
                    function(resolve, reject) {
                            reject('uninitialized');
                    });
            }
            else
            if (error) {
                error('uninitialized');
            }
            return;
        }
        if (callback === undefined && error === undefined) {
            return new Promise(
                function(resolve) {
                    cordova.exec(
                        function(state) {
                            _watchLink.available = state;
                            resolve(state);
                        }, null, 'WatchLink', 'availability');
                });
        }
        cordova.exec(
            function(state) {
                _watchLink.available = state;
                if (callback) {
                    callback(state);
                }
            }, error, 'WatchLink', 'availability');
    };
    
    /*
    watchLink.availabilityChanged registers a callback to invoke when the availability 
    state changes. The callback parameter represents the new availability state.
    
        Parameter
            callback: function(availability)
        Returns: true if registration succeeded, false otherwise
        
    Supply null to deregister a previously set callback. You can overwrite a previously 
    set callback with a different callback.
    */
    var availabilityChangedCallback = null;
    _watchLink.availabilityChanged = function(callback) {
        availabilityChangedCallback = null;
        if (callback == null) {
            return true;
        }
        if (typeof callback === 'function') {
            availabilityChangedCallback = callback;
			return true;
        }
		_watchLink.errorLog('watchLink.availabilityChanged: parameter is not a function',
			callback);
		return false;
    };
    
    // Watch reachability
    
    /*
    watchLink.reachable is the reachability state.
    
        null: yet to be initialized
        true: watch is reachable
        false: watch is not reachable
        
    Note that watchLink.reachable is false if watchLink.available is not true.
    */
    _watchLink.reachable = null;
    
    /*
    watchLink.reachability updates and returns the current reachability state of the 
    watch session. It is not normally required to call this since watchLink.reachable 
    is kept up to date.
    
        Parameter
            callback: function(reachability)
            
    The callback parameter represents the new reachability state:
    
        true: watch is reachable
        false: watch is not reachable
            
    Using the traditional Cordova callback method:
    
        watchLink.reachability(
            function (reachability) {
                ...
            });
        
    Using the Promise construct:
    
        watchLink.reachability().then(
            function (reachability) {
                ...
            });
    */
    
    _watchLink.reachability = function(callback, error) {   
        if (!_watchLink.initialized) {
            _watchLink.errorLog('watchLink.reachability: watch session not initialized');
            if (callback === undefined && error === undefined) {
                return new Promise(
                    function(resolve, reject) {
                            reject('uninitialized');
                    });
            }
            else
            if (error) {
                error('uninitialized');
            }
            return;
        }
        if (callback === undefined) {
            return new Promise(
                function(resolve) {
                    cordova.exec(
                        function(state) {
                            _watchLink.reachable = state;
                            resolve(state);
                        }, null, 'WatchLink', 'reachability');
                });
        }
        cordova.exec(
            function(state) {
                _watchLink.reachable = state;
                if (callback) {
                    callback(state);
                }
            }, null, 'WatchLink', 'reachability');
    };
    
    /*
    watchLink.reachabilityChanged registers a callback to invoke when the reachibility 
    state changes. The callback parameter represents the new reachability state.
    
        Parameter
            callback: function(<boolean>)
        Returns : true if registration succeeded, false otherwise
        
    Supply null to deregister a previously set callback. You can overwrite a previously 
    set callback with a different callback.
    */
    var reachabilityChangedCallback = null;
    _watchLink.reachabilityChanged = function(callback) {
        reachabilityChangedCallback = null;
        if (callback == null) {
            return;
        }
        if (typeof callback === 'function') {
            reachabilityChangedCallback = callback;
        }
        else {
            _watchLink.errorLog('watchLink.reachabilityChanged: parameter is not a function', callback);
        }
    };
    
    // Watch application state
    
    /*
    Watch application state
    */
    _watchLink.watchApplicationActive = "ACTIVE";
    _watchLink.watchApplicationInactive = "INACTIVE";
    _watchLink.watchAapplicationBackground = "BACKGROUND";
	_watchLink.complicationEnabled = false;
	_watchLink.isPaired = false;
	_watchLink.isAppInstalled = false;
	_watchLink.directoryURL = "";
    
    /*
    watchLink.applicationState is the Watch application state.
    
        null: yet to be initialized, otherwise
		watchLink.applicationState = { state: <state>, complication: <Boolean>
                                        directoryURL: <string> }
		watchLink.applicationState.state
			false: watch is not available, or the application is not not running or suspended
			watchLink.watchApplicationActive: The Watch app is running in foreground 
				and responding to events
			watchLink.watchApplicationInactive: The Watch app is running in foreground 
				but not yet responding to events
			watchLink.watchApplicationBackground: The watch app is running in the background
		watchLink.applicationState.complication
			true: complication is enabled
			false: complication is not enabled
		watchLink.applicationState.isPaired
			true: watch is paired
			false: watch is not paired
		watchLink.applicationState.isAppInstalled
			true: watch app is installed
			false: watch app is not installed
        watchLink.applicationState.directoryURL
            The URL of a directory for storing information specific to the currently 
                paired and active Watch
        
    Note that watchLink.applicationState.state is false if watchLink.available is not true.
    */
    _watchLink.applicationState = null;
    
    /*
    watchLink.watchApplicationState updates and returns the current applicationState 
    state of the Watch app. It is not normally required to call this since
    watchLink.applicationState is kept up to date.
    
        Parameter
            callback: function(state)
            
    The callback parameter represents the new application state:
    
     false: watch is not available, or the application is not not running or suspended
     _watchLink.applicationActive: The Watch app is running in foreground and responding 
        to events
     _watchLink.applicationInactive: The Watch app is running in foreground but 
        not yet responding to events
     _watchLink.applicationBackground: The watch app is running in the background
            
    Using the traditional Cordova callback method:
    
        watchLink.watchAppState(
            function (state) {
                ...
            });
        
    Using the Promise construct:
    
        watchLink.watchAppState().then(
            function (state) {
                ...
            });
    */
    
    _watchLink.watchApplicationState = function(callback, error) { 
        if (!_watchLink.initialized) {
            _watchLink.errorLog('watchLink.watchApplicationState: watch session not initialized');
            if (callback === undefined && error === undefined) {
                return new Promise(
                    function(resolve, reject) {
                            reject('uninitialized');
                    });
            }
            else
            if (error) {
                error('uninitialized');
            }
            return;
        }
        if (callback === undefined) {
            return new Promise(
                function(resolve) {
                    cordova.exec(
                        function(state) {
                            _watchLink.applicationState = state;
                            resolve(state);
                        }, null, 'WatchLink', 'watchApplicationState');
                });
        }
        cordova.exec(
            function(state) {
                _watchLink.applicationState = state;
                if (callback) {
                    callback(_watchLink.applicationState);
                }
            }, null, 'WatchLink', 'watchApplicationState');
    };
    
    /*
    watchLink.applicationStateChanged registers a callback to invoke when the 
    application state changes. The callback parameter represents the new application state.
    
        Parameter
            callback: function(state)
        Returns : true if registration succeeded, false otherwise
        
    Supply null to deregister a previously set callback. You can overwrite a previously 
    set callback with a different callback.
    */
    var applicationStateChangedCallback = null;
    _watchLink.applicationStateChanged = function(callback) {
        applicationStateChangedCallback = null;
        if (callback == null) {
            return;
        }
        if (typeof callback === 'function') {
            applicationStateChangedCallback = callback;
        }
        else {
            _watchLink.errorLog('watchLink.applicationStateChanged: parameter is not a function', callback);
        }
    };
    
    // Message session management
    
    /*
    watchLink.resetSession resets the current messaging session. Messages waiting 
    for transmission at the host and watch are discarded. Any messages arriving 
    from the watch with and obsolete session ID are discarded.
    
    watchLink.resetSession is called by watchLink initialization code because 
    restarting the Cordova app does not restart the Swift layer. Therefore, 
    the session reset is required to ensure messages dispatched but not processed 
    before the restart are discarded.
    */
    _watchLink.resetSession = function(completion, reason) {
        reason = reason || 'resetSession';
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.resetSession ignored: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            if (completion) {
                completion('uninitialized');
            }
        }
        cordova.exec(
            function() {
                _watchLink.log('Session RESET');
                if (completion) {
                    completion(true);
                }
            }, 
            function(msg) {
            if (!/^sessionreset/.test(msg)) {
                _watchLink.errorLog('Session RESET failed (will retry)--' + msg);
                _watchLink.resetSession();
            }
            }, 
            'WatchLink', 'resetSession', [reason]);
    };
    
    // Dictionary message passing
    
    /*
    The following are reserved message types and should not be used as message types 
    or as keys at the top level of user information, context or complication dictionaries
    */
    var reservedMsgTypes = new RegExp(
		"^(" + 
		"ACK" + "|" +
		"DATA" + "|" +
		"SESSION" + "|" +
		"RESET" + "|" +
		"SETLOGLEVEL" + "|" +
		"SETPRINTLOGLEVEL" + "|" +
		"UPDATEDCONTEXT" + "|" +
		"UPDATEDUSERINFO" + "|" +
		"WATCHLOG" + "|" +
		"WATCHERRORLOG" + "|" +
		"WATCHAPPLOG" +
        "WCSESSION" + ")$"
	);
    
    /* 
    watchLink.sendMessage sends a message to the watch. If the watch is available but 
    not reachable, the message is queued until the watch becomes reachable. 
    Messages are acknowledged by the watch and the success callback will not be 
    invoked until acknowlegement has been received.
    
    Messages are acknowledged by the watch and the success callback will not be 
    invoked until acknowlegement has been received.
            
    Note: if you want to omit acknowledgement, use the traditional Cordova 
    callback method and supply null for the success callback.
    
    Using the traditional Cordova callback method:
    
        // send with acknowledgement
        watchLink.sendMessage(msgType, msgBody, success, error); 
        
        // send without acknowledgement
        watchLink.sendMessage(msgType, msgBody, null, error);      
    
    Using the Promise construct:
            
        watchLink.sendMessage(msgType, msgBody)
            .then(success)
            .catch(error);
    */
    
    _watchLink.sendMessage = function(msgType, msgBody, success, error) {
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.sendMessage: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            if (success === undefined && error === undefined) {
                return new Promise(
                    function(resolve, reject) {
                            reject(_watchLink.initialized ? 'not available' : 'uninitialized');
                    });
            }
            else
            if (error) {
                error(_watchLink.initialized ? 'not available' : 'uninitialized');
            }
            return;
        }
        var err = '';
        if (typeof msgType !== 'string') {
            err = 'watchLink.sendMessage msgType is not a string: ' + typeof msgType;
        }
        else
        if (typeof msgBody !== 'object') {
            err = 'watchLink.sendMessage msgBody is not an object: ' + typeof msgBody;
        }
        else
        if (success != null && typeof success !== 'function') {
            err = 'watchLink.sendMessage success parameter is not a function: ' 
                + typeof success;
        }
        else
        if (error != null && typeof error !== 'function') {
            err = 'watchLink.sendMessage error parameter is not a function: ' 
                + typeof error;
        }
        else
        if (reservedMsgTypes.test(msgType)) {
            err = 'watchLink.sendMessage msgType is reserved: ' + typeof msgType;
        }
        if (err) {
            _watchLink.errorLog(err);
            return;
        }
        msgBody.TIMESTAMP = newTimestamp();
        if (typeof success === 'undefined' && typeof error === 'undefined') {
            return new Promise(
                function(resolve, reject) {
                    if (_watchLink.available !== true) {
                        reject('unavailable', msgType, msgBody);
                        return;
                    }
                    cordova.exec(resolve, reject, 'WatchLink', 'sendMessage', 
                                 [msgType || '', msgBody]);
                });
        }
        if (_watchLink.available !== true) {
            if (error) {
                error('unavailable', msgType, msgBody);
            }
            return;
        }
        if (success === null) {
            cordova.exec(success, error, 'WatchLink', 'sendMessageNoAck', 
                         [msgType || '', msgBody]);
        }
        else {
            cordova.exec(success, error, 'WatchLink', 'sendMessage', 
                         [msgType || '', msgBody]);
        }
    }; 
    
    /*
    watchLink.flushMessages flushes all outstanding messages from the queue. The 
    error handlers for flushed messages are NOT invoked and any acknowledgements 
    that subsequently arrive will be ignored (the success handlers will NOT be invoked).
    */
    
    _watchLink.flushMessages = function() {
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.flushMessages ignored: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            return;
        }
        cordova.exec(null, null, 'WatchLink', 'flushMessages', []);
    };
    
    
    /*
    watchLink.bindMessageHandler establishes a handler to process messages from the 
    watch of a matching message type.
    
    To handle an incoming message, the message type is extracted and each handler 
    with a matching expression is invoked with the message type and message body 
    as parameters.
    
    Processing continues until all matching expressions have been checked, or until 
    a handler returns false to halt processing.
    
        Parameters
            expr: <string> | <RegExp>
            handler: function(<string>, <object>)
        Returns : nothing
        
    The expression can be a string (requires an exact match) or a RegExp.
    
    Supplying null for the handler will unbind a previously bound handler.
    
    Supplying a handler for an existing match expression will overwrite the existing 
    handler for that expression.

    Supplying null for the match expression will set the default handler, unless it 
    is null also in which case the default handler will be unbound.
    */
    
    var messageHandlers = [],
        defaultMessageHandler = null;
    
    _watchLink.bindMessageHandler = function(expr, handler) {
        var reg,
            i,
            err = '';
        if (expr == null) {
            if (handler == null) {
                defaultMessageHandler = null;
                _watchLink.log('watchLink.bindMessageHandler deregistered default handler');
                return;
            }
            if (typeof handler !== 'function') {
                err = 'watchLink.bindMessageHandler parameter is not a function: ' 
                    + typeof handler;
                _watchLink.errorLog(err);
                return;
            }
            defaultMessageHandler = handler;
            _watchLink.log('watchLink.bindMessageHandler registered default handler');
            return;
        }
        if (typeof expr === 'string') {
            reg = new RegExp('^' + expr + '$');
        }
        else
        if (!(expr instanceof RegExp)) {
            err = 'watchLink.bindMessageHandler expr is not a string or RegExp: ' 
                + typeof expr;
            _watchLink.errorLog(err);
            return;
        }
        if (reservedMsgTypes.test(expr.toString())) {
            err = 'watchLink.bindMessageHandler expr uses reserved word ', 
                expr.toString();
            _watchLink.errorLog(err);
            return;
        }
        if (handler == null) {
            for (i = 0; i < messageHandlers.length; i++) {
                if (reg.toString() === messageHandlers[i].reg.toString()) {
                    messageHandlers.splice(i, 1);
                    _watchLink.log('watchLink.bindMessageHandler deregistered for ' + 
                                    reg.toString());
                    return;
                }
            }
            _watchLink.errorLog('watchLink.bindMessageHandler: cannot locate handler for RegExp: ', 
                            reg.toString());
            return;
        }
        if (typeof handler !== 'function') {
            err = 'watchLink.bindMessageHandler: parameter is not a function: ' 
                + typeof handler;
            _watchLink.errorLog(err);
            return;
        }
        for (i = 0; i < messageHandlers.length; i++) {
            if (reg.toString() === messageHandlers[i].reg.toString()) {
                messageHandlers[i].handler = handler;
                return;
            }
        }
        messageHandlers.push({ reg: reg, handler: handler });
    };
    
    // Data message passing
    
    /* 
    watchLink.sendDataMessage sends a data message to the watch. If the watch is 
    available but not reachable, the message is queued until the watch becomes reachable.
    
    Data messages are acknowledged by the watch and the success callback will not be 
    invoked until acknowlegement has been received.
            
    Note: if you want to omit acknowledgement, use the traditional Cordova callback 
    method and supply null for the success callback.
    
    Using the traditional Cordova callback method:
    
         // send with acknowledgement
        watchLink.sendDataMessage(msgData, success, error);   
        
        // send without acknowledgement
        watchLink.sendDataMessage(msgData, null, error);    
    
    Using the Promise construct:
            
        watchLink.sendDataMessage(msgData)
            .then(success)
            .catch(error);
    */
    
    _watchLink.sendDataMessage = function(msgData, success, error) {
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.sendDataMessage: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            if (success === undefined && error === undefined) {
                return new Promise(
                    function(resolve, reject) {
                            reject(_watchLink.initialized ? 'not available' : 'uninitialized');
                    });
            }
            else
            if (error) {
                error(_watchLink.initialized ? 'not available' : 'uninitialized');
            }
            return;
        }
        var err = '';
        if (msgData == null) {
            err = 'watchLink.sendDataMessage msgData is null';
        }
        else
        if (typeof msgData !== 'object') {
            err = 'watchLink.sendDataMessage msgData is not an object: ' + typeof msgBody;
        }
        else
        if (success != null && typeof success !== 'function') {
            err = 'watchLink.sendDataMessage success parameter is not a function: ' 
                + typeof success;
        }
        else
        if (error != null && typeof error !== 'function') {
            err = 'watchLink.sendDataMessage error parameter is not a function: ' 
                + typeof error;
        }
        if (err) {
            _watchLink.errorLog(err);
            return;
        }
        if (typeof success === 'undefined' && typeof error === 'undefined') {
            return new Promise(
                function(resolve, reject) {
                    if (_watchLink.available !== true) {
                        reject('unavailable', msgData);
                        return;
                    }
                    cordova.exec(resolve, reject, 'WatchLink', 'sendDataMessage', [msgData]);
                });
        }
        if (_watchLink.available !== true) {
            if (error) {
                error('unavailable', msgData);
            }
            return;
        }
        if (success === null) {
            cordova.exec(success, error, 'WatchLink', 'sendDataMessageNoAck', [msgData]);
        }
        else {
            cordova.exec(success, error, 'WatchLink', 'sendDataMessage', [msgData]);
        }
    }; 
    
    /*
    watchLink.flushDataMessages flushes all outstanding data messages from the queue. 
    The error handlers for flushed data messages are NOT invoked and any acknowledgements 
    that subsequently arrive will be ignored (the success handlers will NOT be invoked).
    */
    
    _watchLink.flushDataMessages = function() {
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.flushDataMessages ignored: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            return;
        }
        cordova.exec(null, null, 'WatchLink', 'flushDataMessages', []);
    };
    
    
    /*
    watchLink.bindDataMessageHandler establishes a handler to process data messages 
    from the watch.
    
        Parameters
            handler: function(<ArrayBuffer>)
        Returns : nothing
        
    Supplying null for the handler will unbind a previously bound handler.
    
    Supplying a handler will overwrite an existing handler.
    */
    
    var dataMessageHandler = null;
    
    _watchLink.bindDataMessageHandler = function(handler) {
        var err = '';
        if (handler == null) {
            dataMessageHandler = null;
            _watchLink.log('watchLink.bindDataMessageHandler deregistered handler');
            return;
        }
        if (typeof handler !== 'function') {
            err = 'watchLink.bindDataMessageHandler parameter is not a function: ' 
                + typeof handler;
            _watchLink.errorLog(err);
            return;
        }
        dataMessageHandler = handler;
        _watchLink.log('watchLink.bindDataMessageHandler registered handler');
    };
    
    // User information transfers
    
    /*
    watchLink.sendUserInfo sends a user information update to the watch. If the watch 
    is available but not reachable, the information is transmitted in background and 
    acknowledged when the watch becomes reachable and processes the update.
    
    User information updates are acknowledged by the watch and the success callback will 
    not be invoked until acknowlegement has been received.
            
    Note: if you want to omit acknowledgement, use the traditional Cordova callback 
    method and supply null for the success callback.
    
    Using the traditional Cordova callback method:
    
        // send with acknowledgement 
        watchLink.sendUserInfo(userInfo, success, error);   
        
        // send without acknowledgement 
        watchLink.sendUserInfo(userInfo, null, error);   
    
    Using the Promise construct:
    
        watchLink.sendUserInfo(userInfo)
            .then(success)
            .catch(error);
    */
    _watchLink.sendUserInfo = function(userInfo, success, error) {
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.sendUserInfo: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            if (success === undefined && error === undefined) {
                return new Promise(
                    function(resolve, reject) {
                            reject(_watchLink.initialized ? 'not available' : 'uninitialized');
                    });
            }
            else
            if (error) {
                error(_watchLink.initialized ? 'not available' : 'uninitialized');
            }
            return;
        }
        var err = '';
        if (userInfo == null) {
             err = 'watchLink.sendUserInfo userInfo is null';
        }
        else
        if (typeof userInfo !== 'object') {
             err = 'watchLink.sendUserInfo userInfo is not an object: ' + typeof userInfo;
        }
        else
        if (success != null && typeof success !== 'function') {
            err = 'watchLink.sendUserInfo success parameter is not a function: ' 
                + typeof success;
            return;
        }
        else
        if (error != null && typeof error !== 'function') {
            err = 'watchLink.sendUserInfo error parameter is not a function: ' 
                + typeof error;
        }
        if (err) {
            _watchLink.errorLog(err);
            return;
        }
        userInfo.TIMESTAMP = newTimestamp();
        if (typeof success === 'undefined' && typeof error === 'undefined') {
            return new Promise(
                function(resolve, reject) {
                    if (_watchLink.available !== true) {
                        reject('unavailable');
                        return;
                    }
                    cordova.exec(resolve, reject, 'WatchLink', 'sendUserInfo', [userInfo]);
                });
        }
        if (_watchLink.available !== true) {
            if (error) {
                error('unavailable');
            }
            return;
        }
        if (success === null) {
            cordova.exec(success, error, 'WatchLink', 'sendUserInfoNoAck', [userInfo]);
        }
        else {
            cordova.exec(success, error, 'WatchLink', 'sendUserInfo', [userInfo]);
        }
    };
    
    /*
    watchLink.queryUserInfo obtains the status of a user information transfer 
    via the TIMESTAMP set by watchLink.sendUserInfo.
    */
    
    _watchLink.queryUserInfo = function(timestamp, success, error) {
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.queryUserInfo: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            if (success === undefined && error === undefined) {
                return new Promise(
                    function(resolve, reject) {
                            reject(_watchLink.initialized ? 'not available' : 'uninitialized');
                    });
            }
            else
            if (error) {
                error(_watchLink.initialized ? 'not available' : 'uninitialized');
            }
            return;
        }
        var err = '';
        if (typeof timestamp !== 'number') {
            err = 'watchLink.queryUserInfo timestamp is not a number: ' 
                + typeof timestamp;
        }
        else
        if (success != null && typeof success !== 'function') {
            err = 'watchLink.queryUserInfo success parameter is not a function: ' 
                + typeof success;
        }
        else
        if (error != null && typeof error !== 'function') {
            err = 'watchLink.queryUserInfo error parameter is not a function: ' 
                + typeof error;
        }
        if (err) {
            _watchLink.errorLog(err);
            return;
        }
        if (success === undefined && error === undefined) {
            return new Promise(
                function(resolve, reject) {
                    if (_watchLink.available !== true) {
                        reject('unavailable');
                        return;
                    }
                    cordova.exec(resolve, reject, 'WatchLink', 'queryUserInfo', 
                                 [timestamp]);
                });
        }
        if (_watchLink.available !== true) {
            error('unavailable');
            return;
        }
        cordova.exec(success, error, 'WatchLink', 'queryUserInfo', [timestamp]);
    };
    
    /*
    watchLink.cancelUserInfo cancels a user information transfer via the TIMESTAMP 
    set by watchLink.sendUserInfo.
    */
    
    _watchLink.cancelUserInfo = function(timestamp, success, error) {
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.cancelUserInfo: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            if (success === undefined && error === undefined) {
                return new Promise(
                    function(resolve, reject) {
                            reject(_watchLink.initialized ? 'not available' : 'uninitialized');
                    });
            }
            else
            if (error) {
                error(_watchLink.initialized ? 'not available' : 'uninitialized');
            }
            return;
        }
        var err = '';
        if (typeof timestamp !== 'number') {
            err = 'watchLink.cancelUserInfo timestamp is not a number: ' 
                + typeof timestamp;
        }
        else
        if (success != null && typeof success !== 'function') {
            err = 'watchLink.cancelUserInfo success parameter is not a function: ' 
                + typeof success;
        }
        else
        if (error != null && typeof error !== 'function') {
            err = 'watchLink.cancelUserInfo error parameter is not a function: ' 
                + typeof error;
        }
        if (err) {
            _watchLink.errorLog(err);
            return;
        }
        if (success === undefined && error === undefined) {
            return new Promise(
                function(resolve, reject) {
                    if (_watchLink.available !== true) {
                        reject('unavailable');
                        return;
                    }
                    cordova.exec(resolve, reject, 'WatchLink', 'cancelUserInfo', 
                                 [timestamp]);
                });
        }
        if (_watchLink.available !== true) {
            error('unavailable');
            return;
        }
        cordova.exec(success, error, 'WatchLink', 'cancelUserInfo', [timestamp]);
    };
    
    /*
    watchLink.flushUserInfoTransfers flushes all outstanding user information transfers 
    from the queue. The error handlers for flushed user information transfers are NOT 
    invoked and any acknowledgements that subsequently arrive will be ignored (the success 
    handlers will NOT be invoked).   
    */
    _watchLink.flushUserInfoTransfers = function() {
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.flushUserInfoTransfers ignored: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            return;
        }
        cordova.exec(null, null, 'WatchLink', 'flushUserInfo', []);
    };
    
    /*
    watchLink.outstandingUserInfoTransfers obtains the status of all in-progress 
    user information transfers.
    */
    
    _watchLink.outstandingUserInfoTransfers = function(success, error) {
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.outstandingUserInfoTransfers: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            if (success === undefined && error === undefined) {
                return new Promise(
                    function(resolve, reject) {
                            reject(_watchLink.initialized ? 'not available' : 'uninitialized');
                    });
            }
            else
            if (error) {
                error(_watchLink.initialized ? 'not available' : 'uninitialized');
            }
            return;
        }
        var err = '';
        if (success != null && typeof success !== 'function') {
            err = 'watchLink.outstandingUserInfoTransfers success parameter is not a function: ' 
                + typeof success;
        }
        else
        if (error != null && typeof error !== 'function') {
            err = 'watchLink.outstandingUserInfoTransfers error parameter is not a function: ' 
                + typeof error;
        }
        if (err) {
            _watchLink.errorLog(err);
            return;
        }
        if (success == null && error == null) {
            return new Promise(
                function(resolve, reject) {
                    if (_watchLink.available !== true) {
                        reject('unavailable');
                        return;
                    }
                    cordova.exec(resolve, reject, 'WatchLink', 
                                 'outstandingUserInfoTransfers', []);
                });
        }
        if (_watchLink.available !== true) {
            error('unavailable');
            return;
        }
        cordova.exec(success, error, 'WatchLink', 'outstandingUserInfoTransfers', []);
    };
    
    /*
    watchLink.bindUserInfoHandler establishes a handler to process application user 
    information updates from the watch.
    
        Parameter
            handler: function(<object>)
        Returns : nothing
        
    Supply null to deregister a previously set callback. You can overwrite a previously set 
    handler with a different handler.
    
    The handler parameter represents the updated user information object.
    */
    var userInfoHandler = null;
    
    _watchLink.bindUserInfoHandler = function(handler) {
        var err = '';
        userInfoHandler = null;
        if (handler == null) {
            return;
        }
        if (typeof handler !== 'function') {
            err = 'watchLink.bindUserInfoHandler parameter is not a function: ' 
                + typeof handler;
            _watchLink.errorLog(err);
            return;
        }
        userInfoHandler = handler;
        _watchLink.log('watchLink.bindUserInfoHandler registered user information handler');
    };
    
    // Application context transfers
    
    /*
    watchLink.sendContext sends an application context update to the watch. If the watch is 
    available but not reachable, the application context is transmitted in background 
    and acknowledged when the watch becomes reachable and processes the update.
    
    Application context updates are acknowledged by the watch and the success callback will 
    not be invoked until acknowlegement has been received.
            
    Note: if you want to omit acknowledgement, use the traditional Cordova callback method 
    and supply null for the success callback.
    
    Using the traditional Cordova callback method:
    
        // send with acknowledgement
        watchLink.sendContext(userInfo, success, error);    
        
        // send without acknowledgement
        watchLink.sendContext(userInfo, null, error);       
    
    Using the Promise construct:
    
        watchLink.sendContext(userInfo)
            .then(success)
            .catch(error);
    */
    _watchLink.sendContext = function(context, success, error) {
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.sendContext: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            if (success === undefined && error === undefined) {
                return new Promise(
                    function(resolve, reject) {
                            reject(_watchLink.initialized ? 'not available' : 'uninitialized');
                    });
            }
            else
            if (error) {
                error(_watchLink.initialized ? 'not available' : 'uninitialized');
            }
            return;
        }
        var err = '';
        if (context == null) {
             err = 'watchLink.sendContext context is null';
        }
        else
        if (typeof context !== 'object') {
             err = 'watchLink.sendUserInfo userInfo is not an object: ' + typeof context;
        }
        else
        if (success != null && typeof success !== 'function') {
            err = 'watchLink.sendContext success parameter is not a function: ' 
                + typeof success;
            return;
        }
        else
        if (error != null && typeof error !== 'function') {
            err = 'watchLink.sendContext error parameter is not a function: ' 
                + typeof error;
        }
        else
        if (context.ACK != null || context.SESSION != null) {
            err = 'watchLink.sendContext userinfo contains reserved keys';
        }
        if (err) {
            _watchLink.errorLog(err);
            return;
        }
        context.TIMESTAMP = newTimestamp();
        if (typeof success === 'undefined' && typeof error === 'undefined') {
            return new Promise(
                function(resolve, reject) {
                    if (_watchLink.available !== true) {
                        reject('unavailable');
                        return;
                    }
                    cordova.exec(resolve, reject, 'WatchLink', 'sendContext', [context]);
                });
        }
        if (_watchLink.available !== true) {
            if (error) {
                error('unavailable');
            }
            return false;
        }
        if (success === null) {
            cordova.exec(success, error, 'WatchLink', 'sendContextNoAck', [context]);
        }
        else {
            cordova.exec(success, error, 'WatchLink', 'sendContext', [context]);
        }
    };
    
    /*
    watchLink.latestContextSent obtains the latest context transmitted.
    
    Using the traditional Cordova callback method:
    
        watchLink.latestContextSent(success, error);    
    
    Using the Promise construct:
    
        watchLink.latestContextSent()
            .then(success)
            .catch(error);
    */
    
    _watchLink.latestContextSent = function(success, error) {
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.latestContextSent: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            if (success === undefined && error === undefined) {
                return new Promise(
                    function(resolve, reject) {
                            reject(_watchLink.initialized ? 'not available' : 'uninitialized');
                    });
            }
            else
            if (error) {
                error(_watchLink.initialized ? 'not available' : 'uninitialized');
            }
            return;
        }
        var err = '';
        if (success != null && typeof success !== 'function') {
            err = 'watchLink.latestContextSent success parameter is not a function: ' 
                + typeof success;
        }
        else
        if (error != null && typeof error !== 'function') {
            err = 'watchLink.latestContextSent error parameter is not a function: ' 
                + typeof error;
        }
        if (err) {
            _watchLink.errorLog(err);
            return;
        }
        if (success === undefined && error === undefined) {
            return new Promise(
                function(resolve, reject) {
                    if (_watchLink.available !== true) {
                        reject('unavailable');
                        return;
                    }
                    cordova.exec(resolve, reject, 'WatchLink', 'latestContextSent', []);
                });
        }
        if (_watchLink.available !== true) {
            error('unavailable');
            return;
        }
        cordova.exec(success, error, 'WatchLink', 'latestContextSent', []);
    };
    
    /*
    watchLink.latestContextReceived obtains the latest context received.
    
    Using the traditional Cordova callback method:
    
        watchLink.latestContextReceived(success, error);    
    
    Using the Promise construct:
    
        watchLink.latestContextReceived()
            .then(success)
            .catch(error);
    */
    
    _watchLink.latestContextReceived = function(success, error) {
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.latestContextReceived: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            if (success === undefined && error === undefined) {
                return new Promise(
                    function(resolve, reject) {
                            reject(_watchLink.initialized ? 'not available' : 'uninitialized');
                    });
            }
            else
            if (error) {
                error(_watchLink.initialized ? 'not available' : 'uninitialized');
            }
            return;
        }
        var err = '';
        if (success != null && typeof success !== 'function') {
            err = 'watchLink.latestContextReceived success parameter is not a function: ' 
                + typeof success;
        }
        else
        if (error != null && typeof error !== 'function') {
            err = 'watchLink.latestContextReceived error parameter is not a function: ' 
                + typeof error;
        }
        if (err) {
            _watchLink.errorLog(err);
            return;
        }
        if (success === undefined && error === undefined) {
            return new Promise(
                function(resolve, reject) {
                    if (_watchLink.available !== true) {
                        reject('unavailable');
                        return;
                    }
                    cordova.exec(resolve, reject, 'WatchLink', 'latestContextReceived', []);
                });
        }
        if (_watchLink.available !== true) {
            error('unavailable');
            return;
        }
        cordova.exec(success, error, 'WatchLink', 'latestContextReceived', []);
    };
    
    /*
    watchLink.flushContextTransfers flushes all outstanding application context transfers 
    from the queue. The error handlers for flushed application context transfers are NOT 
    invoked and any acknowledgements that subsequently arrive will be ignored (the success 
    handlers will NOT be invoked).   
    */
    _watchLink.flushContextTransfers = function() {
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.flushContextTransfers ignored: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            return;
        }
        cordova.exec(null, null, 'WatchLink', 'flushContextTransfers', []);
    };
    
    /*
    watchLink.bindContextHandler establishes a handler to process application context 
    updates from the watch.
    
        Parameter
            handler: function(<object>)
        Returns : nothing
        
    Supply null to deregister a previously set callback. You can overwrite a previously set 
    handler with a different handler.
    
    The handler parameter represents the updated user information object.
    */
    var contextHandler = null;
    
    _watchLink.bindContextHandler = function(handler) {
        var err = '';
        contextHandler = null;
        if (handler == null) {
            return;
        }
        if (typeof handler !== 'function') {
            err = 'watchLink.bindContextHandler parameter is not a function: ' + typeof handler;
            _watchLink.errorLog(err);
            return;
        }
        contextHandler = handler;
        _watchLink.log('watchLink.bindContextHandler registered context handler');
    };
   
    
    /*
    watchLink.sendComplicationInfo sends a complication information update to the watch. If 
    the watch is available but not reachable,  the complication information is transmitted 
    in background and acknowledged when the watch becomes reachable and processes the 
    update.
    
        watchLink.sendComplicationInfo(complicationInfo);    
    */
    _watchLink.sendComplicationInfo = function(complicationInfo) {
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.sendComplicationInfo ignored: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            return;
        }
        var err = '';
        if (complicationInfo == null) {
             err = 'watchLink.sendComplicationInfo userInfo is null';
        }
        else
        if (typeof complicationInfo !== 'object') {
             err = 'watchLink.sendComplicationInfo userInfo is not an object: ' 
                 + typeof context;
        }
        else
        if (complicationInfo.ACK != null || complicationInfo.TIMESTAMP != null || 
            complicationInfo.TIMESTAMP != null || complicationInfo.SESSION != null) {
            err = 'watchLink.sendComplicationInfo userinfo contains reserved keys';
        }
        if (err) {
            _watchLink.errorLog(err);
            return false;
        }
        complicationInfo.TIMESTAMP = newTimestamp();
        if (_watchLink.available !== true) {
            return false;
        }
        cordova.exec(null, null, 'WatchLink', 'sendComplicationInfo', [complicationInfo]);
        return true;
    };
    
    /*
    watchLink.queryComplication obtains the status of a user information transfer via the 
    TIMESTAMP set by watchLink.sendComplicationInfo.
    */
    
    _watchLink.queryComplication = function(timestamp, success, error) {
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.queryComplication: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            if (success === undefined && error === undefined) {
                return new Promise(
                    function(resolve, reject) {
                            reject(_watchLink.initialized ? 'not available' : 'uninitialized');
                    });
            }
            else
            if (error) {
                error(_watchLink.initialized ? 'not available' : 'uninitialized');
            }
            return;
        }
        var err = '';
        if (typeof TIMESTAMP !== 'number') {
            err = 'watchLink.queryComplication userInfoID is not a number: ' 
                + typeof userInfoID;
        }
        else
        if (success != null && typeof success !== 'function') {
            err = 'watchLink.queryComplication success parameter is not a function: ' 
                + typeof success;
        }
        else
        if (error != null && typeof error !== 'function') {
            err = 'watchLink.queryComplication error parameter is not a function: ' 
                + typeof error;
        }
        if (err) {
            _watchLink.errorLog(err);
            return;
        }
        if (success === undefined && error === undefined) {
            return new Promise(
                function(resolve, reject) {
                    if (_watchLink.available !== true) {
                        reject('unavailable');
                        return;
                    }
                    cordova.exec(resolve, reject, 'WatchLink', 'queryComplication', 
                                 [timestamp]);
                });
        }
        if (_watchLink.available !== true) {
            error('unavailable');
            return;
        }
        cordova.exec(success, error, 'WatchLink', 'queryComplication', [timestamp]);
    };
    
    /*
    watchLink.cancelComplication cancels a complication transfer via the TIMESTAMP set by 
    watchLink.sendComplicationInfo.
    
    Using the traditional Cordova callback method:
    
        watchLink.cancelComplication(timestamp, success, error);    
    
    Using the Promise construct:
    
        watchLink.cancelComplication(timestamp)
            .then(success)
            .catch(error);
    */
    
    _watchLink.cancelComplication = function(timestamp, success, error) {
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.cancelComplication: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            if (success === undefined && error === undefined) {
                return new Promise(
                    function(resolve, reject) {
                            reject(_watchLink.initialized ? 'not available' : 'uninitialized');
                    });
            }
            else
            if (error) {
                error(_watchLink.initialized ? 'not available' : 'uninitialized');
            }
            return;
        }
        var err = '';
        if (typeof timestamp !== 'number') {
            err = 'watchLink.cancelComplication userInfoID is not a number: ' 
                + typeof userInfoID;
        }
        else
        if (success != null && typeof success !== 'function') {
            err = 'watchLink.cancelComplication success parameter is not a function: ' 
                + typeof success;
        }
        else
        if (error != null && typeof error !== 'function') {
            err = 'watchLink.cancelComplication error parameter is not a function: ' 
                + typeof error;
        }
        if (err) {
            _watchLink.errorLog(err);
            return;
        }
        if (success === undefined && error === undefined) {
            return new Promise(
                function(resolve, reject) {
                    if (_watchLink.available !== true) {
                        reject('unavailable');
                        return;
                    }
                    cordova.exec(resolve, reject, 'WatchLink', 'cancelComplication', 
                                 [timestamp]);
                });
        }
        if (_watchLink.available !== true) {
            error('unavailable');
            return;
        }
        cordova.exec(success, error, 'WatchLink', 'cancelComplication', [timestamp]);
    };
    
    /*
    watchLink.outstandingComplicationTransfers obtains the status of all in-progress 
    complication transfers.
    
    Using the traditional Cordova callback method:
    
        watchLink.outstandingComplicationTransfers(success, error);    
    
    Using the Promise construct:
    
        watchLink.outstandingComplicationTransfers()
            .then(success)
            .catch(error);
    */
    
    _watchLink.outstandingComplicationTransfers = function(success, error) {
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.outstandingComplicationTransfers: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            if (success === undefined && error === undefined) {
                return new Promise(
                    function(resolve, reject) {
                            reject(_watchLink.initialized ? 'not available' : 'uninitialized');
                    });
            }
            else
            if (error) {
                error(_watchLink.initialized ? 'not available' : 'uninitialized');
            }
            return;
        }
        var err = '';
        if (success != null && typeof success !== 'function') {
            err = 'watchLink.outstandingComplicationTransfers success parameter is not a function: ' 
                + typeof success;
        }
        else
        if (error != null && typeof error !== 'function') {
            err = 'watchLink.outstandingComplicationTransfers error parameter is not a function: ' 
                + typeof error;
        }
        if (err) {
            _watchLink.errorLog(err);
            return;
        }
        if (success === undefined && error === undefined) {
            return new Promise(
                function(resolve, reject) {
                    if (_watchLink.available !== true) {
                        reject('unavailable');
                        return;
                    }
                    cordova.exec(resolve, reject, 'WatchLink', 
                                 'outstandingComplicationTransfers', []);
                });
        }
        if (_watchLink.available !== true) {
            error('unavailable');
            return;
        }
        cordova.exec(success, error, 'WatchLink', 'outstandingComplicationTransfers', []);
    };
    
    /*
    watchLink.flushComplicationTransfers cancels all outstanding user information transfers. 
    */
    
    _watchLink.flushComplicationTransfers = function() {
        cordova.exec(null, null, 'WatchLink', 'flushComplicationTransfers', []);
    };
    
    /*
    watchLink.queryComplicationQuota obtains the number of daily complications remaining 
    in quota.
    
    Using the traditional Cordova callback method:
    
        watchLink.queryComplicationQuota(success, error);    
    
    Using the Promise construct:
    
        watchLink.queryComplicationQuota()
            .then(success)
            .catch(error);
    */
    
    _watchLink.queryComplicationQuota = function(success, error) {
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.queryComplicationQuota: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            if (success === undefined && error === undefined) {
                return new Promise(
                    function(resolve, reject) {
                            reject(_watchLink.initialized ? 'not available' : 'uninitialized');
                    });
            }
            else
            if (error) {
                error(_watchLink.initialized ? 'not available' : 'uninitialized');
            }
            return;
        }
        var err = '';
        if (typeof timestamp !== 'number') {
            err = 'watchLink.queryComplicationQuota userInfoID is not a number: ' 
                + typeof userInfoID;
        }
        else
        if (success != null && typeof success !== 'function') {
            err = 'watchLink.queryComplicationQuota success parameter is not a function: ' 
                + typeof success;
        }
        else
        if (error != null && typeof error !== 'function') {
            err = 'watchLink.queryComplicationQuota error parameter is not a function: ' 
                + typeof error;
        }
        if (err) {
            _watchLink.errorLog(err);
            return;
        }
        if (success === undefined && error === undefined) {
            return new Promise(
                function(resolve, reject) {
                    if (_watchLink.available !== true) {
                        reject('unavailable');
                        return;
                    }
                    cordova.exec(resolve, reject, 'WatchLink', 'queryComplicationQuota', 
                                 []);
                });
        }
        if (_watchLink.available !== true) {
            error('unavailable');
            return;
        }
        cordova.exec(success, error, 'WatchLink', 'queryComplicationQuota', []);
    };
    
    // Scheduled local notifications
    
    /* 
    watchLink.requestNotificationPermission requests permission from the user to issue notifications 
    
    Using the traditional Cordova callback method:

        watchLink.requestNotificationPermission(allowSound, success, error);   
            allowSound = <Boolean>, whether to include alert sounds in the request
    
    Using the Promise construct:
    
        watchLink.requestNotificationPermission(allowSound)
            .then(success)
            .catch(error);
    */
    
    _watchLink.requestNotificationPermission = function(allowSound, success, error) {
        var err = '';
        if (typeof allowSound !== 'boolean') {
            err = 'watchLink.requestNotificationPermission allowSound is not a boolean';
        }
        else
        if (success != null && typeof success !== 'function') {
            err = 'watchLink.requestNotificationPermission success parameter is not a function: ' 
                + typeof success;
        }
        else
        if (error != null && typeof error !== 'function') {
            err = 'watchLink.requestNotificationPermission error parameter is not a function: ' 
                + typeof error;
        }
        if (err) {
            _watchLink.errorLog(err);
            return;
        }
        if (success === undefined && error === undefined) {
            return new Promise(
                function(resolve, reject) {
                    cordova.exec(resolve, reject, 'WatchLink', 'requestNotificationPermission', 
                                 [allowSound]);
                });
        }
        cordova.exec(success, error, 'WatchLink', 'requestNotificationPermission', [allowSound]);
            
    };
    
    /*
    Notification handling
        
        iOS app                         WatchOS app     Notification
        
        Foreground, screen on           Foreground      iOS delegate
        
        Background/off, screen on       Foreground      iOS alert
        
        Foreground, screen off          Foreground      iOS banner + WatchOS delegate
        
        Background/off, screen off      Foreground      iOS banner + WatchOS delegate
        
        Foreground, screen on           Background      iOS delegate
        
        Background/off, screen on       Background      iOS alert
        
        Foreground, screen off          Background      iOS banner/WatchOS alert
        
        Background/off, screen off      Background      iOS banner/WatchOS alert
    
    
    */
    
    /*
    watchLink.scheduleNotification schedules a notification
    
    Using the traditional Cordova callback method:

        watchLink.scheduleNotification(trigger, payload, success, error);   
    
    Using the Promise construct:
    
        watchLink.scheduleNotification(trigger, payload)
            .then(success)
            .catch(error);
    */
    
    _watchLink.scheduleNotification = function(trigger, payload, success, error) {
        var err = '',
            el,
            delay = null,
            notifyTime,
            triggerClone = {},
            payloadClone;
        if (typeof trigger === 'number') {
            if (trigger < 0) {
                err = 'watchLink.scheduleNotification trigger is invalid: ' + trigger;
            }
            else {
                delay = trigger;
            }
        }
        else
        if (trigger == null) {
            delay = 0;
        }
        else
        if (typeof trigger !== 'object') {
            err = 'watchLink.scheduleNotification trigger is not an object or number: ' + typeof trigger;
        }
        else {
            for (el in trigger) {
                if (trigger.hasOwnProperty(el) && trigger[el] != null) {
                    if (typeof trigger[el] !== 'number') {
                        err = 'watchLink.scheduleNotification trigger ' + el + ' is not a number: ' + typeof trigger[el];
                        break;
                    }
                    if (!/^(year|month|day|hour|minute|second|delay)$/.test(el)) {
                        err = 'watchLink.scheduleNotification trigger element ' + el + ' is not valid';
                        break;
                    }
                    if (trigger[el] < 0) {
                        err = 'watchLink.scheduleNotification trigger ' + el + ' is not valid: ' + trigger[el];
                        break;
                    }
                }
            }
        }
        if (err === '') {
            var date = new Date();
            if (delay == null) {
                triggerClone.year = trigger.year || date.getFullYear();
                triggerClone.month = trigger.month || date.getMonth() + 1;
                triggerClone.day = trigger.day || date.getDay();
                triggerClone.hour = trigger.hour || date.getHours();
                triggerClone.minute = trigger.minute || date.getMinutes();
                triggerClone.second = trigger.second || date.getSeconds();
                notifyTime = Date.parse('' + triggerClone.year + '-' + triggerClone.month + '-' + triggerClone.day + ' ' +
                                        triggerClone.hour + ':' + triggerClone.minute + ':' + triggerClone.second);
               if (isNaN(notifyTime)) {
                    err = 'watchLink.scheduleNotification trigger ' + '' + triggerClone.year + '-' + triggerClone.month +
                        '-' + triggerClone.day + ' ' +   triggerClone.hour +
                        ':' + triggerClone.minute + ':' + triggerClone.second + ' is not a valid date-time';
                }
                else
                if (notifyTime  < date.getTime()) {
                    err = 'watchLink.scheduleNotification trigger ' + '' + triggerClone.year + '-' + triggerClone.month +
                    '-' + triggerClone.day + ' ' +   triggerClone.hour +
                    ':' + triggerClone.minute + ':' + triggerClone.second + ' seconds is earlier than current date-time';
                }
            }
            else {
                triggerClone.delay = delay;
                notifyTime = date.getTime() + triggerClone.delay*1000;
            }
        }
        if (err === '') {
            try {
                payloadClone = JSON.parse(JSON.stringify(payload));
            }
            catch(error) {
                err = 'payload error: ' + error.message;
            }
        }
        if (err === '') {
            for (el in payloadClone) {
                if (trigger.hasOwnProperty(el)) {      
                    if (['title','subtitle','body','userInfo'].indexOf(el)) {
                        err = 'watchLink.scheduleNotification unknown payload element: ' + el;
                        break;
                    }
                    if (typeof payload[el] !== 'string' && (el !== 'userInfo' || typeof payload[el] !== 'object')) {
                        err = 'watchLink.scheduleNotification invalid payload element type: ' + el + ' is ' + (typeof payload[el]);
                        break;
                    }
                }
            }
        }
        if (err === '' && payloadClone.title == null) {
            err = 'watchLink.scheduleNotification payload missing title';
        }
        if (err === '') {
            if (payloadClone.userInfo == null) {
                payloadClone.userInfo = { TIMESTAMP: notifyTime };
            }
            else {
                payloadClone.userInfo.TIMESTAMP = notifyTime;
            }
            if (success != null && typeof success !== 'function') {
                err = 'watchLink.scheduleNotification success parameter is not a function: ' 
                    + typeof success;
            }
            else
            if (error != null && typeof error !== 'function') {
                err = 'watchLink.scheduleNotification error parameter is not a function: ' 
                    + typeof error;
            }
        }
        if (err) {
            _watchLink.errorLog(err);
            return;
        }
        if (success === undefined && error === undefined) {
            return new Promise(
                function(resolve, reject) {
                    cordova.exec(resolve, reject, 'WatchLink', 'scheduleNotification', 
                                 [triggerClone, payloadClone]);
                });
        }
        cordova.exec(success, error, 'WatchLink', 'scheduleNotification', [triggerClone, payloadClone]);
    };
    
    /*
    watchLink.retrieveNotifications retrieves all pending notifications
    
    Using the traditional Cordova callback method:

        watchLink.retrieveNotifications(success, error);   
    
    Using the Promise construct:
    
        watchLink.retrieveNotifications()
            .then(success)
            .catch(error);
    */
    
    _watchLink.retrieveNotifications = function(success, error) {
        var err = '';
        if (success != null && typeof success !== 'function') {
            err = 'watchLink.retrieveNotifications success parameter is not a function: ' 
                + typeof success;
        }
        else
        if (error != null && typeof error !== 'function') {
            err = 'watchLink.retrieveNotifications error parameter is not a function: ' 
                + typeof error;
        }
        if (err) {
            _watchLink.errorLog(err);
            return;
        }
        if (success === undefined && error === undefined) {
            return new Promise(
                function(resolve, reject) {
                    cordova.exec(resolve, reject, 'WatchLink', 'retrieveNotifications');
                });
        }
        cordova.exec(success, error, 'WatchLink', 'retrieveNotifications');
    };
    
    /*
    watchLink.cancelNotification cancels a notification

        watchLink.cancelNotification(timestamp);   
    */
    
    _watchLink.cancelNotification = function(timestamp) {
        var err = '';
        if (typeof timestamp !== 'number') {
            err = 'watchLink.cancelNotification timestamp is not a string: ' + typeof timestamp;
        }
        if (err !== '') {
            _watchLink.errorLog(err);
            return;
        }
        cordova.exec(null, null, 'WatchLink', 'cancelNotification', [timestamp]);
    };

    /*
    watchLink.cancelAllNotifications cancels all pending notifications

        watchLink.cancelNotification(timestamp);   
    */

    _watchLink.cancelAllNotifications = function() {
        cordova.exec(null, null, 'WatchLink', 'cancelAllNotifications');
    };
    
    var notificationHandler = null;
    
    /*
    watchLink.bindNotificationHandler binds a handler to process notifications that
    the user clicks on.

        watchLink.bindNotificationHandler(handler)
            handler = function(userInfo), invoked with the userInfo of the notification
                userInfo.TIMESTAMP is the timestamp returned when the notifcation was scheduled
                use handler = null to cancel a previously bound handler
                otherwise handler will overwrite any previously bound handler
    */
        
    _watchLink.bindNotificationHandler = function(handler) {
        var err = '';
        if (handler == null) {
            notificationHandler = null;
            return;
        }
        if (handler != null && typeof handler !== 'function') {
            err = 'watchLink.bindNotificationHandler handler parameter is not a function: ';
        }
        if (err !== '') {
            _watchLink.errorLog(err);
            return;
        }
        notificationHandler = handler;
    };
    
    /*
    watchLink.showDelegatedNotification sets whether to display delegated notifications
    
        watchLink.showDelegatedNotification(show)
            show = <boolean>, whether to show delegated notifications
    */
    _watchLink.showDelegatedNotification = function(show) {
        var err = '';
        if (typeof show !== 'boolean') {
            err = '    watchLink.showDelegatedNotification: parameter is not boolean: ' + typeof show;
        }
        if (err) {
            _watchLink.errorLog(err);
            return;
        }
        cordova.exec(null, null, 'WatchLink', 'showDelegatedNotification', [show]);
    };
    
    var notificationDelegate = null;
    
    /*
    watchLink.bindNotificationDelegate binds a handler to process notifications that
    arise when the app is in foreground and would normally not be shown.

        watchLink.bindNotificationDelegate(handler)
            handler = function(userInfo), invoked with the userInfo of the notification
                userInfo.TIMESTAMP is the timestamp returned when the notifcation was scheduled
                use callback = null to cancel a previously bound handler
                otherwise callback will overwrite any previously bound handler
    */
        
    _watchLink.bindNotificationDelegate = function(handler) {
        var err = '';
        if (handler == null) {
            notificationDelegate = null;
            return;
        }
        if (handler != null && typeof handler !== 'function') {
            err = 'watchLink.bindNotificationDelegate handler parameter is not a function: ';
        }
        if (err !== '') {
            _watchLink.errorLog(err);
            return;
        }
        notificationDelegate = handler;
    };
    
    // Console log management
    
    /*
    log levels
    */
    _watchLink.allLogs = 3;
    _watchLink.appLogs = 2;
    _watchLink.errorLogs = 1;
    _watchLink.noLogs = 0;
    
    /*
    control Javascript logs
    */
   var JSlogLevel = 3;
    
    /*
    watchLink.JSlogLevel sets the Javascript log level. The default is 3 or "all"
    
    0 or "none"     no Javascript logs will be sent to the Javascript console
    1 or "error"    only Javascript error logs will be sent to the Javascript console 
                        (this is the default)
    2 or "app"      only Javascript error and application logs will be sent to the 
                        Javascript console
    3 or "all"      all Javascript logs will be sent to the Javascript console
    */
    
    _watchLink.JSlogLevel = function(n) {
        var level;
        if (/number|string/.test(typeof n)) {
            if (/^[0-3]$/.test('' + n)) {
                JSlogLevel = parseInt(n, 10);
            }
            else
            if (/^(all|app|error|none)$/.test('' + n)) {
                level = ['none','error','app','all'].indexOf(n);
                JSlogLevel = level;
            }
            else {
                _watchLink.errorLog("watchLink.JSlogLevel illegal parameter "
                              + JSON.stringify(n));
            }
        }
        else {
            _watchLink.errorLog("watchLink.JSlogLevel illegal parameter " + JSON.stringify(n));
        }
    };
    
    
    /*
    watchLink.appLogLevel overrides the watchLink.AppLogLevel set in config.xml
    
    0 or "none"     no iPhone logs will be sent to the Javascript console
    1 or "error"    only iPhone error logs will be sent to the Javascript console 
                        (this is the default)
    2 or "app"      only iPhone error and application logs will be sent to the 
                        Javascript console
    3 or "all"      all iPhone logs will be sent to the Javascript console
    */
    
    _watchLink.appLogLevel = function(n) {
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.appLogLevel ignored: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            return;
        }
        var level;
        if (/number|string/.test(typeof n)) {
            if (/^[0-3]$/.test('' + n)) {
                cordova.exec(
                    function() { 
                        console.log('appLogLevel set to ' + n); 
                    },
                    function() { 
                        _watchLink.errorLog('Error setting appLogLevel to ' + n); 
                    },
                    'WatchLink', 'setAppLogLevel', [parseInt(n, 10)]);
            }
            else
            if (/^(all|app|error|none)$/.test('' + n)) {
                level = ['none','error','app','all'].indexOf(n);
                cordova.exec(
                    function() { 
                        console.log('appLogLevel set to ' + n); 
                    },
                    function() { 
                        _watchLink.errorLog('Error setting appLogLevel to ' + n);
                    },
                    'WatchLink', 'setAppLogLevel', [level]);
            }
            else {
                _watchLink.errorLog("watchLink.appLogLevel illegal parameter "
                              + JSON.stringify(n));
            }
        }
        else {
            _watchLink.errorLog("watchLink.appLogLevel illegal parameter " + JSON.stringify(n));
        }
    };
    
    /*
    watchLink.watchLogLevel overrides the watchLink.WatchLogLevel set in config.xml
    
    0 or "none"     no watch logs will be sent to the Javascript console via the iPhone
    1 or "error"    only watch error logs will be sent to the Javascript console via 
                        the iPhone (this is the default)
    2 or "app"      only watch error and application logs will be sent to the 
                        Javascript console  via the iPhone
    3 or "all"      all watch logs will be sent to the Javascript console via the iPhone
    
    Watch logs are also sent to the Xcode console via "print" if the watchPrintLogLevel
    is set to display these messages
    */
    
    _watchLink.watchLogLevel = function(n) {
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.watchLogLevel ignored: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            return;
        }
        var level;
        if (/number|string/.test(typeof n)) {
            if (/^[0-3]$/.test('' + n)) {
                cordova.exec(
                    function() { 
                        console.log('watchLogLevel set to ' + n); 
                    },
                    function() { 
                        _watchLink.errorLog('Error setting watchLogLevel to ' + n); 
                    },
                    'WatchLink', 'setWatchLogLevel', [parseInt(n, 10)]);
            }
            else
            if (/^(all|app|error|none)$/.test('' + n)) {
                level = ['none','error','app','all'].indexOf(n);
                cordova.exec(
                    function() { 
                        console.log('watchLogLevel set to ' + n); 
                    },
                    function() { 
                        _watchLink.errorLog('Error setting watchLogLevel to ' + n); 
                    },
                    'WatchLink', 'setWatchLogLevel', [level]);
            }
            else {
                _watchLink.errorLog("watchLink.watchLogLevel illegal parameter " + JSON.stringify(n));
            }
        }
        else {
            _watchLink.errorLog("watchLink.watchLogLevel illegal parameter " + JSON.stringify(n));
        }
    };
    
    /*
    watchLink.watchPrintLogLevel overrides the watchLink.WatchPrintLogLevel set in config.xml
    
    0 or "none"     no watch logs will be sent to the Xcode console via "print"
    1 or "error"    only watch error logs will be sent to the Xcode console via "print" (this is the default)
    2 or "app"      only watch error and application logs will be sent to the Xcode console via "print"
    3 or "all"      all watch logs will be sent to the Xcode console via "print"
    */
    
    _watchLink.watchPrintLogLevel = function(n) {
        if (!_watchLink.initialized || _watchLink.available !== true) {
            _watchLink.errorLog('watchLink.watchPrintLogLevel ignored: watch session not ' + (_watchLink.initialized ? 'available' : 'initialized'));
            return;
        }
        var level;
        if (/number|string/.test(typeof n)) {
            if (/^[0-3]$/.test('' + n)) {
                cordova.exec(
                    function() { 
                        console.log('watchPrintLogLevel set to ' + n); 
                    },
                    function() { 
                        _watchLink.errorLog('Error setting watchPrintLogLevel to ' + n); 
                    },
                    'WatchLink', 'setWatchPrintLogLevel', [parseInt(n, 10)]);
            }
            else
            if (/^(all|app|error|none)$/.test('' + n)) {
                level = ['none','error','app','all'].indexOf(n);
                cordova.exec(
                    function() { 
                        console.log('watchPrintLogLevel set to ' + n); 
                    },
                    function() { 
                        _watchLink.errorLog('Error setting watchPrintLogLevel to ' + n); 
                    },
                    'WatchLink', 'setWatchPrintLogLevel', [level]);
            }
            else {
                _watchLink.errorLog("watchLink.watchPrintLogLevel illegal parameter " 
                              + JSON.stringify(n));
            }
        }
        else {
            _watchLink.errorLog("watchLink.watchPrintLogLevel illegal parameter " 
                          + JSON.stringify(n));
        }
    };

    /*
    watchLink.muteLog suppresses swiftLog and watchLog messages from the console
    */
    
    var muteLogs = false;
    
    _watchLink.muteLog = function() {
        muteLogs = true;
    };
    
    /*
    watchLink.unmuteLog restores writing swiftLog and watchLog messages to the console
    */
    
    _watchLink.unmuteLog = function() {
        muteLogs = false;
    };
    
    function logTimestamp() {
        var d = new Date(),
            hour = d.getHours(),
            minutes = d.getMinutes(),
            seconds = d.getSeconds(),
            milliseconds = d.getMilliseconds();
        return '[' + (hour < 10 ? '0' : '') + hour.toString() + ':' + (minutes < 10 ? '0' : '') + minutes.toString() + ':' + 
            (seconds < 10 ? '0' : '') + seconds.toString() + '.' + (milliseconds < 10 ? '00' : (milliseconds < 100 ? '0' : '')) + milliseconds.toString() + ']';
    }
    
    /* 
    Javascript logs
    */
    
    _watchLink.log = function(msg) {
        if (!muteLogs && JSlogLevel > 2) {
             console.log(logTimestamp() + ' ' + msg);
        }
    };
    
    _watchLink.appLog = function(msg) {
        if (!muteLogs && JSlogLevel > 1) {
            console.log('%c' + logTimestamp() + 'App: ' + msg, 'color:blue');
        }
    };
    
    _watchLink.errorLog = function(msg) {
        if (!muteLogs && JSlogLevel > 0) {
            console.warn(logTimestamp() + 'Error: ' + msg);
        }
    };
    
    /*
    Following are the watchLink internals
    */
    
    function handleMessage(msg) {
        var i,
            msgType = '',
            msgBody = (typeof msg === 'string' ? "" : null),
            timestamp,
            wasHandled = false;
        if (typeof msg === 'string') {
            if (/^<<Watch/.test(msg)) {
                if (!muteLogs) {
                    if (/\]Error/.test(msg)) {
                        console.warn(msg);
                    }
                    else
                    if (/\]App/.test(msg)) {
                        console.info('%c' + msg, 'color:blue');
                    }
                    else {
                        console.debug(msg);
                    }
                }
                return;
            }
            if (messageHandlers.length > 0 && /^[a-zA-Z0-9]+:/.test(msg)) {
                msgType = msg.replace(/(^[a-zA-Z0-9]+):[\w\W]*$/, '$1');
                msgBody = msg.replace(/(^[a-zA-Z0-9]+:)/, '');
            }
            else {
                msgBody = msg;
            }
        }
        else
        if (typeof msg === 'object'){
            msgType = msg.msgType;
            msgBody = msg.msg;
            timestamp = msg.TIMESTAMP;
        }
        if (msgType && typeof msgType === 'string') {
            for (i = 0; i < messageHandlers.length; i++) {
                if (messageHandlers[i].reg.test(msgType)) {
                    wasHandled = true;
                    msgBody.TIMESTAMP = timestamp;
                    if (messageHandlers[i].handler(msgType, msgBody) === false) {
                        return;
                    }
                }
            }
        }
        if (!wasHandled) {
            if (defaultMessageHandler) {
                defaultMessageHandler(msgType, msgBody);
            }
            else {
                _watchLink.errorLog('Incoming watch message not handled: ' + msgType + ': ' 
                              + JSON.stringify(msgBody));
            }
        }
    }
    
    this.wcSessionCommand = function(command, payload, error) {
        if (typeof command !== 'string' || !/^(sendMessage|sendDataMessage|updateUserInfo|updateContext)$/.test(command)) {
            _watchLink.errorLog('wcSessionCommand illegal command: ' + JSON.stringify(command));
            return;
        }
        if (payload == null | typeof payload !== 'object') {
            _watchLink.errorLog('wcSessionCommand illegal payload: ' + JSON.stringify(command));
            return;
        }
        if (command === 'UpdateUserInfo') {
            cordova.exec(null, null, 'WatchLink', 'wcSessionCommand', [command, payload]);
        }
        else {
            cordova.exec(null, error, 'WatchLink', 'wcSessionCommand', [command, payload]);
        }
    };
    
    function startLog() {
        _watchLink.log('STARTING logs');
        
        setTimeout( // enables above console.log to appear before Swift logs
            function() {
                cordova.exec(
                        function(msg) {
                            if (!muteLogs) {
                                if (/\]Error/.test(msg)) {
                                    console.debug('%c' + msg, 'color:red');
                                }
                                else
                                if (/\]App/.test(msg)) {
                                    console.debug('%c' + msg, 'color:blue');
                                }
                                else {
                                    console.info(msg);
                                }
                            }
                        },
                        function(msg) {
                            _watchLink.errorLog('watchLink.startLog error: ' + msg);
                        },
                        'WatchLink', 'startLog');
            },0);
    }
    
    var registeredContext = false,
        registeredMessages = false,
        registeredDataMessages = false,
        registeredUserInfo = false,
        registeredNotificationHandler = false,
        registeredNotificationDelegate = false;
    
    document.addEventListener("deviceready",
        function() {
            _watchLink.log('watchLink deviceready');
            _watchLink.ready(
                function() {
                    _watchLink.resetSession(
                        function() {
                            _watchLink.log('watchLink RESET complete');
                        }, 
                        'watchLink-deviceready');
                });
            startLog();
            cordova.exec(
                function() {
                    _watchLink.initialized = true;
                    watchLinkReadyProcs.forEach(
                        function(f) {
                            f();
                        });
                    watchLinkReadyProcs = [];
                },
                null, 'WatchLink', 'initializationComplete');
            cordova.exec(
                function(availability) {
                    _watchLink.available = availability;
                    //_watchLink.log('availability: ' + state);
                    if (availabilityChangedCallback && availability !== 'uninitialized') {
                        availabilityChangedCallback(availability);
                    }
                },
                null, 'WatchLink', 'availabilityChanged');
            cordova.exec(
                function(reachable) {
                    _watchLink.reachable = reachable;
                    //_watchLink.log('reachability: ' + reachable);
                    if (reachabilityChangedCallback && reachable !== 'uninitialized') {
                        reachabilityChangedCallback(reachable);
                    }
                },
                null, 'WatchLink', 'reachabilityChanged');
            cordova.exec(
                function(state) {
                    _watchLink.applicationState = state;
                    //_watchLink.log('applicationState: ' + JSON.stringify(state));
                    if (applicationStateChangedCallback && state !== 'uninitialized') {
                        applicationStateChangedCallback(_watchLink.applicationState);
                    }
                },
                null, 'WatchLink', 'applicationStateChanged');
            cordova.exec(
                function(msg) {
                    if (!registeredMessages) {
                        registeredMessages = true;
                        _watchLink.log("registerReceiveMessage");
                        return;
                    }
                    handleMessage(msg);
                },
                null, 'WatchLink', 'registerReceiveMessage');
            cordova.exec(
                function(data) {
                    if (!registeredDataMessages) {
                        registeredDataMessages = true;
                        _watchLink.log("registerReceiveDataMessage");
                        return;
                    }
                    if (dataMessageHandler) {
                        dataMessageHandler(data);
                    }
                    else {
                        _watchLink.errorLog('watchLink.registerReceiveDataMessages no handler');
                    }
                },
                null, 'WatchLink', 'registerReceiveDataMessage');
            cordova.exec(
                function(userinfo) {
                    if (!registeredUserInfo) {
                        registeredUserInfo = true;
                        _watchLink.log("registerReceiveUserInfo");
                        return;
                    }
                    if (userInfoHandler) {
                        userInfoHandler(userinfo);
                    }
                    else {
                        _watchLink.errorLog('watchLink.registerReceiveUserInfo no handler ', 
                                      JSON.stringify(userinfo));
                    }
                },
                null, 'WatchLink', 'registerReceiveUserInfo');
            cordova.exec(
                function(context) {
                    if (!registeredContext) {
                        registeredContext = true;
                        _watchLink.log("registerReceiveContext");
                        return;
                    }
                    if (contextHandler) {
                        contextHandler(context);
                    }
                    else {
                        _watchLink.errorLog('watchLink.registerReceiveContext no handler ', 
                                      JSON.stringify(context));
                    }
                },
                null, 'WatchLink', 'registerReceiveContext');
            cordova.exec(
                function(timestamp) {
                    if (!registeredNotificationHandler) {
                        registeredNotificationHandler = true;
                        _watchLink.log("registerNotificationHandler");
                        return;
                    }
                    if (notificationHandler) {
                        notificationHandler(timestamp);
                    }
                },
                null, 'WatchLink', 'registerNotificationHandler');
            cordova.exec(
                function(timestamp) {
                    if (!registeredNotificationDelegate) {
                        registeredNotificationDelegate = true;
                        _watchLink.log("registerNotificationDelegate");
                        return;
                    }
                    if (notificationDelegate) {
                        notificationDelegate(timestamp);
                    }
                },
                null, 'WatchLink', 'registerNotificationDelegate');
            cordova.exec(
                function(callbackId) {
                    if (callbackId && callbackId !== 'INVALID' && 
                        cordova.callbacks[callbackId] !== undefined) {
                        delete cordova.callbacks[callbackId];
                    }
                },
                null, 'WatchLink', 'registerCancelCallbackId');
        });
}
module.exports = new watchLink();


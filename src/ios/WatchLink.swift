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

//
// WatchLink.swift
//
import Foundation
import UIKit
import WatchConnectivity
import UserNotifications

// enables access from global scope to public WatchLink properties
var watchObj: WatchLink!

class WatchLink: CDVPlugin, WCSessionDelegate, UNUserNotificationCenterDelegate {

	@objc(pluginInitialize)
	override func pluginInitialize() {
		watchObj = self
        let center = UNUserNotificationCenter.current()
        center.delegate = self
		startSession()
		sessionID = Date().currentTimeMillis()
		watchMessageQueue = MessageQueue()
		watchDataMessageQueue = MessageQueue()
		watchUserInfoQueue = MessageQueue()
        userInfoTransfers = [:]
		appLogLevel = getLogLevel("watchLinkAppLogLevel", appLogLevel)
		watchLogLevel = getLogLevel("watchLinkWatchLogLevel", watchLogLevel)
		watchPrintLogLevel = getLogLevel("watchLinkWatchPrintLogLevel", watchPrintLogLevel)
		NSLog("watchLink initialized, appLogLevel = " + String(appLogLevel) +
                    " watchLogLevel = " + String(watchLogLevel) +
                    " watchPrintLogLevel = " + String(watchPrintLogLevel))
        watchSystemMessages = "WATCHAPPACTIVE|WATCHINAPPACTIVE|WATCHAPPBACKGROUND|WATCHLOG|WATCHAPPLOG|WATCHERRORLOG"
	}
	
	// session startup
	func startSession() {
		guard WCSession.isSupported() else {
			sendErrorLog("Watch Session is not supported")
			return
		}
		let session = WCSession.default
		session.delegate = self
		// async -- results in session:activationDidCompleteWith (below)
		session.activate()
	}
	
	// initialization sync
	
	private var initialized = false
	private var initializationCallbackId: String!
	
	@objc(initializationComplete:)
	private func initializationComplete(command: CDVInvokedUrlCommand) {
		initializationCallbackId = command.callbackId
		if (initialized) {
			let result = CDVPluginResult(status: CDVCommandStatus_OK)
			self.commandDelegate.send(result, callbackId: initializationCallbackId)
		}
	}
	
	// watch availability, reachability and watch application state
	
    let watchStateLock = NSLock()
	var watchActivated = false
	var isReachable = false
	var applicationState = ""
	var complicationEnabled = false
	var watchPaired = false
	var watchInstalled = false
    var watchURL: String = ""
	private var reachabilityCallbackId: String!
	private var availabilityCallbackId: String!
	private var applicationStateCallbackId: String!

	// watch availability
	private func notifyAvailability(callbackId: String = "", keepCallback: Bool = true) {
		if (callbackId == "" && availabilityCallbackId == nil) {
			return
		}
		var result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: true)
		if (!initialized) {
			result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "uninitialized")
		}
		else {
			let session = WCSession.default
			if (watchActivated) {
				isReachable = session.isReachable
				applicationState = "ACTIVE"
				complicationEnabled = session.isComplicationEnabled
				if (session.watchDirectoryURL == nil) {
					watchURL = ""
				}
				else {
					watchURL = session.watchDirectoryURL!.absoluteString
				}
				watchPaired = session.isPaired
				watchInstalled = session.isWatchAppInstalled
				if (!watchPaired || !watchInstalled) {
					applicationState = (watchPaired ? "NOTINSTALLED" : "NOTPAIRED")
					result = CDVPluginResult(status: CDVCommandStatus_OK, 
						messageAs: applicationState)
					sendLog("Availability: " + (watchPaired ? "NOTINSTALLED" : "NOTPAIRED"))
				}
				else {
					sendLog("Availability: true")
				}
			}
			else {
				isReachable = false
				applicationState = "INACTIVE"
				complicationEnabled = false
				watchPaired = false
				watchInstalled = false
				watchURL = ""
				result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: false)
				sendLog("Availability: false")
			}
			if (callbackId == "" && availabilityCallbackId == nil) {
				return
			}
		}
		let callback = (callbackId == "" ? availabilityCallbackId : callbackId)
		if (keepCallback) {
			result!.setKeepCallbackAs(true)
		}
		self.commandDelegate.send(result, callbackId: callback)
	}
	
	@objc(availability:)
	func availability(command: CDVInvokedUrlCommand) {
		notifyAvailability(callbackId: command.callbackId, keepCallback: false)
	}

	@objc(availabilityChanged:)
	func availabilityChanged(command: CDVInvokedUrlCommand) {
		if (availabilityCallbackId != command.callbackId) {
			if (availabilityCallbackId != nil) {
                cancelCallback(availabilityCallbackId)
			}
			availabilityCallbackId = command.callbackId
		}
		notifyAvailability()
	}

	// session reachability
	private func notifyReachability(callbackId: String = "", keepCallback: Bool = true) {
		if (callbackId == "" && reachabilityCallbackId == nil) {
			return
		}
		var result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "uninitialized")
		if (initialized) {
			let session = WCSession.default
			isReachable = session.isReachable
			if (callbackId == "" && reachabilityCallbackId == nil) {
				if (isReachable) {
					processQueue()
				}
				return
			}
			result = CDVPluginResult(status: CDVCommandStatus_OK,
				messageAs: session.isReachable)
			if (session.isReachable) {
				sendLog("Watch reachable")
			}
			else {
				sendLog("Watch NOT reachable")
			}
		}
		let callback = (callbackId == "" ? reachabilityCallbackId : callbackId)
		if (keepCallback) {
			result!.setKeepCallbackAs(true)
		}
		self.commandDelegate.send(result, callbackId: callback)
		if (isReachable) {
			processQueue()
		}
	}
	
	@objc(reachability:)
	func reachability(command: CDVInvokedUrlCommand) {
		notifyReachability(callbackId: command.callbackId, keepCallback: false)
	}

	@objc(reachabilityChanged:)
	func reachabilityChanged(command: CDVInvokedUrlCommand) {
		if (reachabilityCallbackId != command.callbackId) {
			if (reachabilityCallbackId != nil) {
				cancelCallback(reachabilityCallbackId)
			}
			reachabilityCallbackId = command.callbackId
		}
		notifyReachability()
	}
	
	// Watch application state
	private func notifyApplicationState(callbackId: String = "", keepCallback: Bool = true) {
		if (callbackId == "" && applicationStateCallbackId == nil) {
			return
		}
		var result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "uninitialized")
		if (initialized) {
			let session = WCSession.default
			var info: [String: Any] = [:]
			complicationEnabled = session.isComplicationEnabled
			if (session.watchDirectoryURL == nil) {
				watchURL = ""
			}
			else {
				watchURL = session.watchDirectoryURL!.absoluteString
			}
			watchPaired = session.isPaired
			watchInstalled = session.isWatchAppInstalled
            complicationEnabled = session.isComplicationEnabled
			info["complication"] = complicationEnabled
			info["isPaired"] = watchPaired
			info["isAppInstalled"] = watchInstalled
			info["directoryURL"] = watchURL
			info["state"] = false
			if (watchActivated && session.isPaired && session.isWatchAppInstalled) {
				sendLog("Watch Application State: " + applicationState)
				info["state"] = applicationState
			}
			else
			if (watchActivated) {
				sendLog("Watch Application State: " +
					(watchPaired ? "INACTIVE, NOT PAIRED" : "INACTIVE, NOT INSTALLED"))
				info["state"] = "INACTIVE"
			}
			else {
				sendLog("Watch Application State: INACTIVE")
			}
			result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: info)
		}
		let callback = (callbackId == "" ? applicationStateCallbackId : callbackId)
		if (keepCallback) {
			result!.setKeepCallbackAs(true)
		}
		self.commandDelegate.send(result, callbackId: callback)
	}
	
	@objc(watchApplicationState:)
	func watchApplicationState(command: CDVInvokedUrlCommand) {
		notifyApplicationState(callbackId: command.callbackId, keepCallback: false)
	}

	@objc(applicationStateChanged:)
	func applicationStateChanged(command: CDVInvokedUrlCommand) {
		if (applicationStateCallbackId != command.callbackId) {
			if (applicationStateCallbackId != nil) {
				cancelCallback(applicationStateCallbackId)
			}
			applicationStateCallbackId = command.callbackId
		}
		notifyApplicationState()
	}

	func session(_ session: WCSession, 
		activationDidCompleteWith activationState: WCSessionActivationState, 
		error: Error?) 
	{
		let session = WCSession.default
		if (activationState == WCSessionActivationState.activated) {
			watchActivated = true
			complicationEnabled = session.isComplicationEnabled
			watchPaired = session.isPaired
			watchInstalled = session.isWatchAppInstalled
            if (session.watchDirectoryURL == nil) {
                watchURL = ""
            }
            else {
                watchURL = session.watchDirectoryURL!.absoluteString
            }
			if (session.isReachable) {
				sendLog("watchLink session activation complete: Reachable")
			} else {
				sendLog("watchLink session activation complete: NOT Reachable")
			}
			initialized = true
			notifyAvailability()
			notifyApplicationState()
			notifyReachability()
			if (initializationCallbackId != nil) {
				let result = CDVPluginResult(status: CDVCommandStatus_OK)
				self.commandDelegate.send(result, callbackId: initializationCallbackId)
			}
		}
		else {
			watchActivated = false
			if (activationState == WCSessionActivationState.notActivated) {
				sendErrorLog("watchLink session not activated: " + error!.localizedDescription)
			}
			else {
				sendErrorLog("watchLink session inactive: " + error!.localizedDescription)
			}
		}
	}

	func sessionDidBecomeInactive(_ session: WCSession) {
        watchStateLock.lock()
		watchActivated = false
		sendLog("watchLink session deactivating")
		notifyAvailability()
		notifyApplicationState()
		notifyReachability()
        watchStateLock.unlock()
	}

	func sessionDidDeactivate(_ session: WCSession) {
        watchStateLock.lock()
		watchActivated = false
		sendLog("watchLink session deactivation complete")
		notifyAvailability()
		notifyApplicationState()
		notifyReachability()
        watchStateLock.unlock()
	}

	func sessionWatchStateDidChange(_ session: WCSession) {
        watchStateLock.lock()
		sendLog("watchLink session state change")
        notifyAvailability()
        notifyApplicationState()
        notifyReachability()
        watchStateLock.unlock()
	}

	func sessionReachabilityDidChange(_ session: WCSession) {
        watchStateLock.lock()
        let session = WCSession.default
		isReachable = session.isReachable
		notifyReachability()
        watchStateLock.unlock()
	}
	
	// utility routines
	
	// create a new unique timestamp	
	var lastTimestamp: Int64 = 0
	let timestampLock = NSLock()
	private func newTimestamp() -> Int64 {
		timestampLock.lock()
		var timestamp = Date().currentTimeMillis()
		if (timestamp <= lastTimestamp) {
			timestamp = lastTimestamp + 1
		}
		lastTimestamp = timestamp
		timestampLock.unlock()
		return timestamp
	}
	
	// indicate callback cancellation due to session reset to Javascript layer
	private func resetCallback(_ callbackID: String, _ timestamp: Int64) {
		if (callbackID != "") {
			let result = CDVPluginResult(status: CDVCommandStatus_ERROR, 
				messageAs: "sessionreset:" + String(timestamp))
			self.commandDelegate.send(result, callbackId: callbackID)
		}
	}
	
	// in case it's necessary to cancel a callbackID to avoid memory leak
	private var cancelCallbackId: String!
	
	@objc(registerCancelCallbackId:)
	func registerCancelCallbackId(command: CDVInvokedUrlCommand) {
		if (cancelCallbackId != command.callbackId) {
			cancelCallbackId = command.callbackId
		}
		let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "")
		result!.setKeepCallbackAs(true)
		self.commandDelegate.send(result, callbackId: cancelCallbackId)
	}
	
	private func cancelCallback(_ callbackId: String) {
		if (cancelCallbackId != nil && callbackId != "") {
			let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: callbackId)
			result!.setKeepCallbackAs(true)
			self.commandDelegate.send(result, callbackId: cancelCallbackId)
		}
	}

	// message and information transfer queueing

	// store WCSessionUserInfoTransfer against timestamp until subsequent 
	// tranfer or session reset
    private var userInfoTransfers: [Int64: WCSessionUserInfoTransfer]!

	private class MessageQueue {
	
		// this flag indicates whether message or user info transmission is 
		// in progress and awaiting acknowledgement
		var processing = false
        
        var lock = NSLock()

		var msgQueue: [(timestamp: Int64, session: Int64, ack: Bool, 
			callbackId: String, msgType: String, msg: Any)] = []
		
		func enqueue(msgType: String, msg: Any, timestamp: Int64,
				ack: Bool, callbackId: String) 
		{
            lock.lock()
			msgQueue.append((timestamp: timestamp, session: watchObj.sessionID,
				ack: ack, callbackId: callbackId, msgType: msgType, msg: msg))
            lock.unlock()
			return;
		}
		
		// get the queue item with timestamp matching. Items with lower timestamp 
		// are ignored (probably obsolete)
		func getQueueItem(_ timestamp: Int64) -> Int {
            lock.lock()
			var index = 0;
			while (index < msgQueue.count && msgQueue[index].timestamp <= timestamp) {
				if (msgQueue[index].timestamp == timestamp) {
                    lock.unlock()
					return index
				}
				index += 1
			}
            lock.unlock()
			return -1
		}
		
		// clear out the queue, issuing reset callbacks
		func resetQueue() {
            lock.lock()
			while (!msgQueue.isEmpty) {
				watchObj.resetCallback(msgQueue.first!.callbackId, msgQueue.first!.timestamp)
				msgQueue.remove(at: 0)
			}
            processing = false
            lock.unlock()
		}
		
		// clear out the queue, NOT issuing reset callbacks
		func flushQueue() {
            lock.lock()
			while (!msgQueue.isEmpty) {
                watchObj.cancelCallback(msgQueue.first!.callbackId)
				msgQueue.remove(at: 0)
			}
            processing = false
            lock.unlock()
		}
		
		// clear out the queue for msgType, NOT issuing reset callbacks
		func flushQueue(msgType: String) {
            lock.lock()
			var index = msgQueue.count - 1
			while (index >= 0) {
				if (msgQueue[index].msgType == msgType) {
					watchObj.cancelCallback(msgQueue[index].callbackId)
                    if (index == 0) {
                        processing = false
                    }
					msgQueue.remove(at: index)
				}
				index = index - 1
			}
            lock.unlock()
		}
		
		// clear the queue item with lower or matching timestamp, returning the 
		// callback ID and timestamp and setting processing to false
		func clearQueue(timestamp: Int64) -> (String, Int64) {
            lock.lock()
			var callbackId = ""
			var removed: Int64 = 0
            if (!msgQueue.isEmpty && msgQueue.first!.timestamp <= timestamp) {
                processing = false
            }
			while (!msgQueue.isEmpty && msgQueue.first!.timestamp <= timestamp) {
				if (msgQueue.first!.timestamp == timestamp) {
					callbackId = msgQueue.first!.callbackId
					removed = msgQueue.first!.timestamp
				}
				else { // the ack for message was somehow lost
					watchObj.resetCallback(msgQueue.first!.callbackId, msgQueue.first!.timestamp)
				}
				msgQueue.remove(at: 0)
			}
            lock.unlock()
			return (callbackId, removed)
		}
        
		// remove queue items with matching timestamp, ignoring others
		func clearMatchingTimestamp(timestamp: Int64) -> Bool {
            lock.lock()
			var didRemove = false;
			var index = msgQueue.count - 1
			while (index >= 0) {
				if (msgQueue[index].timestamp == timestamp) {
                    if (index == 0) {
                        processing = false
                    }
					didRemove = true
					watchObj.resetCallback(msgQueue[index].callbackId, msgQueue.first!.timestamp)
					msgQueue.remove(at: index)
					break
				}
                if (msgQueue[index].timestamp > timestamp) {
                    break
                }
                index = index - 1
			}
            lock.unlock()
			return didRemove
		}
	}
	
	// the callback IDs for passing messages, context, 
	// user info, notifications and logs up to the Javascript layer
	private var receivedMessageCallbackId: String!
	private var receivedDataMessageCallbackId: String!
	private var receivedContextCallbackId: String!
	private var receivedUserInfoCallbackId: String!
	private var notificationCallbackId: String!
	private var notificationDelegateCallbackId: String!
	private var logcallbackId: String!
	
	// the queues for messages and user info updates, awaiting transmission 
	// and/or acknowledgement
	private var watchMessageQueue: MessageQueue!
	private var watchDataMessageQueue: MessageQueue!
	private var watchUserInfoQueue: MessageQueue!
	private var pendingContextUpdate: (timestamp: Int64, session: Int64, 
		ack: Bool, sent: Bool, callbackId: String, context: [String: Any])!
	
	// the current session ID
	private var sessionID: Int64 = 0
	
	// reset session, clearing all outstanding messages, user info updates and context updates
    private func handleReset() {
        watchMessageQueue.resetQueue()
        watchDataMessageQueue.resetQueue()
        watchUserInfoQueue.resetQueue()
        if (pendingContextUpdate != nil) {
            resetCallback(pendingContextUpdate.callbackId, pendingContextUpdate.timestamp)
            pendingContextUpdate = nil
        }
    }
    
	@objc(resetSession:)
	func resetSession(command: CDVInvokedUrlCommand) {
		let reachable = WCSession.default.isReachable
		let reason = command.argument(at: 0) as! String
		let oldSessionID = sessionID
		sessionID = Date().currentTimeMillis()
        handleReset()
		if (reachable) {
			addMessage(msgType: "RESET", msg: reason + ":" + String(oldSessionID), 
						timestamp: newTimestamp(), ack: true, callbackId: command.callbackId, 
						watchMessageQueue);
		}
		else {
			let info = ["WATCHLINKSESSIONRESET": reason + ":" + String(oldSessionID)]
			addMessage(msgType: "USERINFO", msg: info, timestamp: newTimestamp(), 
				ack: true, callbackId: command.callbackId, watchUserInfoQueue)
		}
		addMessage(msgType: "SETLOGLEVEL", msg: watchLogLevel, timestamp: newTimestamp(), watchMessageQueue)
		addMessage(msgType: "SETPRINTLOGLEVEL", msg: watchPrintLogLevel, timestamp: newTimestamp(), watchMessageQueue)
		sendLog("resetSession requested \(oldSessionID) => \(sessionID)")
	}
	
	// queueing funcs for messages and user info updates
	private func handleMessageQueueResponse(_ response: [String: Any], _ queue: MessageQueue)
	{
		guard let timestamp = response["timestamp"] as? Int64
		else {
			sendErrorLog("handleMessageQueueResponse timestamp not found, response=" + 
				String(describing: response))
			return
		}
		if (timestamp == 0) {
			sendErrorLog("handleMessageQueueResponse timestamp is invalid, response=" + 
				String(describing: response) + " queue=" + String(describing: watchMessageQueue.msgQueue))
			return
		}
		let (callbackId, _) = queue.clearQueue(timestamp: timestamp)
		sendLog("Acknowledged \(timestamp) queue=" + String(describing: watchMessageQueue.msgQueue))
		if (callbackId != "") {
            let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: String(timestamp))
			self.commandDelegate.send(result, callbackId: callbackId)
		}
		processQueue()
	}
	
	private func handleMessageQueueError(_ response: Error, 
		_ timestamp: Int64, _ queue: MessageQueue) 
	{
		if (!queue.msgQueue.isEmpty) {
			let index = queue.getQueueItem(timestamp)
			if (index != -1) {
				if (WCError.Code.notReachable.rawValue as Int == (response as NSError).code ||
                        String(describing: response).matches("WCErrorDomain Code=7007")) {
					sendErrorLog("handleMessageQueueError " + 
						"\(queue.msgQueue[index].timestamp) watch not reachable after " +
						"transmission (will retry), msgType = " + queue.msgQueue[index].msgType + ":")
					queue.processing = false
				}
				else {
					sendErrorLog("handleMessageQueueError " +
						" \(queue.msgQueue[index].timestamp) " + response.localizedDescription +
						"payload = " + queue.msgQueue[index].msgType + ": " + 
                                    String(describing: queue.msgQueue[index].msg))
					let (callbackId, removed) = queue.clearQueue(timestamp: timestamp)
					if (callbackId != "" && removed == timestamp) {
						let result = CDVPluginResult(status: CDVCommandStatus_ERROR, 
							messageAs: response.localizedDescription + ":" + String(timestamp))
						self.commandDelegate.send(result, callbackId: callbackId)
					}
				}
			}
			else {
				queue.processing = false
			}
			processQueue()
		}
	}
	
	// dispatch context if required
	private func dispatchContext() {
		let session = WCSession.default
		var status = "OK"
		if (session.activationState == WCSessionActivationState.activated) {
			pendingContextUpdate.context["ACK"] = pendingContextUpdate.ack
			pendingContextUpdate.context["TIMESTAMP"] = pendingContextUpdate.timestamp
			pendingContextUpdate.context["SESSION"] = pendingContextUpdate.session
			do {
				try
					session.updateApplicationContext(pendingContextUpdate.context)
			}
			catch {
				status = "FAILED: " + error.localizedDescription
				sendErrorLog("dispatchContext " + status)
				pendingContextUpdate = nil
				return
			}
			sendLog("dispatchContext " + 
				String(describing: ["context": pendingContextUpdate.context, 
					"ack": pendingContextUpdate.ack, 
					"timestamp": pendingContextUpdate.timestamp]))
		} else {
			status = "unavailable"
			sendErrorLog("dispatchContext--watch not available")
		}
		if (status == "OK") {
			if (pendingContextUpdate.ack) {
				pendingContextUpdate.sent = true
			}
			else {
				pendingContextUpdate = nil
			}
		}
		else {
			let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: status)
			self.commandDelegate.send(result, callbackId: pendingContextUpdate.callbackId)
			pendingContextUpdate = nil
		}
	}
	
	// handle queued outgoing messages
    
	private func processQueue() {
		let session = WCSession.default
		if (session.isReachable) {
			while (session.isReachable && !watchMessageQueue.msgQueue.isEmpty &&
					!watchMessageQueue.processing) 
			{
                watchMessageQueue.lock.lock()
				let nextMsg = watchMessageQueue.msgQueue.first!
				if (nextMsg.session == sessionID) {
					let timestamp = nextMsg.timestamp
					sendLog("Sending message \(sessionID).\(nextMsg.timestamp) " +
						"ack:\(nextMsg.ack) " + nextMsg.msgType + ": " +
						String(describing: nextMsg.msg))
                    let replyHandler : (([String: Any]) -> Void)? =
                        (nextMsg.ack ?
                            { (response: [String: Any]) in
                                watchObj.handleMessageQueueResponse(response, self.watchMessageQueue) }
                            : nil)
					session.sendMessage(
                        ["timestamp": nextMsg.timestamp,
                            "session": nextMsg.session,
                            "msgType": nextMsg.msgType,
                            "msgBody" : nextMsg.msg],
						replyHandler: replyHandler,
						errorHandler: 
							{ (response: Error) in self.handleMessageQueueError(
                                response, timestamp, self.watchMessageQueue) })
					if (nextMsg.ack) {
						watchMessageQueue.processing = true
						break
					}
					watchMessageQueue.msgQueue.remove(at: 0)
				}
				else {
					cancelCallback(watchMessageQueue.msgQueue.first!.callbackId)
					watchMessageQueue.msgQueue.remove(at: 0)
				}
			}
			if (watchMessageQueue.processing) {
                sendLog("processQueue processing Messages: " + String(describing: watchMessageQueue.msgQueue))
			}
            watchMessageQueue.lock.unlock()
            watchDataMessageQueue.lock.lock()
			while (session.isReachable && !watchDataMessageQueue.msgQueue.isEmpty &&
					!watchDataMessageQueue.processing) 
			{
				let nextMsg = watchDataMessageQueue.msgQueue.first!
				if (nextMsg.session == sessionID) {
					let timestamp = nextMsg.timestamp
					sendLog("Sending message \(sessionID).\(nextMsg.timestamp) " +
						" ack:\(nextMsg.ack) " + nextMsg.msgType + ": DATA")
                    let replyHandler : (([String: Any]) -> Void)? =
                        (nextMsg.ack ?
                            { (response: [String: Any]) in
                                watchObj.handleMessageQueueResponse(response, self.watchDataMessageQueue) }
                        : nil)
					session.sendMessage(
                        ["timestamp": nextMsg.timestamp,
                            "session": nextMsg.session,
                            "msgType": "DATA",
                            "msgBody" : nextMsg.msg],
						replyHandler: replyHandler,
						errorHandler: 
							{ (response: Error) in 
								self.handleMessageQueueError(
                                    response, timestamp, self.watchDataMessageQueue) })
					if (nextMsg.ack) {
						watchDataMessageQueue.processing = true
						break
					}
					watchDataMessageQueue.msgQueue.remove(at: 0)
				}
				else {
					cancelCallback(watchDataMessageQueue.msgQueue.first!.callbackId)
					watchDataMessageQueue.msgQueue.remove(at: 0)
				}
			}
			if (watchDataMessageQueue.processing) {
				sendLog("processQueue--processing Data Messages")
			}
            watchDataMessageQueue.lock.unlock()
		}
        watchUserInfoQueue.lock.lock()
		while (!watchUserInfoQueue.msgQueue.isEmpty && !watchUserInfoQueue.processing) {
			let nextMsg = watchUserInfoQueue.msgQueue.first!
			var msg = nextMsg.msg as! [String: Any]
			if (nextMsg.session == sessionID) {
				msg["ACK"] = nextMsg.ack
				msg["TIMESTAMP"] = nextMsg.timestamp
				msg["SESSION"] = nextMsg.session
				for (timestamp, infoTransfer) in userInfoTransfers {
					if (!infoTransfer.isTransferring) {
                        userInfoTransfers.removeValue(forKey: timestamp)
					}
				}
				userInfoTransfers[nextMsg.timestamp] = session.transferUserInfo(msg)
				sendLog("Sending user info " + String(describing:
                    ["timestamp": nextMsg.timestamp, "ack": nextMsg.ack, 
						"userinfo": nextMsg.msg]))
				if (nextMsg.ack) {
					watchUserInfoQueue.processing = true
					break
				}
				watchUserInfoQueue.msgQueue.remove(at: 0)
			}
			else {
				cancelCallback(watchUserInfoQueue.msgQueue.first!.callbackId)
				watchUserInfoQueue.msgQueue.remove(at: 0)
			}
		}
		if (watchUserInfoQueue.processing) {
            sendLog("processQueue--processing UserInfo " + String(describing:watchUserInfoQueue.msgQueue))
		}
		if (pendingContextUpdate != nil && !pendingContextUpdate.sent) {
			dispatchContext();
		}
        watchUserInfoQueue.lock.unlock()
	}
	
	// add messages to the queues
	private func addMessage(msgType: String, msg: Any, timestamp: Int64, 
			ack: Bool = false, callbackId: String = "", 
			_ queue: MessageQueue)
	{
		queue.enqueue(msgType: msgType, msg: msg, timestamp: timestamp, 
			ack: ack, callbackId: callbackId)
		sendLog("Adding \(sessionID).\(timestamp) ack:\(ack) " + 
			msgType + ": " + String(describing: msg) +
			" callbackID=" + (callbackId == "" ? "none" : callbackId))
		processQueue()
	}
	
	// messaging
	@objc(registerReceiveMessage:)
	func registerReceiveMessage(command: CDVInvokedUrlCommand) {
		if (receivedMessageCallbackId != nil) {
			cancelCallback(receivedMessageCallbackId)
		}
		receivedMessageCallbackId = command.callbackId
		let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "registered")
		result!.setKeepCallbackAs(true)
		self.commandDelegate.send(result, callbackId: receivedMessageCallbackId)
	}
	
	@objc(registerReceiveDataMessage:)
	func registerReceiveDataMessage(command: CDVInvokedUrlCommand) {
		if (receivedDataMessageCallbackId != nil) {
			cancelCallback(receivedDataMessageCallbackId)
		}
		receivedDataMessageCallbackId = command.callbackId
		let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "registered")
		result!.setKeepCallbackAs(true)
		self.commandDelegate.send(result, callbackId: receivedDataMessageCallbackId)
	}
	
    func handleMessage(msgType: String, msgBody: Any, timestamp: Int64) {
		switch msgType {
			case "RESET":
				sendLog("RESET received from Watch")
			case "UPDATEDCONTEXT":
				if (pendingContextUpdate != nil) {
					let ackedTimestamp = Int64(msgBody as! String)
					if (ackedTimestamp == nil) {
						sendErrorLog("UPDATEDCONTEXT timestamp cannot be decoded msgBody=" +
							String(describing: msgBody));
					}
					else
					if (pendingContextUpdate.timestamp == ackedTimestamp) {
						let result = CDVPluginResult(status: CDVCommandStatus_OK, 
							messageAs: String(pendingContextUpdate.timestamp))
						sendLog("Acknowledged UPDATEDCONTEXT \(ackedTimestamp!) callbackId=" +
							pendingContextUpdate.callbackId)
						self.commandDelegate.send(result, 
							callbackId: pendingContextUpdate.callbackId)
						pendingContextUpdate = nil
					}
					else {
						sendErrorLog("UPDATEDCONTEXT acknowledgement timestamp " +
						"\(ackedTimestamp!) does not match pendingContextUpdate.timestamp" +
						" \(pendingContextUpdate.timestamp)")
					}
				}
			case "UPDATEDUSERINFO":
				let ackedTimestamp = Int64(msgBody as! String)
				if (ackedTimestamp == nil) {
					sendErrorLog("UPDATEDUSERINFO timestamp cannot be decoded msg=" + 
						String(describing: msgBody));
				}
				else {
					let (callbackId, timestamp) =
						watchUserInfoQueue.clearQueue(timestamp: ackedTimestamp!)
					sendLog("Acknowledged UPDATEDUSERINFO \(ackedTimestamp!) callbackId=" +
						(callbackId == "" ? "none" : callbackId))
					if (callbackId != "") {
						let result = CDVPluginResult(status: CDVCommandStatus_OK, 
							messageAs: String(timestamp))
						self.commandDelegate.send(result, callbackId: callbackId)
					}
				}
				processQueue()
			case "WATCHAPPACTIVE":
				// watch app active
                watchStateLock.lock()
				applicationState = "ACTIVE"
				notifyApplicationState()
                watchStateLock.unlock()
			case "WATCHAPPINACTIVE":
				// watch app inactive
                watchStateLock.lock()
				applicationState = "INACTIVE"
				notifyApplicationState()
                watchStateLock.unlock()
			case "WATCHAPPBACKGROUND":
				// watch app background
                watchStateLock.lock()
				applicationState = "BACKGROUND"
				notifyApplicationState()
                watchStateLock.unlock()
			case "WATCHLOG":
				// it's a log from the watch
				let msg = msgBody as! [String: String]
				sendWatchLog("WATCH " + Date().timeOfDay() + ">> " + msg["msg"]!)
			case "WATCHERRORLOG":
				// it's an errorlog from the watch
				let msg = msgBody as! [String: String]
				sendWatchErrorLog("WATCH " + Date().timeOfDay() + "Error>> " + msg["msg"]!)
			case "WATCHAPPLOG":
				// it's an app log from the watch
				let msg = msgBody as! [String: String]
				sendWatchAppLog("WATCH " + Date().timeOfDay() + "App>> " + msg["msg"]!)
			case "DATA":
				if (receivedDataMessageCallbackId != nil) {
                    let msgData = msgBody as! Data
                    let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAsArrayBuffer: msgData)
					result!.setKeepCallbackAs(true)
					self.commandDelegate.send(result, 
						callbackId: receivedDataMessageCallbackId)
				}
				else {
					sendErrorLog("didReceiveMessage data handler not bound")
				}
			default:
				if (receivedMessageCallbackId != nil) {
					let result = CDVPluginResult(status: CDVCommandStatus_OK, 
                                                 messageAs: ["msgType": msgType, "msg": msgBody as Any, "TIMESTAMP": timestamp])
					result!.setKeepCallbackAs(true)
					self.commandDelegate.send(result, callbackId: receivedMessageCallbackId)
				}
				else {
					sendLog("didReceiveMessage handler not bound: msg = " +
                                String(describing: ["msgType": msgType, "msg": msgBody as Any, "TIMESTAMP": timestamp]))
				}
		}
	}
	
	func handleDirectMessage(_ message: [String : Any],
		_ replyHandler: @escaping ([String : Any]) -> Void) 
	{
		replyHandler(message)
		if (receivedMessageCallbackId != nil) {
			let result = CDVPluginResult(status: CDVCommandStatus_OK, 
				messageAs: ["msgType": "WCSESSION", "msg": message])
			result!.setKeepCallbackAs(true)
			self.commandDelegate.send(result, callbackId: receivedMessageCallbackId)
		}
		else {
			sendErrorLog("didReceiveDirectMessage not bound")
		}
	}
	
    func handleDirectMessageNoAck(_ message: [String : Any]) {
		if (receivedMessageCallbackId != nil) {
			let result = CDVPluginResult(status: CDVCommandStatus_OK, 
				messageAs: ["msgType": "WCSESSION", "msg": message])
			result!.setKeepCallbackAs(true)
			self.commandDelegate.send(result, callbackId: receivedMessageCallbackId)
		}
		else {
			sendErrorLog("didReceiveDirectMessage not bound")
		}
	}
    
    private var watchSystemMessages: String!
    
	func session(_ session: WCSession, didReceiveMessage message: [String : Any], 
		replyHandler: @escaping ([String : Any]) -> Void) 
	{
		guard let msgType = message["msgType"] as? String
		else {
			sendLog("didReceiveMessage msgType not found message=" + 
				String(describing: message))
			handleDirectMessage(message, replyHandler)
			return
		}
		guard let msgBody = message["msgBody"]
		else {
			sendLog("didReceiveMessage msgBody not found message=" + 
				String(describing: message))
			handleDirectMessage(message, replyHandler)
			return
		}
		guard let timestamp = message["timestamp"] as? Int64
		else {
			sendLog("didReceiveMessage timestamp not found message=" + 
				String(describing: message))
			handleDirectMessage(message, replyHandler)
			return
		}
		guard let session = message["session"] as? Int64
		else {
			sendLog("didReceiveMessage session not found message=" + 
				String(describing: message))
			handleDirectMessage(message, replyHandler)
			return
		}
		replyHandler(["timestamp" : timestamp])
        if (!msgType.matches("^WATCH.*LOG$")) {
            sendLog("Received message " + String(describing: message))
        }
        if(!msgType.matches(watchSystemMessages)) {
            if (session > 0 && session < sessionID) {
                sendLog("didReceiveMessage SESSION obsolete message=" +
                    String(describing: message))
                return
            }
            if (session > sessionID) {
                sendLog("didReceiveMessage SESSION invalid session ID " + String(session) + ", message=" +
                    String(describing: message))
                return
            }
        }
        handleMessage(msgType: msgType, msgBody: msgBody, timestamp: timestamp)
	}
	
	func session(_ session: WCSession, didReceiveMessage message: [String : Any]) -> Void {
		guard let msgType = message["msgType"] as? String
		else {
			sendLog("didReceiveMessage msgType not found message=" + 
				String(describing: message))
			handleDirectMessageNoAck(message)
			return
		}
		guard let msgBody = message["msgBody"]
		else {
			sendLog("didReceiveMessage msgBody not found message=" + 
				String(describing: message))
			handleDirectMessageNoAck(message)
			return
		}
		guard let session = message["session"] as? Int64
		else {
			sendLog("didReceiveMessage SESSION not found message=" + 
				String(describing: message))
			handleDirectMessageNoAck(message)
			return
		}
        guard let timestamp = message["timestamp"] as? Int64
        else {
            sendLog("didReceiveMessage timestamp not found message=" +
                String(describing: message))
            handleDirectMessageNoAck(message)
            return
        }
        if (!msgType.matches("^WATCH.*LOG$")) {
            sendLog("Received message " + String(describing: message))
        }
        if(!msgType.matches(watchSystemMessages)) {
            if (session > 0 && session < sessionID) {
                sendLog("didReceiveMessage SESSION obsolete message=" +
                    String(describing: message))
                return
            }
            if (session > sessionID) {
                sendLog("didReceiveMessage SESSION invalid session ID " + String(session) + ", message=" +
                    String(describing: message))
                return
            }
        }
        handleMessage(msgType: msgType, msgBody: msgBody, timestamp: timestamp)
	}
	
	func session(_ session: WCSession, 
		didReceiveMessageData message: Data, replyHandler: @escaping (Data) -> Void) 
	{
		replyHandler(message)
        sendLog("Received message " + String(describing: message))
		if (receivedDataMessageCallbackId != nil) {
			let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAsArrayBuffer: message)
			result!.setKeepCallbackAs(true)
			self.commandDelegate.send(result, callbackId: receivedDataMessageCallbackId)
			sendLog("didReceiveDirectDataMessage")
		}
		else {
			sendErrorLog("didReceiveDirectDataMessage handler not bound")
		}
	}
	
	func session(_ session: WCSession, didReceiveMessageData message: Data) -> Void {
		if (receivedDataMessageCallbackId != nil) {
			let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAsArrayBuffer: message)
			result!.setKeepCallbackAs(true)
			self.commandDelegate.send(result, callbackId: receivedDataMessageCallbackId)
			sendLog("didReceiveDirectDataMessageNoAck")
		}
		else {
            sendErrorLog("didReceiveDirectDataMessage handler not bound")
		}
	}

	@objc(sendMessage:)
	func sendMessage(command: CDVInvokedUrlCommand) {
		let msgType = command.argument(at: 0) as! String
        let msgBody = command.argument(at: 1) as! [String: Any]
		let timestamp = msgBody["TIMESTAMP"] as! Int64
        addMessage(msgType: msgType, msg: msgBody, timestamp: timestamp,
			ack: true, callbackId: command.callbackId, watchMessageQueue)
	}

	@objc(sendMessageNoAck:)
	func sendMessageNoAck(command: CDVInvokedUrlCommand) {
		let msgType = command.argument(at: 0) as! String
		let msgBody = command.argument(at: 1) as! [String: Any]
		let timestamp = msgBody["TIMESTAMP"] as! Int64
		addMessage(msgType: msgType, msg: msgBody, timestamp: timestamp,
			ack: false, callbackId: command.callbackId, watchMessageQueue)
		let result = CDVPluginResult(status: CDVCommandStatus_OK)
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}

	@objc(flushMessages:)
	func flushMessages(command: CDVInvokedUrlCommand) {
		watchMessageQueue.flushQueue()
		let result = CDVPluginResult(status: CDVCommandStatus_OK)
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}

	@objc(sendDataMessage:)
	func sendDataMessage(command: CDVInvokedUrlCommand) {
        guard let msgData = command.argument(at: 0) as? Data
        else {
            sendErrorLog("payload data error")
            let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "payloaderror")
            self.commandDelegate.send(result, callbackId: command.callbackId)
            return
        }
		let timestamp = newTimestamp()
		addMessage(msgType: "DATA", msg: msgData, timestamp: timestamp, 
			ack: true, callbackId: command.callbackId, watchDataMessageQueue)
	}

	@objc(sendDataMessageNoAck:)
	func sendDataMessageNoAck(command: CDVInvokedUrlCommand) {
        guard let msgData = command.argument(at: 0) as? Data
        else {
            sendErrorLog("payload data error")
            let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "payloaderror")
            self.commandDelegate.send(result, callbackId: command.callbackId)
            return
        }
		let timestamp = newTimestamp()
		addMessage(msgType: "DATA", msg: msgData, timestamp: timestamp,
			ack: false, callbackId: command.callbackId, watchDataMessageQueue)
		let result = CDVPluginResult(status: CDVCommandStatus_OK)
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}

	@objc(flushDataMessages:)
	func flushDataMessages(command: CDVInvokedUrlCommand) {
		watchDataMessageQueue.flushQueue()
		let result = CDVPluginResult(status: CDVCommandStatus_OK)
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}

	// user info send/receieve
	@objc(registerReceiveUserInfo:)
	func registerReceiveUserInfo(command: CDVInvokedUrlCommand) {
		if (receivedUserInfoCallbackId != nil) {
			cancelCallback(receivedUserInfoCallbackId)
		}
		receivedUserInfoCallbackId = command.callbackId
		let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "registered")
		result!.setKeepCallbackAs(true)
		self.commandDelegate.send(result, callbackId: receivedUserInfoCallbackId)
	}
	
	private func handleDirectUserInfo(_ userInfo: [String: Any]) {
		if (receivedUserInfoCallbackId != nil) {
			let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: userInfo)
			result!.setKeepCallbackAs(true)
			self.commandDelegate.send(result, callbackId: receivedUserInfoCallbackId)
		}
		else {
			sendErrorLog("handleDirectUserInfo not bound: userInfo = " +
				String(describing: userInfo))
		}
	}
	
	func session(_ session : WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        sendLog("Received user info " + String(describing: userInfo))
		guard let timestamp = userInfo["TIMESTAMP"] as? Int64
		else {
			sendLog("didReceiveUserInfo TIMESTAMP not found userInfo=" + 
				String(describing: userInfo))
			handleDirectUserInfo(userInfo)
			return
		}
		guard let ack = userInfo["ACK"] as? Bool
		else {
			sendLog("didReceiveUserInfo ACK not found userInfo=" + 
				String(describing: userInfo))
			handleDirectUserInfo(userInfo)
			return
		}
		guard let session = userInfo["SESSION"] as? Int64
		else {
			sendLog("didReceiveUserInfo SESSION not found userInfo=" + 
				String(describing: userInfo))
			handleDirectUserInfo(userInfo)
			return
		}
		if (session != 0 && session != sessionID) {
            sendLog("didReceiveUserInfo SESSION invalid session ID " + String(session) + ", userInfo=" +
                String(describing: userInfo))
			return
		}
		if (ack) {
            addMessage(msgType: "UPDATEDUSERINFO", msg: "\(timestamp)", timestamp: newTimestamp(), watchMessageQueue)
		}
		if (receivedUserInfoCallbackId != nil) {
			let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: userInfo)
			result!.setKeepCallbackAs(true)
			self.commandDelegate.send(result, callbackId: receivedUserInfoCallbackId)
			sendLog("didReceiveUserInfo callback executed");
		}
		else {
			sendErrorLog("didReceiveUserInfo not bound: userInfo = " + 
				String(describing: userInfo))
		}
	}

	@objc(sendUserInfo:)
	func sendUserInfo(command: CDVInvokedUrlCommand) {
		let info = command.argument(at: 0) as! [String: Any]
        let timestamp = info["TIMESTAMP"] as! Int64
		addMessage(msgType: "USERINFO", msg: info, timestamp: timestamp, 
			ack: true, callbackId: command.callbackId, watchUserInfoQueue)
	}

	@objc(sendUserInfoNoAck:)
	func sendUserInfoNoAck(command: CDVInvokedUrlCommand) {
		let info = command.argument(at: 0) as! [String: Any]
        let timestamp = info["TIMESTAMP"] as! Int64
		addMessage(msgType: "USERINFO", msg: info, timestamp: timestamp, 
			ack: false, callbackId: command.callbackId, watchUserInfoQueue)
		let result = CDVPluginResult(status: CDVCommandStatus_OK)
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}
	
	@objc(queryUserInfo:)
	func queryUserInfo(command: CDVInvokedUrlCommand) {
		let timestamp = command.argument(at: 0) as! Int64
		var result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: false)
		guard let transfer = userInfoTransfers[timestamp] 
		else {
			self.commandDelegate.send(result, callbackId: command.callbackId)
			return
		}
        let info: [String : Any] = [ "timestamp" : timestamp, 
			"isComplication": transfer.isCurrentComplicationInfo,
			"transmitComplete" : !transfer.isTransferring, 
			"userInfo": transfer.userInfo ]
		result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: info)
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}
	
	@objc(cancelUserInfo:)
	func cancelUserInfo(command: CDVInvokedUrlCommand) {
		let timestamp = command.argument(at: 0) as! Int64
		var result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: false)
		guard let transfer = userInfoTransfers[timestamp] 
		else {
			self.commandDelegate.send(result, callbackId: command.callbackId)
			return
		}
		if (transfer.isTransferring) {
			transfer.cancel()
			_ = watchUserInfoQueue.clearMatchingTimestamp(timestamp: timestamp)
			result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: true)
		}
        userInfoTransfers.removeValue(forKey: timestamp)
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}
	
	@objc(outstandingUserInfoTransfers:)
	func outstandingUserInfoTransfers(command: CDVInvokedUrlCommand) {
        var transfers: [ [String: Any] ] = []
		for (timestamp, infoTransfer) in userInfoTransfers {
			if (!infoTransfer.isCurrentComplicationInfo) {
				transfers.append(
					[
						"timestamp" : timestamp,
						"isComplication": infoTransfer.isCurrentComplicationInfo,
						"transmitComplete" : !infoTransfer.isTransferring,
						"userInfo": infoTransfer.userInfo
					])
			}
		}
		let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: transfers)
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}
	
	@objc(flushUserInfo:)
	func flushUserInfo(command: CDVInvokedUrlCommand) {
		for (_, infoTransfer) in userInfoTransfers {
			if (infoTransfer.isTransferring) {
                infoTransfer.cancel()
			}
		}
		watchUserInfoQueue.flushQueue()
		let result = CDVPluginResult(status: CDVCommandStatus_OK)
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}

	// application context send/receieve
	@objc(registerReceiveContext:)
	func registerReceiveContext(command: CDVInvokedUrlCommand) {
		if (receivedContextCallbackId != nil) {
			cancelCallback(receivedContextCallbackId)
		}
		receivedContextCallbackId = command.callbackId
		let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "registered")
		result!.setKeepCallbackAs(true)
		self.commandDelegate.send(result, callbackId: receivedContextCallbackId)
	}
	
	private func handleDirectContext(_ context: [String: Any]) {
		if (receivedContextCallbackId != nil) {
			let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: context)
			result!.setKeepCallbackAs(true)
			self.commandDelegate.send(result, callbackId: receivedContextCallbackId)
		}
		else {
			sendErrorLog("handleDirectContext not bound: userInfo = " +
				String(describing: context))
		}
	}
	
	func session(_ session : WCSession, 
		didReceiveApplicationContext applicationContext: [String: Any]) 
	{
        sendLog("Received context " + String(describing: applicationContext))
		guard let timestamp = applicationContext["TIMESTAMP"] as? Int64
		else {
			sendLog("didReceiveApplicationContext TIMESTAMP not found " +
				"applicationContext=" + String(describing: applicationContext))
			handleDirectContext(applicationContext)
			return
		}
		guard let ack = applicationContext["ACK"] as? Bool
		else {
			sendLog("didReceiveApplicationContext ACK not found applicationContext=" + 
				String(describing: applicationContext))
			handleDirectContext(applicationContext)
			return
		}
		guard let session = applicationContext["SESSION"] as? Int64
		else {
			sendLog("didReceiveApplicationContext SESSION not found applicationContext=" +
			String(describing: applicationContext))
			handleDirectContext(applicationContext)
			return
		}
		if (session != 0 && session != sessionID) {
			sendLog("didReceiveApplicationContext SESSION invalid session ID " + String(session) + ", applicationContext=" +
				String(describing: applicationContext))
			return
		}
		if (ack) {
            addMessage(msgType: "UPDATEDCONTEXT", msg: "\(timestamp)", timestamp: newTimestamp(), watchMessageQueue)
		}
		if (receivedContextCallbackId != nil) {
			let result = CDVPluginResult(status: CDVCommandStatus_OK, 
				messageAs: applicationContext)
			result!.setKeepCallbackAs(true)
			self.commandDelegate.send(result, callbackId: receivedContextCallbackId)
		}
		else {
			sendErrorLog("didReceiveApplicationContext not bound: applicationContext = " + 
				String(describing: applicationContext))
		}
	}

	@objc(sendContext:)
	func sendContext(command: CDVInvokedUrlCommand) {
		if (pendingContextUpdate != nil) {
			let result = CDVPluginResult(status: CDVCommandStatus_ERROR, 
				messageAs: "reset:" + String(pendingContextUpdate.timestamp))
			self.commandDelegate.send(result, callbackId: pendingContextUpdate.callbackId)
		}
		let context = command.argument(at: 0) as! [String: Any]
		let timestamp = context["TIMESTAMP"] as! Int64
		pendingContextUpdate = (timestamp: timestamp, session: sessionID, 
			ack: true, sent: false, callbackId: command.callbackId, context: context)
		dispatchContext()
	}

	@objc(sendContextNoAck:)
	func sendContextNoAck(command: CDVInvokedUrlCommand) {
		if (pendingContextUpdate != nil) {
			let result = CDVPluginResult(status: CDVCommandStatus_ERROR, 
				messageAs: "reset:" + String(pendingContextUpdate.timestamp))
			self.commandDelegate.send(result, callbackId: pendingContextUpdate.callbackId)
		}
		let context = command.argument(at: 0) as! [String: Any]
		let timestamp = context["TIMESTAMP"] as! Int64
		pendingContextUpdate = (timestamp: timestamp, session: sessionID, 
			ack: false, sent: false, callbackId: command.callbackId, context: context)
		dispatchContext()
		let result = CDVPluginResult(status: CDVCommandStatus_OK)
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}
	
	@objc(latestContextSent:)
	func latestContextSent(command: CDVInvokedUrlCommand) {
		let session = WCSession.default
		let result = CDVPluginResult(status: CDVCommandStatus_OK, 
			messageAs: session.applicationContext)
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}
	
	@objc(latestContextReceived:)
	func latestContextReceived(command: CDVInvokedUrlCommand) {
		let session = WCSession.default
		let result = CDVPluginResult(status: CDVCommandStatus_OK, 
			messageAs: session.receivedApplicationContext)
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}
	
	@objc(flushContextTransfers:)
	func flushContextTransfers(command: CDVInvokedUrlCommand) {
		if (pendingContextUpdate != nil) {
			cancelCallback(pendingContextUpdate.callbackId)
		}
		pendingContextUpdate = nil
		let result = CDVPluginResult(status: CDVCommandStatus_OK)
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}
	
	// complications
	
	@objc(sendComplicationInfo:)
	func sendComplicationInfo(command: CDVInvokedUrlCommand) {
        let session = WCSession.default
		let info = command.argument(at: 0) as! [String: Any]
		let timestamp = info["TIMESTAMP"] as! Int64
        userInfoTransfers[timestamp] = session.transferCurrentComplicationUserInfo(info)
	}
	
	@objc(queryComplication:)
	func queryComplication(command: CDVInvokedUrlCommand) {
		let timestamp = command.argument(at: 0) as! Int64
		var result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: false)
		guard let transfer = userInfoTransfers[timestamp] 
		else {
			self.commandDelegate.send(result, callbackId: command.callbackId)
			return
		}
        let info: [String : Any] = [ "timestamp" : timestamp, 
			"isComplication": transfer.isCurrentComplicationInfo,
			"transmitComplete" : !transfer.isTransferring, 
			"userInfo": transfer.userInfo ]
		result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: info)
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}
	
	@objc(cancelComplication:)
	func cancelComplication(command: CDVInvokedUrlCommand) {
		let timestamp = command.argument(at: 0) as! Int64
		var result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: false)
		guard let transfer = userInfoTransfers[timestamp] 
		else {
			self.commandDelegate.send(result, callbackId: command.callbackId)
			return
		}
		if (transfer.isTransferring) {
			transfer.cancel()
			_ = watchUserInfoQueue.clearMatchingTimestamp(timestamp: timestamp)
			result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: true)
		}
        userInfoTransfers.removeValue(forKey: timestamp)
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}
	
	@objc(outstandingComplicationTransfers:)
	func outstandingComplicationTransfers(command: CDVInvokedUrlCommand) {
        var transfers: [ [String: Any] ] = []
		for (timestamp, infoTransfer) in userInfoTransfers {
			if (infoTransfer.isCurrentComplicationInfo) {
				transfers.append(
					[
						"timestamp" : timestamp,
						"isComplication": infoTransfer.isCurrentComplicationInfo,
						"transmitComplete" : !infoTransfer.isTransferring,
						"userInfo": infoTransfer.userInfo
					])
			}
		}
		let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: transfers)
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}

	
	
	// notifications
	
	var notificationsAuthorized = false
	var notificationSound = true
	var showDelegatedNotifications = false
    var pendingNotifications: [ [String: Any] ]!
	
	@objc(requestNotificationPermission:)
	func requestNotificationPermission(command: CDVInvokedUrlCommand) {
		let allowSound = command.argument(at: 0) as! Bool
		let center = UNUserNotificationCenter.current()
		var options: UNAuthorizationOptions = []
		options.insert(UNAuthorizationOptions.badge)
		if (allowSound) {
			options.insert(UNAuthorizationOptions.sound)
		}
		var result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: true)
		center.requestAuthorization(options: options) { (granted, error) in
            self.notificationsAuthorized = granted
			if (granted) {
                self.notificationSound = allowSound
				self.commandDelegate.send(result, callbackId: command.callbackId)
			} else {
				result = CDVPluginResult(status: CDVCommandStatus_ERROR, 
							messageAs: "failed:" + error!.localizedDescription)
				self.commandDelegate.send(result, callbackId: command.callbackId)
			}
		}
        if (pendingNotifications != nil && pendingNotifications.count > 0) {
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
        }
        pendingNotifications = []
	}
	
	@objc(scheduleNotification:)
	func scheduleNotification(command: CDVInvokedUrlCommand) {
		var result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "notauthorized")
		if (!notificationsAuthorized) {
			sendErrorLog("scheduleNotification: notifications not authorized")
			self.commandDelegate.send(result, callbackId: command.callbackId)
			return
		}
		let trigger = command.argument(at: 0) as! [String: Int]
		let payload = command.argument(at: 1) as! [String: Any]
		let userInfo = payload["userInfo"] as! [String: Any]
		let timestamp = userInfo["TIMESTAMP"] as! Int
        if (pendingNotifications.count > 0 &&
                pendingNotifications.firstIndex(where: { $0["TIMESTAMP"] as! Int == timestamp }) != nil)
        {
			result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "duplicate")
			sendErrorLog("scheduleNotification: duplicate notification " + String(timestamp))
			self.commandDelegate.send(result, callbackId: command.callbackId)
			return
		}
		let center = UNUserNotificationCenter.current()
		let content = UNMutableNotificationContent()
		var notificationTrigger: UNNotificationTrigger!
		if (trigger["delay"] != nil) {
			notificationTrigger = 
				UNTimeIntervalNotificationTrigger(timeInterval: Double(trigger["delay"]!),
													repeats: false)
		}
		else {
			var date = DateComponents()
			date.year = trigger["year"]
			date.month = trigger["day"]
			date.hour = trigger["hour"]
			date.minute = trigger["minute"]
			date.second = trigger["second"]
			notificationTrigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: false)
		}
		content.title = payload["title"] as! String
        if (payload["subtitle"] != nil) {
            content.subtitle = payload["subtitle"] as! String
        }
		else {
			content.subtitle = "Banner subtitle"
		}
        if (payload["body"] != nil) {
            content.body = payload["body"] as! String
        }
        else {
            content.body = "The body of the banner"
        }
        content.userInfo = payload["userInfo"] as! [String: Any]
		if (notificationSound) {
			content.sound = UNNotificationSound.default
		}
		let request = UNNotificationRequest(
						identifier: String(timestamp),
						content: content, 
						trigger: notificationTrigger)
		center.add(request,
                   withCompletionHandler:
                        {
                            (err: Error?)->Void in
                            if (err != nil) {
                                self.sendErrorLog("Notification failed: " + err!.localizedDescription)
								result = CDVPluginResult(status: CDVCommandStatus_ERROR, 
											messageAs: err!.localizedDescription)
								self.commandDelegate.send(result, callbackId: command.callbackId)
                            }
                            else {
                                self.pendingNotifications.append(userInfo)
                                self.sendLog("Notification " + String(timestamp) + " added")
								result = CDVPluginResult(status: CDVCommandStatus_OK, 
											messageAs: timestamp)
								self.commandDelegate.send(result, callbackId: command.callbackId)
                            }
                        }
        )
	}
	
	@objc(retrieveNotifications:)
	func retrieveNotifications(command: CDVInvokedUrlCommand) {
		let result = CDVPluginResult(status: CDVCommandStatus_OK,
									messageAs:pendingNotifications)
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}
	
	@objc(cancelNotification:)
	func cancelNotification(command: CDVInvokedUrlCommand) {
		let timestamp = command.argument(at: 0) as! Int
		let center = UNUserNotificationCenter.current()
        let index = pendingNotifications.firstIndex(where: { $0["TIMESTAMP"] as! Int == timestamp })
		let result = CDVPluginResult(status: CDVCommandStatus_OK)
		center.removePendingNotificationRequests(withIdentifiers: [String(timestamp)])
		if (index != nil) {
			pendingNotifications.remove(at: index!)
		}
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}
	
	@objc(cancelAllNotifications:)
	func cancelAllNotifications(command: CDVInvokedUrlCommand) {
		let center = UNUserNotificationCenter.current()
		pendingNotifications = []
		center.removeAllPendingNotificationRequests()
		let result = CDVPluginResult(status: CDVCommandStatus_OK)
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}
	
	@objc(showDelegatedNotification:)
	func showDelegatedNotification(command: CDVInvokedUrlCommand) {
		showDelegatedNotifications = command.argument(at: 0) as! Bool
		let result = CDVPluginResult(status: CDVCommandStatus_OK)
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                             willPresent notification: UNNotification,
                   withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        let userInfo = notification.request.content.userInfo
        let timestamp = userInfo["TIMESTAMP"] as! Int
        let index = pendingNotifications.firstIndex(where: { $0["TIMESTAMP"] as! Int == timestamp })
        if (index != nil) {
            pendingNotifications.remove(at: index!)
        }
        sendLog("userNotificationCenter willPresent: " + String(describing: notification))
		if (showDelegatedNotifications) {
            var options: UNNotificationPresentationOptions = [UNNotificationPresentationOptions.alert]
			if (notificationSound) {
				options.insert(UNNotificationPresentationOptions.sound)
			}
			completionHandler(options)
		}
		else {
			completionHandler([])
		}
		if (notificationDelegateCallbackId != nil) {
            let result = CDVPluginResult(status: CDVCommandStatus_OK,
                                            messageAs: userInfo)
			result!.setKeepCallbackAs(true)
			self.commandDelegate.send(result, callbackId: notificationDelegateCallbackId)
		}
    }
	
	func userNotificationCenter(_ center: UNUserNotificationCenter, 
                          didReceive response: UNNotificationResponse, 
               withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let timestamp = userInfo["TIMESTAMP"] as! Int
        let index = pendingNotifications.firstIndex(where: { $0["TIMESTAMP"] as! Int == timestamp })
        if (index != nil) {
            pendingNotifications.remove(at: index!)
        }
		sendLog("userNotificationCenter didReceive: " + String(describing: response))
		completionHandler()
		if (notificationCallbackId != nil) {
            let result = CDVPluginResult(status: CDVCommandStatus_OK,
                                            messageAs: userInfo)
			result!.setKeepCallbackAs(true)
			self.commandDelegate.send(result, callbackId: notificationCallbackId)
		}
	}
	
	@objc(registerNotificationHandler:)
	func registerNotificationHandler(command: CDVInvokedUrlCommand) {
		if (notificationCallbackId != nil) {
			cancelCallback(notificationCallbackId)
		}
		notificationCallbackId = command.callbackId
		let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "")
		result!.setKeepCallbackAs(true)
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}
	
	@objc(registerNotificationDelegate:)
	func registerNotificationDelegate(command: CDVInvokedUrlCommand) {
		if (notificationDelegateCallbackId != nil) {
			cancelCallback(notificationDelegateCallbackId)
		}
		notificationDelegateCallbackId = command.callbackId
		let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "")
		result!.setKeepCallbackAs(true)
		self.commandDelegate.send(result, callbackId: command.callbackId)
	}
	
	/*
	logging and log management. 
	
	swiftLog, swiftAppLog and swiftErrorLog direct messages to
	the javascript console.
	
	log levels: 0/none = none, 1/error = errors, 2/app = app messages, 3/all = all messages
	*/
	private var appLogLevel: Int = 3
	private var watchLogLevel: Int = 3
	private var watchPrintLogLevel: Int = 3
	
	// get the log levels from config.xml
	private func getLogLevel(_ settingName: String, _ setting: Int) -> Int {
		var theLevel = setting
		guard let settings = self.commandDelegate.settings as? [String: String]
		else {
			return theLevel;
		}
		guard let logLevel = settings[settingName.lowercased()]
		else {
			return theLevel;
		}
		if (logLevel.matches("^[0-3]$")) {
			theLevel = Int(logLevel)!
		}
		else
		if (logLevel.matches("^(all|none|error|app)$")) {
			if (logLevel == "all") {
				theLevel = 2
			}
			else
			if (logLevel == "none") {
				theLevel = 0
			}
			else
			if (logLevel == "app") {
				theLevel = 2
			}
			else {
				theLevel = 1
			}
		}
		else {
			sendErrorLog("Illegal value for " + settingName + " (" + logLevel + ")")
		}
		return theLevel
	}
	
	// send watch logs to the javascript layer
	func sendWatchLog(_ msg: String) {
		if (logcallbackId == nil) {
			swiftLogbacklog = swiftLogbacklog + "\n" + msg;
			print("swiftLogbacklog " + msg)
		}
		else {
			let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: msg)
			result!.setKeepCallbackAs(true)
			self.commandDelegate.send(result, callbackId: logcallbackId)
            print(msg)
		}
	}
    
    func sendWatchAppLog(_ msg: String) {
        if (logcallbackId == nil) {
            swiftLogbacklog = swiftLogbacklog + "\n" + msg;
            print("swiftLogbacklog " + msg)
        }
        else {
            let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: msg)
            result!.setKeepCallbackAs(true)
            self.commandDelegate.send(result, callbackId: logcallbackId)
            print(msg)
        }
    }
    
    func sendWatchErrorLog(_ msg: String) {
        if (logcallbackId == nil) {
            swiftLogbacklog = swiftLogbacklog + "\n" + "WARN: " + msg;
            print("swiftLogbacklog " + msg)
        }
        else {
            let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: msg)
            result!.setKeepCallbackAs(true)
            self.commandDelegate.send(result, callbackId: logcallbackId)
            print("WARN: " + msg)
        }
    }
	
	// send a log to the javascript layer
	func sendLog(_ msg: String) {
		if (appLogLevel < 3) {
			return
		}
        let message = Date().timeOfDay() + ">> " + msg
		if (logcallbackId == nil) {
			swiftLogbacklog = swiftLogbacklog + " \n    " + message;
			print("swiftLogbacklog " + message)
		}
		else {
			let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: message)
			result!.setKeepCallbackAs(true)
			self.commandDelegate.send(result, callbackId: logcallbackId)
            print(message)
		}
	}
	
	// send an app log to the javascript layer
	func sendAppLog(_ msg: String) {
		if (appLogLevel < 2) {
			return
		}
        let message = Date().timeOfDay() + "App>> " + msg
		if (logcallbackId == nil) {
			swiftLogbacklog = swiftLogbacklog + " \n    " + message;
			print("swiftLogbacklog " + message)
		}
		else {
			let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: message)
			result!.setKeepCallbackAs(true)
			self.commandDelegate.send(result, callbackId: logcallbackId)
            print(msg)
		}
	}
	
	// send an errorlog to the javascript layer
	func sendErrorLog(_ msg: String) {
		if (appLogLevel == 0) {
			return
		}
        let message = Date().timeOfDay() + "Error>> " + msg
		if (logcallbackId == nil) {
			swiftLogbacklog = swiftLogbacklog + " \n    " + message;
			print("swiftLogbacklog " + message)
		}
		else {
			let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: message)
			result!.setKeepCallbackAs(true)
			self.commandDelegate.send(result, callbackId: logcallbackId)
            print("WARN: " + message)
		}
	}
	
	@objc(startLog:)
	func startLog(command: CDVInvokedUrlCommand) {
		if (logcallbackId != nil) {
			cancelCallback(logcallbackId)
		}
        logcallbackId = command.callbackId
        swiftLogbacklog = Date().timeOfDay() + ">> startLog " + swiftLogbacklog
        print(swiftLogbacklog)
		let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: swiftLogbacklog)
		result!.setKeepCallbackAs(true)
		self.commandDelegate.send(result, callbackId: command.callbackId)
		swiftLogbacklog = "BACKLOG"
	}
	
	@objc(setAppLogLevel:)
	func setAppLogLevel(command: CDVInvokedUrlCommand) {
		let level = command.argument(at: 0) as? Int
		if (level == nil) {
			let result = CDVPluginResult(status: CDVCommandStatus_ERROR)
			self.commandDelegate.send(result, callbackId: command.callbackId)
		}
		else {
			let result = CDVPluginResult(status: CDVCommandStatus_OK)
			self.commandDelegate.send(result, callbackId: command.callbackId)
			appLogLevel = level!
		}
	}
	
	@objc(setWatchLogLevel:)
	func setWatchLogLevel(command: CDVInvokedUrlCommand) {
		let level = command.argument(at: 0) as? Int
		if (level == nil) {
			let result = CDVPluginResult(status: CDVCommandStatus_ERROR)
			self.commandDelegate.send(result, callbackId: command.callbackId)
		}
		else {
			let result = CDVPluginResult(status: CDVCommandStatus_OK)
			self.commandDelegate.send(result, callbackId: command.callbackId)
			watchLogLevel = level!
            addMessage(msgType: "SETLOGLEVEL", msg: watchLogLevel, timestamp: newTimestamp(), watchMessageQueue)
		}
	}
	
	@objc(setWatchPrintLogLevel:)
	func setWatchPrintLogLevel(command: CDVInvokedUrlCommand) {
		let level = command.argument(at: 0) as? Int
		if (level == nil) {
			let result = CDVPluginResult(status: CDVCommandStatus_ERROR)
			self.commandDelegate.send(result, callbackId: command.callbackId)
		}
		else {
			let result = CDVPluginResult(status: CDVCommandStatus_OK)
			self.commandDelegate.send(result, callbackId: command.callbackId)
			watchPrintLogLevel = level!
			addMessage(msgType: "SETPRINTLOGLEVEL", msg: watchPrintLogLevel, timestamp: newTimestamp(), watchMessageQueue)
		}
	}

    var lastWCSessionCommandCallback: String!
    
    @objc(wcSessionCommand:)
    func wcSessionCommand(command: CDVInvokedUrlCommand) {
        let session = WCSession.default
        guard let op = command.argument(at: 0) as? String
        else {
            sendErrorLog("wcSessionCommand: op data error")
            return
        }
        // avoid memory leak from callback hanging around
        if (lastWCSessionCommandCallback != nil) {
            cancelCallback(lastWCSessionCommandCallback)
            lastWCSessionCommandCallback = nil
        }
        switch(op) {
        case "sendMessage":
            guard let payload = command.argument(at: 1) as? [String: Any]
            else {
                sendErrorLog("wcSessionCommand: payload data error")
                return
            }
            lastWCSessionCommandCallback = command.callbackId
            session.sendMessage(payload, replyHandler: nil,
                        errorHandler:
                            { (response: Error) in
                                self.sendErrorLog("wcSessionCommand error " + String(describing: response))
                                if (self.lastWCSessionCommandCallback != nil) {
                                    let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "wcSessionCommand error " + String(describing: response))
                                    self.commandDelegate.send(result, callbackId: self.lastWCSessionCommandCallback)
                                    self.lastWCSessionCommandCallback = nil
                                }
                            })
        case "sendDataMessage":
            guard let payload = command.argument(at: 1) as? Data
            else {
                sendErrorLog("wcSessionCommand: payload data error")
                return
            }
            lastWCSessionCommandCallback = command.callbackId
            session.sendMessageData(payload, replyHandler: nil,
                        errorHandler:
                            { (response: Error) in
                                self.sendErrorLog("wcSessionCommand error " + String(describing: response))
                                if (self.lastWCSessionCommandCallback != nil) {
                                    let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "wcSessionCommand error " + String(describing: response))
                                    self.commandDelegate.send(result, callbackId: self.lastWCSessionCommandCallback)
                                    self.lastWCSessionCommandCallback = nil
                                }
                            })
        case "updateUserInfo":
            guard let payload = command.argument(at: 1) as? [String: Any]
            else {
                sendErrorLog("wcSessionCommand: payload data error")
                return
            }
            session.transferUserInfo(payload)
        case "updateContext":
            guard let payload = command.argument(at: 1) as? [String: Any]
            else {
                sendErrorLog("wcSessionCommand: payload data error")
                return
            }
            lastWCSessionCommandCallback = command.callbackId
            do  {
                try session.updateApplicationContext(payload)
            }
            catch {
                sendErrorLog("wcSessionCommand: updateContext error \(error)")
                if (self.lastWCSessionCommandCallback != nil) {
                    let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "wcSessionCommand: updateContext error \(error)")
                    self.commandDelegate.send(result, callbackId: self.lastWCSessionCommandCallback)
                    self.lastWCSessionCommandCallback = nil
                }
            }
        default:
            sendErrorLog("wcSessionCommand: op data error " + op)
        }
    }
}

// These funcs can be called to send a log to the cordova console from iOS swift
// code external to WatchLink.swift
func swiftLog(_ msg: String) {
	if (watchObj == nil) {
        let message = Date().timeOfDay() + ">> " + msg
		print("watchObj is nil--" + message)
		swiftLogbacklog = swiftLogbacklog + " \n    " + message
	}
	else {
		watchObj.sendLog(msg)
	}
}

func swiftAppLog(_ msg: String) {
	if (watchObj == nil) {
        let message = Date().timeOfDay() + "App>> " + msg
		print("watchObj is nil--" + message)
		swiftLogbacklog = swiftLogbacklog + " \n    " + message
	}
	else {
		watchObj.sendAppLog(msg)
	}
}

func swiftErrorLog(_ msg: String) {
	if (watchObj == nil) {
        let message = Date().timeOfDay() + "Error>> " + msg
		print("watchObj is nil--" + message)
		swiftLogbacklog = swiftLogbacklog + " \n    " + "Error>> " + message
	}
	else {
		watchObj.sendErrorLog(msg)
	}
}

var swiftLogbacklog: String = "BACKLOG"

extension Date {
	func currentTimeMillis() -> Int64 {
		return Int64(self.timeIntervalSince1970 * 1000)
	}
}

extension Date {
	func timeOfDay() -> String {
		let calendar = Calendar.current
		let hour = calendar.component(.hour, from: self)
		let minute = calendar.component(.minute, from: self)
		let second = calendar.component(.second, from: self)
		var time: timeval = timeval()
		gettimeofday(&time, nil)
		let millis = time.tv_usec/1000
		return "[" + (hour < 10 ? "0" + String(hour) : String(hour)) + ":" + 
			(minute < 10 ? "0" + String(minute) : String(minute)) + ":" + 
				(second < 10 ? "0" + String(second) : String(second)) + "." + 
				(millis < 10 ? "00" + String(millis) : 
						(millis < 100 ? "0" + String(millis) : String(millis))) + "]"
	}
}

extension String {
	func matches(_ regex: String) -> Bool {
		return self.range(of: regex, options: .regularExpression, 
			range: nil, locale: nil) != nil
	}
}







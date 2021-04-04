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

/*
 
This module provides the WatchLink connectivity class for the watch extension.

Usage: this should be a super-class of your extension delegate, as in
 
	class ExtensionDelegate: WatchLinkExtensionDelegate {
		 override func applicationDidFinishLaunching() {
			 // Perform any final initialization of your application.
			 super.applicationDidFinishLaunching()
			 printAppLog("AppExtensionDelegate.applicationDidFinishLaunching")
		 }
	}
 
 If your extension delegate processes any of the "session" invocations you must also pass
 these up to WatchLinkExtensionDelegate for processing. However, in most cases, intercepting
 the "session" invocations should not be necessary.
 
 See https://developer.apple.com/documentation/watchconnectivity/wcsessiondelegate for details.
 
 This module also provides the messaging functions to initiate communication with the host app.
 
 */
import WatchKit
import WatchConnectivity
import UserNotifications

var watchObj: WatchLinkExtensionDelegate!

let reservedMsgTypes = "^(" + 
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

var watchInitialized = false

var watchInitializedFunc: (() -> Void)!

func watchReady(_ f: @escaping (() -> Void)) {
	watchInitializedFunc = f
	if (watchInitialized) {
		f()
	}
}

var watchResetFunc: (() -> Void)!

func watchReset(_ f: @escaping (() -> Void)) {
    watchResetFunc = f
}

var phoneAvailable = false
var phoneReachable = false

var availabilityChanged: ((Bool) -> Void)!
var reachabilityChanged: ((Bool) -> Void)!

func bindAvailabilityHandler(_ handler: @escaping ((Bool) -> Void)) {
    availabilityChanged = handler
}
func bindReachabilityHandler(_ handler: @escaping ((Bool) -> Void)) {
    reachabilityChanged = handler
}

func nullHandler(_ msg: String) {}

var watchAppMessageHandlers: [(msgType: String, msgRegex: String, 
	handler: ((String, [String: Any]) -> Bool))]!

var defaultAppMessageHandler: ((String, [String: Any]) -> Void) = logDefaultMessage
	
var watchAppDataMessageHandler: ((Data) -> Void) = logDefaultDataMessage

var watchUserInfoHandler: ((Int64, [String: Any]) -> Void)?

var watchContextHandler: ((Int64, [String: Any]) -> Void)?

func messageToPhone(msgType: String, msgBody: [String: Any], ack: Bool = false, 
	ackHandler: (@escaping (String) -> Void) = nullHandler, 
	errHandler: (@escaping (String) -> Void) = nullHandler, allowReserved: Bool = false) -> Int64
{
	if (watchObj == nil || !watchInitialized) {
		printErrorLog("messageToPhone watchObj is not ready, " + msgType + ": " + 
			String(describing: msgBody));
		return 0
	}
	if (!allowReserved && msgType.matches(reservedMsgTypes)) {
		printErrorLog("messageToPhone matching expr uses reserved word, " + 
			msgType + ": " + String(describing: msgBody));
		return 0
	}
	return watchObj.sendMessage(msgType: msgType, msgBody: msgBody, ack:
		ack, ackHandler: ackHandler, errHandler: errHandler)
}

func dataMessageToPhone(dataMsg: Data, ack: Bool = false, 
	ackHandler: (@escaping (String) -> Void) = nullHandler,
	errHandler: (@escaping (String) -> Void) = nullHandler) -> Int64
{
	if (watchObj == nil || !watchInitialized) {
		printErrorLog("dataMessageToPhone watchObj is not ready");
		return 0
	}
    return watchObj.sendDataMessage(msgData: dataMsg,
		ack: ack, ackHandler: ackHandler, errHandler: errHandler)
}

func bindMessageHandler(msgType: String, handler: @escaping ((String, [String: Any]) -> Bool)) {
	if (watchAppMessageHandlers == nil) {
		watchAppMessageHandlers = []
	}
	if (msgType.matches(reservedMsgTypes)) {
		printErrorLog("bindMessageHandler matching expr uses reserved word, " + msgType)
		return
	}
	watchAppMessageHandlers.append((msgType: msgType, msgRegex: "", handler: handler))
}

func bindMessageHandler(msgRegex: String, 
	handler: @escaping ((String, [String: Any]) -> Bool))
{
	if (watchAppMessageHandlers == nil) {
		watchAppMessageHandlers = []
	}
	if (msgRegex.matches(reservedMsgTypes)) {
		printErrorLog("bindMessageHandler matching expr uses reserved word, " + msgRegex)
		return
	}
	watchAppMessageHandlers.append((msgType: "", msgRegex: msgRegex, handler: handler))
}

func bindDefaultMessageHandler(handler: @escaping ((String, [String: Any]) -> Void)) {
	defaultAppMessageHandler = handler
}

func bindDataMessageHandler(handler: @escaping (Data) -> Void) {
	watchAppDataMessageHandler = handler
}

func bindUserInfoHandler(handler: @escaping (Int64, [String: Any]) -> Void) {
	watchUserInfoHandler = handler
}

func bindContextHandler(handler: @escaping (Int64, [String: Any]) -> Void) {
    watchContextHandler = handler
}

func updateUserInfoToPhone(_ userInfo: [String: Any], ack: Bool = false, 
	ackHandler: (@escaping (String) -> Void) = nullHandler, 
	errHandler: (@escaping (String) -> Void) = nullHandler) -> Int64 
{
	if (watchObj == nil || !watchInitialized || !watchInitialized) {
		printLog("updateUserInfoToPhone watchObj is not ready, userInfo=" + String(describing:userInfo))
		return 0
	}
	if (userInfo["ACK"] != nil || userInfo["TIMESTAMP"] != nil) {
		watchErrorLog("updateUserInfoToPhone conext contains reserved keys: " +
			String(describing:userInfo))
		return 0
	}
	return watchObj.sendUserInfo(userInfo, ack: ack, 
		ackHandler: ackHandler, errHandler: errHandler)
}

func updateContextToPhone(_ context: [String: Any], ack: Bool = false, 
	ackHandler: (@escaping (String) -> Void) = nullHandler, 
	errHandler: (@escaping (String) -> Void) = nullHandler) -> Int64 
{
	if (watchObj == nil || !watchInitialized) {
		printLog("updateContextToPhone watchObj is not ready, context=" + String(describing:context));
		return 0
	}
	if (context["ACK"] != nil || context["TIMESTAMP"] != nil) {
		watchErrorLog("updateContextToPhone conext contains reserved keys: " +
			String(describing:context))
		return 0
	}
	return watchObj.sendContext(context, ack: ack, 
		ackHandler: ackHandler, errHandler: errHandler)
}

private func logDefaultDataMessage(_:Data) -> Void {
	printLog("Data message handler not bound")
}

private func logDefaultMessage(_ msgType: String, _ msgBody: Any) -> Void {
    printLog("Message default handler not bound " + msgType + ": " + String(describing: msgBody))
}

var watchLogLevel = 3
var watchPrintLogLevel = 3

func printLog(_ msg: String) {
	if (watchPrintLogLevel > 2) {
		print("Print" + Date().timeOfDay() + ">> " + msg)
	}
}

func printAppLog(_ msg: String) {
	if (watchPrintLogLevel > 1) {
		print("Print" + Date().timeOfDay() + "App>> " + msg)
	}
}

func printErrorLog(_ msg: String) {
	if (watchPrintLogLevel > 0) {
		print("Print" + Date().timeOfDay() + "Error>> " + msg)
	}
}

func watchLog(_ msg: String) {
	if (watchLogLevel > 2) {
        _ = messageToPhone(msgType: "WATCHLOG", msgBody: ["msg": msg],
			allowReserved: true)
	}
	printLog(msg)
}

func watchAppLog(_ msg: String) {
	if (watchLogLevel > 1) {
        _ = messageToPhone(msgType: "WATCHAPPLOG", msgBody: ["msg": msg],
			allowReserved: true)
	}
	printAppLog(msg)
}

func watchErrorLog(_ msg: String) {
	if (watchLogLevel > 0) {
        _ = messageToPhone(msgType: "WATCHERRORLOG", msgBody: ["msg": msg],
			allowReserved: true)
	}
	printErrorLog(msg)
}

class WatchLinkExtensionDelegate: NSObject, WKExtensionDelegate,
                                  WCSessionDelegate, UNUserNotificationCenterDelegate {
								  
	
	private class MessageQueue {
	
		var processing = false
        
        var lock = NSLock()

		var msgQueue: [(timestamp: Int64, session: Int64, ack: Bool, 
			ackHandler: (String) -> Void, 
			errHandler: (String) -> Void, msgType: String, msg: Any)] = []
		
		func enqueue(msgType: String, msg: Any, ack: Bool, 
			ackHandler: @escaping (String) -> Void, 
			errHandler: @escaping (String) -> Void) -> Int64 
		{
            lock.lock()
			var timestamp = newTimestamp()
			if (!msgQueue.isEmpty && msgQueue.last!.timestamp >= timestamp) {
				timestamp = msgQueue.last!.timestamp + 1;
			}
			msgQueue.append((timestamp: timestamp, session: watchObj.sessionID, 
				ack: ack, ackHandler: ackHandler, errHandler: errHandler, 
				msgType: msgType, msg: msg))
            lock.unlock()
			return timestamp;
		}
		
		// get the queue item with timestamp matching. Items with lower timestamp 
		// are ignored (probably obsolete)
		func getQueueItem(_ timestamp: Int64) -> Int {
            lock.lock()
			var index = 0;
			while (index < msgQueue.count && msgQueue[index].timestamp <= timestamp) {
				if (msgQueue[index].timestamp == timestamp && 
					msgQueue[index].session == watchObj.sessionID) 
				{
                    lock.unlock()
					return index
				}
				index += 1
			}
            lock.unlock()
			return -1
		}
		
		// clear out the queue
        func resetQueue(_ session: Int64) {
            lock.lock()
			while (!msgQueue.isEmpty) {
				msgQueue.remove(at: 0)
			}
			watchObj.sessionID = session
            lock.unlock()
		}
		
		// update the session ID. Queue items with session ID = 0 were added before the session
		// was initialized and are assigned the new session ID. Other queue items are removed
		func updateSession() {
            lock.lock()
            processing = msgQueue.count > 0 && msgQueue[0].ack &&
                            (msgQueue[0].session == 0 || msgQueue[0].session == watchObj.sessionID)
			var i = msgQueue.count - 1
			while (i >= 0) {
				if (msgQueue[i].session == 0) {
					msgQueue[i].session = watchObj.sessionID
				}
				else
				if (msgQueue[i].session != watchObj.sessionID) {
					msgQueue.remove(at: i)
				}
				i -= 1
			}
            lock.unlock()
		}
		
		// invoke the ackHandler for the queue item with matching timestamp.
		// Items with earlier timestamps are obsolete and are removed.
		func clearQueue(timestamp: Int64, isError: Bool = false, msg: String = "") {
            lock.lock()
			if (msgQueue.isEmpty) {
				printErrorLog("clearQueue \(timestamp) empty queue")
			}
			while (!msgQueue.isEmpty && msgQueue.first!.timestamp <= timestamp) {
				if (msgQueue.first!.timestamp < timestamp) {
					printLog("clearQueue first \(msgQueue.first!.timestamp) not acknowledged")
				}
				else 
				if (isError) {
					msgQueue.first!.errHandler(msg + ":" + String(msgQueue.first!.timestamp))
				}
				else {
					msgQueue.first!.ackHandler(String(msgQueue.first!.timestamp))
				}
				msgQueue.remove(at: 0)
			}
			processing = false
            lock.unlock()
		}
	}

	private var hostMessageQueue: MessageQueue!
	private var hostDataMessageQueue: MessageQueue!
	private var hostUserInfoQueue: MessageQueue!
	private var pendingContextUpdate: (
		timestamp: Int64, 
		session: Int64, 
		ack: Bool, 
		sent: Bool, 
		context: [String: Any],
		ackHandler: (String) -> Void,
		errHandler: (String) -> Void
    )!
	var sessionID: Int64 = 0
	
	private func handleReset(_ newSession: Int64) {
		sessionID = newSession
		hostMessageQueue.updateSession()
		hostDataMessageQueue.updateSession()
		hostUserInfoQueue.updateSession()
		if (pendingContextUpdate != nil) {
			if (pendingContextUpdate!.session == 0) {
				pendingContextUpdate!.session = sessionID
			}
			else {
				pendingContextUpdate.errHandler("")
				pendingContextUpdate = nil
			}
		}
	}
   
	private func handleMessageQueueResponse(response: [String: Any], 
		_ queue: MessageQueue)
	{
		let timestamp = response["timestamp"] as! Int64
		printLog("Acknowledged \(timestamp)")
		queue.clearQueue(timestamp: timestamp)
		processQueue()
	}
	
	private func handleMessageQueueError(_ response: Error, _ timestamp: Int64, 
		_ queue: MessageQueue) {
		if (!queue.msgQueue.isEmpty) {
			let index = queue.getQueueItem(timestamp)
			if (index != -1) {
                if (WCError.Code.notReachable.rawValue as Int == (response as NSError).code ||
                        String(describing: response).matches("WCErrorDomain Code=7007")) {
					printErrorLog("handleMessageQueueError \(queue.msgQueue[index].timestamp)" +
						" watch not reachable after transmission (will retry), msgType = " + 
						queue.msgQueue[index].msgType + ":")
					queue.processing = false
				}
				else {
					printErrorLog("handleMessageQueueError \(queue.msgQueue[index].timestamp) " + 
						response.localizedDescription + " payload = " + queue.msgQueue[index].msgType +
						": " + String(describing: queue.msgQueue[index].msg))
					queue.clearQueue(timestamp: timestamp, isError: true, 
						msg: response.localizedDescription)
				}
			}
			else {
				queue.processing = false
			}
			processQueue()
		}
	}
	
	private func dispatchContext() {
		let watchSession = WCSession.default
		pendingContextUpdate.context["ACK"] = pendingContextUpdate.ack
		pendingContextUpdate.context["TIMESTAMP"] = pendingContextUpdate.timestamp
		pendingContextUpdate.context["SESSION"] = pendingContextUpdate.session
		do {
			try
				watchSession.updateApplicationContext(pendingContextUpdate.context)
		}
		catch {
			if (WCError.Code.notReachable.rawValue as Int == (error as NSError).code) {
				return
			}
			pendingContextUpdate = nil
			watchLog("dispatchContext FAILED: " + error.localizedDescription)
			pendingContextUpdate.errHandler("failed: " + error.localizedDescription)
			return
		}
		printLog("dispatchContext " + String(describing: pendingContextUpdate.context))
		if (pendingContextUpdate.ack) {
			pendingContextUpdate.sent = true
		}
		else {
			pendingContextUpdate = nil
		}
	}
	
	private func processQueue() {
		let watchSession = WCSession.default
		if (watchSession.activationState != WCSessionActivationState.activated) {
			return
		}
        hostMessageQueue.lock.lock()
		while (!hostMessageQueue.msgQueue.isEmpty && watchSession.isReachable && 
			!hostMessageQueue.processing) 
		{
			let nextMsg = hostMessageQueue.msgQueue.first!
			if (nextMsg.session != 0 && nextMsg.session != sessionID) {
                printLog("Removed invalid session \(nextMsg.session)")
				hostMessageQueue.msgQueue.remove(at: 0)
				continue
			}
			let timestamp = nextMsg.timestamp
			printLog("Sending message " + 
				String(describing: ["timestamp": nextMsg.timestamp, "ack": nextMsg.ack, 
					"msgType": nextMsg.msgType, "msgBody": nextMsg.msg]))
			let replyHandler : (([String: Any]) -> Void)? =
				(nextMsg.ack ?
					{ (response: [String: Any]) in
						watchObj.handleMessageQueueResponse(response: response,
							self.hostMessageQueue) }
					: nil)
			watchSession.sendMessage(
				["timestamp": nextMsg.timestamp, "session" : nextMsg.session, 
					"msgType": nextMsg.msgType, "msgBody": nextMsg.msg],
				replyHandler: replyHandler,
				errorHandler: 
					{ (response: Error) in self.handleMessageQueueError(response,
						timestamp, self.hostMessageQueue) })
			if (nextMsg.ack) {
				hostMessageQueue.processing = true
				break
			}
				hostMessageQueue.msgQueue.remove(at: 0)
		}
		if (hostMessageQueue.processing) {
			printLog("processQueue--processing Messages")
		}
        hostMessageQueue.lock.unlock()
        hostDataMessageQueue.lock.lock()
		while (!hostDataMessageQueue.msgQueue.isEmpty && 
			watchSession.isReachable && !hostDataMessageQueue.processing) 
		{
			let nextMsg = hostDataMessageQueue.msgQueue.first!
			if (nextMsg.session != 0 && nextMsg.session != sessionID) {
                printErrorLog("hostDataMessageQueue invalid session: " + String(nextMsg.session))
				hostDataMessageQueue.msgQueue.remove(at: 0)
				continue
			}
			let timestamp = nextMsg.timestamp
			printLog("Sending data message " +
				String(describing: ["timestamp": nextMsg.timestamp, "ack": nextMsg.ack]))
			let replyHandler : (([String: Any]) -> Void)? =
				(nextMsg.ack ?
					{ (response: [String: Any]) in
						watchObj.handleMessageQueueResponse(response: response,
							self.hostDataMessageQueue) }
					: nil)
			watchSession.sendMessage(
				["timestamp": nextMsg.timestamp, "session" : nextMsg.session, 
					"msgType": "DATA", "msgBody": nextMsg.msg],
				replyHandler: replyHandler,
				errorHandler: 
					{ (response: Error) in self.handleMessageQueueError(response,
						timestamp, self.hostDataMessageQueue) })
			if (nextMsg.ack) {
				hostDataMessageQueue.processing = true
				break
			}
			hostDataMessageQueue.msgQueue.remove(at: 0)
		}
		if (hostDataMessageQueue.processing) {
			printLog("processQueue--processing Data Messages")
		}
        hostDataMessageQueue.lock.unlock()
        hostUserInfoQueue.lock.lock()
		while (!hostUserInfoQueue.msgQueue.isEmpty && !hostUserInfoQueue.processing)
		{
			let nextMsg = hostUserInfoQueue.msgQueue.first!
			if (nextMsg.session != 0 && nextMsg.session != sessionID) {
				hostUserInfoQueue.msgQueue.remove(at: 0)
				continue
			}
			var msg = nextMsg.msg as! [String: Any]
			msg["ACK"] = nextMsg.ack
			msg["TIMESTAMP"] = nextMsg.timestamp
			msg["SESSION"] = nextMsg.session
			watchSession.transferUserInfo(msg)
			printLog("Sending User Info " + String(describing: nextMsg.msg))
			if (nextMsg.ack) {
				hostUserInfoQueue.processing = true
				break
			}
			hostUserInfoQueue.msgQueue.remove(at: 0)
		}
		if (hostUserInfoQueue.processing) {
			printLog("processQueue--processing UserInfo")
		}
		if (pendingContextUpdate != nil && !pendingContextUpdate.sent) 
		{
			dispatchContext();
		}
        hostUserInfoQueue.lock.unlock()
	}
	
	private func addMessage(msgType: String, msgBody: Any,
		ack: Bool = false, _ queue: MessageQueue,
		ackHandler: (@escaping (String) -> Void) = nullHandler, 
		errHandler: (@escaping (String) -> Void) = nullHandler) -> Int64
	{
		let timestamp = queue.enqueue(msgType: msgType, msg: msgBody, 
			ack: ack, ackHandler: ackHandler, errHandler: errHandler)
		printLog("Added message to queue timestamp: \(timestamp) ack:\(ack) " + msgType + ": " +
			String(describing: msgBody))
		processQueue()
		return timestamp
	}
	
	func startWatchSession(){
		guard WCSession.isSupported() else {
			printErrorLog("watchSession is not supported")
			return
		}
		printLog("Watch Session started")
		let watchSession = WCSession.default
		watchSession.delegate = self
		watchSession.activate()
	}

	internal func applicationDidFinishLaunching() {
		// Perform any final initialization of the application.
		startWatchSession()
		watchObj = self
		hostMessageQueue = MessageQueue()
        hostDataMessageQueue = MessageQueue()
		hostUserInfoQueue = MessageQueue()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
		printLog("WatchLinkExtensionDelegate.applicationDidFinishLaunching")
	}
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                             willPresent notification: UNNotification,
                   withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        printLog("userNotificationCenter: " + String(describing: notification))
        completionHandler([.sound,.banner])
    }
	
	func userNotificationCenter(_ center: UNUserNotificationCenter, 
                          didReceive response: UNNotificationResponse, 
               withCompletionHandler completionHandler: @escaping () -> Void) {
		printLog("userNotificationCenter didReceive: " + String(describing: response))
		completionHandler()
	}
    

	func applicationDidBecomeActive() {
		// Restart any tasks that were paused (or not yet started) while the application was
		// inactive. If the application was previously in the background, optionally 
		// refresh the user interface.
		printLog("Watch App Active")
        _ = addMessage(msgType: "WATCHAPPACTIVE", msgBody: [:], ack: false, hostMessageQueue)
	}

	func applicationWillResignActive() {
		// Sent when the application is about to move from active to inactive state.
		printLog("Watch App Background")
		_ = addMessage(msgType: "WATCHAPPBACKGROUND", msgBody: [:], 
			ack: false, hostMessageQueue)
	}
    
    func sessionCompanionAppInstalledDidChange(_ session: WCSession) {
        if (phoneReachable != session.isReachable) {
			phoneReachable = session.isReachable
			if (reachabilityChanged != nil) {
				reachabilityChanged(session.isReachable)
			}
		}
        phoneAvailable = session.isCompanionAppInstalled
        if (availabilityChanged != nil) {
            availabilityChanged(session.isCompanionAppInstalled)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        phoneReachable = session.isReachable
        if (reachabilityChanged != nil) {
            reachabilityChanged(session.isReachable)
        }
    }

	func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
		// Sent when the system needs to launch the application in the background to 
		// process tasks.
		for task in backgroundTasks {
			switch task {
			case let backgroundTask as WKApplicationRefreshBackgroundTask:
				// Be sure to complete the background task once you’re done.
				backgroundTask.setTaskCompletedWithSnapshot(false)
			case let snapshotTask as WKSnapshotRefreshBackgroundTask:
				// Snapshot tasks have a unique completion call, make sure to set your expiration date
				snapshotTask.setTaskCompleted(restoredDefaultState: true,
                    estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
			case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
				// Be sure to complete the connectivity task once you’re done.
				connectivityTask.setTaskCompletedWithSnapshot(false)
			case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
				// Be sure to complete the URL session task once you’re done.
				urlSessionTask.setTaskCompletedWithSnapshot(false)
			case let relevantShortcutTask as WKRelevantShortcutRefreshBackgroundTask:
				// Be sure to complete the relevant-shortcut task once you're done.
				relevantShortcutTask.setTaskCompletedWithSnapshot(false)
			case let intentDidRunTask as WKIntentDidRunRefreshBackgroundTask:
				// Be sure to complete the intent-did-run task once you're done.
				intentDidRunTask.setTaskCompletedWithSnapshot(false)
			default:
				// make sure to complete unhandled task types
				task.setTaskCompletedWithSnapshot(false)
			}
		}
	}
	
	func session(_ session: WCSession, 
		activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) 
	{
		let session = WCSession.default
        phoneReachable = session.isReachable
		if (activationState == WCSessionActivationState.activated) {
			if (session.isReachable) {
				printLog("Reachability state: YES")
			}
			else {
				printLog("Reachability state: NO")
			}
			if (activationState == WCSessionActivationState.activated) {
				phoneAvailable = true
				printLog("Watch App Active")
				_ = addMessage(msgType: "WATCHAPPACTIVE", msgBody: [:], ack: false, hostMessageQueue)
			}
			else {
				printLog("Watch App Inactive")
                phoneAvailable = false
				_ = addMessage(msgType: "WATCHAPPINACTIVE", msgBody: [:], ack: false, hostMessageQueue)
			}
			watchInitialized = true
			if (watchInitializedFunc != nil) {
				watchInitializedFunc()
				watchInitializedFunc = nil
			}
			processQueue()
		}
		else {
            phoneAvailable = false
			if (activationState == WCSessionActivationState.notActivated) {
				watchErrorLog("watch session not activated: " + error!.localizedDescription)
			}
			else {
				watchErrorLog("watch session inactive: " + error!.localizedDescription)
			}
		}
	}
	
	// messaging
    
    private func routeMessage(msgType: String, msgBody: Any) {
        switch msgType {
            case "RESET":
                guard let msg = msgBody as? [String: Any]
                else {
                    return
                }
                let reason = msg["WATCHLINKSESSIONRESET"] as? String
                if (reason != nil) {
                    watchLog("RESET: " + reason!)
                }
                return
            case "SETLOGLEVEL":
                let level = msgBody as? Int
                if (level != nil) {
                    let printLevel = watchPrintLogLevel
                    watchPrintLogLevel = 3
                    printLog("SETLOGLEVEL \(level!)")
                    watchPrintLogLevel = printLevel
                    watchLogLevel = level!
                }
                else {
                    printErrorLog("SETLOGLEVEL received illegal level " +
                        String(describing: msgBody))
                }
            case "SETPRINTLOGLEVEL":
                let level = msgBody as? Int
                if (level != nil) {
                    watchPrintLogLevel = 3
                    printLog("SETPRINTLOGLEVEL \(level!)")
                    watchPrintLogLevel = level!
                }
                else {
                    printErrorLog("SETPRINTLOGLEVEL received illegal level " +
                        String(describing: msgBody))
                }
            case "UPDATEDCONTEXT":
                let ackedTimestamp = Int64(msgBody as! String)
                if (ackedTimestamp != nil && pendingContextUpdate != nil && pendingContextUpdate.timestamp == ackedTimestamp!) {
                    pendingContextUpdate.ackHandler(String(ackedTimestamp!))
                    printLog("ACK UPDATEDCONTEXT")
                }
                else {
                    printErrorLog("ACK UPDATEDCONTEXT not pending")
                }
                pendingContextUpdate = nil
            case "UPDATEDUSERINFO":
                let ackedTimestamp = Int64(msgBody as! String)
                if (ackedTimestamp != nil) {
                    hostUserInfoQueue.clearQueue(timestamp: ackedTimestamp!)
                    printLog("ACK UPDATEDUSERINFO cleared queue")
                }
                else {
                    printErrorLog("ACK UPDATEDUSERINFO nil queue")
                }
                processQueue()
            case "DATA":
                watchLog("Received Data message")
                let msgData = msgBody as! Data
                watchAppDataMessageHandler(msgData)
            default:
                let body = msgBody as! [String: Any]
                watchLog("Received message " + msgType + ": " + String(describing: body))
                if (watchAppMessageHandlers != nil && msgType != "") {
                    var handled = false
                    for handler in watchAppMessageHandlers {
                        if (msgType == handler.msgType || msgType.matches(handler.msgRegex)) {
                            handled = true
                            //DispatchQueue.main.sync {
                            let handlerResult = (handler.handler(msgType, body) == false)
                            //}
                            if (handlerResult == false) {
                                break;
                            }
                        }
                    }
                    if (!handled) {
                        defaultAppMessageHandler(msgType, body)
                    }
                }
                else {
                    defaultAppMessageHandler(msgType, body)
                }
        }
    }
    
	func handleMessage(message: [String : Any]) {
        guard let session = message["session"] as? Int64
		else {
			printLog("didReceiveMessage SESSION not found message=" + 
				String(describing: message))
			defaultAppMessageHandler("WCSESSION", message)
			return
		}
        guard let msgType = message["msgType"] as? String
        else {
            printLog("didReceiveMessage msgType not found message=" +
                String(describing: message))
			defaultAppMessageHandler("WCSESSION", message)
            return
        }
		if (session < sessionID) {
			printLog("didReceiveMessage SESSION obsolete message=" + 
				String(describing: message))
			return
		}
        if (session > sessionID) {
            printLog("Session RESET, msgType=" + msgType + " old session=" + String(sessionID) + " new session=" + String(session))
            handleReset(session)
            if (watchResetFunc != nil) {
                watchResetFunc()
            }
        }
        guard let msgBody = message["msgBody"]
		else {
			printLog("didReceiveMessage msgBody not found message=" + 
				String(describing: message))
			defaultAppMessageHandler("WCSESSION", message)
			return
		}
        routeMessage(msgType: msgType, msgBody: msgBody)
	}
	
	func session(_ session: WCSession, 
		didReceiveMessage message: [String : Any], 
		replyHandler: @escaping ([String : Any]) -> Void) 
	{
		replyHandler(message)
        printLog("Received message " + String(describing: message))
		handleMessage(message: message)
	}
	
	func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        printLog("Received message " + String(describing: message))
		handleMessage(message: message)
	}
	
	func session(_ session: WCSession, 
		didReceiveMessageData message: Data, replyHandler: @escaping (Data) -> Void) 
	{
		replyHandler(message)
		watchAppDataMessageHandler(message)
	}
	
	func session(_ session: WCSession, didReceiveMessageData message: Data) -> Void
	{
		watchAppDataMessageHandler(message)
	}
	
	func sendMessage(msgType: String, msgBody: [String: Any], ack: Bool = false, 
		ackHandler: (@escaping (String) -> Void) = nullHandler, 
		errHandler: (@escaping (String) -> Void) = nullHandler) -> Int64 
	{
		return addMessage(msgType: msgType, msgBody: msgBody, ack: ack, 
			hostMessageQueue, ackHandler: ackHandler, errHandler: errHandler)
	}
	
	func sendDataMessage(msgData: Any, ack: Bool = false, 
		ackHandler: (@escaping (String) -> Void) = nullHandler,
		errHandler: (@escaping (String) -> Void) = nullHandler) -> Int64 
	{
		return addMessage(msgType: "DATA", msgBody: msgData, ack: ack,
			hostDataMessageQueue, ackHandler: ackHandler, errHandler: errHandler)
	}
	
	// application user info
	func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        let complication = userInfo["ISCOMPLICATION"] as? Bool
        if (complication != nil) {
            printLog("didReceiveUserInfo complication update=" +
                String(describing: userInfo))
            if (watchUserInfoHandler != nil) {
                watchUserInfoHandler!(-1, userInfo)
            }
            return
        }
		guard let timestamp = userInfo["TIMESTAMP"] as? Int64
		else {
			printLog("didReceiveUserInfo TIMESTAMP not found message=" +
				String(describing: userInfo))
			if (watchUserInfoHandler != nil) {
				watchUserInfoHandler!(-1, userInfo)
			}
			return
		}
		guard let ack = userInfo["ACK"] as? Bool
		else {
			printLog("didReceiveUserInfo ACK not found userInfo=" + 
				String(describing: userInfo))
			if (watchUserInfoHandler != nil) {
				watchUserInfoHandler!(-1, userInfo)
			}
			return
		}
		guard let session = userInfo["SESSION"] as? Int64
		else {
			printLog("didReceiveUserInfo SESSION not found userInfo=" + 
				String(describing: userInfo))
			if (watchUserInfoHandler != nil) {
				watchUserInfoHandler!(-1, userInfo)
			}
			return
		}
		if (session < sessionID) {
            printLog("didReceiveUserInfo SESSION obsolete session ID " + String(session) + ", sessionID=" +
                String(sessionID))
			return
		}
        if (session > sessionID) {
            handleReset(session)
            printLog("Session RESET via user info, old session=" + String(sessionID) + " new session=" + String(session))
            if (watchResetFunc != nil) {
                watchResetFunc()
            }
        }
		if (ack) {
			_ = addMessage(msgType: "UPDATEDUSERINFO", msgBody: "\(timestamp)", 
				ack: false, hostMessageQueue)
		}
        let msgType = userInfo["MSGTYPE"] as? String
        let msgBody = userInfo["MSGBODY"]
        if (msgType != nil && msgBody != nil) {
            printLog("Received message via user info " + String(describing: userInfo))
            routeMessage(msgType: msgType!, msgBody: msgBody!)
            return
        }
        printLog("Received user info " + String(describing: userInfo))
		if (watchUserInfoHandler != nil) {
			watchUserInfoHandler!(timestamp, userInfo)
		}
	}
	
	func sendUserInfo(_ info: [String: Any], ack: Bool = false, 
		ackHandler: (@escaping (String) -> Void) = nullHandler, 
		errHandler: (@escaping (String) -> Void) = nullHandler) -> Int64 
	{
		addMessage(msgType: "USERINFO", msgBody: info, ack: ack, hostUserInfoQueue,
			ackHandler: ackHandler, errHandler: errHandler)
	}
	
	// application context
	func session(_ session: WCSession, 
		didReceiveApplicationContext applicationContext: [String : Any]) 
	{
        printLog("Received context " + String(describing: applicationContext))
		guard let timestamp = applicationContext["TIMESTAMP"] as? Int64
		else {
			printLog("didReceiveApplicationContext TIMESTAMP not found" +
				" applicationContext=" +
				String(describing: applicationContext))
			if (watchContextHandler != nil) {
				watchContextHandler!(-1, applicationContext)
			}
			return
		}
		guard let ack = applicationContext["ACK"] as? Bool
		else {
			printLog("didReceiveApplicationContext ACK not found " +
				"applicationContext=" + 
				String(describing: applicationContext))
			if (watchContextHandler != nil) {
				watchContextHandler!(-1, applicationContext)
			}
			return
		}
		guard let session = applicationContext["SESSION"] as? Int64
		else {
			printLog("didReceiveApplicationContext SESSION not found " +
				"applicationContext=" + 
				String(describing: applicationContext))
			if (watchContextHandler != nil) {
				watchContextHandler!(-1, applicationContext)
			}
			return
		}
		if (session < sessionID) {
            printLog("didReceiveApplicationContext SESSION obsolete session ID " + String(session) + ", sessionID=" +
                String(sessionID))
			return
		}
        if (session > sessionID) {
            printLog("Session RESET via context, old session=" + String(sessionID) + " new sessionID=" + String(session))
            handleReset(session)
            if (watchResetFunc != nil) {
                watchResetFunc()
            }
        }
		if (ack) {
            _ = addMessage(msgType: "UPDATEDCONTEXT", msgBody: "\(timestamp)",
				ack: false, hostMessageQueue)
		}
		if (watchContextHandler != nil) {
			watchContextHandler!(timestamp, applicationContext)
		}
        else {
            watchErrorLog("watchContextHandler NOT BOUND")
        }
	}
	
	func sendContext(_ context: [String: Any], ack: Bool = false, 
		ackHandler: (@escaping (String) -> Void) = nullHandler, 
		errHandler: (@escaping (String) -> Void) = nullHandler) -> Int64 
	{
		let timestamp = Date().currentTimeMillis()
		if (pendingContextUpdate != nil) {
			pendingContextUpdate.errHandler("reset:" + String(pendingContextUpdate.timestamp))
		}
		pendingContextUpdate = (timestamp: timestamp, 
			session: sessionID, 
			ack: ack, 
			sent: false, context: context,
			ackHandler: ackHandler, 
			errHandler: errHandler)
		dispatchContext()
		return timestamp
	}
}

	var lastTimestamp: Int64 = 0

	func newTimestamp() -> Int64 {
		var timestamp = Date().currentTimeMillis()
		if (timestamp <= lastTimestamp) {
			timestamp = lastTimestamp + 1
		}
		lastTimestamp = timestamp
		return timestamp
	}
		
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
		return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
	}
}



import Foundation
import WatchConnectivity
import Combine

/// Manages Watch ↔ iPhone communication on the Watch side
final class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published private(set) var isReachable = false
    @Published private(set) var tasks: [WatchTask] = []
    @Published private(set) var lastSyncDate: Date?

    private let session: WCSession
    private let dataStore = WatchDataStore.shared

    private override init() {
        self.session = WCSession.default
        super.init()

        // Load cached data
        tasks = dataStore.todayTasks
        lastSyncDate = dataStore.lastSyncDate

        // Activate session
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Public Methods

    /// Request fresh task data from iPhone
    func requestSync() {
        guard session.isReachable else {
            print("[Watch] iPhone not reachable for sync")
            return
        }

        let message = WatchMessage(type: .requestSync)
        session.sendMessage(message.toDictionary(), replyHandler: nil) { error in
            print("[Watch] Failed to request sync: \(error.localizedDescription)")
        }
    }

    /// Toggle task completion and notify iPhone
    func toggleTaskCompletion(_ task: WatchTask) {
        // Optimistically update local state
        dataStore.markTaskCompleted(id: task.id)
        tasks = dataStore.todayTasks

        // Send completion request to iPhone
        let message = WatchMessage(type: .toggleCompletion, taskID: task.id)

        if session.isReachable {
            session.sendMessage(message.toDictionary(), replyHandler: nil) { error in
                print("[Watch] Failed to send completion: \(error.localizedDescription)")
            }
        } else {
            // Queue for later sync via transferUserInfo
            session.transferUserInfo(message.toDictionary())
        }
    }

    // MARK: - Private Methods

    private func handleTasksUpdate(_ tasks: [WatchTask]) {
        DispatchQueue.main.async {
            self.dataStore.updateTasks(tasks)
            self.tasks = tasks
            self.lastSyncDate = Date()
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("[Watch] Session activation failed: \(error.localizedDescription)")
            return
        }
        print("[Watch] Session activated: \(activationState.rawValue)")

        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }

        // Request initial sync
        if activationState == .activated {
            requestSync()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }

        if session.isReachable {
            requestSync()
        }
    }

    // Receive messages from iPhone
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleIncomingMessage(message)
        replyHandler(["received": true])
    }

    // Receive background transfers
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleIncomingMessage(userInfo)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleIncomingMessage(applicationContext)
    }

    // iOS-only required delegate methods
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("[Watch] Session became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("[Watch] Session deactivated")
        session.activate()
    }
    #endif

    private func handleIncomingMessage(_ message: [String: Any]) {
        guard let watchMessage = WatchMessage.from(dictionary: message) else {
            print("[Watch] Failed to parse message")
            return
        }

        switch watchMessage.type {
        case .tasksUpdate:
            if let tasks = watchMessage.tasks {
                handleTasksUpdate(tasks)
            }
        case .syncComplete:
            print("[Watch] Sync complete")
        default:
            break
        }
    }
}

import Foundation
import WatchConnectivity
import Combine

/// Lightweight task model for Watch communication (iPhone side)
struct WatchTask: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let priority: Int16
    let isOverdue: Bool
    let dueTime: Date?

    init(from task: Task) {
        self.id = task.id
        self.title = task.title
        self.isCompleted = task.isCompleted
        self.priority = task.priority.rawValue
        self.isOverdue = task.isOverdue
        self.dueTime = task.dueTime
    }
}

// MARK: - Message Types

enum WatchMessageType: String, Codable {
    case requestSync = "requestSync"
    case tasksUpdate = "tasksUpdate"
    case toggleCompletion = "toggleCompletion"
    case syncComplete = "syncComplete"
}

struct WatchMessage: Codable {
    let type: WatchMessageType
    let tasks: [WatchTask]?
    let taskID: UUID?
    let timestamp: Date

    init(type: WatchMessageType, tasks: [WatchTask]? = nil, taskID: UUID? = nil) {
        self.type = type
        self.tasks = tasks
        self.taskID = taskID
        self.timestamp = Date()
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": type.rawValue,
            "timestamp": timestamp.timeIntervalSince1970
        ]
        if let tasks = tasks, let data = try? JSONEncoder().encode(tasks) {
            dict["tasks"] = data
        }
        if let taskID = taskID {
            dict["taskID"] = taskID.uuidString
        }
        return dict
    }

    static func from(dictionary: [String: Any]) -> WatchMessage? {
        guard let typeString = dictionary["type"] as? String,
              let type = WatchMessageType(rawValue: typeString) else {
            return nil
        }

        var tasks: [WatchTask]?
        if let tasksData = dictionary["tasks"] as? Data {
            tasks = try? JSONDecoder().decode([WatchTask].self, from: tasksData)
        }

        var taskID: UUID?
        if let taskIDString = dictionary["taskID"] as? String {
            taskID = UUID(uuidString: taskIDString)
        }

        return WatchMessage(type: type, tasks: tasks, taskID: taskID)
    }
}

// MARK: - Watch Connectivity Service (iPhone Side)

/// Manages iPhone ↔ Watch communication on the iPhone side
final class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published private(set) var isWatchAppInstalled = false
    @Published private(set) var isReachable = false

    private let session: WCSession
    private var taskService: TaskService?
    private var cancellables = Set<AnyCancellable>()

    private override init() {
        self.session = WCSession.default
        super.init()

        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Configuration

    /// Connect to TaskService to receive updates
    func configure(with taskService: TaskService) {
        self.taskService = taskService

        // Subscribe to task changes
        taskService.$tasks
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.sendTasksToWatch(tasks)
            }
            .store(in: &cancellables)
    }

    // MARK: - Sending Data to Watch

    func sendTasksToWatch(_ tasks: [Task]) {
        // Only attempt sync if Watch app is installed
        guard session.isWatchAppInstalled else { return }

        // Filter to today's tasks and limit to 20
        let todayTasks = tasks
            .filter { $0.isDueToday || $0.isOverdue }
            .prefix(20)
            .map { WatchTask(from: $0) }

        let message = WatchMessage(type: .tasksUpdate, tasks: Array(todayTasks))
        let dict = message.toDictionary()

        // Try immediate message if reachable
        if session.isReachable {
            session.sendMessage(dict, replyHandler: nil) { [weak self] error in
                // Fallback to application context
                self?.updateApplicationContext(dict)
            }
        } else {
            // Use application context for background updates
            updateApplicationContext(dict)
        }
    }

    private func updateApplicationContext(_ context: [String: Any]) {
        guard session.isWatchAppInstalled else { return }
        try? session.updateApplicationContext(context)
    }

    // MARK: - Handling Watch Requests

    private func handleCompletionRequest(taskID: UUID) {
        guard let taskService = taskService else { return }

        DispatchQueue.main.async {
            if let task = taskService.tasks.first(where: { $0.id == taskID }) {
                taskService.toggleTaskCompletion(task)
            }
        }
    }

    private func handleSyncRequest() {
        guard let taskService = taskService else { return }
        sendTasksToWatch(taskService.tasks)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate for new watch
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }

        // Send fresh data when Watch becomes reachable
        if session.isReachable, let taskService = taskService {
            sendTasksToWatch(taskService.tasks)
        }
    }

    // Receive messages from Watch
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

    private func handleIncomingMessage(_ message: [String: Any]) {
        guard let watchMessage = WatchMessage.from(dictionary: message) else { return }

        switch watchMessage.type {
        case .requestSync:
            handleSyncRequest()
        case .toggleCompletion:
            if let taskID = watchMessage.taskID {
                handleCompletionRequest(taskID: taskID)
            }
        default:
            break
        }
    }
}

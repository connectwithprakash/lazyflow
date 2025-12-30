import Foundation
import EventKit
import Combine

/// Service for managing calendar integration using EventKit
final class CalendarService: ObservableObject {
    static let shared = CalendarService()

    private let eventStore = EKEventStore()

    @Published private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var calendars: [EKCalendar] = []
    @Published private(set) var events: [EKEvent] = []

    private var cancellables = Set<AnyCancellable>()

    private init() {
        updateAuthorizationStatus()

        // Listen for calendar changes
        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .sink { [weak self] _ in
                self?.refreshCalendars()
            }
            .store(in: &cancellables)
    }

    // MARK: - Authorization

    private func updateAuthorizationStatus() {
        if #available(iOS 17.0, *) {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        } else {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        }
    }

    /// Request calendar access permission
    @MainActor
    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                updateAuthorizationStatus()
                if granted {
                    refreshCalendars()
                }
                return granted
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                updateAuthorizationStatus()
                if granted {
                    refreshCalendars()
                }
                return granted
            }
        } catch {
            print("Failed to request calendar access: \(error)")
            return false
        }
    }

    var hasCalendarAccess: Bool {
        if #available(iOS 17.0, *) {
            return authorizationStatus == .fullAccess
        } else {
            return authorizationStatus == .authorized
        }
    }

    // MARK: - Calendars

    /// Refresh the list of available calendars
    func refreshCalendars() {
        guard hasCalendarAccess else { return }
        calendars = eventStore.calendars(for: .event)
    }

    /// Get the default calendar for new events
    var defaultCalendar: EKCalendar? {
        eventStore.defaultCalendarForNewEvents
    }

    // MARK: - Events

    /// Fetch events for a date range
    func fetchEvents(from startDate: Date, to endDate: Date, calendars: [EKCalendar]? = nil) -> [EKEvent] {
        guard hasCalendarAccess else { return [] }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )

        let fetchedEvents = eventStore.events(matching: predicate)
        return fetchedEvents.sorted { $0.startDate < $1.startDate }
    }

    /// Fetch events for a specific day
    func fetchEvents(for date: Date) -> [EKEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return fetchEvents(from: startOfDay, to: endOfDay)
    }

    /// Fetch events for the current week
    func fetchEventsForCurrentWeek() -> [EKEvent] {
        let calendar = Calendar.current
        let today = Date()

        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return []
        }

        return fetchEvents(from: weekStart, to: weekEnd)
    }

    // MARK: - Event CRUD

    /// Create a new calendar event from a task
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        notes: String? = nil,
        calendar: EKCalendar? = nil
    ) throws -> EKEvent {
        guard hasCalendarAccess else {
            throw CalendarError.noAccess
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes
        event.calendar = calendar ?? defaultCalendar

        try eventStore.save(event, span: .thisEvent)

        return event
    }

    /// Create a time block event from a Task
    func createTimeBlock(for task: Task, startDate: Date, duration: TimeInterval) throws -> EKEvent {
        let endDate = startDate.addingTimeInterval(duration)

        let event = try createEvent(
            title: task.title,
            startDate: startDate,
            endDate: endDate,
            notes: task.notes
        )

        return event
    }

    /// Update an existing event
    func updateEvent(_ event: EKEvent) throws {
        guard hasCalendarAccess else {
            throw CalendarError.noAccess
        }

        try eventStore.save(event, span: .thisEvent)
    }

    /// Delete an event
    func deleteEvent(_ event: EKEvent) throws {
        guard hasCalendarAccess else {
            throw CalendarError.noAccess
        }

        try eventStore.remove(event, span: .thisEvent)
    }

    /// Find event by identifier
    func event(withIdentifier identifier: String) -> EKEvent? {
        eventStore.event(withIdentifier: identifier)
    }

    // MARK: - Task-Event Linking

    /// Link a task to a calendar event
    func linkTask(_ task: Task, toEventWithID eventID: String) -> Task {
        var updatedTask = task
        updatedTask.linkedEventID = eventID
        return updatedTask
    }

    /// Unlink a task from its calendar event
    func unlinkTask(_ task: Task) -> Task {
        var updatedTask = task
        updatedTask.linkedEventID = nil
        return updatedTask
    }

    /// Get the linked event for a task
    func linkedEvent(for task: Task) -> EKEvent? {
        guard let eventID = task.linkedEventID else { return nil }
        return event(withIdentifier: eventID)
    }

    // MARK: - Event to Task Conversion

    /// Create a task from a calendar event
    func createTaskFromEvent(_ event: EKEvent) -> Task {
        let task = Task(
            title: event.title ?? "Untitled Event",
            notes: event.notes,
            dueDate: event.startDate,
            linkedEventID: event.eventIdentifier,
            estimatedDuration: event.endDate.timeIntervalSince(event.startDate)
        )
        return task
    }

    /// Create a task from a CalendarEvent model
    func createTaskFromCalendarEvent(_ calendarEvent: CalendarEvent) -> Task {
        let task = Task(
            title: calendarEvent.title,
            dueDate: calendarEvent.startDate,
            linkedEventID: calendarEvent.id,
            estimatedDuration: calendarEvent.duration
        )
        return task
    }

    // MARK: - Bidirectional Sync

    /// Update calendar event when linked task changes
    func syncTaskToEvent(_ task: Task) throws {
        guard let eventID = task.linkedEventID,
              let event = event(withIdentifier: eventID) else {
            return
        }

        // Update event with task details
        event.title = task.title
        event.notes = task.notes

        // If task has a due date with time, update event time
        if let dueDate = task.dueDate {
            let duration = task.estimatedDuration ?? event.endDate.timeIntervalSince(event.startDate)
            event.startDate = dueDate
            event.endDate = dueDate.addingTimeInterval(duration)
        }

        try updateEvent(event)
    }

    /// Delete linked calendar event when task is deleted
    func deleteLinkedEvent(for task: Task) throws {
        guard let eventID = task.linkedEventID,
              let event = event(withIdentifier: eventID) else {
            return
        }

        try deleteEvent(event)
    }

    // MARK: - Time Block Helpers

    /// Find available time slots for a given duration on a specific day
    func findAvailableSlots(
        on date: Date,
        duration: TimeInterval,
        workingHoursStart: Int = 9,
        workingHoursEnd: Int = 17
    ) -> [DateInterval] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        guard let workStart = calendar.date(bySettingHour: workingHoursStart, minute: 0, second: 0, of: startOfDay),
              let workEnd = calendar.date(bySettingHour: workingHoursEnd, minute: 0, second: 0, of: startOfDay) else {
            return []
        }

        let events = fetchEvents(from: workStart, to: workEnd)

        var availableSlots: [DateInterval] = []
        var currentStart = workStart

        for event in events {
            // If there's a gap before this event
            if currentStart.addingTimeInterval(duration) <= event.startDate {
                availableSlots.append(DateInterval(start: currentStart, end: event.startDate))
            }
            // Move current start to after this event
            if event.endDate > currentStart {
                currentStart = event.endDate
            }
        }

        // Check for slot after last event
        if currentStart.addingTimeInterval(duration) <= workEnd {
            availableSlots.append(DateInterval(start: currentStart, end: workEnd))
        }

        return availableSlots
    }

    /// Suggest the next available time slot for a task
    func suggestTimeSlot(for task: Task, preferredDate: Date = Date()) -> DateInterval? {
        let duration = task.estimatedDuration ?? 3600 // Default 1 hour

        // Check today and next 7 days
        for dayOffset in 0..<7 {
            guard let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: preferredDate) else {
                continue
            }

            let slots = findAvailableSlots(on: date, duration: duration)
            if let firstSlot = slots.first {
                return DateInterval(start: firstSlot.start, duration: duration)
            }
        }

        return nil
    }
}

// MARK: - Calendar Errors

enum CalendarError: LocalizedError {
    case noAccess
    case eventNotFound
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .noAccess:
            return "Calendar access not granted. Please enable calendar access in Settings."
        case .eventNotFound:
            return "The calendar event could not be found."
        case .saveFailed:
            return "Failed to save the calendar event."
        }
    }
}

// MARK: - Calendar Event Model (for UI)

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarColor: CGColor?
    let linkedTaskID: UUID?

    init(from ekEvent: EKEvent, linkedTaskID: UUID? = nil) {
        self.id = ekEvent.eventIdentifier ?? UUID().uuidString
        self.title = ekEvent.title ?? "Untitled"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.isAllDay = ekEvent.isAllDay
        self.calendarColor = ekEvent.calendar?.cgColor
        self.linkedTaskID = linkedTaskID
    }

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        if isAllDay {
            return "All Day"
        }

        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}

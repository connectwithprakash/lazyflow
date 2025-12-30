import Foundation
import EventKit
import Combine

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published private(set) var calendarEvents: [CalendarEvent] = []
    @Published private(set) var hasAccess = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let calendarService = CalendarService.shared
    private let taskService = TaskService()
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
        checkAccess()
    }

    private func setupBindings() {
        calendarService.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if #available(iOS 17.0, *) {
                    self?.hasAccess = status == .fullAccess
                } else {
                    self?.hasAccess = status == .authorized
                }
            }
            .store(in: &cancellables)
    }

    private func checkAccess() {
        hasAccess = calendarService.hasCalendarAccess
    }

    // MARK: - Access

    func requestAccessIfNeeded() async {
        if !hasAccess {
            await requestAccess()
        } else {
            loadEvents()
        }
    }

    func requestAccess() async {
        let granted = await calendarService.requestAccess()
        hasAccess = granted
        if granted {
            loadEvents()
        }
    }

    // MARK: - Events

    func loadEvents() {
        guard hasAccess else { return }
        isLoading = true

        let today = Date()
        let calendar = Calendar.current

        // Load events for the current month
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            isLoading = false
            return
        }

        let ekEvents = calendarService.fetchEvents(from: monthStart, to: monthEnd)
        calendarEvents = ekEvents.map { CalendarEvent(from: $0) }

        isLoading = false
    }

    func events(for date: Date) -> [CalendarEvent] {
        let calendar = Calendar.current
        return calendarEvents.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: date)
        }
    }

    func eventsForWeek(containing date: Date) -> [Date: [CalendarEvent]] {
        let calendar = Calendar.current
        let weekStart = weekStart(for: date)

        var eventsByDay: [Date: [CalendarEvent]] = [:]

        for dayOffset in 0..<7 {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else {
                continue
            }
            let startOfDay = calendar.startOfDay(for: dayDate)
            eventsByDay[startOfDay] = events(for: dayDate)
        }

        return eventsByDay
    }

    func weekStart(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    // MARK: - Time Blocking

    func createTimeBlock(for task: Task, at startDate: Date) async throws {
        guard hasAccess else {
            throw CalendarError.noAccess
        }

        let duration = task.estimatedDuration ?? 3600 // Default 1 hour

        do {
            let event = try calendarService.createTimeBlock(for: task, startDate: startDate, duration: duration)

            // Refresh events
            loadEvents()

            // Return the event ID for linking
            if let eventID = event.eventIdentifier {
                // Update task with linked event ID
                await updateTaskWithEventLink(task: task, eventID: eventID)
            }
        } catch {
            errorMessage = "Failed to create time block: \(error.localizedDescription)"
            throw error
        }
    }

    private func updateTaskWithEventLink(task: Task, eventID: String) async {
        var updatedTask = task
        updatedTask.linkedEventID = eventID
        taskService.updateTask(updatedTask)
    }

    // MARK: - Suggestions

    func suggestTimeSlot(for task: Task) -> DateInterval? {
        calendarService.suggestTimeSlot(for: task)
    }

    func findAvailableSlots(on date: Date, duration: TimeInterval) -> [DateInterval] {
        calendarService.findAvailableSlots(on: date, duration: duration)
    }
}

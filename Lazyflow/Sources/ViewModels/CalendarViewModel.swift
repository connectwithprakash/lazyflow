import Foundation
import Observation
import EventKit
import Combine
import LazyflowCore

@MainActor
@Observable
final class CalendarViewModel {
    private(set) var calendarEvents: [CalendarEvent] = []
    private(set) var hasAccess = false
    private(set) var isDenied = false
    private(set) var isLoading = false
    var errorMessage: String?

    private let calendarService: CalendarService
    private let taskService: any TaskServiceProtocol
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    init(
        calendarService: CalendarService = .shared,
        taskService: any TaskServiceProtocol = TaskService.shared
    ) {
        self.calendarService = calendarService
        self.taskService = taskService
        setupBindings()
        checkAccess()
    }

    private func setupBindings() {
        calendarService.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if #available(iOS 17.0, *) {
                    self?.hasAccess = status == .fullAccess
                    self?.isDenied = status == .denied
                } else {
                    self?.hasAccess = status == .authorized
                    self?.isDenied = status == .denied
                }
            }
            .store(in: &cancellables)
    }

    private func checkAccess() {
        hasAccess = calendarService.hasCalendarAccess
        isDenied = calendarService.authorizationStatus == .denied
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
            try taskService.createCalendarEvent(for: task, startDate: startDate, duration: duration)
            loadEvents()
        } catch {
            errorMessage = "Failed to create time block: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Suggestions

    func suggestTimeSlot(for task: Task) -> DateInterval? {
        calendarService.suggestTimeSlot(for: task)
    }

    func findAvailableSlots(on date: Date, duration: TimeInterval) -> [DateInterval] {
        calendarService.findAvailableSlots(on: date, duration: duration)
    }
}

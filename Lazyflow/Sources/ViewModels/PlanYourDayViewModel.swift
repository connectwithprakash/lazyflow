import Foundation
import Combine
import EventKit

/// ViewModel for the Plan Your Day flow
@MainActor
final class PlanYourDayViewModel: ObservableObject {

    // MARK: - State

    enum ViewState {
        case loading
        case noAccess
        case empty
        case selection
        case creating
        case completed(PlanYourDayResult)
    }

    @Published var viewState: ViewState = .loading
    @Published var events: [PlanEventItem] = []

    private let calendarService: CalendarService
    private let taskService: TaskService

    // MARK: - Computed Properties

    var selectedEvents: [PlanEventItem] {
        events.filter(\.isSelected)
    }

    var selectedCount: Int {
        selectedEvents.count
    }

    var allSelected: Bool {
        !events.isEmpty && events.allSatisfy(\.isSelected)
    }

    var noneSelected: Bool {
        events.allSatisfy { !$0.isSelected }
    }

    /// Total estimated time in minutes for selected timed events (excludes all-day)
    var totalEstimatedMinutes: Int {
        selectedEvents.reduce(0) { total, event in
            total + (event.isAllDay ? 0 : event.durationMinutes)
        }
    }

    /// Formatted total estimated time
    var formattedEstimatedTime: String {
        let minutes = totalEstimatedMinutes
        if minutes == 0 { return "0m" }
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
    }

    /// Timed events (non all-day)
    var timedEvents: [PlanEventItem] {
        events.filter { !$0.isAllDay }
    }

    /// All-day events
    var allDayEvents: [PlanEventItem] {
        events.filter(\.isAllDay)
    }

    // MARK: - Init

    init(
        calendarService: CalendarService = .shared,
        taskService: TaskService = .shared
    ) {
        self.calendarService = calendarService
        self.taskService = taskService
    }

    // MARK: - Actions

    /// Load today's calendar events, filtering out those already linked to tasks
    func loadEvents() async {
        viewState = .loading

        if !calendarService.hasCalendarAccess {
            let granted = await calendarService.requestAccess()
            if !granted {
                viewState = .noAccess
                return
            }
        }

        let ekEvents = calendarService.fetchEvents(for: Date())
        let linkedEventIDs = Set(taskService.tasks.compactMap(\.linkedEventID))

        let items = Self.filterAndMap(ekEvents: ekEvents, linkedEventIDs: linkedEventIDs)

        if items.isEmpty {
            events = []
            viewState = .empty
        } else {
            events = items
            viewState = .selection
        }
    }

    /// Filter out already-linked events and map to PlanEventItems.
    /// Extracted as a static method for testability (EKEvent can't be mocked in unit tests,
    /// but this is covered via PlanEventItem-level tests).
    static func filterAndMap(ekEvents: [EKEvent], linkedEventIDs: Set<String>) -> [PlanEventItem] {
        ekEvents
            .filter { event in
                guard let identifier = event.eventIdentifier else { return false }
                return !linkedEventIDs.contains(identifier)
            }
            .map { PlanEventItem(from: $0) }
    }

    /// Toggle selection for a single event
    func toggleSelection(for eventID: String) {
        guard let index = events.firstIndex(where: { $0.id == eventID }) else { return }
        events[index].isSelected.toggle()
    }

    /// Select all events
    func selectAll() {
        for index in events.indices {
            events[index].isSelected = true
        }
    }

    /// Deselect all events
    func deselectAll() {
        for index in events.indices {
            events[index].isSelected = false
        }
    }

    /// Create tasks from selected events
    func createTasks() {
        let selected = selectedEvents
        guard !selected.isEmpty else { return }

        viewState = .creating

        var totalMinutes = 0

        for event in selected {
            let today = Calendar.current.startOfDay(for: Date())
            let dueTime = event.isAllDay ? nil : event.startDate
            let notes = event.location
            let estimatedDuration = event.isAllDay ? nil : event.duration

            taskService.createTask(
                title: event.title,
                notes: notes,
                dueDate: today,
                dueTime: dueTime,
                priority: .none,
                estimatedDuration: estimatedDuration,
                linkedEventID: event.eventIdentifier
            )

            if !event.isAllDay {
                totalMinutes += event.durationMinutes
            }
        }

        let result = PlanYourDayResult(
            tasksCreated: selected.count,
            totalEstimatedMinutes: totalMinutes,
            createdAt: Date()
        )

        viewState = .completed(result)
    }
}

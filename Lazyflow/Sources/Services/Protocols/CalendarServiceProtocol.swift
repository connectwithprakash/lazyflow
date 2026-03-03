import EventKit
import Foundation

/// Protocol defining the public API surface of CalendarService consumed by ViewModels.
protocol CalendarServiceProtocol: AnyObject {
    var authorizationStatus: EKAuthorizationStatus { get }
    var calendars: [EKCalendar] { get }
    var events: [EKEvent] { get }
    var hasCalendarAccess: Bool { get }

    @MainActor
    func requestAccess() async -> Bool

    func refreshCalendars()
    var defaultCalendar: EKCalendar? { get }
    func getOrCreateLazyflowCalendar() -> EKCalendar?
    func syncCalendar() -> EKCalendar?

    // MARK: - Event Fetch

    func fetchEvents(from startDate: Date, to endDate: Date, calendars: [EKCalendar]?) -> [EKEvent]
    func fetchEvents(for date: Date) -> [EKEvent]
    func fetchEventsForCurrentWeek() -> [EKEvent]

    // MARK: - Event CRUD

    @discardableResult
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        notes: String?,
        calendar: EKCalendar?,
        recurrenceRule: EKRecurrenceRule?
    ) throws -> EKEvent

    func createTimeBlock(for task: Task, startDate: Date, duration: TimeInterval) throws -> EKEvent
    func updateEvent(_ event: EKEvent, span: EKSpan) throws
    func deleteEvent(_ event: EKEvent, span: EKSpan) throws

    // MARK: - Event Lookup

    func event(withIdentifier identifier: String) -> EKEvent?
    func event(withExternalIdentifier identifier: String) -> EKEvent?

    // MARK: - Task-Event Linking

    func linkTask(_ task: Task, toEventWithID eventID: String) -> Task
    func unlinkTask(_ task: Task) -> Task
    func linkedEvent(for task: Task) -> EKEvent?

    // MARK: - Conversion

    func createTaskFromEvent(_ event: EKEvent) -> Task
    func createTaskFromCalendarEvent(_ calendarEvent: CalendarEvent) -> Task

    // MARK: - Sync

    func syncTaskToEvent(_ task: Task) throws
    func deleteLinkedEvent(for task: Task) throws

    // MARK: - Time Block Helpers

    func findAvailableSlots(
        on date: Date,
        duration: TimeInterval,
        workingHoursStart: Int,
        workingHoursEnd: Int
    ) -> [DateInterval]

    func suggestTimeSlot(for task: Task, preferredDate: Date) -> DateInterval?
}

// MARK: - Default Parameter Values

extension CalendarServiceProtocol {
    func fetchEvents(from startDate: Date, to endDate: Date, calendars: [EKCalendar]? = nil) -> [EKEvent] {
        fetchEvents(from: startDate, to: endDate, calendars: calendars)
    }

    @discardableResult
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        notes: String? = nil,
        calendar: EKCalendar? = nil,
        recurrenceRule: EKRecurrenceRule? = nil
    ) throws -> EKEvent {
        try createEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            notes: notes,
            calendar: calendar,
            recurrenceRule: recurrenceRule
        )
    }

    func updateEvent(_ event: EKEvent, span: EKSpan = .thisEvent) throws {
        try updateEvent(event, span: span)
    }

    func deleteEvent(_ event: EKEvent, span: EKSpan = .thisEvent) throws {
        try deleteEvent(event, span: span)
    }

    func findAvailableSlots(
        on date: Date,
        duration: TimeInterval,
        workingHoursStart: Int = 9,
        workingHoursEnd: Int = 17
    ) -> [DateInterval] {
        findAvailableSlots(
            on: date,
            duration: duration,
            workingHoursStart: workingHoursStart,
            workingHoursEnd: workingHoursEnd
        )
    }

    func suggestTimeSlot(for task: Task, preferredDate: Date = Date()) -> DateInterval? {
        suggestTimeSlot(for: task, preferredDate: preferredDate)
    }
}

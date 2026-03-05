import EventKit
import Foundation
import LazyflowCore
@testable import Lazyflow

/// No-op mock of CalendarServiceProtocol that records method calls.
/// Does not interact with the real EventKit store.
final class MockCalendarService: CalendarServiceProtocol {
    private(set) var calls: [String] = []

    var authorizationStatus: EKAuthorizationStatus = .notDetermined
    var calendars: [EKCalendar] = []
    var events: [EKEvent] = []
    var hasCalendarAccess: Bool = false
    var defaultCalendar: EKCalendar?

    @MainActor
    func requestAccess() async -> Bool {
        calls.append("requestAccess")
        return hasCalendarAccess
    }

    func refreshCalendars() {
        calls.append("refreshCalendars")
    }

    func getOrCreateLazyflowCalendar() -> EKCalendar? {
        calls.append("getOrCreateLazyflowCalendar")
        return nil
    }

    func syncCalendar() -> EKCalendar? {
        calls.append("syncCalendar")
        return nil
    }

    func fetchEvents(from startDate: Date, to endDate: Date, calendars: [EKCalendar]?) -> [EKEvent] {
        calls.append("fetchEvents(from:to:)")
        return events
    }

    func fetchEvents(for date: Date) -> [EKEvent] {
        calls.append("fetchEvents(for:)")
        return events
    }

    func fetchEventsForCurrentWeek() -> [EKEvent] {
        calls.append("fetchEventsForCurrentWeek")
        return events
    }

    @discardableResult
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        notes: String?,
        calendar: EKCalendar?,
        recurrenceRule: EKRecurrenceRule?
    ) throws -> EKEvent {
        calls.append("createEvent")
        let event = EKEvent(eventStore: EKEventStore())
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        return event
    }

    func createTimeBlock(for task: Task, startDate: Date, duration: TimeInterval) throws -> EKEvent {
        calls.append("createTimeBlock")
        let event = EKEvent(eventStore: EKEventStore())
        event.title = task.title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(duration)
        return event
    }

    func updateEvent(_ event: EKEvent, span: EKSpan) throws {
        calls.append("updateEvent")
    }

    func deleteEvent(_ event: EKEvent, span: EKSpan) throws {
        calls.append("deleteEvent")
    }

    func event(withIdentifier identifier: String) -> EKEvent? {
        calls.append("event(withIdentifier:)")
        return nil
    }

    func event(withExternalIdentifier identifier: String) -> EKEvent? {
        calls.append("event(withExternalIdentifier:)")
        return nil
    }

    func linkTask(_ task: Task, toEventWithID eventID: String) -> Task {
        calls.append("linkTask")
        var linked = task
        linked.linkedEventID = eventID
        return linked
    }

    func unlinkTask(_ task: Task) -> Task {
        calls.append("unlinkTask")
        return task
    }

    func linkedEvent(for task: Task) -> EKEvent? {
        calls.append("linkedEvent")
        return nil
    }

    func createTaskFromEvent(_ event: EKEvent) -> Task {
        calls.append("createTaskFromEvent")
        return Task(title: event.title ?? "Untitled", dueDate: event.startDate, linkedEventID: event.eventIdentifier)
    }

    func createTaskFromCalendarEvent(_ calendarEvent: CalendarEvent) -> Task {
        calls.append("createTaskFromCalendarEvent")
        return Task(title: calendarEvent.title, dueDate: calendarEvent.startDate)
    }

    func syncTaskToEvent(_ task: Task) throws {
        calls.append("syncTaskToEvent")
    }

    func deleteLinkedEvent(for task: Task) throws {
        calls.append("deleteLinkedEvent")
    }

    func findAvailableSlots(
        on date: Date,
        duration: TimeInterval,
        workingHoursStart: Int,
        workingHoursEnd: Int
    ) -> [DateInterval] {
        calls.append("findAvailableSlots")
        return []
    }

    func suggestTimeSlot(for task: Task, preferredDate: Date) -> DateInterval? {
        calls.append("suggestTimeSlot")
        return nil
    }
}

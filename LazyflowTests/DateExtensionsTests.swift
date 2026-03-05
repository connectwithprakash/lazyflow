import XCTest
import LazyflowCore
@testable import Lazyflow

final class DateExtensionsTests: XCTestCase {

    // MARK: - Date Properties

    func testIsToday() {
        XCTAssertTrue(Date().isToday)
        XCTAssertFalse(Date().addingDays(1).isToday)
        XCTAssertFalse(Date().addingDays(-1).isToday)
    }

    func testIsTomorrow() {
        XCTAssertTrue(Date().addingDays(1).isTomorrow)
        XCTAssertFalse(Date().isTomorrow)
    }

    func testIsYesterday() {
        XCTAssertTrue(Date().addingDays(-1).isYesterday)
        XCTAssertFalse(Date().isYesterday)
    }

    func testIsPast() {
        XCTAssertTrue(Date().addingDays(-1).isPast)
        XCTAssertFalse(Date().isPast, "Today should not be in the past")
        XCTAssertFalse(Date().addingDays(1).isPast)
    }

    func testIsWithinNextWeek() {
        XCTAssertTrue(Date().isWithinNextWeek)
        XCTAssertTrue(Date().addingDays(3).isWithinNextWeek)
        // addingDays(6) stays within the window; addingDays(7) depends on time of day
        XCTAssertTrue(Date().addingDays(6).isWithinNextWeek)
        XCTAssertFalse(Date().addingDays(8).isWithinNextWeek)
        XCTAssertFalse(Date().addingDays(-1).isWithinNextWeek)
    }

    // MARK: - Start/End of Day

    func testStartOfDay() {
        let date = Date()
        let start = date.startOfDay
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: start)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }

    func testEndOfDay() {
        let date = Date()
        let end = date.endOfDay
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: end)
        XCTAssertEqual(components.hour, 23)
        XCTAssertEqual(components.minute, 59)
        XCTAssertEqual(components.second, 59)
    }

    // MARK: - Date Arithmetic

    func testAddingDays() {
        let date = Date()
        let tomorrow = date.addingDays(1)
        XCTAssertTrue(Calendar.current.isDate(tomorrow, inSameDayAs: Calendar.current.date(byAdding: .day, value: 1, to: date)!))
    }

    func testAddingHours() {
        let date = Date()
        let later = date.addingHours(2)
        let diff = later.timeIntervalSince(date)
        XCTAssertEqual(diff, 7200, accuracy: 1)
    }

    func testAddingMinutes() {
        let date = Date()
        let later = date.addingMinutes(30)
        let diff = later.timeIntervalSince(date)
        XCTAssertEqual(diff, 1800, accuracy: 1)
    }

    // MARK: - Weekday

    func testWeekday_IsInRange() {
        let weekday = Date().weekday
        XCTAssertTrue((1...7).contains(weekday))
    }

    func testWeekdayName_NotEmpty() {
        XCTAssertFalse(Date().weekdayName.isEmpty)
    }

    func testShortWeekdayName_NotEmpty() {
        XCTAssertFalse(Date().shortWeekdayName.isEmpty)
    }

    // MARK: - Days From Today

    func testDaysFromToday() {
        XCTAssertEqual(Date().daysFromToday, 0)
        XCTAssertEqual(Date().addingDays(1).daysFromToday, 1)
        XCTAssertEqual(Date().addingDays(-1).daysFromToday, -1)
        XCTAssertEqual(Date().addingDays(7).daysFromToday, 7)
    }

    // MARK: - Date Creation

    func testDateFrom_ValidComponents() {
        let date = Date.from(year: 2026, month: 1, day: 15, hour: 10, minute: 30)
        XCTAssertNotNil(date)

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 10)
        XCTAssertEqual(components.minute, 30)
    }

    func testDateFrom_DefaultTime() {
        let date = Date.from(year: 2026, month: 6, day: 1)
        XCTAssertNotNil(date)
        let components = Calendar.current.dateComponents([.hour, .minute], from: date!)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
    }

    // MARK: - WithTime

    func testWithTime_CombinesCorrectly() {
        let date = Date.from(year: 2026, month: 3, day: 15)!
        let time = Date.from(year: 2026, month: 1, day: 1, hour: 14, minute: 30)!

        let combined = date.withTime(from: time)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: combined)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 30)
    }

    // MARK: - Formatting

    func testRelativeFormatted_Today() {
        XCTAssertEqual(Date().relativeFormatted, "Today")
    }

    func testRelativeFormatted_Tomorrow() {
        XCTAssertEqual(Date().addingDays(1).relativeFormatted, "Tomorrow")
    }

    func testRelativeFormatted_Yesterday() {
        XCTAssertEqual(Date().addingDays(-1).relativeFormatted, "Yesterday")
    }

    func testShortFormatted_ContainsExpectedContent() {
        let date = Date.from(year: 2026, month: 3, day: 15)!
        let formatted = date.shortFormatted
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("15") || formatted.contains("Mar") || formatted.contains("3"),
                       "Short format should contain the day or month")
    }

    func testFullFormatted_ContainsExpectedContent() {
        let date = Date.from(year: 2026, month: 3, day: 15)!
        let formatted = date.fullFormatted
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("2026") || formatted.contains("March") || formatted.contains("Mar"),
                       "Full format should contain the year or month name")
    }

    func testTimeFormatted_ContainsExpectedContent() {
        let date = Date.from(year: 2026, month: 1, day: 1, hour: 14, minute: 30)!
        let formatted = date.timeFormatted
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("30"), "Time format should contain the minutes")
    }

    func testDateTimeFormatted_ContainsExpectedContent() {
        let date = Date.from(year: 2026, month: 3, day: 15, hour: 14, minute: 30)!
        let formatted = date.dateTimeFormatted
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("15") || formatted.contains("Mar"),
                       "DateTime format should contain the day or month")
    }

    // MARK: - Date Range Helpers

    func testCurrentWeekDates_ReturnsSeven() {
        let dates = Date.currentWeekDates
        XCTAssertEqual(dates.count, 7)
    }

    func testNextDays_ReturnsCorrectCount() {
        XCTAssertEqual(Date.nextDays(5).count, 5)
        XCTAssertEqual(Date.nextDays(14).count, 14)
        XCTAssertEqual(Date.nextDays(0).count, 0)
    }

    func testNextDays_StartsFromToday() {
        let dates = Date.nextDays(3)
        XCTAssertTrue(Calendar.current.isDateInToday(dates[0]))
    }

    // MARK: - Natural Language Parsing

    func testParse_Today() {
        let result = Date.parse(from: "Buy groceries today")
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.date.isToday)
    }

    func testParse_Tomorrow() {
        let result = Date.parse(from: "Meeting tomorrow")
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.date.isTomorrow)
    }

    func testParse_CleanedTitle() {
        let result = Date.parse(from: "Buy groceries tomorrow")
        XCTAssertNotNil(result)
        let cleaned = result!.cleanedTitle(from: "Buy groceries tomorrow")
        XCTAssertEqual(cleaned, "Buy groceries")
    }

    func testParse_NoDate_ReturnsNil() {
        let result = Date.parse(from: "Buy groceries")
        XCTAssertNil(result)
    }
}

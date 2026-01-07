import XCTest
@testable import Lazyflow

final class TimeProtectionServiceTests: XCTestCase {

    // MARK: - TimeProtectionRule Tests

    func testTimeProtectionRule_FormattedTimeRange() {
        let rule = TimeProtectionRule(
            name: "Lunch",
            type: .lunch,
            startHour: 12,
            startMinute: 0,
            endHour: 13,
            endMinute: 30,
            daysOfWeek: [2, 3, 4, 5, 6]
        )
        XCTAssertEqual(rule.formattedTimeRange, "12:00 - 13:30")
    }

    func testTimeProtectionRule_FormattedDays_Weekdays() {
        let rule = TimeProtectionRule(
            name: "Work",
            type: .focus,
            startHour: 9,
            startMinute: 0,
            endHour: 17,
            endMinute: 0,
            daysOfWeek: [2, 3, 4, 5, 6] // Mon-Fri
        )
        XCTAssertEqual(rule.formattedDays, "Weekdays")
    }

    func testTimeProtectionRule_FormattedDays_Weekends() {
        let rule = TimeProtectionRule(
            name: "Rest",
            type: .personal,
            startHour: 0,
            startMinute: 0,
            endHour: 23,
            endMinute: 59,
            daysOfWeek: [1, 7] // Sun, Sat
        )
        XCTAssertEqual(rule.formattedDays, "Weekends")
    }

    func testTimeProtectionRule_FormattedDays_Everyday() {
        let rule = TimeProtectionRule(
            name: "Sleep",
            type: .sleep,
            startHour: 22,
            startMinute: 0,
            endHour: 6,
            endMinute: 0,
            daysOfWeek: [1, 2, 3, 4, 5, 6, 7]
        )
        XCTAssertEqual(rule.formattedDays, "Every day")
    }

    func testTimeProtectionRule_FormattedDays_Custom() {
        let rule = TimeProtectionRule(
            name: "Gym",
            type: .exercise,
            startHour: 6,
            startMinute: 0,
            endHour: 7,
            endMinute: 0,
            daysOfWeek: [2, 4, 6] // Mon, Wed, Fri
        )
        XCTAssertEqual(rule.formattedDays, "Mon, Wed, Fri")
    }

    // MARK: - TimeProtectionType Tests

    func testTimeProtectionType_AllCases() {
        let types: [TimeProtectionType] = [.lunch, .family, .focus, .sleep, .exercise, .personal, .custom]
        XCTAssertEqual(TimeProtectionType.allCases.count, types.count)
    }

    func testTimeProtectionType_SystemImages() {
        XCTAssertEqual(TimeProtectionType.lunch.systemImage, "fork.knife")
        XCTAssertEqual(TimeProtectionType.family.systemImage, "figure.2.and.child.holdinghands")
        XCTAssertEqual(TimeProtectionType.focus.systemImage, "brain.head.profile")
        XCTAssertEqual(TimeProtectionType.sleep.systemImage, "moon.zzz")
        XCTAssertEqual(TimeProtectionType.exercise.systemImage, "figure.run")
        XCTAssertEqual(TimeProtectionType.personal.systemImage, "person")
        XCTAssertEqual(TimeProtectionType.custom.systemImage, "clock")
    }

    func testTimeProtectionType_DefaultColors() {
        XCTAssertEqual(TimeProtectionType.lunch.defaultColor, "orange")
        XCTAssertEqual(TimeProtectionType.family.defaultColor, "pink")
        XCTAssertEqual(TimeProtectionType.focus.defaultColor, "purple")
        XCTAssertEqual(TimeProtectionType.sleep.defaultColor, "indigo")
        XCTAssertEqual(TimeProtectionType.exercise.defaultColor, "green")
        XCTAssertEqual(TimeProtectionType.personal.defaultColor, "blue")
        XCTAssertEqual(TimeProtectionType.custom.defaultColor, "gray")
    }

    // MARK: - Time Protection Check Tests

    func testIsTimeProtected_DuringProtectedTime() {
        let rules = [
            TimeProtectionRule(
                name: "Lunch",
                type: .lunch,
                startHour: 12,
                startMinute: 0,
                endHour: 13,
                endMinute: 0,
                daysOfWeek: [1, 2, 3, 4, 5, 6, 7], // Every day
                isActive: true
            )
        ]

        // Create a date at 12:30
        let calendar = Calendar.current
        let today = Date()
        let checkTime = calendar.date(bySettingHour: 12, minute: 30, second: 0, of: today)!

        let result = isTimeProtected(checkTime, rules: rules)
        XCTAssertTrue(result.isProtected)
        XCTAssertEqual(result.rule?.name, "Lunch")
    }

    func testIsTimeProtected_OutsideProtectedTime() {
        let rules = [
            TimeProtectionRule(
                name: "Lunch",
                type: .lunch,
                startHour: 12,
                startMinute: 0,
                endHour: 13,
                endMinute: 0,
                daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
                isActive: true
            )
        ]

        let calendar = Calendar.current
        let today = Date()
        let checkTime = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today)!

        let result = isTimeProtected(checkTime, rules: rules)
        XCTAssertFalse(result.isProtected)
        XCTAssertNil(result.rule)
    }

    func testIsTimeProtected_InactiveRule() {
        let rules = [
            TimeProtectionRule(
                name: "Lunch",
                type: .lunch,
                startHour: 12,
                startMinute: 0,
                endHour: 13,
                endMinute: 0,
                daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
                isActive: false // Disabled
            )
        ]

        let calendar = Calendar.current
        let today = Date()
        let checkTime = calendar.date(bySettingHour: 12, minute: 30, second: 0, of: today)!

        let result = isTimeProtected(checkTime, rules: rules)
        XCTAssertFalse(result.isProtected)
    }

    func testIsTimeProtected_OvernightRule() {
        let rules = [
            TimeProtectionRule(
                name: "Sleep",
                type: .sleep,
                startHour: 22,
                startMinute: 0,
                endHour: 6,
                endMinute: 0,
                daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
                isActive: true
            )
        ]

        let calendar = Calendar.current
        let today = Date()

        // 11 PM should be protected
        let lateNight = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: today)!
        let resultLate = isTimeProtected(lateNight, rules: rules)
        XCTAssertTrue(resultLate.isProtected)

        // 5 AM should be protected
        let earlyMorning = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: today)!
        let resultEarly = isTimeProtected(earlyMorning, rules: rules)
        XCTAssertTrue(resultEarly.isProtected)

        // 10 AM should not be protected
        let midMorning = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today)!
        let resultMid = isTimeProtected(midMorning, rules: rules)
        XCTAssertFalse(resultMid.isProtected)
    }

    // MARK: - Preset Rules Tests

    func testCreatePresetRules_HasExpectedCount() {
        let presets = TimeProtectionService.createPresetRules()
        XCTAssertEqual(presets.count, 5)
    }

    func testCreatePresetRules_HasLunchBreak() {
        let presets = TimeProtectionService.createPresetRules()
        let lunch = presets.first { $0.type == .lunch }
        XCTAssertNotNil(lunch)
        XCTAssertEqual(lunch?.startHour, 12)
        XCTAssertEqual(lunch?.endHour, 13)
    }

    func testCreatePresetRules_HasSleepTime() {
        let presets = TimeProtectionService.createPresetRules()
        let sleep = presets.first { $0.type == .sleep }
        XCTAssertNotNil(sleep)
        XCTAssertEqual(sleep?.startHour, 22)
        XCTAssertEqual(sleep?.endHour, 7)
        XCTAssertTrue(sleep?.isActive ?? false)
    }

    // MARK: - Rule Codable Tests

    func testTimeProtectionRule_Codable() throws {
        let rule = TimeProtectionRule(
            name: "Test Rule",
            type: .focus,
            startHour: 9,
            startMinute: 30,
            endHour: 11,
            endMinute: 30,
            daysOfWeek: [2, 3, 4],
            isActive: true,
            allowedCategories: [.work, .learning]
        )

        let encoded = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(TimeProtectionRule.self, from: encoded)

        XCTAssertEqual(decoded.id, rule.id)
        XCTAssertEqual(decoded.name, "Test Rule")
        XCTAssertEqual(decoded.type, .focus)
        XCTAssertEqual(decoded.startHour, 9)
        XCTAssertEqual(decoded.startMinute, 30)
        XCTAssertEqual(decoded.endHour, 11)
        XCTAssertEqual(decoded.endMinute, 30)
        XCTAssertEqual(decoded.daysOfWeek, [2, 3, 4])
        XCTAssertTrue(decoded.isActive)
        XCTAssertEqual(decoded.allowedCategories, [.work, .learning])
    }

    // MARK: - Helper Methods

    private func isTimeProtected(_ date: Date, rules: [TimeProtectionRule]) -> (isProtected: Bool, rule: TimeProtectionRule?) {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = timeComponents.hour, let minute = timeComponents.minute else {
            return (false, nil)
        }

        let timeInMinutes = hour * 60 + minute

        for rule in rules where rule.isActive {
            guard rule.daysOfWeek.contains(weekday) else { continue }

            let ruleStart = rule.startHour * 60 + rule.startMinute
            let ruleEnd = rule.endHour * 60 + rule.endMinute

            // Handle overnight rules
            if ruleStart > ruleEnd {
                if timeInMinutes >= ruleStart || timeInMinutes < ruleEnd {
                    return (true, rule)
                }
            } else {
                if timeInMinutes >= ruleStart && timeInMinutes < ruleEnd {
                    return (true, rule)
                }
            }
        }

        return (false, nil)
    }
}

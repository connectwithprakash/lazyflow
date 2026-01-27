import CoreData

extension RecurringRuleEntity {
    /// Typed accessor for daysOfWeek array
    /// Core Data stores as NSArray, this provides Swift [Int]? interface
    var daysOfWeekArray: [Int]? {
        get { daysOfWeek as? [Int] }
        set { daysOfWeek = newValue as NSArray? }
    }

    /// Typed accessor for specificTimes array
    /// Core Data stores as NSArray, this provides Swift [Date]? interface
    var specificTimesArray: [Date]? {
        get { specificTimes as? [Date] }
        set { specificTimes = newValue as NSArray? }
    }

    /// Convert Core Data entity to domain model
    func toRecurringRule() -> RecurringRule {
        RecurringRule(
            id: id ?? UUID(),
            frequency: RecurringFrequency(rawValue: frequencyRaw) ?? .daily,
            interval: Int(interval),
            daysOfWeek: daysOfWeekArray,
            endDate: endDate,
            hourInterval: hourInterval > 0 ? Int(hourInterval) : nil,
            timesPerDay: timesPerDay > 0 ? Int(timesPerDay) : nil,
            specificTimes: specificTimesArray,
            activeHoursStart: activeHoursStart,
            activeHoursEnd: activeHoursEnd
        )
    }

    /// Update entity from domain model
    func update(from rule: RecurringRule) {
        id = rule.id
        frequencyRaw = rule.frequency.rawValue
        interval = Int16(rule.interval)
        daysOfWeekArray = rule.daysOfWeek
        endDate = rule.endDate
        hourInterval = Int16(rule.hourInterval ?? 0)
        timesPerDay = Int16(rule.timesPerDay ?? 0)
        specificTimesArray = rule.specificTimes
        activeHoursStart = rule.activeHoursStart
        activeHoursEnd = rule.activeHoursEnd
    }
}

import CoreData

extension RecurringRuleEntity {
    /// Typed accessor for daysOfWeek array
    /// Core Data stores as NSArray, this provides Swift [Int]? interface
    var daysOfWeekArray: [Int]? {
        get { daysOfWeek as? [Int] }
        set { daysOfWeek = newValue as NSArray? }
    }
}

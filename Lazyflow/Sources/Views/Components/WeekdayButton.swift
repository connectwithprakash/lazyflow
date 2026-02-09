import SwiftUI

struct WeekdayButton: View {
    let day: Int
    let isSelected: Bool
    let action: () -> Void

    private var dayLetter: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let symbols = formatter.veryShortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        return symbols[day - 1]
    }

    var body: some View {
        Button(action: action) {
            Text(dayLetter)
                .font(DesignSystem.Typography.caption1)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : Color.Lazyflow.textPrimary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isSelected ? Color.Lazyflow.accent : Color.secondary.opacity(0.1))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

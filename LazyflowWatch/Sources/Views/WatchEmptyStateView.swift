import SwiftUI

/// Empty state when no tasks are due today
struct WatchEmptyStateView: View {
    private let accentColor = Color(red: 33/255, green: 138/255, blue: 141/255)

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(accentColor.opacity(0.6))

            Text("No tasks today")
                .font(.headline)

            Text("Enjoy your free time!")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    WatchEmptyStateView()
}

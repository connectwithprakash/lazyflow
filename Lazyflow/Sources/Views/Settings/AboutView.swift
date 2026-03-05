import SwiftUI
import LazyflowCore
import LazyflowUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xxl) {
                    // App Icon
                    Image(systemName: "clock.fill")
                        .font(.system(size: 64))
                        .foregroundColor(Color.Lazyflow.accent)
                        .padding(.top, DesignSystem.Spacing.xxl)

                    // App Name
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text("Lazyflow")
                            .font(DesignSystem.Typography.largeTitle)
                            .foregroundColor(Color.Lazyflow.textPrimary)

                        Text("Calendar-First Todo App")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                    }

                    // Description
                    Text("Lazyflow helps engineers manage their tasks and time by seamlessly integrating todo lists with your calendar. See what's due, when you're free, and plan your day with ease.")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.xxl)

                    Spacer()
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

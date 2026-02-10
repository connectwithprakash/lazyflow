import SwiftUI

struct DurationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var estimatedDuration: TimeInterval?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text("Estimated Duration")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Lazyflow.textPrimary)
                    .padding(.horizontal)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: DesignSystem.Spacing.sm) {
                    ForEach(TaskViewModel.durationPresets, id: \.0) { preset in
                        DurationChip(
                            title: preset.0,
                            isSelected: estimatedDuration == preset.1,
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if estimatedDuration == preset.1 {
                                        estimatedDuration = nil
                                    } else {
                                        estimatedDuration = preset.1
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, DesignSystem.Spacing.lg)
            .navigationTitle("Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if estimatedDuration != nil {
                        Button("Clear") {
                            estimatedDuration = nil
                            dismiss()
                        }
                        .foregroundColor(Color.Lazyflow.error)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

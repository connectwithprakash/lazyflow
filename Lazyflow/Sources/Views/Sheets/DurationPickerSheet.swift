import SwiftUI
import LazyflowCore
import LazyflowUI

struct DurationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var estimatedDuration: TimeInterval?

    @State private var customHours: Int = 0
    @State private var customMinutes: Int = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Preset Chips

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
                                        customHours = 0
                                        customMinutes = 0
                                    } else {
                                        estimatedDuration = preset.1
                                        syncWheelsFromDuration()
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, DesignSystem.Spacing.sm)

                // MARK: - Custom Wheels

                HStack(spacing: 0) {
                    Picker("Hours", selection: $customHours) {
                        ForEach(0...4, id: \.self) { hour in
                            Text("\(hour)").tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Text("hours")
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Lazyflow.textSecondary)

                    Picker("Minutes", selection: $customMinutes) {
                        ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { min in
                            Text("\(min)").tag(min)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Text("min")
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                }
                .padding(.horizontal)
                .onChange(of: customHours) { _, _ in
                    updateDurationFromWheels()
                }
                .onChange(of: customMinutes) { _, _ in
                    updateDurationFromWheels()
                }
            }
            .navigationTitle("Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if estimatedDuration != nil {
                        Button("Clear") {
                            estimatedDuration = nil
                            customHours = 0
                            customMinutes = 0
                            dismiss()
                        }
                        .foregroundColor(Color.Lazyflow.error)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                syncWheelsFromDuration()
            }
        }
    }

    private func syncWheelsFromDuration() {
        guard let duration = estimatedDuration else {
            customHours = 0
            customMinutes = 0
            return
        }
        let totalMinutes = Int(duration / 60)
        customHours = totalMinutes / 60
        customMinutes = (totalMinutes % 60 / 5) * 5
    }

    private func updateDurationFromWheels() {
        let totalSeconds = TimeInterval((customHours * 60 + customMinutes) * 60)
        if totalSeconds > 0 {
            estimatedDuration = totalSeconds
        } else {
            estimatedDuration = nil
        }
    }
}

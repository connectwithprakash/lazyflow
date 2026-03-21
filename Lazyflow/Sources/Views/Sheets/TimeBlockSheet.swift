import SwiftUI
import LazyflowCore
import LazyflowUI

struct TimeBlockSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedDate: Date?
    @Binding var hasDate: Bool
    @Binding var selectedTime: Date?
    @Binding var hasTime: Bool
    @Binding var estimatedDuration: TimeInterval?

    @State private var isCustomDurationExpanded = false
    @State private var customHours = 0
    @State private var customMinutes = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // MARK: - Quick Time Chips

                    HStack(spacing: DesignSystem.Spacing.md) {
                        TimeQuickOption(title: "Morning", hour: 9) {
                            setTime(hour: 9, minute: 0)
                        }
                        TimeQuickOption(title: "Afternoon", hour: 13) {
                            setTime(hour: 13, minute: 0)
                        }
                        TimeQuickOption(title: "Evening", hour: 18) {
                            setTime(hour: 18, minute: 0)
                        }
                    }
                    .padding(.horizontal)

                    // MARK: - Start Time Picker

                    DatePicker(
                        "Start Time",
                        selection: Binding(
                            get: { selectedTime ?? nextQuarterHour() },
                            set: {
                                selectedTime = $0
                                hasTime = true
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .font(DesignSystem.Typography.body)
                    .datePickerStyle(.compact)
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // MARK: - Duration Section Header

                    Text("Duration")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(Color.Lazyflow.textPrimary)
                        .padding(.horizontal)

                    // MARK: - Duration Preset Chips

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
                                            syncCustomWheelsFromDuration()
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)

                    // MARK: - Custom Duration

                    DisclosureGroup("Custom", isExpanded: $isCustomDurationExpanded) {
                        HStack(spacing: DesignSystem.Spacing.lg) {
                            VStack(spacing: DesignSystem.Spacing.xs) {
                                Picker("Hours", selection: $customHours) {
                                    ForEach(0...4, id: \.self) { hour in
                                        Text("\(hour)").tag(hour)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80, height: 120)
                                .clipped()

                                Text("hours")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(Color.Lazyflow.textSecondary)
                            }

                            VStack(spacing: DesignSystem.Spacing.xs) {
                                Picker("Minutes", selection: $customMinutes) {
                                    ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { minute in
                                        Text("\(minute)").tag(minute)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80, height: 120)
                                .clipped()

                                Text("min")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(Color.Lazyflow.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, DesignSystem.Spacing.sm)
                        .onChange(of: customHours) { _, _ in
                            syncDurationFromCustomWheels()
                        }
                        .onChange(of: customMinutes) { _, _ in
                            syncDurationFromCustomWheels()
                        }
                    }
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)
                    .padding(.horizontal)
                }
                .padding(.top)
            }
            .navigationTitle("Time Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        selectedTime = nil
                        hasTime = false
                        estimatedDuration = nil
                        customHours = 0
                        customMinutes = 0
                        isCustomDurationExpanded = false
                        dismiss()
                    }
                    .foregroundColor(Color.Lazyflow.error)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                // Auto-set date to today if no date set
                if !hasDate {
                    selectedDate = Date()
                    hasDate = true
                }
                // Auto-set time to next quarter hour if no time set
                if selectedTime == nil {
                    selectedTime = nextQuarterHour()
                    hasTime = true
                }
                // Auto-set duration to 30 min if not set
                if estimatedDuration == nil {
                    estimatedDuration = 30 * 60
                    customMinutes = 30
                }
                // Sync custom wheels from existing duration
                if let duration = estimatedDuration {
                    let totalMinutes = Int(duration) / 60
                    customHours = totalMinutes / 60
                    customMinutes = (totalMinutes % 60 / 5) * 5
                }
            }
        }
    }

    // MARK: - Helpers

    private func nextQuarterHour() -> Date {
        let cal = Calendar.current
        let now = Date()
        let minute = cal.component(.minute, from: now)
        let roundedUp = ((minute / 15) + 1) * 15
        return cal.date(byAdding: .minute, value: roundedUp - minute, to: now) ?? now
    }

    private func setTime(hour: Int, minute: Int) {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        if let date = Calendar.current.date(from: components) {
            selectedTime = date
            hasTime = true
        }
    }

    private func syncCustomWheelsFromDuration() {
        guard let duration = estimatedDuration else {
            customHours = 0
            customMinutes = 0
            return
        }
        let totalMinutes = Int(duration) / 60
        customHours = min(totalMinutes / 60, 4)
        customMinutes = (totalMinutes % 60 / 5) * 5
    }

    private func syncDurationFromCustomWheels() {
        let totalSeconds = TimeInterval((customHours * 60 + customMinutes) * 60)
        if totalSeconds > 0 {
            estimatedDuration = totalSeconds
        } else {
            estimatedDuration = nil
        }
    }
}

// MARK: - Time Quick Option

private struct TimeQuickOption: View {
    let title: String
    let hour: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                Text(formattedHour)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(Color.Lazyflow.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var formattedHour: String {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = 0
        guard let date = Calendar.current.date(from: components) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: date)
    }
}

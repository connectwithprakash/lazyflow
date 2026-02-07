import SwiftUI

/// Sheet-based flow for planning the day by selecting calendar events to convert to tasks
struct PlanYourDayView: View {
    @StateObject private var viewModel = PlanYourDayViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.viewState {
                case .loading:
                    loadingState
                case .noAccess:
                    noAccessState
                case .empty:
                    emptyState
                case .selection:
                    selectionState
                case .creating:
                    creatingState
                case .completed(let result):
                    completionState(result)
                }
            }
            .background(Color.adaptiveBackground)
            .navigationTitle("Plan Your Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await viewModel.loadEvents()
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading your calendar...")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - No Access State

    private var noAccessState: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundColor(Color.Lazyflow.warning)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Calendar Access Needed")
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(Color.Lazyflow.textPrimary)

                Text("Grant calendar access in Settings to\nreview events and plan your day.")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(Color.Lazyflow.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(width: 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 56))
                .foregroundColor(Color.Lazyflow.accent)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("All Set!")
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(Color.Lazyflow.textPrimary)

                Text("No new calendar events to review.\nAll events are already linked to tasks.")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(Color.Lazyflow.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button("Done") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .frame(width: 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Selection State

    private var selectionState: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    selectionHeader
                        .padding(.top, DesignSystem.Spacing.md)

                    // Timed events
                    if !viewModel.timedEvents.isEmpty {
                        eventSection(title: "Events", events: viewModel.timedEvents)
                    }

                    // All-day events
                    if !viewModel.allDayEvents.isEmpty {
                        eventSection(title: "All Day", events: viewModel.allDayEvents, deEmphasized: true)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }

            actionBar
        }
    }

    private var selectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text("\(viewModel.selectedCount) event\(viewModel.selectedCount == 1 ? "" : "s") selected")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.Lazyflow.textPrimary)

                if viewModel.selectedCount > 0 {
                    Text("Est. \(viewModel.formattedEstimatedTime)")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                }
            }

            Spacer()

            Button {
                withAnimation(DesignSystem.Animation.quick) {
                    if viewModel.allSelected {
                        viewModel.deselectAll()
                    } else {
                        viewModel.selectAll()
                    }
                }
            } label: {
                Text(viewModel.allSelected ? "Deselect All" : "Select All")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.accent)
            }
        }
        .padding()
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }

    private func eventSection(title: String, events: [PlanEventItem], deEmphasized: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(DesignSystem.Typography.footnote)
                .foregroundColor(Color.Lazyflow.textTertiary)
                .textCase(.uppercase)
                .padding(.leading, DesignSystem.Spacing.xs)

            VStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(events) { event in
                    eventRow(event, deEmphasized: deEmphasized)
                }
            }
        }
    }

    private func eventRow(_ event: PlanEventItem, deEmphasized: Bool) -> some View {
        Button {
            withAnimation(DesignSystem.Animation.quick) {
                viewModel.toggleSelection(for: event.id)
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Selection indicator
                ZStack {
                    Circle()
                        .strokeBorder(
                            event.isSelected ? Color.Lazyflow.accent : Color.Lazyflow.textTertiary.opacity(0.5),
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)

                    if event.isSelected {
                        Circle()
                            .fill(Color.Lazyflow.accent)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // Calendar color dot
                if let cgColor = event.calendarColor {
                    Circle()
                        .fill(Color(cgColor: cgColor))
                        .frame(width: 8, height: 8)
                }

                // Event details
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text(event.title)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(
                            deEmphasized
                                ? Color.Lazyflow.textSecondary
                                : Color.Lazyflow.textPrimary
                        )
                        .lineLimit(2)

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text(event.formattedTimeRange)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textSecondary)

                        if !event.isAllDay {
                            Text(event.formattedDuration)
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textTertiary)
                        }
                    }

                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                            Text(location)
                                .font(DesignSystem.Typography.caption1)
                                .lineLimit(1)
                        }
                        .foregroundColor(Color.Lazyflow.textTertiary)
                    }
                }

                Spacer()
            }
            .padding()
            .background(Color.adaptiveSurface)
            .cornerRadius(DesignSystem.CornerRadius.large)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .stroke(
                        event.isSelected ? Color.Lazyflow.accent.opacity(0.4) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(event.title), \(event.formattedTimeRange)")
        .accessibilityAddTraits(event.isSelected ? .isSelected : [])
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Divider()

            HStack(spacing: DesignSystem.Spacing.md) {
                Button {
                    dismiss()
                } label: {
                    Text("Skip")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: DesignSystem.TouchTarget.comfortable)
                }

                Button {
                    viewModel.createTasks()
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Start My Day")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.noneSelected)
            }
            .padding(.horizontal)
            .padding(.bottom, DesignSystem.Spacing.sm)
        }
        .background(Color.adaptiveSurface)
    }

    // MARK: - Creating State

    private var creatingState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Setting up your day...")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Completion State

    private func completionState(_ result: PlanYourDayResult) -> some View {
        VStack(spacing: DesignSystem.Spacing.xxl) {
            Spacer()

            // Celebration icon
            ZStack {
                Circle()
                    .fill(Color.Lazyflow.accent.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(Color.Lazyflow.accent)
            }

            VStack(spacing: DesignSystem.Spacing.md) {
                Text("You're All Set!")
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(Color.Lazyflow.textPrimary)

                Text(result.summaryText)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(Color.Lazyflow.textSecondary)

                if result.totalEstimatedMinutes > 0 {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "clock")
                            .font(DesignSystem.Typography.caption1)
                        Text("Estimated: \(result.formattedTotalTime)")
                            .font(DesignSystem.Typography.subheadline)
                    }
                    .foregroundColor(Color.Lazyflow.textTertiary)
                }
            }

            Spacer()

            Button("Let's Go!") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal)
                .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    PlanYourDayView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}

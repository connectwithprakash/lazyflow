import SwiftUI
import EventKit

struct CalendarView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = CalendarViewModel()
    @StateObject private var taskService = TaskService.shared
    @State private var selectedDate = Date()
    @State private var currentWeekStart = Calendar.current.startOfWeek(for: Date())
    @State private var viewMode: CalendarViewMode = .week
    @State private var showingTimeBlockSheet = false
    @State private var pendingTask: Task?
    @State private var pendingDropTime: Date?
    @State private var eventToConvert: CalendarEvent?
    @State private var showingDeniedAlert = false
    @State private var undoAction: UndoAction?

    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad: No NavigationStack (provided by split view)
            calendarContent
                .navigationTitle("Calendar")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { todayToolbar }
                .task { await viewModel.requestAccessIfNeeded() }
                .sheet(isPresented: $showingTimeBlockSheet) {
                    if let task = pendingTask, let dropTime = pendingDropTime {
                        TimeBlockSheet(task: task, startTime: dropTime) { startTime, duration in
                            createTimeBlock(for: task, startTime: startTime, duration: duration)
                        }
                    }
                }
                .sheet(item: $eventToConvert) { event in
                    CreateTaskFromEventSheet(event: event) { task in
                        createTaskFromEvent(task)
                    }
                }
                .alert("Calendar Access Denied", isPresented: $showingDeniedAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                } message: {
                    Text("Calendar access was previously denied. Please enable it in Settings to use this feature.")
                }
        } else {
            // iPhone: Full NavigationStack
            NavigationStack {
                calendarContent
                    .navigationTitle("Calendar")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { todayToolbar }
                    .task { await viewModel.requestAccessIfNeeded() }
                    .sheet(isPresented: $showingTimeBlockSheet) {
                        if let task = pendingTask, let dropTime = pendingDropTime {
                            TimeBlockSheet(task: task, startTime: dropTime) { startTime, duration in
                                createTimeBlock(for: task, startTime: startTime, duration: duration)
                            }
                        }
                    }
                    .sheet(item: $eventToConvert) { event in
                        CreateTaskFromEventSheet(event: event) { task in
                            createTaskFromEvent(task)
                        }
                    }
                    .alert("Calendar Access Denied", isPresented: $showingDeniedAlert) {
                        Button("Cancel", role: .cancel) { }
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    } message: {
                        Text("Calendar access was previously denied. Please enable it in Settings to use this feature.")
                    }
            }
        }
    }

    @ToolbarContentBuilder
    private var todayToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                withAnimation(.smooth(duration: 0.35)) {
                    let today = Date()
                    selectedDate = today
                    currentWeekStart = Calendar.current.startOfWeek(for: today)
                }
            } label: {
                Text("Today")
                    .font(DesignSystem.Typography.callout)
            }
        }
    }

    private var calendarContent: some View {
        VStack(spacing: 0) {
                // Calendar access banner if needed
                if !viewModel.hasAccess {
                    calendarAccessBanner
                }

                // View mode picker
                Picker("View", selection: $viewMode) {
                    Text("Day").tag(CalendarViewMode.day)
                    Text("Week").tag(CalendarViewMode.week)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, DesignSystem.Spacing.sm)

                // Date navigation
                dateNavigationBar

                // Calendar content
                if viewModel.hasAccess {
                    switch viewMode {
                    case .day:
                        DayView(
                            currentDate: $selectedDate,
                            eventsProvider: { viewModel.events(for: $0) },
                            onTaskDropped: { task, time in
                                pendingTask = task
                                pendingDropTime = time
                                showingTimeBlockSheet = true
                            },
                            onCreateTaskFromEvent: { event in
                                eventToConvert = event
                            },
                            onCreateTaskInstantly: { event in
                                createTaskInstantlyFromEvent(event)
                            }
                        )
                    case .week:
                        WeekView(
                            currentWeekStart: $currentWeekStart,
                            eventsProvider: { viewModel.eventsForWeek(containing: $0) },
                            onDateSelected: { selectedDate = $0 },
                            onTaskDropped: { task, date in
                                pendingTask = task
                                pendingDropTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date)
                                showingTimeBlockSheet = true
                            },
                            onCreateTaskFromEvent: { event in
                                eventToConvert = event
                            },
                            onCreateTaskInstantly: { event in
                                createTaskInstantlyFromEvent(event)
                            }
                        )
                        .onChange(of: currentWeekStart) { _, newValue in
                            selectedDate = newValue
                        }
                    }
                } else {
                    noAccessView
                }
            }
            .errorToast(message: $viewModel.errorMessage)
            .undoToast(action: $undoAction) { action in
                // Undo: delete the created task
                taskService.deleteTask(action.task)
            }
    }

    // MARK: - Sheets Modifier

    @ViewBuilder
    var calendarSheets: some View {
        self
            .sheet(isPresented: $showingTimeBlockSheet) {
                if let task = pendingTask, let dropTime = pendingDropTime {
                    TimeBlockSheet(
                        task: task,
                        startTime: dropTime,
                        onConfirm: { startTime, duration in
                            createTimeBlock(for: task, startTime: startTime, duration: duration)
                        }
                    )
                }
            }
            .sheet(item: $eventToConvert) { event in
                CreateTaskFromEventSheet(
                    event: event,
                    onConfirm: { task in
                        createTaskFromEvent(task)
                    }
                )
            }
    }

    private func createTaskFromEvent(_ task: Task) {
        // Save the task using TaskService
        taskService.createTask(
            title: task.title,
            notes: task.notes,
            dueDate: task.dueDate,
            dueTime: task.dueTime,
            reminderDate: task.reminderDate,
            priority: task.priority,
            listID: task.listID,
            estimatedDuration: task.estimatedDuration,
            recurringRule: task.recurringRule
        )
    }

    private func createTaskInstantlyFromEvent(_ event: CalendarEvent) {
        // Create task with smart defaults
        let task = taskService.createTask(
            title: event.title,
            dueDate: event.startDate,
            dueTime: event.startDate,
            priority: .medium,
            estimatedDuration: event.duration
        )

        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Show toast with undo option
        undoAction = .createdFromEvent(task)
    }

    private func createTimeBlock(for task: Task, startTime: Date, duration: TimeInterval) {
        do {
            _ = try CalendarService.shared.createTimeBlock(for: task, startDate: startTime, duration: duration)
            viewModel.loadEvents()
        } catch {
            print("Failed to create time block: \(error)")
        }
    }

    private var calendarAccessBanner: some View {
        HStack {
            Image(systemName: "calendar.badge.exclamationmark")
                .foregroundStyle(.orange)

            Text("Calendar access needed")
                .font(DesignSystem.Typography.subheadline)

            Spacer()

            Button("Enable") {
                if viewModel.isDenied {
                    showingDeniedAlert = true
                } else {
                    _Concurrency.Task {
                        await viewModel.requestAccess()
                    }
                }
            }
            .font(DesignSystem.Typography.subheadline)
            .fontWeight(.semibold)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }

    private var dateNavigationBar: some View {
        HStack {
            Button {
                navigateDate(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            Text(dateTitle)
                .font(DesignSystem.Typography.headline)

            Spacer()

            Button {
                navigateDate(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    private var dateTitle: String {
        let formatter = DateFormatter()

        switch viewMode {
        case .day:
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: selectedDate)
        case .week:
            let weekEnd = Calendar.current.date(byAdding: .day, value: 6, to: currentWeekStart) ?? currentWeekStart
            formatter.dateFormat = "MMM d"
            let startStr = formatter.string(from: currentWeekStart)
            let endStr = formatter.string(from: weekEnd)
            return "\(startStr) - \(endStr)"
        }
    }

    private func navigateDate(by value: Int) {
        let calendar = Calendar.current
        withAnimation(.smooth(duration: 0.35)) {
            switch viewMode {
            case .day:
                selectedDate = calendar.date(byAdding: .day, value: value, to: selectedDate) ?? selectedDate
            case .week:
                currentWeekStart = calendar.date(byAdding: .weekOfYear, value: value, to: currentWeekStart) ?? currentWeekStart
            }
        }
    }

    private var noAccessView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            Image(systemName: "calendar")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Calendar Access Required")
                .font(DesignSystem.Typography.title2)

            Text(viewModel.isDenied
                ? "Calendar access was denied. Please enable it in Settings to view your events."
                : "Enable calendar access to view your events and schedule tasks as time blocks.")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)

            Button {
                if viewModel.isDenied {
                    showingDeniedAlert = true
                } else {
                    _Concurrency.Task {
                        await viewModel.requestAccess()
                    }
                }
            } label: {
                Text(viewModel.isDenied ? "Open Settings" : "Enable Calendar Access")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.Lazyflow.accent)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)

            Spacer()
        }
    }
}

// MARK: - View Mode

enum CalendarViewMode {
    case day
    case week
}

// MARK: - Day View

struct DayView: View {
    @Binding var currentDate: Date
    let eventsProvider: (Date) -> [CalendarEvent]
    var onTaskDropped: ((Task, Date) -> Void)?
    var onCreateTaskFromEvent: ((CalendarEvent) -> Void)?
    var onCreateTaskInstantly: ((CalendarEvent) -> Void)?

    private let calendar = Calendar.current
    @State private var scrollPosition: Date?
    @State private var isInitialized = false

    // Pre-generate dates: 1 year back and forward from today
    private var dates: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (-365...365).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today)
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(dates, id: \.self) { date in
                    DayContentView(
                        date: date,
                        events: eventsProvider(date),
                        onTaskDropped: onTaskDropped,
                        onCreateTaskFromEvent: onCreateTaskFromEvent,
                        onCreateTaskInstantly: onCreateTaskInstantly
                    )
                    .containerRelativeFrame(.horizontal, count: 1, span: 1, spacing: 0)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollPosition)
        .ignoresSafeArea(.container, edges: .horizontal)
        .onChange(of: scrollPosition) { _, newDate in
            if let newDate, isInitialized {
                currentDate = newDate
            }
        }
        .onChange(of: currentDate) { _, newDate in
            let normalizedDate = calendar.startOfDay(for: newDate)
            if scrollPosition != normalizedDate {
                withAnimation(.smooth(duration: 0.35)) {
                    scrollPosition = normalizedDate
                }
            }
        }
        .onAppear {
            if !isInitialized {
                scrollPosition = calendar.startOfDay(for: currentDate)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInitialized = true
                }
            }
        }
    }
}

struct DayContentView: View {
    let date: Date
    let events: [CalendarEvent]
    var onTaskDropped: ((Task, Date) -> Void)?
    var onCreateTaskFromEvent: ((CalendarEvent) -> Void)?
    var onCreateTaskInstantly: ((CalendarEvent) -> Void)?

    private let hourHeight: CGFloat = 60
    private let startHour = 0
    private let endHour = 24
    private let timeColumnWidth: CGFloat = 48
    @State private var isDraggingOver = false
    @State private var dragLocation: CGPoint = .zero
    @State private var hasScrolledToCurrentTime = false

    /// Current hour for initial scroll position
    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    /// Calculates column layout for overlapping events
    private var eventLayout: [(event: CalendarEvent, column: Int, totalColumns: Int)] {
        let timedEvents = events.filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        guard !timedEvents.isEmpty else { return [] }

        var columns: [[CalendarEvent]] = []
        var result: [(event: CalendarEvent, column: Int, totalColumns: Int)] = []

        for event in timedEvents {
            var assignedColumn: Int?
            for (index, column) in columns.enumerated() {
                let overlaps = column.contains { existing in
                    event.startDate < existing.endDate && event.endDate > existing.startDate
                }
                if !overlaps {
                    assignedColumn = index
                    columns[index].append(event)
                    break
                }
            }

            if assignedColumn == nil {
                assignedColumn = columns.count
                columns.append([event])
            }

            result.append((event: event, column: assignedColumn!, totalColumns: 0))
        }

        for i in 0..<result.count {
            let event = result[i].event
            var maxColumns = result[i].column + 1
            for j in 0..<result.count {
                let other = result[j].event
                if event.startDate < other.endDate && event.endDate > other.startDate {
                    maxColumns = max(maxColumns, result[j].column + 1)
                }
            }
            result[i].totalColumns = maxColumns
        }

        return result
    }

    private var allDayEvents: [CalendarEvent] {
        events.filter { $0.isAllDay }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // All-day events section
                    if !allDayEvents.isEmpty {
                        AllDayEventsSection(
                            events: allDayEvents,
                            onCreateTaskFromEvent: onCreateTaskFromEvent
                        )
                    }

                    // Time grid with timed events
                    ZStack(alignment: .topLeading) {
                        // Hour grid - each row has time label + line
                        VStack(spacing: 0) {
                            ForEach(startHour..<endHour, id: \.self) { hour in
                                HourRow(hour: hour, isHighlighted: isHourHighlighted(hour))
                                    .frame(height: hourHeight, alignment: .top)
                                    .id(hour)
                            }
                        }

                        // Events overlay
                        eventsOverlay

                        // Drop indicator
                        if isDraggingOver {
                            dropIndicator
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
            .onAppear {
                // Scroll to current time (show 2 hours before current hour)
                if !hasScrolledToCurrentTime {
                    let targetHour = max(0, currentHour - 2)
                    proxy.scrollTo(targetHour, anchor: .top)
                    hasScrolledToCurrentTime = true
                }
            }
        }
        .dropDestination(for: Task.self) { tasks, location in
            guard let task = tasks.first else { return false }
            let dropTime = calculateDropTime(from: location)
            onTaskDropped?(task, dropTime)
            isDraggingOver = false
            return true
        } isTargeted: { isTargeted in
            isDraggingOver = isTargeted
        }
    }

    @ViewBuilder
    private var eventsOverlay: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - timeColumnWidth - DesignSystem.Spacing.sm

            ForEach(eventLayout, id: \.event.id) { layout in
                let columnWidth = availableWidth / CGFloat(layout.totalColumns)
                let xOffset = timeColumnWidth + CGFloat(layout.column) * columnWidth

                EventBlockView(
                    event: layout.event,
                    hourHeight: hourHeight,
                    startHour: startHour,
                    width: columnWidth - 2,
                    xOffset: xOffset,
                    onSwipeToCreateTask: {
                        onCreateTaskInstantly?(layout.event)
                    }
                )
                .contextMenu {
                    Button {
                        onCreateTaskFromEvent?(layout.event)
                    } label: {
                        Label("Create Task", systemImage: "checkmark.circle.badge.plus")
                    }
                }
            }

        }
        .frame(height: CGFloat(endHour - startHour) * hourHeight)
    }

    private func isHourHighlighted(_ hour: Int) -> Bool {
        guard isDraggingOver else { return false }
        let dragHour = startHour + Int(dragLocation.y / hourHeight)
        return hour == dragHour
    }

    private func calculateDropTime(from location: CGPoint) -> Date {
        let adjustedY = location.y - 50 // Account for time label padding
        let hourOffset = adjustedY / hourHeight
        let hour = startHour + Int(hourOffset)
        let minute = Int((hourOffset.truncatingRemainder(dividingBy: 1)) * 60)

        // Round to nearest 15 minutes
        let roundedMinute = (minute / 15) * 15

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = min(max(hour, startHour), endHour - 1)
        components.minute = roundedMinute

        return calendar.date(from: components) ?? date
    }

    @ViewBuilder
    private var dropIndicator: some View {
        let yOffset = max(0, dragLocation.y - 50)
        Rectangle()
            .fill(Color.Lazyflow.accent.opacity(0.3))
            .frame(height: hourHeight)
            .overlay(
                Rectangle()
                    .fill(Color.Lazyflow.accent)
                    .frame(height: 2),
                alignment: .top
            )
            .offset(y: yOffset)
            .animation(.easeInOut(duration: 0.15), value: yOffset)
    }
}

struct HourRow: View {
    let hour: Int
    var isHighlighted: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Text(hourString)
                .font(DesignSystem.Typography.caption1)
                .foregroundStyle(isHighlighted ? Color.Lazyflow.accent : .secondary)
                .frame(width: 40, alignment: .trailing)

            Rectangle()
                .fill(isHighlighted ? Color.Lazyflow.accent : Color.gray.opacity(0.2))
                .frame(height: isHighlighted ? 2 : 1)
        }
        .background(isHighlighted ? Color.Lazyflow.accent.opacity(0.05) : .clear)
    }

    private var hourString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        guard let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) else {
            return "\(hour):00"
        }
        return formatter.string(from: date)
    }
}

// MARK: - All-Day Events Section

struct AllDayEventsSection: View {
    let events: [CalendarEvent]
    var onCreateTaskFromEvent: ((CalendarEvent) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            // Header row - matches HourRow layout
            HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                Text("All Day")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)

                // All-day events as horizontal scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(events) { event in
                            AllDayEventChip(event: event)
                                .contextMenu {
                                    Button {
                                        onCreateTaskFromEvent?(event)
                                    } label: {
                                        Label("Create Task", systemImage: "checkmark.circle.badge.plus")
                                    }
                                }
                        }
                    }
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(Color.adaptiveSurface.opacity(0.5))
    }
}

struct AllDayEventChip: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(eventColor)
                .frame(width: 4)

            Text(event.title)
                .font(DesignSystem.Typography.caption1)
                .fontWeight(.medium)
                .foregroundStyle(Color.Lazyflow.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(eventColor.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title), all day event")
        .accessibilityHint("Double tap to view event options")
    }

    private var eventColor: Color {
        if let cgColor = event.calendarColor {
            return Color(cgColor: cgColor)
        }
        return Color.Lazyflow.accent
    }
}

/// Event block view for Day view - positioned absolutely using offset
struct EventBlockView: View {
    let event: CalendarEvent
    let hourHeight: CGFloat
    let startHour: Int
    let width: CGFloat
    let xOffset: CGFloat
    var onSwipeToCreateTask: (() -> Void)?

    private var yOffset: CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: event.startDate)
        let minute = calendar.component(.minute, from: event.startDate)
        let hoursSinceStart = CGFloat(hour - startHour) + CGFloat(minute) / 60.0
        return hoursSinceStart * hourHeight
    }

    private var height: CGFloat {
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: event.startDate)
        let startMinute = calendar.component(.minute, from: event.startDate)
        let endHour = calendar.component(.hour, from: event.endDate)
        let endMinute = calendar.component(.minute, from: event.endDate)

        let startPosition = CGFloat(startHour - self.startHour) + CGFloat(startMinute) / 60.0
        var endPosition = CGFloat(endHour - self.startHour) + CGFloat(endMinute) / 60.0

        // Handle events that span midnight
        if endPosition < startPosition {
            endPosition += 24.0
        }

        let height = (endPosition - startPosition) * hourHeight
        return max(height, 24)
    }

    private var eventColor: Color {
        if let cgColor = event.calendarColor {
            return Color(cgColor: cgColor)
        }
        return Color.Lazyflow.accent
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Color indicator strip
            RoundedRectangle(cornerRadius: 2)
                .fill(eventColor)
                .frame(width: 4, height: height)

            // Event content
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(DesignSystem.Typography.caption1)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(height > 40 ? 2 : 1)

                if height > 35 {
                    Text(event.formattedTimeRange)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                }

                if height > 55, let location = event.location, !location.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 8))
                        Text(location)
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.xs)
            .padding(.vertical, 4)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(eventColor.opacity(0.85))
                .shadow(color: eventColor.opacity(0.3), radius: 2, x: 0, y: 1)
        )
        .contentShape(Rectangle())
        .offset(x: xOffset, y: yOffset)
        .onTapGesture(count: 2) {
            // Double tap to create task instantly
            onSwipeToCreateTask?()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title), \(event.formattedTimeRange)")
        .accessibilityHint("Double tap to create task instantly, or long press for options")
        .accessibilityAction(named: "Create Task") {
            onSwipeToCreateTask?()
        }
    }
}

// MARK: - Week View

struct WeekView: View {
    @Binding var currentWeekStart: Date
    let eventsProvider: (Date) -> [Date: [CalendarEvent]]
    let onDateSelected: (Date) -> Void
    var onTaskDropped: ((Task, Date) -> Void)?
    var onCreateTaskFromEvent: ((CalendarEvent) -> Void)?
    var onCreateTaskInstantly: ((CalendarEvent) -> Void)?

    private let calendar = Calendar.current
    @State private var highlightedDay: Int?
    @State private var scrollPosition: Date?
    @State private var isInitialized = false

    // Pre-generate week start dates: ~1 year back and forward
    // Using week starts to ensure consistent alignment
    private var weekStarts: [Date] {
        let today = Date()
        // Get the start of the current week
        let currentWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        return (-52...52).compactMap { offset in
            calendar.date(byAdding: .weekOfYear, value: offset, to: currentWeek)
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 0) {
                ForEach(weekStarts, id: \.self) { weekStart in
                    WeekContentView(
                        startDate: weekStart,
                        events: eventsProvider(weekStart),
                        highlightedDay: scrollPosition == weekStart ? highlightedDay : nil,
                        onDateSelected: onDateSelected,
                        onTaskDropped: onTaskDropped,
                        onCreateTaskFromEvent: onCreateTaskFromEvent,
                        onCreateTaskInstantly: onCreateTaskInstantly,
                        onHighlightChanged: { highlightedDay = $0 }
                    )
                    .containerRelativeFrame(.horizontal, count: 1, span: 1, spacing: 0)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollPosition)
        .onChange(of: scrollPosition) { _, newWeekStart in
            if let newWeekStart, isInitialized {
                currentWeekStart = newWeekStart
            }
        }
        .onChange(of: currentWeekStart) { _, newWeekStart in
            let normalizedWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: newWeekStart)) ?? newWeekStart
            if scrollPosition != normalizedWeek {
                withAnimation(.smooth(duration: 0.35)) {
                    scrollPosition = normalizedWeek
                }
            }
        }
        .onAppear {
            if !isInitialized {
                let normalizedWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentWeekStart)) ?? currentWeekStart
                scrollPosition = normalizedWeek
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInitialized = true
                }
            }
        }
    }
}

struct WeekContentView: View {
    let startDate: Date
    let events: [Date: [CalendarEvent]]
    let highlightedDay: Int?
    let onDateSelected: (Date) -> Void
    var onTaskDropped: ((Task, Date) -> Void)?
    var onCreateTaskFromEvent: ((CalendarEvent) -> Void)?
    var onCreateTaskInstantly: ((CalendarEvent) -> Void)?
    var onHighlightChanged: ((Int?) -> Void)?

    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 50
    private let startHour = 0
    private let endHour = 24
    private let timeColumnWidth: CGFloat = 40

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Day headers with time column spacer
                    HStack(spacing: 0) {
                        // Spacer for time column
                        Color.clear
                            .frame(width: timeColumnWidth)

                        ForEach(0..<7, id: \.self) { dayOffset in
                            if let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) {
                                DayHeader(date: date, isToday: calendar.isDateInToday(date))
                                    .frame(maxWidth: .infinity)
                                    .onTapGesture {
                                        onDateSelected(date)
                                    }
                            }
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.sm)

                    Divider()

                    // Time grid with day columns
                    HStack(alignment: .top, spacing: 0) {
                    // Time column
                    VStack(spacing: 0) {
                        ForEach(startHour..<endHour, id: \.self) { hour in
                            HStack {
                                Text(hourString(for: hour))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .frame(width: timeColumnWidth - 4, alignment: .trailing)
                            }
                            .frame(height: hourHeight, alignment: .top)
                        }
                    }

                    // Day columns with time grid
                    ForEach(0..<7, id: \.self) { dayOffset in
                        if let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) {
                            let dayEvents = events[calendar.startOfDay(for: date)] ?? []

                            WeekDayColumn(
                                date: date,
                                events: dayEvents,
                                hourHeight: hourHeight,
                                startHour: startHour,
                                endHour: endHour,
                                isDropTarget: highlightedDay == dayOffset,
                                onCreateTaskFromEvent: onCreateTaskFromEvent,
                                onCreateTaskInstantly: onCreateTaskInstantly
                            )
                            .frame(maxWidth: .infinity)
                            .dropDestination(for: Task.self) { tasks, location in
                                guard let task = tasks.first else { return false }
                                let dropTime = calculateDropTime(from: location, for: date)
                                onTaskDropped?(task, dropTime)
                                onHighlightChanged?(nil)
                                return true
                            } isTargeted: { isTargeted in
                                onHighlightChanged?(isTargeted ? dayOffset : nil)
                            }
                        }
                    }
                    }
                }
            }
        }
    }

    private func hourString(for hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        guard let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) else {
            return "\(hour)"
        }
        return formatter.string(from: date)
    }

    private func calculateDropTime(from location: CGPoint, for date: Date) -> Date {
        let hourOffset = location.y / hourHeight
        let hour = startHour + Int(hourOffset)
        let minute = Int((hourOffset.truncatingRemainder(dividingBy: 1)) * 60)
        let roundedMinute = (minute / 15) * 15

        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = min(max(hour, startHour), endHour - 1)
        components.minute = roundedMinute

        return calendar.date(from: components) ?? date
    }
}

// MARK: - Week Day Column with Time Grid

struct WeekDayColumn: View {
    let date: Date
    let events: [CalendarEvent]
    let hourHeight: CGFloat
    let startHour: Int
    let endHour: Int
    var isDropTarget: Bool = false
    var onCreateTaskFromEvent: ((CalendarEvent) -> Void)?
    var onCreateTaskInstantly: ((CalendarEvent) -> Void)?

    private var timedEvents: [CalendarEvent] {
        events.filter { !$0.isAllDay }
    }

    private var allDayEvents: [CalendarEvent] {
        events.filter { $0.isAllDay }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Hour grid lines
            VStack(spacing: 0) {
                ForEach(startHour..<endHour, id: \.self) { _ in
                    VStack(spacing: 0) {
                        Divider()
                        Spacer()
                    }
                    .frame(height: hourHeight)
                }
            }

            // Events overlay
            ForEach(timedEvents) { event in
                WeekEventBlock(
                    event: event,
                    hourHeight: hourHeight,
                    startHour: startHour,
                    onSwipeToCreateTask: {
                        onCreateTaskInstantly?(event)
                    }
                )
                .contextMenu {
                    Button {
                        onCreateTaskFromEvent?(event)
                    } label: {
                        Label("Create Task", systemImage: "checkmark.circle.badge.plus")
                    }
                }
            }

            // Drop target indicator
            if isDropTarget {
                Rectangle()
                    .fill(Color.Lazyflow.accent.opacity(0.15))
                    .overlay(
                        Rectangle()
                            .stroke(Color.Lazyflow.accent, lineWidth: 2)
                    )
            }
        }
        .frame(height: CGFloat(endHour - startHour) * hourHeight)
    }
}

struct WeekEventBlock: View {
    let event: CalendarEvent
    let hourHeight: CGFloat
    let startHour: Int
    var onSwipeToCreateTask: (() -> Void)?

    private var yOffset: CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: event.startDate)
        let minute = calendar.component(.minute, from: event.startDate)
        let hoursSinceStart = CGFloat(hour - startHour) + CGFloat(minute) / 60.0
        return hoursSinceStart * hourHeight
    }

    private var height: CGFloat {
        let durationHours = event.duration / 3600
        return max(CGFloat(durationHours) * hourHeight, 20)
    }

    private var eventColor: Color {
        if let cgColor = event.calendarColor {
            return Color(cgColor: cgColor)
        }
        return Color.Lazyflow.accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(event.title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(height > 30 ? 2 : 1)

            if height > 35 {
                Text(formattedTime)
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(eventColor.opacity(0.9))
        )
        .contentShape(Rectangle())
        .padding(.horizontal, 1)
        .offset(y: yOffset)
        .onTapGesture(count: 2) {
            // Double tap to create task instantly
            onSwipeToCreateTask?()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title), \(formattedTime)")
        .accessibilityHint("Double tap to create task instantly, or long press for options")
        .accessibilityAction(named: "Create Task") {
            onSwipeToCreateTask?()
        }
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: event.startDate)
    }
}

struct DayHeader: View {
    let date: Date
    let isToday: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(dayOfWeek)
                .font(DesignSystem.Typography.caption1)
                .foregroundStyle(.secondary)

            Text(dayNumber)
                .font(DesignSystem.Typography.title3)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isToday ? Color.Lazyflow.accent : .primary)
                .frame(width: 32, height: 32)
                .background(isToday ? Color.Lazyflow.accent.opacity(0.1) : .clear)
                .clipShape(Circle())
        }
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

// MARK: - Time Block Sheet

struct TimeBlockSheet: View {
    let task: Task
    let startTime: Date
    let onConfirm: (Date, TimeInterval) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedStartTime: Date
    @State private var selectedDuration: TimeInterval

    private let durations: [(String, TimeInterval)] = [
        ("15 min", 900),
        ("30 min", 1800),
        ("45 min", 2700),
        ("1 hour", 3600),
        ("1.5 hours", 5400),
        ("2 hours", 7200),
        ("3 hours", 10800),
        ("4 hours", 14400)
    ]

    init(task: Task, startTime: Date, onConfirm: @escaping (Date, TimeInterval) -> Void) {
        self.task = task
        self.startTime = startTime
        self.onConfirm = onConfirm
        _selectedStartTime = State(initialValue: startTime)
        _selectedDuration = State(initialValue: task.estimatedDuration ?? 3600)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Task info section
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(Color.Lazyflow.accent)
                        Text(task.title)
                            .font(DesignSystem.Typography.headline)
                    }

                    if let notes = task.notes {
                        Text(notes)
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Task")
                }

                // Time selection section
                Section {
                    DatePicker(
                        "Start Time",
                        selection: $selectedStartTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    Picker("Duration", selection: $selectedDuration) {
                        ForEach(durations, id: \.1) { duration in
                            Text(duration.0).tag(duration.1)
                        }
                    }

                    // End time display
                    HStack {
                        Text("End Time")
                        Spacer()
                        Text(endTimeFormatted)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Schedule")
                }

                // Preview section
                Section {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(Color.Lazyflow.accent)
                            Text(dateFormatted)
                                .font(DesignSystem.Typography.subheadline)
                        }

                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(Color.Lazyflow.accent)
                            Text(timeRangeFormatted)
                                .font(DesignSystem.Typography.subheadline)
                        }
                    }
                } header: {
                    Text("Time Block Preview")
                }
            }
            .navigationTitle("Schedule Time Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onConfirm(selectedStartTime, selectedDuration)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var endTime: Date {
        selectedStartTime.addingTimeInterval(selectedDuration)
    }

    private var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: selectedStartTime)
    }

    private var endTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: endTime)
    }

    private var timeRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: selectedStartTime)) - \(formatter.string(from: endTime))"
    }
}

// MARK: - Create Task From Event Sheet

struct CreateTaskFromEventSheet: View {
    let event: CalendarEvent
    let onConfirm: (Task) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var notes: String
    @State private var selectedPriority: Priority = .medium
    @State private var dueDate: Date
    @State private var includeDueDate: Bool = true

    init(event: CalendarEvent, onConfirm: @escaping (Task) -> Void) {
        self.event = event
        self.onConfirm = onConfirm
        _title = State(initialValue: event.title)
        _notes = State(initialValue: "")
        _dueDate = State(initialValue: event.startDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Event info section
                Section {
                    HStack {
                        Circle()
                            .fill(eventColor)
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(DesignSystem.Typography.headline)
                            Text(event.formattedTimeRange)
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("From Event")
                }

                // Task details section
                Section {
                    TextField("Task Title", text: $title)
                        .font(DesignSystem.Typography.body)

                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .font(DesignSystem.Typography.body)
                        .lineLimit(3...6)
                } header: {
                    Text("Task Details")
                }

                // Priority section
                Section {
                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(Priority.allCases) { priority in
                            HStack {
                                Image(systemName: priority.iconName)
                                    .foregroundColor(priority.color)
                                Text(priority.displayName)
                            }
                            .tag(priority)
                        }
                    }
                } header: {
                    Text("Priority")
                }

                // Due date section
                Section {
                    Toggle("Set Due Date", isOn: $includeDueDate)

                    if includeDueDate {
                        DatePicker(
                            "Due Date",
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                } header: {
                    Text("Due Date")
                }

                // Preview section
                Section {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Image(systemName: selectedPriority.iconName)
                                .foregroundColor(selectedPriority.color)
                            Text(title.isEmpty ? "Untitled Task" : title)
                                .font(DesignSystem.Typography.headline)
                        }

                        if !notes.isEmpty {
                            Text(notes)
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }

                        if includeDueDate {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(Color.Lazyflow.accent)
                                Text(dueDateFormatted)
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Task Preview")
                }
            }
            .navigationTitle("Create Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let task = Task(
                            title: title.isEmpty ? event.title : title,
                            notes: notes.isEmpty ? nil : notes,
                            dueDate: includeDueDate ? dueDate : nil,
                            priority: selectedPriority,
                            linkedEventID: event.id,
                            estimatedDuration: event.duration
                        )
                        onConfirm(task)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty && event.title.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var eventColor: Color {
        if let cgColor = event.calendarColor {
            return Color(cgColor: cgColor)
        }
        return Color.Lazyflow.accent
    }

    private var dueDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dueDate)
    }
}

// MARK: - Calendar Extension

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }
}

// MARK: - Preview

#Preview {
    CalendarView()
}

#Preview("Time Block Sheet") {
    TimeBlockSheet(
        task: Task.sample,
        startTime: Date(),
        onConfirm: { _, _ in }
    )
}

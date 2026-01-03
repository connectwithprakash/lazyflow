import SwiftUI
import EventKit

struct CalendarView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = CalendarViewModel()
    @StateObject private var taskService = TaskService()
    @State private var selectedDate = Date()
    @State private var currentWeekStart = Calendar.current.startOfWeek(for: Date())
    @State private var viewMode: CalendarViewMode = .week
    @State private var showingTimeBlockSheet = false
    @State private var pendingTask: Task?
    @State private var pendingDropTime: Date?
    @State private var eventToConvert: CalendarEvent?
    @State private var showingDeniedAlert = false

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
                selectedDate = Date()
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
        switch viewMode {
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: value, to: selectedDate) ?? selectedDate
        case .week:
            currentWeekStart = calendar.date(byAdding: .weekOfYear, value: value, to: currentWeekStart) ?? currentWeekStart
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
                    .background(Color.Taskweave.accent)
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

    private let calendar = Calendar.current
    @State private var scrollPosition: Date?
    @State private var isInitialized = false

    // Pre-generate dates: 1 year back and forward from today
    // This is the standard approach - pre-generate a reasonable range
    // rather than trying to dynamically manage scroll position
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
                        onCreateTaskFromEvent: onCreateTaskFromEvent
                    )
                    .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollPosition)
        .onChange(of: scrollPosition) { _, newDate in
            // Update currentDate when user scrolls
            if let newDate, isInitialized {
                currentDate = newDate
            }
        }
        .onChange(of: currentDate) { _, newDate in
            // Respond to external changes (chevron buttons, "Today" button)
            let normalizedDate = calendar.startOfDay(for: newDate)
            if scrollPosition != normalizedDate {
                scrollPosition = normalizedDate
            }
        }
        .onAppear {
            // Set initial position without triggering onChange
            if !isInitialized {
                scrollPosition = calendar.startOfDay(for: currentDate)
                // Delay setting initialized to avoid initial onChange trigger
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

    private let hourHeight: CGFloat = 60
    private let startHour = 6
    private let endHour = 22
    @State private var isDraggingOver = false
    @State private var dragLocation: CGPoint = .zero

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // Hour grid
                    VStack(spacing: 0) {
                        ForEach(startHour..<endHour, id: \.self) { hour in
                            HourRow(hour: hour, isHighlighted: isHourHighlighted(hour))
                                .frame(height: hourHeight)
                        }
                    }

                    // Events overlay
                    ForEach(events) { event in
                        if !event.isAllDay {
                            EventBlock(event: event, hourHeight: hourHeight, startHour: startHour)
                                .contextMenu {
                                    Button {
                                        onCreateTaskFromEvent?(event)
                                    } label: {
                                        Label("Create Task", systemImage: "checkmark.circle.badge.plus")
                                    }
                                }
                        }
                    }

                    // Drop indicator
                    if isDraggingOver {
                        dropIndicator
                    }
                }
                .padding(.leading, 50) // Space for time labels
            }
            .dropDestination(for: Task.self) { tasks, location in
                guard let task = tasks.first else { return false }
                let dropTime = calculateDropTime(from: location, in: geometry)
                onTaskDropped?(task, dropTime)
                isDraggingOver = false
                return true
            } isTargeted: { isTargeted in
                isDraggingOver = isTargeted
            }
        }
    }

    private func isHourHighlighted(_ hour: Int) -> Bool {
        guard isDraggingOver else { return false }
        let dragHour = startHour + Int(dragLocation.y / hourHeight)
        return hour == dragHour
    }

    private func calculateDropTime(from location: CGPoint, in geometry: GeometryProxy) -> Date {
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
            .fill(Color.Taskweave.accent.opacity(0.3))
            .frame(height: hourHeight)
            .overlay(
                Rectangle()
                    .fill(Color.Taskweave.accent)
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
                .foregroundStyle(isHighlighted ? Color.Taskweave.accent : .secondary)
                .frame(width: 40, alignment: .trailing)

            Rectangle()
                .fill(isHighlighted ? Color.Taskweave.accent : Color.gray.opacity(0.2))
                .frame(height: isHighlighted ? 2 : 1)
        }
        .background(isHighlighted ? Color.Taskweave.accent.opacity(0.05) : .clear)
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

struct EventBlock: View {
    let event: CalendarEvent
    let hourHeight: CGFloat
    let startHour: Int

    var body: some View {
        let yOffset = calculateYOffset()
        let height = calculateHeight()

        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
            .fill(eventColor.opacity(0.8))
            .frame(height: max(height, 20))
            .overlay(
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(DesignSystem.Typography.caption1)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if height > 30 {
                        Text(event.formattedTimeRange)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, 4),
                alignment: .topLeading
            )
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .offset(y: yOffset)
    }

    private func calculateYOffset() -> CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: event.startDate)
        let minute = calendar.component(.minute, from: event.startDate)
        let hoursSinceStart = CGFloat(hour - startHour) + CGFloat(minute) / 60.0
        return hoursSinceStart * hourHeight
    }

    private func calculateHeight() -> CGFloat {
        let durationHours = event.duration / 3600
        return CGFloat(durationHours) * hourHeight
    }

    private var eventColor: Color {
        if let cgColor = event.calendarColor {
            return Color(cgColor: cgColor)
        }
        return Color.Taskweave.accent
    }
}

// MARK: - Week View

struct WeekView: View {
    @Binding var currentWeekStart: Date
    let eventsProvider: (Date) -> [Date: [CalendarEvent]]
    let onDateSelected: (Date) -> Void
    var onTaskDropped: ((Task, Date) -> Void)?
    var onCreateTaskFromEvent: ((CalendarEvent) -> Void)?

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
            LazyHStack(spacing: 0) {
                ForEach(weekStarts, id: \.self) { weekStart in
                    WeekContentView(
                        startDate: weekStart,
                        events: eventsProvider(weekStart),
                        highlightedDay: scrollPosition == weekStart ? highlightedDay : nil,
                        onDateSelected: onDateSelected,
                        onTaskDropped: onTaskDropped,
                        onCreateTaskFromEvent: onCreateTaskFromEvent,
                        onHighlightChanged: { highlightedDay = $0 }
                    )
                    .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollPosition)
        .onChange(of: scrollPosition) { _, newWeekStart in
            // Update currentWeekStart when user scrolls
            if let newWeekStart, isInitialized {
                currentWeekStart = newWeekStart
            }
        }
        .onChange(of: currentWeekStart) { _, newWeekStart in
            // Respond to external changes (chevron buttons, "Today" button)
            let normalizedWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: newWeekStart)) ?? newWeekStart
            if scrollPosition != normalizedWeek {
                scrollPosition = normalizedWeek
            }
        }
        .onAppear {
            // Set initial position without triggering onChange
            if !isInitialized {
                let normalizedWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentWeekStart)) ?? currentWeekStart
                scrollPosition = normalizedWeek
                // Delay setting initialized to avoid initial onChange trigger
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
    var onHighlightChanged: ((Int?) -> Void)?

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            // Day headers
            HStack(spacing: 0) {
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

            // Day columns with events
            ScrollView {
                HStack(alignment: .top, spacing: 1) {
                    ForEach(0..<7, id: \.self) { dayOffset in
                        if let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) {
                            let dayEvents = events[calendar.startOfDay(for: date)] ?? []

                            DayColumn(
                                date: date,
                                events: dayEvents,
                                isDropTarget: highlightedDay == dayOffset,
                                onCreateTaskFromEvent: onCreateTaskFromEvent
                            )
                            .frame(maxWidth: .infinity)
                            .dropDestination(for: Task.self) { tasks, _ in
                                guard let task = tasks.first else { return false }
                                onTaskDropped?(task, date)
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
                .foregroundStyle(isToday ? Color.Taskweave.accent : .primary)
                .frame(width: 32, height: 32)
                .background(isToday ? Color.Taskweave.accent.opacity(0.1) : .clear)
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

struct DayColumn: View {
    let date: Date
    let events: [CalendarEvent]
    var isDropTarget: Bool = false
    var onCreateTaskFromEvent: ((CalendarEvent) -> Void)?

    private var maxEventsToShow: Int { 4 }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(events.prefix(maxEventsToShow)) { event in
                CompactEventView(event: event)
                    .contextMenu {
                        Button {
                            onCreateTaskFromEvent?(event)
                        } label: {
                            Label("Create Task", systemImage: "checkmark.circle.badge.plus")
                        }
                    }
            }

            if events.count > maxEventsToShow {
                Text("+\(events.count - maxEventsToShow)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            }

            if isDropTarget {
                HStack(spacing: 2) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 10))
                    Text("Drop")
                        .font(.system(size: 9))
                }
                .foregroundColor(Color.Taskweave.accent)
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .frame(minHeight: 120)
        .background(isDropTarget ? Color.Taskweave.accent.opacity(0.1) : .clear)
        .cornerRadius(DesignSystem.CornerRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .stroke(isDropTarget ? Color.Taskweave.accent : .clear, lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.15), value: isDropTarget)
    }
}

struct CompactEventView: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(eventColor)
                .frame(width: 6, height: 6)

            Text(event.title)
                .font(DesignSystem.Typography.caption2)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private var eventColor: Color {
        if let cgColor = event.calendarColor {
            return Color(cgColor: cgColor)
        }
        return Color.Taskweave.accent
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
                            .foregroundColor(Color.Taskweave.accent)
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
                                .foregroundColor(Color.Taskweave.accent)
                            Text(dateFormatted)
                                .font(DesignSystem.Typography.subheadline)
                        }

                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(Color.Taskweave.accent)
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
                                    .foregroundColor(Color.Taskweave.accent)
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
        return Color.Taskweave.accent
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

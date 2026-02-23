import CoreData
import SwiftUI

/// Main content view with adaptive navigation
/// - iPad (regular size class): NavigationSplitView with sidebar
/// - iPhone (compact size class): TabView with bottom tabs
struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("hasShownICloudPrompt") private var hasShownICloudPrompt = false
    @State private var selectedTab: Tab? = .today
    @State private var activeSheet: SheetType?
    @State private var showICloudPrompt = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    // Navigation paths for hub internal routing (iPhone deep links)
    @State private var insightsNavigationPath = NavigationPath()
    @State private var profileNavigationPath = NavigationPath()

    // Focus Mode coordinator (persists active session across restarts)
    @StateObject private var focusCoordinator = FocusSessionCoordinator(
        taskService: TaskService.shared,
        prioritizationService: PrioritizationService.shared
    )

    /// Consolidated sheet types to avoid multiple .sheet conflicts
    enum SheetType: Identifiable {
        case search
        case addTask
        case dailySummary
        case morningBriefing

        var id: String {
            switch self {
            case .search: return "search"
            case .addTask: return "addTask"
            case .dailySummary: return "dailySummary"
            case .morningBriefing: return "morningBriefing"
            }
        }
    }

    enum Tab: String, CaseIterable, Identifiable {
        case today = "Today"
        case calendar = "Calendar"
        case upcoming = "Upcoming"
        case insights = "Insights"
        case me = "Me"
        // Keep these for iPad sidebar and deep linking
        case history = "History"
        case lists = "Lists"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .today: return "star.fill"
            case .calendar: return "calendar"
            case .upcoming: return "calendar.badge.clock"
            case .insights: return "chart.bar.xaxis"
            case .me: return "person.circle"
            case .history: return "clock.arrow.circlepath"
            case .lists: return "folder.fill"
            case .settings: return "gear"
            }
        }

        /// Tabs shown in iPhone tab bar
        static var iPhoneTabs: [Tab] {
            [.today, .calendar, .upcoming, .insights, .me]
        }
    }

    /// Destinations within Insights hub (for iPhone deep linking)
    enum InsightsDestination: Hashable {
        case history
    }

    /// Destinations within Profile/Me hub (for iPhone deep linking)
    enum ProfileDestination: Hashable {
        case lists
        case settings
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if horizontalSizeClass == .regular {
                    iPadNavigationView
                } else {
                    iPhoneTabView
                }
            }

            if focusCoordinator.shouldShowPill {
                ReturnToFocusPill()
                    .padding(.bottom, 60)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: focusCoordinator.shouldShowPill)
            }
        }
        .fullScreenCover(isPresented: $focusCoordinator.isFocusPresented) {
            FocusModeView()
                .environmentObject(focusCoordinator)
        }
        .environmentObject(focusCoordinator)
        .tint(Color.Lazyflow.accent)
        .preferredColorScheme(appearanceMode.colorScheme)
        .onChange(of: horizontalSizeClass) { _, newValue in
            // Normalize tab selection when transitioning to compact (iPhone) mode
            // iPad-only tabs need to be remapped to their hub equivalents
            if newValue == .compact {
                switch selectedTab {
                case .history:
                    selectedTab = .insights
                    insightsNavigationPath.append(InsightsDestination.history)
                case .lists:
                    selectedTab = .me
                    profileNavigationPath.append(ProfileDestination.lists)
                case .settings:
                    selectedTab = .me
                    profileNavigationPath.append(ProfileDestination.settings)
                default:
                    break
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .search:
                SearchView()
            case .addTask:
                AddTaskView()
            case .dailySummary:
                DailySummaryView()
            case .morningBriefing:
                MorningBriefingView()
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTaskShortcut)) { _ in
            activeSheet = .addTask
        }
        .onReceive(NotificationCenter.default.publisher(for: .searchShortcut)) { _ in
            activeSheet = .search
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToTab)) { notification in
            if let tabName = notification.object as? String {
                navigateToTab(tabName)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showDailySummary)) { _ in
            activeSheet = .dailySummary
        }
        .onReceive(NotificationCenter.default.publisher(for: .showMorningBriefing)) { _ in
            activeSheet = .morningBriefing
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            // Check if we should show iCloud prompt after first task is created
            checkICloudPrompt()
        }
        .task {
            // Rehydrate any persisted focus session from a previous app launch
            focusCoordinator.rehydrate()
        }
        .alert("Sync with iCloud?", isPresented: $showICloudPrompt) {
            Button("Enable iCloud Sync") {
                PersistenceController.setICloudSyncEnabled(true)
                hasShownICloudPrompt = true
                // Show restart required message
                showRestartRequiredAlert = true
            }
            Button("Not Now", role: .cancel) {
                hasShownICloudPrompt = true
            }
        } message: {
            Text("Enable iCloud sync to access your tasks on all your Apple devices. You can change this later in Settings.")
        }
        .alert("Restart Required", isPresented: $showRestartRequiredAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please restart the app to enable iCloud sync.")
        }
    }

    @State private var showRestartRequiredAlert = false

    private func checkICloudPrompt() {
        // Don't show if already shown or iCloud already enabled
        guard !hasShownICloudPrompt,
              !PersistenceController.isICloudSyncEnabled,
              FileManager.default.ubiquityIdentityToken != nil else {
            return
        }

        // Check if user has created their first task
        let taskCount = TaskService.shared.tasks.count
        if taskCount >= 1 {
            // Small delay to let the task creation animation complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showICloudPrompt = true
            }
        }
    }

    // MARK: - iPad Navigation (NavigationSplitView)

    private var iPadNavigationView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 300)
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var sidebarContent: some View {
        List(selection: $selectedTab) {
            Section("Tasks") {
                sidebarRow(for: .today)
                sidebarRow(for: .calendar)
                sidebarRow(for: .upcoming)
            }

            Section("Insights") {
                sidebarRow(for: .history)
            }

            Section("You") {
                sidebarRow(for: .lists)
                sidebarRow(for: .settings)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Lazyflow")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    activeSheet = .addTask
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    activeSheet = .search
                } label: {
                    Image(systemName: "magnifyingglass")
                }
            }
        }
    }

    private func sidebarRow(for tab: Tab) -> some View {
        Label(tab.rawValue, systemImage: tab.icon)
            .tag(tab)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab ?? .today {
        case .today:
            TodayView()
        case .calendar:
            CalendarView()
        case .upcoming:
            UpcomingView()
        case .insights:
            InsightsView()
        case .me:
            ProfileView()
        case .history:
            HistoryView()
        case .lists:
            ListsView()
        case .settings:
            SettingsView()
        }
    }

    // MARK: - iPhone Navigation (TabView)

    private var iPhoneTabView: some View {
        TabView(selection: Binding(
            get: { selectedTab ?? .today },
            set: { selectedTab = $0 }
        )) {
            TodayView()
                .tabItem {
                    Label(Tab.today.rawValue, systemImage: Tab.today.icon)
                }
                .tag(Tab.today)

            CalendarView()
                .tabItem {
                    Label(Tab.calendar.rawValue, systemImage: Tab.calendar.icon)
                }
                .tag(Tab.calendar)

            UpcomingView()
                .tabItem {
                    Label(Tab.upcoming.rawValue, systemImage: Tab.upcoming.icon)
                }
                .tag(Tab.upcoming)

            InsightsView(navigationPath: $insightsNavigationPath)
                .tabItem {
                    Label(Tab.insights.rawValue, systemImage: Tab.insights.icon)
                }
                .tag(Tab.insights)

            ProfileView(navigationPath: $profileNavigationPath)
                .tabItem {
                    Label(Tab.me.rawValue, systemImage: Tab.me.icon)
                }
                .tag(Tab.me)
        }
    }

    // MARK: - Deep Linking

    private func handleDeepLink(_ url: URL) {
        guard let host = url.host else { return }

        switch host {
        case "today", "calendar", "upcoming", "insights", "me", "history", "lists", "settings":
            navigateToTab(host)
        case "search":
            activeSheet = .search
        case "add", "new":
            activeSheet = .addTask
        case "daily-summary":
            activeSheet = .dailySummary
        case "morning-briefing":
            activeSheet = .morningBriefing
        default:
            break
        }
    }

    /// Navigate to a tab, handling iPhone hub routing for history/lists/settings
    private func navigateToTab(_ tabName: String) {
        let isCompact = horizontalSizeClass == .compact

        switch tabName {
        case "today": selectedTab = .today
        case "calendar": selectedTab = .calendar
        case "upcoming": selectedTab = .upcoming
        case "insights": selectedTab = .insights
        case "me": selectedTab = .me
        case "history":
            if isCompact {
                // On iPhone, navigate to Insights hub then push History
                selectedTab = .insights
                insightsNavigationPath.append(InsightsDestination.history)
            } else {
                selectedTab = .history
            }
        case "lists":
            if isCompact {
                // On iPhone, navigate to Me hub then push Lists
                selectedTab = .me
                profileNavigationPath.append(ProfileDestination.lists)
            } else {
                selectedTab = .lists
            }
        case "settings":
            if isCompact {
                // On iPhone, navigate to Me hub then push Settings
                selectedTab = .me
                profileNavigationPath.append(ProfileDestination.settings)
            } else {
                selectedTab = .settings
            }
        default: break
        }
    }
}

// MARK: - Preview

#Preview("iPhone") {
    ContentView()
        .environment(\.horizontalSizeClass, .compact)
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}

#Preview("iPad") {
    ContentView()
        .environment(\.horizontalSizeClass, .regular)
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}

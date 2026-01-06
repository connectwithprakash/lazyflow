import SwiftUI

/// Main content view with adaptive navigation
/// - iPad (regular size class): NavigationSplitView with sidebar
/// - iPhone (compact size class): TabView with bottom tabs
struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @State private var selectedTab: Tab? = .today
    @State private var showSearch = false
    @State private var showAddTask = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    enum Tab: String, CaseIterable, Identifiable {
        case today = "Today"
        case calendar = "Calendar"
        case upcoming = "Upcoming"
        case lists = "Lists"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .today: return "star.fill"
            case .calendar: return "calendar"
            case .upcoming: return "calendar.badge.clock"
            case .lists: return "folder.fill"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadNavigationView
            } else {
                iPhoneTabView
            }
        }
        .tint(Color.Lazyflow.accent)
        .preferredColorScheme(appearanceMode.colorScheme)
        .sheet(isPresented: $showSearch) {
            SearchView()
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskView()
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTaskShortcut)) { _ in
            showAddTask = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .searchShortcut)) { _ in
            showSearch = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToTab)) { notification in
            if let tabName = notification.object as? String {
                switch tabName {
                case "today": selectedTab = .today
                case "calendar": selectedTab = .calendar
                case "upcoming": selectedTab = .upcoming
                case "lists": selectedTab = .lists
                case "settings": selectedTab = .settings
                default: break
                }
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

            Section("Organize") {
                sidebarRow(for: .lists)
            }

            Section("System") {
                sidebarRow(for: .settings)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Lazyflow")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddTask = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSearch = true
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

            ListsView()
                .tabItem {
                    Label(Tab.lists.rawValue, systemImage: Tab.lists.icon)
                }
                .tag(Tab.lists)

            SettingsView()
                .tabItem {
                    Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
    }

    // MARK: - Deep Linking

    private func handleDeepLink(_ url: URL) {
        guard let host = url.host else { return }

        switch host {
        case "today":
            selectedTab = .today
        case "calendar":
            selectedTab = .calendar
        case "upcoming":
            selectedTab = .upcoming
        case "lists":
            selectedTab = .lists
        case "settings":
            selectedTab = .settings
        case "search":
            showSearch = true
        case "add", "new":
            showAddTask = true
        default:
            break
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

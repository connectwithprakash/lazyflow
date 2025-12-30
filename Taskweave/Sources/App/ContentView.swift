import SwiftUI

/// Main content view with tab navigation
struct ContentView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @State private var selectedTab: Tab = .today
    @State private var showSearch = false

    enum Tab: String, CaseIterable {
        case today = "Today"
        case upcoming = "Upcoming"
        case lists = "Lists"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .today: return "star.fill"
            case .upcoming: return "calendar"
            case .lists: return "folder.fill"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label(Tab.today.rawValue, systemImage: Tab.today.icon)
                }
                .tag(Tab.today)

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
        .tint(Color.Taskweave.accent)
        .preferredColorScheme(appearanceMode.colorScheme)
        .sheet(isPresented: $showSearch) {
            SearchView()
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    // MARK: - Deep Linking

    private func handleDeepLink(_ url: URL) {
        guard let host = url.host else { return }

        switch host {
        case "today":
            selectedTab = .today
        case "upcoming":
            selectedTab = .upcoming
        case "lists":
            selectedTab = .lists
        case "settings":
            selectedTab = .settings
        case "search":
            showSearch = true
        default:
            break
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}

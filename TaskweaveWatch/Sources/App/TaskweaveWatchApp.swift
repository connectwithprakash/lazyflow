import SwiftUI
import WatchConnectivity

@main
struct TaskweaveWatchApp: App {
    @StateObject private var connectivityService = WatchConnectivityService.shared
    @StateObject private var viewModel = WatchViewModel()

    var body: some Scene {
        WindowGroup {
            WatchTodayView(viewModel: viewModel)
                .environmentObject(connectivityService)
        }
    }
}

import SwiftUI

/// Main view showing today's tasks on Watch
struct WatchTodayView: View {
    @ObservedObject var viewModel: WatchViewModel
    @EnvironmentObject var connectivityService: WatchConnectivityService

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isEmpty {
                    WatchEmptyStateView()
                } else if viewModel.allComplete {
                    WatchAllCompleteView(
                        completedCount: viewModel.completedCount
                    )
                } else {
                    taskListContent
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
    }

    private var taskListContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Progress header
                WatchProgressHeader(
                    progress: viewModel.progress,
                    completedCount: viewModel.completedCount,
                    totalCount: viewModel.totalCount
                )

                // Task list
                ForEach(viewModel.incompleteTasks) { task in
                    WatchTaskRowView(task: task) {
                        viewModel.toggleCompletion(task)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Progress Header

struct WatchProgressHeader: View {
    let progress: Double
    let completedCount: Int
    let totalCount: Int

    var body: some View {
        HStack(spacing: 12) {
            // Progress ring
            WatchProgressRing(progress: progress)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(completedCount) of \(totalCount)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text("completed")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Progress Ring

struct WatchProgressRing: View {
    let progress: Double

    private let accentColor = Color(red: 33/255, green: 138/255, blue: 141/255) // #218A8D

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 4)

            // Progress
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    accentColor,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Checkmark when complete
            if progress >= 1.0 {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accentColor)
            }
        }
    }
}

// MARK: - All Complete View

struct WatchAllCompleteView: View {
    let completedCount: Int

    private let accentColor = Color(red: 33/255, green: 138/255, blue: 141/255)

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(accentColor)

            Text("All done!")
                .font(.headline)

            Text("\(completedCount) tasks completed")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    WatchTodayView(viewModel: WatchViewModel())
        .environmentObject(WatchConnectivityService.shared)
}

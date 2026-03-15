import SwiftUI
import os
import LazyflowCore
import LazyflowUI

struct DataAboutSettingsView: View {
    @State private var showAbout = false

    // Data management state
    @State private var iCloudSyncEnabled = PersistenceController.isICloudSyncEnabled
    @State private var syncStatus: SyncStatus = .disabled
    @State private var localDataCounts = DataCounts(tasks: 0, lists: 0)
    @State private var cloudCountsResult: PersistenceController.CloudCountsResult?
    @State private var isLoadingCloudCounts = false
    @State private var isDeleting = false
    @State private var isDeletingCloud = false

    // Delete confirmation states
    @State private var showDeleteLocalConfirmation = false
    @State private var showDeleteEverywhereConfirmation = false
    @State private var showDeleteCloudOnlyConfirmation = false
    @State private var showResyncConfirmation = false
    @State private var showResetEventPreferencesConfirmation = false

    private var iCloudAvailable: Bool {
        PersistenceController.isICloudAvailable
    }

    private var cloudDataCounts: DataCounts? {
        guard case .success(let counts) = cloudCountsResult else { return nil }
        return counts
    }

    private var cloudCountsError: String? {
        guard case .error(let message) = cloudCountsResult else { return nil }
        return message
    }

    @ViewBuilder
    private var syncStatusText: some View {
        if !iCloudSyncEnabled {
            Text("Tasks stored locally only")
        } else {
            switch syncStatus {
            case .synced(let date):
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.Lazyflow.success)
                        .font(.caption)
                    Text("Synced · \(timeAgo(from: date))")
                }
            case .syncing:
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Syncing...")
                }
            case .pendingChanges(let count):
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(Color.Lazyflow.warning)
                        .font(.caption)
                    Text("\(count) change\(count == 1 ? "" : "s") pending")
                }
            case .offline:
                HStack(spacing: 4) {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(Color.Lazyflow.warning)
                        .font(.caption)
                    Text("Offline · Changes will sync when online")
                }
            case .disabled:
                Text("Tasks stored locally only")
            case .error(let message):
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(Color.Lazyflow.error)
                        .font(.caption)
                    Text(message)
                }
            }
        }
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        Form {
            // MARK: - iCloud Sync Section
            Section {
                Toggle(isOn: $iCloudSyncEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: iCloudSyncEnabled ? "icloud.fill" : "icloud.slash")
                            .font(.title2)
                            .foregroundColor(iCloudSyncEnabled ? Color.Lazyflow.accent : Color.Lazyflow.textTertiary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("iCloud Sync")
                            syncStatusText
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                    }
                }
                .disabled(!iCloudAvailable)
                .onChange(of: iCloudSyncEnabled) { _, newValue in
                    PersistenceController.setICloudSyncEnabled(newValue)
                    PersistenceController.shared.reloadStoreWithCurrentSyncSettings()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        refreshData()
                    }
                }

                if !iCloudAvailable {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color.Lazyflow.warning)
                        Text("Sign in to iCloud in Settings to enable sync")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                    }
                }
            } header: {
                Text("iCloud")
            } footer: {
                if iCloudAvailable && iCloudSyncEnabled {
                    Text("Tasks sync automatically when you make changes.")
                } else if iCloudAvailable {
                    Text("Enable to sync tasks across your Apple devices.")
                }
            }

            // MARK: - Data Overview Section
            Section("Storage") {
                HStack {
                    Image(systemName: "iphone")
                        .foregroundColor(Color.Lazyflow.accent)
                        .frame(width: 28)
                    Text("On This Device")
                    Spacer()
                    Text(localDataCounts.description)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                }

                if iCloudAvailable {
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(iCloudSyncEnabled ? Color.Lazyflow.accent : Color.Lazyflow.textTertiary)
                            .frame(width: 28)
                        Text("In iCloud")
                        Spacer()
                        if isLoadingCloudCounts {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if let cloudCounts = cloudDataCounts {
                            if cloudCounts.isEmpty {
                                Text("Empty")
                                    .foregroundColor(Color.Lazyflow.textTertiary)
                            } else {
                                Text(cloudCounts.description)
                                    .foregroundColor(Color.Lazyflow.textSecondary)
                            }
                        } else if let error = cloudCountsError {
                            Button {
                                fetchCloudCounts()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(Color.Lazyflow.warning)
                                        .font(.caption)
                                    Text(error)
                                        .foregroundColor(Color.Lazyflow.warning)
                                }
                                .font(DesignSystem.Typography.caption1)
                            }
                        } else if !iCloudSyncEnabled {
                            Text("Sync disabled")
                                .foregroundColor(Color.Lazyflow.textTertiary)
                                .font(DesignSystem.Typography.caption1)
                        } else {
                            Button("Check") {
                                fetchCloudCounts()
                            }
                            .font(DesignSystem.Typography.caption1)
                        }
                    }
                }

                if iCloudSyncEnabled && iCloudAvailable {
                    Button {
                        showResyncConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .frame(width: 28)
                            Text("Re-sync from iCloud")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Color.Lazyflow.textTertiary)
                        }
                    }
                    .foregroundColor(Color.Lazyflow.textPrimary)
                }
            }

            // MARK: - Danger Zone Section
            Section {
                Button(role: .destructive) {
                    showDeleteLocalConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clear Local Cache")
                            if iCloudSyncEnabled {
                                Text("Re-downloads from iCloud")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(Color.Lazyflow.textSecondary)
                            } else if iCloudAvailable {
                                Text("Local only · iCloud backup kept")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(Color.Lazyflow.textSecondary)
                            } else {
                                Text("Removes all local data")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(Color.Lazyflow.textSecondary)
                            }
                        }
                        Spacer()
                        if isDeleting {
                            ProgressView()
                        }
                    }
                }
                .disabled(isDeleting || isDeletingCloud || localDataCounts.isEmpty)

                Button(role: .destructive) {
                    showDeleteEverywhereConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Delete Everything")
                            Text(iCloudAvailable ? "Local + iCloud · All devices" : "Local data only")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                        Spacer()
                    }
                }
                .disabled(isDeleting || isDeletingCloud || localDataCounts.isEmpty)

                if !iCloudSyncEnabled && iCloudAvailable {
                    Button(role: .destructive) {
                        showDeleteCloudOnlyConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "icloud.slash.fill")
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Delete iCloud Data")
                                Text("Cloud only · Keeps local data")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(Color.Lazyflow.textSecondary)
                            }
                            Spacer()
                            if isDeletingCloud {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isDeleting || isDeletingCloud)
                }

                Button(role: .destructive) {
                    showResetEventPreferencesConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reset Event Preferences")
                            Text("Clears learned Plan Your Day patterns")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                        Spacer()
                    }
                }
            } header: {
                Text("Danger Zone")
            } footer: {
                if iCloudSyncEnabled {
                    Label(
                        "\"Delete Everything\" will remove data from ALL devices synced with this iCloud account.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundColor(Color.Lazyflow.warning)
                } else if iCloudAvailable {
                    Label(
                        "Sync is disabled. Data in iCloud will NOT be deleted unless you use \"Delete iCloud Data\".",
                        systemImage: "info.circle.fill"
                    )
                } else {
                    Text("Data is stored locally on this device only.")
                }
            }

            // MARK: - About Section
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                }

                Button {
                    showAbout = true
                } label: {
                    Text("About Lazyflow")
                        .foregroundColor(Color.Lazyflow.textPrimary)
                }

                Link(destination: URL(string: "https://lazyflow.netlify.app/privacy/")!) {
                    Text("Privacy Policy")
                }

                Link(destination: URL(string: "https://lazyflow.netlify.app/terms/")!) {
                    Text("Terms of Service")
                }
            }
        }
        .settingsFormWidth()
        .navigationTitle("Data & About")
        .sheet(isPresented: $showAbout) { AboutView() }
        .onAppear {
            refreshData()
        }
        // MARK: - Alerts
        .alert("Clear Local Cache?", isPresented: $showDeleteLocalConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Cache", role: .destructive) {
                clearLocalData()
            }
        } message: {
            if iCloudSyncEnabled {
                Text("This will clear local data and re-download from iCloud. Your data is safe in the cloud.")
            } else {
                Text("This will permanently delete all data from this device. This cannot be undone.")
            }
        }
        .alert("Delete Everything?", isPresented: $showDeleteEverywhereConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteEverything()
            }
        } message: {
            if iCloudSyncEnabled {
                Text("⚠️ This will permanently delete all tasks and lists from this device AND all other devices synced with your iCloud account. This cannot be undone!")
            } else {
                Text("This will permanently delete all tasks and lists from this device. This cannot be undone.")
            }
        }
        .alert("Delete iCloud Data?", isPresented: $showDeleteCloudOnlyConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete from iCloud", role: .destructive) {
                deleteCloudData()
            }
        } message: {
            Text("This will delete all your data stored in iCloud. Local data on this device will not be affected. Other devices will lose their synced data.")
        }
        .alert("Re-sync from iCloud?", isPresented: $showResyncConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Re-sync", role: .destructive) {
                resyncFromCloud()
            }
        } message: {
            Text("This will replace local data with data from iCloud. Any unsynced local changes will be lost.")
        }
        .alert("Reset Event Preferences?", isPresented: $showResetEventPreferencesConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                EventPreferenceLearningService.shared.clearAllLearningData()
            }
        } message: {
            Text("This will clear all learned event preferences. The app will need to re-learn which events you typically skip or select.")
        }
    }

    // MARK: - Actions

    private func refreshData() {
        syncStatus = PersistenceController.shared.getSyncStatus()
        localDataCounts = PersistenceController.shared.getLocalDataCounts()

        if iCloudAvailable && iCloudSyncEnabled {
            fetchCloudCounts()
        } else {
            cloudCountsResult = nil
        }
    }

    private func fetchCloudCounts() {
        guard !isLoadingCloudCounts else { return }
        isLoadingCloudCounts = true

        _Concurrency.Task {
            let result = await PersistenceController.shared.getCloudDataCountsWithError()
            await MainActor.run {
                cloudCountsResult = result
                isLoadingCloudCounts = false
                syncStatus = PersistenceController.shared.getSyncStatus()
            }
        }
    }

    private func clearLocalData() {
        isDeleting = true
        PersistenceController.shared.deleteLocalDataOnly()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            refreshData()
            isDeleting = false
        }
    }

    private func deleteEverything() {
        isDeleting = true

        PersistenceController.shared.deleteAllDataEverywhere()

        if iCloudAvailable {
            _Concurrency.Task {
                try? await PersistenceController.shared.deleteCloudKitData()
                await MainActor.run {
                    refreshData()
                    isDeleting = false
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                refreshData()
                isDeleting = false
            }
        }
    }

    private func deleteCloudData() {
        isDeletingCloud = true
        _Concurrency.Task {
            do {
                try await PersistenceController.shared.deleteCloudKitData()
            } catch {
                Logger.sync.error("Failed to delete CloudKit data: \(error, privacy: .public)")
            }
            await MainActor.run {
                isDeletingCloud = false
                refreshData()
            }
        }
    }

    private func resyncFromCloud() {
        isDeleting = true
        PersistenceController.shared.resyncFromCloud()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            refreshData()
            isDeleting = false
        }
    }
}

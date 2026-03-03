import SwiftUI

struct ProviderConfigurationSheet: View {
    @Environment(\.dismiss) private var dismiss
    var llmService = LLMService.shared

    let providerType: LLMProviderType

    @State private var endpoint: String = ""
    @State private var apiKey: String = ""
    @State private var model: String = ""
    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var showDeleteConfirmation = false
    @State private var showTestConfirmation = false
    @State private var availableModels: [AvailableModel] = []
    @State private var isFetchingModels = false
    @State private var modelFetchError: String?
    @State private var hasLoadedConfig = false

    private enum TestResult {
        case success
        case failure(String)
    }

    private var isConfigured: Bool {
        llmService.availableProviders.contains(providerType)
    }

    private var canSave: Bool {
        !endpoint.isEmpty && !model.isEmpty && endpointValidationError == nil
    }

    /// Validates that external endpoints use HTTPS
    private var endpointValidationError: String? {
        guard !endpoint.isEmpty,
              let url = URL(string: endpoint),
              let host = url.host?.lowercased() else { return nil }

        if providerType == .custom,
           !OpenResponsesProvider.isLocalHost(host),
           url.scheme?.lowercased() != "https" {
            return "External endpoints must use HTTPS for security."
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // Provider Info
                Section {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: providerType.iconName)
                            .font(.title2)
                            .foregroundColor(Color.Lazyflow.accent)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(providerType.displayName)
                                .font(DesignSystem.Typography.headline)

                            Text(providerType.description)
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                    }
                }

                // Privacy Warning for external providers
                if providerType.isExternal {
                    Section {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color.Lazyflow.warning)
                            Text("Your task data will be sent to external servers when using this provider.")
                                .font(DesignSystem.Typography.footnote)
                                .foregroundColor(Color.Lazyflow.textSecondary)
                        }
                    }
                }

                // Configuration Fields
                Section("Configuration") {
                    TextField("Endpoint URL", text: $endpoint)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .onChange(of: endpoint) { _, _ in
                            // Clear models when endpoint changes
                            availableModels = []
                            modelFetchError = nil
                        }

                    if let error = endpointValidationError {
                        Text(error)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.error)
                    }

                    // Show API key field for providers that require it OR custom endpoints (optional)
                    if providerType.requiresAPIKey || providerType == .custom {
                        SecureField(providerType == .custom ? "API Key (optional)" : "API Key", text: $apiKey)
                            .textContentType(.password)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                }

                // Model Selection
                Section {
                    if availableModels.isEmpty {
                        // Manual entry with fetch button
                        HStack {
                            TextField("Model Name", text: $model)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()

                            Button {
                                fetchModels()
                            } label: {
                                if isFetchingModels {
                                    ProgressView()
                                        .frame(width: 20, height: 20)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundColor(Color.Lazyflow.accent)
                                }
                            }
                            .disabled(endpoint.isEmpty || isFetchingModels)
                        }

                        if let error = modelFetchError {
                            Text(error)
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(Color.Lazyflow.error)
                        }
                    } else {
                        // Model selection with NavigationLink
                        NavigationLink {
                            ModelSelectionView(
                                models: availableModels,
                                selectedModelId: $model
                            )
                        } label: {
                            HStack {
                                Text("Model")
                                Spacer()
                                if let selectedModel = availableModels.first(where: { $0.id == model }) {
                                    Text(selectedModel.displayName)
                                        .foregroundColor(Color.Lazyflow.textSecondary)
                                        .lineLimit(1)
                                } else {
                                    Text("Select")
                                        .foregroundColor(Color.Lazyflow.textTertiary)
                                }
                            }
                        }

                        Button {
                            availableModels = []
                            model = ""
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Enter Manually")
                            }
                            .font(DesignSystem.Typography.footnote)
                            .foregroundColor(Color.Lazyflow.accent)
                        }
                    }
                } header: {
                    Text("Model")
                } footer: {
                    if availableModels.isEmpty && providerType != .custom {
                        Text("Tap the download icon to fetch available models from the server.")
                    } else if !availableModels.isEmpty {
                        let freeCount = availableModels.filter { $0.isFree }.count
                        if freeCount > 0 && freeCount < availableModels.count {
                            Text("\(availableModels.count) models available (\(freeCount) free)")
                        } else {
                            Text("\(availableModels.count) models available")
                        }
                    }
                }

                // Test Connection
                Section {
                    Button {
                        // Show confirmation for external providers
                        if providerType.isExternal {
                            showTestConfirmation = true
                        } else {
                            testConnection()
                        }
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "network")
                            }
                            Text("Test Connection")
                            Spacer()
                            if let result = testResult {
                                switch result {
                                case .success:
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color.Lazyflow.success)
                                case .failure:
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Color.Lazyflow.error)
                                }
                            }
                        }
                    }
                    .disabled(!canSave || isTesting)

                    if case .failure(let message) = testResult {
                        Text(message)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(Color.Lazyflow.error)
                    }
                }

                // Remove Provider (if configured)
                if isConfigured {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Remove Provider")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Configure \(providerType.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveConfiguration()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                loadExistingConfig()
            }
            .alert("Remove Provider", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    llmService.removeOpenResponsesProvider(type: providerType)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to remove \(providerType.displayName)? You'll need to reconfigure it to use it again.")
            }
            .alert("Test Connection", isPresented: $showTestConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Test Anyway") {
                    testConnection()
                }
            } message: {
                Text("This will send a test request to \(providerType.displayName). Your task data may be sent to external servers.")
            }
        }
    }

    private func loadExistingConfig() {
        // Only load once to prevent resetting fields when navigating back from model selection
        guard !hasLoadedConfig else { return }
        hasLoadedConfig = true

        // Load default or existing configuration
        let config: OpenResponsesConfig

        if let existingConfig = llmService.getOpenResponsesConfig(for: providerType) {
            config = existingConfig
        } else {
            // Use defaults based on provider type
            switch providerType {
            case .ollama:
                config = .ollamaDefault
            case .custom:
                config = .customDefault
            case .apple:
                return // Apple doesn't need configuration
            }
        }

        endpoint = config.endpoint
        apiKey = config.apiKey ?? ""
        model = config.model
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        let config = OpenResponsesConfig(
            endpoint: endpoint,
            apiKey: apiKey.isEmpty ? nil : apiKey,
            model: model
        )

        _Concurrency.Task {
            do {
                _ = try await llmService.testConnection(config: config)
                await MainActor.run {
                    testResult = .success
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = .failure(error.localizedDescription)
                    isTesting = false
                }
            }
        }
    }

    private func saveConfiguration() {
        let config = OpenResponsesConfig(
            endpoint: endpoint,
            apiKey: apiKey.isEmpty ? nil : apiKey,
            model: model
        )

        llmService.configureOpenResponses(config: config, providerType: providerType)
        llmService.selectedProvider = providerType
        dismiss()
    }

    private func fetchModels() {
        isFetchingModels = true
        modelFetchError = nil

        _Concurrency.Task {
            do {
                let models = try await OpenResponsesConfig.fetchAvailableModels(
                    endpoint: endpoint,
                    apiKey: apiKey.isEmpty ? nil : apiKey,
                    for: providerType
                )

                await MainActor.run {
                    availableModels = models
                    isFetchingModels = false

                    // Auto-select first model if current model is empty or not in list
                    if model.isEmpty || !models.contains(where: { $0.id == model }) {
                        model = models.first?.id ?? ""
                    }
                }
            } catch {
                await MainActor.run {
                    modelFetchError = "Failed to fetch models: \(error.localizedDescription)"
                    isFetchingModels = false
                }
            }
        }
    }
}

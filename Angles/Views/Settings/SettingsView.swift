import SwiftUI

/// Settings overview — view active provider, switch providers, browse tools, manage memory.
struct SettingsView: View {
    @Binding var hasConfiguredProvider: Bool
    @State private var selectedType: ProviderType = .openRouter
    @State private var apiKey = ""
    @State private var baseURL = ""
    @State private var modelID = ""
    @State private var maxTokens = 4096
    @State private var showReset = false
    @State private var showToolList = false
    @State private var savedCount = 0
    @State private var memoryCount: Int = {
        guard let data = UserDefaults.standard.data(forKey: "angles_memory"),
              let mem = try? JSONDecoder().decode([MemoryEntry].self, from: data) else { return 0 }
        return mem.count
    }()

    var body: some View {
        NavigationStack {
            Form {
                // Active provider status
                Section("Active Provider") {
                    activeProviderCard()
                }

                // Switch provider
                Section("Switch Provider") {
                    Picker("Provider", selection: $selectedType) {
                        ForEach(ProviderType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: providerIcon(for: type))
                                    .foregroundStyle(providerColor(for: type))
                                Text(type.rawValue)
                            }.tag(type)
                        }
                    }
                    .onChange(of: selectedType) { _, t in resetFields(for: t) }

                    configField("API Key", "sk-...", $apiKey, secure: true)
                    configField("Host URL", "https://...", $baseURL, url: true)
                    configField("Model ID", "model-id", $modelID)
                    HStack {
                        Text("Max Tokens").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        TextField("4096", value: $maxTokens, format: .number)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    }

                    Button("Save & Activate") { saveAndActivate() }
                        .disabled(apiKey.isEmpty || baseURL.isEmpty || modelID.isEmpty)
                }

                // Available Tools
                Section {
                    Button(action: { showToolList.toggle() }) {
                        HStack {
                            Text("Available Tools")
                            Spacer()
                            Text("\(ToolDefinition.allTools.count)").foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                // Memory stats
                Section {
                    HStack {
                        Text("Stored Memories")
                        Spacer()
                        Text("\(memoryCount)").foregroundStyle(.secondary)
                    }
                }

                // Danger zone
                Section {
                    Button("Reset All Settings", role: .destructive) { showReset = true }
                } footer: {
                    Text("This clears your API config and returns to the onboarding screen.")
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.1.0").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("App")
                        Spacer()
                        Text("Angles").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Reset All?", isPresented: $showReset) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    UserDefaults.standard.removeObject(forKey: "hasConfiguredProvider")
                    UserDefaults.standard.removeObject(forKey: "activeProvider")
                    hasConfiguredProvider = false
                }
            } message: { Text("Delete your API config and return to setup.") }
            .onAppear { loadConfig(); memoryCount = countMemory() }
            .sheet(isPresented: $showToolList) {
                ToolListView()
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func activeProviderCard() -> some View {
        if let data = UserDefaults.standard.data(forKey: "activeProvider"),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    Text(dict["name"] as? String ?? "Unknown").bold()
                }
                Text("Model: \(dict["modelID"] as? String ?? "")").font(.caption).foregroundStyle(.secondary)
                Text("Host: \(dict["baseURL"] as? String ?? "")").font(.caption2).foregroundStyle(.secondary)
                Text("Max Tokens: \(dict["maxTokens"] as? Int ?? 0)").font(.caption2).foregroundStyle(.secondary)
            }
        } else {
            Label("No provider configured", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private func configField(_ label: String, _ placeholder: String, _ binding: Binding<String>, secure: Bool = false, url: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            if secure {
                SecureField(placeholder, text: binding).textContentType(.password)
            } else {
                TextField(placeholder, text: binding)
                    .keyboardType(url ? .URL : .default)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
    }

    private func providerIcon(for type: ProviderType) -> String {
        switch type {
        case .openRouter: return "network"
        case .openAI: return "brain.head.profile"
        case .claude: return "sparkles"
        case .gemini: return "star.circle"
        case .grok: return "bolt.circle"
        case .deepSeek: return "waveform.circle"
        case .custom: return "gearshape.2"
        }
    }

    private func providerColor(for type: ProviderType) -> Color {
        switch type {
        case .openRouter: return .purple
        case .openAI: return .green
        case .claude: return .orange
        case .gemini: return .blue
        case .grok: return .cyan
        case .deepSeek: return .indigo
        case .custom: return .gray
        }
    }

    private func resetFields(for type: ProviderType) {
        switch type {
        case .openRouter: baseURL = "https://openrouter.ai/api/v1"; modelID = "openai/gpt-4o"
        case .openAI: baseURL = "https://api.openai.com/v1"; modelID = "gpt-4o"
        case .claude: baseURL = "https://api.anthropic.com/v1"; modelID = "claude-sonnet-4-20250514"
        case .gemini: baseURL = "https://generativelanguage.googleapis.com/v1beta"; modelID = "gemini-2.5-pro"
        case .grok: baseURL = "https://api.x.ai/v1"; modelID = "grok-3"
        case .deepSeek: baseURL = "https://api.deepseek.com/v1"; modelID = "deepseek-chat"
        case .custom: baseURL = ""; modelID = ""
        }
        apiKey = ""
    }

    private func loadConfig() {
        guard let data = UserDefaults.standard.data(forKey: "activeProvider"),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        selectedType = ProviderType(rawValue: dict["providerType"] as? String ?? "") ?? .openRouter
        baseURL = dict["baseURL"] as? String ?? ""
        modelID = dict["modelID"] as? String ?? ""
        maxTokens = dict["maxTokens"] as? Int ?? 4096
    }

    private func saveAndActivate() {
        let dict: [String: Any] = [
            "name": selectedType.rawValue, "providerType": selectedType.rawValue,
            "apiKey": apiKey, "baseURL": baseURL, "modelID": modelID, "maxTokens": maxTokens
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict) {
            UserDefaults.standard.set(data, forKey: "activeProvider")
        }
    }

    private func countMemory() -> Int {
        guard let data = UserDefaults.standard.data(forKey: "angles_memory"),
              let mem = try? JSONDecoder().decode([MemoryEntry].self, from: data) else { return 0 }
        return mem.count
    }
}

// MARK: - Tool List Sheet

struct ToolListView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(ToolDefinition.allTools) { tool in
                VStack(alignment: .leading, spacing: 4) {
                    Text(tool.name)
                        .font(.headline.monospaced())
                        .foregroundStyle(.cyan)
                    Text(tool.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            .navigationTitle("Tools (\(ToolDefinition.allTools.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
import SwiftUI

/// First-launch onboarding — user selects a provider and enters API configuration.
struct WelcomeView: View {
    @Binding var hasConfiguredProvider: Bool
    @State private var selectedProviderType: ProviderType = .openRouter
    @State private var apiKey = ""
    @State private var baseURL = "https://openrouter.ai/api/v1"
    @State private var modelID = "openai/gpt-4o"
    @State private var maxTokens = 4096
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "angle")
                        .font(.system(size: 48))
                        .foregroundStyle(.cyan)
                        .padding(.top, 32)
                    
                    Text("Welcome to Angles")
                        .font(.largeTitle.bold())
                    
                    Text("Your personal coding AI agent")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 24)
                
                Form {
                    Section {
                        Picker("Provider", selection: $selectedProviderType) {
                            ForEach(ProviderType.allCases, id: \.self) { type in
                                HStack {
                                    Image(systemName: providerIcon(for: type))
                                        .foregroundStyle(providerColor(for: type))
                                    Text(type.rawValue)
                                }.tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedProviderType) { _, t in resetFields(for: t) }
                    } header: {
                        Text("Choose your AI Provider")
                    }
                    
                    Section("API Configuration") {
                        field("API Key", "sk-...", $apiKey, isSecure: true)
                        field("Host URL", "https://...", $baseURL, keyboard: .URL)
                        field("Model ID", "model-id", $modelID)
                        field("Max Tokens", "4096", numberValue: $maxTokens, keyboard: .numberPad)
                    }
                    
                    Section {
                        Button(action: saveAndContinue) {
                            HStack {
                                Spacer()
                                Text("Launch Angles").bold()
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty
                            || baseURL.trimmingCharacters(in: .whitespaces).isEmpty
                            || modelID.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - Fields Helper
    
    @ViewBuilder
    private func field(_ label: String, _ placeholder: String, _ binding: Binding<String>, isSecure: Bool = false, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            if isSecure {
                SecureField(placeholder, text: binding).textContentType(.password)
            } else {
                TextField(placeholder, text: binding)
                    .keyboardType(keyboard)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
    }
    
    @ViewBuilder
    private func field(_ label: String, _ placeholder: String, numberValue: Binding<Int>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, value: numberValue, format: .number)
                .keyboardType(keyboard)
        }
    }
    
    // MARK: - Provider Icons & Colors
    
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
    
    private func saveAndContinue() {
        let dict: [String: Any] = [
            "name": selectedProviderType.rawValue,
            "providerType": selectedProviderType.rawValue,
            "apiKey": apiKey,
            "baseURL": baseURL,
            "modelID": modelID,
            "maxTokens": maxTokens
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict) {
            UserDefaults.standard.set(data, forKey: "activeProvider")
        }
        UserDefaults.standard.set(true, forKey: "hasConfiguredProvider")
        hasConfiguredProvider = true
    }
}
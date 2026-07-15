import Foundation
import SwiftData

@Model
final class ProviderConfig {
    var name: String
    var providerType: ProviderType
    var apiKey: String
    var baseURL: String
    var modelID: String
    var maxTokens: Int
    var isActive: Bool
    var createdAt: Date
    var geminiAPIKeyQuery: Bool   // Gemini uses ?key= in URL, others use Authorization header

    init(name: String, providerType: ProviderType, apiKey: String, baseURL: String, modelID: String, maxTokens: Int = 4096, isActive: Bool = false) {
        self.name = name
        self.providerType = providerType
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.modelID = modelID
        self.maxTokens = maxTokens
        self.isActive = isActive
        self.createdAt = Date()
        self.geminiAPIKeyQuery = providerType == .gemini
    }

    static func templates() -> [ProviderConfig] {
        [
            ProviderConfig(
                name: "OpenRouter",
                providerType: .openRouter,
                apiKey: "",
                baseURL: "https://openrouter.ai/api/v1",
                modelID: "openai/gpt-4o"
            ),
            ProviderConfig(
                name: "OpenAI (ChatGPT)",
                providerType: .openAI,
                apiKey: "",
                baseURL: "https://api.openai.com/v1",
                modelID: "gpt-4o"
            ),
            ProviderConfig(
                name: "Anthropic Claude",
                providerType: .claude,
                apiKey: "",
                baseURL: "https://api.anthropic.com/v1",
                modelID: "claude-sonnet-4-20250514"
            ),
            ProviderConfig(
                name: "Google Gemini",
                providerType: .gemini,
                apiKey: "",
                baseURL: "https://generativelanguage.googleapis.com/v1beta",
                modelID: "gemini-2.5-pro"
            ),
            ProviderConfig(
                name: "xAI Grok",
                providerType: .grok,
                apiKey: "",
                baseURL: "https://api.x.ai/v1",
                modelID: "grok-3"
            ),
            ProviderConfig(
                name: "DeepSeek",
                providerType: .deepSeek,
                apiKey: "",
                baseURL: "https://api.deepseek.com/v1",
                modelID: "deepseek-chat"
            ),
            ProviderConfig(
                name: "Custom",
                providerType: .custom,
                apiKey: "",
                baseURL: "",
                modelID: ""
            ),
        ]
    }
}

enum ProviderType: String, Codable, CaseIterable {
    case openRouter = "OpenRouter"
    case openAI = "OpenAI"
    case claude = "Claude"
    case gemini = "Gemini"
    case grok = "Grok"
    case deepSeek = "DeepSeek"
    case custom = "Custom"

    var requestFormat: APIRequestFormat {
        switch self {
        case .gemini:
            return .geminiNative
        case .claude:
            return .claudeNative
        default:
            return .openAICompatible
        }
    }

    var usesAPIKeyInQuery: Bool {
        self == .gemini
    }

    var requiresAPIKeyHeader: Bool {
        self != .gemini
    }
}

enum APIRequestFormat {
    case openAICompatible  // Standard /chat/completions (OpenRouter, OpenAI, Grok, DeepSeek, Custom)
    case geminiNative      // Gemini native /models/{model}:streamGenerateContent
    case claudeNative      // Anthropic Messages API
}
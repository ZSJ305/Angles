import SwiftUI

/// ViewModel for the Chat screen. Manages messages, API calls, and tool execution loop.
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var isStreaming = false
    @Published var errorMessage: String?
    
    var toolExecutor: ToolExecutor?
    var browserCoordinator: WebViewCoordinator?
    private var apiClient: APIClient?
    private var streamingTask: Task<Void, Never>?
    private var configDict: [String: Any]?
    
    init() {
        loadConfig()
    }
    
    func loadConfig() {
        guard let data = UserDefaults.standard.data(forKey: "activeProvider"),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        configDict = dict
        
        let providerType = ProviderType(rawValue: dict["providerType"] as? String ?? "OpenRouter") ?? .openRouter
        let config = ProviderConfig(
            name: dict["name"] as? String ?? providerType.rawValue,
            providerType: providerType,
            apiKey: dict["apiKey"] as? String ?? "",
            baseURL: dict["baseURL"] as? String ?? "",
            modelID: dict["modelID"] as? String ?? "",
            maxTokens: dict["maxTokens"] as? Int ?? 4096,
            isActive: true
        )
        apiClient = APIClient(config: config)
    }
    
    func reloadConfig() {
        loadConfig()
    }
    
    var hasConfig: Bool { apiClient != nil }
    
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard let client = apiClient else {
            errorMessage = "No API configured. Go to Settings first."
            return
        }
        
        let userMsg = ChatMessage(role: .user, content: inputText)
        messages.append(userMsg)
        inputText = ""
        errorMessage = nil
        isStreaming = true
        
        let assistantMsg = ChatMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMsg)
        
        streamingTask = Task {
            var fullResponse = ""
            let msgIdx = messages.count - 1
            
            client.sendStreaming(
                messages: Array(messages.dropLast()),
                systemPrompt: SystemPrompt.defaultPrompt(),
                tools: ToolDefinition.allTools,
                onToken: { [weak self] token in
                    Task { @MainActor in
                        fullResponse += token
                        self?.messages[msgIdx].content = fullResponse
                    }
                },
                onToolCall: { [weak self] name, args in
                    guard let strongSelf = self else { return "" }
                    let callID = UUID().uuidString
                    let callData = ToolCallData(id: callID, name: name, arguments: String(data: try! JSONSerialization.data(withJSONObject: args), encoding: .utf8) ?? "{}")
                    let result = try await strongSelf.toolExecutor?.execute(name: name, arguments: args) ?? "Tool not available"
                    let resultData = ToolResultData(callID: callID, result: result)
                    
                    await MainActor.run {
                        var msg = strongSelf.messages[msgIdx]
                        msg.toolCalls = (msg.toolCalls ?? []) + [callData]
                        msg.toolResults = (msg.toolResults ?? []) + [resultData]
                        fullResponse += "\n🔧 \(name): \(result)\n"
                        msg.content = fullResponse
                    }
                    return result
                },
                onComplete: { [weak self] in
                    Task { @MainActor in
                        self?.messages[msgIdx].isStreaming = false
                        self?.isStreaming = false
                    }
                },
                onError: { [weak self] error in
                    Task { @MainActor in
                        self?.errorMessage = error.localizedDescription
                        self?.messages[msgIdx].isStreaming = false
                        self?.isStreaming = false
                        if !fullResponse.isEmpty {
                            self?.messages[msgIdx].content = fullResponse
                        } else {
                            self?.messages[msgIdx].content = "Error: \(error.localizedDescription)"
                        }
                    }
                }
            )
        }
    }
    
    func stopStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false
        if let last = messages.last, last.isStreaming {
            messages[messages.count - 1].isStreaming = false
        }
    }
    
    func clearChat() {
        messages.removeAll()
    }
}
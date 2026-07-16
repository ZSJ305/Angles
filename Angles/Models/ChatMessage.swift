import Foundation

final class ChatMessage: ObservableObject, Identifiable {
    var id = UUID()
    var role: MessageRole
    var content: String
    var timestamp = Date()
    var toolCalls: [ToolCallData]?
    var toolResults: [ToolResultData]?
    var isStreaming = false
    var sessionID = UUID()

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date(), sessionID: UUID = UUID()) {
        self.id = id; self.role = role; self.content = content; self.timestamp = timestamp; self.sessionID = sessionID
    }
}

enum MessageRole: String, Codable, CaseIterable {
    case user, assistant, system, tool
    var displayName: String {
        switch self {
        case .user: return "You"
        case .assistant: return "Angles"
        case .system: return "System"
        case .tool: return "Tool"
        }
    }
}

struct ToolCallData: Codable {
    var id: String
    var name: String
    var arguments: String
}

struct ToolResultData: Codable {
    var callID: String
    var result: String
}
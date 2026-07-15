import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
    var toolCalls: [ToolCallData]?
    var toolResults: [ToolResultData]?
    var isStreaming: Bool
    var sessionID: UUID
    
    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date(), sessionID: UUID = UUID()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.toolCalls = nil
        self.toolResults = nil
        self.isStreaming = false
        self.sessionID = sessionID
    }
}

enum MessageRole: String, Codable, CaseIterable {
    case user
    case assistant
    case system
    case tool
    
    var displayName: String {
        switch self {
        case .user: return "You"
        case .assistant: return "Angles"
        case .system: return "System"
        case .tool: return "Tool"
        }
    }
}

/// Represents a tool call from the model
struct ToolCallData: Codable {
    var id: String
    var name: String
    var arguments: String  // JSON string
}

/// Represents a tool result returned to the model
struct ToolResultData: Codable {
    var callID: String
    var result: String
}
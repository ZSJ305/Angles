import SwiftUI

/// Individual message bubble in the chat
struct MessageBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(spacing: 0) {
            if message.role == .assistant {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Angles")
                        .font(.caption2.bold())
                        .foregroundStyle(.cyan)
                    Text(message.content)
                        .font(.body)
                        .textSelection(.enabled)
                    
                    if message.isStreaming {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Thinking...")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(.cyan.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                Spacer(minLength: 40)
            } else if message.role == .user {
                Spacer(minLength: 40)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("You")
                        .font(.caption2.bold())
                        .foregroundStyle(.blue)
                    Text(message.content)
                        .font(.body)
                        .textSelection(.enabled)
                }
                .padding(12)
                .background(.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if message.role == .tool {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🔧 Tool Result")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                    Text(message.content)
                        .font(.caption)
                        .textSelection(.enabled)
                        .lineLimit(6)
                }
                .padding(8)
                .background(.green.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Message Input Bar

struct MessageInputBar: View {
    @Binding var text: String
    let isStreaming: Bool
    let hasConfig: Bool
    let onSend: () -> Void
    let onStop: () -> Void
    var isFocused: FocusState<Bool>.Binding?
    
    var body: some View {
        HStack(spacing: 8) {
            TextField(hasConfig ? "Message Angles..." : "Configure API in Settings first", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .lineLimit(1...5)
                .disabled(!hasConfig)
                .onSubmit { if hasConfig && !isStreaming { onSend() } }
            
            if isStreaming {
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(hasConfig && !text.trimmingCharacters(in: .whitespaces).isEmpty ? .cyan : .gray)
                }
                .disabled(!hasConfig || text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
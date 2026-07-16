import SwiftUI

/// Individual message bubble in the chat
struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(spacing: 0) {
            if message.role == .assistant {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Angles")
                        .font(Font.caption2.weight(.bold))
                        .foregroundColor(.cyan)
                    Text(message.content)
                        .font(.body)

                    if message.isStreaming {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Thinking...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color.cyan.opacity(0.08))
                .cornerRadius(12)
                Spacer(minLength: 40)
            } else if message.role == .user {
                Spacer(minLength: 40)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("You")
                        .font(Font.caption2.weight(.bold))
                        .foregroundColor(.blue)
                    Text(message.content)
                        .font(.body)
                }
                .padding(12)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(12)
            } else if message.role == .tool {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🔧 Tool Result")
                        .font(Font.caption2.weight(.bold))
                        .foregroundColor(.green)
                    Text(message.content)
                        .font(.caption)
                        .lineLimit(6)
                }
                .padding(8)
                .background(Color.green.opacity(0.06))
                .cornerRadius(8)
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

    var body: some View {
        HStack(spacing: 8) {
            TextField(hasConfig ? "Message Angles..." : "Configure API in Settings first",
                      text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray5))
                .cornerRadius(20)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .disabled(!hasConfig)

            if isStreaming {
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                        .foregroundColor(.red)
                }
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(hasConfig && !text.trimmingCharacters(in: .whitespaces).isEmpty ? .cyan : .gray)
                }
                .disabled(!hasConfig || text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
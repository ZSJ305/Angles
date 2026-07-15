import SwiftUI

/// Main chat interface: message list + input bar
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    let toolExecutor: ToolExecutor
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Message list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            if viewModel.messages.isEmpty {
                                EmptyChatView()
                            }
                            
                            ForEach(viewModel.messages) { msg in
                                MessageBubbleView(message: msg)
                                    .id(msg.id)
                            }
                            
                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .defaultScrollAnchor(.bottom)
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let last = viewModel.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onChange(of: viewModel.messages.last?.content ?? "") { _, _ in
                        if let last = viewModel.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                
                Divider()
                
                // Input bar
                MessageInputBar(
                    text: $viewModel.inputText,
                    isStreaming: viewModel.isStreaming,
                    hasConfig: viewModel.hasConfig,
                    onSend: { viewModel.sendMessage() },
                    onStop: { viewModel.stopStreaming() }
                )
                .focused($isFocused)
            }
            .navigationTitle("Angles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: viewModel.clearChat) {
                        Image(systemName: "trash")
                    }
                    .disabled(viewModel.messages.isEmpty)
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !viewModel.hasConfig {
                        Label("No API", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}

// MARK: - Empty State

struct EmptyChatView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            Image(systemName: "angle")
                .font(.system(size: 60))
                .foregroundStyle(.cyan.opacity(0.5))
            Text("Angles is ready")
                .font(.title2.bold())
            Text("Ask me to code, browse the web, or manage files.\nI can create, read, write, and delete files.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 100)
    }
}
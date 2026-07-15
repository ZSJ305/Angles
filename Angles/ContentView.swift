import SwiftUI

/// Main tabbed interface: Chat + Browser + Settings
struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var chatViewModel = ChatViewModel()
    @StateObject private var browserCoordinator = WebViewCoordinator()
    @StateObject private var toolExecutor = ToolExecutor()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ChatView(viewModel: chatViewModel, toolExecutor: toolExecutor)
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(0)
            
            BrowserView(coordinator: browserCoordinator)
                .tabItem {
                    Label("Browser", systemImage: "safari.fill")
                }
                .tag(1)
            
            SettingsView(hasConfiguredProvider: .constant(true))
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .onAppear {
            toolExecutor.webViewCoordinator = browserCoordinator
            chatViewModel.toolExecutor = toolExecutor
            chatViewModel.browserCoordinator = browserCoordinator
        }
    }
}
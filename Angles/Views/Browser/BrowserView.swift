import SwiftUI

/// Built-in web browser with CDP-like capabilities:
/// navigate, screenshot, execute JS, page info, user-agent customization.
struct BrowserView: View {
    @ObservedObject var coordinator: WebViewCoordinator
    @State private var urlText = ""
    @State private var showUAEditor = false
    @State private var customUserAgent = ""
    @State private var showJSConsole = false
    @State private var jsScript = "document.title"
    @State private var jsResult = ""
    @State private var showPageInfo = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // URL bar
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("Enter URL...", text: $urlText)
                            .textFieldStyle(.plain)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onSubmit { go() }

                        Button(action: go) { Image(systemName: "arrow.right.circle.fill").font(.title3) }
                    }

                    // Toolbar
                    HStack {
                        Button(action: { coordinator.goBack() }) { Image(systemName: "chevron.left") }
                            .disabled(!coordinator.canGoBack)
                        Button(action: { coordinator.goForward() }) { Image(systemName: "chevron.right") }
                            .disabled(!coordinator.canGoForward)
                        Button(action: { coordinator.reload() }) { Image(systemName: "arrow.clockwise") }

                        if coordinator.isLoading { ProgressView().scaleEffect(0.7).padding(.horizontal, 4) }

                        Spacer()

                        Menu {
                            Button(action: { showPageInfo = true }) {
                                Label("Page Info", systemImage: "info.circle")
                            }
                            Button(action: { showJSConsole = true }) {
                                Label("Execute JavaScript", systemImage: "chevron.left.forwardslash.chevron.right")
                            }
                            Button(action: captureScreenshot) {
                                Label("Screenshot", systemImage: "camera.viewfinder")
                            }
                            Divider()
                            Button(action: { showUAEditor = true }) {
                                Label("Set User Agent", systemImage: "person.text.rectangle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle").font(.title3)
                        }
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)

                Divider()

                // WebView
                WebViewRepresentable(coordinator: coordinator, homeURL: nil)
            }
            .navigationTitle("Browser")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showUAEditor) {
                uaEditorSheet()
            }
            .sheet(isPresented: $showJSConsole) {
                jsConsoleSheet()
            }
            .sheet(isPresented: $showPageInfo) {
                pageInfoSheet()
            }
        }
    }

    private func go() {
        var s = urlText.trimmingCharacters(in: .whitespaces)
        if !s.contains("://") && !s.isEmpty { s = "https://\(s)" }
        if let u = URL(string: s) { coordinator.navigate(to: u) }
    }

    private func captureScreenshot() {
        Task {
            if let img = try? await coordinator.captureScreenshot(fullPage: false) {
                let fn = "screenshot_\(Int(Date().timeIntervalSince1970)).png"
                try? img.pngData()?.write(to: FileManager.documentsDirectory.appendingPathComponent(fn))
            }
        }
    }

    // MARK: - Sheets

    @ViewBuilder
    private func uaEditorSheet() -> some View {
        NavigationStack {
            Form {
                Section("Custom User Agent") {
                    TextEditor(text: $customUserAgent).frame(minHeight: 100).font(.caption.monospaced())
                    Text("Empty = default Mobile Safari").font(.caption2).foregroundStyle(.secondary)
                }
                Section {
                    Button("Apply") { coordinator.setCustomUserAgent(customUserAgent); showUAEditor = false }
                    Button("Reset to Default") { coordinator.setCustomUserAgent(""); customUserAgent = ""; showUAEditor = false }
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("User Agent").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { showUAEditor = false } } }
        }
    }

    @ViewBuilder
    private func jsConsoleSheet() -> some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("JavaScript Console").font(.headline).padding(.top)
                TextEditor(text: $jsScript)
                    .font(.caption.monospaced())
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)

                Button("Execute") {
                    Task {
                        do { jsResult = try await coordinator.executeJS(jsScript) }
                        catch { jsResult = "Error: \(error.localizedDescription)" }
                    }
                }
                .buttonStyle(.borderedProminent)

                if !jsResult.isEmpty {
                    ScrollView {
                        Text(jsResult)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .padding()
                    }
                    .frame(maxHeight: 200)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                }
                Spacer()
            }
            .navigationTitle("JS Console").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showJSConsole = false } } }
        }
    }

    @ViewBuilder
    private func pageInfoSheet() -> some View {
        NavigationStack {
            Form {
                Section("Page Info") {
                    LabeledContent("Title", value: coordinator.pageTitle)
                    LabeledContent("URL", value: coordinator.currentURL?.absoluteString ?? "-")
                    LabeledContent("Loading", value: coordinator.isLoading ? "Yes" : "No")
                    LabeledContent("Can Go Back", value: coordinator.canGoBack ? "Yes" : "No")
                    LabeledContent("Can Go Forward", value: coordinator.canGoForward ? "Yes" : "No")
                }
            }
            .navigationTitle("Page Info").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showPageInfo = false } } }
        }
    }
}
import SwiftUI

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
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Enter URL...", text: $urlText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .keyboardType(.URL)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                    Button(action: go) { Image(systemName: "arrow.right.circle.fill").font(.title3) }
                }
                HStack {
                    Button(action: { coordinator.goBack() }) { Image(systemName: "chevron.left") }.disabled(!coordinator.canGoBack)
                    Button(action: { coordinator.goForward() }) { Image(systemName: "chevron.right") }.disabled(!coordinator.canGoForward)
                    Button(action: { coordinator.reload() }) { Image(systemName: "arrow.clockwise") }
                    if coordinator.isLoading { ProgressView().scaleEffect(0.7).padding(.horizontal, 4) }
                    Spacer()
                    Menu {
                        Button(action: { showPageInfo = true }) { Label("Page Info", systemImage: "info.circle") }
                        Button(action: { showJSConsole = true }) { Label("Execute JS", systemImage: "chevron.left.forwardslash.chevron.right") }
                        Button(action: captureScreenshot) { Label("Screenshot", systemImage: "camera.viewfinder") }
                        Divider()
                        Button(action: { showUAEditor = true }) { Label("Set User Agent", systemImage: "person.text.rectangle") }
                    } label: { Image(systemName: "ellipsis.circle").font(.title3) }
                }.font(.subheadline)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            Divider()

            WebViewRepresentable(coordinator: coordinator, homeURL: nil)
        }
        .navigationBarTitle("Browser", displayMode: .inline)
        .sheet(isPresented: $showUAEditor) { uaEditorSheet() }
        .sheet(isPresented: $showJSConsole) { jsConsoleSheet() }
        .sheet(isPresented: $showPageInfo) { pageInfoSheet() }
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

    @ViewBuilder
    private func uaEditorSheet() -> some View {
        VStack {
            Text("Custom User Agent").font(.headline).padding(.top)
            TextEditor(text: $customUserAgent).frame(minHeight: 80).font(.caption).padding(8)
                .background(Color(.systemGray6)).cornerRadius(8).padding(.horizontal)
            Text("Empty = default Mobile Safari").font(.caption2).foregroundColor(.secondary)
            HStack {
                Button("Apply") { coordinator.setCustomUserAgent(customUserAgent); showUAEditor = false }
                Button("Reset to Default") { coordinator.setCustomUserAgent(""); customUserAgent = ""; showUAEditor = false }.foregroundColor(.secondary)
            }.padding()
            Spacer()
        }
    }

    @ViewBuilder
    private func jsConsoleSheet() -> some View {
        VStack(spacing: 12) {
            Text("JavaScript Console").font(.headline).padding(.top)
            TextEditor(text: $jsScript).font(Font.caption.monospacedDigit()).frame(minHeight: 60).padding(8)
                .background(Color(.systemGray6)).cornerRadius(8).padding(.horizontal)
            Button("Execute") {
                Task { do { jsResult = try await coordinator.executeJS(jsScript) } catch { jsResult = "Error: \(error.localizedDescription)" } }
            }
            if !jsResult.isEmpty {
                ScrollView { Text(jsResult).font(Font.caption.monospacedDigit()).padding() }
                    .frame(maxHeight: 200).background(Color(.systemGray6)).cornerRadius(8).padding(.horizontal)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func pageInfoSheet() -> some View {
        Form {
            Section(header: Text("Page Info")) {
                HStack { Text("Title"); Spacer(); Text(coordinator.pageTitle).foregroundColor(.secondary) }
                HStack { Text("URL"); Spacer(); Text(coordinator.currentURL?.absoluteString ?? "-").foregroundColor(.secondary).lineLimit(1) }
                HStack { Text("Loading"); Spacer(); Text(coordinator.isLoading ? "Yes" : "No").foregroundColor(.secondary) }
            }
        }
    }
}
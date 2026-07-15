import WebKit
import SwiftUI

/// Coordinator for WKWebView — handles navigation, content extraction, JS execution, and screenshots.
/// Inspired by Minis' BrowserUseOffloadBridge pattern.
@MainActor
final class WebViewCoordinator: NSObject, ObservableObject {
    
    private(set) var webView: WKWebView?
    private var customUserAgent: String?
    private var pageLoadContinuation: CheckedContinuation<Void, Error>?
    
    @Published var isLoading = false
    @Published var currentURL: URL?
    @Published var pageTitle = ""
    @Published var canGoBack = false
    @Published var canGoForward = false
    
    // MARK: - Configuration
    
    func bind(to webView: WKWebView) {
        self.webView = webView
        webView.navigationDelegate = self
        webView.uiDelegate = self
        if let ua = customUserAgent { webView.customUserAgent = ua }
    }
    
    func setCustomUserAgent(_ ua: String) {
        customUserAgent = ua
        webView?.customUserAgent = ua
    }
    
    func navigate(to url: URL) {
        webView?.load(URLRequest(url: url))
    }
    
    /// Navigate and wait for the page to finish loading
    func navigateAndWait(url: URL) async throws {
        return try await withCheckedThrowingContinuation { c in
            self.pageLoadContinuation = c
            webView?.load(URLRequest(url: url))
            Task {
                try? await Task.sleep(for: .seconds(15))
                if self.pageLoadContinuation != nil {
                    self.pageLoadContinuation?.resume()
                    self.pageLoadContinuation = nil
                }
            }
        }
    }
    
    /// Extract readable text from the current page
    func loadAndExtract(url: URL) async throws -> String {
        try await navigateAndWait(url: url)
        return try await withCheckedThrowingContinuation { c in
            webView?.evaluateJavaScript("document.body.innerText") { result, error in
                if let e = error { c.resume(throwing: e) }
                else if let text = result as? String {
                    let cleaned = text
                        .components(separatedBy: .newlines)
                        .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                        .joined(separator: "\n")
                    c.resume(returning: cleaned)
                } else { c.resume(returning: "(empty page)") }
            }
        }
    }
    
    /// Execute JavaScript and return the result
    func executeJS(_ script: String) async throws -> String {
        guard let wv = webView else { throw NSError(domain: "Angles", code: -1, userInfo: [NSLocalizedDescriptionKey: "WebView not ready"]) }
        return try await withCheckedThrowingContinuation { c in
            wv.evaluateJavaScript(script) { result, error in
                if let e = error { c.resume(throwing: e) }
                else { c.resume(returning: "\(result ?? "undefined")") }
            }
        }
    }
    
    /// Capture screenshot of the web view
    func captureScreenshot(fullPage: Bool = false) async throws -> UIImage {
        guard let wv = webView else { throw NSError(domain: "Angles", code: -1) }
        
        if fullPage {
            let snapshotConfig = WKSnapshotConfiguration()
            snapshotConfig.rect = CGRect(origin: .zero, size: wv.scrollView.contentSize)
            return try await wv.takeSnapshot(configuration: snapshotConfig)
        } else {
            let renderer = UIGraphicsImageRenderer(bounds: wv.bounds)
            return renderer.image { ctx in
                wv.drawHierarchy(in: wv.bounds, afterScreenUpdates: true)
            }
        }
    }
    
    // MARK: - Navigation Actions
    
    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }
    func stopLoading() { webView?.stopLoading() }
}

// MARK: - WKNavigationDelegate

extension WebViewCoordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation n: WKNavigation!) {
        isLoading = true
    }
    func webView(_ webView: WKWebView, didFinish n: WKNavigation!) {
        isLoading = false
        currentURL = webView.url
        pageTitle = webView.title ?? ""
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        pageLoadContinuation?.resume()
        pageLoadContinuation = nil
    }
    func webView(_ webView: WKWebView, didFail n: WKNavigation!, withError err: Error) {
        isLoading = false
        pageLoadContinuation?.resume(throwing: err)
        pageLoadContinuation = nil
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError err: Error) {
        isLoading = false
        pageLoadContinuation?.resume(throwing: err)
        pageLoadContinuation = nil
    }
}

// MARK: - WKUIDelegate

extension WebViewCoordinator: WKUIDelegate {
    func webView(_ wv: WKWebView, createWebViewWith config: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if action.targetFrame == nil { wv.load(action.request) }
        return nil
    }
}

// MARK: - UIViewRepresentable

struct WebViewRepresentable: UIViewRepresentable {
    let coordinator: WebViewCoordinator
    var homeURL: URL?
    var userAgent: String?
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        wv.allowsLinkPreview = true
        if let ua = userAgent { wv.customUserAgent = ua }
        coordinator.bind(to: wv)
        if let home = homeURL { wv.load(URLRequest(url: home)) }
        return wv
    }
    func updateUIView(_: WKWebView, context: Context) {}
}
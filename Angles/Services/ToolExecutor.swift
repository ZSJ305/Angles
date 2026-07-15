import Foundation
import SwiftUI
import WebKit

/// Executes tool calls from the AI agent.
/// Inspired by Minis' bridge pattern — tools dispatch to UIKit/WebKit/SwiftData layers.
@MainActor
final class ToolExecutor: ObservableObject {
    
    var webViewCoordinator: WebViewCoordinator?
    
    /// Local memory store (survives app lifetime, persisted in UserDefaults)
    private var memory: [MemoryEntry] = []
    private let memoryKey = "angles_memory"
    
    init() {
        loadMemory()
    }
    
    func execute(name: String, arguments: [String: Any]) async throws -> String {
        switch name {
        case "file_create":     return try await fileCreate(arguments)
        case "file_write":      return try await fileWrite(arguments)
        case "file_read":       return try await fileRead(arguments)
        case "file_delete":     return try await fileDelete(arguments)
        case "file_list":       return try await fileList(arguments)
        case "file_move":       return try await fileMove(arguments)
        case "file_copy":       return try await fileCopy(arguments)
        case "web_browse":      return try await webBrowse(arguments)
        case "web_screenshot":  return try await webScreenshot(arguments)
        case "web_execute_js":  return try await webExecuteJS(arguments)
        case "web_get_page_info": return try await webGetPageInfo(arguments)
        case "shell_execute":   return try await shellExecute(arguments)
        case "memory_remember": return try await memoryRemember(arguments)
        case "memory_recall":   return try await memoryRecal(arguments)
        default: throw ToolError.unknownTool(name)
        }
    }
    
    // MARK: - Memory
    
    private func loadMemory() {
        guard let data = UserDefaults.standard.data(forKey: memoryKey),
              let entries = try? JSONDecoder().decode([MemoryEntry].self, from: data) else { return }
        memory = entries
    }
    
    private func saveMemory() {
        guard let data = try? JSONEncoder().encode(memory) else { return }
        UserDefaults.standard.set(data, forKey: memoryKey)
    }
    
    private func memoryRemember(_ args: [String: Any]) async throws -> String {
        guard let content = args["content"] as? String else { throw ToolError.missingArgument("content") }
        let category = args["category"] as? String ?? "general"
        memory.append(MemoryEntry(content: content, category: category))
        saveMemory()
        return "✅ Remembered: \"\(content.prefix(80))...\" in category: \(category)"
    }
    
    private func memoryRecal(_ args: [String: Any]) async throws -> String {
        guard let keywords = args["keywords"] as? String else { throw ToolError.missingArgument("keywords") }
        let category = args["category"] as? String
        let kw = keywords.lowercased().split(separator: " ")
        var results = memory.filter { entry in
            let match = kw.allSatisfy { k in entry.content.lowercased().contains(k) || entry.category.lowercased().contains(k) }
            if let cat = category { return match && entry.category.lowercased() == cat.lowercased() }
            return match
        }
        results.sort(by: { $0.timestamp > $1.timestamp })
        if results.isEmpty { return "No memories found for: \(keywords)" }
        return results.prefix(5).map { "[\($0.category)] \($0.content.prefix(100))" }.joined(separator: "\n")
    }
    
    // MARK: - File Ops
    
    private func resolvePath(_ path: String) -> URL {
        path.hasPrefix("/") 
            ? FileManager.documentsDirectory.appendingPathComponent(String(path.dropFirst()))
            : FileManager.documentsDirectory.appendingPathComponent(path)
    }
    
    private func fileCreate(_ args: [String: Any]) async throws -> String {
        guard let path = args["path"] as? String, let content = args["content"] as? String
        else { throw ToolError.missingArgument("path/content") }
        let url = resolvePath(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return "✅ File created: \(path) (\(content.count) bytes)"
    }
    
    private func fileWrite(_ args: [String: Any]) async throws -> String {
        guard let path = args["path"] as? String, let content = args["content"] as? String
        else { throw ToolError.missingArgument("path/content") }
        try content.write(to: resolvePath(path), atomically: true, encoding: .utf8)
        return "✅ File written: \(path) (\(content.count) bytes)"
    }
    
    private func fileRead(_ args: [String: Any]) async throws -> String {
        guard let path = args["path"] as? String else { throw ToolError.missingArgument("path") }
        let maxLen = args["max_length"] as? Int ?? 10000
        let content = try String(contentsOf: resolvePath(path), encoding: .utf8)
        if content.count > maxLen {
            return String(content.prefix(maxLen)) + "\n... (truncated, \(content.count - maxLen) more chars)"
        }
        return content
    }
    
    private func fileDelete(_ args: [String: Any]) async throws -> String {
        guard let path = args["path"] as? String else { throw ToolError.missingArgument("path") }
        let recursive = args["recursive"] as? Bool ?? false
        let url = resolvePath(path)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        else { return "⚠️ Not found: \(path)" }
        if isDir.boolValue && !recursive { return "⚠️ Use recursive=true for directories: \(path)" }
        try FileManager.default.removeItem(at: url)
        return "✅ Deleted: \(path)"
    }
    
    private func fileList(_ args: [String: Any]) async throws -> String {
        guard let path = args["path"] as? String else { throw ToolError.missingArgument("path") }
        let recursive = args["recursive"] as? Bool ?? false
        let url = resolvePath(path), fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return "⚠️ Not found: \(path)" }
        
        if recursive {
            guard let e = fm.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey])
            else { return "⚠️ Cannot read: \(path)" }
            var lines: [String] = []
            for case let u as URL in e {
                var d: ObjCBool = false; fm.fileExists(atPath: u.path, isDirectory: &d)
                lines.append("\(d.boolValue ? "📁" : "📄") \(u.path.replacingOccurrences(of: url.path+"/", with: ""))")
            }
            return lines.joined(separator: "\n")
        } else {
            let items = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
            return items.map { u in
                var d: ObjCBool = false; fm.fileExists(atPath: u.path, isDirectory: &d)
                return "\(d.boolValue ? "📁" : "📄") \(u.lastPathComponent)"
            }.sorted().joined(separator: "\n")
        }
    }
    
    private func fileMove(_ args: [String: Any]) async throws -> String {
        guard let src = args["source"] as? String, let dst = args["destination"] as? String
        else { throw ToolError.missingArgument("source/destination") }
        try FileManager.default.createDirectory(at: resolvePath(dst).deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: resolvePath(src), to: resolvePath(dst))
        return "✅ Moved: \(src) → \(dst)"
    }
    
    private func fileCopy(_ args: [String: Any]) async throws -> String {
        guard let src = args["source"] as? String, let dst = args["destination"] as? String
        else { throw ToolError.missingArgument("source/destination") }
        try FileManager.default.createDirectory(at: resolvePath(dst).deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: resolvePath(src), to: resolvePath(dst))
        return "✅ Copied: \(src) → \(dst)"
    }
    
    // MARK: - Web Ops
    
    private func webBrowse(_ args: [String: Any]) async throws -> String {
        guard let urlStr = args["url"] as? String, let url = URL(string: urlStr)
        else { throw ToolError.missingArgument("url") }
        if let ua = args["user_agent"] as? String { await webViewCoordinator?.setCustomUserAgent(ua) }
        return try await webViewCoordinator?.loadAndExtract(url: url) ?? "⚠️ Browser unavailable"
    }
    
    private func webScreenshot(_ args: [String: Any]) async throws -> String {
        let fullPage = args["full_page"] as? Bool ?? false
        guard let img = try await webViewCoordinator?.captureScreenshot(fullPage: fullPage)
        else { return "⚠️ Browser unavailable" }
        let fn = "screenshot_\(Int(Date().timeIntervalSince1970)).png"
        try img.pngData()?.write(to: FileManager.documentsDirectory.appendingPathComponent(fn))
        return "📸 Saved: \(fn) (\(img.size.width)×\(img.size.height))"
    }
    
    private func webExecuteJS(_ args: [String: Any]) async throws -> String {
        guard let script = args["script"] as? String else { throw ToolError.missingArgument("script") }
        return try await withCheckedThrowingContinuation { cont in
            webViewCoordinator?.webView?.evaluateJavaScript(script) { result, error in
                if let e = error { cont.resume(throwing: e) }
                else { cont.resume(returning: "\(result ?? "undefined")") }
            }
        }
    }
    
    private func webGetPageInfo(_ args: [String: Any]) async throws -> String {
        guard let c = webViewCoordinator else { return "⚠️ Browser unavailable" }
        return "📄 \(c.pageTitle)\n🔗 \(c.currentURL?.absoluteString ?? "none")\n⏳ Loading: \(c.isLoading ? "yes" : "no")"
    }
    
    // MARK: - Shell
    
    private func shellExecute(_ args: [String: Any]) async throws -> String {
        guard let cmd = args["command"] as? String else { throw ToolError.missingArgument("command") }
        let timeout = args["timeout"] as? Int ?? 30
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/sh"); p.arguments = ["-c", cmd]
        let out = Pipe(), err = Pipe(); p.standardOutput = out; p.standardError = err
        try p.run()
        Task { try? await Task.sleep(for: .seconds(timeout)); if p.isRunning { p.terminate() } }
        p.waitUntilExit()
        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        var r = stdout; if !stderr.isEmpty { r += "\n[stderr]\n\(stderr)" }
        r += "\nExit: \(p.terminationStatus)"; return r
    }
}

// MARK: - Memory Model

struct MemoryEntry: Codable, Identifiable {
    var id = UUID()
    var content: String
    var category: String
    var timestamp = Date()
}

enum ToolError: LocalizedError {
    case unknownTool(String), missingArgument(String)
    var errorDescription: String? {
        switch self {
        case .unknownTool(let n): return "Unknown tool: \(n)"
        case .missingArgument(let a): return "Missing: \(a)"
        }
    }
}

extension FileManager {
    static let documentsDirectory: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }()
}
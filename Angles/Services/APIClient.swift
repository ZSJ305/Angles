import Foundation

/// Multi-provider API client supporting OpenAI-compatible, Gemini-native, and Claude-native request formats.
/// Inspired by Minis' multi-provider routing system.
final class APIClient: ObservableObject {
    
    private var config: ProviderConfig
    private let urlSession: URLSession
    
    init(config: ProviderConfig) {
        self.config = config
        let s = URLSessionConfiguration.default
        s.timeoutIntervalForRequest = 120
        s.timeoutIntervalForResource = 300
        self.urlSession = URLSession(configuration: s)
    }
    
    func updateConfig(_ new: ProviderConfig) { config = new }
    
    // MARK: - Streaming Chat
    
    func sendStreaming(
        messages: [ChatMessage],
        systemPrompt: String,
        tools: [ToolDefinition],
        onToken: @escaping (String) -> Void,
        onToolCall: @escaping (String, [String: Any]) async throws -> String,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        Task {
            do {
                switch config.providerType.requestFormat {
                case .openAICompatible:
                    try await streamOpenAI(messages: messages, systemPrompt: systemPrompt, tools: tools, onToken: onToken, onToolCall: onToolCall, onComplete: onComplete, onError: onError)
                case .geminiNative:
                    try await streamGemini(messages: messages, systemPrompt: systemPrompt, tools: tools, onToken: onToken, onToolCall: onToolCall, onComplete: onComplete, onError: onError)
                case .claudeNative:
                    try await streamClaude(messages: messages, systemPrompt: systemPrompt, tools: tools, onToken: onToken, onToolCall: onToolCall, onComplete: onComplete, onError: onError)
                }
            } catch {
                onError(error)
            }
        }
    }
    
    // MARK: - OpenAI-Compatible (OpenRouter, OpenAI, Grok, DeepSeek, Custom)
    
    private func streamOpenAI(
        messages: [ChatMessage], systemPrompt: String, tools: [ToolDefinition],
        onToken: @escaping (String) -> Void,
        onToolCall: @escaping (String, [String: Any]) async throws -> String,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) async throws {
        let url = URL(string: "\(config.baseURL)/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        if config.providerType == .openRouter {
            req.setValue("Angles/1.0", forHTTPHeaderField: "HTTP-Referer")
            req.setValue("Angles iOS App", forHTTPHeaderField: "X-Title")
        }
        
        var msgArr: [[String: Any]] = [["role": "system", "content": systemPrompt]]
        for msg in messages {
            var entry: [String: Any] = ["role": msg.role.rawValue, "content": msg.content]
            if let tcs = msg.toolCalls, !tcs.isEmpty {
                entry.removeValue(forKey: "content")
                entry["tool_calls"] = tcs.map { tc in
                    ["id": tc.id, "type": "function", "function": ["name": tc.name, "arguments": tc.arguments]]
                }
            }
            if let trs = msg.toolResults, !trs.isEmpty {
                entry["role"] = "tool"
                entry["tool_call_id"] = trs.first!.callID
                entry["content"] = trs.first!.result
            }
            msgArr.append(entry)
        }
        
        var body: [String: Any] = [
            "model": config.modelID,
            "messages": msgArr,
            "max_tokens": config.maxTokens,
            "stream": true
        ]
        
        if !tools.isEmpty {
            body["tools"] = tools.map { [
                "type": "function",
                "function": ["name": $0.name, "description": $0.description, "parameters": $0.parameters.asDict]
            ] }
            body["tool_choice"] = "auto"
        }
        
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (bytes, _) = try await urlSession.bytes(for: req)
        
        var toolCallBuf: [String: (String, String, String)] = [:] // idx -> (id, name, args)
        
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let ds = String(line.dropFirst(6))
            if ds == "[DONE]" { onComplete(); return }
            guard let data = ds.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let choice = choices.first else { continue }
            
            if let delta = choice["delta"] as? [String: Any] {
                if let content = delta["content"] as? String { onToken(content) }
                if let tcs = delta["tool_calls"] as? [[String: Any]] {
                    for tc in tcs {
                        let idx = "\(tc["index"] as? Int ?? 0)"
                        var cur = toolCallBuf[idx] ?? ("", "", "")
                        if let id = tc["id"] as? String { cur.0 = id }
                        if let fn = tc["function"] as? [String: Any] {
                            if let n = fn["name"] as? String { cur.1 = n }
                            if let a = fn["arguments"] as? String { cur.2 += a }
                        }
                        toolCallBuf[idx] = cur
                    }
                }
            }
            
            if let fr = choice["finish_reason"] as? String, fr == "tool_calls" {
                for (_, tc) in toolCallBuf.sorted(by: { Int($0.key)! < Int($1.key)! }) {
                    onToken("\n🔧 Calling: \(tc.1)\n")
                    do {
                        let args = (try? JSONSerialization.jsonObject(with: tc.2.data(using: .utf8)!) as? [String: Any]) ?? [:]
                        let result = try await onToolCall(tc.1, args)
                        onToken("\n\(result)\n")
                    } catch {
                        onToken("\n❌ Tool error: \(error.localizedDescription)\n")
                    }
                }
                toolCallBuf = [:]
            }
        }
        onComplete()
    }
    
    // MARK: - Gemini Native
    
    private func streamGemini(
        messages: [ChatMessage], systemPrompt: String, tools: [ToolDefinition],
        onToken: @escaping (String) -> Void,
        onToolCall: @escaping (String, [String: Any]) async throws -> String,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) async throws {
        let urlStr = "\(config.baseURL)/models/\(config.modelID):streamGenerateContent?alt=sse&key=\(config.apiKey)"
        let url = URL(string: urlStr)!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var contents: [[String: Any]] = []
        for msg in messages where msg.role != .system {
            var entry: [String: Any] = [
                "role": msg.role == .assistant ? "model" : "user",
                "parts": [["text": msg.content]]
            ]
            if let tcs = msg.toolCalls, !tcs.isEmpty {
                var parts: [[String: Any]] = []
                for tc in tcs {
                    parts.append(["functionCall": ["name": tc.name, "args": (try? JSONSerialization.jsonObject(with: tc.arguments.data(using: .utf8)!)) ?? [:]]])
                }
                entry["parts"] = parts
            }
            if let trs = msg.toolResults, !trs.isEmpty {
                entry["parts"] = [["functionResponse": ["name": msg.toolCalls?.first?.name ?? "", "response": ["result": trs.first!.result]]]]
                entry["role"] = "tool"
            }
            contents.append(entry)
        }
        
        var body: [String: Any] = [
            "systemInstruction": ["parts": [["text": systemPrompt]]],
            "contents": contents,
            "generationConfig": ["maxOutputTokens": config.maxTokens, "temperature": 0.7]
        ]
        
        if !tools.isEmpty {
            body["tools"] = [["functionDeclarations": tools.map { tool in
                var decl: [String: Any] = ["name": tool.name, "description": tool.description]
                if let props = tool.parameters.properties {
                    decl["parameters"] = ["type": tool.parameters.type, "properties": props.mapValues { $0.asDict }, "required": tool.parameters.required ?? []]
                }
                return decl
            }]]
        }
        
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (bytes, _) = try await urlSession.bytes(for: req)
        
        for try await line in bytes.lines {
            guard line.hasPrefix("data: "), let ds = line.dropFirst(6).data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: ds) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let c = candidates.first, let content = c["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else { continue }
            
            for part in parts {
                if let text = part["text"] as? String { onToken(text) }
                if let fc = part["functionCall"] as? [String: Any],
                   let name = fc["name"] as? String {
                    let args = fc["args"] as? [String: Any] ?? [:]
                    onToken("\n🔧 Calling: \(name)\n")
                    do {
                        let result = try await onToolCall(name, args)
                        onToken("\n\(result)\n")
                    } catch {
                        onToken("\n❌ Tool error: \(error.localizedDescription)\n")
                    }
                }
            }
        }
        onComplete()
    }
    
    // MARK: - Claude (Anthropic Messages API)
    
    private func streamClaude(
        messages: [ChatMessage], systemPrompt: String, tools: [ToolDefinition],
        onToken: @escaping (String) -> Void,
        onToolCall: @escaping (String, [String: Any]) async throws -> String,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) async throws {
        let url = URL(string: "\(config.baseURL)/messages")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        var msgArr: [[String: Any]] = []
        for msg in messages {
            var entry: [String: Any] = ["role": msg.role == .assistant ? "assistant" : "user"]
            // Claude needs consolidated messages — tools go in content array
            var contentArr: [[String: Any]] = []
            if !msg.content.isEmpty { contentArr.append(["type": "text", "text": msg.content]) }
            if let tcs = msg.toolCalls, !tcs.isEmpty {
                for tc in tcs {
                    contentArr.append(["type": "tool_use", "id": tc.id, "name": tc.name, "input": (try? JSONSerialization.jsonObject(with: tc.arguments.data(using: .utf8)!)) ?? [:]])
                }
            }
            if let trs = msg.toolResults, !trs.isEmpty {
                entry["role"] = "user"
                for tr in trs {
                    contentArr.append(["type": "tool_result", "tool_use_id": tr.callID, "content": tr.result])
                }
            }
            entry["content"] = contentArr
            msgArr.append(entry)
        }
        
        var body: [String: Any] = [
            "model": config.modelID,
            "system": systemPrompt,
            "messages": msgArr,
            "max_tokens": config.maxTokens,
            "stream": true
        ]
        
        if !tools.isEmpty {
            body["tools"] = tools.map { ["name": $0.name, "description": $0.description, "input_schema": $0.parameters.asDict] }
        }
        
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (bytes, _) = try await urlSession.bytes(for: req)
        
        var currentToolID = ""
        var currentToolName = ""
        var currentToolInput = ""
        var currentToolBuffer = ""
        
        for try await line in bytes.lines {
            guard line.hasPrefix("data: "), let ds = line.dropFirst(6).data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: ds) as? [String: Any],
                  let type = json["type"] as? String else { continue }
            
            switch type {
            case "content_block_start":
                if let cb = json["content_block"] as? [String: Any],
                   cb["type"] as? String == "tool_use",
                   let id = cb["id"] as? String,
                   let name = cb["name"] as? String {
                    currentToolID = id; currentToolName = name; currentToolInput = ""
                    onToken("\n🔧 Calling: \(name)\n")
                }
            case "content_block_delta":
                if let delta = json["delta"] as? [String: Any] {
                    if let text = delta["text"] as? String { onToken(text) }
                    if let input = delta["partial_json"] as? String { currentToolInput += input }
                }
            case "content_block_stop":
                if !currentToolName.isEmpty {
                    let args = (try? JSONSerialization.jsonObject(with: currentToolInput.data(using: .utf8)!)) as? [String: Any] ?? [:]
                    do {
                        let result = try await onToolCall(currentToolName, args)
                        onToken("\n\(result)\n")
                    } catch {
                        onToken("\n❌ Tool error: \(error.localizedDescription)\n")
                    }
                    currentToolName = ""; currentToolID = ""
                }
            case "message_stop":
                onComplete(); return
            default: break
            }
        }
        onComplete()
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidResponse(String)
    case invalidToolArguments(String)
    case networkError(Error)
    case missingAPIKey
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse(let m): return "Invalid API response: \(m)"
        case .invalidToolArguments(let a): return "Failed to parse tool arguments: \(a)"
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .missingAPIKey: return "API key not configured"
        }
    }
}", "path": "/var/minis/mounts/angles/Angles/Angles/Services/APIClient.swift", "tool_title": "升级 APIClient — 三种协议：OpenAI / Gemini / Claude"}
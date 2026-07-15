import Foundation

/// Defines the tool capabilities exposed to the AI agent.
/// Inspired by Minis' tool system — file ops, web browse, shell, JS execution, memory, and more.
struct ToolDefinition: Codable, Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let parameters: JSONSchema
    
    static let allTools: [ToolDefinition] = [
        .createFile, .writeFile, .readFile, .deleteFile, .listDirectory,
        .moveFile, .copyFile,
        .webBrowse, .webScreenshot, .webExecuteJS, .webGetPageInfo,
        .shellExecute,
        .remember, .recall,
    ]
    
    // MARK: - File Operations
    
    static let createFile = ToolDefinition(
        name: "file_create",
        description: "Create a new file with specified content. Creates parent directories if needed.",
        parameters: JSONSchema(type: "object", properties: [
            "path": JSONSchema(type: "string", description: "Absolute path for the new file"),
            "content": JSONSchema(type: "string", description: "Content to write into the file"),
        ], required: ["path", "content"])
    )
    
    static let writeFile = ToolDefinition(
        name: "file_write",
        description: "Write or overwrite content to an existing file.",
        parameters: JSONSchema(type: "object", properties: [
            "path": JSONSchema(type: "string", description: "Path to the file"),
            "content": JSONSchema(type: "string", description: "Content to write"),
        ], required: ["path", "content"])
    )
    
    static let readFile = ToolDefinition(
        name: "file_read",
        description: "Read the contents of a file and return it as text.",
        parameters: JSONSchema(type: "object", properties: [
            "path": JSONSchema(type: "string", description: "Path to the file to read"),
            "max_length": JSONSchema(type: "integer", description: "Max characters to return (default: 10000)"),
        ], required: ["path"])
    )
    
    static let deleteFile = ToolDefinition(
        name: "file_delete",
        description: "Delete a file or directory at the specified path.",
        parameters: JSONSchema(type: "object", properties: [
            "path": JSONSchema(type: "string", description: "Path to delete"),
            "recursive": JSONSchema(type: "boolean", description: "If true, delete directories recursively"),
        ], required: ["path"])
    )
    
    static let listDirectory = ToolDefinition(
        name: "file_list",
        description: "List files and directories at a given path. Use recursive=true for deep listing.",
        parameters: JSONSchema(type: "object", properties: [
            "path": JSONSchema(type: "string", description: "Directory path to list"),
            "recursive": JSONSchema(type: "boolean", description: "If true, list recursively"),
        ], required: ["path"])
    )
    
    static let moveFile = ToolDefinition(
        name: "file_move",
        description: "Move or rename a file or directory from source to destination.",
        parameters: JSONSchema(type: "object", properties: [
            "source": JSONSchema(type: "string", description: "Source path"),
            "destination": JSONSchema(type: "string", description: "Destination path"),
        ], required: ["source", "destination"])
    )
    
    static let copyFile = ToolDefinition(
        name: "file_copy",
        description: "Copy a file from source to destination.",
        parameters: JSONSchema(type: "object", properties: [
            "source": JSONSchema(type: "string", description: "Source path"),
            "destination": JSONSchema(type: "string", description: "Destination path"),
        ], required: ["source", "destination"])
    )
    
    // MARK: - Web Operations
    
    static let webBrowse = ToolDefinition(
        name: "web_browse",
        description: "Navigate to a URL in the built-in browser and return the page's readable text content. The browser stays open so you can chain multiple actions (screenshot, JS, navigate again).",
        parameters: JSONSchema(type: "object", properties: [
            "url": JSONSchema(type: "string", description: "URL to navigate to"),
            "user_agent": JSONSchema(type: "string", description: "Custom User-Agent string (optional). Default: Mobile Safari."),
        ], required: ["url"])
    )
    
    static let webScreenshot = ToolDefinition(
        name: "web_screenshot",
        description: "Take a screenshot of the current web page in the built-in browser. Supports full page capture.",
        parameters: JSONSchema(type: "object", properties: [
            "full_page": JSONSchema(type: "boolean", description: "If true, capture the full scrollable page"),
        ], required: [])
    )
    
    static let webExecuteJS = ToolDefinition(
        name: "web_execute_js",
        description: "Execute JavaScript on the current page and return the result. Use for scraping dynamic content, clicking elements, or extracting structured data.",
        parameters: JSONSchema(type: "object", properties: [
            "script": JSONSchema(type: "string", description: "JavaScript code to execute. Use return to send data back."),
        ], required: ["script"])
    )
    
    static let webGetPageInfo = ToolDefinition(
        name: "web_get_page_info",
        description: "Get metadata about the current web page: title, URL, scroll position, loading status.",
        parameters: JSONSchema(type: "object", properties: [:], required: [])
    )
    
    // MARK: - Shell
    
    static let shellExecute = ToolDefinition(
        name: "shell_execute",
        description: "Execute a shell command and return stdout, stderr, and exit code. Commands run in an isolated process with a configurable timeout.",
        parameters: JSONSchema(type: "object", properties: [
            "command": JSONSchema(type: "string", description: "The shell command to run"),
            "timeout": JSONSchema(type: "integer", description: "Timeout in seconds (default: 30)"),
        ], required: ["command"])
    )
    
    // MARK: - Memory
    
    static let remember = ToolDefinition(
        name: "memory_remember",
        description: "Save a piece of information to persistent memory. Use for remembering user preferences, project context, or important facts across sessions.",
        parameters: JSONSchema(type: "object", properties: [
            "content": JSONSchema(type: "string", description: "The content to remember"),
            "category": JSONSchema(type: "string", description: "Optional category tag (e.g. 'preference', 'project', 'note')"),
        ], required: ["content"])
    )
    
    static let recall = ToolDefinition(
        name: "memory_recall",
        description: "Search and recall previously stored memories by keywords.",
        parameters: JSONSchema(type: "object", properties: [
            "keywords": JSONSchema(type: "string", description: "Space-separated keywords to search for"),
            "category": JSONSchema(type: "string", description: "Optional category filter"),
        ], required: ["keywords"])
    )
}

/// Simple JSON Schema representation for OpenAI-compatible tool parameters.
struct JSONSchema: Codable {
    var type: String
    var properties: [String: JSONSchema]?
    var description: String?
    var required: [String]?
    
    init(type: String, properties: [String: JSONSchema]? = nil, description: String? = nil, required: [String]? = nil) {
        self.type = type
        self.properties = properties
        self.description = description
        self.required = required
    }
    
    var asDict: [String: Any] {
        var dict: [String: Any] = ["type": type]
        if let props = properties {
            dict["properties"] = props.mapValues { $0.asDict }
        }
        if let desc = description {
            dict["description"] = desc
        }
        if let req = required {
            dict["required"] = req
        }
        return dict
    }
}
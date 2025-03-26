import Foundation

/// A registry for managing OpenAI-compatible tools and handling tool calls
public class OpenAIToolRegistry {
    private let bridge = OpenAIBridge()
    private var tools: [String: MCPTool] = [:]
    private var toolSchemas: [String: String] = [:]

    /// Register an MCP tool with its JSON schema
    /// - Parameters:
    ///   - tool: The MCP tool to register
    ///   - schema: The JSON schema describing the tool
    public func registerTool(_ tool: MCPTool, schema: String) {
        let sanitizedName = sanitizeToolName(tool.methodName)
        tools[sanitizedName] = tool
        toolSchemas[sanitizedName] = schema
    }

    /// Get all registered tools in OpenAI function format
    /// - Returns: Array of OpenAI function definitions
    public func getOpenAIFunctions() throws -> [OpenAIBridge.OpenAIFunction] {
        return try toolSchemas.map { try bridge.convertToOpenAIFunction($0.value) }
    }

    /// Handle an OpenAI tool call by executing the corresponding MCP tool
    /// - Parameter toolCall: The OpenAI tool call to handle
    /// - Returns: The tool response in OpenAI format
    public func handleToolCall(_ toolCall: OpenAIBridge.ToolCall) async throws -> [String: String] {
        let (name, params) = try bridge.convertToMCPCall(toolCall)

        guard let tool = tools[name] else {
            throw MCPError.toolNotFound
        }

        let response = try await tool.handle(params: params)
        return bridge.convertToOpenAIResponse(response, toolCallId: toolCall.id)
    }

    /// Handle multiple OpenAI tool calls
    /// - Parameter toolCalls: Array of OpenAI tool calls to handle
    /// - Returns: Array of tool responses in OpenAI format
    public func handleToolCalls(_ toolCalls: [OpenAIBridge.ToolCall]) async throws -> [[String: String]] {
        var responses: [[String: String]] = []

        for toolCall in toolCalls {
            let response = try await handleToolCall(toolCall)
            responses.append(response)
        }

        return responses
    }

    /// Sanitize tool name for OpenAI compatibility
    private func sanitizeToolName(_ name: String) -> String {
        return name.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
    }
}

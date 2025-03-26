import Foundation
import MLX

/// A registry for managing MLX-compatible tools and handling tool calls
public class MLXToolRegistry: ToolRegistry {
    private let bridge = MLXBridge()
    private var tools: [String: MCPTool] = [:]

    /// Initialize an empty MLX tool registry
    override public init() {}

    /// Register an MCP tool with its JSON schema
    /// - Parameters:
    ///   - tool: The MCP tool to register
    ///   - schema: The JSON schema describing the tool
    public func registerTool(_ tool: MCPTool) {
        // Store the original tool name
        let originalName = tool.methodName
        let sanitizedName = sanitizeToolName(originalName)

        tools[sanitizedName] = tool
    }

    /// Get all registered tools in MLX function format
    /// - Returns: Array of MLX function definitions as [String: JSON] for MLX Swift format
    public func getMLXFunctions() throws -> [[String: JSON]] {
        try tools.map {
            let mlxFunction = try bridge.convertToMLXFunction($0.value.toolSchema)

            // Convert the MLXFunction to a dictionary
            let function: [String: JSON] = [
                "type": .string(mlxFunction.type),
                "function": .object([
                    "name": .string(mlxFunction.function.name),
                    "description": .string(mlxFunction.function.description),
                    "parameters": .object(mlxFunction.function.parameters),
                ]),
            ]

            return function
        }
    }

    /// Process MLX model output to find and execute tool calls
    /// - Parameters:
    ///   - modelOutput: The raw text output from the MLX model
    /// - Returns: A tuple containing processed text and whether tools were called
    public func processToolCalls(_ modelOutput: String) async throws -> (String, Bool) {
        // Extract tool calls from the model output
        let toolCalls = try bridge.extractToolCalls(from: modelOutput)

        if toolCalls.isEmpty {
            return (modelOutput, false)
        }

        var processedText = modelOutput
        var toolResponses: [String] = []

        // Process each tool call
        for toolCall in toolCalls {
            let (name, params) = try bridge.convertToMCPCall(toolCall)

            guard let tool = tools[name] else {
                throw MCPError.toolNotFound
            }

            // Execute the tool
            let response = try await tool.handle(params: params)

            // Format the response for the model
            let formattedResponse = bridge.formatToolResponse(response, toolName: name)
            toolResponses.append(formattedResponse)
        }

        // Append tool responses to the model output
        if !toolResponses.isEmpty {
            processedText += "\n\n" + toolResponses.joined(separator: "\n\n")
        }

        return (processedText, !toolResponses.isEmpty)
    }

    /// Look up a tool by its method name
    /// - Parameter methodName: The method name to look up
    /// - Returns: The corresponding MCPTool, if found
    override public func tool(for methodName: String) -> MCPTool? {
        let sanitizedName = sanitizeToolName(methodName)
        return tools[sanitizedName]
    }

    /// Sanitize tool name for MLX compatibility
    private func sanitizeToolName(_ name: String) -> String {
        return name.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
    }
}

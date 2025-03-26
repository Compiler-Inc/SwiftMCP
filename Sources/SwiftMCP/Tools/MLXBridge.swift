import Foundation
import MLX

/// A bridge to convert MCP tools to MLX-compatible function definitions
public class MLXBridge {
    /// Represents an MLX function definition
    public struct MLXFunction: Codable {
        /// Change type from let property to computed property
        public var type: String { "function" }
        public let function: FunctionDefinition

        public init(function: FunctionDefinition) {
            self.function = function
        }

        public struct FunctionDefinition: Codable {
            public let name: String
            public let description: String
            public let parameters: [String: JSON]

            public init(name: String, description: String, parameters: [String: JSON]) {
                self.name = name
                self.description = description
                self.parameters = parameters
            }
        }
    }

    /// Represents an MLX tool call made by the model
    public struct ToolCall: Codable {
        public let name: String
        public let arguments: [String: JSON]

        public init(name: String, arguments: [String: JSON]) {
            self.name = name
            self.arguments = arguments
        }
    }

    /// Extract tool calls from MLX model output text
    /// - Parameter text: The raw output text from the MLX model
    /// - Returns: An array of extracted tool calls
    public func extractToolCalls(from text: String) throws -> [ToolCall] {
        // MLX uses <tool_call> JSON </tool_call> format, similar to the PR documentation
        let pattern = #"<tool_call>\s*({.*?})\s*</tool_call>"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)

        var toolCalls: [ToolCall] = []

        for match in matches {
            if let captureRange = Range(match.range(at: 1), in: text) {
                let jsonString = String(text[captureRange])

                guard let jsonData = jsonString.data(using: .utf8) else {
                    throw MCPError.toolError("Invalid tool call format - could not convert to data")
                }

                // Try to decode directly as [String: JSON]
                do {
                    let json = try JSONDecoder().decode([String: JSON].self, from: jsonData)

                    // Get name from the JSON using pattern matching
                    guard let nameJson = json["name"], case let .string(name) = nameJson else {
                        throw MCPError.toolError("Invalid tool call format - missing name")
                    }

                    // Get arguments from the JSON using pattern matching
                    guard let argsJson = json["arguments"], case let .object(arguments) = argsJson else {
                        throw MCPError.toolError("Invalid tool call format - missing or invalid arguments")
                    }

                    let toolCall = ToolCall(name: name, arguments: arguments)
                    toolCalls.append(toolCall)
                } catch {
                    throw MCPError.toolError("Failed to parse tool call: \(error.localizedDescription)")
                }
            }
        }

        return toolCalls
    }

    /// Convert MLX tool call to MCP format
    /// - Parameter toolCall: The MLX tool call to convert
    /// - Returns: A tuple with the tool name and parameters
    public func convertToMCPCall(_ toolCall: ToolCall) throws -> (name: String, params: [String: JSON]) {
        // Since we're already using [String: JSON], we just need to sanitize the name
        return (name: sanitizeToolName(toolCall.name), params: toolCall.arguments)
    }

    /// Convert an MCP tool JSON schema to MLX function format
    /// - Parameter jsonSchema: The JSON schema string from the MCP tool
    /// - Returns: An MLX function definition
    public func convertToMLXFunction(_ jsonSchema: String) throws -> MLXFunction {
        guard let data = jsonSchema.data(using: .utf8) else {
            throw MCPError.toolError("Invalid JSON schema format - could not convert to data")
        }

        // Try to decode the schema as a JSON object
        do {
            let json = try JSONDecoder().decode([String: JSON].self, from: data)

            // Extract function properties using pattern matching
            guard let functionJson = json["function"], case let .object(functionObj) = functionJson else {
                throw MCPError.toolError("Invalid JSON schema format - missing function object")
            }

            // Extract name using pattern matching
            guard let nameJson = functionObj["name"], case let .string(name) = nameJson else {
                throw MCPError.toolError("Invalid JSON schema format - missing name")
            }

            // Extract description using pattern matching
            guard let descJson = functionObj["description"], case let .string(description) = descJson else {
                throw MCPError.toolError("Invalid JSON schema format - missing description")
            }

            // Extract parameters using pattern matching
            guard let paramsJson = functionObj["parameters"], case let .object(parameters) = paramsJson else {
                throw MCPError.toolError("Invalid JSON schema format - missing parameters")
            }

            let functionDef = MLXFunction.FunctionDefinition(
                name: sanitizeToolName(name),
                description: description,
                parameters: parameters
            )

            return MLXFunction(function: functionDef)
        } catch {
            throw MCPError.toolError("Failed to parse JSON schema: \(error.localizedDescription)")
        }
    }

    /// Format MCP tool response for MLX consumption
    /// - Parameter response: The MCP tool response
    /// - Returns: A formatted JSON string response
    public func formatToolResponse(_ response: [String: JSON], toolName: String) -> String {
        let jsonString: String

        if let jsonData = try? JSONEncoder().encode(response),
           let string = String(data: jsonData, encoding: .utf8)
        {
            jsonString = string
        } else {
            jsonString = String(describing: response)
        }

        return """
        <tool_response>
        {"name": "\(toolName)", "content": \(jsonString)}
        </tool_response>
        """
    }

    /// Sanitize tool name for compatibility
    private func sanitizeToolName(_ name: String) -> String {
        return name.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
    }
}

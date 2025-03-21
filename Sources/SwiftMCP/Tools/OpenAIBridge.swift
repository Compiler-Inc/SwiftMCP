import Foundation

/// A bridge to convert MCP tools to OpenAI-compatible function definitions
public class OpenAIBridge {
    /// Represents an OpenAI function definition
    public struct OpenAIFunction: Codable {
        private(set) public var type: String = "function"
        public let function: FunctionDefinition
        
        enum CodingKeys: String, CodingKey {
            case type, function
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try container.decode(String.self, forKey: .type)
            function = try container.decode(FunctionDefinition.self, forKey: .function)
        }
        
        public init(function: FunctionDefinition) {
            self.function = function
        }
        
        public struct FunctionDefinition: Codable {
            public let name: String
            public let description: String
            public let parameters: String
            
            enum CodingKeys: String, CodingKey {
                case name, description, parameters
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(name, forKey: .name)
                try container.encode(description, forKey: .description)
                let parametersData = try JSONSerialization.data(withJSONObject: jsonToDictionary(parameters))
                let parametersString = String(data: parametersData, encoding: .utf8) ?? "{}"
                try container.encode(parametersString, forKey: .parameters)
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                name = try container.decode(String.self, forKey: .name)
                description = try container.decode(String.self, forKey: .description)
                let parametersString = try container.decode(String.self, forKey: .parameters)
                parameters = parametersString
            }
            
            public init(name: String, description: String, parameters: String) {
                self.name = name
                self.description = description
                self.parameters = parameters
            }
            
            func jsonToDictionary(_ json: String) -> [String: Any] {
                guard let data = json.data(using: .utf8),
                   let params = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    return [:]
                }
                
                return params
            }
        }
    }
    
    /// Represents an OpenAI tool call
    public struct ToolCall: Codable {
        public let id: String
        public let type: String
        public let function: FunctionCall
        
        public struct FunctionCall: Codable {
            public let name: String
            public let arguments: String
        }
    }
    
    /// Convert an MCP tool JSON schema to OpenAI function format
    /// - Parameter jsonSchema: The JSON schema string from the MCP tool
    /// - Returns: An OpenAI function definition
    public func convertToOpenAIFunction(_ jsonSchema: String) throws -> OpenAIFunction {
        guard let data = jsonSchema.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let function = json["function"] as? [String: Any],
              let name = function["name"] as? String,
              let description = function["description"] as? String,
              let parameters = function["parameters"] as? [String: Any] else {
            throw MCPError.toolError("Invalid JSON schema format")
        }
        
        let parametersData = try JSONSerialization.data(withJSONObject: parameters)
        let parametersString = String(data: parametersData, encoding: .utf8) ?? "{}"
        
        let functionDef = OpenAIFunction.FunctionDefinition(
            name: sanitizeToolName(name),
            description: description,
            parameters: parametersString
        )
        
        return OpenAIFunction(function: functionDef)
    }
    
    // Updated OpenAI tool call conversion to use JSON
    public func convertToMCPCall(_ toolCall: ToolCall) throws -> (name: String, params: [String: JSON]) {
        guard let data = toolCall.function.arguments.data(using: .utf8) else {
            throw MCPError.toolError("Invalid tool call arguments")
        }
        
        let params = try JSONDecoder().decode([String: JSON].self, from: data)
        return (name: toolCall.function.name, params: params)
    }
    
    /// Convert MCP tool response to OpenAI format
    /// - Parameters:
    ///   - response: The MCP tool response
    ///   - toolCallId: The OpenAI tool call ID
    /// - Returns: The formatted tool response
    public func convertToOpenAIResponse(_ response: [String: JSON], toolCallId: String) -> [String: String] {
        let content: String
        if let jsonData = try? JSONEncoder().encode(response),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            content = jsonString
        } else {
            content = String(describing: response)
        }
        
        return [
            "tool_call_id": toolCallId,
            "content": content
        ]
    }
    
    /// Sanitize tool name for OpenAI compatibility
    private func sanitizeToolName(_ name: String) -> String {
        return name.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
    }
}

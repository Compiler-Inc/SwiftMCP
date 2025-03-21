//
//  MCPClient.swift
//  SwiftMCP
//
//  Created by Atharva Vaidya on 3/20/25.
//

import Foundation

/// The main MCP client that handles JSON-RPC message routing and tool execution
public class MCPClient {
    /// The registry containing all available tools
    private let toolRegistry: ToolRegistry
    
    /// Handler for sending responses back to the client
    public typealias ResponseHandler = (String) -> Void
    private let responseHandler: ResponseHandler
    
    /// Initialize a new MCP client
    /// - Parameters:
    ///   - toolRegistry: Registry containing available tools
    ///   - responseHandler: Handler for sending responses back to the client
    public init(toolRegistry: ToolRegistry, responseHandler: @escaping ResponseHandler) {
        self.toolRegistry = toolRegistry
        self.responseHandler = responseHandler
    }

    /// Handle an incoming JSON-RPC message
    /// - Parameter data: Raw JSON data containing the request
    public func handleIncomingMessage(data: Data) async throws {
        do {
            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)
            
            // Lookup the tool associated with the method
            guard let tool = toolRegistry.tool(for: request.method) else {
                try sendErrorResponse(id: request.id, error: .toolNotFound)
                return
            }
            
            let result = try await tool.handle(params: request.params)
            try sendSuccessResponse(id: request.id, result: result)
        } catch {
            let rawJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let id = (rawJson?["id"] as? String) ?? "null"
            let error = MCPError.invalidRequest("Invalid JSON-RPC request format")
            try sendErrorResponse(id: id, error: error)
            throw error
        }
    }
    
    /// Send a success response
    private func sendSuccessResponse(id: String, result: [String: JSON]) throws {
        let response: [String: JSON] = [
            "jsonrpc": .string("2.0"),
            "id": .string(id),
            "result": .object(result)
        ]
        try sendResponse(response)
    }
    
    /// Send an error response
    private func sendErrorResponse(id: String?, error: MCPError) throws {
        let response: [String: JSON] = [
            "jsonrpc": .string("2.0"),
            "id": .string(id ?? "null"),
            "error": .object([
                "code": .number(Double(error.jsonRpcCode)),
                "message": .string(error.description)
            ])
        ]
        try sendResponse(response)
    }
    
    /// Serialize and send a response via the response handler
    private func sendResponse(_ response: [String: JSON]) throws {
        let jsonData = try JSONEncoder().encode(response)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw MCPError.invalidParams("Failed to serialize response to JSON")
        }
        responseHandler(jsonString)
    }
}

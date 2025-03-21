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
            // Use JSONDecoder to decode the request
            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)
            let result = try await handleRequest(request)
            sendSuccessResponse(id: request.id, result: result)
        } catch {
            // If decoding fails, attempt to get the ID from raw JSON
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                sendErrorResponse(id: json["id"] as? String, error: .invalidParams("Invalid JSON format"))
            } else {
                sendErrorResponse(id: nil, error: .invalidParams("Invalid JSON format"))
            }
        }
    }
    
    /// Handle a parsed JSON-RPC request
    private func handleRequest(_ request: JSONRPCRequest) async throws -> [String: Any] {
        // Lookup the tool associated with the method
        guard let tool = toolRegistry.tool(for: request.method) else {
            sendErrorResponse(id: request.id, error: .toolNotFound)
            return [:]
        }
        
        return try await tool.handle(params: request.params)
    }
    
    /// Send a success response
    private func sendSuccessResponse(id: String, result: Any) {
        let response: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "result": result
        ]
        sendResponse(response)
    }
    
    /// Send an error response
    private func sendErrorResponse(id: String?, error: MCPError) {
        let response: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id ?? "null",
            "error": [
                "code": error.jsonRpcCode,
                "message": error.description
            ]
        ]
        sendResponse(response)
    }
    
    /// Serialize and send a response via the response handler
    private func sendResponse(_ response: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: response, options: [.prettyPrinted])
            if let jsonString = String(data: data, encoding: .utf8) {
                responseHandler(jsonString)
            }
        } catch {
            print("Error serializing response: \(error)")
        }
    }
}

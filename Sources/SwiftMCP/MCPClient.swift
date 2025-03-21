//
//  MCPClient.swift
//  SwiftMCP
//
//  Created by Atharva Vaidya on 3/20/25.
//

import Foundation

/// Represents a JSON-RPC request
struct JSONRPCRequest {
    let jsonrpc: String
    let method: String
    let params: [String: Any]
    let id: String
    
    static func parse(_ json: [String: Any]) -> Result<JSONRPCRequest, MCPError> {
        guard let version = json["jsonrpc"] as? String,
              let method = json["method"] as? String,
              let id = json["id"] as? String else {
            return .failure(.invalidParams("Missing required JSON-RPC fields"))
        }
        
        let params = json["params"] as? [String: Any] ?? [:]
        return .success(JSONRPCRequest(jsonrpc: version, method: method, params: params, id: id))
    }
}

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
    public func handleIncomingMessage(data: Data) {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                sendErrorResponse(id: nil, error: .invalidParams("Invalid JSON format"))
                return
            }
            
            // Parse the JSON-RPC request
            let requestResult = JSONRPCRequest.parse(json)
            switch requestResult {
            case .success(let request):
                handleRequest(request)
            case .failure(let error):
                sendErrorResponse(id: json["id"] as? String, error: error)
            }
        } catch {
            sendErrorResponse(id: nil, error: .invalidParams("JSON parsing error: \(error.localizedDescription)"))
        }
    }
    
    /// Handle a parsed JSON-RPC request
    private func handleRequest(_ request: JSONRPCRequest) {
        // Lookup the tool associated with the method
        guard let tool = toolRegistry.tool(for: request.method) else {
            sendErrorResponse(id: request.id, error: .toolNotFound)
            return
        }
        
        // Execute the tool's handler
        Task.detached {
//            do {
//                try await tool.handle(params: request.params)
//            } catch {
//                print(error)
//            }
        }
        
//        { result in
//           switch result {
//           case .success(let resultData):
//               self.sendSuccessResponse(id: request.id, result: resultData)
//           case .failure(let error):
//               self.sendErrorResponse(id: request.id, error: error)
//           }
//       }
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

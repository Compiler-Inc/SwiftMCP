//
//  MCPError.swift
//  SwiftMCP
//
//  Created by Atharva Vaidya on 3/20/25.
//

import Foundation

/// Represents errors that can occur within the MCP toolkit.
/// These errors are mapped to appropriate JSON-RPC error responses when sent back to clients.
public enum MCPError: Error, CustomStringConvertible {
    /// Indicates that the requested tool was not found in the registry
    case toolNotFound
    
    /// Indicates that the parameters provided in the request were invalid
    case invalidParams(String)
    
    /// Represents tool-specific errors with a message
    case toolError(String)
    
    /// JSON Parsing Error
    case jsonParsingError(Error)
    
    /// Invalid request error with a message
    case invalidRequest(String)
    
    /// Provides human-readable descriptions for each error case
    public var description: String {
        switch self {
        case .toolNotFound:
            return "The requested tool was not found in the registry"
        case .invalidParams(let message):
            return "Invalid parameters: \(message)"
        case .toolError(let message):
            return "Tool error: \(message)"
        case .jsonParsingError(let error):
            return "JSON parsing error: \(error.localizedDescription)"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        }
    }
    
    /// Returns the JSON-RPC error code associated with this error
    var jsonRpcCode: Int {
        switch self {
        case .toolNotFound:
            return -32601
        case .invalidParams:
            return -32602
        case .toolError:
            return -32000
        case .jsonParsingError:
            return -32700
        case .invalidRequest:
            return -32600
        }
    }
}

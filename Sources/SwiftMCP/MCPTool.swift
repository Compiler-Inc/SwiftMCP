//
//  MCPTool.swift
//  SwiftMCP
//
//  Created by Atharva Vaidya on 3/20/25.
//

import Foundation

/// Protocol defining the interface for MCP tools.
/// Each tool represents a specific capability that can be invoked via JSON-RPC.
/// Tools can wrap native iOS APIs, custom functionality, or any other feature
/// that needs to be exposed through the MCP interface.
public protocol MCPTool: Sendable {
    /// The JSON-RPC method name this tool responds to.
    /// This should be a unique identifier in the format "category/action",
    /// for example "healthKit/getSteps" or "location/getCurrentPosition".
    var methodName: String { get }

    /// The JSON schema for the tool's definition in OpenAI's chat completion format.
    var toolSchema: String { get }

    /// Handle the incoming JSON-RPC call.
    /// - Parameters:
    ///   - params: The JSON-RPC parameters as a dictionary of JSON values
    ///   - completion: Completion handler that should be called with either a success value
    ///                that can be serialized to JSON, or an MCPError on failure.
    /// - Note: Implementations should be thread-safe and handle their own background execution if needed.
    func handle(params: [String: JSON]) async throws -> [String: JSON]
}

/// Extension providing default implementations and utility methods for MCPTool
public extension MCPTool {
    /// Validates that required parameters are present in the params dictionary
    /// - Parameters:
    ///   - required: Array of required parameter keys
    ///   - params: The parameters dictionary to validate
    /// - Returns: A Result containing void on success or an MCPError on failure
    func validateParams(_ required: [String], in params: [String: JSON]) -> Result<Void, MCPError> {
        let missing = required.filter { !params.keys.contains($0) }
        if !missing.isEmpty {
            return .failure(.invalidParams("Missing required parameters: \(missing.joined(separator: ", "))"))
        }
        return .success(())
    }
}

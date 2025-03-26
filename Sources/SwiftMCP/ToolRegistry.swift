//
//  ToolRegistry.swift
//  SwiftMCP
//
//  Created by Atharva Vaidya on 3/20/25.
//

import Foundation

/// A registry that maintains a collection of MCP tools and provides methods to register and retrieve them.
/// This class serves as the central repository for all available tools in the MCP toolkit.
public class ToolRegistry {
    /// Dictionary storing the registered tools, keyed by their method names
    private var tools: [String: MCPTool] = [:]

    public init() {}

    /// Registers a tool in the registry.
    /// - Parameter tool: The tool to register, conforming to MCPTool protocol
    public func register(tool: MCPTool) {
        tools[tool.methodName] = tool
    }

    /// Retrieves a tool by its method name.
    /// - Parameter method: The JSON-RPC method name associated with the tool
    /// - Returns: The corresponding MCPTool if found, nil otherwise
    public func tool(for method: String) -> MCPTool? {
        tools[method]
    }

    /// Removes a tool from the registry.
    /// - Parameter methodName: The method name of the tool to remove
    public func unregister(methodName: String) {
        tools.removeValue(forKey: methodName)
    }

    /// Returns all registered method names.
    /// - Returns: Array of registered method names
    public func registeredMethods() -> [String] {
        Array(tools.keys)
    }
}

//
//  File.swift
//  SwiftMCP
//
//  Created by Atharva Vaidya on 3/20/25.
//

import Foundation

/// Represents a JSON-RPC request
struct JSONRPCRequest: Codable {
    let jsonrpc: String
    let method: String
    let params: [String: JSON]
    let id: String
    
    // Add coding keys
    enum CodingKeys: String, CodingKey {
        case jsonrpc, method, params, id
    }
    
    // Updated init
    init(jsonrpc: String = "2.0", method: String, params: [String: JSON], id: String) {
        self.jsonrpc = jsonrpc
        self.method = method
        self.params = params
        self.id = id
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.jsonrpc = try container.decode(String.self, forKey: .jsonrpc)
        self.method = try container.decode(String.self, forKey: .method)
        self.id = try container.decode(String.self, forKey: .id)
        self.params = try container.decode([String: JSON].self, forKey: .params)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(jsonrpc, forKey: .jsonrpc)
        try container.encode(method, forKey: .method)
        try container.encode(id, forKey: .id)
        try container.encode(params, forKey: .params)
    }
}

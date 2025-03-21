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
    let params: [String: Any]
    let id: String
    
    // Add coding keys
    enum CodingKeys: String, CodingKey {
        case jsonrpc, method, params, id
    }
    
    // Custom encoding implementation
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        try container.encode(method, forKey: .method)
        try container.encode(id, forKey: .id)
        
        // Handle params dictionary using JSONSerialization
        let paramsData = try JSONSerialization.data(withJSONObject: params)
        if let paramsString = String(data: paramsData, encoding: .utf8) {
            try container.encode(paramsString, forKey: .params)
        }
    }
    
    // Custom decoding implementation
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jsonrpc = try container.decode(String.self, forKey: .jsonrpc)
        method = try container.decode(String.self, forKey: .method)
        id = try container.decode(String.self, forKey: .id)
        
        // Handle params dictionary using JSONSerialization
        let paramsString = try container.decode(String.self, forKey: .params)
        if let paramsData = paramsString.data(using: .utf8),
           let params = try JSONSerialization.jsonObject(with: paramsData) as? [String: Any] {
            self.params = params
        } else {
            self.params = [:]
        }
    }
    
    // Regular init
    init(jsonrpc: String = "2.0", method: String, params: [String: Any], id: String) {
        self.jsonrpc = jsonrpc
        self.method = method
        self.params = params
        self.id = id
    }
}

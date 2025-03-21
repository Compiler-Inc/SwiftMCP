import XCTest
@testable import SwiftMCP

final class SwiftMCPTests: XCTestCase {
    var registry: ToolRegistry!
    var responses: [String]!
    var client: MCPClient!
    
    override func setUp() {
        super.setUp()
        registry = ToolRegistry()
        responses = []
        client = MCPClient(toolRegistry: registry) { [weak self] response in
            self?.responses.append(response)
        }
    }
    
    override func tearDown() {
        registry = nil
        responses = nil
        client = nil
        super.tearDown()
    }
    
    // MARK: - Tool Registry Tests
    
    func testToolRegistration() {
        let mockTool = MockTool(methodName: "test/mock")
        registry.register(tool: mockTool)
        
        XCTAssertNotNil(registry.tool(for: "test/mock"))
        XCTAssertNil(registry.tool(for: "nonexistent/method"))
    }
    
    func testToolUnregistration() {
        let mockTool = MockTool(methodName: "test/mock")
        registry.register(tool: mockTool)
        registry.unregister(methodName: "test/mock")
        
        XCTAssertNil(registry.tool(for: "test/mock"))
    }
    
    // MARK: - MCPClient Tests
    
    func testValidJSONRPCRequest() {
        let mockTool = MockTool(methodName: "test/mock")
        registry.register(tool: mockTool)
        
        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "test/mock",
            "params": ["key": "value"],
            "id": "1"
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: request) else {
            XCTFail("Failed to serialize request")
            return
        }
        
        client.handleIncomingMessage(data: data)
        
        XCTAssertEqual(responses.count, 1)
        XCTAssertTrue(responses[0].contains("\"result\""))
        XCTAssertTrue(responses[0].contains("\"id\":\"1\""))
    }
    
    func testInvalidJSONRPCRequest() {
        let request: [String: Any] = [
            "invalid": "request"
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: request) else {
            XCTFail("Failed to serialize request")
            return
        }
        
        client.handleIncomingMessage(data: data)
        
        XCTAssertEqual(responses.count, 1)
        XCTAssertTrue(responses[0].contains("\"error\""))
    }
    
    func testMethodNotFound() {
        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "nonexistent/method",
            "params": [:],
            "id": "1"
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: request) else {
            XCTFail("Failed to serialize request")
            return
        }
        
        client.handleIncomingMessage(data: data)
        
        XCTAssertEqual(responses.count, 1)
        XCTAssertTrue(responses[0].contains("\"error\""))
        XCTAssertTrue(responses[0].contains("Tool not found"))
    }
}

// MARK: - Mock Tool for Testing

private class MockTool: MCPTool {
    let methodName: String
    
    init(methodName: String) {
        self.methodName = methodName
    }
    
    func handle(params: [String : Any], completion: @escaping (Result<Any, MCPError>) -> Void) {
        completion(.success(["status": "success", "params": params]))
    }
}

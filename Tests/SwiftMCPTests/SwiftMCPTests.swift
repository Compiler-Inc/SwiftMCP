@testable import SwiftMCP
import XCTest

final class SwiftMCPTests: XCTestCase {
    var registry: ToolRegistry!
    var responses: [String]!
    var client: MCPClient!

    override func setUp() {
        super.setUp()
        registry = ToolRegistry()
        responses = []
        client = MCPClient(toolRegistry: registry) { [weak self] response in
            print("got response: \(response)")
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

    func testToolRegistration() async throws {
        let mockTool = MockTool(methodName: "test/mock")
        registry.register(tool: mockTool)

        XCTAssertNotNil(registry.tool(for: "test/mock"))
        XCTAssertNil(registry.tool(for: "nonexistent/method"))
    }

    func testToolUnregistration() async throws {
        let mockTool = MockTool(methodName: "test/mock")
        registry.register(tool: mockTool)
        registry.unregister(methodName: "test/mock")

        XCTAssertNil(registry.tool(for: "test/mock"))
    }

    // MARK: - MCPClient Tests

    func testValidJSONRPCRequest() async throws {
        let mockTool = MockTool(methodName: "test/mock")
        registry.register(tool: mockTool)

        let request: [String: JSON] = [
            "jsonrpc": .string("2.0"),
            "method": .string("test/mock"),
            "params": .object(["key": .string("value")]),
            "id": .string("1"),
        ]

        let data = try JSONEncoder().encode(request)

        try await client.handleIncomingMessage(data: data)
        XCTAssertEqual(responses.count, 1)
        XCTAssertTrue(responses[0].contains("\"result\""))
        XCTAssertTrue(responses[0].contains("\"id\":\"1\""))
    }

    func testInvalidJSONRPCRequest() async throws {
        // Send an invalid request that's missing required fields
        let request: [String: JSON] = [
            "invalid": .string("request"),
            "id": .string("test-id"),
        ]

        let data = try JSONEncoder().encode(request)

        do {
            try await client.handleIncomingMessage(data: data)
            XCTFail("Parsed invalid JSON RPC request")
        } catch {
            XCTAssertEqual(responses.count, 1)
            XCTAssertTrue(responses[0].contains("\"error\""))
            XCTAssertTrue(responses[0].contains("Invalid JSON-RPC request format"))
            XCTAssertTrue(responses[0].contains("\"id\":\"test-id\""))
        }
    }

    func testMethodNotFound() async throws {
        let request: [String: JSON] = [
            "jsonrpc": .string("2.0"),
            "method": .string("nonexistent/method"),
            "params": .object([:]),
            "id": .string("1"),
        ]

        let data = try JSONEncoder().encode(request)

        try await client.handleIncomingMessage(data: data)

        XCTAssertEqual(responses.count, 1)
        XCTAssertTrue(responses[0].contains("\"error\""))
        XCTAssertTrue(responses[0].contains("The requested tool was not found in the registry"))
    }
}

// MARK: - Mock Tool for Testing

private final class MockTool: MCPTool {
    var toolSchema: String { "" }
    
    let methodName: String

    init(methodName: String) {
        self.methodName = methodName
    }

    func handle(params: [String: JSON]) async throws -> [String: JSON] {
        return [
            "status": .string("success"),
            "params": .object(params),
        ]
    }
}

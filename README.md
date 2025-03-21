# SwiftMCP

A Swift Package that implements an MCP (Machine Control Protocol) client for iOS and macOS, enabling native API integration through a JSON-RPC interface.

## Features

- JSON-RPC 2.0 compliant interface
- Modular tool architecture for easy extension
- Built-in HealthKit integration
- Comprehensive error handling
- Thread-safe design
- Fully documented API
- Extensive test coverage

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 6.0+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SwiftMCP.git", from: "1.0.0")
]
```

## Usage

### Basic Setup

```swift
import SwiftMCP

// Create a tool registry
let registry = ToolRegistry()

// Create an MCP client with a response handler
let client = MCPClient(toolRegistry: registry) { response in
    print("Received response: \(response)")
}

// Register tools
do {
    let healthKitTool = try HealthKitTool()
    registry.register(tool: healthKitTool)
} catch {
    print("Failed to initialize HealthKit tool: \(error)")
}
```

### Handling JSON-RPC Requests

```swift
// Example JSON-RPC request for step count
let request: [String: Any] = [
    "jsonrpc": "2.0",
    "method": "healthKit/getSteps",
    "params": [
        "startDate": "2024-03-20T00:00:00Z",
        "endDate": "2024-03-20T23:59:59Z"
    ],
    "id": "1"
]

if let data = try? JSONSerialization.data(withJSONObject: request) {
    client.handleIncomingMessage(data: data)
}
```

### Creating Custom Tools

```swift
class CustomTool: MCPTool {
    let methodName = "custom/method"

    func handle(params: [String: Any], completion: @escaping (Result<Any, MCPError>) -> Void) {
        // Implement your custom functionality here
        completion(.success(["result": "success"]))
    }
}
```

## Available Tools

### HealthKitTool

Provides access to HealthKit data through the MCP interface.

#### Methods

- `healthKit/getSteps`
  - Parameters:
    - `startDate` (optional): ISO8601 string representing the start date (defaults to start of today)
    - `endDate` (optional): ISO8601 string representing the end date (defaults to now)
  - Returns:
    - `steps`: Integer representing the step count
    - `startDate`: ISO8601 string of the actual start date used
    - `endDate`: ISO8601 string of the actual end date used

## Error Handling

The package uses the `MCPError` type for error handling, which includes:

- `toolNotFound`: When the requested method doesn't exist
- `invalidParams`: When the request parameters are invalid
- `toolError`: Generic error case for tool-specific errors with a descriptive message

Each tool can provide detailed error information through the `toolError` case while maintaining a clean separation between the core MCP framework and tool-specific implementations.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

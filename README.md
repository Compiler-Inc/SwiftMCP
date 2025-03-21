# SwiftMCP

A Swift Package that implements an MCP (Machine Control Protocol) client for iOS and macOS, enabling native API integration through a JSON-RPC interface. The package also includes an OpenAI-compatible function calling bridge.

## Features

- JSON-RPC 2.0 compliant interface
- Modular tool architecture for easy extension
- Built-in HealthKit integration with comprehensive workout support
- OpenAI function calling compatibility
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

### OpenAI Function Calling Bridge

```swift
// Create and set up the OpenAI bridge
let openAIRegistry = OpenAIToolRegistry()

// Register your MCP tools with their schemas
openAIRegistry.registerTool(healthKitTool, schema: healthKitToolSchema)

// Get OpenAI function definitions
let functions = try openAIRegistry.getOpenAIFunctions()

// Handle OpenAI tool calls
let toolCalls: [OpenAIBridge.ToolCall] = ... // from OpenAI response
let toolResponses = try await openAIRegistry.handleToolCalls(toolCalls)
```

### Handling JSON-RPC Requests

```swift
// Example JSON-RPC request for health data
let request: [String: Any] = [
    "jsonrpc": "2.0",
    "method": "healthKit",
    "params": [
        "action": "getData",
        "dataType": "stepCount",
        "timeRange": "today"
    ],
    "id": "1"
]

// Example JSON-RPC request for workouts
let workoutRequest: [String: Any] = [
    "jsonrpc": "2.0",
    "method": "healthKit",
    "params": [
        "action": "getWorkouts",
        "workoutType": "running",
        "includeRoutes": true,
        "timeRange": "last_week"
    ],
    "id": "2"
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

Provides comprehensive access to HealthKit data through the MCP interface.

#### Methods

- `healthKit`

  - Actions:

    - `getData`: Retrieve health metrics

      - Parameters:
        - `dataType`: Type of health data to retrieve (e.g., "stepCount", "heartRate")
        - `timeRange` (optional): Predefined range ("today", "yesterday", "this_week", etc.)
        - `duration` (optional): ISO 8601 duration string (e.g., "P7D" for 7 days)
      - Returns:
        - `dataType`: The type of data retrieved
        - `unit`: The unit of measurement
        - `samples`: Array of data points with values and timestamps

    - `getWorkouts`: Retrieve workout data
      - Parameters:
        - `workoutType` (optional): Type of workout to filter by (e.g., "running", "cycling")
        - `includeRoutes` (optional): Boolean to include GPS route data
        - `timeRange` (optional): Predefined range
        - `duration` (optional): ISO 8601 duration string
      - Returns:
        - `workouts`: Array of workout data including:
          - `type`: Workout type
          - `startDate`: Start timestamp
          - `endDate`: End timestamp
          - `duration`: Duration in seconds
          - `distance` (optional): Distance in meters
          - `calories` (optional): Energy burned in kilocalories
          - `route` (optional): Array of GPS coordinates with timestamps

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

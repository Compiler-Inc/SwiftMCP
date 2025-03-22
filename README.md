# SwiftMCP

A Swift Package that implements an MCP (Model Context Protocol) client for iOS and macOS, enabling native API integration through a JSON-RPC interface. The package also includes an OpenAI-compatible function calling bridge.

## Features

- Open source function definitions for Apple's native APIs like HealthKit
- JSON-RPC 2.0 compliant interface
- Some test coverage

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 6.0+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/compiler-inc/SwiftMCP.git", from: "1.0.0")
]
```

### Architecture

[![](https://mermaid.ink/img/pako:eNqFVE1zmzAU_CsaXWt7jBPAcGgmxXWnnXHiiXNJwQcVnm0mIFF9tHFt__dK4sNMnEy4aPW0u9qHEAecsgxwiDcF-5vuCJfocZZQpB-hfm05qXYowSuQqkpwXTfPbVU58RNT3KA1Gg4_owfY5kLyffzIWNFO1mdJW2rJhibiugoc2WlDB5rV4CJIxOgf4ILInFE015FfhZq8CnVfAb39rjeJa_ROto5mRd9AzmAjYj02KzYd0sWc5mZr0dM2bKtc6eRLzspKxgaiGqNPF3okWWPdczqrrZnRRKQoDk2GBXkGUTuZ8s3prDyjVmQcjnfsiOY5JbplUcUWIQN1AFh_qH4CcUT1C5dxM5rcP1b3d8OHZaStfisQsufUskz8RbSMihyojDvUY3Y1y_36AqnZOzZASbBBeux2vTW2_eixn-WirYZnNU0wq-u10j_d1gHNGS_JG111ZuacvpD0uT7jGZHk3eM0NKvpjuGt194tWqr5jLt7gAe4BJ0nz_QdPZhyguUOSkhwqGEGG6IKaW7BSVOJkmy1pykOJVcwwJyp7Q6HG1IIPVNVRiTMcqJvU9lVK0J_Mla2Eshyyfii_inYf4Ol4PCAX3B45Y9Hnht4zjSY-I7r-u4A73HoT0au73jTwL2aekEQ-KcB_mdNx6Ppted77tTxJo7jj8fXp_9SZmEl?type=png)](https://mermaid.live/edit#pako:eNqFVE1zmzAU_CsaXWt7jBPAcGgmxXWnnXHiiXNJwQcVnm0mIFF9tHFt__dK4sNMnEy4aPW0u9qHEAecsgxwiDcF-5vuCJfocZZQpB-hfm05qXYowSuQqkpwXTfPbVU58RNT3KA1Gg4_owfY5kLyffzIWNFO1mdJW2rJhibiugoc2WlDB5rV4CJIxOgf4ILInFE015FfhZq8CnVfAb39rjeJa_ROto5mRd9AzmAjYj02KzYd0sWc5mZr0dM2bKtc6eRLzspKxgaiGqNPF3okWWPdczqrrZnRRKQoDk2GBXkGUTuZ8s3prDyjVmQcjnfsiOY5JbplUcUWIQN1AFh_qH4CcUT1C5dxM5rcP1b3d8OHZaStfisQsufUskz8RbSMihyojDvUY3Y1y_36AqnZOzZASbBBeux2vTW2_eixn-WirYZnNU0wq-u10j_d1gHNGS_JG111ZuacvpD0uT7jGZHk3eM0NKvpjuGt194tWqr5jLt7gAe4BJ0nz_QdPZhyguUOSkhwqGEGG6IKaW7BSVOJkmy1pykOJVcwwJyp7Q6HG1IIPVNVRiTMcqJvU9lVK0J_Mla2Eshyyfii_inYf4Ol4PCAX3B45Y9Hnht4zjSY-I7r-u4A73HoT0au73jTwL2aekEQ-KcB_mdNx6Ppted77tTxJo7jj8fXp_9SZmEl)

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

### OpenAI Integration

This example demonstrates:

1. Setting up the MCP client with HealthKit tool
2. Creating an OpenAI bridge and registering the tool schema
3. Converting MCP tools to OpenAI function definitions
4. Sending an initial request to OpenAI
5. Processing any tool calls through MCP
6. Sending the tool results back to OpenAI for final summarization

The flow allows OpenAI to:

- Request step count data using the HealthKit `getData` action
- Request workout data using the HealthKit `getWorkouts` action
- Receive the actual health and workout data through MCP
- Provide a natural language summary of the data

```swift
import SwiftMCP
import OpenAI

// 1. Set up MCP client and tools
let registry = ToolRegistry()
let client = MCPClient(toolRegistry: registry) { response in
    print("Received response: \(response)")
}

// Initialize HealthKit tool
let healthKitTool = try HealthKitTool()
registry.register(tool: healthKitTool)

// 2. Set up OpenAI bridge
let openAIRegistry = OpenAIToolRegistry()
let healthKitSchema = JSONSchema(
    type: .object,
    properties: [
        "action": .init(type: .string, enum: ["getData", "getWorkouts"]),
        "dataType": .init(type: .string, description: "Type of health data to retrieve (e.g., stepCount, heartRate)"),
        "timeRange": .init(type: .string, enum: ["today", "yesterday", "this_week", "last_week"]),
        "workoutType": .init(type: .string, enum: ["running", "cycling", "walking"]),
        "includeRoutes": .init(type: .boolean)
    ],
    required: ["action"]
)

// Register the HealthKit tool with its schema
openAIRegistry.registerTool(healthKitTool, schema: healthKitSchema)

// 3. Get OpenAI function definitions
let functions = try openAIRegistry.getOpenAIFunctions()

// 4. Create OpenAI client and chat request
let openAI = OpenAI(apiToken: "your-api-key")
let query = "What was my step count today and how many calories did I burn in my last run?"

let chatRequest = ChatRequest(
    model: .gpt4o,
    messages: [
        .init(role: .user, content: query)
    ],
    functions: functions,
    functionCall: "auto"
)

// 5. Send request to OpenAI
let result = try await openAI.chat(request: chatRequest)

// 6. Handle any tool calls from OpenAI
if let toolCalls = result.choices.first?.message.toolCalls {
    // Process each tool call through MCP
    let toolResponses = try await openAIRegistry.handleToolCalls(toolCalls)

    // 7. Send follow-up request to OpenAI with tool results
    let followUpRequest = ChatRequest(
        model: .gpt4,
        messages: [
            .init(role: .user, content: query),
            result.choices.first!.message,
            .init(role: .assistant, content: nil, toolCalls: toolResponses)
        ]
    )

    // 8. Get final summarized response
    let finalResult = try await openAI.chat(request: followUpRequest)
    print(finalResult.choices.first?.message.content ?? "No response")
}
```

Note: Make sure to handle errors appropriately and replace "your-api-key" with your actual OpenAI API key.

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
let request = JSONRPCRequest(
    jsonrpc: "2.0",
    method: "healthKit",
    params: [
        "action": .string("getData"),
        "dataType": .string("stepCount"),
        "timeRange": .string("today")
    ],
    id: "1"
)

// Example JSON-RPC request for workouts
let workoutRequest = JSONRPCRequest(
    jsonrpc: "2.0",
    method: "healthKit",
    params: [
        "action": .string("getWorkouts"),
        "workoutType": .string("running"),
        "includeRoutes": .bool(true),
        "timeRange": .string("last_week")
    ],
    id: "2"
)

if let data = try? JSONEncoder().encode(request) {
    try await client.handleIncomingMessage(data: data)
}
```

### Creating Custom Tools

```swift
class CustomTool: MCPTool {
    let methodName = "custom/method"

    func handle(params: [String: JSON]) async throws -> [String: JSON] {
        // Implement your custom functionality here
        return [
            "status": .string("success"),
            "result": .object(["data": .string("your data here")])
        ]
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
- `jsonParsingError`: When JSON parsing fails
- `invalidRequest`: When the JSON-RPC request format is invalid

## Contributing

I want to add as many iOS APIs as possible to this repo. The goal is to create a comprehensive collection of MCP-compatible tools for iOS development.

Any contributions are welcome! Please feel free to submit a PR.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

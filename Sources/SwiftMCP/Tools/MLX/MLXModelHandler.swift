import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import Hub

/// Handler for managing MLX models with function calling capabilities
public class MLXModelHandler: @unchecked Sendable {
    /// The loaded MLX model container
    private var modelContainer: ModelContainer?
    
    /// The MLX tool registry for function calling
    private var toolRegistry: MLXToolRegistry
    
    private var lock = NSLock()
    
    /// Initialize the MLX model handler with a tool registry
    /// - Parameter toolRegistry: The MLX tool registry for function calling
    public init(toolRegistry: MLXToolRegistry) {
        self.toolRegistry = toolRegistry
    }
    
    /// Load an MLX model using the model registry
    public func loadModel() async throws {
        // Load the model using LLMModelFactory
        modelContainer = try await LLMModelFactory.shared.loadContainer(
            configuration: LLMRegistry.llama3_2_3B_4bit,
            progressHandler: { progress in
                print("Loading model: \(progress.fractionCompleted * 100)%")
            }
        )
    }
    
    /// Generate text with function calling support
    public func generateWithFunctionCalling(
        prompt: String,
        systemPrompt: String? = nil,
        parameters: [String: JSON] = [:]
    ) async throws -> String {
        guard let modelContainer = modelContainer else {
            throw MCPError.toolError("MLX model not loaded")
        }
        
        // Extract generation parameters
        let temperature: Float = parameters["temperature"].flatMap { if case .number(let t) = $0 { return Float(t) } else { return nil } } ?? 0.7
        let maxTokens = parameters["max_tokens"].flatMap { if case .number(let t) = $0 { return Int(t) } else { return nil } } ?? 1024
        
        // Create generation parameters
        let generateParams = GenerateParameters(
            temperature: temperature
        )
        
        // Get tools from registry
//        let functions = try toolRegistry.getMLXFunctions()
        
        // Create input and generate using MLX's perform method
        return try await modelContainer.perform { context in
            // Format the message content for the model
            let messages: [[String: Any]] = [
                [
                    "role": "system",
                    "content": systemPrompt ?? "You are a helpful assistant with access to tools."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
            
            let userInput = UserInput(
                messages: messages,
                tools: []
            )
            
            let input = try await context.processor.prepare(input: userInput)
            
            // Generate using the prepared input and get the output property
            let result = try MLXLMCommon.generate(
                input: input,
                parameters: generateParams,
                context: context
            ) { tokens in
                if tokens.count >= maxTokens {
                    return .stop
                }
                return .more
            }
            
            return result.output // Return the output string from GenerateResult
        }
    }
    
    public func generate(
        messages: [[String: any Sendable]],
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws -> GenerateResult? {
        guard let modelContainer else { return nil }
        
        return try await modelContainer.perform { context in
            let input = try await context.processor.prepare(
                input: .init(messages: messages, tools: [])
            )
            
            let generateParams = GenerateParameters(
                temperature: 0.7
            )
            
            return try MLXLMCommon.generate(
                input: input,
                parameters: generateParams,
                context: context
            ) { [unowned self] tokens in
                if tokens.count % 1 == 0 {
                    self.lock.lock()
                    defer { self.lock.unlock() }
                    let text = context.tokenizer.decode(tokens: tokens)
                    Task { @MainActor in
                        onProgress(text)
                    }
                }
                return .more
            }
        }
    }
}

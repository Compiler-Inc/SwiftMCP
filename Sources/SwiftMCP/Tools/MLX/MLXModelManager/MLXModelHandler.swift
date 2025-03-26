//
//  MLXModelHandler.swift
//  SwiftMCP
//
//  Created by Atharva Vaidya on 3/24/25.
//

import Foundation
import Hub
import MLX
import MLXLLM
import MLXLMCommon

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
            configuration: LLMRegistry.llama3_2_1B_4bit,
            progressHandler: { progress in
                print("Loading model: \(progress.fractionCompleted * 100)%")
            }
        )
    }

    public func generate(
        messages: [[String: any Sendable]],
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws -> GenerateResult? {
        guard let modelContainer = modelContainer else {
            return nil
        }

        return try await modelContainer.perform { [messages] context in
            let input = try await context.processor.prepare(
                input: UserInput(
                    messages: messages
                )
            )

            return try MLXLMCommon.generate(
                input: input,
                parameters: .init(),
                context: context
            ) { tokens in
                let text = context.tokenizer.decode(tokens: tokens)
                Task { @MainActor in
                    onProgress(text)
                }
                return .more
            }
        }
    }

    public func generateWithTools(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]],
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws -> GenerateResult? {
        guard let modelContainer = modelContainer else {
            return nil
        }

        return try await modelContainer.perform { [messages] context in
            let input = try await context.processor.prepare(
                input: UserInput(
                    messages: messages,
                    tools: tools
                )
            )

            return try MLXLMCommon.generate(
                input: input,
                parameters: .init(),
                context: context
            ) { tokens in
                let text = context.tokenizer.decode(tokens: tokens)
                Task { @MainActor in
                    onProgress(text)
                }
                return .more
            }
        }
    }
}

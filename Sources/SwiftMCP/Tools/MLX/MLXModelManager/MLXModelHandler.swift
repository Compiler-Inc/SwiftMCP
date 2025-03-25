//
//  File.swift
//  SwiftMCP
//
//  Created by Atharva Vaidya on 3/24/25.
//

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
        guard let modelContainer else { return nil }

        return try await modelContainer.perform { context in
            let input = try await context.processor.prepare(
                input: .init(messages: messages, tools: [])
            )

            let generateParams = GenerateParameters(
                temperature: 0.7
            )
            
            var detokenizer = NaiveStreamingDetokenizer(tokenizer: context.tokenizer)
            var tokenCount = 0

            return try MLXLMCommon.generate(
                input: input,
                parameters: generateParams,
                context: context
            ) { [unowned self] tokens in
                if let last = tokens.last {
                    self.lock.lock()
                    defer { self.lock.unlock() }
                    detokenizer.append(token: last)
                    tokenCount += 1
                }
                
                if let decodedToken = detokenizer.next() {
                    let cleanedToken = decodedToken.replacingOccurrences(of: "Ċ", with: "\n")
                    Task { @MainActor in
                        onProgress(cleanedToken)
                    }
                }
                
                if tokenCount > 1024 {
                    return .stop
                }
                
                return .more
            }
        }
    }
}

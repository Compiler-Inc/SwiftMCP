// ModelManager.swift
import Foundation
import Combine
import SwiftUI
import CoreImage
import MLX
import MLXLMCommon
import Tokenizers
import Hub

public final class ModelManager: ObservableObject, @unchecked Sendable {
    @Published public var progressPercent: Int = 0
    @Published public var output: String = ""
    @Published public var isLoading: Bool = false
    @Published public var isGenerating: Bool = false

    public var maxTokens: Int?
    private let modelPath: String
    public private(set) var container: ModelContext?
    private var temperature: Float = 0.7
    private var topP: Float = 0.9
    private var repetitionPenalty: Float = 1.0

    public init(modelPath: String) {
        self.modelPath = modelPath
    }

    public func setHyperparameters(temperature: Float?, topP: Float?, repetitionPenalty: Float?) {
        if let temp = temperature { self.temperature = temp }
        if let p = topP { self.topP = p }
        if let rp = repetitionPenalty { self.repetitionPenalty = rp }
    }

    public func loadModel() async throws {
        guard !isLoading else { return }
        
        await MainActor.run {
            self.isLoading = true
            self.output = "Loading model..."
        }
        
        do {
            let configuration = ModelConfiguration(id: modelPath)
            let hub = HubApi()
            let ctx = try await ModelFactory.shared.load(
                hub: hub,
                configuration: configuration,
                progressHandler: { progress in
                    Task { @MainActor in
                        self.progressPercent = Int(progress.fractionCompleted * 100)
                    }
                }
            )
            
            await MainActor.run {
                self.container = ctx
                self.output = "Model loaded successfully."
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.output += "\nError loading model: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    public func generate(prompt: String, imagePath: String? = nil) async {
        guard let container else {
            await MainActor.run { self.output = "Model not loaded." }
            return
        }
        guard !isGenerating else { return }
        
        await MainActor.run {
            self.isGenerating = true
            self.output = ""
        }

        do {
            var userInput = UserInput(prompt: .text(prompt))
            if let imagePath = imagePath, !imagePath.isEmpty,
               FileManager.default.fileExists(atPath: imagePath),
               let ciImage = CIImage(contentsOf: URL(fileURLWithPath: imagePath)) {
                userInput.images = [.ciImage(ciImage)]
            } else if let imagePath = imagePath {
                await MainActor.run {
                    self.output += "\nWarning: Could not load image at \(imagePath)"
                }
            }

            let lmInput = try await container.processor.prepare(input: userInput)

            let parameters = GenerateParameters(
                temperature: temperature,
                topP: topP,
                repetitionPenalty: repetitionPenalty
            )

            var detokenizer = NaiveStreamingDetokenizer(tokenizer: container.tokenizer)
            var tokenCount = 0

            // Start generation
            _ = try MLXLMCommon.generate(
                input: lmInput,
                parameters: parameters,
                context: container
            ) { tokens in
                if let last = tokens.last {
                    detokenizer.append(token: last)
                    tokenCount += 1
                }

                if let decodedToken = detokenizer.next() {
                    let cleanedToken = decodedToken.replacingOccurrences(of: "Ċ", with: "\n")
                    Task { @MainActor in
                        self.output += cleanedToken
                        await Task.yield()
                    }
                }

                // Only stop if maxTokens is set and we've reached that limit
                if let limit = self.maxTokens, tokenCount >= limit {
                    return .stop
                }

                return .more
            }

            // Optionally set final output to the result's output if desired
            // await MainActor.run { self.output = result.output }

        } catch {
            await MainActor.run { self.output += "\nGeneration error: \(error.localizedDescription)" }
        }

        await MainActor.run { 
            self.output = self.output.replacingOccurrences(of: "<|im_end|>", with: "")
            self.output = self.output.replacingOccurrences(of: "Ċ", with: "\n")
            self.isGenerating = false 
        }
    }
}


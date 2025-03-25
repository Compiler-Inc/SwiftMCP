// ModelFactory.swift
// Unified Model Factory merging LLM and VLM logic

import Foundation
import Hub
import MLX
import MLXLMCommon
import Tokenizers

// MARK: - ModelFactoryError

public enum ModelFactoryError: Error {
    case unsupportedModelType(String)
    case unsupportedProcessorType(String)
    case unsupportedModality(String)
    case imageRequired
    case maskRequired
    case singleImageAllowed
    case imageProcessingFailure(String)
}

// MARK: - Base Configurations

/*public struct BaseConfiguration: Codable {
    public let modelType: String
    public let quantization: Quantization?
    
    public enum Quantization: String, Codable {
        case int8
        case int4
        case none
    }
}*/

public struct BaseProcessorConfiguration: Codable, Sendable {
    public let processorClass: String

    enum CodingKeys: String, CodingKey {
        case processorClass = "processor_class"
    }
}

// MARK: - Unified ModelTypeRegistry

/// A unified registry that can create both LLM and VLM models from their configurations.
public class ModelTypeRegistry: @unchecked Sendable {

    // Note: using NSLock as we have very small (just dictionary get/set)
    // critical sections and expect no contention. this allows the methods
    // to remain synchronous.
    private let lock = NSLock()

    // A unified dictionary for both LLM and VLM models.
    // Each entry maps a modelType string to a closure that instantiates the model.
    private var creators: [String: @Sendable (URL) throws -> any LanguageModel] = [:]

    /// Add a new model to the type registry.
    public func registerModelType(
        _ type: String, creator: @Sendable @escaping (URL) throws -> any LanguageModel
    ) {
        lock.lock()
        creators[type] = creator
        lock.unlock()
    }

    /// Given a `modelType` and configuration file instantiate a new `LanguageModel`.
    public func createModel(configuration: URL, modelType: String) throws -> LanguageModel {
        lock.lock()
        let creator = creators[modelType]
        lock.unlock()

        guard let creator else {
            throw ModelFactoryError.unsupportedModelType(modelType)
        }
        return try creator(configuration)
    }

    /// Helper function for creating model closures
    private static func create<C: Codable, M: Sendable>(
        _ configurationType: C.Type, _ modelInit: @escaping (C) -> M
    ) -> (URL) throws -> M {
        { url in
            let configuration = try JSONDecoder().decode(C.self, from: Data(contentsOf: url))
            return modelInit(configuration)
        }
    }
}

// MARK: - Unified ProcessorRegistry

public class ProcessorRegistry: @unchecked Sendable {
    private let lock = NSLock()

    private var creators: [String: @Sendable (URL, any Tokenizer) throws -> any UserInputProcessor] = [:]

    public init() {
        // If you have LLM processors that need special configs, register them here.
        // Otherwise, the default LLMUserInputProcessor doesn't need a separate configuration.
    }

    public func registerProcessorType(
        _ type: String,
        creator: @Sendable @escaping (URL, any Tokenizer) throws -> any UserInputProcessor
    ) {
        lock.lock()
        creators[type] = creator
        lock.unlock()
    }

    public func createModel(configuration: URL, processorType: String, tokenizer: any Tokenizer)
    throws -> any UserInputProcessor {
        lock.lock()
        let creator = creators[processorType]
        lock.unlock()

        guard let creator else {
            throw ModelFactoryError.unsupportedProcessorType(processorType)
        }
        return try creator(configuration, tokenizer)
    }

    // Helper for creating processor closures
    private func create<C: Codable, P: Sendable>(
        _ configurationType: C.Type, _ processorInit: @escaping (C, any Tokenizer) -> P
    ) -> (URL, any Tokenizer) throws -> P {
        { url, tokenizer in
            let configuration = try JSONDecoder().decode(
                C.self, from: Data(contentsOf: url))
            return processorInit(configuration, tokenizer)
        }
    }
}

// MARK: - Unified ModelRegistry

public class ModelRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var registry = [String: ModelConfiguration]()

    // Combine configurations from LLM and VLM:
    // LLM configurations:
    static public let smolLM_135M_4bit = ModelConfiguration(
        id: "mlx-community/SmolLM-135M-Instruct-4bit",
        defaultPrompt: "Tell me about the history of Spain."
    )

    static public let mistralNeMo4bit = ModelConfiguration(
        id: "mlx-community/Mistral-Nemo-Instruct-2407-4bit",
        defaultPrompt: "Explain quaternions."
    )

    static public let mistral7B4bit = ModelConfiguration(
        id: "mlx-community/Mistral-7B-Instruct-v0.3-4bit",
        defaultPrompt: "Describe the Swift language."
    )

    static public let codeLlama13b4bit = ModelConfiguration(
        id: "mlx-community/CodeLlama-13b-Instruct-hf-4bit-MLX",
        overrideTokenizer: "PreTrainedTokenizer",
        defaultPrompt: "func sortArray(_ array: [Int]) -> String { <FILL_ME> }"
    )

    static public let phi4bit = ModelConfiguration(
        id: "mlx-community/phi-2-hf-4bit-mlx",
        defaultPrompt: "Why is the sky blue?"
    )

    static public let phi3_5_4bit = ModelConfiguration(
        id: "mlx-community/Phi-3.5-mini-instruct-4bit",
        defaultPrompt: "What is the gravity on Mars and the moon?",
        extraEOSTokens: ["<|end|>"]
    )

    static public let phi3_5MoE = ModelConfiguration(
        id: "mlx-community/Phi-3.5-MoE-instruct-4bit",
        defaultPrompt: "What is the gravity on Mars and the moon?",
        extraEOSTokens: ["<|end|>"]
    ) {
        prompt in "<|user|>\n\(prompt)<|end|>\n<|assistant|>\n"
    }

    static public let gemma2bQuantized = ModelConfiguration(
        id: "mlx-community/quantized-gemma-2b-it",
        overrideTokenizer: "PreTrainedTokenizer",
        defaultPrompt: "what is the difference between lettuce and cabbage?"
    )

    static public let gemma_2_9b_it_4bit = ModelConfiguration(
        id: "mlx-community/gemma-2-9b-it-4bit",
        overrideTokenizer: "PreTrainedTokenizer",
        defaultPrompt: "What is the difference between lettuce and cabbage?"
    )

    static public let gemma_2_2b_it_4bit = ModelConfiguration(
        id: "mlx-community/gemma-2-2b-it-4bit",
        overrideTokenizer: "PreTrainedTokenizer",
        defaultPrompt: "What is the difference between lettuce and cabbage?"
    )

    static public let qwen205b4bit = ModelConfiguration(
        id: "mlx-community/Qwen1.5-0.5B-Chat-4bit",
        overrideTokenizer: "PreTrainedTokenizer",
        defaultPrompt: "why is the sky blue?"
    )

    static public let openelm270m4bit = ModelConfiguration(
        id: "mlx-community/OpenELM-270M-Instruct",
        defaultPrompt: "Once upon a time there was"
    )

    static public let llama3_1_8B_4bit = ModelConfiguration(
        id: "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit",
        defaultPrompt: "What is the difference between a fruit and a vegetable?"
    )

    static public let llama3_8B_4bit = ModelConfiguration(
        id: "mlx-community/Meta-Llama-3-8B-Instruct-4bit",
        defaultPrompt: "What is the difference between a fruit and a vegetable?"
    )

    static public let llama3_2_1B_4bit = ModelConfiguration(
        id: "mlx-community/Llama-3.2-1B-Instruct-4bit",
        defaultPrompt: "What is the difference between a fruit and a vegetable?"
    )

    static public let llama3_2_3B_4bit = ModelConfiguration(
        id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
        defaultPrompt: "What is the difference between a fruit and a vegetable?"
    )

    // VLM configurations:
    static public let paligemma3bMix448_8bit = ModelConfiguration(
        id: "mlx-community/paligemma-3b-mix-448-8bit",
        defaultPrompt: "Describe the image in English"
    )

    static public let qwen2VL2BInstruct4Bit = ModelConfiguration(
        id: "mlx-community/Qwen2-VL-2B-Instruct-4bit",
        defaultPrompt: "Describe the image in English"
    )

    /*static public let llava1_5_7B_4bit = ModelConfiguration(
        id: "mlx-community/llava-1.5-7b-4bit",
        defaultPrompt: "Describe the image in English"
    )*/

    private static func all() -> [ModelConfiguration] {
        [
            codeLlama13b4bit,
            gemma2bQuantized,
            gemma_2_2b_it_4bit,
            gemma_2_9b_it_4bit,
            llama3_1_8B_4bit,
            llama3_2_1B_4bit,
            llama3_2_3B_4bit,
            llama3_8B_4bit,
            mistral7B4bit,
            mistralNeMo4bit,
            openelm270m4bit,
            phi3_5MoE,
            phi3_5_4bit,
            phi4bit,
            qwen205b4bit,
            smolLM_135M_4bit,

            // VLM configs:
            paligemma3bMix448_8bit,
            qwen2VL2BInstruct4Bit,
            //llava1_5_7B_4bit
        ]
    }

    public init() {
        let configs = Self.all()
        for c in configs {
            registry[c.name] = c
        }
    }

    public func register(configurations: [ModelConfiguration]) {
        lock.lock()
        for c in configurations {
            registry[c.name] = c
        }
        lock.unlock()
    }

    public func configuration(id: String) -> ModelConfiguration {
        lock.lock()
        defer { lock.unlock() }
        return registry[id] ?? ModelConfiguration(id: id)
    }
}

// MARK: - Default LLM UserInputProcessor (from original code)

private struct LLMUserInputProcessor: UserInputProcessor {
    let tokenizer: Tokenizer
    let configuration: ModelConfiguration

    internal init(tokenizer: any Tokenizer, configuration: ModelConfiguration) {
        self.tokenizer = tokenizer
        self.configuration = configuration
    }

    func prepare(input: UserInput) throws -> LMInput {
        do {
            let messages = input.prompt.asMessages()
            let promptTokens = try tokenizer.applyChatTemplate(messages: messages)
            return LMInput(tokens: MLXArray(promptTokens))
        } catch {
            let prompt = input.prompt
                .asMessages()
                .compactMap { $0["content"] as? String }
                .joined(separator: ". ")
            let promptTokens = tokenizer.encode(text: prompt)
            return LMInput(tokens: MLXArray(promptTokens))
        }
    }
}

// MARK: - ModelFactory

public final class ModelFactory: Sendable {

    public static let shared = ModelFactory()

    public let modelRegistry = ModelRegistry()
    public let processorRegistry = ProcessorRegistry()
    public let typeRegistry = ModelTypeRegistry()

    public func configuration(id: String) -> ModelConfiguration {
        modelRegistry.configuration(id: id)
    }

    public func load(
        hub: HubApi,
        configuration: ModelConfiguration,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> ModelContext {
        let modelDirectory = try await downloadModel(
            hub: hub, configuration: configuration, progressHandler: progressHandler
        )

        let configurationURL = modelDirectory.appendingPathComponent("config.json")
        let baseConfig = try JSONDecoder().decode(BaseConfiguration.self, from: Data(contentsOf: configurationURL))

        let model = try typeRegistry.createModel(configuration: configurationURL, modelType: baseConfig.modelType)

        try loadWeights(modelDirectory: modelDirectory, model: model, quantization: baseConfig.quantization)

        let tokenizer = try await loadPatchedTokenizer(configuration: configuration, hub: hub)

        let processorConfigurationURL = modelDirectory.appendingPathComponent("preprocessor_config.json")
        let processor: any UserInputProcessor
        if FileManager.default.fileExists(atPath: processorConfigurationURL.path) {
            let baseProcessorConfig = try JSONDecoder().decode(BaseProcessorConfiguration.self, from: Data(contentsOf: processorConfigurationURL))
            processor = try processorRegistry.createModel(
                configuration: processorConfigurationURL,
                processorType: baseProcessorConfig.processorClass, tokenizer: tokenizer
            )
        } else {
            // If no special processor config, fallback to an LLM processor
            processor = LLMUserInputProcessor(tokenizer: tokenizer, configuration: configuration)
        }

        return ModelContext(configuration: configuration, model: model, processor: processor, tokenizer: tokenizer)
    }

    private func loadPatchedTokenizer(configuration: ModelConfiguration, hub: HubApi) async throws -> Tokenizer {
    var (tokenizerConfig, tokenizerData) = try await loadTokenizerConfig(configuration: configuration, hub: hub)

    var dict = tokenizerData.dictionary
    if var preTok = dict["pre_tokenizer"] as? [String: Any] {
        if let type = preTok["type"] as? String, type == "Sequence",
           var subTokArr = preTok["pretokenizers"] as? [[String: Any]] {

            // We'll scan each sub-pretokenizer. If we find 'Split' with "invert"=true, "behavior"="Removed"
            var didPatch = false
            for i in 0..<subTokArr.count {
                let item = subTokArr[i]
                if let subType = item["type"] as? String, subType == "Split",
                   let behavior = item["behavior"] as? String, behavior == "Removed",
                   let invert = item["invert"] as? Bool, invert == true {

                    // We found the destructive "Split" => remove or fix it
                    print("DEBUG: Found destructive Split pretokenizer. Removing it.")
                    subTokArr.remove(at: i)
                    didPatch = true
                    break
                }
            }
            // If we removed something, reassign the array
            if didPatch {
                preTok["pretokenizers"] = subTokArr
                dict["pre_tokenizer"] = preTok
                tokenizerData = Config(dict)
            }
        }
    }

    return try PreTrainedTokenizer(tokenizerConfig: tokenizerConfig, tokenizerData: tokenizerData)
 }
}

extension ModelConfiguration.Identifier {
    var stringValue: String {
        switch self {
        case .id(let str):
            return str
        case .directory(let url):
            return url.absoluteString
        }
    }
}


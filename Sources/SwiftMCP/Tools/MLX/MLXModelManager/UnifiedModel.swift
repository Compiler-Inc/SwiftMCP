import MLX
import MLXLMCommon
import Foundation

/// Unified protocol for both LLMs and VLMs
public protocol UnifiedModel: LanguageModel, LoRAModel {
    /// Prepare the input (text, optional image/audio/video, etc.) before inference.
    func prepare(_ input: LMInput, cache: [any KVCache], windowSize: Int?) throws -> PrepareResult
}

extension UnifiedModel {
    /// Default implementation of `prepare` for models handling text prompts in chunks.
    public func prepare(_ input: LMInput, cache: [KVCache], windowSize: Int?) throws -> PrepareResult {
        let prefillStepSize = windowSize ?? 512
        var y = input.text
        var state: LMOutput.State? = nil

        // Prepare the prompt in chunks if larger than the prefill size
        while y.tokens.size > prefillStepSize {
            let input = y[.newAxis, ..<prefillStepSize]
            let result = self(input, cache: cache.isEmpty ? nil : cache, state: state)
            eval(cache)
            y = y[prefillStepSize...]
        }

        return .tokens(y)
    }
}

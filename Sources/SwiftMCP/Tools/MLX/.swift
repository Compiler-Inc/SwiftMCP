import Foundation

/// Factory for creating MLX model handlers based on model type
public class MLXModelFactory {
    /// Supported MLX model types
    public enum ModelType {
        case mistral
        case llama
        case phi
        case custom
    }
    
    /// Create an appropriate MLX model handler for the given model type
    /// - Parameters:
    ///   - modelType: The type of MLX model to create a handler for
    ///   - toolRegistry: The tool registry to use with the model
    /// - Returns: An MLX model handler configured for the specified model type
    public static func createModelHandler(
        modelType: ModelType,
        toolRegistry: MLXToolRegistry
    ) -> MLXModelHandler {
        switch modelType {
        case .mistral:
            return MLXMistralHandler(toolRegistry: toolRegistry)
        case .llama, .phi, .custom:
            // Default to base handler for now
            // In a full implementation, you would create specialized handlers for each model type
            return MLXModelHandler(toolRegistry: toolRegistry)
        }
    }
    
    /// Detect the model type from the model configuration
    /// - Parameter modelURL: URL to the model directory
    /// - Returns: The detected model type
    public static func detectModelType(from modelURL: URL) -> ModelType {
        // Look for config.json to determine model type
        let configURL = modelURL.appendingPathComponent("config.json")
        
        guard let configData = try? Data(contentsOf: configURL) else {
            return .custom
        }
        
        // Decode the config file
        do {
            let config = try JSONDecoder().decode([String: JSON].self, from: configData)
            
            // Try to get the model_type from the config using pattern matching
            guard let modelTypeJson = config["model_type"], 
                  case .string(let modelTypeValue) = modelTypeJson else {
                return .custom
            }
            
            // Convert model_type string to ModelType enum
            switch modelTypeValue.lowercased() {
            case "mistral", "mixtral":
                return .mistral
            case "llama":
                return .llama
            case "phi":
                return .phi
            default:
                return .custom
            }
        } catch {
            return .custom
        }
    }
} 
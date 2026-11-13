// CloudLLMService.swift
// Calls a cloud LLM over HTTPS: the "old way", before on-device Apple Intelligence.
// The provider, model and API key come from Settings. With no key, a Demo mode answers instead.

import Foundation

class CloudLLMService {

    /// Sends `prompt` to the selected provider and returns the reply text.
    func complete(prompt: String) async throws -> String {
        let provider = LLMSettings.provider
        guard let apiKey = LLMSettings.apiKey(for: provider), !apiKey.isEmpty else {
            try await Task.sleep(for: .seconds(1))   // pretend to make a network call
            return demoResponse(for: prompt)
        }
        throw LLMError.invalidResponse   // The real request comes in the next step.
    }

    // MARK: – Demo mode

    private func demoResponse(for prompt: String) -> String {
        let lower = prompt.lowercased()
        if lower.contains("weather") {
            return "[Demo mode] Tomorrow in Jakarta expect around 31 °C with a chance of afternoon thunderstorms. Add an API key in Settings to get a real answer."
        }
        return "[Demo mode] A cloud model would answer “\(prompt.prefix(60))” here. Add an API key in Settings to call a real one."
    }
}

enum LLMError: LocalizedError {
    case invalidResponse
    case http(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The cloud LLM returned a reply in an unexpected format."
        case .http(let status, let body):
            let hint: String
            switch status {
            case 401, 403: hint = "The API key was rejected. Check it in Settings."
            case 404:      hint = "The model name wasn’t found. Check it in Settings."
            case 429:      hint = "Rate limit or no credit left on this key."
            default:       hint = ""
            }
            return ["HTTP \(status).", hint, body].filter { !$0.isEmpty }.joined(separator: " ")
        }
    }
}

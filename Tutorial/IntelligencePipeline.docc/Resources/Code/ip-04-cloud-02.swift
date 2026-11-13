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

        let model = LLMSettings.model(for: provider)
        let request = try makeRequest(provider: provider, model: model, apiKey: apiKey, prompt: prompt)
        print("[CloudLLM] Calling \(provider.title) model \(model)…")
        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("[CloudLLM] Network error: \(error)")
            throw error
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = serverMessage(from: data)
            print("[CloudLLM] HTTP \(http.statusCode): \(message)")
            throw LLMError.http(status: http.statusCode, body: message)
        }
        print("[CloudLLM] OK")
        guard let text = extractText(provider: provider, data: data) else {
            throw LLMError.invalidResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: – Building the request for each provider

    private func makeRequest(provider: LLMProvider, model: String, apiKey: String, prompt: String) throws -> URLRequest {
        let url: URL
        var headers = ["Content-Type": "application/json"]
        let body: [String: Any]
        let system = "Answer in two short sentences."

        switch provider {
        case .openAI:
            url = URL(string: "https://api.openai.com/v1/chat/completions")!
            headers["Authorization"] = "Bearer \(apiKey)"
            body = ["model": model,
                    "messages": [["role": "system", "content": system], ["role": "user", "content": prompt]],
                    "max_tokens": 200]
        case .gemini:
            url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
            headers["x-goog-api-key"] = apiKey
            body = ["system_instruction": ["parts": [["text": system]]],
                    "contents": [["parts": [["text": prompt]]]]]
        case .anthropic:
            url = URL(string: "https://api.anthropic.com/v1/messages")!
            headers["x-api-key"] = apiKey
            headers["anthropic-version"] = "2023-06-01"
            body = ["model": model, "max_tokens": 200, "system": system,
                    "messages": [["role": "user", "content": prompt]]]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: – Reading the reply from each provider's JSON shape

    private func extractText(provider: LLMProvider, data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        switch provider {
        case .openAI:
            let choices = json["choices"] as? [[String: Any]]
            let message = choices?.first?["message"] as? [String: Any]
            return message?["content"] as? String
        case .gemini:
            let candidates = json["candidates"] as? [[String: Any]]
            let content = candidates?.first?["content"] as? [String: Any]
            let parts = content?["parts"] as? [[String: Any]]
            return parts?.compactMap { $0["text"] as? String }.joined()
        case .anthropic:
            let content = json["content"] as? [[String: Any]]
            return content?.compactMap { $0["text"] as? String }.joined()
        }
    }

    /// Pulls the human-readable message out of an error reply, whatever the provider.
    private func serverMessage(from data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)?.prefix(200).description ?? ""
        }
        if let error = json["error"] as? [String: Any], let message = error["message"] as? String { return message }
        if let error = json["error"] as? String { return error }
        return ""
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

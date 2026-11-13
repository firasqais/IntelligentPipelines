// LLMSettings.swift
// Which cloud provider to call, which model, and the API key (kept in the Keychain).
// Nothing here is hard-coded into the app, so the project can be shared safely.

import Foundation
import Security

/// The cloud LLM providers the pipeline can call.
enum LLMProvider: String, CaseIterable, Identifiable {
    case openAI, gemini, anthropic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openAI:    return "OpenAI"
        case .gemini:    return "Google Gemini"
        case .anthropic: return "Anthropic"
        }
    }

    /// A sensible, inexpensive default model. Editable in Settings.
    var defaultModel: String {
        switch self {
        case .openAI:    return "gpt-4o-mini"
        case .gemini:    return "gemini-2.5-flash"
        case .anthropic: return "claude-haiku-5-5"
        }
    }

    var keyHelp: String {
        switch self {
        case .openAI:    return "platform.openai.com › API keys. Keys start with sk-"
        case .gemini:    return "aistudio.google.com › Get API key. Keys start with AIza"
        case .anthropic: return "console.anthropic.com › API keys. Keys start with sk-ant-"
        }
    }
}

/// Reads and writes the settings. Provider and model go in UserDefaults; the key goes in the Keychain.
enum LLMSettings {
    private static let providerKey = "llm.provider"
    private static let modelKey = "llm.model."

    static var provider: LLMProvider {
        get { LLMProvider(rawValue: UserDefaults.standard.string(forKey: providerKey) ?? "") ?? .openAI }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: providerKey) }
    }

    static func model(for provider: LLMProvider) -> String {
        let saved = UserDefaults.standard.string(forKey: modelKey + provider.rawValue) ?? ""
        return saved.isEmpty ? provider.defaultModel : saved
    }

    static func setModel(_ model: String, for provider: LLMProvider) {
        UserDefaults.standard.set(model, forKey: modelKey + provider.rawValue)
    }
}

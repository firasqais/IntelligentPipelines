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

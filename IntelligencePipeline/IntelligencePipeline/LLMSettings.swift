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

    static func apiKey(for provider: LLMProvider) -> String? {
        Keychain.read(account: provider.rawValue)
    }

    static func setAPIKey(_ key: String, for provider: LLMProvider) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { Keychain.delete(account: provider.rawValue) }
        else { Keychain.save(trimmed, account: provider.rawValue) }
    }

    /// True when the selected provider has a key, so the real API will be called.
    static var isConfigured: Bool {
        !(apiKey(for: provider) ?? "").isEmpty
    }
}

/// A tiny Keychain wrapper: one string per account.
private enum Keychain {
    private static let service = "au.edu.uts.IntelligencePipeline.apiKeys"

    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func save(_ value: String, account: String) {
        let data = Data(value.utf8)
        var q = query(account)
        if SecItemCopyMatching(q as CFDictionary, nil) == errSecSuccess {
            SecItemUpdate(q as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        } else {
            q[kSecValueData as String] = data
            SecItemAdd(q as CFDictionary, nil)
        }
    }

    static func read(account: String) -> String? {
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(account: String) {
        SecItemDelete(query(account) as CFDictionary)
    }
}

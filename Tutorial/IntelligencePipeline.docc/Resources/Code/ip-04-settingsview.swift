// SettingsView.swift
// Choose the cloud provider, model and API key. The key is stored in the Keychain, never in code.

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var provider = LLMSettings.provider
    @State private var model = ""
    @State private var apiKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Provider", selection: $provider) {
                        ForEach(LLMProvider.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Cloud LLM")
                } footer: {
                    Text("The same pipeline can call any provider. Only the request and reply formats differ; see CloudLLMService.swift.")
                }

                Section {
                    TextField("Model", text: $model, prompt: Text(provider.defaultModel))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("API key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text(provider.title)
                } footer: {
                    Text(provider.keyHelp)
                }

                Section {
                    Label(apiKey.isEmpty ? "Demo mode: a canned answer is shown instead of calling the API."
                                         : "Live: the pipeline will call \(provider.title).",
                          systemImage: apiKey.isEmpty ? "theatermasks" : "icloud.and.arrow.up")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                }
            }
            .onAppear { load(provider) }
            .onChange(of: provider) { _, newValue in load(newValue) }
        }
    }

    private func load(_ provider: LLMProvider) {
        let saved = LLMSettings.model(for: provider)
        model = saved == provider.defaultModel ? "" : saved
        apiKey = LLMSettings.apiKey(for: provider) ?? ""
    }

    private func save() {
        LLMSettings.provider = provider
        LLMSettings.setModel(model.trimmingCharacters(in: .whitespaces), for: provider)
        LLMSettings.setAPIKey(apiKey, for: provider)
    }
}

#Preview {
    SettingsView()
}

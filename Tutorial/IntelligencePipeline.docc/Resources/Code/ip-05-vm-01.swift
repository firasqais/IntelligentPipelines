// PipelineViewModel.swift
// Orchestrates all pipeline stages and exposes state to the UI.

import SwiftUI
import AVFoundation

/// Where stage 1 gets its input from.
enum InputSource: String, CaseIterable, Identifiable {
    case sample, record, text
    var id: String { rawValue }
    var title: String {
        switch self {
        case .sample: return "Sample"
        case .record: return "Record"
        case .text:   return "Type"
        }
    }
    var systemImage: String {
        switch self {
        case .sample: return "waveform"
        case .record: return "mic.fill"
        case .text:   return "keyboard"
        }
    }
}

@MainActor
class PipelineViewModel: ObservableObject {

    // MARK: – Published state
    @Published var stageStatuses: [PipelineStep: StageStatus] = Dictionary(
        uniqueKeysWithValues: PipelineStep.allCases.map { ($0, .waiting) }
    )
    @Published var finalResponse: String?
    @Published var isRunning = false
    @Published var isRecording = false
    @Published var transcript: String?
    @Published var intentResult: IntentResult?
    @Published var source: InputSource = .sample
    @Published var typedText = ""

    // MARK: – Services
    private let sampleService  = SampleAudioService()
    private let recorder       = AudioRecorderService()
    private let speechService  = SpeechTranscriberService()
    private let intentService  = IntentClassifierService()
    private let cloudService   = CloudLLMService()

    var sampleText: String { SampleAudioService.sampleText }

    // MARK: – Pipeline runner

    func runPipeline() async {
        switch source {
        case .sample:
            await run(audioURL: nil, recordLabel: "")
        case .record:
            break   // Recording: added in the next step
        case .text:
            await run(audioURL: nil, recordLabel: "")
        }
    }

    /// Runs every stage. `audioURL` is a recording; nil means use the sample or the typed text.
    private func run(audioURL: URL?, recordLabel: String) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        finalResponse = nil
        transcript = nil
        intentResult = nil
        for step in PipelineStep.allCases { stageStatuses[step] = .waiting }

        // ── Stage 1: Get audio (or text) ──────────────────────────────
        set(.record, to: .running)
        var text: String?
        var url = audioURL

        if source == .text {
            let typed = typedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !typed.isEmpty else {
                set(.record, to: .failed("Type a question first."))
                return
            }
            text = typed
            set(.record, to: .done("Typed input (no audio)"))
        } else if url == nil {
            do {
                url = try await sampleService.sampleAudio()
                set(.record, to: .done("Spoke the sample question with text-to-speech:\n“\(sampleText)”"))
            } catch {
                set(.record, to: .failed(error.localizedDescription))
                return
            }
        } else {
            set(.record, to: .done(recordLabel))
        }

        // ── Stage 2: Transcribe ────────────────────────────────────────
        set(.transcribe, to: .running)
        if let text {
            set(.transcribe, to: .done("Skipped: the input was already text"))
            transcript = text
        } else if let url {
            guard await speechService.requestPermission() else {
                set(.transcribe, to: .failed("Speech recognition permission denied. Allow it in Settings › Privacy & Security › Speech Recognition."))
                return
            }
            do {
                let result = try await speechService.transcribe(audioURL: url)
                transcript = result
                set(.transcribe, to: .done("“\(result)”\nvia \(speechService.lastEngine)"))
            } catch where source == .sample {
                // The sample was spoken from known text, so the demo can carry on honestly.
                transcript = sampleText
                set(.transcribe, to: .done("Speech recognition isn’t working here, so the known sample text was used instead:\n“\(sampleText)”\n\n\(error.localizedDescription)"))
            } catch {
                set(.transcribe, to: .failed(error.localizedDescription))
                return
            }
        }

        guard let text = transcript, !text.isEmpty else {
            set(.transcribe, to: .failed("Nothing was heard. Try again, a little louder."))
            return
        }

        // ── Stage 3: Classify intent ───────────────────────────────────
        set(.classifyIntent, to: .running)
        await Task.yield()
        let intent = intentService.classifyIntent(text: text)
        intentResult = intent
        set(.classifyIntent, to: .done("\(intent.label) (\(Int(intent.confidence * 100))%)"))

        // ── Stage 4: Cloud LLM (only if the intent router says so) ────
        if intent.requiresCloud {
            set(.cloudLLM, to: .running)
            do {
                let response = try await cloudService.complete(prompt: text)
                finalResponse = response
                let via = LLMSettings.isConfigured
                    ? "\(LLMSettings.provider.title) · \(LLMSettings.model(for: LLMSettings.provider))"
                    : "Demo mode (no API key)"
                set(.cloudLLM, to: .done("Answered by \(via)"))
            } catch {
                set(.cloudLLM, to: .failed(error.localizedDescription))
            }
        } else {
            set(.cloudLLM, to: .done("Skipped: handled on-device (confidence ≥ 75%)"))
            finalResponse = "On-device result: \(intent.label). No cloud call needed."
        }
    }

    func reset() {
        if isRecording { _ = recorder.stop(); isRecording = false }
        isRunning = false
        finalResponse = nil
        transcript = nil
        intentResult = nil
        for step in PipelineStep.allCases { stageStatuses[step] = .waiting }
    }

    // MARK: – Private
    private func set(_ step: PipelineStep, to status: StageStatus) {
        withAnimation(.easeInOut(duration: 0.25)) {
            stageStatuses[step] = status
        }
    }
}

// SpeechTranscriberService.swift
// Turns an audio file into text, trying three engines in turn:
//   1. SpeechTranscriber (iOS 26 SpeechAnalyzer): on-device, newest model, not on every iPhone.
//   2. DictationTranscriber (iOS 26 SpeechAnalyzer): on-device, works on more devices.
//   3. SFSpeechRecognizer: the older API. Needs Dictation turned on in Settings.
// `lastEngine` says which one produced the text, so the UI can show it.

import Foundation
import Speech
import AVFoundation

class SpeechTranscriberService {

    private(set) var lastEngine = ""

    // MARK: – Permission
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: – Transcription from file
    func transcribe(audioURL: URL) async throws -> String {
        var problems: [String] = []
        if let file = try? AVAudioFile(forReading: audioURL) {
            let f = file.processingFormat
            print("[Speech] Transcribing \(audioURL.lastPathComponent): \(String(format: "%.1f", Double(file.length) / f.sampleRate)) s, \(Int(f.sampleRate)) Hz, \(f.channelCount) ch")
        }

        for locale in ["en-AU", "en-US", "en-GB"] {
            do {
                let text = try await transcribeWithLegacyRecognizer(audioURL, locale: Locale(identifier: locale))
                lastEngine = "SFSpeechRecognizer (\(locale))"
                return text
            } catch {
                problems.append("SFSpeechRecognizer \(locale): \(error.localizedDescription)")
                print("[Speech] SFSpeechRecognizer \(locale) failed: \(error)")
            }
        }
        throw TranscriptionError.allFailed(problems)
    }

    // MARK: – Fallback: SFSpeechRecognizer
    private func transcribeWithLegacyRecognizer(_ url: URL, locale: Locale) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

        return try await withCheckedThrowingContinuation { continuation in
            var finished = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !finished else { return }
                if let error {
                    finished = true
                    continuation.resume(throwing: error)
                    return
                }
                guard let result, result.isFinal else { return }
                finished = true
                continuation.resume(returning: result.bestTranscription.formattedString)
            }
        }
    }
}

enum TranscriptionError: LocalizedError {
    case recognizerUnavailable
    case nothingHeard
    case noEnglishModel([String])
    case noAudioFormat
    case allFailed([String])

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognizer is not available for this locale."
        case .nothingHeard:
            return "No speech was recognised in the audio."
        case .noEnglishModel(let locales):
            return "No English speech model is offered. Available: \(locales.prefix(8).joined(separator: ", "))."
        case .noAudioFormat:
            return "The audio couldn’t be converted for the speech analyzer."
        case .allFailed(let problems):
            return "Speech recognition failed.\n" + problems.map { "• " + $0 }.joined(separator: "\n")
                + "\nOn iPhone, check Settings › General › Keyboard › Enable Dictation is on."
        }
    }
}

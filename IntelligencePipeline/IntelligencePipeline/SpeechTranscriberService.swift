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

        if SpeechTranscriber.isAvailable {
            do {
                let text = try await transcribeWithSpeechTranscriber(audioURL)
                lastEngine = "SpeechTranscriber"
                return text
            } catch {
                problems.append("SpeechTranscriber: \(error.localizedDescription)")
                print("[Speech] SpeechTranscriber failed: \(error)")
            }
        } else {
            problems.append("SpeechTranscriber: not supported on this device")
            print("[Speech] SpeechTranscriber is not available on this device")
        }

        do {
            let text = try await transcribeWithDictationTranscriber(audioURL)
            lastEngine = "DictationTranscriber"
            return text
        } catch {
            problems.append("DictationTranscriber: \(error.localizedDescription)")
            print("[Speech] DictationTranscriber failed: \(error)")
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

    // MARK: – SpeechAnalyzer engines

    private func transcribeWithSpeechTranscriber(_ url: URL) async throws -> String {
        let locale = try pickEnglish(from: await SpeechTranscriber.supportedLocales)
        let transcriber = SpeechTranscriber(locale: locale,
                                            transcriptionOptions: [],
                                            reportingOptions: [],
                                            attributeOptions: [])
        try await prepare(locale: locale, modules: [transcriber])
        let collector = Task {
            var text = ""
            for try await result in transcriber.results where result.isFinal {
                text += String(result.text.characters)
            }
            return text
        }
        return try await analyze(url, modules: [transcriber], collector: collector)
    }

    private func transcribeWithDictationTranscriber(_ url: URL) async throws -> String {
        let locale = try pickEnglish(from: await DictationTranscriber.supportedLocales)
        let transcriber = DictationTranscriber(locale: locale, preset: .longDictation)
        try await prepare(locale: locale, modules: [transcriber])
        let collector = Task {
            var text = ""
            for try await result in transcriber.results where result.isFinal {
                text += String(result.text.characters)
            }
            return text
        }
        return try await analyze(url, modules: [transcriber], collector: collector)
    }

    /// Prefers Australian, then US, then any English.
    private func pickEnglish(from supported: [Locale]) throws -> Locale {
        let english = supported.filter { $0.language.languageCode?.identifier == "en" }
        if let locale = english.first(where: { $0.region?.identifier == "AU" })
            ?? english.first(where: { $0.region?.identifier == "US" })
            ?? english.first {
            return locale
        }
        throw TranscriptionError.noEnglishModel(supported.map { $0.identifier(.bcp47) })
    }

    /// Reserves the locale for this app and downloads its model if needed.
    private func prepare(locale: Locale, modules: [any SpeechModule]) async throws {
        let reserved = await AssetInventory.reservedLocales
        if !reserved.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) {
            _ = try await AssetInventory.reserve(locale: locale)
        }
        if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
            try await request.downloadAndInstall()
        }
    }

    /// Streams the file through a SpeechAnalyzer and returns what `collector` gathered.
    private func analyze(_ url: URL, modules: [any SpeechModule], collector: Task<String, Error>) async throws -> String {
        defer { collector.cancel() }
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules) else {
            throw TranscriptionError.noAudioFormat
        }
        let analyzer = SpeechAnalyzer(modules: modules)
        let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
        try await analyzer.start(inputSequence: inputSequence)
        try feedAudio(from: url, as: format, into: inputBuilder)
        inputBuilder.finish()
        try await analyzer.finalizeAndFinishThroughEndOfInput()

        let text = try await collector.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranscriptionError.nothingHeard }
        return text
    }

    /// Reads the file and converts it to `format`, yielding one buffer per second of audio.
    private func feedAudio(from url: URL, as format: AVAudioFormat, into builder: AsyncStream<AnalyzerInput>.Continuation) throws {
        let file = try AVAudioFile(forReading: url)
        let inFormat = file.processingFormat
        guard let converter = AVAudioConverter(from: inFormat, to: format) else {
            throw TranscriptionError.noAudioFormat
        }
        let chunk = AVAudioFrameCount(inFormat.sampleRate)
        while file.framePosition < file.length {
            guard let inBuffer = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: chunk) else { break }
            try file.read(into: inBuffer, frameCount: chunk)
            if inBuffer.frameLength == 0 { break }

            let ratio = format.sampleRate / inFormat.sampleRate
            let capacity = AVAudioFrameCount(Double(inBuffer.frameLength) * ratio) + 1024
            guard let outBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { break }

            var handedOver = false
            var conversionError: NSError?
            converter.convert(to: outBuffer, error: &conversionError) { _, status in
                if handedOver { status.pointee = .noDataNow; return nil }
                handedOver = true
                status.pointee = .haveData
                return inBuffer
            }
            if let conversionError { throw conversionError }
            if outBuffer.frameLength > 0 { builder.yield(AnalyzerInput(buffer: outBuffer)) }
        }
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

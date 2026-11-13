// SampleAudioService.swift
// Creates the sample audio on the device, so the project needs no bundled recording.
// AVSpeechSynthesizer speaks the question into a file instead of the speaker;
// the pipeline then transcribes that file like any other recording.

import AVFoundation
import Foundation

final class SampleAudioService: NSObject {

    /// The question the demo speaks. Change it and the sample is regenerated on the next run.
    static let sampleText = "What is the weather going to be like in Jakarta tomorrow?"

    private let synthesizer = AVSpeechSynthesizer()

    /// Where the generated file lives. The file name includes a hash of the text,
    /// so changing `sampleText` produces a new file.
    var sampleURL: URL {
        let name = "sample-\(abs(Self.sampleText.hashValue)).caf"
        return FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }

    /// Returns a file containing the spoken sample, generating it on first use.
    func sampleAudio() async throws -> URL {
        let url = sampleURL
        if FileManager.default.fileExists(atPath: url.path) { return url }
        try await synthesize(Self.sampleText, to: url)
        return url
    }

    /// Speaks `text` into a CAF file at `url`.
    private func synthesize(_ text: String, to url: URL) async throws {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-AU") ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        try? FileManager.default.removeItem(at: url)
        var file: AVAudioFile?
        var writeError: Error?

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var finished = false
            synthesizer.write(utterance) { buffer in
                guard !finished else { return }
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                if pcm.frameLength == 0 {
                    // An empty buffer marks the end of speech.
                    finished = true
                    if let writeError { continuation.resume(throwing: writeError) }
                    else if file == nil { continuation.resume(throwing: SampleAudioError.noAudioProduced) }
                    else { continuation.resume() }
                    return
                }
                do {
                    if file == nil {
                        file = try AVAudioFile(forWriting: url,
                                               settings: pcm.format.settings,
                                               commonFormat: pcm.format.commonFormat,
                                               interleaved: pcm.format.isInterleaved)
                    }
                    try file?.write(from: pcm)
                } catch {
                    writeError = error
                }
            }
        }
        file = nil // closes the file
    }
}

enum SampleAudioError: LocalizedError {
    case noAudioProduced
    var errorDescription: String? {
        "The speech synthesizer produced no audio. Check that a voice is installed in Settings › Accessibility › Spoken Content."
    }
}

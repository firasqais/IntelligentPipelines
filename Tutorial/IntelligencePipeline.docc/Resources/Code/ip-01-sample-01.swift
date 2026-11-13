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
        // Speaking the text into the file: next step
        return url
    }
}

enum SampleAudioError: LocalizedError {
    case noAudioProduced
    var errorDescription: String? {
        "The speech synthesizer produced no audio. Check that a voice is installed in Settings › Accessibility › Spoken Content."
    }
}

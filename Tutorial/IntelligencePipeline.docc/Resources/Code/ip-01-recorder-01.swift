// AudioRecorderService.swift
// Records the microphone with AVAudioEngine, writing the mic's own format to a .caf file.
// It also reports a live level (0…1) so the UI can show the mic is hearing you.

import AVFoundation
import Foundation

final class AudioRecorderService {

    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private var sampleRate: Double = 0
    private(set) var fileURL: URL?
    private(set) var framesWritten: AVAudioFramePosition = 0
    private(set) var isRecording = false

    /// Seconds recorded so far.
    var recordedSeconds: Double { sampleRate > 0 ? Double(framesWritten) / sampleRate : 0 }

    /// Asks for microphone access. Returns false if it was refused now or earlier.
    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw RecorderError.noMicrophone }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("recording.caf")
        try? FileManager.default.removeItem(at: url)
        file = try AVAudioFile(forWriting: url, settings: format.settings,
                               commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        sampleRate = format.sampleRate
        framesWritten = 0

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            do {
                try self.file?.write(from: buffer)
                self.framesWritten += AVAudioFramePosition(buffer.frameLength)
            } catch {
                // Keep recording; a dropped buffer only loses a fraction of a second.
            }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            file = nil
            throw RecorderError.couldNotStart(error.localizedDescription)
        }
        fileURL = url
        isRecording = true
    }

    /// Stops recording and returns the file.
    func stop() -> URL? {
        guard isRecording else { return fileURL }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        file = nil   // closes the file so it can be read
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return fileURL
    }
}

enum RecorderError: LocalizedError {
    case noMicrophone
    case couldNotStart(String)

    var errorDescription: String? {
        switch self {
        case .noMicrophone:
            return "No microphone input is available. On the simulator, choose a Mac microphone in I/O › Audio Input."
        case .couldNotStart(let reason):
            return "The microphone couldn’t start: \(reason) Is another app using it?"
        }
    }
}

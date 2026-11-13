// PipelineStage.swift
// Defines the stages of the intelligence pipeline and their state.

import Foundation

/// The four stages of the pipeline.
enum PipelineStep: Int, CaseIterable, Identifiable {
    case record, transcribe, classifyIntent, cloudLLM

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .record:          return "Record"
        case .transcribe:      return "Transcribe"
        case .classifyIntent:  return "Classify Intent"
        case .cloudLLM:        return "Cloud LLM"
        }
    }

    var systemImage: String {
        switch self {
        case .record:          return "mic.fill"
        case .transcribe:      return "text.bubble.fill"
        case .classifyIntent:  return "brain.filled.head.profile"
        case .cloudLLM:        return "icloud.and.arrow.up.fill"
        }
    }
}

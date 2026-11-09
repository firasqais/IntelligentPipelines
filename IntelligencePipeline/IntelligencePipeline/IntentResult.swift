// IntentResult.swift
// Models the output of the NaturalLanguage intent classifier.

import Foundation

/// A classified intent from user speech.
struct IntentResult {
    let label: String       // e.g. "question", "command", "greeting"
    let confidence: Double  // 0.0 – 1.0

    var requiresCloud: Bool {
        // Route to cloud if label is "question" or confidence is low
        return label == "question" || confidence < 0.75
    }
}

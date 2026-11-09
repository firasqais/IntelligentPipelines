// IntentClassifierService.swift
// Uses NaturalLanguage framework to classify the intent of a text string.
// Students can swap in a Create ML NLModel for a custom domain classifier.

import Foundation
import NaturalLanguage

class IntentClassifierService {

    // MARK: – Built-in sentiment tagger (Course 1 recap)
    private let sentimentTagger = NLTagger(tagSchemes: [.sentimentScore])

    // MARK: – Intent classification
    /// Classify the intent of `text` into a simple label + confidence.
    func classifyIntent(text: String) -> IntentResult {

        // ── Keyword-based intent router (simple baseline) ──────────────
        // TODO (students): Replace with a trained NLModel from Create ML
        //   let model = try? NLModel(mlModel: MyIntentClassifier().model)
        //   return IntentResult(label: model?.predictedLabel(for: text) ?? "unknown",
        //                       confidence: model?.predictedLabelHypotheses(for: text, maximumCount: 1).values.first ?? 0)

        let lower = text.lowercased()
        if lower.contains("?") || lower.hasPrefix("what") || lower.hasPrefix("how") ||
           lower.hasPrefix("who") || lower.hasPrefix("when") || lower.hasPrefix("why") {
            return IntentResult(label: "question", confidence: 0.85)
        } else if lower.hasPrefix("set") || lower.hasPrefix("open") ||
                  lower.hasPrefix("turn") || lower.hasPrefix("call") {
            return IntentResult(label: "command", confidence: 0.88)
        } else {
            // Fallback: use sentiment to guess
            sentimentTagger.string = text
            let (sentiment, _) = sentimentTagger.tag(at: text.startIndex,
                                                     unit: .paragraph,
                                                     scheme: .sentimentScore)
            let score = Double(sentiment?.rawValue ?? "0") ?? 0
            return IntentResult(label: score >= 0 ? "positive_statement" : "negative_statement",
                                confidence: 0.60 + abs(score) * 0.3)
        }
    }
}

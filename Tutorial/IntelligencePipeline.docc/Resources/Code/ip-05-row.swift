// PipelineStageView.swift
// A single row showing a pipeline stage, its status, and its output.

import SwiftUI

struct PipelineStageView: View {
    let step: PipelineStep
    let status: StageStatus

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            // ── Stage icon ────────────────────────────────────────────
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 40, height: 40)
                Image(systemName: step.systemImage)
                    .foregroundStyle(iconForeground)
                    .font(.system(size: 16, weight: .semibold))
            }

            // ── Stage info ────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(step.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    statusBadge
                }
                if let output = status.output {
                    Text(output)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                        .textSelection(.enabled)
                }
                if case .failed(let msg) = status {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: – Sub-views
    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .waiting:
            Text("Waiting")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .running:
            HStack(spacing: 4) {
                ProgressView().scaleEffect(0.7)
                Text("Running")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private var iconBackground: Color {
        switch status {
        case .waiting:  return Color(.systemGray5)
        case .running:  return .blue.opacity(0.15)
        case .done:     return .green.opacity(0.15)
        case .failed:   return .red.opacity(0.15)
        }
    }

    private var iconForeground: Color {
        switch status {
        case .waiting:  return .secondary
        case .running:  return .blue
        case .done:     return .green
        case .failed:   return .red
        }
    }
}

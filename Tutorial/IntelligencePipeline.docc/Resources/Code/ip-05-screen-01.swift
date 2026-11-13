// ContentView.swift
// Main UI for the Intelligence Pipeline.
// Shows each stage in sequence with live status updates.

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = PipelineViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Pipeline stages ───────────────────────────────
                    VStack(spacing: 0) {
                        ForEach(Array(PipelineStep.allCases.enumerated()), id: \.element.id) { index, step in
                            PipelineStageView(
                                step: step,
                                status: vm.stageStatuses[step] ?? .waiting
                            )
                            if index < PipelineStep.allCases.count - 1 {
                                pipelineConnector(step: step)
                            }
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                    // ── Run button ────────────────────────────────────
                    Button {
                        Task { await vm.runPipeline() }
                    } label: {
                        Label(runTitle, systemImage: runSymbol)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(vm.isRunning)
                    .tint(vm.isRecording ? .red : .indigo)

                    // ── Final response ────────────────────────────────
                    if let response = vm.finalResponse {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Final Response", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold))
                            Text(response)
                                .font(.body)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    Spacer()
                }
                .padding()
                .animation(.spring(response: 0.4), value: vm.finalResponse)
            }
            .navigationTitle("Intelligence Pipeline")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset", action: vm.reset)
                }
            }
        }
    }

    private var runTitle: String {
        if vm.isRunning { return "Pipeline Running…" }
        if vm.isRecording { return "Stop & Run Pipeline" }
        return vm.source == .record ? "Start Recording" : "Run Pipeline"
    }

    private var runSymbol: String {
        if vm.isRecording { return "stop.fill" }
        return vm.source == .record ? "mic.fill" : "play.fill"
    }

    /// Vertical connector line between pipeline stages
    private func pipelineConnector(step: PipelineStep) -> some View {
        HStack {
            Spacer().frame(width: 20)
            Rectangle()
                .fill(
                    (vm.stageStatuses[step]?.isDone ?? false)
                        ? Color.green.opacity(0.4)
                        : Color(.systemGray4)
                )
                .frame(width: 2, height: 20)
                .padding(.leading, 19)
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}

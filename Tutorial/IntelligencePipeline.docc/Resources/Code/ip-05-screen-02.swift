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

                    // ── Input source ──────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Input", selection: $vm.source) {
                            ForEach(InputSource.allCases) { Label($0.title, systemImage: $0.systemImage).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .disabled(vm.isRunning || vm.isRecording)

                        switch vm.source {
                        case .sample:
                            Text("Speaks “\(vm.sampleText)” with text-to-speech, then runs it through the pipeline.")
                                .font(.caption).foregroundStyle(.secondary)
                        case .record:
                            if vm.isRecording {
                                HStack(spacing: 10) {
                                    Image(systemName: "waveform")
                                        .foregroundStyle(.red)
                                        .symbolEffect(.variableColor.iterative, isActive: vm.micLevel > 0.15)
                                    ProgressView(value: Double(vm.micLevel))
                                        .tint(.red)
                                        .animation(.linear(duration: 0.1), value: vm.micLevel)
                                    Text(String(format: "%.1f s", vm.recordedSeconds))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Text("Listening… the bar should move when you speak.")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text("Tap Start Recording, ask a question, then tap Stop & Run Pipeline.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        case .text:
                            TextField("Type a question…", text: $vm.typedText, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .submitLabel(.go)
                                .onSubmit { Task { await vm.runPipeline() } }
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

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

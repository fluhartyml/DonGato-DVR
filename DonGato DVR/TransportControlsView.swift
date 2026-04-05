//
//  TransportControlsView.swift
//  DonGato DVR
//
//  Created by Michael Fluharty on 4/5/26.
//

import SwiftUI
import SwiftData

struct TransportControlsView: View {
    @Environment(CaptureService.self) private var captureService
    @Environment(\.modelContext) private var modelContext
    @State private var showStopConfirmation = false

    var body: some View {
        HStack(spacing: 24) {
            // Record button
            Button {
                if captureService.isRecording {
                    showStopConfirmation = true
                } else {
                    captureService.startRecording()
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: captureService.isRecording ? "stop.circle.fill" : "record.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(captureService.isRecording ? .white : .red)
                    Text(captureService.isRecording ? "STOP" : "REC")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(captureService.isRecording ? .white : .red)
                }
            }
            .disabled(!captureService.deviceConnected)

            // Manual split button
            // Split button — press and hold to bracket the transition
            VStack(spacing: 4) {
                Image(systemName: "scissors")
                    .font(.system(size: 40))
                    .foregroundStyle(captureService.isSplitPressed ? .red : .yellow)
                    .scaleEffect(captureService.isSplitPressed ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: captureService.isSplitPressed)
                Text(captureService.isSplitPressed ? "HOLD" : "SPLIT")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(captureService.isSplitPressed ? .red : .yellow)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !captureService.isSplitPressed {
                            captureService.beginManualSplit()
                        }
                    }
                    .onEnded { _ in
                        captureService.endManualSplit()
                    }
            )
            .disabled(!captureService.isRecording)
            .opacity(captureService.isRecording ? 1.0 : 0.3)
        }
        .padding(.vertical, 8)
        .alert("Stop Recording?", isPresented: $showStopConfirmation) {
            Button("Stop & Process", role: .destructive) {
                Task {
                    await stopAndProcess()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will stop the recording and process \(captureService.splitPoints.count) detected split points.")
        }
    }

    private func stopAndProcess() async {
        let contentMode = captureService.contentMode
        let quality = captureService.quality
        let duration = captureService.elapsedTime

        let segmentFiles = await captureService.stopRecording()

        // Create a recording entry for each segment file
        for file in segmentFiles {
            let recording = Recording(
                title: "Seg \(file.index + 1) — \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))",
                dateRecorded: Date(),
                duration: file.duration,
                fileURL: file.url.path,
                qualityPreset: quality.rawValue,
                contentMode: contentMode.rawValue,
                fileSize: file.fileSize,
                isProcessed: true
            )

            let segment = Segment(
                index: file.index,
                startTime: file.startTime,
                endTime: file.endTime,
                detectionType: file.detectionType,
                fileURL: file.url.path,
                isExported: true
            )
            recording.segments = [segment]
            modelContext.insert(recording)
        }
    }
}

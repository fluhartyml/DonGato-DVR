//
//  RecordingsListView.swift
//  DonGato DVR
//
//  Created by Michael Fluharty on 4/5/26.
//

import SwiftUI
import SwiftData

struct RecordingsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TranscodeService.self) private var transcodeService
    @Query(sort: \Recording.dateRecorded, order: .reverse) private var recordings: [Recording]

    var body: some View {
        List {
            if transcodeService.isTranscoding {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(transcodeService.statusMessage)
                            .font(.system(size: 18))
                        ProgressView(value: transcodeService.progress)
                            .tint(.orange)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Processing")
                        .font(.system(size: 18, weight: .bold))
                }
            }

            if recordings.isEmpty {
                Section {
                    Text("No recordings yet. Connect a capture device and hit REC.")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 20)
                }
            }

            ForEach(recordings) { recording in
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(recording.title)
                                .font(.system(size: 20, weight: .bold))
                            Spacer()
                            Text(recording.qualityPreset)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        HStack {
                            Label(formatDuration(recording.duration), systemImage: "clock")
                            Spacer()
                            Label(formatFileSize(recording.fileSize), systemImage: "doc")
                            Spacer()
                            Label(recording.contentMode.uppercased(), systemImage:
                                    recording.contentMode == "chapters" ? "film.stack" : "film")
                        }
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)

                        Text(recording.dateRecorded, style: .date)
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)

                        if !recording.segments.isEmpty {
                            Divider()
                            Text("\(recording.segments.count) segments detected")
                                .font(.system(size: 18, weight: .medium))

                            ForEach(recording.segments.sorted { $0.index < $1.index }) { segment in
                                HStack {
                                    Text("Seg \(segment.index + 1)")
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    Spacer()
                                    Text(formatDuration(segment.duration))
                                        .font(.system(size: 16, design: .monospaced))
                                    Text(segment.detectionType)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Action buttons
                        HStack {
                            ShareLink(
                                item: URL(fileURLWithPath: recording.fileURL)
                            ) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 20))
                            }

                            Spacer()

                            Button {
                                Task { await splitRecording(recording) }
                            } label: {
                                Image(systemName: "scissors")
                                    .font(.system(size: 20))
                            }
                            .disabled(recording.segments.isEmpty || transcodeService.isTranscoding)

                            Spacer()

                            Menu {
                                ForEach(TranscodeQuality.allCases) { quality in
                                    Button(quality.rawValue) {
                                        Task { await transcodeRecording(recording, quality: quality) }
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 20))
                            }
                            .disabled(transcodeService.isTranscoding)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: deleteRecordings)
        }
        .navigationTitle("Recordings")
    }

    private func splitRecording(_ recording: Recording) async {
        let sourceURL = URL(fileURLWithPath: recording.fileURL)
        let outputDir = sourceURL.deletingLastPathComponent()
            .appendingPathComponent("Split_\(recording.title)", isDirectory: true)
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let splitPoints = recording.segments.map { segment in
            SplitPoint(time: segment.endTime, type: DetectionType(rawValue: segment.detectionType) ?? .manual)
        }

        do {
            let urls = try await transcodeService.splitRecording(
                sourceURL: sourceURL,
                splitPoints: splitPoints,
                outputDirectory: outputDir
            )
            // Update segments with file URLs
            for (index, url) in urls.enumerated() {
                if index < recording.segments.count {
                    recording.segments[index].fileURL = url.path
                    recording.segments[index].isExported = true
                }
            }
        } catch {
            print("Split failed: \(error)")
        }
    }

    private func transcodeRecording(_ recording: Recording, quality: TranscodeQuality) async {
        let sourceURL = URL(fileURLWithPath: recording.fileURL)
        let outputURL = sourceURL.deletingLastPathComponent()
            .appendingPathComponent("Transcoded_\(sourceURL.lastPathComponent)")

        do {
            try await transcodeService.transcode(
                sourceURL: sourceURL,
                outputURL: outputURL,
                quality: quality
            )
        } catch {
            print("Transcode failed: \(error)")
        }
    }

    private func deleteRecordings(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let recording = recordings[index]
                // Clean up file
                try? FileManager.default.removeItem(atPath: recording.fileURL)
                modelContext.delete(recording)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

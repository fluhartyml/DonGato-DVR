//
//  TranscodeService.swift
//  DonGato DVR
//
//  Created by Michael Fluharty on 4/5/26.
//

import AVFoundation

enum TranscodeQuality: String, CaseIterable, Identifiable {
    case original = "Original"
    case half = "Half Size"
    case quarter = "Quarter Size"
    case custom = "Custom"

    var id: String { rawValue }

    var scaleFactor: Float {
        switch self {
        case .original: return 1.0
        case .half: return 0.5
        case .quarter: return 0.25
        case .custom: return 0.5
        }
    }
}

@Observable
final class TranscodeService {
    private(set) var isTranscoding = false
    private(set) var progress: Float = 0
    private(set) var statusMessage: String = ""

    /// Split a recording into segments at the given split points
    func splitRecording(
        sourceURL: URL,
        splitPoints: [SplitPoint],
        outputDirectory: URL
    ) async throws -> [URL] {
        isTranscoding = true
        progress = 0
        statusMessage = "Preparing to split..."

        let asset = AVURLAsset(url: sourceURL)
        let duration = try await asset.load(.duration)
        let totalDuration = CMTimeGetSeconds(duration)

        // Build time ranges from split points
        var ranges: [(start: CMTime, end: CMTime)] = []
        let sortedSplits = splitPoints.sorted { $0.time < $1.time }

        var lastTime: CMTime = .zero
        for split in sortedSplits {
            let splitTime = CMTime(seconds: split.time, preferredTimescale: 600)
            if CMTimeGetSeconds(splitTime) - CMTimeGetSeconds(lastTime) > 0.5 {
                ranges.append((start: lastTime, end: splitTime))
            }
            lastTime = splitTime
        }
        // Add final segment
        if CMTimeGetSeconds(duration) - CMTimeGetSeconds(lastTime) > 0.5 {
            ranges.append((start: lastTime, end: duration))
        }

        if ranges.isEmpty {
            ranges.append((start: .zero, end: duration))
        }

        var outputURLs: [URL] = []
        let total = Float(ranges.count)

        for (index, range) in ranges.enumerated() {
            statusMessage = "Exporting segment \(index + 1) of \(ranges.count)..."

            let outputURL = outputDirectory.appendingPathComponent(
                "Segment_\(String(format: "%03d", index + 1)).mov"
            )

            try? FileManager.default.removeItem(at: outputURL)

            let timeRange = CMTimeRange(start: range.start, end: range.end)

            guard let exportSession = AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPresetPassthrough
            ) else { continue }

            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mov
            exportSession.timeRange = timeRange

            await exportSession.export()

            if exportSession.status == .completed {
                outputURLs.append(outputURL)
            }

            progress = Float(index + 1) / total
        }

        statusMessage = "Done — \(outputURLs.count) segments exported"
        isTranscoding = false
        return outputURLs
    }

    /// Transcode a video to a different resolution/quality
    func transcode(
        sourceURL: URL,
        outputURL: URL,
        quality: TranscodeQuality,
        customTargetSize: Int64? = nil
    ) async throws {
        isTranscoding = true
        progress = 0
        statusMessage = "Transcoding..."

        let asset = AVURLAsset(url: sourceURL)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            isTranscoding = false
            throw TranscodeError.noVideoTrack
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let scale = CGFloat(quality.scaleFactor)
        let targetWidth = Int(naturalSize.width * scale)
        let targetHeight = Int(naturalSize.height * scale)

        // Calculate bitrate
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        let bitrate: Int
        if let targetSize = customTargetSize {
            // Calculate bitrate to hit target file size
            bitrate = Int((Double(targetSize) * 8.0) / durationSeconds)
        } else {
            bitrate = targetWidth * targetHeight * 4
        }

        try? FileManager.default.removeItem(at: outputURL)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: targetWidth,
            AVVideoHeightKey: targetHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate
            ]
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writer.add(videoInput)

        // Audio — stereo AAC
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000
        ]
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        writer.add(audioInput)

        let reader = try AVAssetReader(asset: asset)

        let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        reader.add(videoReaderOutput)

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        var audioReaderOutput: AVAssetReaderTrackOutput?
        if let audioTrack = audioTracks.first {
            let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM
            ])
            reader.add(output)
            audioReaderOutput = output
        }

        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: .zero)

        // Write video
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            videoInput.requestMediaDataWhenReady(on: DispatchQueue(label: "com.dongato.transcode.video")) {
                while videoInput.isReadyForMoreMediaData {
                    if let buffer = videoReaderOutput.copyNextSampleBuffer() {
                        videoInput.append(buffer)
                        let time = CMSampleBufferGetPresentationTimeStamp(buffer)
                        let pct = CMTimeGetSeconds(time) / durationSeconds
                        DispatchQueue.main.async { [weak self] in
                            self?.progress = Float(min(pct, 1.0))
                        }
                    } else {
                        videoInput.markAsFinished()
                        continuation.resume()
                        return
                    }
                }
            }
        }

        // Write audio
        if let audioOutput = audioReaderOutput {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                audioInput.requestMediaDataWhenReady(on: DispatchQueue(label: "com.dongato.transcode.audio")) {
                    while audioInput.isReadyForMoreMediaData {
                        if let buffer = audioOutput.copyNextSampleBuffer() {
                            audioInput.append(buffer)
                        } else {
                            audioInput.markAsFinished()
                            continuation.resume()
                            return
                        }
                    }
                }
            }
        } else {
            audioInput.markAsFinished()
        }

        await writer.finishWriting()

        statusMessage = "Transcode complete"
        progress = 1.0
        isTranscoding = false
    }

    enum TranscodeError: LocalizedError {
        case noVideoTrack
        case exportFailed(String)

        var errorDescription: String? {
            switch self {
            case .noVideoTrack: return "No video track found in source file"
            case .exportFailed(let reason): return "Export failed: \(reason)"
            }
        }
    }
}

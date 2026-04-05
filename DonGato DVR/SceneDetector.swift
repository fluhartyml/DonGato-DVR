//
//  SceneDetector.swift
//  DonGato DVR
//
//  Created by Michael Fluharty on 4/5/26.
//

import AVFoundation
import CoreImage
import Accelerate

struct SplitPoint: Identifiable {
    let id = UUID()
    let time: TimeInterval
    let type: DetectionType
}

enum DetectionType: String, CaseIterable, Identifiable {
    case blackFrame = "Black Frame"
    case sceneChange = "Scene Change"
    case audioGap = "Audio Gap"
    case manual = "Manual"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .blackFrame: return "rectangle.fill"
        case .sceneChange: return "film"
        case .audioGap: return "speaker.slash"
        case .manual: return "hand.tap"
        }
    }
}

@Observable
final class SceneDetector {
    // Detection toggles
    var blackFrameEnabled = true
    var sceneChangeEnabled = true
    var audioGapEnabled = false
    var manualEnabled = true

    // Sensitivity sliders (0.0 to 1.0)
    var blackFrameThreshold: Float = 0.5    // How dark counts as "black"
    var blackFrameDuration: Float = 0.5     // Minimum seconds of black
    var sceneChangeSensitivity: Float = 0.5 // How much visual diff triggers split
    var audioGapThreshold: Float = 0.5      // Volume floor for "silence"
    var audioGapDuration: Float = 0.5       // Minimum seconds of silence

    // Callback for UI notifications
    var onSplitDetected: ((DetectionType, TimeInterval) -> Void)?

    // Internal state
    private var previousHistogram: [Float]?
    private var blackFrameStartTime: TimeInterval?
    private var silenceStartTime: TimeInterval?
    private var lastSplitTime: TimeInterval = 0
    private let minimumSplitInterval: TimeInterval = 2.0 // Prevent rapid-fire splits

    // Presets
    enum Preset: String, CaseIterable, Identifiable {
        case broadcastTV = "Broadcast TV"
        case shortForm = "Short-form Clips"
        case homeVideo = "Home Video"
        case custom = "Custom"

        var id: String { rawValue }
    }

    func applyPreset(_ preset: Preset) {
        switch preset {
        case .broadcastTV:
            blackFrameEnabled = true
            sceneChangeEnabled = false
            audioGapEnabled = true
            blackFrameThreshold = 0.7
            blackFrameDuration = 0.6
            audioGapThreshold = 0.6
            audioGapDuration = 0.8
        case .shortForm:
            blackFrameEnabled = true
            sceneChangeEnabled = true
            audioGapEnabled = false
            blackFrameThreshold = 0.5
            blackFrameDuration = 0.3
            sceneChangeSensitivity = 0.7
        case .homeVideo:
            blackFrameEnabled = false
            sceneChangeEnabled = true
            audioGapEnabled = true
            sceneChangeSensitivity = 0.4
            audioGapThreshold = 0.4
            audioGapDuration = 1.0
        case .custom:
            break
        }
    }

    // MARK: - Frame Analysis

    func analyzeFrame(_ pixelBuffer: CVPixelBuffer, at time: TimeInterval) -> SplitPoint? {
        guard time - lastSplitTime > minimumSplitInterval else { return nil }

        // Black frame detection
        if blackFrameEnabled {
            let brightness = averageBrightness(of: pixelBuffer)
            let threshold = Float(1.0 - blackFrameThreshold) * 0.15 // Scale to useful range

            if brightness < threshold {
                if blackFrameStartTime == nil {
                    blackFrameStartTime = time
                } else if let start = blackFrameStartTime {
                    let requiredDuration = TimeInterval(blackFrameDuration) * 2.0 // 0-2 seconds
                    if time - start >= requiredDuration {
                        blackFrameStartTime = nil
                        lastSplitTime = time
                        onSplitDetected?(.blackFrame, time)
                        return SplitPoint(time: time, type: .blackFrame)
                    }
                }
            } else {
                blackFrameStartTime = nil
            }
        }

        // Scene change detection via histogram comparison
        if sceneChangeEnabled {
            let histogram = computeHistogram(of: pixelBuffer)
            if let previous = previousHistogram {
                let difference = histogramDifference(previous, histogram)
                let threshold = (1.0 - sceneChangeSensitivity) * 0.8 + 0.1 // Range 0.1-0.9

                if difference > threshold {
                    previousHistogram = histogram
                    lastSplitTime = time
                    onSplitDetected?(.sceneChange, time)
                    return SplitPoint(time: time, type: .sceneChange)
                }
            }
            previousHistogram = histogram
        }

        return nil
    }

    // MARK: - Audio Analysis

    func analyzeAudio(_ sampleBuffer: CMSampleBuffer, at time: TimeInterval) -> SplitPoint? {
        guard audioGapEnabled else { return nil }
        guard time - lastSplitTime > minimumSplitInterval else { return nil }

        let rms = audioRMS(from: sampleBuffer)
        let threshold = Float(audioGapThreshold) * 0.01 // Scale to audio levels

        if rms < threshold {
            if silenceStartTime == nil {
                silenceStartTime = time
            } else if let start = silenceStartTime {
                let requiredDuration = TimeInterval(audioGapDuration) * 4.0 // 0-4 seconds
                if time - start >= requiredDuration {
                    silenceStartTime = nil
                    lastSplitTime = time
                    onSplitDetected?(.audioGap, time)
                    return SplitPoint(time: time, type: .audioGap)
                }
            }
        } else {
            silenceStartTime = nil
        }

        return nil
    }

    // MARK: - Image Processing

    private func averageBrightness(of pixelBuffer: CVPixelBuffer) -> Float {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return 0.5 }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        // Sample every 16th pixel for performance
        var totalBrightness: Float = 0
        var sampleCount: Float = 0
        let step = 16

        let pixels = baseAddress.assumingMemoryBound(to: UInt8.self)
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let offset = y * bytesPerRow + x * 4
                let b = Float(pixels[offset])
                let g = Float(pixels[offset + 1])
                let r = Float(pixels[offset + 2])
                // Luminance formula
                totalBrightness += (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
                sampleCount += 1
            }
        }

        return sampleCount > 0 ? totalBrightness / sampleCount : 0.5
    }

    private func computeHistogram(of pixelBuffer: CVPixelBuffer) -> [Float] {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return Array(repeating: 0, count: 64)
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        // 64-bin histogram (combined RGB)
        var histogram = Array(repeating: Float(0), count: 64)
        let step = 8
        var totalSamples: Float = 0

        let pixels = baseAddress.assumingMemoryBound(to: UInt8.self)
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let offset = y * bytesPerRow + x * 4
                let r = Int(pixels[offset + 2]) >> 2 // 0-63
                let g = Int(pixels[offset + 1]) >> 2
                let b = Int(pixels[offset]) >> 2
                let combined = (r + g + b) / 3
                let bin = min(combined, 63)
                histogram[bin] += 1
                totalSamples += 1
            }
        }

        // Normalize
        if totalSamples > 0 {
            for i in 0..<64 {
                histogram[i] /= totalSamples
            }
        }

        return histogram
    }

    private func histogramDifference(_ a: [Float], _ b: [Float]) -> Float {
        var diff: Float = 0
        for i in 0..<min(a.count, b.count) {
            diff += abs(a[i] - b[i])
        }
        return diff
    }

    // MARK: - Audio Processing

    private func audioRMS(from sampleBuffer: CMSampleBuffer) -> Float {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return 1.0 }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

        guard status == kCMBlockBufferNoErr, let data = dataPointer else { return 1.0 }

        let sampleCount = length / MemoryLayout<Int16>.size
        guard sampleCount > 0 else { return 1.0 }

        let samples = UnsafeBufferPointer(
            start: UnsafeRawPointer(data).assumingMemoryBound(to: Int16.self),
            count: sampleCount
        )

        var sumSquares: Float = 0
        let step = max(sampleCount / 512, 1) // Sample subset for performance
        var counted: Float = 0

        for i in stride(from: 0, to: sampleCount, by: step) {
            let sample = Float(samples[i]) / Float(Int16.max)
            sumSquares += sample * sample
            counted += 1
        }

        return counted > 0 ? sqrt(sumSquares / counted) : 1.0
    }

    func reset() {
        previousHistogram = nil
        blackFrameStartTime = nil
        silenceStartTime = nil
        lastSplitTime = 0
    }
}

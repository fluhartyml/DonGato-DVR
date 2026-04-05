//
//  CaptureService.swift
//  DonGato DVR
//
//  Created by Michael Fluharty on 4/5/26.
//

import AVFoundation
import CoreImage
import Combine

enum CaptureQuality: String, CaseIterable, Identifiable {
    case sd = "SD (480p)"
    case hd = "HD (720p)"
    case fullHD = "1080p"
    case uhd = "4K"

    var id: String { rawValue }

    var dimensions: (width: Int, height: Int) {
        switch self {
        case .sd: return (640, 480)
        case .hd: return (1280, 720)
        case .fullHD: return (1920, 1080)
        case .uhd: return (3840, 2160)
        }
    }

    var displayName: String { rawValue }
}

enum ContentMode: String, CaseIterable, Identifiable {
    case continuous = "CONTINUOUS"
    case chapters = "CHAPTERS"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .continuous: return "Broadcast — stitch around commercials"
        case .chapters: return "Split into individual clips"
        }
    }
}

@Observable
final class CaptureService: NSObject {
    private(set) var isRecording = false
    private(set) var isPreviewing = false
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var segmentTime: TimeInterval = 0
    private(set) var deviceConnected = false
    private(set) var deviceName: String = "No Device"
    private(set) var isUsingBuiltInCamera = false
    private(set) var splitPoints: [SplitPoint] = []
    private(set) var currentRecordingURL: URL?
    private(set) var splitPressTime: TimeInterval?
    var isSplitPressed = false

    var quality: CaptureQuality = .fullHD
    var contentMode: ContentMode = .chapters

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var sessionStartTime: CMTime?
    private var lastSegmentSplitTime: TimeInterval = 0
    private var recordingTimer: Timer?
    private var isWritingStarted = false

    private let processingQueue = DispatchQueue(label: "com.dongato.capture", qos: .userInitiated)
    private let audioQueue = DispatchQueue(label: "com.dongato.audio", qos: .userInitiated)

    var sceneDetector: SceneDetector?

    var previewLayer: AVCaptureVideoPreviewLayer? {
        guard let session = captureSession else { return nil }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspect
        return layer
    }

    func setupSession() {
        let session = AVCaptureSession()
        session.beginConfiguration()

        // Look for UVC capture device (Elgato or similar), fall back to built-in camera
        let externalDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external],
            mediaType: .video,
            position: .unspecified
        )

        let device: AVCaptureDevice
        if let external = externalDiscovery.devices.first {
            device = external
            isUsingBuiltInCamera = false
            deviceName = device.localizedName
        } else if let builtIn = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            device = builtIn
            isUsingBuiltInCamera = true
            deviceName = "Camcorder Mode"
        } else {
            deviceConnected = false
            deviceName = "No Camera Available"
            session.commitConfiguration()
            captureSession = session
            return
        }

        deviceConnected = true

        do {
            let videoInput = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            }

            // Audio input — external device first, then built-in mic
            let audioDevice: AVCaptureDevice?
            if !isUsingBuiltInCamera {
                let audioDiscovery = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.external],
                    mediaType: .audio,
                    position: .unspecified
                )
                audioDevice = audioDiscovery.devices.first ?? AVCaptureDevice.default(for: .audio)
            } else {
                audioDevice = AVCaptureDevice.default(for: .audio)
            }
            if let audioDevice {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            }
        } catch {
            deviceConnected = false
            deviceName = "Device Error: \(error.localizedDescription)"
        }

        // Video data output for frame analysis
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoDataOutput.setSampleBufferDelegate(self, queue: processingQueue)
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }
        self.videoOutput = videoDataOutput

        // Audio data output for silence detection
        let audioDataOutput = AVCaptureAudioDataOutput()
        audioDataOutput.setSampleBufferDelegate(self, queue: audioQueue)
        if session.canAddOutput(audioDataOutput) {
            session.addOutput(audioDataOutput)
        }
        self.audioOutput = audioDataOutput

        session.commitConfiguration()
        self.captureSession = session
    }

    func startPreview() {
        guard let session = captureSession, !session.isRunning else { return }
        processingQueue.async {
            session.startRunning()
        }
        isPreviewing = true
    }

    func stopPreview() {
        guard let session = captureSession, session.isRunning else { return }
        processingQueue.async {
            session.stopRunning()
        }
        isPreviewing = false
    }

    func startRecording() {
        guard !isRecording else { return }

        let dims = quality.dimensions
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let recordingsDir = documentsURL.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let filename = "DonGato_\(formatter.string(from: Date())).mov"
        let outputURL = recordingsDir.appendingPathComponent(filename)

        do {
            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: dims.width,
                AVVideoHeightKey: dims.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: dims.width * dims.height * 4
                ]
            ]
            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput.expectsMediaDataInRealTime = true
            if writer.canAdd(videoInput) {
                writer.add(videoInput)
            }
            self.videoWriterInput = videoInput

            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128000
            ]
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput.expectsMediaDataInRealTime = true
            if writer.canAdd(audioInput) {
                writer.add(audioInput)
            }
            self.audioWriterInput = audioInput

            writer.startWriting()
            self.assetWriter = writer
            self.currentRecordingURL = outputURL
            self.sessionStartTime = nil
            self.isWritingStarted = false
            self.splitPoints = []
            self.lastSegmentSplitTime = 0
            self.elapsedTime = 0
            self.segmentTime = 0
            self.isRecording = true

            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self, self.isRecording else { return }
                self.elapsedTime += 0.1
                self.segmentTime = self.elapsedTime - self.lastSegmentSplitTime
            }
        } catch {
            print("Failed to create writer: \(error)")
        }
    }

    func stopRecording() async -> URL? {
        guard isRecording else { return nil }
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil

        guard let writer = assetWriter else { return nil }

        videoWriterInput?.markAsFinished()
        audioWriterInput?.markAsFinished()

        await writer.finishWriting()

        let url = currentRecordingURL
        assetWriter = nil
        videoWriterInput = nil
        audioWriterInput = nil
        sessionStartTime = nil
        isWritingStarted = false

        return url
    }

    func beginManualSplit() {
        guard isRecording else { return }
        splitPressTime = elapsedTime
        isSplitPressed = true
    }

    func endManualSplit() {
        guard isRecording, let detector = sceneDetector else { return }
        let pressTime = splitPressTime ?? elapsedTime
        let releaseTime = elapsedTime
        isSplitPressed = false
        splitPressTime = nil

        // Smart snap — search between press and release for the best cut
        let point = detector.smartSnap(pressTime: pressTime, releaseTime: releaseTime)
        splitPoints.append(point)
        lastSegmentSplitTime = point.time
        segmentTime = elapsedTime - point.time
        detector.onSplitDetected?(.manual, point.time)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CaptureService: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Start the asset writer session on first frame
        if isRecording, !isWritingStarted {
            assetWriter?.startSession(atSourceTime: timestamp)
            sessionStartTime = timestamp
            isWritingStarted = true
        }

        if output == videoOutput {
            // Write video
            if isRecording, let input = videoWriterInput, input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }

            // Run scene detection on video frames
            if isRecording, let detector = sceneDetector {
                if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    let detectedSplit = detector.analyzeFrame(pixelBuffer, at: elapsedTime)
                    if let split = detectedSplit {
                        DispatchQueue.main.async { [weak self] in
                            self?.splitPoints.append(split)
                            self?.lastSegmentSplitTime = split.time
                            self?.segmentTime = 0
                        }
                    }
                }
            }
        } else if output == audioOutput {
            // Write audio
            if isRecording, let input = audioWriterInput, input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }

            // Run audio gap detection
            if isRecording, let detector = sceneDetector {
                let detectedSplit = detector.analyzeAudio(sampleBuffer, at: elapsedTime)
                if let split = detectedSplit {
                    DispatchQueue.main.async { [weak self] in
                        self?.splitPoints.append(split)
                        self?.lastSegmentSplitTime = split.time
                        self?.segmentTime = 0
                    }
                }
            }
        }
    }
}

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
    private(set) var splitPressTime: TimeInterval?
    private(set) var segmentFiles: [SegmentFile] = []
    var isSplitPressed = false
    var cameraPosition: AVCaptureDevice.Position = .back

    var quality: CaptureQuality = .fullHD
    var contentMode: ContentMode = .chapters

    // Current segment tracking
    private(set) var currentSegmentIndex = 0
    private(set) var currentSegmentURL: URL?

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
    private var isCyclingWriter = false // Lock to prevent frame drops during cycle
    private var recordingsDir: URL?
    private var recordingBaseName: String = ""
    private var segmentStartTime: TimeInterval = 0

    private let processingQueue = DispatchQueue(label: "com.dongato.capture", qos: .userInitiated)
    private let audioQueue = DispatchQueue(label: "com.dongato.audio", qos: .userInitiated)
    private let writerQueue = DispatchQueue(label: "com.dongato.writer", qos: .userInitiated)

    var sceneDetector: SceneDetector?

    var previewLayer: AVCaptureVideoPreviewLayer? {
        guard let session = captureSession else { return nil }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspect
        return layer
    }

    // MARK: - Segment File Tracking

    struct SegmentFile: Identifiable {
        let id = UUID()
        let index: Int
        let url: URL
        let startTime: TimeInterval
        var endTime: TimeInterval
        let detectionType: String

        var duration: TimeInterval { endTime - startTime }

        var fileSize: Int64 {
            (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        }
    }

    // MARK: - Session Setup

    func setupSession() {
        let session = AVCaptureSession()
        session.beginConfiguration()

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
        } else if let builtIn = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) {
            device = builtIn
            isUsingBuiltInCamera = true
            deviceName = cameraPosition == .front ? "Camcorder — Front" : "Camcorder — Rear"
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

        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoDataOutput.setSampleBufferDelegate(self, queue: processingQueue)
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }
        self.videoOutput = videoDataOutput

        let audioDataOutput = AVCaptureAudioDataOutput()
        audioDataOutput.setSampleBufferDelegate(self, queue: audioQueue)
        if session.canAddOutput(audioDataOutput) {
            session.addOutput(audioDataOutput)
        }
        self.audioOutput = audioDataOutput

        session.commitConfiguration()
        self.captureSession = session
    }

    // MARK: - Camera Controls

    func flipCamera() {
        guard isUsingBuiltInCamera, !isRecording else { return }
        cameraPosition = (cameraPosition == .back) ? .front : .back
        stopPreview()
        setupSession()
        startPreview()
    }

    func changeQuality(_ newQuality: CaptureQuality) {
        guard !isRecording else { return }
        quality = newQuality
        if isUsingBuiltInCamera {
            guard let session = captureSession else { return }
            session.beginConfiguration()
            switch newQuality {
            case .uhd:
                if session.canSetSessionPreset(.hd4K3840x2160) {
                    session.sessionPreset = .hd4K3840x2160
                }
            case .fullHD:
                if session.canSetSessionPreset(.hd1920x1080) {
                    session.sessionPreset = .hd1920x1080
                }
            case .hd:
                if session.canSetSessionPreset(.hd1280x720) {
                    session.sessionPreset = .hd1280x720
                }
            case .sd:
                if session.canSetSessionPreset(.vga640x480) {
                    session.sessionPreset = .vga640x480
                }
            }
            session.commitConfiguration()
        }
    }

    // MARK: - Preview

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

    // MARK: - Writer Management

    private func createWriter(segmentIndex: Int) throws -> (AVAssetWriter, AVAssetWriterInput, AVAssetWriterInput) {
        guard let dir = recordingsDir else {
            throw NSError(domain: "DonGato", code: 1, userInfo: [NSLocalizedDescriptionKey: "No recordings directory"])
        }

        let filename = "\(recordingBaseName)_Seg\(String(format: "%03d", segmentIndex)).mov"
        let outputURL = dir.appendingPathComponent(filename)

        let dims = quality.dimensions
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

        writer.startWriting()
        currentSegmentURL = outputURL

        return (writer, videoInput, audioInput)
    }

    private func finalizeCurrentWriter(endTime: TimeInterval, detectionType: String) {
        guard let writer = assetWriter, let url = currentSegmentURL else { return }

        videoWriterInput?.markAsFinished()
        audioWriterInput?.markAsFinished()

        let segIndex = currentSegmentIndex
        let startTime = segmentStartTime

        // Add to segment files list
        let segment = SegmentFile(
            index: segIndex,
            url: url,
            startTime: startTime,
            endTime: endTime,
            detectionType: detectionType
        )

        writer.finishWriting { [weak self] in
            DispatchQueue.main.async {
                self?.segmentFiles.append(segment)
            }
        }
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = documentsURL.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.recordingsDir = dir

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        self.recordingBaseName = "DonGato_\(formatter.string(from: Date()))"

        do {
            let (writer, videoInput, audioInput) = try createWriter(segmentIndex: 0)
            self.assetWriter = writer
            self.videoWriterInput = videoInput
            self.audioWriterInput = audioInput
            self.sessionStartTime = nil
            self.isWritingStarted = false
            self.isCyclingWriter = false
            self.splitPoints = []
            self.segmentFiles = []
            self.lastSegmentSplitTime = 0
            self.elapsedTime = 0
            self.segmentTime = 0
            self.currentSegmentIndex = 0
            self.segmentStartTime = 0
            self.isRecording = true

            sceneDetector?.reset()

            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self, self.isRecording else { return }
                self.elapsedTime += 0.1
                self.segmentTime = self.elapsedTime - self.lastSegmentSplitTime
            }
        } catch {
            print("Failed to create writer: \(error)")
        }
    }

    func stopRecording() async -> [SegmentFile] {
        guard isRecording else { return [] }
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil

        // Finalize the last segment
        finalizeCurrentWriter(endTime: elapsedTime, detectionType: "end")

        // Wait briefly for the writer to finish
        try? await Task.sleep(for: .milliseconds(500))

        let files = segmentFiles
        assetWriter = nil
        videoWriterInput = nil
        audioWriterInput = nil
        sessionStartTime = nil
        isWritingStarted = false

        return files
    }

    // MARK: - Live Split (Cycle Writer)

    private func performLiveSplit(at splitTime: TimeInterval, detectionType: String) {
        guard isRecording, !isCyclingWriter else { return }
        isCyclingWriter = true

        // Finalize the current segment
        finalizeCurrentWriter(endTime: splitTime, detectionType: detectionType)

        // Start a new segment
        currentSegmentIndex += 1
        segmentStartTime = splitTime

        do {
            let (writer, videoInput, audioInput) = try createWriter(segmentIndex: currentSegmentIndex)
            self.assetWriter = writer
            self.videoWriterInput = videoInput
            self.audioWriterInput = audioInput
            self.sessionStartTime = nil
            self.isWritingStarted = false
        } catch {
            print("Failed to cycle writer: \(error)")
        }

        isCyclingWriter = false
    }

    // MARK: - Manual Split (Press and Hold)

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

        let point = detector.smartSnap(pressTime: pressTime, releaseTime: releaseTime)
        splitPoints.append(point)
        lastSegmentSplitTime = point.time
        segmentTime = elapsedTime - point.time

        // Cycle the writer — new file starts now
        writerQueue.async { [weak self] in
            self?.performLiveSplit(at: point.time, detectionType: DetectionType.manual.rawValue)
        }

        detector.onSplitDetected?(.manual, point.time)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CaptureService: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        // Skip frames while cycling writer to prevent crashes
        guard !isCyclingWriter else { return }

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
                        // Auto-detected split — cycle writer on background queue
                        let splitTime = split.time
                        let splitType = split.type.rawValue
                        writerQueue.async { [weak self] in
                            self?.performLiveSplit(at: splitTime, detectionType: splitType)
                        }
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
                    let splitTime = split.time
                    let splitType = split.type.rawValue
                    writerQueue.async { [weak self] in
                        self?.performLiveSplit(at: splitTime, detectionType: splitType)
                    }
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

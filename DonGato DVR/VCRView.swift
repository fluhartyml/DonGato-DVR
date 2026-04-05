//
//  VCRView.swift
//  DonGato DVR
//
//  Created by Michael Fluharty on 4/5/26.
//

import SwiftUI

struct VCRView: View {
    @Environment(CaptureService.self) private var captureService
    @Environment(SceneDetector.self) private var sceneDetector
    @State private var showDetectionSettings = false

    var body: some View {
        @Bindable var capture = captureService
        @Bindable var detector = sceneDetector

        VStack(spacing: 0) {
            // Video preview area
            ZStack {
                if !captureService.deviceConnected {
                    Image("DonGatoLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 300, maxHeight: 300)
                        .opacity(0.6)
                }
                VideoPreviewContainer()
            }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 300)
                .background(Color.black)
                .overlay(alignment: .topLeading) {
                    if captureService.isRecording {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.red)
                                .frame(width: 12, height: 12)
                            Text("REC")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundStyle(.red)
                        }
                        .padding(12)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if !captureService.deviceConnected {
                        Text("NO SIGNAL")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(.red)
                            .padding(12)
                    } else if captureService.isUsingBuiltInCamera {
                        VStack(alignment: .trailing, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "video.fill")
                                Text("CAMCORDER")
                            }
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange.opacity(0.8))

                            // Flip camera button
                            Button {
                                captureService.flipCamera()
                            } label: {
                                Image(systemName: "camera.rotate.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .disabled(captureService.isRecording)
                        }
                        .padding(12)
                    }
                }

            // VCR faceplate
            VStack(spacing: 16) {
                // Device name
                Text(captureService.deviceName)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                // Dual tape counters
                TapeCounterView(
                    elapsedTime: captureService.elapsedTime,
                    segmentTime: captureService.segmentTime
                )

                // Split point indicators
                if !captureService.splitPoints.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(captureService.splitPoints.suffix(20)) { point in
                            Image(systemName: point.type.iconName)
                                .font(.system(size: 14))
                                .foregroundStyle(splitColor(for: point.type))
                        }
                    }
                    .padding(.horizontal)
                }

                // Content mode switch
                HStack(spacing: 20) {
                    ForEach(ContentMode.allCases) { mode in
                        Button {
                            capture.contentMode = mode
                        } label: {
                            Text(mode.rawValue)
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundStyle(capture.contentMode == mode ? .white : .gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    capture.contentMode == mode ? Color.blue.opacity(0.3) : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }

                // Quality selector
                HStack(spacing: 12) {
                    ForEach(CaptureQuality.allCases) { q in
                        Button {
                            captureService.changeQuality(q)
                        } label: {
                            Text(q.displayName)
                                .font(.system(size: 18, weight: .medium, design: .monospaced))
                                .foregroundStyle(capture.quality == q ? .white : .gray)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    capture.quality == q ? Color.orange.opacity(0.3) : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }

                // Transport controls
                TransportControlsView()

                // Detection settings button
                Button {
                    showDetectionSettings = true
                } label: {
                    HStack {
                        Image(systemName: "waveform.badge.magnifyingglass")
                        Text("Detection Settings")
                    }
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.orange)
                    .padding(.vertical, 8)
                }
                .padding(.bottom, 12)
            }
            .background(Color(white: 0.08))
        }
        .sheet(isPresented: $showDetectionSettings) {
            DetectionSettingsView()
        }
        .onAppear {
            captureService.sceneDetector = sceneDetector
            captureService.setupSession()
            captureService.startPreview()
        }
        .onDisappear {
            captureService.stopPreview()
        }
    }

    private func splitColor(for type: DetectionType) -> Color {
        switch type {
        case .blackFrame: return .purple
        case .sceneChange: return .cyan
        case .audioGap: return .yellow
        case .manual: return .green
        }
    }
}

//
//  DVRSettingsView.swift
//  DonGato DVR
//
//  Created by Michael Fluharty on 4/5/26.
//

import SwiftUI
import AVFoundation

enum VideoRotation: String, CaseIterable, Identifiable {
    case none = "0°"
    case quarter = "90°"
    case half = "180°"
    case threeQuarter = "270°"

    var id: String { rawValue }

    var angle: CGFloat {
        switch self {
        case .none: return 0
        case .quarter: return 90
        case .half: return 180
        case .threeQuarter: return 270
        }
    }
}

enum AspectRatioMode: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case widescreen = "16:9"
    case standard = "4:3"
    case square = "1:1"

    var id: String { rawValue }
}

@Observable
final class DVRSettings {
    var rotation: VideoRotation = .none
    var isMirrored: Bool = false
    var aspectRatio: AspectRatioMode = .auto

    /// Lock the current rotation/mirror as the new "upright" baseline
    func lockCurrentOrientation() {
        // Current settings become the new normal — nothing to change,
        // they're already applied. This confirms "this is correct."
    }

    /// Reset all DVR settings to factory defaults
    func resetToFactory() {
        rotation = .none
        isMirrored = false
        aspectRatio = .auto
    }
}

struct DVRSettingsView: View {
    @Environment(DVRSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var s = settings

        NavigationStack {
            List {
                // Rotation
                Section {
                    Picker("Rotation", selection: $s.rotation) {
                        ForEach(VideoRotation.allCases) { rot in
                            Text(rot.rawValue).tag(rot)
                        }
                    }
                    .pickerStyle(.segmented)
                    .font(.system(size: 18))
                } header: {
                    Label("Rotation", systemImage: "rotate.right")
                        .font(.system(size: 18, weight: .bold))
                } footer: {
                    Text("Correct rotated video from external capture devices.")
                        .font(.system(size: 14))
                }

                // Mirror
                Section {
                    Toggle("Horizontal Flip", isOn: $s.isMirrored)
                        .font(.system(size: 18))
                } header: {
                    Label("Mirror", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                        .font(.system(size: 18, weight: .bold))
                } footer: {
                    Text("Flip the video horizontally to correct mirrored sources.")
                        .font(.system(size: 14))
                }

                // Aspect Ratio
                Section {
                    Picker("Aspect Ratio", selection: $s.aspectRatio) {
                        ForEach(AspectRatioMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .font(.system(size: 18))
                } header: {
                    Label("Aspect Ratio", systemImage: "aspectratio")
                        .font(.system(size: 18, weight: .bold))
                } footer: {
                    Text("Auto uses the source's native ratio. Override for non-standard sources.")
                        .font(.system(size: 14))
                }

                // Preview of current settings
                Section {
                    HStack {
                        Spacer()
                        Image(systemName: "tv")
                            .font(.system(size: 60))
                            .foregroundStyle(.orange)
                            .rotationEffect(.degrees(settings.rotation.angle))
                            .scaleEffect(x: settings.isMirrored ? -1 : 1, y: 1)
                            .animation(.easeInOut(duration: 0.3), value: settings.rotation)
                            .animation(.easeInOut(duration: 0.3), value: settings.isMirrored)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                } header: {
                    Text("Preview")
                        .font(.system(size: 18, weight: .bold))
                }

                // Reset
                Section {
                    Button(role: .destructive) {
                        settings.resetToFactory()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Reset to Factory")
                                .font(.system(size: 18, weight: .medium))
                            Spacer()
                        }
                    }
                } footer: {
                    Text("Resets rotation, mirror, and aspect ratio to defaults.")
                        .font(.system(size: 14))
                }
            }
            .navigationTitle("DVR Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 18))
                }
            }
        }
    }
}

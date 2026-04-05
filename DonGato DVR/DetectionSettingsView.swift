//
//  DetectionSettingsView.swift
//  DonGato DVR
//
//  Created by Michael Fluharty on 4/5/26.
//

import SwiftUI

struct DetectionSettingsView: View {
    @Environment(SceneDetector.self) private var detector
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPreset: SceneDetector.Preset = .custom

    var body: some View {
        @Bindable var det = detector

        NavigationStack {
            List {
                // Presets
                Section {
                    ForEach(SceneDetector.Preset.allCases) { preset in
                        Button {
                            selectedPreset = preset
                            detector.applyPreset(preset)
                        } label: {
                            HStack {
                                Text(preset.rawValue)
                                    .font(.system(size: 18))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedPreset == preset {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Presets")
                        .font(.system(size: 18, weight: .bold))
                }

                // Black Frame Detection
                Section {
                    Toggle("Enabled", isOn: $det.blackFrameEnabled)
                        .font(.system(size: 18))
                        .onChange(of: det.blackFrameEnabled) { selectedPreset = .custom }

                    if det.blackFrameEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Darkness Threshold")
                                .font(.system(size: 18))
                            Slider(value: $det.blackFrameThreshold, in: 0...1)
                                .onChange(of: det.blackFrameThreshold) { selectedPreset = .custom }
                            HStack {
                                Text("Lenient")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Strict")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Minimum Duration")
                                .font(.system(size: 18))
                            Slider(value: $det.blackFrameDuration, in: 0...1)
                                .onChange(of: det.blackFrameDuration) { selectedPreset = .custom }
                            HStack {
                                Text("Short")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Long")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Label("Black Frame", systemImage: "rectangle.fill")
                        .font(.system(size: 18, weight: .bold))
                }

                // Scene Change Detection
                Section {
                    Toggle("Enabled", isOn: $det.sceneChangeEnabled)
                        .font(.system(size: 18))
                        .onChange(of: det.sceneChangeEnabled) { selectedPreset = .custom }

                    if det.sceneChangeEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sensitivity")
                                .font(.system(size: 18))
                            Slider(value: $det.sceneChangeSensitivity, in: 0...1)
                                .onChange(of: det.sceneChangeSensitivity) { selectedPreset = .custom }
                            HStack {
                                Text("Less Splits")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("More Splits")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Label("Scene Change", systemImage: "film")
                        .font(.system(size: 18, weight: .bold))
                }

                // Audio Gap Detection
                Section {
                    Toggle("Enabled", isOn: $det.audioGapEnabled)
                        .font(.system(size: 18))
                        .onChange(of: det.audioGapEnabled) { selectedPreset = .custom }

                    if det.audioGapEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Silence Threshold")
                                .font(.system(size: 18))
                            Slider(value: $det.audioGapThreshold, in: 0...1)
                                .onChange(of: det.audioGapThreshold) { selectedPreset = .custom }
                            HStack {
                                Text("Quiet")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Silent")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Gap Duration")
                                .font(.system(size: 18))
                            Slider(value: $det.audioGapDuration, in: 0...1)
                                .onChange(of: det.audioGapDuration) { selectedPreset = .custom }
                            HStack {
                                Text("Short")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Long")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Label("Audio Gap", systemImage: "speaker.slash")
                        .font(.system(size: 18, weight: .bold))
                }

                // Manual Split
                Section {
                    Toggle("Enabled", isOn: $det.manualEnabled)
                        .font(.system(size: 18))
                } header: {
                    Label("Manual Split", systemImage: "hand.tap")
                        .font(.system(size: 18, weight: .bold))
                } footer: {
                    Text("Tap the scissors button during recording to manually mark a split point.")
                        .font(.system(size: 14))
                }
            }
            .navigationTitle("Detection Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 18))
                }
            }
        }
    }
}

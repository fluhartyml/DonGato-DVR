//
//  AboutView.swift
//  DonGato DVR
//
//  Created by Michael Fluharty on 4/5/26.
//

import SwiftUI

struct AboutView: View {
    @State private var showEasterEgg = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App icon and name
                VStack(spacing: 12) {
                    Image("DonGatoLogo")
                        .resizable()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(radius: 8)

                    Text("DonGato DVR")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))

                    Text(appVersion)
                        .font(.system(size: 18, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                Divider()

                // Legal disclaimer
                VStack(alignment: .leading, spacing: 8) {
                    Text("LEGAL NOTICE")
                        .font(.system(size: 18, weight: .bold))

                    Text("By using DonGato DVR, you agree that you own or have the legal right to record all content captured with this application. DonGato DVR does not contain any DRM circumvention, breaking, or disabling technology. Breaking DRM is illegal under the Digital Millennium Copyright Act (DMCA) and equivalent international laws. All video sources captured by DonGato DVR are assumed to be intellectual property owned by the user. The user is solely responsible for ensuring they have the legal right to record and store any content captured with this application.")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Divider()

                // Technologies
                VStack(alignment: .leading, spacing: 16) {
                    Text("BUILT WITH")
                        .font(.system(size: 18, weight: .bold))
                        .padding(.horizontal)

                    TechCreditRow(
                        name: "AVFoundation",
                        description: "Video capture, recording, and playback engine",
                        license: "Apple Framework"
                    )

                    TechCreditRow(
                        name: "Core Image & Vision",
                        description: "Scene detection and frame analysis",
                        license: "Apple Framework"
                    )

                    TechCreditRow(
                        name: "SwiftData",
                        description: "Recording metadata and segment persistence",
                        license: "Apple Framework"
                    )

                    TechCreditRow(
                        name: "SwiftUI",
                        description: "User interface framework",
                        license: "Apple Framework"
                    )

                    Button {
                        showEasterEgg = true
                    } label: {
                        TechCreditRow(
                            name: "Engineered with Claude by Anthropic",
                            description: "AI-assisted development",
                            license: ""
                        )
                    }
                }

                Divider()

                // License
                VStack(alignment: .leading, spacing: 8) {
                    Text("LICENSE")
                        .font(.system(size: 18, weight: .bold))

                    Text("GNU General Public License v3.0")
                        .font(.system(size: 18))

                    Text("Share and share alike with attribution required.")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Divider()

                // Credits
                VStack(spacing: 8) {
                    Text("Michael Fluharty")
                        .font(.system(size: 20, weight: .bold))
                    Text("sigfigprd")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("About")
        .sheet(isPresented: $showEasterEgg) {
            VStack(spacing: 20) {
                Image(systemName: "sparkle")
                    .font(.system(size: 80))
                    .foregroundStyle(.purple)
                    .symbolEffect(.pulse, isActive: true)

                Text("Hello from Claude")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))

                Text("Anthropic")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)

                Button("Dismiss") { showEasterEgg = false }
                    .font(.system(size: 18))
                    .padding(.top, 20)
            }
            .presentationDetents([.medium])
        }
    }
}

struct TechCreditRow: View {
    let name: String
    let description: String
    let license: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
            Text(description)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            if !license.isEmpty {
                Text(license)
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal)
    }
}

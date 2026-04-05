//
//  TapeCounterView.swift
//  DonGato DVR
//
//  Created by Michael Fluharty on 4/5/26.
//

import SwiftUI

struct TapeCounterView: View {
    let elapsedTime: TimeInterval
    let segmentTime: TimeInterval

    var body: some View {
        HStack(spacing: 30) {
            // Total elapsed counter
            VStack(spacing: 4) {
                Text("ELAPSED")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.gray)
                Text(formatTime(elapsedTime))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                    .monospacedDigit()
            }

            Rectangle()
                .fill(.gray.opacity(0.3))
                .frame(width: 1, height: 50)

            // Current segment counter
            VStack(spacing: 4) {
                Text("SEGMENT")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.gray)
                Text(formatTime(segmentTime))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

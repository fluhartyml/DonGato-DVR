//
//  Segment.swift
//  DonGato DVR
//
//  Created by Michael Fluharty on 4/5/26.
//

import Foundation
import SwiftData

@Model
final class Segment {
    var index: Int
    var startTime: TimeInterval
    var endTime: TimeInterval
    var detectionType: String // "black_frame", "scene_change", "audio_gap", "manual"
    var fileURL: String
    var isExported: Bool

    var duration: TimeInterval {
        endTime - startTime
    }

    init(
        index: Int = 0,
        startTime: TimeInterval = 0,
        endTime: TimeInterval = 0,
        detectionType: String = "manual",
        fileURL: String = "",
        isExported: Bool = false
    ) {
        self.index = index
        self.startTime = startTime
        self.endTime = endTime
        self.detectionType = detectionType
        self.fileURL = fileURL
        self.isExported = isExported
    }
}

//
//  Recording.swift
//  DonGato DVR
//
//  Created by Michael Fluharty on 4/5/26.
//

import Foundation
import SwiftData

@Model
final class Recording {
    var title: String
    var dateRecorded: Date
    var duration: TimeInterval
    var fileURL: String
    var qualityPreset: String
    var contentMode: String // "continuous" or "chapters"
    var fileSize: Int64
    var isProcessed: Bool

    @Relationship(deleteRule: .cascade)
    var segments: [Segment]

    init(
        title: String = "Untitled Recording",
        dateRecorded: Date = Date(),
        duration: TimeInterval = 0,
        fileURL: String = "",
        qualityPreset: String = "1080p",
        contentMode: String = "chapters",
        fileSize: Int64 = 0,
        isProcessed: Bool = false,
        segments: [Segment] = []
    ) {
        self.title = title
        self.dateRecorded = dateRecorded
        self.duration = duration
        self.fileURL = fileURL
        self.qualityPreset = qualityPreset
        self.contentMode = contentMode
        self.fileSize = fileSize
        self.isProcessed = isProcessed
        self.segments = segments
    }
}

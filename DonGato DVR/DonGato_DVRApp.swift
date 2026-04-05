//
//  DonGato_DVRApp.swift
//  DonGato DVR
//
//  Created by Michael Fluharty on 4/5/26.
//

import SwiftUI
import SwiftData

@main
struct DonGato_DVRApp: App {
    @State private var captureService = CaptureService()
    @State private var sceneDetector = SceneDetector()
    @State private var transcodeService = TranscodeService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Recording.self,
            Segment.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(captureService)
                .environment(sceneDetector)
                .environment(transcodeService)
        }
        .modelContainer(sharedModelContainer)
    }
}

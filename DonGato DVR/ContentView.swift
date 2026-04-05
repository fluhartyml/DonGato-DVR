//
//  ContentView.swift
//  DonGato DVR
//
//  Created by Michael Fluharty on 4/5/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            VCRView()
                .tabItem {
                    Label("VCR", systemImage: "tv")
                }

            NavigationStack {
                RecordingsListView()
            }
            .tabItem {
                Label("Recordings", systemImage: "film.stack")
            }

            NavigationStack {
                AboutView()
            }
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
    }
}

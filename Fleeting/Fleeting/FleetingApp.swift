//
//  FleetingApp.swift
//  Fleeting
//
//  Created by Shriram Vasudevan on 4/14/25.
//

import SwiftUI

@main
struct FleetingApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var journalManager = JournalStorageManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(journalManager)
                .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

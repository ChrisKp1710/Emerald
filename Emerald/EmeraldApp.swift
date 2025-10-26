//
//  EmeraldApp.swift
//  Emerald
//
//  Created by Christian Koscielniak Pinto on 26/10/25.
//

import SwiftUI
import OSLog
import Combine
import UniformTypeIdentifiers

@main
struct EmeraldApp: App {
    @StateObject private var emulatorState = EmulatorState()
    @StateObject private var romLibrary = ROMLibrary()
    @StateObject private var settings = EmulatorSettings()
    @Environment(\.openWindow) private var openWindow
    
    init() {
        // Listen for ROM Library open requests
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OpenROMLibrary"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                NSApp.sendAction(Selector(("openROMLibraryWindow:")), to: nil, from: nil)
            }
        }
    }
    
    var body: some Scene {
        // Main emulator window
        WindowGroup("Emerald GBA Emulator") {
            MainEmulatorView()
                .environmentObject(emulatorState)
                .environmentObject(romLibrary)
                .environmentObject(settings)
                .focusedEmulatorState(emulatorState)
                .focusedROMLibrary(romLibrary)
                .focusedEmulatorSettings(settings)
                .frame(minWidth: 480, minHeight: 320)
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        .commands {
            EmulatorMenuCommands()
        }
        
        // ROM Library window
        WindowGroup("ROM Library", id: "library") {
            ROMLibraryView()
                .environmentObject(romLibrary)
                .environmentObject(settings)
                .frame(minWidth: 800, minHeight: 600)
        }
        
        // Settings window
        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(emulatorState)
        }
    }
}

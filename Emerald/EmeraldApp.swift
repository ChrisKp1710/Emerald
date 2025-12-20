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
        // Main window - Everything integrated!
        WindowGroup("Emerald GBA Emulator") {
            MainEmulatorView()
                .environmentObject(emulatorState)
                .environmentObject(romLibrary)
                .environmentObject(settings)
                .focusedEmulatorState(emulatorState)
                .focusedROMLibrary(romLibrary)
                .focusedEmulatorSettings(settings)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)
        .commands {
            EmulatorMenuCommands()
        }
        
        // Settings window
        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(emulatorState)
        }
    }
}

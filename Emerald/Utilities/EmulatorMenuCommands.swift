//
//  EmulatorMenuCommands.swift
//  Emerald
//
//  Created by Christian Koscielniak Pinto on 26/10/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct EmulatorMenuCommands: Commands {
    @FocusedValue(\.emulatorState) private var emulatorState
    @FocusedValue(\.romLibrary) private var romLibrary
    @FocusedValue(\.emulatorSettings) private var settings
    
    var body: some Commands {
        // File Menu
        CommandGroup(replacing: .newItem) {
            Button("Open ROM...") {
                // Open ROM file picker
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.init(filenameExtension: "gba")!, 
                                           .init(filenameExtension: "bin")!,
                                           .init(filenameExtension: "rom")!]
                panel.allowsMultipleSelection = false
                
                if panel.runModal() == .OK, let url = panel.url {
                    Task {
                        try? await romLibrary?.addROM(from: url)
                        if let rom = romLibrary?.roms.first(where: { $0.url == url }) {
                            try? await emulatorState?.loadROM(rom)
                            emulatorState?.startEmulation()
                        }
                    }
                }
            }
            .keyboardShortcut("o", modifiers: .command)
            
            Button("Show ROM Library...") {
                NSApp.sendAction(#selector(AppDelegate.showROMLibrary), to: nil, from: nil)
            }
            .keyboardShortcut("l", modifiers: .command)
            
            Divider()
            
            Button("Close ROM") {
                emulatorState?.stopEmulation()
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(emulatorState?.currentROM == nil)
        }
        
        // Emulation Menu
        CommandMenu("Emulation") {
            Button(emulatorState?.isRunning == true && emulatorState?.isPaused == false ? "Pause" : "Resume") {
                if emulatorState?.isRunning == true {
                    if emulatorState?.isPaused == true {
                        emulatorState?.resumeEmulation()
                    } else {
                        emulatorState?.pauseEmulation()
                    }
                } else {
                    emulatorState?.startEmulation()
                }
            }
            .keyboardShortcut(.space)
            .disabled(emulatorState?.currentROM == nil)
            
            Button("Reset") {
                Task {
                    await emulatorState?.reset()
                }
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(emulatorState?.currentROM == nil)
            
            Button("Stop") {
                emulatorState?.stopEmulation()
            }
            .keyboardShortcut(".", modifiers: .command)
            .disabled(emulatorState?.isRunning != true)
            
            Divider()
            
            Menu("Emulation Speed") {
                Button("0.25×") {
                    emulatorState?.emulationSpeed = 0.25
                }
                .keyboardShortcut("1", modifiers: .command)
                
                Button("0.5×") {
                    emulatorState?.emulationSpeed = 0.5
                }
                .keyboardShortcut("2", modifiers: .command)
                
                Button("1.0× (Normal)") {
                    emulatorState?.emulationSpeed = 1.0
                }
                .keyboardShortcut("3", modifiers: .command)
                
                Button("2.0×") {
                    emulatorState?.emulationSpeed = 2.0
                }
                .keyboardShortcut("4", modifiers: .command)
                
                Button("4.0×") {
                    emulatorState?.emulationSpeed = 4.0
                }
                .keyboardShortcut("5", modifiers: .command)
            }
            .disabled(emulatorState?.currentROM == nil)
            
            Divider()
            
            Menu("Save State") {
                ForEach(0..<10, id: \.self) { slot in
                    Button("Slot \(slot)") {
                        Task {
                            try? await emulatorState?.saveState(to: slot)
                        }
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(slot)")), modifiers: .command)
                }
            }
            .disabled(emulatorState?.currentROM == nil)
            
            Menu("Load State") {
                ForEach(0..<10, id: \.self) { slot in
                    Button("Slot \(slot)") {
                        Task {
                            try? await emulatorState?.loadState(from: slot)
                        }
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(slot)")), modifiers: [.command, .shift])
                }
            }
            .disabled(emulatorState?.currentROM == nil)
        }
        
        // Video Menu
        CommandMenu("Video") {
            Menu("Scale") {
                Button("1×") {
                    settings?.displayScale = 1.0
                }
                Button("2×") {
                    settings?.displayScale = 2.0
                }
                Button("3×") {
                    settings?.displayScale = 3.0
                }
                Button("4×") {
                    settings?.displayScale = 4.0
                }
                Button("5×") {
                    settings?.displayScale = 5.0
                }
                Button("6×") {
                    settings?.displayScale = 6.0
                }
            }
            
            Toggle("Maintain Aspect Ratio", isOn: Binding(
                get: { settings?.maintainAspectRatio ?? true },
                set: { settings?.maintainAspectRatio = $0 }
            ))
            
            Divider()
            
            Menu("Scaling Filter") {
                ForEach(ScalingFilter.allCases, id: \.self) { filter in
                    Button(filter.rawValue) {
                        settings?.scalingFilter = filter
                    }
                }
            }
            
            Toggle("Color Correction", isOn: Binding(
                get: { settings?.colorCorrection ?? true },
                set: { settings?.colorCorrection = $0 }
            ))
            
            Divider()
            
            Toggle("Vertical Sync", isOn: Binding(
                get: { settings?.enableVSync ?? true },
                set: { settings?.enableVSync = $0 }
            ))
        }
        
        // Audio Menu
        CommandMenu("Audio") {
            Toggle("Enable Audio", isOn: Binding(
                get: { settings?.audioEnabled ?? true },
                set: { settings?.audioEnabled = $0 }
            ))
            
            Divider()
            
            Menu("Volume") {
                Button("25%") {
                    settings?.masterVolume = 0.25
                }
                Button("50%") {
                    settings?.masterVolume = 0.5
                }
                Button("75%") {
                    settings?.masterVolume = 0.75
                }
                Button("100%") {
                    settings?.masterVolume = 1.0
                }
            }
            .disabled(settings?.audioEnabled != true)
        }
        
        // Window Menu Additions
        CommandGroup(after: .windowSize) {
            Button("ROM Library") {
                NSApp.sendAction(#selector(AppDelegate.showROMLibrary), to: nil, from: nil)
            }
            .keyboardShortcut("l", modifiers: .command)
        }
        
        // Help Menu Additions
        CommandGroup(after: .help) {
            Button("Emerald Help") {
                NSWorkspace.shared.open(URL(string: "https://github.com/your-username/emerald/wiki")!)
            }
            
            Button("Report Issue") {
                NSWorkspace.shared.open(URL(string: "https://github.com/your-username/emerald/issues")!)
            }
            
            Divider()
            
            Button("Show Debug Information") {
                settings?.debugMode.toggle()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
        
        // Debug Menu
        CommandMenu("Debug") {
            Button("Toggle Log Console") {
                Task { @MainActor in
                    LogManager.shared.toggle()
                }
            }
            .keyboardShortcut("`", modifiers: .command)
            
            Button("Clear Logs") {
                Task { @MainActor in
                    LogManager.shared.clear()
                }
            }
            
            Divider()
            
            Button("Show FPS") {
                // Toggle FPS display
            }
        }
    }
}

// MARK: - AppDelegate for Window Management

@objc class AppDelegate: NSObject, NSApplicationDelegate {
    private var romLibraryWindow: NSWindow?
    
    @objc func showROMLibrary() {
        if let window = romLibraryWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // Create ROM Library window programmatically if needed
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
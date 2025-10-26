//
//  MainEmulatorView.swift
//  Emerald
//
//  Created by Christian Koscielniak Pinto on 26/10/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct MainEmulatorView: View {
    @EnvironmentObject private var emulatorState: EmulatorState
    @EnvironmentObject private var romLibrary: ROMLibrary
    @EnvironmentObject private var settings: EmulatorSettings
    @StateObject private var logManager = LogManager.shared
    
    @State private var showingFilePicker = false
    @State private var showingROMLibrary = false
    @State private var dragOver = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main emulator area
            emulatorContent
            
            // Log console (toggleable)
            if logManager.isVisible {
                LogConsoleView()
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
            handleDrop(providers: providers)
        }
    }
    
    var emulatorContent: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                if let currentROM = emulatorState.currentROM {
                    // Emulator screen
                    EmulatorScreenView()
                        .aspectRatio(240.0/160.0, contentMode: .fit)
                        .scaleEffect(settings.displayScale)
                        .clipped()
                } else {
                    // Welcome screen
                    WelcomeView()
                }
                
                // Drag overlay
                if dragOver {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .background(Color.accentColor.opacity(0.1))
                        .overlay(
                            VStack(spacing: 16) {
                                Image(systemName: "gamecontroller")
                                    .font(.system(size: 48))
                                    .foregroundColor(.accentColor)
                                
                                Text("Drop ROM file to play")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                        )
                        .padding(20)
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
            handleDrop(providers: providers)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [
                UTType(filenameExtension: "gba", conformingTo: .data) ?? .data,
                UTType(filenameExtension: "bin", conformingTo: .data) ?? .data,
                UTType(filenameExtension: "rom", conformingTo: .data) ?? .data
            ]
        ) { result in
            handleFileImport(result: result)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if emulatorState.isRunning {
                    Button(emulatorState.isPaused ? "Resume" : "Pause") {
                        if emulatorState.isPaused {
                            emulatorState.resumeEmulation()
                        } else {
                            emulatorState.pauseEmulation()
                        }
                    }
                    .keyboardShortcut(.space, modifiers: [])
                    
                    Button("Stop") {
                        emulatorState.stopEmulation()
                    }
                    .keyboardShortcut(".", modifiers: .command)
                }
                
                Button("Open ROM...") {
                    showingFilePicker = true
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        _ = provider.loadObject(ofClass: URL.self) { url, error in
            if let url = url {
                DispatchQueue.main.async {
                    loadROM(from: url)
                }
            }
        }
        return true
    }
    
    private func handleFileImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            loadROM(from: url)
        case .failure(let error):
            print("Failed to import file: \(error)")
        }
    }
    
    private func loadROM(from url: URL) {
        Task {
            do {
                // First try to add to library if not already there
                if !romLibrary.roms.contains(where: { $0.url == url }) {
                    try await romLibrary.addROM(from: url)
                }
                
                // Find the ROM in the library
                if let rom = romLibrary.roms.first(where: { $0.url == url }) {
                    try await emulatorState.loadROM(rom)
                    emulatorState.startEmulation()
                }
            } catch {
                print("Failed to load ROM: \(error)")
            }
        }
    }
}

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 72))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Emerald GBA Emulator")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Drop a ROM file here or use File > Open ROM...")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                Button("Open ROM Library") {
                    // Open ROM Library window
                    if let url = URL(string: "emerald://library") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .keyboardShortcut("l", modifiers: .command)
                
                Button("Open ROM...") {
                    // This will trigger the file picker
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            .padding(.top)
        }
        .padding(40)
    }
}

#Preview {
    MainEmulatorView()
        .environmentObject(EmulatorState())
        .environmentObject(ROMLibrary())
        .environmentObject(EmulatorSettings())
}
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
    @State private var dragOver = false
    @State private var searchText = ""
    @State private var showAdvancedLibrary = false // Toggle tra vista semplice e avanzata
    
    // Determina se mostrare library o emulator
    private var showingLibrary: Bool {
        emulatorState.currentROM == nil || !emulatorState.isRunning
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar sempre visibile
            if showingLibrary {
                libraryToolbar
            } else {
                emulatorToolbar
            }
            
            Divider()
            
            // Contenuto principale: Switch tra vista semplice/avanzata/emulator
            Group {
                if showingLibrary {
                    if showAdvancedLibrary {
                        // Vista avanzata con sidebar e dettagli
                        advancedLibraryView
                            .transition(.move(edge: .trailing))
                    } else {
                        // Vista semplice con griglia
                        simpleLibraryView
                            .transition(.move(edge: .leading))
                    }
                } else {
                    // Vista emulatore
                    emulatorContent
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showAdvancedLibrary)
            .animation(.easeInOut(duration: 0.3), value: showingLibrary)
            
            // Log console (toggleable)
            if logManager.isVisible {
                LogConsoleView()
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
            handleDrop(providers: providers)
        }
    }
    
    // MARK: - Library Toolbar
    
    var libraryToolbar: some View {
        HStack {
            // Back button se siamo in vista avanzata
            if showAdvancedLibrary {
                Button {
                    withAnimation {
                        showAdvancedLibrary = false
                    }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
            }
            
            Text(showAdvancedLibrary ? "Library" : "Library")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search ROMs...", text: $searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 200)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            
            // Toggle vista semplice/avanzata
            Button {
                withAnimation {
                    showAdvancedLibrary.toggle()
                }
            } label: {
                Image(systemName: showAdvancedLibrary ? "square.grid.2x2" : "sidebar.left")
            }
            .help(showAdvancedLibrary ? "Simple View" : "Advanced Library")
            .keyboardShortcut("l", modifiers: .command)
            
            // Add ROM button
            Button {
                openROMFilePicker()
            } label: {
                Label("Add ROM", systemImage: "plus")
            }
            
            // Rescan button
            Button {
                Task {
                    await romLibrary.scanForROMs()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(romLibrary.isScanning)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Emulator Toolbar
    
    var emulatorToolbar: some View {
        HStack {
            Button {
                emulatorState.stopEmulation()
            } label: {
                Label("Back to Library", systemImage: "chevron.left")
            }
            
            Spacer()
            
            if let rom = emulatorState.currentROM {
                Text(rom.title)
                    .font(.headline)
            }
            
            Spacer()
            
            // Emulator controls will go here
            Text("") // Placeholder for symmetry
                .frame(width: 100)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Library Views
    
    // Vista semplice: Griglia base
    var simpleLibraryView: some View {
        Group {
            if romLibrary.roms.isEmpty {
                emptyLibraryView
            } else {
                romGridView
            }
        }
    }
    
    // Vista avanzata: Sidebar + dettagli
    var advancedLibraryView: some View {
        ROMLibraryView()
            .environmentObject(romLibrary)
            .environmentObject(settings)
            .environmentObject(emulatorState)
    }
    
    var emptyLibraryView: some View {
        VStack(spacing: 24) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 72))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No ROMs Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Add GBA ROM files to get started")
                    .foregroundColor(.secondary)
            }
            
            Button("Add ROM") {
                openROMFilePicker()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var romGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredROMs) { rom in
                    ROMCardView(rom: rom)
                        .onTapGesture {
                            playROM(rom)
                        }
                }
            }
            .padding()
        }
    }
    
    private var filteredROMs: [GBARom] {
        if searchText.isEmpty {
            return romLibrary.roms
        } else {
            return romLibrary.roms.filter { rom in
                rom.title.localizedCaseInsensitiveContains(searchText) ||
                rom.gameCode.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Emulator Content
    
    var emulatorContent: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                // Emulator screen
                EmulatorScreenView()
                    .aspectRatio(240.0/160.0, contentMode: .fit)
                    .scaleEffect(settings.displayScale)
                    .clipped()
                
                // Drag overlay
                if dragOver {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .background(Color.accentColor.opacity(0.1))
                        .overlay(
                            VStack(spacing: 16) {
                                Image(systemName: "arrow.down.doc.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.accentColor)
                                Text("Drop ROM file to play")
                                    .font(.headline)
                                    .foregroundColor(.accentColor)
                            }
                        )
                        .padding(20)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func playROM(_ rom: GBARom) {
        Task { @MainActor in
            do {
                await LogManager.shared.log("▶️ Starting emulation for: \(rom.title)", category: "System", level: .info)
                try await emulatorState.loadROM(rom)
                emulatorState.startEmulation()
            } catch {
                await LogManager.shared.log("❌ Failed to load ROM: \(error.localizedDescription)", category: "ROM", level: .error)
            }
        }
    }
    
    private func openROMFilePicker() {
        Task { @MainActor in
            await LogManager.shared.log("🔍 Opening ROM file picker...", category: "System", level: .info)
            
            let panel = NSOpenPanel()
            panel.title = "Select GBA ROM Files"
            panel.message = "Choose one or more GBA ROM files to add to your library"
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowedContentTypes = [
                .init(filenameExtension: "gba")!,
                .init(filenameExtension: "bin")!,
                .init(filenameExtension: "rom")!
            ]
            
            let response = panel.runModal()
            
            if response == .OK {
                await LogManager.shared.log("✅ User selected \(panel.urls.count) file(s)", category: "System", level: .success)
                
                for url in panel.urls {
                    do {
                        try await romLibrary.addROM(from: url)
                    } catch {
                        await LogManager.shared.log("❌ Failed to add ROM: \(error.localizedDescription)", category: "ROM", level: .error)
                    }
                }
            } else {
                await LogManager.shared.log("ℹ️ User cancelled file selection", category: "System", level: .info)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        _ = provider.loadObject(ofClass: URL.self) { url, error in
            if let url = url {
                Task { @MainActor in
                    self.loadROM(from: url)
                }
            }
        }
        return true
    }
    
    private func loadROM(from url: URL) {
        Task { @MainActor in
            do {
                await LogManager.shared.log("🎮 Loading ROM from drag & drop: \(url.lastPathComponent)", category: "ROM", level: .info)
                
                let filename = url.lastPathComponent
                
                // Check if ROM already exists in library
                if let existingROM = romLibrary.roms.first(where: { $0.url.lastPathComponent == filename }) {
                    await LogManager.shared.log("ℹ️ ROM already in library, starting playback", category: "ROM", level: .info)
                    playROM(existingROM)
                    return
                }
                
                // Add new ROM to library
                try await romLibrary.addROM(from: url)
                
                // Play the newly added ROM
                if let rom = romLibrary.roms.last {
                    playROM(rom)
                }
            } catch {
                await LogManager.shared.log("❌ Failed to load ROM: \(error.localizedDescription)", category: "ROM", level: .error)
            }
        }
    }
}

#Preview {
    MainEmulatorView()
        .environmentObject(EmulatorState())
        .environmentObject(ROMLibrary())
        .environmentObject(EmulatorSettings())
}
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
    @State private var showSidebar = false // Toggle sidebar nella vista unificata
    
    var body: some View {
        VStack(spacing: 0) {
            if emulatorState.currentROM != nil {
                // Modalità emulatore
                emulatorToolbar
                Divider()
                emulatorView
            } else {
                // Modalità libreria unificata
                libraryToolbar
                Divider()
                unifiedLibraryView
            }
            
            // Console di debug
            if logManager.isVisible {
                LogConsoleView()
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSidebar)
        .animation(.easeInOut(duration: 0.25), value: emulatorState.currentROM != nil)
        .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
            handleDrop(providers: providers)
        }
    }
    
    // MARK: - Unified Library View
    
    private var unifiedLibraryView: some View {
        HStack(spacing: 0) {
            // Sidebar compatta (appare/scompare)
            if showSidebar {
                compactSidebar
                    .frame(width: 200)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            
            // Griglia ROM (sempre presente)
            libraryGridContent
        }
    }
    
    // Sidebar compatta stile Apple
    private var compactSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Categories")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            // Lista categorie
            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(ROMCategory.allCases, id: \.self) { category in
                        CategoryRow(
                            category: category,
                            count: romLibrary.roms.filter { $0.category == category }.count,
                            isSelected: romLibrary.selectedCategories.contains(category)
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if romLibrary.selectedCategories.contains(category) {
                                    romLibrary.selectedCategories.remove(category)
                                } else {
                                    romLibrary.selectedCategories.insert(category)
                                }
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // All Games
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            romLibrary.selectedCategories.removeAll()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "gamecontroller")
                                .font(.system(size: 14))
                                .foregroundColor(romLibrary.selectedCategories.isEmpty ? .white : .blue)
                                .frame(width: 20)
                            
                            Text("All Games")
                                .font(.system(size: 13))
                                .foregroundColor(romLibrary.selectedCategories.isEmpty ? .white : .primary)
                            
                            Spacer()
                            
                            Text("\(romLibrary.roms.count)")
                                .font(.caption2)
                                .foregroundColor(romLibrary.selectedCategories.isEmpty ? .white.opacity(0.8) : .secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(romLibrary.selectedCategories.isEmpty ? Color.blue : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.leading, 8)
        .padding(.vertical, 8)
    }
    
    private var libraryGridContent: some View {
        ScrollView {
            if romLibrary.filteredROMs.isEmpty {
                emptyLibraryView
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 180, maximum: 250), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(romLibrary.filteredROMs) { rom in
                        ROMCardView(rom: rom)
                            .onTapGesture {
                                playROM(rom)
                            }
                    }
                }
                .padding()
            }
        }
        .searchable(text: $romLibrary.searchText, prompt: "Search ROMs...")
    }
    
    private var emptyLibraryView: some View {
        VStack(spacing: 20) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No ROMs Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add GBA ROM files to get started")
                .foregroundColor(.secondary)
            
            Button("Add ROM") {
                openROMFilePicker()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Library Toolbar
    
    var libraryToolbar: some View {
        HStack {
            Text("Library")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search ROMs...", text: $romLibrary.searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 200)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            
            // Toggle sidebar (icona cambia: griglia quando sidebar aperta, sidebar quando chiusa)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    showSidebar.toggle()
                }
            } label: {
                Image(systemName: showSidebar ? "square.grid.2x2" : "sidebar.left")
            }
            .help(showSidebar ? "Simple Grid View" : "Show Advanced Library")
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
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Emulator View
    
    private var emulatorView: some View {
        GeometryReader { geometry in
            ZStack {
                // Background nero
                Color.black
                    .ignoresSafeArea()
                
                // Schermo emulatore
                EmulatorScreenView()
                    .aspectRatio(240.0/160.0, contentMode: .fit)
                    .scaleEffect(settings.displayScale)
                    .clipped()
                
                // Overlay drag & drop
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

// MARK: - Subviews per Performance

private struct CategoryRow: View {
    let category: ROMCategory
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .white : .purple)
                    .frame(width: 20)
                
                Text(category.rawValue)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.purple : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainEmulatorView()
        .environmentObject(EmulatorState())
        .environmentObject(ROMLibrary())
        .environmentObject(EmulatorSettings())
}
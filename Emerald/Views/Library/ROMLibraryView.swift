//
//  ROMLibraryView.swift
//  Emerald
//
//  Created by Christian Koscielniak Pinto on 26/10/25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ROMLibraryView: View {
    @EnvironmentObject private var romLibrary: ROMLibrary
    @EnvironmentObject private var settings: EmulatorSettings
    @EnvironmentObject private var emulatorState: EmulatorState
    
    @State private var selectedROMID: GBARom.ID?
    @State private var showingDeleteAlert = false
    @State private var romToDelete: GBARom?
    
    private var selectedROM: GBARom? {
        guard let id = selectedROMID else { return nil }
        return romLibrary.roms.first(where: { $0.id == id })
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with categories
            CategorySidebar()
        } detail: {
            // Main content area
            VStack(spacing: 0) {
                // Toolbar
                LibraryToolbar()
                
                Divider()
                
                // ROM grid/list
                ROMContentView(selectedROMID: $selectedROMID)
                    .contextMenu(forSelectionType: GBARom.ID.self) { selection in
                        if selection.count == 1,
                           let romID = selection.first,
                           let rom = romLibrary.roms.first(where: { $0.id == romID }) {
                            
                            Button("Play") {
                                Task {
                                    try? await emulatorState.loadROM(rom)
                                    emulatorState.startEmulation()
                                }
                            }
                            
                            Divider()
                            
                            Button("Show in Finder") {
                                NSWorkspace.shared.selectFile(rom.url.path, 
                                                            inFileViewerRootedAtPath: "")
                            }
                            
                            Button("Remove from Library", role: .destructive) {
                                romToDelete = rom
                                showingDeleteAlert = true
                            }
                        }
                    } primaryAction: { selection in
                        if let romID = selection.first,
                           let rom = romLibrary.roms.first(where: { $0.id == romID }) {
                            Task {
                                try? await emulatorState.loadROM(rom)
                                emulatorState.startEmulation()
                            }
                        }
                    }
            }
        }
        .searchable(text: $romLibrary.searchText, prompt: "Search ROMs...")
        .alert("Remove ROM", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let rom = romToDelete {
                    try? romLibrary.removeROM(rom)
                }
            }
        } message: {
            if let rom = romToDelete {
                Text("Are you sure you want to remove \"\(rom.title)\" from your library? This will also delete any save data.")
            }
        }
        .task {
            await romLibrary.scanForROMs()
        }
    }
}

struct CategorySidebar: View {
    @EnvironmentObject private var romLibrary: ROMLibrary
    
    var body: some View {
        List(selection: $romLibrary.selectedCategories) {
            Section("Categories") {
                ForEach(ROMCategory.allCases, id: \.self) { category in
                    let count = romLibrary.roms.filter { $0.category == category }.count
                    
                    HStack {
                        Image(systemName: category.systemImage)
                            .foregroundColor(.accentColor)
                        
                        Text(category.rawValue)
                        
                        Spacer()
                        
                        if count > 0 {
                            Text("\(count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.2), in: Capsule())
                        }
                    }
                    .tag(category)
                }
            }
            
            Section("Library") {
                HStack {
                    Image(systemName: "gamecontroller")
                        .foregroundColor(.blue)
                    
                    Text("All Games")
                    
                    Spacer()
                    
                    Text("\(romLibrary.roms.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.2), in: Capsule())
                }
                .onTapGesture {
                    romLibrary.selectedCategories.removeAll()
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }
}

struct LibraryToolbar: View {
    @EnvironmentObject private var romLibrary: ROMLibrary
    
    var body: some View {
        HStack {
            // View style toggle
            Picker("View Style", selection: $romLibrary.viewStyle) {
                ForEach(ViewStyle.allCases, id: \.self) { style in
                    Label(style.rawValue, systemImage: style.systemImage)
                        .tag(style)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            
            Spacer()
            
            // Sort options
            Menu {
                Picker("Sort By", selection: $romLibrary.sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            .menuStyle(.borderlessButton)
            
            Divider()
                .frame(height: 20)
            
            // Add ROM button - Using NSOpenPanel for proper sandbox permissions
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
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .disabled(romLibrary.isScanning)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
                        print("Failed to add ROM from \(url.path): \(error)")
                    }
                }
            } else {
                await LogManager.shared.log("ℹ️ User cancelled file selection", category: "System", level: .info)
            }
        }
    }
}

struct ROMContentView: View {
    @EnvironmentObject private var romLibrary: ROMLibrary
    @Binding var selectedROMID: GBARom.ID?
    
    var body: some View {
        Group {
            if romLibrary.roms.isEmpty {
                EmptyLibraryView()
            } else if romLibrary.viewStyle == .grid {
                ROMGridView(selectedROMID: $selectedROMID)
            } else {
                ROMListView(selectedROMID: $selectedROMID)
            }
        }
    }
}

struct ROMGridView: View {
    @EnvironmentObject private var romLibrary: ROMLibrary
    @Binding var selectedROMID: GBARom.ID?
    
    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(romLibrary.filteredROMs) { rom in
                    ROMCardView(rom: rom)
                        .onTapGesture {
                            selectedROMID = rom.id
                        }
                }
            }
            .padding()
        }
        .overlay {
            if romLibrary.isScanning {
                ProgressView("Scanning for ROMs...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
    }
}

struct ROMListView: View {
    @EnvironmentObject private var romLibrary: ROMLibrary
    @Binding var selectedROMID: GBARom.ID?
    
    var body: some View {
        Table(romLibrary.filteredROMs, selection: $selectedROMID) {
            TableColumn("Title") { rom in
                HStack {
                    Image(systemName: rom.category.systemImage)
                        .foregroundColor(.secondary)
                    Text(rom.title)
                        .fontWeight(.medium)
                }
            }
            .width(min: 200, ideal: 300)
            
            TableColumn("Publisher", value: \.publisher)
                .width(min: 100, ideal: 150)
            
            TableColumn("Size") { rom in
                Text(ByteCountFormatter.string(fromByteCount: Int64(rom.romSize), 
                                             countStyle: .file))
            }
            .width(min: 80, ideal: 100)
            
            TableColumn("Last Played") { rom in
                if let lastPlayed = rom.lastPlayed {
                    Text(lastPlayed, style: .relative)
                } else {
                    Text("Never")
                        .foregroundColor(.secondary)
                }
            }
            .width(min: 100, ideal: 120)
            
            TableColumn("Playtime") { rom in
                Text(formatPlaytime(rom.totalPlaytime))
            }
            .width(min: 80, ideal: 100)
        }
        .overlay {
            if romLibrary.isScanning {
                ProgressView("Scanning for ROMs...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
    }
    
    private func formatPlaytime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "< 1m"
        }
    }
}

struct ROMCardView: View {
    let rom: GBARom
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Game cover image con placeholder colorato
            ROMImageView(rom: rom)
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(rom.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(rom.publisher)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: rom.category.systemImage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(rom.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(ByteCountFormatter.string(fromByteCount: Int64(rom.romSize), 
                                                 countStyle: .file))
                        .font(.caption2)
                        .foregroundColor(Color.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No ROMs Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Add GBA ROM files to get started")
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                Text("Supported formats: .gba, .bin, .rom")
                    .font(.caption)
                    .foregroundColor(Color.secondary)
                
                HStack(spacing: 16) {
                    Text("• Drag and drop ROM files")
                    Text("• Use the + button")
                    Text("• Set up auto-scan folders")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ROMLibraryView()
        .environmentObject(ROMLibrary())
        .environmentObject(EmulatorSettings())
        .environmentObject(EmulatorState())
}
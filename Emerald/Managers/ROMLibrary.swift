//
//  ROMLibrary.swift
//  Emerald
//
//  Created by Christian Koscielniak Pinto on 26/10/25.
//

import Foundation
import SwiftUI
import OSLog
import CryptoKit
import Combine
import UniformTypeIdentifiers

/// Manages the ROM library and metadata
@MainActor
final class ROMLibrary: ObservableObject {
    private let logger = Logger(subsystem: "com.emerald.gba", category: "ROMLibrary")
    
    // MARK: - Published Properties
    @Published var roms: [GBARom] = []
    @Published var isScanning = false
    @Published var searchText = ""
    @Published var sortOrder: SortOrder = .title
    @Published var viewStyle: ViewStyle = .grid
    @Published var selectedCategories: Set<ROMCategory> = []
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private var folderMonitor: DispatchSourceFileSystemObject?
    private let romDirectoryURL: URL
    private let metadataURL: URL
    
    // MARK: - Initialization
    
    init() {
        // Setup ROM directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let emeraldDir = appSupport.appendingPathComponent("Emerald")
        romDirectoryURL = emeraldDir.appendingPathComponent("ROMs")
        metadataURL = emeraldDir.appendingPathComponent("metadata.json")
        
        // Create directories if needed
        try? fileManager.createDirectory(at: romDirectoryURL, withIntermediateDirectories: true)
        
        // Load existing metadata
        loadMetadata()
        
        // Start monitoring ROM directory
        startDirectoryMonitoring()
        
        // Initial scan
        Task {
            await scanForROMs()
        }
    }
    
    deinit {
        folderMonitor?.cancel()
    }
    
    // MARK: - Public Interface
    
    var filteredROMs: [GBARom] {
        var filtered = roms
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { rom in
                rom.title.localizedCaseInsensitiveContains(searchText) ||
                rom.gameCode.localizedCaseInsensitiveContains(searchText) ||
                rom.publisher.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply category filter
        if !selectedCategories.isEmpty {
            filtered = filtered.filter { rom in
                selectedCategories.contains(rom.category)
            }
        }
        
        // Apply sorting
        switch sortOrder {
        case .title:
            filtered.sort { $0.title < $1.title }
        case .dateAdded:
            filtered.sort { $0.dateAdded > $1.dateAdded }
        case .lastPlayed:
            filtered.sort { ($0.lastPlayed ?? Date.distantPast) > ($1.lastPlayed ?? Date.distantPast) }
        case .playtime:
            filtered.sort { $0.totalPlaytime > $1.totalPlaytime }
        case .publisher:
            filtered.sort { $0.publisher < $1.publisher }
        }
        
        return filtered
    }
    
    func addROM(from url: URL) async throws {
        await LogManager.shared.log("🎮 Adding ROM from: \(url.path)", category: "ROM", level: .info)
        logger.info("Adding ROM from: \(url.path)")
        
        // Start accessing security-scoped resource
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        await LogManager.shared.log("✅ Security-scoped access granted: \(accessing)", category: "ROM", level: accessing ? .success : .warning)
        
        // Copy ROM to library directory
        let filename = url.lastPathComponent
        let destinationURL = romDirectoryURL.appendingPathComponent(filename)
        
        if fileManager.fileExists(atPath: destinationURL.path) {
            await LogManager.shared.log("⚠️ ROM already exists", category: "ROM", level: .warning)
            throw ROMLibraryError.romAlreadyExists
        }
        
        do {
            await LogManager.shared.log("📋 Copying ROM to library...", category: "ROM", level: .info)
            try fileManager.copyItem(at: url, to: destinationURL)
            await LogManager.shared.log("✅ ROM copied successfully", category: "ROM", level: .success)
        } catch {
            await LogManager.shared.log("❌ Failed to copy ROM: \(error.localizedDescription)", category: "ROM", level: .error)
            throw error
        }
        
        // Parse ROM metadata
        await LogManager.shared.log("📦 Parsing ROM metadata...", category: "ROM", level: .info)
        let rom = try parseROMMetadata(at: destinationURL)
        roms.append(rom)
        
        // Save security-scoped bookmark for future access
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: "bookmark_\(rom.id)")
            await LogManager.shared.log("🔖 Security bookmark saved", category: "ROM", level: .success)
        } catch {
            await LogManager.shared.log("⚠️ Failed to save bookmark: \(error.localizedDescription)", category: "ROM", level: .warning)
        }
        
        // Save metadata
        saveMetadata()
        
        await LogManager.shared.log("🎉 ROM added successfully: \(rom.title)", category: "ROM", level: .success)
        logger.info("Successfully added ROM: \(rom.title)")
    }
    
    func removeROM(_ rom: GBARom) throws {
        logger.info("Removing ROM: \(rom.title)")
        
        // Remove ROM file
        try fileManager.removeItem(at: rom.url)
        
        // Remove save file if exists
        if fileManager.fileExists(atPath: rom.saveURL.path) {
            try fileManager.removeItem(at: rom.saveURL)
        }
        
        // Remove from array
        roms.removeAll { $0.id == rom.id }
        
        // Save metadata
        saveMetadata()
    }
    
    func updateROMPlaytime(_ rom: GBARom, additionalTime: TimeInterval) {
        guard let index = roms.firstIndex(where: { $0.id == rom.id }) else { return }
        
        roms[index].totalPlaytime += additionalTime
        roms[index].lastPlayed = Date()
        
        saveMetadata()
    }
    
    func scanForROMs() async {
        await MainActor.run {
            isScanning = true
        }
        
        logger.info("Scanning for ROMs in: \(self.romDirectoryURL.path)")
        
        do {
            let urls = try fileManager.contentsOfDirectory(
                at: self.romDirectoryURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            var newROMs: [GBARom] = []
            
            for url in urls {
                let pathExtension = url.pathExtension.lowercased()
                guard ["gba", "bin", "rom"].contains(pathExtension) else { continue }
                
                // Skip if already in library
                if roms.contains(where: { $0.url == url }) {
                    continue
                }
                
                do {
                    let rom = try parseROMMetadata(at: url)
                    newROMs.append(rom)
                } catch {
                    logger.error("Failed to parse ROM at \(url.path): \(error)")
                }
            }
            
            await MainActor.run {
                roms.append(contentsOf: newROMs)
                isScanning = false
            }
            
            if !newROMs.isEmpty {
                saveMetadata()
                logger.info("Found \(newROMs.count) new ROMs")
            }
            
        } catch {
            logger.error("Failed to scan ROM directory: \(error)")
            await MainActor.run {
                isScanning = false
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func parseROMMetadata(at url: URL) throws -> GBARom {
        let data = try Data(contentsOf: url)
        let header = try ROMHeader(data: data)
        return GBARom(url: url, header: header)
    }
    

    
    private func loadMetadata() {
        guard fileManager.fileExists(atPath: metadataURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: metadataURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.roms = try decoder.decode([GBARom].self, from: data)
            logger.info("Loaded \(self.roms.count) ROMs from metadata")
        } catch {
            logger.error("Failed to load metadata: \(error)")
        }
    }
    
    private func saveMetadata() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(self.roms)
            try data.write(to: metadataURL)
            logger.debug("Saved metadata for \(self.roms.count) ROMs")
        } catch {
            logger.error("Failed to save metadata: \(error)")
        }
    }
    
    private func startDirectoryMonitoring() {
        let fd = open(romDirectoryURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        
        folderMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: DispatchQueue.global(qos: .utility)
        )
        
        folderMonitor?.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.logger.info("ROM directory changed, rescanning...")
                await self?.scanForROMs()
            }
        }
        
        folderMonitor?.setCancelHandler {
            close(fd)
        }
        
        folderMonitor?.resume()
    }
}
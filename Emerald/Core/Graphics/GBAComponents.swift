//
//  GBAComponents.swift
//  Emerald
//
//  Created by Christian Koscielniak Pinto on 26/10/25.
//

import Foundation
import OSLog
import MetalKit

// MARK: - GBA Cartridge

final class GBACartridge {
    private let logger = Logger(subsystem: "com.emerald.gba", category: "Cartridge")
    
    private let romData: Data
    private let saveURL: URL
    private var saveRAM: Data = Data()
    
    init(data: Data, saveURL: URL) throws {
        guard data.count >= 0xC0 else {
            throw CartridgeError.invalidROM
        }
        
        self.romData = data
        self.saveURL = saveURL
        
        // Load existing save data if available
        if FileManager.default.fileExists(atPath: saveURL.path) {
            do {
                saveRAM = try Data(contentsOf: saveURL)
            } catch {
                logger.warning("Failed to load save data: \(error)")
            }
        }
        
        logger.info("Cartridge loaded: \(data.count) bytes")
    }
    
    func read8(address: UInt32) -> UInt8 {
        let offset = Int(address & 0x1FFFFFF)
        
        if offset < romData.count {
            return romData[offset]
        }
        
        // Handle save RAM access
        if address >= 0x0E000000 && address < 0x0E010000 {
            let saveOffset = Int(address - 0x0E000000)
            if saveOffset < saveRAM.count {
                return saveRAM[saveOffset]
            }
        }
        
        return 0xFF
    }
    
    func write8(address: UInt32, value: UInt8) {
        // Handle save RAM writes
        if address >= 0x0E000000 && address < 0x0E010000 {
            let saveOffset = Int(address - 0x0E000000)
            
            // Ensure save RAM is large enough
            if saveOffset >= saveRAM.count {
                saveRAM.count = saveOffset + 1
            }
            
            saveRAM[saveOffset] = value
        }
    }
    
    func saveBatteryBackup() {
        guard !saveRAM.isEmpty else { return }
        
        do {
            try saveRAM.write(to: self.saveURL)
            logger.info("Save data written to \(self.saveURL.path)")
        } catch {
            logger.error("Failed to write save data: \(error)")
        }
    }
}

enum CartridgeError: LocalizedError {
    case invalidROM
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidROM: return "Invalid ROM file"
        case .saveFailed: return "Failed to save battery backup"
        }
    }
}

// MARK: - Memory State for Save States

struct MemoryState: Codable {
    let iwram: Data
    let ewram: Data
    let vram: Data
    let oam: Data
    let palette: Data
    let ioRegisters: Data
}

// MARK: - Picture Processing Unit

final class GBAPictureProcessingUnit {
    private let logger = Logger(subsystem: "com.emerald.gba", category: "PPU")
    
    private weak var memory: GBAMemoryManager?
    private weak var renderer: MetalRenderer?
    private var frameBuffer = Data(count: 240 * 160 * 4) // RGBA
    
    weak var interruptController: GBAInterruptController?
    
    init(memory: GBAMemoryManager, renderer: MetalRenderer?) {
        self.memory = memory
        self.renderer = renderer
        logger.info("PPU initialized")
    }
    
    func reset() {
        frameBuffer = Data(count: 240 * 160 * 4) // Reset to zeros
        logger.info("PPU reset")
    }
    
    func update(cycles: Int) {
        // PPU update logic would go here
        // This is a simplified version
    }
    
    func renderFrame() async {
        // Simplified rendering - just fill with a test pattern
        frameBuffer.withUnsafeMutableBytes { bytes in
            let pixels = bytes.bindMemory(to: UInt32.self)
            for y in 0..<160 {
                for x in 0..<240 {
                    let index = y * 240 + x
                    // Test pattern
                    let r = UInt32((x * 255) / 240)
                    let g = UInt32((y * 255) / 160)
                    let b = UInt32(128)
                    pixels[index] = (0xFF << 24) | (b << 16) | (g << 8) | r
                }
            }
        }
        
        // Update Metal renderer
        await MainActor.run {
            frameBuffer.withUnsafeBytes { ptr in
                renderer?.updateTexture(with: ptr.baseAddress!, width: 240, height: 160)
            }
        }
    }
    
    func saveState() -> PPUState? {
        return PPUState(frameBuffer: frameBuffer)
    }
    
    func loadState(_ state: PPUState) {
        frameBuffer = state.frameBuffer
    }
}

struct PPUState: Codable {
    let frameBuffer: Data
}

// MARK: - Audio Processing Unit

final class GBAAudioProcessingUnit {
    private let logger = Logger(subsystem: "com.emerald.gba", category: "APU")
    
    private weak var audioEngine: GBAAudioEngine?
    
    init(audioEngine: GBAAudioEngine?) {
        self.audioEngine = audioEngine
        logger.info("APU initialized")
    }
    
    func reset() {
        logger.info("APU reset")
    }
    
    func update(cycles: Int) {
        // Audio processing logic would go here
    }
    
    func saveState() -> APUState? {
        return APUState()
    }
    
    func loadState(_ state: APUState) {
        // Restore audio state
    }
}

struct APUState: Codable {
    // Audio state would be stored here
}

// MARK: - Audio Engine

// MARK: - Timer System

final class GBATimerSystem {
    private let logger = Logger(subsystem: "com.emerald.gba", category: "Timers")
    
    weak var interruptController: GBAInterruptController?
    
    init() {
        logger.info("Timer system initialized")
    }
    
    func reset() {
        logger.info("Timer system reset")
    }
    
    func update(cycles: Int) {
        // Timer update logic
    }
}

// MARK: - DMA Controller

final class GBADMAController {
    private let logger = Logger(subsystem: "com.emerald.gba", category: "DMA")
    
    private weak var memory: GBAMemoryManager?
    weak var interruptController: GBAInterruptController?
    
    init(memory: GBAMemoryManager) {
        self.memory = memory
        logger.info("DMA controller initialized")
    }
    
    func reset() {
        logger.info("DMA controller reset")
    }
    
    func update(cycles: Int) {
        // DMA update logic
    }
    
    func handleDMAWrite(channel: Int, offset: UInt32, value: UInt8) {
        logger.debug("DMA\(channel) register write: offset=\(offset) value=\(value)")
    }
}

// MARK: - Interrupt Controller

final class GBAInterruptController {
    private let logger = Logger(subsystem: "com.emerald.gba", category: "Interrupts")
    
    private var pendingInterrupts: Set<GBAInterrupt> = []
    
    init() {
        logger.info("Interrupt controller initialized")
    }
    
    func reset() {
        pendingInterrupts.removeAll()
        logger.info("Interrupt controller reset")
    }
    
    func requestInterrupt(_ interrupt: GBAInterrupt) {
        pendingInterrupts.insert(interrupt)
        logger.debug("Interrupt requested: \(interrupt)")
    }
    
    func getPendingInterrupt() -> GBAInterrupt? {
        return pendingInterrupts.first
    }
    
    func clearInterrupt(_ interrupt: GBAInterrupt) {
        pendingInterrupts.remove(interrupt)
    }
}

// MARK: - Save State System

final class SaveState {
    let slot: Int
    let timestamp: Date
    let romChecksum: String
    let cpuState: CPUState
    let memoryState: MemoryState
    let ppuState: PPUState?
    let apuState: APUState?
    
    init(slot: Int, timestamp: Date, romChecksum: String, cpuState: CPUState, 
         memoryState: MemoryState, ppuState: PPUState?, apuState: APUState?) {
        self.slot = slot
        self.timestamp = timestamp
        self.romChecksum = romChecksum
        self.cpuState = cpuState
        self.memoryState = memoryState
        self.ppuState = ppuState
        self.apuState = apuState
    }
    
    func save() async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(self)
        let url = SaveState.getSaveStateURL(slot: slot)
        try data.write(to: url)
    }
    
    static func load(from slot: Int) async throws -> SaveState {
        let url = SaveState.getSaveStateURL(slot: slot)
        let data = try Data(contentsOf: url)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(SaveState.self, from: data)
    }
    
    private static func getSaveStateURL(slot: Int) -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let emeraldDir = appSupport.appendingPathComponent("Emerald")
        let saveStatesDir = emeraldDir.appendingPathComponent("SaveStates")
        
        try? FileManager.default.createDirectory(at: saveStatesDir, withIntermediateDirectories: true)
        
        return saveStatesDir.appendingPathComponent("slot\(slot).emeraldsave")
    }
}

extension SaveState: Codable {}
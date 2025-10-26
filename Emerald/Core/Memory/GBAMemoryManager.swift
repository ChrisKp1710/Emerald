//
//  GBAMemoryManager.swift
//  Emerald
//
//  Created by Christian Koscielniak Pinto on 26/10/25.
//

import Foundation
import OSLog

/// Game Boy Advance Memory Management Unit
final class GBAMemoryManager {
    private let logger = Logger(subsystem: "com.emerald.gba", category: "Memory")
    
    // MARK: - Memory Regions
    
    /// Internal Work RAM (32KB) - Fast
    private var iwram = Data(count: 32 * 1024)
    
    /// External Work RAM (256KB) - Slower
    private var ewram = Data(count: 256 * 1024)
    
    /// Video RAM (96KB)
    private var vram = Data(count: 96 * 1024)
    
    /// Object Attribute Memory (1KB)
    private var oam = Data(count: 1024)
    
    /// Palette RAM (1KB)
    private var palette = Data(count: 1024)
    
    /// I/O Registers
    private var ioRegisters = Data(count: 1024)
    
    /// Game Pak reference
    private weak var cartridge: GBACartridge?
    
    /// DMA Controller reference
    weak var dmaController: GBADMAController?
    
    // MARK: - Initialization
    
    init(cartridge: GBACartridge) {
        self.cartridge = cartridge
        reset()
        logger.info("Memory manager initialized")
    }
    
    func reset() {
        iwram = Data(count: 32 * 1024)
        ewram = Data(count: 256 * 1024)
        vram = Data(count: 96 * 1024)
        oam = Data(count: 1024)
        palette = Data(count: 1024)
        ioRegisters = Data(count: 1024)
        
        logger.info("Memory reset complete")
    }
    
    // MARK: - Memory Access Interface
    
    func read8(address: UInt32) -> UInt8 {
        let region = address >> 24
        let offset = address & 0xFFFFFF
        
        switch region {
        case 0x00: // BIOS
            return readBIOS(offset: offset)
        case 0x02: // EWRAM
            return ewram.withUnsafeBytes { $0.load(fromByteOffset: Int(offset % 0x40000), as: UInt8.self) }
        case 0x03: // IWRAM
            return iwram.withUnsafeBytes { $0.load(fromByteOffset: Int(offset % 0x8000), as: UInt8.self) }
        case 0x04: // I/O Registers
            return readIORegister8(offset: offset)
        case 0x05: // Palette RAM
            return palette.withUnsafeBytes { $0.load(fromByteOffset: Int(offset % 0x400), as: UInt8.self) }
        case 0x06: // VRAM
            return vram.withUnsafeBytes { $0.load(fromByteOffset: Int(offset % 0x18000), as: UInt8.self) }
        case 0x07: // OAM
            return oam.withUnsafeBytes { $0.load(fromByteOffset: Int(offset % 0x400), as: UInt8.self) }
        case 0x08...0x0D: // Game Pak
            return cartridge?.read8(address: address) ?? 0xFF
        default:
            logger.warning("Invalid read8 from address: \(String(format: "%08X", address))")
            return 0xFF
        }
    }
    
    func read16(address: UInt32) -> UInt16 {
        let alignedAddress = address & ~1
        return UInt16(read8(address: alignedAddress)) |
               (UInt16(read8(address: alignedAddress + 1)) << 8)
    }
    
    func read32(address: UInt32) -> UInt32 {
        let alignedAddress = address & ~3
        return UInt32(read16(address: alignedAddress)) |
               (UInt32(read16(address: alignedAddress + 2)) << 16)
    }
    
    func write8(address: UInt32, value: UInt8) {
        let region = address >> 24
        let offset = address & 0xFFFFFF
        
        switch region {
        case 0x02: // EWRAM
            ewram.withUnsafeMutableBytes { 
                $0.storeBytes(of: value, toByteOffset: Int(offset % 0x40000), as: UInt8.self)
            }
        case 0x03: // IWRAM
            iwram.withUnsafeMutableBytes { 
                $0.storeBytes(of: value, toByteOffset: Int(offset % 0x8000), as: UInt8.self)
            }
        case 0x04: // I/O Registers
            writeIORegister8(offset: offset, value: value)
        case 0x05: // Palette RAM
            palette.withUnsafeMutableBytes { 
                $0.storeBytes(of: value, toByteOffset: Int(offset % 0x400), as: UInt8.self)
            }
        case 0x06: // VRAM
            vram.withUnsafeMutableBytes { 
                $0.storeBytes(of: value, toByteOffset: Int(offset % 0x18000), as: UInt8.self)
            }
        case 0x07: // OAM
            oam.withUnsafeMutableBytes { 
                $0.storeBytes(of: value, toByteOffset: Int(offset % 0x400), as: UInt8.self)
            }
        case 0x08...0x0D: // Game Pak
            cartridge?.write8(address: address, value: value)
        default:
            logger.warning("Invalid write8 to address: \(String(format: "%08X", address))")
        }
    }
    
    func write16(address: UInt32, value: UInt16) {
        let alignedAddress = address & ~1
        write8(address: alignedAddress, value: UInt8(value & 0xFF))
        write8(address: alignedAddress + 1, value: UInt8((value >> 8) & 0xFF))
    }
    
    func write32(address: UInt32, value: UInt32) {
        let alignedAddress = address & ~3
        write16(address: alignedAddress, value: UInt16(value & 0xFFFF))
        write16(address: alignedAddress + 2, value: UInt16((value >> 16) & 0xFFFF))
    }
    
    // MARK: - BIOS Access
    
    private func readBIOS(offset: UInt32) -> UInt8 {
        // Simplified BIOS implementation
        // In a real implementation, this would load from a BIOS file
        return 0xFF
    }
    
    // MARK: - I/O Register Access
    
    private func readIORegister8(offset: UInt32) -> UInt8 {
        guard offset < ioRegisters.count else { return 0xFF }
        
        return ioRegisters.withUnsafeBytes { 
            $0.load(fromByteOffset: Int(offset), as: UInt8.self)
        }
    }
    
    private func writeIORegister8(offset: UInt32, value: UInt8) {
        guard offset < ioRegisters.count else { return }
        
        ioRegisters.withUnsafeMutableBytes { 
            $0.storeBytes(of: value, toByteOffset: Int(offset), as: UInt8.self)
        }
        
        // Handle special I/O register writes
        handleIOWrite(offset: offset, value: value)
    }
    
    private func handleIOWrite(offset: UInt32, value: UInt8) {
        // Handle writes to specific I/O registers
        switch offset {
        case 0x200...0x20F: // DMA0 registers
            dmaController?.handleDMAWrite(channel: 0, offset: offset - 0x200, value: value)
        case 0x210...0x21F: // DMA1 registers
            dmaController?.handleDMAWrite(channel: 1, offset: offset - 0x210, value: value)
        case 0x220...0x22F: // DMA2 registers
            dmaController?.handleDMAWrite(channel: 2, offset: offset - 0x220, value: value)
        case 0x230...0x23F: // DMA3 registers
            dmaController?.handleDMAWrite(channel: 3, offset: offset - 0x230, value: value)
        default:
            break
        }
    }
    
    // MARK: - Direct Memory Access for PPU
    
    func getVRAMPointer() -> UnsafePointer<UInt8> {
        return vram.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    }
    
    func getPalettePointer() -> UnsafePointer<UInt8> {
        return palette.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    }
    
    func getOAMPointer() -> UnsafePointer<UInt8> {
        return oam.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    }
    
    // MARK: - Save States
    
    func saveState() -> MemoryState {
        return MemoryState(
            iwram: iwram,
            ewram: ewram,
            vram: vram,
            oam: oam,
            palette: palette,
            ioRegisters: ioRegisters
        )
    }
    
    func loadState(_ state: MemoryState) {
        iwram = state.iwram
        ewram = state.ewram
        vram = state.vram
        oam = state.oam
        palette = state.palette
        ioRegisters = state.ioRegisters
    }
}
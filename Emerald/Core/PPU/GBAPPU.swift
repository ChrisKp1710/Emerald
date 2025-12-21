//
//  GBAPPU.swift
//  Emerald
//
//  GBA Picture Processing Unit - Core
//  Main PPU class with registers and state management
//

import Foundation
import os.log

// MARK: - Background Layer Structure

/// Represents a single GBA background layer with all its properties
struct BackgroundLayer {
    var enabled: Bool = false
    var priority: UInt8 = 0
    var charBase: UInt32 = 0           // Character (tile) data base address
    var screenBase: UInt32 = 0         // Screen (map) data base address
    var size: UInt8 = 0                // 0=256x256, 1=512x256, 2=256x512, 3=512x512
    var colorMode: Bool = false        // false=16 colors (4bpp), true=256 colors (8bpp)
    var mosaic: Bool = false           // Mosaic effect enabled
    var wraparound: Bool = true        // Coordinate wraparound

    /// Parse BGCNT register to populate layer properties
    mutating func updateFromBGCNT(_ bgcnt: UInt16) {
        self.priority = UInt8(bgcnt & 0x03)
        self.charBase = UInt32((bgcnt & 0x000C) >> 2) * 0x4000
        self.mosaic = (bgcnt & 0x0040) != 0
        self.colorMode = (bgcnt & 0x0080) != 0
        self.screenBase = UInt32((bgcnt & 0x1F00) >> 8) * 0x800
        self.wraparound = (bgcnt & 0x2000) != 0
        self.size = UInt8((bgcnt >> 14) & 0x03)
    }
}

@MainActor
final class GBAPPU {
    // MARK: - Properties

    internal let logger = Logger(subsystem: "dev.kodechris.Emerald", category: "PPU")
    internal weak var memory: GBAMemoryManager?
    internal weak var interrupts: GBAInterruptController?

    // Display
    internal var framebuffer: [UInt32] // 240x160 RGBA pixels
    internal var currentScanline: Int = 0
    internal var currentCycle: Int = 0

    // Background Layers (for tile modes)
    internal var backgroundLayers: [BackgroundLayer] = Array(repeating: BackgroundLayer(), count: 4)
    
    // LCD Control Register (0x04000000)
    internal var dispcnt: UInt16 = 0x0080  // Display Control
    internal var dispstat: UInt16 = 0      // Display Status
    internal var vcount: UInt16 = 0        // Vertical Counter
    
    // Background Control (0x04000008-0x0400000E)
    internal var bgcnt: [UInt16] = [0, 0, 0, 0]  // BG0-BG3 Control
    
    // Background Scroll (0x04000010-0x0400001E)
    internal var bghofs: [UInt16] = [0, 0, 0, 0] // BG0-BG3 H-Offset
    internal var bgvofs: [UInt16] = [0, 0, 0, 0] // BG0-BG3 V-Offset
    
    // Window Control
    internal var win0h: UInt16 = 0         // Window 0 Horizontal
    internal var win1h: UInt16 = 0         // Window 1 Horizontal
    internal var win0v: UInt16 = 0         // Window 0 Vertical
    internal var win1v: UInt16 = 0         // Window 1 Vertical
    internal var winin: UInt16 = 0         // Inside Window
    internal var winout: UInt16 = 0        // Outside Window
    
    // Blending
    internal var bldcnt: UInt16 = 0        // Blend Control
    internal var bldalpha: UInt16 = 0      // Alpha Blend
    internal var bldy: UInt16 = 0          // Brightness
    
    // Mosaic
    internal var mosaic: UInt16 = 0        // Mosaic Effect
    
    // MARK: - Constants
    
    static let screenWidth = 240
    static let screenHeight = 160
    static let hblankCycles = 68
    static let hblankStart = 960
    static let scanlineCycles = 1232
    static let vblankStart = 160
    static let vblankEnd = 227
    
    // MARK: - Initialization
    
    init() {
        // Initialize framebuffer (240×160, black screen)
        self.framebuffer = Array(repeating: 0xFF000000, count: Self.screenWidth * Self.screenHeight)
        
        // Initialize registers to zero (BIOS skip will set proper values)
        // Reference: mGBA software-video.c reset() initializes to 0x0080,
        // but CPU reset() will overwrite to 0x0000 during BIOS skip
        dispcnt = 0x0000  // Start with NO forced blank (changed from 0x0080)
        dispstat = 0x0000
        vcount = 0x0000
        
        logger.info("🎮 PPU initialized - DISPCNT: 0x0000 (no forced blank)")
    }
    
    func setMemory(_ memory: GBAMemoryManager) {
        self.memory = memory
        logger.debug("PPU memory reference set")
    }
    
    func setInterrupts(_ interrupts: GBAInterruptController) {
        self.interrupts = interrupts
        logger.debug("PPU interrupts reference set")
    }
    
    // MARK: - Main Update
    
    func step(cycles: Int) {
        guard memory != nil else { return }
        
        currentCycle += cycles
        
        // Check if we completed a scanline
        if currentCycle >= Self.scanlineCycles {
            currentCycle -= Self.scanlineCycles
            currentScanline += 1
            
            // Handle VBlank
            if currentScanline == Self.vblankStart {
                enterVBlank()
            } else if currentScanline > Self.vblankEnd {
                currentScanline = 0
                exitVBlank()
            } else if currentScanline < Self.vblankStart {
                // Render scanline
                renderScanline()
            }
            
            // Update VCOUNT register
            vcount = UInt16(currentScanline)
            
            // Check for VCount match
            checkVCountMatch()
        }
        
        // Check for HBlank
        if currentCycle >= Self.hblankStart && (dispstat & 0x0002) == 0 {
            enterHBlank()
        }
    }
    
    // MARK: - Rendering
    
    private func renderScanline() {
        let mode = dispcnt & 0x07
        let forcedBlank = (dispcnt & 0x80) != 0
        
        // Log solo prima scanline per non spammare
        if currentScanline == 0 {
            logger.info("🎨 Rendering Frame - DISPCNT: 0x\(String(format: "%04X", self.dispcnt)) | Mode: \(mode) | ForcedBlank: \(forcedBlank) | Enabled BG: [\(self.backgroundLayers.enumerated().map { $1.enabled ? "\($0)" : "-" }.joined())]")
        }
        
        // Se forced blank, renderizza schermo bianco
        if forcedBlank {
            let offset = currentScanline * Self.screenWidth
            for x in 0..<Self.screenWidth {
                framebuffer[offset + x] = 0xFFFFFFFF  // Bianco
            }
            return
        }
        
        switch mode {
        case 0: renderMode0() // Tile mode
        case 1: renderMode1() // Tile + 1 affine
        case 2: renderMode2() // 2 affine
        case 3: renderMode3() // Bitmap 240×160
        case 4: renderMode4() // Bitmap 240×160 (paletted)
        case 5: renderMode5() // Bitmap 160×128
        default:
            logger.warning("Unsupported video mode: \(mode)")
            clearScanline()
        }
    }
    
    private func clearScanline() {
        let y = currentScanline
        guard y < Self.screenHeight else { return }
        
        let offset = y * Self.screenWidth
        for x in 0..<Self.screenWidth {
            framebuffer[offset + x] = 0xFF000000 // Black
        }
    }
    
    // MARK: - VBlank / HBlank
    
    private func enterVBlank() {
        dispstat |= 0x0001 // Set VBlank flag
        
        // Trigger VBlank interrupt if enabled
        if (dispstat & 0x0008) != 0 {
            interrupts?.requestInterrupt(.vblank) // VBlank interrupt
        }
        
        // logger.debug("Entered VBlank") // Too verbose
    }
    
    private func exitVBlank() {
        dispstat &= ~0x0001 // Clear VBlank flag
        // logger.debug("Exited VBlank") // Too verbose
    }
    
    private func enterHBlank() {
        dispstat |= 0x0002 // Set HBlank flag
        
        // Trigger HBlank interrupt if enabled
        if (dispstat & 0x0010) != 0 {
            interrupts?.requestInterrupt(.hblank) // HBlank interrupt
        }
    }
    
    private func checkVCountMatch() {
        let vcountSetting = (dispstat >> 8) & 0xFF
        if vcount == vcountSetting {
            dispstat |= 0x0004 // Set VCount flag
            
            // Trigger VCount interrupt if enabled
            if (dispstat & 0x0020) != 0 {
                interrupts?.requestInterrupt(.vcounter) // VCount interrupt
            }
        } else {
            dispstat &= ~0x0004 // Clear VCount flag
        }
    }
    
    // MARK: - Register Access
    
    func readRegister16(_ address: UInt32) -> UInt16 {
        switch address {
        case 0x04000000: return dispcnt
        case 0x04000004: return dispstat
        case 0x04000006: return vcount
        case 0x04000008...0x0400000E:
            let index = Int((address - 0x04000008) / 2)
            return bgcnt[index]
        case 0x04000048: return winin
        case 0x0400004A: return winout
        case 0x04000050: return bldcnt
        case 0x04000052: return bldalpha
        case 0x04000054: return bldy
        default:
            return 0
        }
    }
    
    func writeRegister16(_ address: UInt32, value: UInt16) {
        switch address {
        case 0x04000000:
            let oldDispcnt = dispcnt
            dispcnt = value
            // Update background enabled flags
            for i in 0..<4 {
                backgroundLayers[i].enabled = (value & (0x0100 << i)) != 0
            }
            logger.info("✏️ DISPCNT WRITE: 0x\(String(format: "%04X", oldDispcnt)) → 0x\(String(format: "%04X", value)) | Mode: \(value & 0x07) | ForcedBlank: \((value & 0x80) != 0 ? "YES" : "NO") | BG: [\(self.backgroundLayers[0].enabled ? "0" : "-")\(self.backgroundLayers[1].enabled ? "1" : "-")\(self.backgroundLayers[2].enabled ? "2" : "-")\(self.backgroundLayers[3].enabled ? "3" : "-")]")
        case 0x04000004:
            dispstat = (dispstat & 0x0007) | (value & 0xFFF8) // Preserve status bits
        case 0x04000008...0x0400000E:
            let index = Int((address - 0x04000008) / 2)
            bgcnt[index] = value
            // Update background layer configuration
            backgroundLayers[index].updateFromBGCNT(value)
            backgroundLayers[index].enabled = (dispcnt & (0x0100 << index)) != 0
        case 0x04000010...0x0400001E:
            let index = Int((address - 0x04000010) / 4)
            if (address & 2) == 0 {
                bghofs[index] = value & 0x1FF
            } else {
                bgvofs[index] = value & 0x1FF
            }
        case 0x04000040: win0h = value
        case 0x04000042: win1h = value
        case 0x04000044: win0v = value
        case 0x04000046: win1v = value
        case 0x04000048: winin = value
        case 0x0400004A: winout = value
        case 0x0400004C: mosaic = value
        case 0x04000050: bldcnt = value
        case 0x04000052: bldalpha = value
        case 0x04000054: bldy = value & 0x1F
        default:
            break
        }
    }
    
    // MARK: - Public Interface
    
    func getFramebuffer() -> [UInt32] {
        return framebuffer
    }
    
    func reset() {
        framebuffer = Array(repeating: 0xFF000000, count: Self.screenWidth * Self.screenHeight)
        currentScanline = 0
        currentCycle = 0
        dispcnt = 0x0080
        dispstat = 0
        vcount = 0
        bgcnt = [0, 0, 0, 0]
        bghofs = [0, 0, 0, 0]
        bgvofs = [0, 0, 0, 0]
        win0h = 0
        win1h = 0
        win0v = 0
        win1v = 0
        winin = 0
        winout = 0
        bldcnt = 0
        bldalpha = 0
        bldy = 0
        mosaic = 0
        logger.info("PPU reset complete")
    }
}

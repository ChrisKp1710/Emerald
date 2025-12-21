//
//  PPUTileModes.swift
//  Emerald
//
//  PPU Tile Modes (Mode 0, 1, 2)
//  Professional implementation following mGBA architecture
//

import Foundation
import os

extension GBAPPU {

    // MARK: - Mode 0: 4 Tile Backgrounds

    /// Renders Mode 0: 4 regular tile backgrounds with priority-based compositing
    /// Based on mGBA software-mode0.c implementation
    internal func renderMode0() {
        let y = currentScanline
        guard y < Self.screenHeight else { return }
        
        // Log solo prima scanline
        if y == 0 {
            let enabledBGs = self.backgroundLayers.enumerated().filter { $1.enabled }.map { $0.0 }
            logger.info("🖼️ Mode 0 rendering - BG enabled: \(enabledBGs)")
            for i in enabledBGs {
                let bg = self.backgroundLayers[i]
                logger.debug("  BG\(i): Priority=\(bg.priority), CharBase=0x\(String(format: "%X", bg.charBase)), ScreenBase=0x\(String(format: "%X", bg.screenBase)), Size=\(bg.size), Colors=\(bg.colorMode ? 256 : 16)")
            }
        }

        // Priority buffers for compositing (4 = no layer, highest priority)
        var priorityBuffer = [UInt8](repeating: 4, count: Self.screenWidth)
        var colorBuffer = [UInt32](repeating: 0, count: Self.screenWidth)

        // Render backgrounds in priority order (0 = highest, 3 = lowest)
        for priority in UInt8(0)...3 {
            for bgIndex in 0..<4 {
                let bg = backgroundLayers[bgIndex]

                // Only render if enabled and matching priority
                if bg.enabled && bg.priority == priority {
                    renderBackgroundLayer(
                        bgIndex: bgIndex,
                        scanline: y,
                        priority: priority,
                        colorBuffer: &colorBuffer,
                        priorityBuffer: &priorityBuffer
                    )
                }
            }
        }

        // Apply backdrop color where no layer rendered
        let backdropColor = getBackdropColor()
        let offset = y * Self.screenWidth

        for x in 0..<Self.screenWidth {
            framebuffer[offset + x] = colorBuffer[x] != 0 ? colorBuffer[x] : backdropColor
        }
    }

    // MARK: - Background Layer Rendering

    /// Renders a single background layer to the color/priority buffers
    private func renderBackgroundLayer(
        bgIndex: Int,
        scanline: Int,
        priority: UInt8,
        colorBuffer: inout [UInt32],
        priorityBuffer: inout [UInt8]
    ) {
        guard let memory = memory else { return }

        let bg = backgroundLayers[bgIndex]
        let scrollX = Int(bghofs[bgIndex])
        let scrollY = Int(bgvofs[bgIndex])

        // Apply scrolling with wrapping
        let actualY = bg.wraparound ? (scanline + scrollY) & 0x1FF : (scanline + scrollY)

        // Render each pixel of the scanline
        for x in 0..<Self.screenWidth {
            // Skip if already rendered by higher priority layer
            if priority > priorityBuffer[x] {
                continue
            }

            let actualX = bg.wraparound ? (x + scrollX) & 0x1FF : (x + scrollX)

            // Read pixel from background
            if let pixel = readBackgroundPixel(
                bgIndex: bgIndex,
                x: actualX,
                y: actualY,
                layer: bg,
                memory: memory
            ) {
                // Pixel 0 is transparent
                if pixel != 0 {
                    colorBuffer[x] = pixel
                    priorityBuffer[x] = priority
                }
            }
        }
    }

    // MARK: - Pixel Reading

    /// Reads a single pixel from a background layer
    /// Returns nil if out of bounds, 0 if transparent, color otherwise
    private func readBackgroundPixel(
        bgIndex: Int,
        x: Int,
        y: Int,
        layer: BackgroundLayer,
        memory: GBAMemoryManager
    ) -> UInt32? {
        // Calculate tile coordinates
        let tileX = x / 8
        let tileY = y / 8
        let pixelX = x % 8
        let pixelY = y % 8

        // Get map entry address (which tile to use)
        guard let mapAddr = calculateMapAddress(
            tileX: tileX,
            tileY: tileY,
            layer: layer
        ) else {
            return nil  // Out of bounds
        }

        // Read map entry (16-bit)
        let vramBase: UInt32 = 0x06000000
        let mapEntry = memory.read16(address: vramBase + layer.screenBase + mapAddr)

        // Extract tile information from map entry
        let tileIndex = mapEntry & 0x3FF
        let flipH = (mapEntry & 0x0400) != 0
        let flipV = (mapEntry & 0x0800) != 0
        let paletteBank = UInt16((mapEntry >> 12) & 0xF)

        // Apply flipping
        var localPixelX = pixelX
        var localPixelY = pixelY
        if flipH { localPixelX = 7 - pixelX }
        if flipV { localPixelY = 7 - pixelY }

        // Read pixel from tile data
        if layer.colorMode {
            // 256 colors (8bpp) - 64 bytes per tile
            return read256ColorPixel(
                tileIndex: tileIndex,
                pixelX: localPixelX,
                pixelY: localPixelY,
                charBase: layer.charBase,
                memory: memory
            )
        } else {
            // 16 colors (4bpp) - 32 bytes per tile
            return read16ColorPixel(
                tileIndex: tileIndex,
                pixelX: localPixelX,
                pixelY: localPixelY,
                paletteBank: paletteBank,
                charBase: layer.charBase,
                memory: memory
            )
        }
    }

    // MARK: - Tile Data Reading

    /// Reads a pixel from a 16-color (4bpp) tile
    private func read16ColorPixel(
        tileIndex: UInt16,
        pixelX: Int,
        pixelY: Int,
        paletteBank: UInt16,
        charBase: UInt32,
        memory: GBAMemoryManager
    ) -> UInt32? {
        let vramBase: UInt32 = 0x06000000

        // 16 colors: 4 bits per pixel, 32 bytes per tile (8x8)
        let tileAddr = vramBase + charBase + UInt32(tileIndex) * 32
        let rowAddr = tileAddr + UInt32(pixelY) * 4  // 4 bytes per row

        // Read 4 bytes (8 pixels, 4 bits each)
        let rowData = memory.read32(address: rowAddr)

        // Extract 4-bit pixel value
        let shift = pixelX * 4
        let pixelValue = UInt8((rowData >> shift) & 0xF)

        // 0 = transparent
        if pixelValue == 0 {
            return 0
        }

        // Get color from palette (16 colors per bank)
        let paletteIndex = paletteBank * 16 + UInt16(pixelValue)
        return readPaletteColor(index: paletteIndex, memory: memory)
    }

    /// Reads a pixel from a 256-color (8bpp) tile
    private func read256ColorPixel(
        tileIndex: UInt16,
        pixelX: Int,
        pixelY: Int,
        charBase: UInt32,
        memory: GBAMemoryManager
    ) -> UInt32? {
        let vramBase: UInt32 = 0x06000000

        // 256 colors: 8 bits per pixel, 64 bytes per tile (8x8)
        let tileAddr = vramBase + charBase + UInt32(tileIndex) * 64
        let pixelAddr = tileAddr + UInt32(pixelY * 8 + pixelX)

        // Read 8-bit pixel value
        let pixelValue = memory.read8(address: pixelAddr)

        // 0 = transparent
        if pixelValue == 0 {
            return 0
        }

        // Get color from palette (256 colors total)
        return readPaletteColor(index: UInt16(pixelValue), memory: memory)
    }

    // MARK: - Map Address Calculation

    /// Calculates the address offset in the screen map for a given tile coordinate
    /// Handles all 4 size configurations (256x256, 512x256, 256x512, 512x512)
    private func calculateMapAddress(tileX: Int, tileY: Int, layer: BackgroundLayer) -> UInt32? {
        let baseTileX = tileX & 0x1F  // 0-31
        let baseTileY = tileY & 0x1F  // 0-31

        var offset: UInt32 = 0

        switch layer.size {
        case 0:  // 256x256 (32x32 tiles, 1 screen block)
            // Single 32x32 map
            if tileX >= 32 || tileY >= 32 { return nil }  // Out of bounds
            offset = UInt32(baseTileY * 32 + baseTileX) * 2

        case 1:  // 512x256 (64x32 tiles, 2 horizontal screen blocks)
            if tileX >= 64 || tileY >= 32 { return nil }

            if tileX >= 32 {
                offset = 0x800  // Second screen block
            }
            offset += UInt32(baseTileY * 32 + baseTileX) * 2

        case 2:  // 256x512 (32x64 tiles, 2 vertical screen blocks)
            if tileX >= 32 || tileY >= 64 { return nil }

            if tileY >= 32 {
                offset = 0x800  // Second screen block
            }
            offset += UInt32(baseTileY * 32 + baseTileX) * 2

        case 3:  // 512x512 (64x64 tiles, 4 screen blocks)
            if tileX >= 64 || tileY >= 64 { return nil }

            // Quad-screen layout:
            // [0][1]
            // [2][3]
            if tileX >= 32 && tileY < 32 {
                offset = 0x800  // Top-right
            } else if tileX < 32 && tileY >= 32 {
                offset = 0x800  // Bottom-left
            } else if tileX >= 32 && tileY >= 32 {
                offset = 0x1000  // Bottom-right
            }
            offset += UInt32(baseTileY * 32 + baseTileX) * 2

        default:
            return nil
        }

        return offset
    }

    // MARK: - Helper Functions

    /// Reads a color from palette RAM and converts BGR555 to RGBA8888
    private func readPaletteColor(index: UInt16, memory: GBAMemoryManager) -> UInt32 {
        let paletteBase: UInt32 = 0x05000000
        let rgb555 = memory.read16(address: paletteBase + UInt32(index) * 2)

        // Convert BGR555 to RGB888
        let r = UInt32((rgb555 & 0x001F) << 3)
        let g = UInt32(((rgb555 & 0x03E0) >> 5) << 3)
        let b = UInt32(((rgb555 & 0x7C00) >> 10) << 3)

        // Return RGBA (alpha = 0xFF)
        return 0xFF000000 | (b << 16) | (g << 8) | r
    }

    /// Renders the backdrop color to the current scanline
    private func renderBackdrop() {
        let y = currentScanline
        guard y < Self.screenHeight else { return }

        let backdropColor = getBackdropColor()
        let offset = y * Self.screenWidth

        for x in 0..<Self.screenWidth {
            framebuffer[offset + x] = backdropColor
        }
    }

    /// Gets the backdrop color (first palette entry)
    private func getBackdropColor() -> UInt32 {
        guard let memory = memory else { return 0xFF000000 }

        // Backdrop color is first entry in palette RAM
        return readPaletteColor(index: 0, memory: memory)
    }

    // MARK: - Mode 1: 2 Tile + 1 Affine Background

    internal func renderMode1() {
        // TODO: Implement tile mode 1
        // - BG0, BG1: Regular tile backgrounds (use renderBackgroundLayer)
        // - BG2: Affine background (requires affine transform)

        // For now, render backdrop color
        renderBackdrop()
    }

    // MARK: - Mode 2: 2 Affine Backgrounds

    internal func renderMode2() {
        // TODO: Implement tile mode 2
        // - BG2, BG3: Both affine backgrounds

        // For now, render backdrop color
        renderBackdrop()
    }
}

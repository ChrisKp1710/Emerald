//
//  PPUBitmapModes.swift
//  Emerald
//
//  PPU Bitmap Modes (Mode 3, 4, 5)
//  Handles direct framebuffer rendering
//

import Foundation

extension GBAPPU {
    
    // MARK: - Mode 3: 240×160 RGB555 Bitmap
    
    internal func renderMode3() {
        guard let memory = memory else { return }
        
        let y = currentScanline
        guard y < Self.screenHeight else { return }
        
        // Mode 3: VRAM is a 240×160 bitmap of 16-bit RGB555 pixels
        // VRAM starts at 0x06000000
        let vramBase: UInt32 = 0x06000000
        let lineOffset = y * Self.screenWidth
        
        for x in 0..<Self.screenWidth {
            // Calculate VRAM address for this pixel
            let pixelAddress = vramBase + UInt32((lineOffset + x) * 2)
            
            // Read 16-bit RGB555 pixel
            let rgb555 = memory.read16(address: pixelAddress)
            
            // Convert RGB555 to RGB888
            let r = UInt32((rgb555 & 0x001F) << 3)
            let g = UInt32(((rgb555 & 0x03E0) >> 5) << 3)
            let b = UInt32(((rgb555 & 0x7C00) >> 10) << 3)
            
            // Store in framebuffer as ARGB8888
            let rgba = 0xFF000000 | (b << 16) | (g << 8) | r
            framebuffer[lineOffset + x] = rgba
        }
    }
    
    // MARK: - Mode 4: 240×160 8-bit Paletted Bitmap
    
    internal func renderMode4() {
        guard let memory = memory else { return }
        
        let y = currentScanline
        guard y < Self.screenHeight else { return }
        
        // Mode 4: VRAM is 240×160 bitmap of 8-bit palette indices
        // Two frames available: 0x06000000 and 0x0600A000
        // Frame selected by bit 4 of DISPCNT
        let frame = (dispcnt & 0x0010) != 0 ? 1 : 0
        let vramBase: UInt32 = 0x06000000 + UInt32(frame * 0xA000)
        let paletteBase: UInt32 = 0x05000000 // Palette RAM
        
        let lineOffset = y * Self.screenWidth
        
        for x in 0..<Self.screenWidth {
            // Read 8-bit palette index
            let pixelAddress = vramBase + UInt32(lineOffset + x)
            let paletteIndex = memory.read8(address: pixelAddress)
            
            // Read RGB555 color from palette
            let colorAddress = paletteBase + UInt32(paletteIndex) * 2
            let rgb555 = memory.read16(address: colorAddress)
            
            // Convert RGB555 to RGB888
            let r = UInt32((rgb555 & 0x001F) << 3)
            let g = UInt32(((rgb555 & 0x03E0) >> 5) << 3)
            let b = UInt32(((rgb555 & 0x7C00) >> 10) << 3)
            
            // Store in framebuffer as ARGB8888
            let rgba = 0xFF000000 | (b << 16) | (g << 8) | r
            framebuffer[lineOffset + x] = rgba
        }
    }
    
    // MARK: - Mode 5: 160×128 RGB555 Bitmap
    
    internal func renderMode5() {
        guard let memory = memory else { return }
        
        let y = currentScanline
        guard y < Self.screenHeight else { return }
        
        // Mode 5: 160×128 bitmap, centered on 240×160 screen
        // Two frames available like Mode 4
        let frame = (dispcnt & 0x0010) != 0 ? 1 : 0
        let vramBase: UInt32 = 0x06000000 + UInt32(frame * 0xA000)
        
        let bitmapWidth = 160
        let bitmapHeight = 128
        let xOffset = (Self.screenWidth - bitmapWidth) / 2
        let yOffset = (Self.screenHeight - bitmapHeight) / 2
        
        let lineOffset = y * Self.screenWidth
        
        // Check if scanline is within bitmap area
        if y < yOffset || y >= yOffset + bitmapHeight {
            // Outside bitmap area - draw backdrop color
            let backdropColor = getBackdropColor()
            for x in 0..<Self.screenWidth {
                framebuffer[lineOffset + x] = backdropColor
            }
            return
        }
        
        let bitmapY = y - yOffset
        
        for x in 0..<Self.screenWidth {
            if x < xOffset || x >= xOffset + bitmapWidth {
                // Outside bitmap area - draw backdrop color
                framebuffer[lineOffset + x] = getBackdropColor()
            } else {
                let bitmapX = x - xOffset
                
                // Calculate VRAM address
                let pixelAddress = vramBase + UInt32((bitmapY * bitmapWidth + bitmapX) * 2)
                
                // Read 16-bit RGB555 pixel
                let rgb555 = memory.read16(address: pixelAddress)
                
                // Convert RGB555 to RGB888
                let r = UInt32((rgb555 & 0x001F) << 3)
                let g = UInt32(((rgb555 & 0x03E0) >> 5) << 3)
                let b = UInt32(((rgb555 & 0x7C00) >> 10) << 3)
                
                // Store in framebuffer as ARGB8888
                let rgba = 0xFF000000 | (b << 16) | (g << 8) | r
                framebuffer[lineOffset + x] = rgba
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func getBackdropColor() -> UInt32 {
        guard let memory = memory else { return 0xFF000000 }
        
        // Backdrop color is first entry in palette RAM
        let paletteBase: UInt32 = 0x05000000
        let rgb555 = memory.read16(address: paletteBase)
        
        // Convert RGB555 to RGB888
        let r = UInt32((rgb555 & 0x001F) << 3)
        let g = UInt32(((rgb555 & 0x03E0) >> 5) << 3)
        let b = UInt32(((rgb555 & 0x7C00) >> 10) << 3)
        
        return 0xFF000000 | (b << 16) | (g << 8) | r
    }
}

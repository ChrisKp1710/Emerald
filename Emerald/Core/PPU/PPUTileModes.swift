//
//  PPUTileModes.swift
//  Emerald
//
//  PPU Tile Modes (Mode 0, 1, 2)
//  Handles tile-based background rendering
//

import Foundation

extension GBAPPU {
    
    // MARK: - Mode 0: 4 Tile Backgrounds
    
    internal func renderMode0() {
        // TODO: Implement tile mode 0
        // - 4 background layers (BG0-BG3)
        // - Each can be text or affine
        // - Priority-based rendering
        
        // For now, render backdrop color
        renderBackdrop()
    }
    
    // MARK: - Mode 1: 2 Tile + 1 Affine Background
    
    internal func renderMode1() {
        // TODO: Implement tile mode 1
        // - BG0, BG1: Regular tile backgrounds
        // - BG2: Affine background (rotation/scaling)
        // - Priority-based rendering
        
        // For now, render backdrop color
        renderBackdrop()
    }
    
    // MARK: - Mode 2: 2 Affine Backgrounds
    
    internal func renderMode2() {
        // TODO: Implement tile mode 2
        // - BG2, BG3: Both affine backgrounds
        // - Rotation and scaling support
        // - Priority-based rendering
        
        // For now, render backdrop color
        renderBackdrop()
    }
    
    // MARK: - Helper Functions
    
    private func renderBackdrop() {
        let y = currentScanline
        guard y < Self.screenHeight else { return }
        
        let backdropColor = getBackdropColor()
        let offset = y * Self.screenWidth
        
        for x in 0..<Self.screenWidth {
            framebuffer[offset + x] = backdropColor
        }
    }
    
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

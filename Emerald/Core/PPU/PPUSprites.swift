//
//  PPUSprites.swift
//  Emerald
//
//  PPU Sprite Rendering (OBJ)
//  Handles 128 hardware sprites with priority and effects
//

import Foundation

extension GBAPPU {
    
    // MARK: - Sprite Structures
    
    struct Sprite {
        var y: Int
        var x: Int
        var tileNumber: Int
        var priority: Int
        var palette: Int
        var hFlip: Bool
        var vFlip: Bool
        var width: Int
        var height: Int
        var mode: Int // 0=normal, 1=semi-transparent, 2=window, 3=prohibited
        var mosaic: Bool
        var colorMode: Int // 0=4bpp, 1=8bpp
        var shape: Int // 0=square, 1=horizontal, 2=vertical
        var size: Int // 0-3 depending on shape
        var affineIndex: Int
        var doubleSize: Bool
        var disabled: Bool
    }
    
    // MARK: - Sprite Rendering
    
    internal func renderSprites(scanline: [UInt32]) -> [UInt32] {
        guard memory != nil else { return scanline }
        
        // Check if sprites are enabled
        guard (dispcnt & 0x1000) != 0 else { return scanline }
        
        var outputLine = scanline
        let y = currentScanline
        
        // OAM (Object Attribute Memory) at 0x07000000
        // 128 sprites × 8 bytes each = 1024 bytes
        let oamBase: UInt32 = 0x07000000
        
        // Collect visible sprites for this scanline
        var visibleSprites: [Sprite] = []
        
        for i in 0..<128 {
            let spriteAddr = oamBase + UInt32(i * 8)
            let sprite = parseSprite(address: spriteAddr)
            
            // Check if sprite is on this scanline
            if !sprite.disabled && isSpriteVisible(sprite, scanline: y) {
                visibleSprites.append(sprite)
            }
        }
        
        // Sort by priority (lower priority renders first, higher on top)
        visibleSprites.sort { $0.priority < $1.priority }
        
        // Render each visible sprite
        for sprite in visibleSprites {
            renderSprite(sprite, to: &outputLine, scanline: y)
        }
        
        return outputLine
    }
    
    // MARK: - Sprite Parsing
    
    private func parseSprite(address: UInt32) -> Sprite {
        guard let memory = memory else {
            return Sprite(y: 0, x: 0, tileNumber: 0, priority: 0, palette: 0,
                         hFlip: false, vFlip: false, width: 8, height: 8,
                         mode: 0, mosaic: false, colorMode: 0, shape: 0, size: 0,
                         affineIndex: 0, doubleSize: false, disabled: true)
        }
        
        // OAM structure (8 bytes per sprite):
        // Attr0 (2 bytes): Y, shape, mode, mosaic, colors, etc.
        // Attr1 (2 bytes): X, size, flip, affine
        // Attr2 (2 bytes): Tile number, priority, palette
        
        let attr0 = memory.read16(address: address)
        let attr1 = memory.read16(address: address + 2)
        let attr2 = memory.read16(address: address + 4)
        
        // Parse Attr0
        let y = Int(attr0 & 0xFF)
        let objMode = Int((attr0 >> 8) & 0x3) // 0=normal, 1=affine, 2=disabled, 3=affine+double
        let gfxMode = Int((attr0 >> 10) & 0x3) // 0=normal, 1=blend, 2=window
        let mosaic = (attr0 & 0x1000) != 0
        let colorMode = Int((attr0 >> 13) & 0x1) // 0=4bpp(16 colors), 1=8bpp(256 colors)
        let shape = Int((attr0 >> 14) & 0x3) // 0=square, 1=wide, 2=tall
        
        // Parse Attr1
        let x = Int(attr1 & 0x1FF)
        let size = Int((attr1 >> 14) & 0x3)
        
        var hFlip = false
        var vFlip = false
        var affineIndex = 0
        var doubleSize = false
        
        if objMode == 1 || objMode == 3 { // Affine mode
            affineIndex = Int((attr1 >> 9) & 0x1F)
            doubleSize = objMode == 3
        } else {
            hFlip = (attr1 & 0x1000) != 0
            vFlip = (attr1 & 0x2000) != 0
        }
        
        // Parse Attr2
        let tileNumber = Int(attr2 & 0x3FF)
        let priority = Int((attr2 >> 10) & 0x3)
        let palette = Int((attr2 >> 12) & 0xF)
        
        // Calculate sprite dimensions
        let (width, height) = getSpriteDimensions(shape: shape, size: size)
        
        let disabled = (objMode == 2)
        
        return Sprite(
            y: y, x: x, tileNumber: tileNumber, priority: priority, palette: palette,
            hFlip: hFlip, vFlip: vFlip, width: width, height: height,
            mode: gfxMode, mosaic: mosaic, colorMode: colorMode, shape: shape, size: size,
            affineIndex: affineIndex, doubleSize: doubleSize, disabled: disabled
        )
    }
    
    private func getSpriteDimensions(shape: Int, size: Int) -> (Int, Int) {
        // Sprite size table
        let sizes: [[(Int, Int)]] = [
            // Square
            [(8, 8), (16, 16), (32, 32), (64, 64)],
            // Wide (horizontal)
            [(16, 8), (32, 8), (32, 16), (64, 32)],
            // Tall (vertical)
            [(8, 16), (8, 32), (16, 32), (32, 64)]
        ]
        
        guard shape < sizes.count, size < sizes[shape].count else {
            return (8, 8)
        }
        
        return sizes[shape][size]
    }
    
    // MARK: - Sprite Visibility & Rendering
    
    private func isSpriteVisible(_ sprite: Sprite, scanline: Int) -> Bool {
        let spriteY = sprite.y
        let spriteHeight = sprite.height
        
        // Handle Y wrapping (sprites can wrap around screen)
        let adjustedY = spriteY >= 160 ? spriteY - 256 : spriteY
        
        return scanline >= adjustedY && scanline < adjustedY + spriteHeight
    }
    
    private func renderSprite(_ sprite: Sprite, to line: inout [UInt32], scanline: Int) {
        guard memory != nil else { return }
        
        // TODO: Implement full sprite rendering
        // For now, this is a simplified version
        
        let spriteY = sprite.y >= 160 ? sprite.y - 256 : sprite.y
        let localY = scanline - spriteY
        
        guard localY >= 0 && localY < sprite.height else { return }
        
        // TODO: Handle affine transformation
        // TODO: Handle flipping
        // TODO: Handle tile reading from VRAM
        // TODO: Handle palette lookup
        // TODO: Handle transparency
        // TODO: Handle blending modes
        
        // Placeholder: Just mark sprite area with a debug color
        let spriteX = sprite.x >= 256 ? sprite.x - 512 : sprite.x
        
        for x in 0..<sprite.width {
            let screenX = spriteX + x
            guard screenX >= 0 && screenX < Self.screenWidth else { continue }
            
            // Debug: Red tint for sprite area
            // line[screenX] = 0xFFFF0000
        }
    }
}

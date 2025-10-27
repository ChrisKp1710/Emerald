//
//  ROMImageExtractor.swift
//  Emerald
//
//  Created by Christian Koscielniak Pinto on 27/10/25.
//

import Foundation
import SwiftUI
import AppKit

/// Extracts logo and creates placeholder images for GBA ROMs
@MainActor
class ROMImageExtractor {
    
    /// Extract the Nintendo logo from ROM header (offset 0x04, 156 bytes)
    /// This creates a unique visual identifier for each ROM
    static func extractLogoImage(from romData: Data) -> NSImage? {
        guard romData.count >= 160 else { return nil }
        
        // Nintendo logo is at offset 0x04, 156 bytes
        // It's a 1-bit bitmap, 48x8 pixels
        let logoData = romData.subdata(in: 4..<160)
        
        // Create a simple image from the logo data
        // For now, return a placeholder - full implementation would decode the bitmap
        return createPlaceholderImage(from: logoData)
    }
    
    /// Generate a color-coded placeholder based on ROM title/category
    static func generatePlaceholder(for rom: GBARom) -> NSImage {
        let size = NSSize(width: 240, height: 160)
        
        return NSImage(size: size, flipped: false) { bounds in
            // Background gradient based on category
            let gradient = NSGradient(colors: [
                categoryColor(for: rom.category).withAlphaComponent(0.8),
                categoryColor(for: rom.category).withAlphaComponent(0.4)
            ])
            gradient?.draw(in: bounds, angle: 135)
            
            // Game controller icon
            let iconSize: CGFloat = 60
            let iconRect = NSRect(
                x: (bounds.width - iconSize) / 2,
                y: (bounds.height - iconSize) / 2 + 20,
                width: iconSize,
                height: iconSize
            )
            
            if let icon = NSImage(systemSymbolName: rom.category.systemImage, accessibilityDescription: nil) {
                icon.draw(in: iconRect)
            }
            
            // ROM title at bottom
            let titleRect = NSRect(
                x: 10,
                y: 10,
                width: bounds.width - 20,
                height: 30
            )
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: NSColor.white,
                .paragraphStyle: paragraphStyle
            ]
            
            rom.title.draw(in: titleRect, withAttributes: attributes)
            
            return true
        }
    }
    
    /// Create a simple placeholder from logo data (for unique visual)
    private static func createPlaceholderImage(from logoData: Data) -> NSImage {
        let size = NSSize(width: 240, height: 160)
        
        return NSImage(size: size, flipped: false) { bounds in
            // Use logo data to create a unique pattern
            let hash = logoData.hashValue
            let hue = CGFloat(abs(hash) % 360) / 360.0
            
            NSColor(hue: hue, saturation: 0.6, brightness: 0.7, alpha: 1.0).setFill()
            bounds.fill()
            
            return true
        }
    }
    
    /// Get category-specific color
    private static func categoryColor(for category: ROMCategory) -> NSColor {
        switch category {
        case .action: return NSColor.systemRed
        case .adventure: return NSColor.systemOrange
        case .rpg: return NSColor.systemPurple
        case .fighting: return NSColor.systemPink
        case .platform: return NSColor.systemBlue
        case .puzzle: return NSColor.systemTeal
        case .racing: return NSColor.systemYellow
        case .shooter: return NSColor.systemRed.blended(withFraction: 0.3, of: .black)!
        case .simulation: return NSColor.systemGreen
        case .sports: return NSColor.systemOrange.blended(withFraction: 0.3, of: .white)!
        case .strategy: return NSColor.systemIndigo
        case .educational: return NSColor.systemBrown
        case .homebrew: return NSColor.systemGray
        case .demo: return NSColor.systemGray
        case .unknown: return NSColor.darkGray
        }
    }
}

/// SwiftUI wrapper for ROM images
struct ROMImageView: View {
    let rom: GBARom
    @State private var image: NSImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Loading placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                    
                    ProgressView()
                }
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        // Try to load cached image or generate new one
        await MainActor.run {
            do {
                let romData = try Data(contentsOf: rom.url)
                image = ROMImageExtractor.generatePlaceholder(for: rom)
            } catch {
                image = ROMImageExtractor.generatePlaceholder(for: rom)
            }
        }
    }
}

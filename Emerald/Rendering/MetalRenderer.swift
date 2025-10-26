//
//  MetalRenderer.swift
//  Emerald
//
//  Created by Christian Koscielniak Pinto on 26/10/25.
//

import Foundation
import Metal
import MetalKit
import OSLog

final class MetalRenderer {
    private let logger = Logger(subsystem: "com.emerald.gba", category: "MetalRenderer")
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var texture: MTLTexture?
    
    // GBA screen dimensions
    static let screenWidth = 240
    static let screenHeight = 160
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RendererError.metalNotSupported
        }
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw RendererError.failedToCreateCommandQueue
        }
        
        self.device = device
        self.commandQueue = commandQueue
        
        // Create texture for GBA screen
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: Self.screenWidth,
            height: Self.screenHeight,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            throw RendererError.failedToCreateTexture
        }
        
        self.texture = texture
        
        logger.info("Metal renderer initialized")
    }
    
    func updateTexture(with frameBuffer: UnsafeRawPointer, width: Int, height: Int) {
        guard let texture = texture else { return }
        
        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: width, height: height, depth: 1)
        )
        
        texture.replace(
            region: region,
            mipmapLevel: 0,
            withBytes: frameBuffer,
            bytesPerRow: width * 4 // 4 bytes per pixel (RGBA)
        )
    }
    
    func getTexture() -> MTLTexture? {
        return texture
    }
}

enum RendererError: LocalizedError {
    case metalNotSupported
    case failedToCreateCommandQueue
    case failedToCreateTexture
    
    var errorDescription: String? {
        switch self {
        case .metalNotSupported:
            return "Metal is not supported on this device"
        case .failedToCreateCommandQueue:
            return "Failed to create Metal command queue"
        case .failedToCreateTexture:
            return "Failed to create Metal texture"
        }
    }
}
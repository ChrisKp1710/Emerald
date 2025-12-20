//
//  EmulatorScreenView.swift
//  Emerald
//
//  Created by Christian Koscielniak Pinto on 26/10/25.
//

import SwiftUI
import MetalKit

struct EmulatorScreenView: View {
    @EnvironmentObject var emulatorState: EmulatorState
    @State private var metalRenderer: EmulatorMetalRenderer?

    var body: some View {
        let _ = print("🎨 DEBUG: EmulatorScreenView body is being rendered")
        GeometryReader { geometry in
            let _ = print("🎨 DEBUG: GeometryReader size: \(geometry.size)")
            MetalView(metalRenderer: $metalRenderer, emulatorState: emulatorState)
                .aspectRatio(240.0 / 160.0, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        }
    }
}

struct MetalView: NSViewRepresentable {
    @EnvironmentObject private var settings: EmulatorSettings
    @Binding var metalRenderer: EmulatorMetalRenderer?
    let emulatorState: EmulatorState

    func makeNSView(context: Context) -> MTKView {
        print("🎨 DEBUG: makeNSView called - Creating MTKView")
        let metalView = MTKView()

        // Setup Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal device not available")
        }
        
        print("🎨 DEBUG: Metal device created: \(device.name)")

        metalView.device = device
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.framebufferOnly = false

        // Create and set the renderer
        let renderer = EmulatorMetalRenderer(device: device, view: metalView)
        metalView.delegate = renderer

        // Set up callback to update framebuffer from emulator IMMEDIATELY
        var frameCount = 0
        emulatorState.setFrameUpdateCallback { [weak renderer] framebuffer in
            frameCount += 1

            // Debug: Log first few frames
            if frameCount <= 3 {
                let firstPixels = Array(framebuffer.prefix(5))
                print("🖼️ Frame \(frameCount) callback - First 5 pixels: \(firstPixels.map { String(format: "0x%08X", $0) })")
            }

            // Use withUnsafeBytes to avoid copying the entire array
            framebuffer.withUnsafeBytes { bufferPointer in
                guard let baseAddress = bufferPointer.baseAddress else { return }
                let data = Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: baseAddress),
                              count: framebuffer.count * MemoryLayout<UInt32>.stride,
                              deallocator: .none)
                renderer?.updateFramebuffer(data)
            }
        }

        // Store the renderer in the binding (async is ok here)
        DispatchQueue.main.async {
            self.metalRenderer = renderer
        }

        // Configure rendering settings
        metalView.enableSetNeedsDisplay = false
        metalView.preferredFramesPerSecond = settings.enableVSync ? 60 : 0

        return metalView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // Update renderer settings when needed
        nsView.preferredFramesPerSecond = settings.enableVSync ? 60 : 0
    }
}

// MARK: - Emulator Metal Renderer

class EmulatorMetalRenderer: NSObject {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var renderPipelineState: MTLRenderPipelineState?
    private var texture: MTLTexture?
    private var vertexBuffer: MTLBuffer?
    
    // GBA screen dimensions
    private let screenWidth = 240
    private let screenHeight = 160
    
    // Vertex data for full-screen quad
    private let vertices: [Float] = [
        // Positions    // Texture coordinates
        -1.0, -1.0,     0.0, 1.0,  // Bottom left
         1.0, -1.0,     1.0, 1.0,  // Bottom right
        -1.0,  1.0,     0.0, 0.0,  // Top left
         1.0,  1.0,     1.0, 0.0   // Top right
    ]
    
    init(device: MTLDevice, view: MTKView) {
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Could not create command queue")
        }
        self.commandQueue = commandQueue
        
        super.init()
        
        setupMetal(view: view)
        createTexture()
        createVertexBuffer()
    }
    
    private func setupMetal(view: MTKView) {
        // Load shaders
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not create default Metal library")
        }
        
        guard let vertexFunction = library.makeFunction(name: "vertex_main"),
              let fragmentFunction = library.makeFunction(name: "fragment_main") else {
            fatalError("Could not create shader functions")
        }
        
        // Create render pipeline
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Could not create render pipeline state: \(error)")
        }
    }
    
    private func createTexture() {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: screenWidth,
            height: screenHeight,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        texture = device.makeTexture(descriptor: textureDescriptor)
    }
    
    private func createVertexBuffer() {
        let vertexDataSize = vertices.count * MemoryLayout<Float>.size
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertexDataSize, options: [])
    }
    
    func updateFramebuffer(_ frameData: Data) {
        guard let texture = texture else { return }
        
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                              size: MTLSize(width: screenWidth, height: screenHeight, depth: 1))
        
        frameData.withUnsafeBytes { bytes in
            texture.replace(region: region,
                           mipmapLevel: 0,
                           withBytes: bytes.baseAddress!,
                           bytesPerRow: screenWidth * 4)
        }
    }
}

extension EmulatorMetalRenderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle size changes if needed
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let renderPipelineState = renderPipelineState,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
              let vertexBuffer = vertexBuffer,
              let texture = texture else {
            return
        }
        
        // Setup render state
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(texture, index: 0)
        
        // Draw quad
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
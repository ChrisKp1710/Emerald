//
//  EmulatorState.swift
//  Emerald
//
//  Created by Christian Koscielniak Pinto on 26/10/25.
//

import Foundation
import SwiftUI
import OSLog
import Combine

/// Main state manager for the emulator
@MainActor
final class EmulatorState: ObservableObject {
    private let logger = Logger(subsystem: "com.emerald.gba", category: "EmulatorState")
    
    // MARK: - Published Properties
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var currentROM: GBARom?
    @Published var currentSaveState: SaveState?
    @Published var framerate: Double = 0.0
    @Published var emulationSpeed: Double = 1.0
    @Published var audioEnabled = true
    @Published var volume: Double = 0.8
    
    // MARK: - Core Components
    private var cpu: GBAARM7TDMI?
    private var memory: GBAMemoryManager?
    private var ppu: GBAPictureProcessingUnit?
    private var apu: GBAAudioProcessingUnit?
    private var cartridge: GBACartridge?
    private var timerSystem: GBATimerSystem?
    private var dmaController: GBADMAController?
    private var interruptController: GBAInterruptController?
    
    // MARK: - Rendering & Audio
    private var metalRenderer: MetalRenderer?
    private var audioEngine: GBAAudioEngine?
    
    // MARK: - Threading
    private var emulationTask: Task<Void, Never>?
    private let emulationQueue = DispatchQueue(label: "com.emerald.emulation", qos: .userInteractive)
    
    // MARK: - Performance Monitoring
    private var frameCounter = 0
    private var lastFrameTime = CACurrentMediaTime()
    
    init() {
        logger.info("Initializing EmulatorState")
        setupComponents()
    }
    
    deinit {
        // Clean up resources
        emulationTask?.cancel()
        emulationTask = nil
        
        // Save battery backup if needed
        cartridge?.saveBatteryBackup()
    }
    
    // MARK: - Public Interface
    
    func loadROM(_ rom: GBARom) async throws {
        let log = LogManager.shared
        
        await log.log("🎮 Starting ROM load process...", category: "ROM", level: .info)
        await log.log("ROM: \(rom.title)", category: "ROM", level: .info)
        await log.log("File: \(rom.url.lastPathComponent)", category: "ROM", level: .info)
        
        logger.info("Loading ROM: \(rom.title)")
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: rom.url.path) else {
            await log.log("❌ ROM file not found at path!", category: "ROM", level: .error)
            throw EmulatorError.failedToLoadROM
        }
        await log.log("✅ ROM file found", category: "ROM", level: .success)
        
        // Read ROM data
        guard let romData = try? Data(contentsOf: rom.url) else {
            await log.log("❌ Failed to read ROM data", category: "ROM", level: .error)
            throw EmulatorError.failedToLoadROM
        }
        await log.log("✅ ROM data read: \(romData.count) bytes (\(romData.count / 1024 / 1024) MB)", category: "ROM", level: .success)
        
        // Stop current emulation
        await log.log("🛑 Stopping current emulation", category: "System", level: .info)
        stopEmulation()
        
        // Create new cartridge
        await log.log("📦 Creating cartridge...", category: "ROM", level: .info)
        do {
            cartridge = try GBACartridge(data: romData, saveURL: rom.saveURL)
            await log.log("✅ Cartridge created successfully", category: "ROM", level: .success)
        } catch {
            await log.log("❌ Failed to create cartridge: \(error.localizedDescription)", category: "ROM", level: .error)
            throw error
        }
        
        // Initialize components with new cartridge
        await log.log("🔧 Initializing emulator components...", category: "System", level: .info)
        try await initializeWithCartridge(cartridge!)
        await log.log("✅ Components initialized", category: "System", level: .success)
        
        currentROM = rom
        await log.log("🎉 ROM loaded successfully!", category: "ROM", level: .success)
        await log.log("Ready to start emulation", category: "System", level: .info)
        
        logger.info("Successfully loaded ROM")
    }
    
    func startEmulation() {
        guard let cartridge = cartridge, !isRunning else { 
            Task {
                await LogManager.shared.log("⚠️ Cannot start: No cartridge or already running", category: "System", level: .warning)
            }
            return
        }
        
        Task {
            await LogManager.shared.log("▶️ Starting emulation", category: "System", level: .info)
        }
        
        logger.info("Starting emulation")
        isRunning = true
        isPaused = false
        
        Task {
            await LogManager.shared.log("✅ Emulation started (60 FPS target)", category: "System", level: .success)
        }
        
        emulationTask = Task {
            await runEmulationLoop()
        }
    }
    
    func pauseEmulation() {
        guard isRunning else { return }
        logger.info("Pausing emulation")
        isPaused = true
    }
    
    func resumeEmulation() {
        guard isRunning else { return }
        logger.info("Resuming emulation")
        isPaused = false
    }
    
    func stopEmulation() {
        guard isRunning else { return }
        
        logger.info("Stopping emulation")
        isRunning = false
        isPaused = false
        
        emulationTask?.cancel()
        emulationTask = nil
        
        // Save battery backup if needed
        cartridge?.saveBatteryBackup()
    }
    
    func reset() async {
        logger.info("Resetting emulator")
        
        let wasRunning = isRunning
        stopEmulation()
        
        // Reset all components
        cpu?.reset()
        memory?.reset()
        ppu?.reset()
        apu?.reset()
        timerSystem?.reset()
        dmaController?.reset()
        interruptController?.reset()
        
        if wasRunning {
            startEmulation()
        }
    }
    
    // MARK: - Save States
    
    func saveState(to slot: Int) async throws {
        guard let cpu = cpu, let memory = memory else {
            throw EmulatorError.emulatorNotInitialized
        }
        
        let saveState = SaveState(
            slot: slot,
            timestamp: Date(),
            romChecksum: currentROM?.checksum ?? "",
            cpuState: cpu.saveState(),
            memoryState: memory.saveState(),
            ppuState: ppu?.saveState(),
            apuState: apu?.saveState()
        )
        
        try await saveState.save()
        logger.info("Saved state to slot \(slot)")
    }
    
    func loadState(from slot: Int) async throws {
        guard let saveState = try? await SaveState.load(from: slot),
              saveState.romChecksum == currentROM?.checksum else {
            throw EmulatorError.invalidSaveState
        }
        
        // Restore component states
        cpu?.loadState(saveState.cpuState)
        memory?.loadState(saveState.memoryState)
        
        if let ppuState = saveState.ppuState {
            ppu?.loadState(ppuState)
        }
        
        if let apuState = saveState.apuState {
            apu?.loadState(apuState)
        }
        
        currentSaveState = saveState
        logger.info("Loaded state from slot \(slot)")
    }
    
    // MARK: - Private Methods
    
    private func setupComponents() {
        // Initialize Metal renderer
        do {
            metalRenderer = try MetalRenderer()
        } catch {
            logger.error("Failed to initialize Metal renderer: \(error)")
        }
        
        // Initialize audio engine
        do {
            audioEngine = try GBAAudioEngine()
        } catch {
            logger.error("Failed to initialize audio engine: \(error)")
        }
    }
    
    private func initializeWithCartridge(_ cartridge: GBACartridge) async throws {
        await LogManager.shared.log("Initializing Memory Manager...", category: "Memory", level: .info)
        // Initialize memory manager
        memory = GBAMemoryManager(cartridge: cartridge)
        await LogManager.shared.log("✅ Memory Manager ready", category: "Memory", level: .success)
        
        await LogManager.shared.log("Initializing CPU (ARM7TDMI)...", category: "CPU", level: .info)
        // Initialize CPU
        cpu = GBAARM7TDMI(memory: memory!)
        await LogManager.shared.log("✅ CPU ready", category: "CPU", level: .success)
        
        await LogManager.shared.log("Initializing PPU (Graphics)...", category: "PPU", level: .info)
        // Initialize PPU
        ppu = GBAPictureProcessingUnit(memory: memory!, renderer: metalRenderer)
        await LogManager.shared.log("⚠️ PPU initialized (stub - no rendering yet)", category: "PPU", level: .warning)
        
        await LogManager.shared.log("Initializing APU (Audio)...", category: "Audio", level: .info)
        // Initialize APU
        apu = GBAAudioProcessingUnit(audioEngine: audioEngine)
        await LogManager.shared.log("⚠️ APU initialized (stub - no sound yet)", category: "Audio", level: .warning)
        
        // Initialize timer system
        timerSystem = GBATimerSystem()
        
        // Initialize DMA controller
        dmaController = GBADMAController(memory: memory!)
        
        // Initialize interrupt controller
        interruptController = GBAInterruptController()
        
        // Connect components
        connectComponents()
    }
    
    private func connectComponents() {
        guard let cpu = cpu,
              let memory = memory,
              let ppu = ppu,
              let apu = apu,
              let timerSystem = timerSystem,
              let dmaController = dmaController,
              let interruptController = interruptController else {
            return
        }
        
        // Set up component interconnections
        cpu.interruptController = interruptController
        memory.dmaController = dmaController
        ppu.interruptController = interruptController
        timerSystem.interruptController = interruptController
        dmaController.interruptController = interruptController
    }
    
    private func runEmulationLoop() async {
        let targetFrameTime = 1.0 / 59.73 // GBA runs at ~59.73 FPS
        var lastTime = CACurrentMediaTime()
        
        while isRunning && !Task.isCancelled {
            if !isPaused {
                let startTime = CACurrentMediaTime()
                
                // Execute one frame
                await executeFrame()
                
                // Update framerate counter
                updateFramerate()
                
                // Frame timing
                let frameTime = CACurrentMediaTime() - startTime
                let targetTime = targetFrameTime / emulationSpeed
                
                if frameTime < targetTime {
                    let sleepTime = targetTime - frameTime
                    try? await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
                }
            } else {
                // Sleep while paused
                try? await Task.sleep(nanoseconds: 16_000_000) // ~60 FPS check
            }
        }
    }
    
    private func executeFrame() async {
        // Execute one frame worth of cycles (approximately 280,896 cycles)
        let cyclesPerFrame = 280_896
        var cyclesExecuted = 0
        
        while cyclesExecuted < cyclesPerFrame && isRunning && !isPaused {
            // Execute CPU instruction
            let cycles = cpu?.executeInstruction() ?? 1
            cyclesExecuted += cycles
            
            // Update other components
            ppu?.update(cycles: cycles)
            apu?.update(cycles: cycles)
            timerSystem?.update(cycles: cycles)
            dmaController?.update(cycles: cycles)
        }
        
        // Render frame
        await ppu?.renderFrame()
    }
    
    private func updateFramerate() {
        frameCounter += 1
        let currentTime = CACurrentMediaTime()
        
        if currentTime - lastFrameTime >= 1.0 {
            framerate = Double(frameCounter) / (currentTime - lastFrameTime)
            frameCounter = 0
            lastFrameTime = currentTime
        }
    }
}

// MARK: - EmulatorError

enum EmulatorError: LocalizedError {
    case failedToLoadROM
    case emulatorNotInitialized
    case invalidSaveState
    case metalInitializationFailed
    case audioInitializationFailed
    
    var errorDescription: String? {
        switch self {
        case .failedToLoadROM:
            return "Failed to load ROM file"
        case .emulatorNotInitialized:
            return "Emulator components not initialized"
        case .invalidSaveState:
            return "Invalid save state"
        case .metalInitializationFailed:
            return "Failed to initialize Metal renderer"
        case .audioInitializationFailed:
            return "Failed to initialize audio engine"
        }
    }
}
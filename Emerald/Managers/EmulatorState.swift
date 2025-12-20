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
    @Published var currentFramebuffer: [UInt32] = []
    
    // MARK: - Core Components
    private var cpu: GBAARM7TDMI?
    private var memory: GBAMemoryManager?
    private var ppu: GBAPPU?  // Nuova PPU modulare
    private var apu: GBAAudioProcessingUnit?
    private var cartridge: GBACartridge?
    private var timerSystem: GBATimerSystem?
    private var dmaController: GBADMAController?
    private var interruptController: GBAInterruptController?
    
    // MARK: - Rendering & Audio
    private var metalRenderer: MetalRenderer?
    private var frameUpdateCallback: (([UInt32]) -> Void)? // Callback to update screen
    private var audioEngine: GBAAudioEngine?
    
    // MARK: - Threading
    private var emulationTask: Task<Void, Never>?
    private let emulationQueue = DispatchQueue(label: "com.emerald.emulation", qos: .userInteractive)
    
    // MARK: - Performance Monitoring
    private var frameCounter = 0
    private var frameCount = 0  // Per il logging debug
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
        Task { @MainActor [weak self] in
            self?.cartridge?.saveBatteryBackup()
        }
    }
    
    // MARK: - Public Interface
    
    func getMetalRenderer() -> MetalRenderer? {
        return metalRenderer
    }

    func setFrameUpdateCallback(_ callback: @escaping ([UInt32]) -> Void) {
        self.frameUpdateCallback = callback
        logger.debug("Frame update callback set")
    }
    
    func loadROM(_ rom: GBARom) async throws {
        let log = LogManager.shared
        
        log.log("🎮 Starting ROM load process...", category: "ROM", level: .info)
        log.log("ROM: \(rom.title)", category: "ROM", level: .info)
        log.log("File: \(rom.url.lastPathComponent)", category: "ROM", level: .info)
        
        logger.info("Loading ROM: \(rom.title)")
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: rom.url.path) else {
            log.log("❌ ROM file not found at path!", category: "ROM", level: .error)
            throw EmulatorError.failedToLoadROM
        }
        log.log("✅ ROM file found", category: "ROM", level: .success)
        
        // Read ROM data
        guard let romData = try? Data(contentsOf: rom.url) else {
            log.log("❌ Failed to read ROM data", category: "ROM", level: .error)
            throw EmulatorError.failedToLoadROM
        }
        log.log("✅ ROM data read: \(romData.count) bytes (\(romData.count / 1024 / 1024) MB)", category: "ROM", level: .success)
        
        // Stop current emulation
        log.log("🛑 Stopping current emulation", category: "System", level: .info)
        stopEmulation()
        
        // Create new cartridge
        log.log("📦 Creating cartridge...", category: "ROM", level: .info)
        do {
            cartridge = try GBACartridge(data: romData, saveURL: rom.saveURL)
            log.log("✅ Cartridge created successfully", category: "ROM", level: .success)
        } catch {
            log.log("❌ Failed to create cartridge: \(error.localizedDescription)", category: "ROM", level: .error)
            throw error
        }
        
        // IMPORTANT: Set currentROM FIRST to trigger UI update
        await MainActor.run {
            self.objectWillChange.send() // Force SwiftUI update
            currentROM = rom
            log.log("⚠️ DEBUG: currentROM set to: \(rom.title) - UI should switch now", category: "System", level: .info)
            log.log("⚠️ DEBUG: currentROM is nil? \(currentROM == nil ? "YES" : "NO")", category: "System", level: .info)
        }
        
        // Then initialize components with new cartridge
        log.log("🔧 Initializing emulator components...", category: "System", level: .info)
        try await initializeWithCartridge(cartridge!)
        log.log("✅ Components initialized", category: "System", level: .success)
        
        log.log("🎉 ROM loaded successfully!", category: "ROM", level: .success)
        log.log("Ready to start emulation", category: "System", level: .info)

        logger.info("Successfully loaded ROM")
    }
    
    func startEmulation() {
        guard cartridge != nil, !isRunning else { 
            Task {
                LogManager.shared.log("⚠️ Cannot start: No cartridge or already running", category: "System", level: .warning)
            }
            return
        }
        
        Task {
            LogManager.shared.log("▶️ Starting emulation", category: "System", level: .info)
        }
        
        logger.info("Starting emulation")
        isRunning = true
        isPaused = false
        
        Task {
            LogManager.shared.log("✅ Emulation started (60 FPS target)", category: "System", level: .success)
        }
        
        emulationTask = Task.detached { [weak self] in
            guard let self = self else { return }
            await self.runEmulationLoop()
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
            ppuState: nil, // TODO: Implement ppu.saveState()
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
        
        // TODO: Implement ppu.loadState()
        // if let ppuState = saveState.ppuState {
        //     ppu?.loadState(ppuState)
        // }
        
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
        LogManager.shared.log("Initializing Memory Manager...", category: "Memory", level: .info)
        // Initialize memory manager
        memory = GBAMemoryManager(cartridge: cartridge)
        LogManager.shared.log("✅ Memory Manager ready", category: "Memory", level: .success)
        
        // Initialize interrupt controller FIRST (needed by other components)
        interruptController = GBAInterruptController()
        LogManager.shared.log("Interrupt controller initialized", category: "System", level: .info)
        
        LogManager.shared.log("Initializing CPU (ARM7TDMI)...", category: "CPU", level: .info)
        // Initialize CPU
        cpu = GBAARM7TDMI(memory: memory!)
        LogManager.shared.log("✅ CPU ready", category: "CPU", level: .success)

        LogManager.shared.log("Initializing BIOS HLE...", category: "BIOS", level: .info)
        // Initialize BIOS High-Level Emulation
        let bios = GBABIOS(cpu: cpu!, memory: memory!, interrupts: interruptController!)
        cpu?.bios = bios
        LogManager.shared.log("✅ BIOS HLE ready - Software interrupts enabled", category: "BIOS", level: .success)

        LogManager.shared.log("Initializing PPU (Graphics)...", category: "PPU", level: .info)
        // Initialize new modular PPU
        ppu = GBAPPU()
        ppu?.setMemory(memory!)
        ppu?.setInterrupts(interruptController!)
        LogManager.shared.log("✅ PPU ready with Mode 3/4/5 support", category: "PPU", level: .success)
        
        LogManager.shared.log("Initializing APU (Audio)...", category: "Audio", level: .info)
        // Initialize APU
        apu = GBAAudioProcessingUnit(audioEngine: audioEngine)
        LogManager.shared.log("⚠️ APU initialized (stub - no sound yet)", category: "Audio", level: .warning)
        
        // Initialize timer system
        timerSystem = GBATimerSystem()
        
        // Initialize DMA controller
        dmaController = GBADMAController(memory: memory!)
        
        // Connect components
        connectComponents()
    }
    
    private func connectComponents() {
        guard let cpu = cpu,
              let memory = memory,
              let ppu = ppu,
              let _ = apu,
              let timerSystem = timerSystem,
              let dmaController = dmaController,
              let interruptController = interruptController else {
            return
        }
        
        // Set up component interconnections
        cpu.interruptController = interruptController
        memory.dmaController = dmaController
        ppu.setInterrupts(interruptController) // Use setInterrupts method
        timerSystem.interruptController = interruptController
        dmaController.interruptController = interruptController
    }
    
    private func runEmulationLoop() async {
        let targetFrameTime = 1.0 / 59.73 // GBA runs at ~59.73 FPS
        var _ = CACurrentMediaTime()
        
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
        var instructionsExecuted = 0
        
        // Safety limit to prevent infinite loops
        let maxInstructionsPerFrame = 100_000
        
        while cyclesExecuted < cyclesPerFrame && isRunning && !isPaused && instructionsExecuted < maxInstructionsPerFrame {
            // Execute CPU instruction
            let cycles = cpu?.executeInstruction() ?? 1
            cyclesExecuted += cycles
            instructionsExecuted += 1
            
            // Update PPU (nuova implementazione)
            ppu?.step(cycles: cycles)
            
            // Update other components
            apu?.update(cycles: cycles)
            timerSystem?.update(cycles: cycles)
            dmaController?.update(cycles: cycles)
        }
        
        // Debug: Warn if we hit the safety limit
        if instructionsExecuted >= maxInstructionsPerFrame {
            logger.warning("⚠️ Safety limit hit: \(instructionsExecuted) instructions")
        }
        
        // Transfer framebuffer to renderer
        if let framebuffer = ppu?.framebuffer {
            // Call the callback to update screen (doesn't block main thread)
            frameUpdateCallback?(framebuffer)

            // Debug: Log first frame rendering
            if self.frameCount == 0 {
                logger.debug("🖼️ First frame rendered successfully")
            }
        }
        
        // Update frame counter - log only every 300 frames (5 seconds)
        self.frameCount += 1
        if self.frameCount % 300 == 0 {
            logger.info("📊 Frame \(self.frameCount) - Emulator running")
        }
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
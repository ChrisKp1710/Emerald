//
//  EmulatorSettings.swift
//  Emerald
//
//  Created by Christian Koscielniak Pinto on 26/10/25.
//

import Foundation
import SwiftUI
import OSLog
import Combine

/// Manages all emulator settings and preferences
@MainActor
final class EmulatorSettings: ObservableObject {
    private let logger = Logger(subsystem: "com.emerald.gba", category: "Settings")
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Display Settings
    @Published var displayScale: Double = 3.0 {
        didSet { userDefaults.set(displayScale, forKey: "displayScale") }
    }
    
    @Published var maintainAspectRatio: Bool = true {
        didSet { userDefaults.set(maintainAspectRatio, forKey: "maintainAspectRatio") }
    }
    
    @Published var scalingFilter: ScalingFilter = .sharp {
        didSet { userDefaults.set(scalingFilter.rawValue, forKey: "scalingFilter") }
    }
    
    @Published var colorCorrection: Bool = true {
        didSet { userDefaults.set(colorCorrection, forKey: "colorCorrection") }
    }
    
    @Published var enableVSync: Bool = true {
        didSet { userDefaults.set(enableVSync, forKey: "enableVSync") }
    }
    
    @Published var frameSkip: Int = 0 {
        didSet { userDefaults.set(frameSkip, forKey: "frameSkip") }
    }
    
    // MARK: - Audio Settings
    @Published var audioEnabled: Bool = true {
        didSet { userDefaults.set(audioEnabled, forKey: "audioEnabled") }
    }
    
    @Published var masterVolume: Double = 0.8 {
        didSet { userDefaults.set(masterVolume, forKey: "masterVolume") }
    }
    
    @Published var audioLatency: AudioLatency = .normal {
        didSet { userDefaults.set(audioLatency.rawValue, forKey: "audioLatency") }
    }
    
    @Published var audioChannels: AudioChannelConfig = .stereo {
        didSet { userDefaults.set(audioChannels.rawValue, forKey: "audioChannels") }
    }
    
    // MARK: - Input Settings
    @Published var keyboardMappings: [GBAButton: KeyboardMapping] = [:] {
        didSet { saveKeyboardMappings() }
    }
    
    @Published var controllerMappings: [GBAButton: ControllerMapping] = [:] {
        didSet { saveControllerMappings() }
    }
    
    @Published var enableTurboMode: Bool = false {
        didSet { userDefaults.set(enableTurboMode, forKey: "enableTurboMode") }
    }
    
    @Published var turboSpeed: Double = 2.0 {
        didSet { userDefaults.set(turboSpeed, forKey: "turboSpeed") }
    }
    
    // MARK: - Performance Settings
    @Published var enableMultithreading: Bool = true {
        didSet { userDefaults.set(enableMultithreading, forKey: "enableMultithreading") }
    }
    
    @Published var cpuUsageLimit: Double = 0.8 {
        didSet { userDefaults.set(cpuUsageLimit, forKey: "cpuUsageLimit") }
    }
    
    @Published var thermalThrottling: Bool = true {
        didSet { userDefaults.set(thermalThrottling, forKey: "thermalThrottling") }
    }
    
    @Published var performanceMode: PerformanceMode = .balanced {
        didSet { userDefaults.set(performanceMode.rawValue, forKey: "performanceMode") }
    }
    
    // MARK: - Advanced Settings
    @Published var enableBIOS: Bool = false {
        didSet { userDefaults.set(enableBIOS, forKey: "enableBIOS") }
    }
    
    @Published var biosURL: URL? {
        didSet { 
            if let url = biosURL {
                userDefaults.set(url, forKey: "biosURL")
            } else {
                userDefaults.removeObject(forKey: "biosURL")
            }
        }
    }
    
    @Published var enableRTC: Bool = true {
        didSet { userDefaults.set(enableRTC, forKey: "enableRTC") }
    }
    
    @Published var saveType: SaveType = .auto {
        didSet { userDefaults.set(saveType.rawValue, forKey: "saveType") }
    }
    
    @Published var debugMode: Bool = false {
        didSet { userDefaults.set(debugMode, forKey: "debugMode") }
    }
    
    // MARK: - Library Settings
    @Published var autoScanDirectories: [URL] = [] {
        didSet { saveAutoScanDirectories() }
    }
    
    @Published var enableMetadataFetching: Bool = true {
        didSet { userDefaults.set(enableMetadataFetching, forKey: "enableMetadataFetching") }
    }
    
    @Published var autoBackupSaves: Bool = true {
        didSet { userDefaults.set(autoBackupSaves, forKey: "autoBackupSaves") }
    }
    
    // MARK: - Initialization
    
    init() {
        loadSettings()
        setupDefaultKeyboardMappings()
        logger.info("Settings initialized")
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        displayScale = userDefaults.object(forKey: "displayScale") as? Double ?? 3.0
        maintainAspectRatio = userDefaults.object(forKey: "maintainAspectRatio") as? Bool ?? true
        
        if let filterRaw = userDefaults.string(forKey: "scalingFilter"),
           let filter = ScalingFilter(rawValue: filterRaw) {
            scalingFilter = filter
        }
        
        colorCorrection = userDefaults.object(forKey: "colorCorrection") as? Bool ?? true
        enableVSync = userDefaults.object(forKey: "enableVSync") as? Bool ?? true
        frameSkip = userDefaults.object(forKey: "frameSkip") as? Int ?? 0
        
        audioEnabled = userDefaults.object(forKey: "audioEnabled") as? Bool ?? true
        masterVolume = userDefaults.object(forKey: "masterVolume") as? Double ?? 0.8
        
        if let latencyRaw = userDefaults.string(forKey: "audioLatency"),
           let latency = AudioLatency(rawValue: latencyRaw) {
            audioLatency = latency
        }
        
        if let channelsRaw = userDefaults.string(forKey: "audioChannels"),
           let channels = AudioChannelConfig(rawValue: channelsRaw) {
            audioChannels = channels
        }
        
        enableTurboMode = userDefaults.object(forKey: "enableTurboMode") as? Bool ?? false
        turboSpeed = userDefaults.object(forKey: "turboSpeed") as? Double ?? 2.0
        
        enableMultithreading = userDefaults.object(forKey: "enableMultithreading") as? Bool ?? true
        cpuUsageLimit = userDefaults.object(forKey: "cpuUsageLimit") as? Double ?? 0.8
        thermalThrottling = userDefaults.object(forKey: "thermalThrottling") as? Bool ?? true
        
        if let modeRaw = userDefaults.string(forKey: "performanceMode"),
           let mode = PerformanceMode(rawValue: modeRaw) {
            performanceMode = mode
        }
        
        enableBIOS = userDefaults.object(forKey: "enableBIOS") as? Bool ?? false
        biosURL = userDefaults.url(forKey: "biosURL")
        enableRTC = userDefaults.object(forKey: "enableRTC") as? Bool ?? true
        
        if let saveTypeRaw = userDefaults.string(forKey: "saveType"),
           let saveType = SaveType(rawValue: saveTypeRaw) {
            self.saveType = saveType
        }
        
        debugMode = userDefaults.object(forKey: "debugMode") as? Bool ?? false
        enableMetadataFetching = userDefaults.object(forKey: "enableMetadataFetching") as? Bool ?? true
        autoBackupSaves = userDefaults.object(forKey: "autoBackupSaves") as? Bool ?? true
        
        loadKeyboardMappings()
        loadControllerMappings()
        loadAutoScanDirectories()
    }
    
    func resetToDefaults() {
        logger.info("Resetting settings to defaults")
        
        // Reset all properties to their default values
        displayScale = 3.0
        maintainAspectRatio = true
        scalingFilter = .sharp
        colorCorrection = true
        enableVSync = true
        frameSkip = 0
        
        audioEnabled = true
        masterVolume = 0.8
        audioLatency = .normal
        audioChannels = .stereo
        
        enableTurboMode = false
        turboSpeed = 2.0
        
        enableMultithreading = true
        cpuUsageLimit = 0.8
        thermalThrottling = true
        performanceMode = .balanced
        
        enableBIOS = false
        biosURL = nil
        enableRTC = true
        saveType = .auto
        debugMode = false
        
        autoScanDirectories = []
        enableMetadataFetching = true
        autoBackupSaves = true
        
        setupDefaultKeyboardMappings()
        keyboardMappings = [:]
        controllerMappings = [:]
        
        // Clear UserDefaults
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            if key.hasPrefix("com.emerald") || 
               ["displayScale", "maintainAspectRatio", "scalingFilter", "colorCorrection", 
                "enableVSync", "frameSkip", "audioEnabled", "masterVolume", "audioLatency",
                "audioChannels", "enableTurboMode", "turboSpeed", "enableMultithreading",
                "cpuUsageLimit", "thermalThrottling", "performanceMode", "enableBIOS",
                "biosURL", "enableRTC", "saveType", "debugMode", "enableMetadataFetching",
                "autoBackupSaves"].contains(key) {
                defaults.removeObject(forKey: key)
            }
        }
    }
    
    // MARK: - Keyboard Mappings
    
    private func setupDefaultKeyboardMappings() {
        keyboardMappings = [
            .up: KeyboardMapping(keyCode: 126, modifiers: []),      // Up Arrow
            .down: KeyboardMapping(keyCode: 125, modifiers: []),    // Down Arrow
            .left: KeyboardMapping(keyCode: 123, modifiers: []),    // Left Arrow
            .right: KeyboardMapping(keyCode: 124, modifiers: []),   // Right Arrow
            .a: KeyboardMapping(keyCode: 44, modifiers: []),        // X
            .b: KeyboardMapping(keyCode: 46, modifiers: []),        // Z
            .l: KeyboardMapping(keyCode: 0, modifiers: []),         // A
            .r: KeyboardMapping(keyCode: 1, modifiers: []),         // S
            .start: KeyboardMapping(keyCode: 36, modifiers: []),    // Return
            .select: KeyboardMapping(keyCode: 48, modifiers: [])    // Tab
        ]
    }
    
    private func loadKeyboardMappings() {
        guard let data = userDefaults.data(forKey: "keyboardMappings") else { return }
        
        do {
            let decoder = JSONDecoder()
            keyboardMappings = try decoder.decode([GBAButton: KeyboardMapping].self, from: data)
        } catch {
            logger.error("Failed to load keyboard mappings: \(error)")
            setupDefaultKeyboardMappings()
        }
    }
    
    private func saveKeyboardMappings() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(keyboardMappings)
            userDefaults.set(data, forKey: "keyboardMappings")
        } catch {
            logger.error("Failed to save keyboard mappings: \(error)")
        }
    }
    
    // MARK: - Controller Mappings
    
    private func loadControllerMappings() {
        guard let data = userDefaults.data(forKey: "controllerMappings") else { return }
        
        do {
            let decoder = JSONDecoder()
            controllerMappings = try decoder.decode([GBAButton: ControllerMapping].self, from: data)
        } catch {
            logger.error("Failed to load controller mappings: \(error)")
        }
    }
    
    private func saveControllerMappings() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(controllerMappings)
            userDefaults.set(data, forKey: "controllerMappings")
        } catch {
            logger.error("Failed to save controller mappings: \(error)")
        }
    }
    
    // MARK: - Auto-scan Directories
    
    private func loadAutoScanDirectories() {
        guard let data = userDefaults.data(forKey: "autoScanDirectories") else { return }
        
        do {
            autoScanDirectories = try JSONDecoder().decode([URL].self, from: data)
        } catch {
            logger.error("Failed to load auto-scan directories: \(error)")
        }
    }
    
    private func saveAutoScanDirectories() {
        do {
            let data = try JSONEncoder().encode(autoScanDirectories)
            userDefaults.set(data, forKey: "autoScanDirectories")
        } catch {
            logger.error("Failed to save auto-scan directories: \(error)")
        }
    }
}

// MARK: - Supporting Types

enum ScalingFilter: String, CaseIterable, Codable {
    case sharp = "Sharp"
    case smooth = "Smooth"
    case crt = "CRT"
    case scanlines = "Scanlines"
    
    var description: String {
        switch self {
        case .sharp: return "Pixel-perfect scaling with sharp edges"
        case .smooth: return "Smooth bilinear filtering"
        case .crt: return "CRT monitor simulation"
        case .scanlines: return "Retro scanline effect"
        }
    }
}

enum AudioLatency: String, CaseIterable, Codable {
    case low = "Low"
    case normal = "Normal"
    case high = "High"
    
    var bufferSize: Int {
        switch self {
        case .low: return 64
        case .normal: return 256
        case .high: return 512
        }
    }
}

enum AudioChannelConfig: String, CaseIterable, Codable {
    case mono = "Mono"
    case stereo = "Stereo"
    case surround = "Surround"
}

enum PerformanceMode: String, CaseIterable, Codable {
    case battery = "Battery Saver"
    case balanced = "Balanced"
    case performance = "Performance"
    
    var description: String {
        switch self {
        case .battery: return "Optimize for battery life"
        case .balanced: return "Balance performance and efficiency"
        case .performance: return "Maximum performance"
        }
    }
}

enum SaveType: String, CaseIterable, Codable {
    case auto = "Auto-detect"
    case none = "None"
    case sram = "SRAM"
    case flash64k = "Flash 64KB"
    case flash128k = "Flash 128KB"
    case eeprom = "EEPROM"
}

enum GBAButton: String, CaseIterable, Codable {
    case a = "A"
    case b = "B"
    case l = "L"
    case r = "R"
    case start = "Start"
    case select = "Select"
    case up = "Up"
    case down = "Down"
    case left = "Left"
    case right = "Right"
    
    var displayName: String {
        return rawValue
    }
}

struct KeyboardMapping: Codable {
    let keyCode: UInt16
    let modifiers: Set<KeyboardModifier>
}

struct ControllerMapping: Codable {
    let buttonIndex: Int
    let isAxis: Bool
    let axisDirection: AxisDirection?
}

enum KeyboardModifier: String, CaseIterable, Codable {
    case command = "⌘"
    case option = "⌥"
    case control = "⌃"
    case shift = "⇧"
}

enum AxisDirection: String, Codable {
    case positive = "+"
    case negative = "-"
}
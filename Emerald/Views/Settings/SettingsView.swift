//
//  SettingsView.swift
//  Emerald
//
//  Created by Christian Koscielniak Pinto on 26/10/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var settings: EmulatorSettings
    @EnvironmentObject private var emulatorState: EmulatorState
    
    var body: some View {
        TabView {
            DisplaySettingsView()
                .tabItem {
                    Label("Display", systemImage: "display")
                }
            
            AudioSettingsView()
                .tabItem {
                    Label("Audio", systemImage: "speaker.2")
                }
            
            InputSettingsView()
                .tabItem {
                    Label("Input", systemImage: "gamecontroller")
                }
            
            PerformanceSettingsView()
                .tabItem {
                    Label("Performance", systemImage: "speedometer")
                }
            
            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
            
            LibrarySettingsView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
        }
        .frame(width: 600, height: 500)
    }
}

struct DisplaySettingsView: View {
    @EnvironmentObject private var settings: EmulatorSettings
    
    var body: some View {
        Form {
            Section("Scaling") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Display Scale:")
                        Spacer()
                        Text("\(settings.displayScale, specifier: "%.1f")×")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $settings.displayScale, in: 1.0...6.0, step: 0.1) {
                        Text("Scale")
                    }
                    .controlSize(.small)
                }
                
                Toggle("Maintain Aspect Ratio", isOn: $settings.maintainAspectRatio)
                
                HStack {
                    Text("Scaling Filter:")
                    Spacer()
                    Picker("Filter", selection: $settings.scalingFilter) {
                        ForEach(ScalingFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
            }
            
            Section("Color & Effects") {
                Toggle("Color Correction", isOn: $settings.colorCorrection)
                
                Text("Adjusts colors to match original GBA screen characteristics")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Performance") {
                Toggle("Vertical Sync", isOn: $settings.enableVSync)
                
                HStack {
                    Text("Frame Skip:")
                    Spacer()
                    Picker("Frame Skip", selection: $settings.frameSkip) {
                        Text("None").tag(0)
                        Text("1 Frame").tag(1)
                        Text("2 Frames").tag(2)
                        Text("3 Frames").tag(3)
                        Text("Auto").tag(-1)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }
                
                if settings.frameSkip > 0 {
                    Text("May improve performance at the cost of visual smoothness")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Display Settings")
    }
}

struct AudioSettingsView: View {
    @EnvironmentObject private var settings: EmulatorSettings
    
    var body: some View {
        Form {
            Section("Audio Output") {
                Toggle("Enable Audio", isOn: $settings.audioEnabled)
                
                if settings.audioEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Master Volume:")
                            Spacer()
                            Text("\(Int(settings.masterVolume * 100))%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $settings.masterVolume, in: 0.0...1.0) {
                            Text("Volume")
                        }
                        .controlSize(.small)
                    }
                    
                    HStack {
                        Text("Channel Configuration:")
                        Spacer()
                        Picker("Channels", selection: $settings.audioChannels) {
                            ForEach(AudioChannelConfig.allCases, id: \.self) { config in
                                Text(config.rawValue).tag(config)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }
                }
            }
            
            if settings.audioEnabled {
                Section("Quality & Latency") {
                    HStack {
                        Text("Audio Latency:")
                        Spacer()
                        Picker("Latency", selection: $settings.audioLatency) {
                            ForEach(AudioLatency.allCases, id: \.self) { latency in
                                VStack(alignment: .trailing) {
                                    Text(latency.rawValue)
                                    Text("(\(latency.bufferSize) samples)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(latency)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                    
                    Text("Lower latency reduces audio delay but may cause crackling on slower systems")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Audio Settings")
    }
}

struct InputSettingsView: View {
    @EnvironmentObject private var settings: EmulatorSettings
    @State private var selectedButton: GBAButton?
    @State private var isRecordingInput = false
    
    var body: some View {
        Form {
            Section("Keyboard Controls") {
                VStack(spacing: 8) {
                    ForEach(GBAButton.allCases, id: \.self) { button in
                        HStack {
                            Text("\(button.displayName):")
                                .frame(width: 60, alignment: .leading)
                            
                            Spacer()
                            
                            Button {
                                selectedButton = button
                                isRecordingInput = true
                            } label: {
                                if let mapping = settings.keyboardMappings[button] {
                                    Text(keyDescription(for: mapping))
                                        .foregroundColor(.primary)
                                } else {
                                    Text("Not Set")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .frame(width: 120)
                        }
                    }
                }
                
                Button("Reset to Defaults") {
                    // Reset keyboard mappings to default
                    settings.keyboardMappings = [:]
                }
                .buttonStyle(.bordered)
            }
            
            Section("Turbo Mode") {
                Toggle("Enable Turbo Mode", isOn: $settings.enableTurboMode)
                
                if settings.enableTurboMode {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Turbo Speed:")
                            Spacer()
                            Text("\(settings.turboSpeed, specifier: "%.1f")×")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $settings.turboSpeed, in: 1.1...10.0, step: 0.1) {
                            Text("Speed")
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Input Settings")
        .alert("Press a key", isPresented: $isRecordingInput) {
            Button("Cancel") {
                isRecordingInput = false
                selectedButton = nil
            }
        } message: {
            Text("Press the key you want to assign to \(selectedButton?.displayName ?? "")...")
        }
    }
    
    private func keyDescription(for mapping: KeyboardMapping) -> String {
        var description = ""
        
        if mapping.modifiers.contains(.command) { description += "⌘" }
        if mapping.modifiers.contains(.option) { description += "⌥" }
        if mapping.modifiers.contains(.control) { description += "⌃" }
        if mapping.modifiers.contains(.shift) { description += "⇧" }
        
        // Convert key code to string (simplified)
        switch mapping.keyCode {
        case 36: description += "Return"
        case 48: description += "Tab"
        case 123: description += "←"
        case 124: description += "→"
        case 125: description += "↓"
        case 126: description += "↑"
        case 0: description += "A"
        case 1: description += "S"
        case 44: description += "Z"
        case 46: description += "X"
        default: description += "Key \(mapping.keyCode)"
        }
        
        return description.isEmpty ? "Unknown" : description
    }
}

struct PerformanceSettingsView: View {
    @EnvironmentObject private var settings: EmulatorSettings
    
    var body: some View {
        Form {
            Section("CPU Usage") {
                HStack {
                    Text("Performance Mode:")
                    Spacer()
                    Picker("Mode", selection: $settings.performanceMode) {
                        ForEach(PerformanceMode.allCases, id: \.self) { mode in
                            VStack(alignment: .trailing) {
                                Text(mode.rawValue)
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }
                
                Toggle("Enable Multithreading", isOn: $settings.enableMultithreading)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("CPU Usage Limit:")
                        Spacer()
                        Text("\(Int(settings.cpuUsageLimit * 100))%")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $settings.cpuUsageLimit, in: 0.3...1.0) {
                        Text("CPU Limit")
                    }
                    .controlSize(.small)
                }
                
                Toggle("Thermal Throttling", isOn: $settings.thermalThrottling)
                
                Text("Automatically reduces performance to prevent overheating")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Performance Settings")
    }
}

struct AdvancedSettingsView: View {
    @EnvironmentObject private var settings: EmulatorSettings
    @State private var showingBIOSPicker = false
    
    var body: some View {
        Form {
            Section("BIOS") {
                Toggle("Use BIOS File", isOn: $settings.enableBIOS)
                
                if settings.enableBIOS {
                    HStack {
                        Text("BIOS File:")
                        Spacer()
                        
                        if let biosURL = settings.biosURL {
                            Text(biosURL.lastPathComponent)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Not selected")
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Choose...") {
                            showingBIOSPicker = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    Text("Using an official GBA BIOS improves compatibility")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Hardware") {
                Toggle("Enable Real-Time Clock", isOn: $settings.enableRTC)
                
                HStack {
                    Text("Save Type:")
                    Spacer()
                    Picker("Save Type", selection: $settings.saveType) {
                        ForEach(SaveType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }
                
                Text("Auto-detect is recommended for most games")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Debug") {
                Toggle("Debug Mode", isOn: $settings.debugMode)
                
                if settings.debugMode {
                    Text("Shows performance information and debug controls")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Reset") {
                Button("Reset All Settings to Defaults") {
                    settings.resetToDefaults()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Advanced Settings")
        .fileImporter(
            isPresented: $showingBIOSPicker,
            allowedContentTypes: [.init(filenameExtension: "bin")!, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                settings.biosURL = urls.first
            case .failure(let error):
                print("Failed to select BIOS: \(error)")
            }
        }
    }
}

struct LibrarySettingsView: View {
    @EnvironmentObject private var settings: EmulatorSettings
    @State private var showingFolderPicker = false
    
    var body: some View {
        Form {
            Section("Auto-Scan Folders") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(settings.autoScanDirectories, id: \.self) { url in
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.blue)
                            
                            Text(url.path)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button {
                                settings.autoScanDirectories.removeAll { $0 == url }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if settings.autoScanDirectories.isEmpty {
                        Text("No auto-scan folders configured")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    Button("Add Folder...") {
                        showingFolderPicker = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            Section("Metadata") {
                Toggle("Enable Metadata Fetching", isOn: $settings.enableMetadataFetching)
                
                Text("Automatically fetch game information from online databases")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Backup") {
                Toggle("Auto-Backup Save Files", isOn: $settings.autoBackupSaves)
                
                Text("Automatically create backups of save files")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Library Settings")
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    if !settings.autoScanDirectories.contains(url) {
                        settings.autoScanDirectories.append(url)
                    }
                }
            case .failure(let error):
                print("Failed to select folders: \(error)")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(EmulatorSettings())
        .environmentObject(EmulatorState())
}
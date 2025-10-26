//
//  FocusedValues.swift
//  Emerald
//
//  Created by Christian Koscielniak Pinto on 26/10/25.
//

import SwiftUI

// MARK: - FocusedValues Extensions

extension FocusedValues {
    var emulatorState: EmulatorState? {
        get { self[EmulatorStateFocusedValueKey.self] }
        set { self[EmulatorStateFocusedValueKey.self] = newValue }
    }
    
    var romLibrary: ROMLibrary? {
        get { self[ROMLibraryFocusedValueKey.self] }
        set { self[ROMLibraryFocusedValueKey.self] = newValue }
    }
    
    var emulatorSettings: EmulatorSettings? {
        get { self[EmulatorSettingsFocusedValueKey.self] }
        set { self[EmulatorSettingsFocusedValueKey.self] = newValue }
    }
}

// MARK: - FocusedValueKeys

private struct EmulatorStateFocusedValueKey: FocusedValueKey {
    typealias Value = EmulatorState
}

private struct ROMLibraryFocusedValueKey: FocusedValueKey {
    typealias Value = ROMLibrary
}

private struct EmulatorSettingsFocusedValueKey: FocusedValueKey {
    typealias Value = EmulatorSettings
}

// MARK: - View Extensions

extension View {
    func focusedEmulatorState(_ state: EmulatorState?) -> some View {
        self.focusedValue(\.emulatorState, state)
    }
    
    func focusedROMLibrary(_ library: ROMLibrary?) -> some View {
        self.focusedValue(\.romLibrary, library)
    }
    
    func focusedEmulatorSettings(_ settings: EmulatorSettings?) -> some View {
        self.focusedValue(\.emulatorSettings, settings)
    }
}
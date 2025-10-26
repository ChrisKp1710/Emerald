//
//  GBAInterrupts.swift
//  Emerald
//
//  Created by Christian Koscielniak Pinto on 26/10/25.
//

import Foundation

/// GBA Interrupt types
enum GBAInterrupt: UInt16, CaseIterable, CustomStringConvertible {
    case vblank = 0x0001
    case hblank = 0x0002
    case vcounter = 0x0004
    case timer0 = 0x0008
    case timer1 = 0x0010
    case timer2 = 0x0020
    case timer3 = 0x0040
    case serial = 0x0080
    case dma0 = 0x0100
    case dma1 = 0x0200
    case dma2 = 0x0400
    case dma3 = 0x0800
    case keypad = 0x1000
    case gamepak = 0x2000
    
    var description: String {
        switch self {
        case .vblank: return "V-Blank"
        case .hblank: return "H-Blank"
        case .vcounter: return "V-Counter"
        case .timer0: return "Timer 0"
        case .timer1: return "Timer 1"
        case .timer2: return "Timer 2"
        case .timer3: return "Timer 3"
        case .serial: return "Serial"
        case .dma0: return "DMA 0"
        case .dma1: return "DMA 1"
        case .dma2: return "DMA 2"
        case .dma3: return "DMA 3"
        case .keypad: return "Keypad"
        case .gamepak: return "Game Pak"
        }
    }
    
    var priority: Int {
        switch self {
        case .vblank: return 0
        case .hblank: return 1
        case .vcounter: return 2
        case .timer0: return 3
        case .timer1: return 4
        case .timer2: return 5
        case .timer3: return 6
        case .serial: return 7
        case .dma0: return 8
        case .dma1: return 9
        case .dma2: return 10
        case .dma3: return 11
        case .keypad: return 12
        case .gamepak: return 13
        }
    }
}
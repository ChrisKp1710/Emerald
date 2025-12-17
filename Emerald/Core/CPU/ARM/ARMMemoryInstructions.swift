//
//  ARMMemoryInstructions.swift
//  Emerald
//
//  ARM7TDMI Memory Access Instructions (Load/Store, Branch, etc.)
//

import Foundation
import os

extension GBAARM7TDMI {
    
    // MARK: - Halfword and Signed Data Transfer
    
    /// Execute Halfword/Signed Data Transfer (LDRH, STRH, LDRSB, LDRSH)
    /// Encoding: xxxx 000P U0WL nnnn dddd oooo 1SH1 oooo
    @inlinable
    internal func executeHalfwordTransfer(_ instruction: UInt32) -> Int {
        let p = (instruction >> 24) & 1 != 0  // Pre/post indexing
        let u = (instruction >> 23) & 1 != 0  // Up/down
        let w = (instruction >> 21) & 1 != 0  // Write-back
        let l = (instruction >> 20) & 1 != 0  // Load/store
        let rn = Int((instruction >> 16) & 0xF)
        let rd = Int((instruction >> 12) & 0xF)
        let s = (instruction >> 6) & 1 != 0   // Signed
        let h = (instruction >> 5) & 1 != 0   // Halfword
        
        var address = registers[rn]
        var offset: UInt32
        
        // Calculate offset
        if (instruction >> 22) & 1 != 0 {
            // Immediate offset
            let offsetHi = (instruction >> 8) & 0xF
            let offsetLo = instruction & 0xF
            offset = (offsetHi << 4) | offsetLo
        } else {
            // Register offset
            let rm = Int(instruction & 0xF)
            offset = registers[rm]
        }
        
        // Apply offset
        if p {
            // Pre-indexed
            address = u ? address &+ offset : address &- offset
        }
        
        var cycles = 1
        
        if l {
            // Load
            if s {
                if h {
                    // LDRSH - Load signed halfword
                    let value16 = memory?.read16(address: address) ?? 0
                    // Sign extend to 32-bit
                    let signedValue = Int16(bitPattern: value16)
                    registers[rd] = UInt32(bitPattern: Int32(signedValue))
                } else {
                    // LDRSB - Load signed byte
                    let value8 = memory?.read8(address: address) ?? 0
                    // Sign extend to 32-bit
                    let signedValue = Int8(bitPattern: value8)
                    registers[rd] = UInt32(bitPattern: Int32(signedValue))
                }
            } else {
                // LDRH - Load unsigned halfword
                let value16 = memory?.read16(address: address) ?? 0
                registers[rd] = UInt32(value16)
            }
            
            // Handle PC load
            if rd == 15 {
                flushPipeline()
                cycles += 2
            }
            
            cycles += 1 // Additional cycle for load
        } else {
            // Store (only STRH is valid, S=0 H=1)
            if h && !s {
                // STRH - Store halfword
                let value = UInt16(truncatingIfNeeded: registers[rd])
                memory?.write16(address: address, value: value)
            }
        }
        
        // Post-indexed or write-back
        if !p {
            // Post-indexed
            address = u ? registers[rn] &+ offset : registers[rn] &- offset
            registers[rn] = address
        } else if w && rn != rd {
            // Write-back (only if pre-indexed and not loading into base register)
            registers[rn] = address
        }
        
        return cycles
    }
    
    // MARK: - Single Data Swap
    
    /// Execute Single Data Swap (SWP, SWPB)
    /// Encoding: xxxx 0001 0B00 nnnn dddd 0000 1001 mmmm
    @inlinable
    internal func executeSingleDataSwap(_ instruction: UInt32) -> Int {
        let b = (instruction >> 22) & 1 != 0  // Byte/word
        let rn = Int((instruction >> 16) & 0xF)
        let rd = Int((instruction >> 12) & 0xF)
        let rm = Int(instruction & 0xF)
        
        let address = registers[rn]
        
        guard let mem = memory else { return 1 }
        
        if b {
            // SWPB - Swap byte
            let temp = mem.read8(address: address)
            mem.write8(address: address, value: UInt8(truncatingIfNeeded: registers[rm]))
            registers[rd] = UInt32(temp)
        } else {
            // SWP - Swap word
            let temp = mem.read32(address: address)
            mem.write32(address: address, value: registers[rm])
            registers[rd] = temp
        }
        
        return 4 // Swap instructions take 4 cycles
    }
    
    // MARK: - PSR Transfer Instructions
    
    @inlinable
    internal func executeMRS(_ instruction: UInt32) -> Int {
        // MRS - Move PSR to Register
        // Format: MRS{cond} Rd, <PSR>
        let rd = Int((instruction >> 12) & 0xF)
        let useSPSR = (instruction >> 22) & 1 != 0
        
        if useSPSR {
            // Read SPSR (only valid in non-User/System modes)
            let currentMode = Mode(rawValue: cpsr & 0x1F)
            if currentMode == .user || currentMode == .system {
                // Unpredictable - reading SPSR in User/System mode
                registers[rd] = 0
            } else {
                // TODO: Get SPSR for current mode from banked registers
                registers[rd] = cpsr // Placeholder
            }
        } else {
            // Read CPSR
            registers[rd] = cpsr
        }
        
        return 1
    }
    
    @inlinable
    internal func executeMSR(_ instruction: UInt32) -> Int {
        // MSR - Move to PSR
        // Format: MSR{cond} <PSR>_<fields>, Rm or #imm
        let useSPSR = (instruction >> 22) & 1 != 0
        let immediate = (instruction >> 25) & 1 != 0
        let fieldMask = (instruction >> 16) & 0xF
        
        var value: UInt32
        if immediate {
            // Immediate value
            let imm = instruction & 0xFF
            let rotate = ((instruction >> 8) & 0xF) * 2
            value = rotateRight(imm, by: Int(rotate))
        } else {
            // Register value
            let rm = Int(instruction & 0xF)
            value = registers[rm]
        }
        
        // Build mask based on field flags
        var mask: UInt32 = 0
        if fieldMask & 0x1 != 0 { // Control field (bits 0-7)
            mask |= 0x000000FF
        }
        if fieldMask & 0x2 != 0 { // Extension field (bits 8-15)
            mask |= 0x0000FF00
        }
        if fieldMask & 0x4 != 0 { // Status field (bits 16-23)
            mask |= 0x00FF0000
        }
        if fieldMask & 0x8 != 0 { // Flags field (bits 24-31)
            mask |= 0xFF000000
        }
        
        // Check privileges for modifying control bits
        let currentMode = Mode(rawValue: cpsr & 0x1F)
        if currentMode == .user {
            // User mode can only modify flags (bits 24-31)
            mask &= 0xFF000000
        }
        
        if useSPSR {
            // Write SPSR (only valid in non-User/System modes)
            if currentMode != .user && currentMode != .system {
                // TODO: Update SPSR for current mode in banked registers
                // Placeholder: just update CPSR for now
                cpsr = (cpsr & ~mask) | (value & mask)
            }
        } else {
            // Write CPSR
            cpsr = (cpsr & ~mask) | (value & mask)
            
            // If mode changed, handle register banking
            let newMode = Mode(rawValue: cpsr & 0x1F)
            if newMode != currentMode {
                // TODO: Switch register banks
                // For now, just log the mode change
            }
        }
        
        return 1
    }
    
    // MARK: - Load/Store Instructions
    
    internal func executeLoadStore(_ instruction: UInt32) -> Int {
        let p = (instruction >> 24) & 1 != 0  // Pre/post indexing
        let u = (instruction >> 23) & 1 != 0  // Up/down
        let b = (instruction >> 22) & 1 != 0  // Byte/word
        let w = (instruction >> 21) & 1 != 0  // Write-back
        let l = (instruction >> 20) & 1 != 0  // Load/store
        let rn = Int((instruction >> 16) & 0xF)
        let rd = Int((instruction >> 12) & 0xF)
        
        var address = registers[rn]
        var offset: UInt32 = 0
        var cycles = 1
        
        // Calculate offset
        if (instruction >> 25) & 1 != 0 {
            // Register offset
            let rm = Int(instruction & 0xF)
            offset = registers[rm]
            
            // Apply shift
            let shiftType = (instruction >> 5) & 0x3
            let shiftAmount = (instruction >> 7) & 0x1F
            offset = applyShift(value: offset, shiftType: shiftType, amount: shiftAmount, updateCarry: false)
        } else {
            // Immediate offset
            offset = instruction & 0xFFF
        }
        
        // Apply pre/post indexing
        if p {
            // Pre-indexing
            if u {
                address = address &+ offset
            } else {
                address = address &- offset
            }
        }
        
        // Perform load/store
        guard let memory = memory else { return cycles }
        
        if l {
            // Load
            if b {
                registers[rd] = UInt32(memory.read8(address: address))
            } else {
                registers[rd] = memory.read32(address: address)
            }
            cycles += getMemoryAccessCycles(address: address)
            
            if rd == 15 {
                flushPipeline()
                cycles += 2
            }
        } else {
            // Store
            if b {
                memory.write8(address: address, value: UInt8(truncatingIfNeeded: registers[rd] & 0xFF))
            } else {
                memory.write32(address: address, value: registers[rd])
            }
            cycles += getMemoryAccessCycles(address: address)
        }
        
        // Post-indexing or write-back
        if !p || w {
            if !p {
                // Post-indexing
                if u {
                    registers[rn] = registers[rn] &+ offset
                } else {
                    registers[rn] = registers[rn] &- offset
                }
            } else {
                // Write-back
                registers[rn] = address
            }
        }
        
        return cycles
    }
    
    // MARK: - Load/Store Multiple
    
    internal func executeLoadStoreMultiple(_ instruction: UInt32) -> Int {
        let p = (instruction >> 24) & 1 != 0  // Pre/post increment
        let u = (instruction >> 23) & 1 != 0  // Up/down
        let _ = (instruction >> 22) & 1 != 0  // PSR & force user mode (unused for now)
        let w = (instruction >> 21) & 1 != 0  // Write-back
        let l = (instruction >> 20) & 1 != 0  // Load/store
        let rn = Int((instruction >> 16) & 0xF)
        let registerList = instruction & 0xFFFF
        
        var address = registers[rn]
        var cycles = 1
        var registerCount = 0
        
        guard let memory = memory else { return cycles }
        
        // Count registers in list
        for i in 0..<16 {
            if (registerList >> i) & 1 != 0 {
                registerCount += 1
            }
        }
        
        // Adjust address for pre-decrement
        if !u {
            address = address &- UInt32(registerCount * 4)
        }
        
        if p && u {
            address += 4
        } else if p && !u {
            address -= 4
        }
        
        // Transfer registers
        for i in 0..<16 {
            if (registerList >> i) & 1 != 0 {
                if l {
                    // Load
                    registers[i] = memory.read32(address: address)
                    if i == 15 {
                        flushPipeline()
                        cycles += 2
                    }
                } else {
                    // Store
                    memory.write32(address: address, value: registers[i])
                }
                
                cycles += getMemoryAccessCycles(address: address)
                
                if u {
                    address += 4
                } else {
                    address -= 4
                }
            }
        }
        
        // Write-back
        if w {
            if u {
                registers[rn] = registers[rn] &+ UInt32(registerCount * 4)
            } else {
                registers[rn] = registers[rn] &- UInt32(registerCount * 4)
            }
        }
        
        return cycles
    }
    
    // MARK: - Branch Instructions
    
    internal func executeBranch(_ instruction: UInt32) -> Int {
        let l = (instruction >> 24) & 1 != 0  // Link
        var offset = instruction & 0xFFFFFF
        
        // Sign extend 24-bit offset to 32-bit
        if (offset & 0x800000) != 0 {
            offset |= 0xFF000000  // Set upper 8 bits for negative
        }
        
        // Shift left by 2 (instructions are word-aligned)
        let signedOffset = Int32(bitPattern: offset) << 2
        
        if l {
            // Branch with Link - save return address
            registers[14] = registers[15] - 4
        }
        
        // Update PC
        registers[15] = UInt32(bitPattern: Int32(bitPattern: registers[15]) &+ signedOffset)
        
        flushPipeline()
        return 3
    }
    
    // MARK: - Software Interrupt
    
    internal func executeSWI(_ instruction: UInt32) -> Int {
        // Software Interrupt
        // In ARM mode: SWI number is in bits [23:16]
        let swiNumber = UInt8((instruction >> 16) & 0xFF)

        // Use BIOS HLE if available
        if let bios = self.bios {
            logger.debug("SWI 0x\(String(format: "%02X", swiNumber)) - Using BIOS HLE")
            return bios.handleSWI(swiNumber)
        }

        // Fallback: Old behavior (jump to BIOS at 0x00000008)
        // This should not happen in normal operation
        logger.warning("⚠️ BIOS HLE not available! Falling back to BIOS jump (will likely fail)")

        savedPSR[.supervisor] = cpsr
        cpsr = (cpsr & 0xFFFFFF00) | 0x13 // Supervisor mode
        registers[14] = registers[15] - 4
        registers[15] = 0x00000008
        flushPipeline()

        return 3
    }
    
    // MARK: - Helper Functions
    
    private func rotateRight(_ value: UInt32, by amount: Int) -> UInt32 {
        guard amount > 0 else { return value }
        let effectiveAmount = amount % 32
        return (value >> effectiveAmount) | (value << (32 - effectiveAmount))
    }
    
    private func getMemoryAccessCycles(address: UInt32) -> Int {
        // Simplified memory timing
        // Real GBA has complex wait states based on memory region
        if address < 0x02000000 {
            return 1  // BIOS, Work RAM - fast
        } else if address < 0x08000000 {
            return 1  // I/O, Palette, VRAM, OAM - fast
        } else {
            return 3  // ROM - slower
        }
    }
}

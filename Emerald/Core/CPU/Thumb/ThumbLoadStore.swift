//
//  ThumbLoadStore.swift
//  Emerald
//
//  Thumb Format 6, 7, 8, 9, 10: All load/store operations
//

import Foundation

extension GBAARM7TDMI {
    
    // MARK: - Format 6: PC-Relative Load
    
    /// Format 6: LDR Rd, [PC, #imm]
    /// Encoding: 01001[Rd:3][word8:8]
    @inlinable
    internal func executeThumbPCLoad(_ instruction: UInt16) -> Int {
        let rd = Int((instruction >> 8) & 0x7)
        let word8 = UInt32(instruction & 0xFF)
        let offset = word8 << 2
        
        // PC is current instruction + 4, aligned to word
        let pc = (registers[15] & ~2) + 4
        let address = (pc & ~3) + offset
        
        guard let memory = memory else { return 1 }
        registers[rd] = memory.read32(address: address)
        
        return 3 // Memory access
    }
    
    // MARK: - Format 7: Load/Store with Register Offset
    
    /// Format 7: LDR/STR/LDRB/STRB with register offset
    /// Encoding: 0101[L:1][B:1]0[Ro:3][Rb:3][Rd:3]
    @inlinable
    internal func executeThumbLoadStoreReg(_ instruction: UInt16) -> Int {
        let isLoad = (instruction >> 11) & 0x1 != 0
        let isByte = (instruction >> 10) & 0x1 != 0
        let ro = Int((instruction >> 6) & 0x7)
        let rb = Int((instruction >> 3) & 0x7)
        let rd = Int(instruction & 0x7)
        
        let address = registers[rb] &+ registers[ro]
        guard let memory = memory else { return 1 }
        
        if isLoad {
            if isByte {
                // LDRB - Load byte
                registers[rd] = UInt32(memory.read8(address: address))
            } else {
                // LDR - Load word
                registers[rd] = memory.read32(address: address & ~3)
            }
        } else {
            if isByte {
                // STRB - Store byte
                memory.write8(address: address, value: UInt8(registers[rd] & 0xFF))
            } else {
                // STR - Store word
                memory.write32(address: address & ~3, value: registers[rd])
            }
        }
        
        return 3
    }
    
    // MARK: - Format 8: Load/Store Sign-Extended Byte/Halfword
    
    /// Format 8: STRH, LDSB, LDRH, LDSH with register offset
    /// Encoding: 0101[H:1][S:1]1[Ro:3][Rb:3][Rd:3]
    @inlinable
    internal func executeThumbLoadStoreSigned(_ instruction: UInt16) -> Int {
        let h = (instruction >> 11) & 0x1
        let s = (instruction >> 10) & 0x1
        let ro = Int((instruction >> 6) & 0x7)
        let rb = Int((instruction >> 3) & 0x7)
        let rd = Int(instruction & 0x7)
        
        let address = registers[rb] &+ registers[ro]
        guard let memory = memory else { return 1 }
        
        switch (h, s) {
        case (0, 0): // STRH - Store halfword
            memory.write16(address: address & ~1, value: UInt16(registers[rd] & 0xFFFF))
            
        case (0, 1): // LDSB - Load sign-extended byte
            let byte = memory.read8(address: address)
            registers[rd] = UInt32(bitPattern: Int32(Int8(bitPattern: byte)))
            
        case (1, 0): // LDRH - Load halfword
            let halfword = memory.read16(address: address & ~1)
            registers[rd] = UInt32(halfword)
            
        case (1, 1): // LDSH - Load sign-extended halfword
            let halfword = memory.read16(address: address & ~1)
            registers[rd] = UInt32(bitPattern: Int32(Int16(bitPattern: halfword)))
            
        default:
            break
        }
        
        return 3
    }
    
    // MARK: - Format 7 (continued): Load/Store with Immediate Offset
    
    /// Format 7: LDR/STR/LDRB/STRB with 5-bit immediate offset
    /// Encoding: 011[B:1][L:1][offset5:5][Rb:3][Rd:3]
    @inlinable
    internal func executeThumbLoadStoreImm(_ instruction: UInt16) -> Int {
        let isByte = (instruction >> 12) & 0x1 != 0
        let isLoad = (instruction >> 11) & 0x1 != 0
        let offset5 = UInt32((instruction >> 6) & 0x1F)
        let rb = Int((instruction >> 3) & 0x7)
        let rd = Int(instruction & 0x7)
        
        let offset = isByte ? offset5 : (offset5 << 2)
        let address = registers[rb] &+ offset
        guard let memory = memory else { return 1 }
        
        if isLoad {
            if isByte {
                // LDRB
                registers[rd] = UInt32(memory.read8(address: address))
            } else {
                // LDR
                registers[rd] = memory.read32(address: address & ~3)
            }
        } else {
            if isByte {
                // STRB
                memory.write8(address: address, value: UInt8(registers[rd] & 0xFF))
            } else {
                // STR
                memory.write32(address: address & ~3, value: registers[rd])
            }
        }
        
        return 3
    }
    
    // MARK: - Format 9: Load/Store Halfword
    
    /// Format 9: LDRH/STRH with 5-bit immediate offset
    /// Encoding: 1000[L:1][offset5:5][Rb:3][Rd:3]
    @inlinable
    internal func executeThumbLoadStoreHalf(_ instruction: UInt16) -> Int {
        let isLoad = (instruction >> 11) & 0x1 != 0
        let offset5 = UInt32((instruction >> 6) & 0x1F)
        let rb = Int((instruction >> 3) & 0x7)
        let rd = Int(instruction & 0x7)
        
        let offset = offset5 << 1
        let address = registers[rb] &+ offset
        guard let memory = memory else { return 1 }
        
        if isLoad {
            // LDRH
            let halfword = memory.read16(address: address & ~1)
            registers[rd] = UInt32(halfword)
        } else {
            // STRH
            memory.write16(address: address & ~1, value: UInt16(registers[rd] & 0xFFFF))
        }
        
        return 3
    }
    
    // MARK: - Format 10: SP-Relative Load/Store
    
    /// Format 10: LDR/STR with SP-relative addressing
    /// Encoding: 1001[L:1][Rd:3][word8:8]
    @inlinable
    internal func executeThumbSPLoadStore(_ instruction: UInt16) -> Int {
        let isLoad = (instruction >> 11) & 0x1 != 0
        let rd = Int((instruction >> 8) & 0x7)
        let word8 = UInt32(instruction & 0xFF)
        let offset = word8 << 2
        
        let address = registers[13] &+ offset // SP = R13
        guard let memory = memory else { return 1 }
        
        if isLoad {
            // LDR Rd, [SP, #imm]
            registers[rd] = memory.read32(address: address & ~3)
        } else {
            // STR Rd, [SP, #imm]
            memory.write32(address: address & ~3, value: registers[rd])
        }
        
        return 3
    }
    
    // MARK: - Format 14: Multiple Load/Store
    
    /// Format 14: LDMIA/STMIA (increment after)
    /// Encoding: 1100[L:1][Rb:3][Rlist:8]
    @inlinable
    internal func executeThumbLoadStoreMultiple(_ instruction: UInt16) -> Int {
        let isLoad = (instruction >> 11) & 0x1 != 0
        let rb = Int((instruction >> 8) & 0x7)
        let rlist = instruction & 0xFF
        
        var address = registers[rb]
        guard let memory = memory else { return 1 }
        
        var transferCount = 0
        
        if isLoad {
            // LDMIA Rb!, {Rlist}
            for i in 0..<8 {
                if (rlist & (1 << i)) != 0 {
                    registers[i] = memory.read32(address: address)
                    address &+= 4
                    transferCount += 1
                }
            }
        } else {
            // STMIA Rb!, {Rlist}
            for i in 0..<8 {
                if (rlist & (1 << i)) != 0 {
                    memory.write32(address: address, value: registers[i])
                    address &+= 4
                    transferCount += 1
                }
            }
        }
        
        // Write back to base register
        registers[rb] = address
        
        return 1 + transferCount // Base + 1 cycle per transfer
    }
}

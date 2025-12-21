//
//  ThumbStackBranch.swift
//  Emerald
//
//  Thumb Format 11, 12, 13, 15, 16, 17, 18, 19: Stack operations and branches
//

import Foundation
import os

extension GBAARM7TDMI {
    
    // MARK: - Format 11: Load Address
    
    /// Format 11: ADD Rd, PC/SP, #imm
    /// Encoding: 1010[SP:1][Rd:3][word8:8]
    @inlinable
    internal func executeThumbLoadAddr(_ instruction: UInt16) -> Int {
        let useSP = (instruction >> 11) & 0x1 != 0
        let rd = Int((instruction >> 8) & 0x7)
        let word8 = UInt32(instruction & 0xFF)
        let offset = word8 << 2
        
        if useSP {
            // ADD Rd, SP, #imm
            registers[rd] = registers[13] &+ offset
        } else {
            // ADD Rd, PC, #imm
            let pc = (registers[15] & ~2) + 4
            registers[rd] = (pc & ~3) &+ offset
        }
        
        return 1
    }
    
    // MARK: - Format 12: Add Offset to Stack Pointer
    
    /// Format 12: ADD SP, #imm or SUB SP, #imm
    /// Encoding: 10110000[S:1][sword7:7]
    @inlinable
    internal func executeThumbAddSP(_ instruction: UInt16) -> Int {
        let isNegative = (instruction >> 7) & 0x1 != 0
        let sword7 = UInt32(instruction & 0x7F)
        let offset = sword7 << 2
        
        if isNegative {
            // SUB SP, #imm
            registers[13] = registers[13] &- offset
        } else {
            // ADD SP, #imm
            registers[13] = registers[13] &+ offset
        }
        
        return 1
    }
    
    // MARK: - Format 13: Push/Pop Registers
    
    /// Format 13: PUSH/POP with optional LR/PC
    /// Encoding: 1011[L:1]10[R:1][Rlist:8]
    @inlinable
    internal func executeThumbPushPop(_ instruction: UInt16) -> Int {
        let isLoad = (instruction >> 11) & 0x1 != 0
        let pcLrBit = (instruction >> 8) & 0x1 != 0
        let rlist = instruction & 0xFF
        
        guard let memory = memory else { return 1 }
        var transferCount = 0
        
        if isLoad {
            // POP {Rlist}
            var address = registers[13]
            
            // Pop low registers
            for i in 0..<8 {
                if (rlist & (1 << i)) != 0 {
                    registers[i] = memory.read32(address: address)
                    address &+= 4
                    transferCount += 1
                }
            }
            
            // Pop PC if R bit set
            if pcLrBit {
                registers[15] = memory.read32(address: address) & ~1
                address &+= 4
                transferCount += 1
                flushPipeline()
            }
            
            registers[13] = address
            return pcLrBit ? (2 + transferCount) : (1 + transferCount)
            
        } else {
            // PUSH {Rlist}
            var address = registers[13]
            
            // Calculate total count first
            var count = 0
            for i in 0..<8 {
                if (rlist & (1 << i)) != 0 {
                    count += 1
                }
            }
            if pcLrBit { count += 1 }
            
            // Decrement SP
            address = address &- UInt32(count * 4)
            registers[13] = address
            
            // Push low registers
            for i in 0..<8 {
                if (rlist & (1 << i)) != 0 {
                    memory.write32(address: address, value: registers[i])
                    address &+= 4
                    transferCount += 1
                }
            }
            
            // Push LR if R bit set
            if pcLrBit {
                memory.write32(address: address, value: registers[14])
                transferCount += 1
            }
            
            return 1 + transferCount
        }
    }
    
    // MARK: - Format 15: Conditional Branch
    
    /// Format 15: B<cond> label
    /// Encoding: 1101[cond:4][soffset8:8]
    @inlinable
    internal func executeThumbConditionalBranch(_ instruction: UInt16) -> Int {
        let condition = UInt32((instruction >> 8) & 0xF)
        let soffset8 = Int8(bitPattern: UInt8(instruction & 0xFF))
        
        let conditionMet = checkCondition(condition)
        
        // Disabled logging for performance
        // if instructionCount < 50 {
        //     let offset = Int32(soffset8) << 1
        //     let pc = registers[15]
        //     logger.debug("🔀 Branch: cond=\(condition), offset=\(offset), PC=0x\(String(format: "%08X", pc)), taken=\(conditionMet), target=0x\(String(format: "%08X", UInt32(Int32(pc) + offset)))")
        // }
        
        if conditionMet {
            let offset = Int32(soffset8) << 1
            let pc = registers[15]
            // PC is already at instruction+4, offset is from (instruction+4)
            registers[15] = UInt32(Int32(pc) + offset)
            flushPipeline()
            return 3
        }
        
        return 1
    }
    
    // MARK: - Format 17: Software Interrupt
    
    /// Format 17: SWI #imm8
    /// Encoding: 11011111[value8:8]
    @inlinable
    internal func executeThumbSWI(_ instruction: UInt16) -> Int {
        // In Thumb mode: SWI number is in bits [7:0]
        let swiNumber = UInt8(instruction & 0xFF)

        // Use BIOS HLE if available
        if let bios = self.bios {
            logger.debug("Thumb SWI 0x\(String(format: "%02X", swiNumber)) - Using BIOS HLE")
            return bios.handleSWI(swiNumber)
        }

        // Fallback: Old behavior (jump to BIOS at 0x00000008)
        logger.warning("⚠️ BIOS HLE not available! SWI 0x\(String(format: "%02X", swiNumber)) called but BIOS is nil")

        savedPSR[.supervisor] = cpsr
        cpsr = (cpsr & ~0x1F) | 0x13 // Supervisor mode
        cpsr |= 0x80 // Disable IRQ
        registers[14] = registers[15] - 2 // Thumb instruction is 2 bytes
        registers[15] = 0x00000008
        cpsr &= ~0x20 // Clear Thumb bit
        flushPipeline()

        return 3
    }
    
    // MARK: - Format 18: Unconditional Branch
    
    /// Format 18: B label (unconditional)
    /// Encoding: 11100[offset11:11]
    @inlinable
    internal func executeThumbBranch(_ instruction: UInt16) -> Int {
        let offset11 = instruction & 0x7FF
        
        // Sign extend 11-bit offset to 32-bit
        let signExtended: Int32
        if (offset11 & 0x400) != 0 {
            // Negative - extend with 1s
            signExtended = Int32(bitPattern: UInt32(offset11) | 0xFFFFF800)
        } else {
            // Positive
            signExtended = Int32(offset11)
        }
        
        let offset = signExtended << 1
        let pc = registers[15]
        // PC is already at instruction+4, offset is from (instruction+4)
        registers[15] = UInt32(Int32(pc) + offset)
        
        flushPipeline()
        return 3
    }
    
    // MARK: - Format 19: Long Branch with Link
    
    /// Format 19: BL label (two-instruction sequence)
    /// First instruction:  11110[offset_hi:11]
    /// Second instruction: 11111[offset_lo:11]
    @inlinable
    internal func executeThumbLongBranch(_ instruction: UInt16) -> Int {
        let h = (instruction >> 11) & 0x1
        let offset11 = instruction & 0x7FF
        
        if h == 0 {
            // First instruction: BL prefix
            // Sign extend upper 11 bits to 32 bits and shift left 12
            let signExtended: Int32
            if (offset11 & 0x400) != 0 {
                signExtended = Int32(bitPattern: UInt32(offset11) | 0xFFFFF800)
            } else {
                signExtended = Int32(offset11)
            }
            
            let pc = registers[15]
            let offset = signExtended << 12
            registers[14] = UInt32(Int32(pc) + offset + 4)
            
            return 1
            
        } else {
            // Second instruction: BL suffix
            let temp = registers[15]
            registers[15] = (registers[14] &+ (UInt32(offset11) << 1)) & ~1
            registers[14] = (temp - 2) | 1 // Return address with Thumb bit
            
            flushPipeline()
            return 3
        }
    }
}

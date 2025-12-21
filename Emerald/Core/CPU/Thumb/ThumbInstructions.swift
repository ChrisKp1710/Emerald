//
//  ThumbInstructions.swift
//  Emerald
//
//  Created on 28/10/2025.
//  Copyright © 2025 Christian Koscielniakpinto. All rights reserved.
//

import Foundation
import OSLog

/// Extension containing all Thumb instruction execution methods
extension GBAARM7TDMI {
    
    // MARK: - Main Thumb Instruction Dispatcher
    
    @inlinable
    internal func executeThumbInstruction(_ instruction: UInt16) -> Int {
        // Log first 50 Thumb executions
        if self.instructionCount < 50 {
            logger.debug("🎯 Execute[Thumb]: Instr=0x\(String(format: "%04X", instruction)), PC=0x\(String(format: "%08X", self.registers[15])), Count=\(self.instructionCount)")
        }
        
        // Decode based on bits [15:13] for major categories
        let majorOpcode = (instruction >> 13) & 0x7
        
        switch majorOpcode {
        case 0, 1: // Format 1, 2: Shift operations, Add/subtract
            return decodeThumbFormat1and2(instruction)
        case 2: // Format 3: Move/compare/add/subtract immediate
            return executeThumbImmediate(instruction)
        case 3: // Format 4, 5: ALU ops, Hi register ops
            return decodeThumbFormat4and5(instruction)
        case 4: // Format 6, 7, 8: PC-relative load, Load/store
            return decodeThumbFormat6to8(instruction)
        case 5: // Format 9, 10: Load/store halfword, SP-relative
            return decodeThumbFormat9and10(instruction)
        case 6: // Format 11, 12, 13: Load address, Add offset to SP, Push/pop
            return decodeThumbFormat11to13(instruction)
        case 7: // Format 14, 15, 16, 17, 18, 19: Multiple load/store, conditional branch, SWI, branch
            return decodeThumbFormat14to19(instruction)
        default:
            logger.warning("Unknown Thumb instruction: \(String(format: "%04X", instruction))")
            return 1
        }
    }
    
    // MARK: - Format Decoders
    
    private func decodeThumbFormat1and2(_ instruction: UInt16) -> Int {
        let bit11_10 = (instruction >> 11) & 0x3
        
        if bit11_10 <= 2 {
            // Format 1: Move shifted register (LSL, LSR, ASR)
            return executeThumbShift(instruction)
        } else {
            // Format 2: Add/subtract
            return executeThumbAddSubtract(instruction)
        }
    }
    
    private func decodeThumbFormat4and5(_ instruction: UInt16) -> Int {
        let bit12 = (instruction >> 12) & 0x1
        
        if bit12 == 0 {
            let bit11_10 = (instruction >> 10) & 0x3
            
            if bit11_10 == 0 {
                // Format 4: ALU operations
                return executeThumbALU(instruction)
            } else {
                // Format 5: Hi register operations/branch exchange
                return executeThumbHiReg(instruction)
            }
        } else {
            // Format 6: PC-relative load
            return executeThumbPCLoad(instruction)
        }
    }
    
    private func decodeThumbFormat6to8(_ instruction: UInt16) -> Int {
        let bit12 = (instruction >> 12) & 0x1
        
        if bit12 == 0 {
            // Format 7: Load/store with register offset
            return executeThumbLoadStoreReg(instruction)
        } else {
            let bit11_10 = (instruction >> 10) & 0x3
            
            if bit11_10 == 0 || bit11_10 == 1 {
                // Format 8: Load/store sign-extended byte/halfword
                return executeThumbLoadStoreSigned(instruction)
            } else {
                // Format 7 continued: Load/store with immediate offset
                return executeThumbLoadStoreImm(instruction)
            }
        }
    }
    
    private func decodeThumbFormat9and10(_ instruction: UInt16) -> Int {
        let bit12 = (instruction >> 12) & 0x1
        
        if bit12 == 0 {
            // Format 9: Load/store halfword
            return executeThumbLoadStoreHalf(instruction)
        } else {
            // Format 10: SP-relative load/store
            return executeThumbSPLoadStore(instruction)
        }
    }
    
    private func decodeThumbFormat11to13(_ instruction: UInt16) -> Int {
        let bit12 = (instruction >> 12) & 0x1
        
        if bit12 == 0 {
            // Format 11: Load address
            return executeThumbLoadAddr(instruction)
        } else {
            let bit11_10 = (instruction >> 10) & 0x3
            
            if bit11_10 == 0 {
                // Format 12: Add offset to stack pointer
                return executeThumbAddSP(instruction)
            } else {
                // Format 13: Push/pop registers
                return executeThumbPushPop(instruction)
            }
        }
    }
    
    private func decodeThumbFormat14to19(_ instruction: UInt16) -> Int {
        let bit12_8 = (instruction >> 8) & 0x1F
        
        if bit12_8 < 16 {
            // Format 14: Multiple load/store
            return executeThumbLoadStoreMultiple(instruction)
        } else if bit12_8 == 0x1F {
            // Format 17: Software interrupt
            return executeThumbSWI(instruction)
        } else if bit12_8 < 0x1C {
            // Format 15: Conditional branch
            return executeThumbConditionalBranch(instruction)
        } else if bit12_8 == 0x1C {
            // Format 18: Unconditional branch
            return executeThumbBranch(instruction)
        } else {
            // Format 19: Long branch with link
            return executeThumbLongBranch(instruction)
        }
    }
}

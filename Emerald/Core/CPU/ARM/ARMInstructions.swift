//
//  ARMInstructions.swift
//  Emerald
//
//  ARM7TDMI ARM Instruction Set Implementation
//

import Foundation
import os

extension GBAARM7TDMI {
    
    // MARK: - ARM Instruction Execution
    
    internal func executeARMInstruction(_ instruction: UInt32) -> Int {
        // Check for multiply instructions
        if (instruction & 0x0FC000F0) == 0x00000090 {
            return executeMultiply(instruction)
        }
        
        // Check for multiply long instructions
        if (instruction & 0x0F8000F0) == 0x00800090 {
            return executeMultiplyLong(instruction)
        }
        
        // Check for halfword/signed data transfer
        if (instruction & 0x0E000090) == 0x00000090 {
            return executeHalfwordTransfer(instruction)
        }
        
        // Check for single data swap
        if (instruction & 0x0FB00FF0) == 0x01000090 {
            return executeSingleDataSwap(instruction)
        }
        
        // Check for PSR Transfer (MRS)
        if (instruction & 0x0FBF0FFF) == 0x010F0000 {
            return executeMRS(instruction)
        }
        
        // Check for PSR Transfer (MSR)
        if (instruction & 0x0FB00000) == 0x03200000 || (instruction & 0x0DB00000) == 0x01200000 {
            return executeMSR(instruction)
        }
        
        // Check for branch and exchange
        if (instruction & 0x0FFFFFF0) == 0x012FFF10 {
            let rm = Int(instruction & 0xF)
            let address = registers[rm]
            
            if address & 1 != 0 {
                cpsr |= 0x20
                instructionSet = .thumb
            }
            
            registers[15] = address & 0xFFFFFFFE
            flushPipeline()
            return 3
        }
        
        let category = (instruction >> 26) & 0x3
        
        switch category {
        case 0:
            // Data processing or PSR transfer
            if (instruction & 0x01900000) == 0x01000000 {
                // PSR transfer handled above
                return 1
            }
            return executeDataProcessing(instruction)
            
        case 1:
            // Single data transfer
            return executeLoadStore(instruction)
            
        case 2:
            // Block data transfer or branch
            if (instruction & 0x02000000) == 0 {
                return executeLoadStoreMultiple(instruction)
            } else {
                return executeBranch(instruction)
            }
            
        case 3:
            // Software interrupt
            return executeSWI(instruction)
            
        default:
            logger.warning("Unknown ARM instruction: \(String(format: "%08X", instruction))")
            return 1
        }
    }
    
    // MARK: - Data Processing Instructions
    
    private func executeDataProcessing(_ instruction: UInt32) -> Int {
        let opcode = (instruction >> 21) & 0xF
        let s = (instruction >> 20) & 1 != 0
        let rd = Int((instruction >> 12) & 0xF)
        let rn = Int((instruction >> 16) & 0xF)
        let rm = Int(instruction & 0xF)
        let i = (instruction >> 25) & 1 != 0
        
        var operand2: UInt32
        var cycles = 1
        
        // Calculate operand2
        if i {
            // Immediate value
            let immediate = instruction & 0xFF
            let rotate = ((instruction >> 8) & 0xF) * 2
            operand2 = rotateRight(immediate, by: Int(rotate))
        } else {
            // Register value
            operand2 = registers[rm]
            
            // Apply shift if needed
            let shiftType = (instruction >> 5) & 0x3
            let shiftAmount = (instruction >> 7) & 0x1F
            
            operand2 = applyShift(operand2, type: Int(shiftType), amount: Int(shiftAmount))
            
            if shiftAmount != 0 {
                cycles += 1
            }
        }
        
        let rnValue = registers[rn]
        var result: UInt32 = 0
        
        // Execute operation
        switch opcode {
        case 0: // AND
            result = rnValue & operand2
        case 1: // EOR
            result = rnValue ^ operand2
        case 2: // SUB
            result = rnValue &- operand2
        case 3: // RSB
            result = operand2 &- rnValue
        case 4: // ADD
            result = rnValue &+ operand2
        case 5: // ADC
            let carry: UInt32 = (cpsr & 0x20000000) != 0 ? 1 : 0
            result = rnValue &+ operand2 &+ carry
        case 6: // SBC
            let carry: UInt32 = (cpsr & 0x20000000) != 0 ? 0 : 1
            result = rnValue &- operand2 &- carry
        case 7: // RSC
            let carry: UInt32 = (cpsr & 0x20000000) != 0 ? 0 : 1
            result = operand2 &- rnValue &- carry
        case 8: // TST
            result = rnValue & operand2
        case 9: // TEQ
            result = rnValue ^ operand2
        case 10: // CMP
            result = rnValue &- operand2
        case 11: // CMN
            result = rnValue &+ operand2
        case 12: // ORR
            result = rnValue | operand2
        case 13: // MOV
            result = operand2
        case 14: // BIC
            result = rnValue & (~operand2)
        case 15: // MVN
            result = ~operand2
        default:
            break
        }
        
        // Update destination register (except for comparison operations)
        if opcode < 8 || opcode > 11 {
            registers[rd] = result
            
            // Handle PC writes
            if rd == 15 {
                flushPipeline()
                cycles += 2
            }
        }
        
        // Update flags if S bit is set
        if s {
            updateFlags(result: result, operation: Int(opcode))
        }
        
        return cycles
    }
    
    // MARK: - Multiply Instructions
    
    /// Execute MUL and MLA instructions
    /// Optimized for both Apple Silicon and Intel architectures
    @inlinable
    internal func executeMultiply(_ instruction: UInt32) -> Int {
        let a = (instruction >> 21) & 1 != 0  // Accumulate
        let s = (instruction >> 20) & 1 != 0  // Set flags
        let rd = Int((instruction >> 16) & 0xF)
        let rn = Int((instruction >> 12) & 0xF)
        let rs = Int((instruction >> 8) & 0xF)
        let rm = Int(instruction & 0xF)
        
        // Get operands
        let op1 = registers[rm]
        let op2 = registers[rs]
        
        // Perform multiplication
        var result = op1.multipliedReportingOverflow(by: op2).partialValue
        
        // Add accumulate if MLA
        if a {
            let acc = registers[rn]
            result = result.addingReportingOverflow(acc).partialValue
        }
        
        // Write result
        registers[rd] = result
        
        // Update flags if S bit set
        if s {
            // N flag: bit 31 of result
            let n: UInt32 = (result >> 31) & 1
            // Z flag: result is zero
            let z: UInt32 = result == 0 ? 1 : 0
            // C flag: meaningless (unchanged)
            // V flag: meaningless (unchanged)
            
            cpsr = (cpsr & 0x0FFFFFFF) | (n << 31) | (z << 30)
        }
        
        // Timing: 1S + mI where m = 1-4 depending on operand values
        // Simplified to 2-4 cycles
        let cycles = a ? 3 : 2
        return cycles
    }
    
    /// Execute long multiply instructions (UMULL, UMLAL, SMULL, SMLAL)
    /// Uses 64-bit arithmetic for maximum performance on modern CPUs
    @inlinable
    internal func executeMultiplyLong(_ instruction: UInt32) -> Int {
        let u = (instruction >> 22) & 1 != 0  // Unsigned
        let a = (instruction >> 21) & 1 != 0  // Accumulate
        let s = (instruction >> 20) & 1 != 0  // Set flags
        let rdHi = Int((instruction >> 16) & 0xF)
        let rdLo = Int((instruction >> 12) & 0xF)
        let rs = Int((instruction >> 8) & 0xF)
        let rm = Int(instruction & 0xF)
        
        let op1 = registers[rm]
        let op2 = registers[rs]
        
        var result64: UInt64
        
        if u {
            // Unsigned multiply
            result64 = UInt64(op1) * UInt64(op2)
            
            // Add accumulate if UMLAL
            if a {
                let accHi = UInt64(registers[rdHi])
                let accLo = UInt64(registers[rdLo])
                let acc64 = (accHi << 32) | accLo
                result64 = result64.addingReportingOverflow(acc64).partialValue
            }
        } else {
            // Signed multiply
            let signed1 = Int64(Int32(bitPattern: op1))
            let signed2 = Int64(Int32(bitPattern: op2))
            let signedResult = signed1 * signed2
            result64 = UInt64(bitPattern: signedResult)
            
            // Add accumulate if SMLAL
            if a {
                let accHi = UInt64(registers[rdHi])
                let accLo = UInt64(registers[rdLo])
                let acc64 = (accHi << 32) | accLo
                let signedAcc = Int64(bitPattern: acc64)
                let finalResult = signedResult + signedAcc
                result64 = UInt64(bitPattern: finalResult)
            }
        }
        
        // Split 64-bit result into two 32-bit registers
        registers[rdLo] = UInt32(result64 & 0xFFFFFFFF)
        registers[rdHi] = UInt32(result64 >> 32)
        
        // Update flags if S bit set
        if s {
            // N flag: bit 63 of result
            let n: UInt32 = UInt32((result64 >> 63) & 1)
            // Z flag: result is zero
            let z: UInt32 = result64 == 0 ? 1 : 0
            // C flag: meaningless (unchanged)
            // V flag: meaningless (unchanged)
            
            cpsr = (cpsr & 0x0FFFFFFF) | (n << 31) | (z << 30)
        }
        
        // Timing: 1S + (m+1)I where m = 1-4
        // Simplified to 3-5 cycles
        let cycles = a ? 5 : 4
        return cycles
    }
    
    // MARK: - Helper Functions
    
    private func rotateRight(_ value: UInt32, by amount: Int) -> UInt32 {
        guard amount > 0 else { return value }
        let effectiveAmount = amount % 32
        return (value >> effectiveAmount) | (value << (32 - effectiveAmount))
    }
    
    private func applyShift(_ value: UInt32, type: Int, amount: Int) -> UInt32 {
        return applyShift(value: value, shiftType: UInt32(type), amount: UInt32(amount), updateCarry: false)
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

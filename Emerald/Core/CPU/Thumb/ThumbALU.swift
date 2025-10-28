//
//  ThumbALU.swift
//  Emerald
//
//  Thumb Format 4, 5: ALU operations and Hi register operations
//

import Foundation

extension GBAARM7TDMI {
    
    // MARK: - Format 4: ALU Operations
    
    /// Format 4: ALU operations between two low registers
    /// Encoding: 010000[op:4][Rs:3][Rd:3]
    @inlinable
    internal func executeThumbALU(_ instruction: UInt16) -> Int {
        let op = (instruction >> 6) & 0xF
        let rs = Int((instruction >> 3) & 0x7)
        let rd = Int(instruction & 0x7)
        
        let operand1 = registers[rd]
        let operand2 = registers[rs]
        var result: UInt32
        var updateFlags = true
        var cycles = 1
        
        switch op {
        case 0x0: // AND Rd, Rs
            result = operand1 & operand2
            
        case 0x1: // EOR Rd, Rs
            result = operand1 ^ operand2
            
        case 0x2: // LSL Rd, Rs
            let shift = operand2 & 0xFF
            if shift >= 32 {
                result = 0
            } else if shift > 0 {
                result = operand1 << shift
            } else {
                result = operand1
            }
            cycles = 1 + Int(shift) // Variable timing
            
        case 0x3: // LSR Rd, Rs
            let shift = operand2 & 0xFF
            if shift >= 32 {
                result = 0
            } else if shift > 0 {
                result = operand1 >> shift
            } else {
                result = operand1
            }
            cycles = 1 + Int(shift)
            
        case 0x4: // ASR Rd, Rs
            let shift = operand2 & 0xFF
            let signedValue = Int32(bitPattern: operand1)
            if shift >= 32 {
                result = signedValue < 0 ? 0xFFFFFFFF : 0
            } else if shift > 0 {
                result = UInt32(bitPattern: signedValue >> Int32(shift))
            } else {
                result = operand1
            }
            cycles = 1 + Int(shift)
            
        case 0x5: // ADC Rd, Rs - Add with carry
            let carry: UInt32 = (cpsr & 0x20000000) != 0 ? 1 : 0
            let (res1, carry1) = operand1.addingReportingOverflow(operand2)
            let (res2, carry2) = res1.addingReportingOverflow(carry)
            result = res2
            
            // Update carry and overflow flags
            let finalCarry = carry1 || carry2
            cpsr = (cpsr & ~0x30000000) |
                   (finalCarry ? 0x20000000 : 0)
            
        case 0x6: // SBC Rd, Rs - Subtract with carry
            let carry: UInt32 = (cpsr & 0x20000000) != 0 ? 1 : 0
            let (res1, borrow1) = operand1.subtractingReportingOverflow(operand2)
            let (res2, borrow2) = res1.subtractingReportingOverflow(1 - carry)
            result = res2
            
            let finalBorrow = borrow1 || borrow2
            cpsr = (cpsr & ~0x20000000) |
                   (finalBorrow ? 0 : 0x20000000)
            
        case 0x7: // ROR Rd, Rs - Rotate right
            let shift = operand2 & 0xFF
            if shift == 0 {
                result = operand1
            } else {
                let actualShift = shift & 0x1F
                result = (operand1 >> actualShift) | (operand1 << (32 - actualShift))
            }
            cycles = 1 + Int(shift & 0xFF)
            
        case 0x8: // TST Rd, Rs - Test bits
            result = operand1 & operand2
            updateFlags = false
            cpsr = (cpsr & ~0xC0000000) |
                   (result & 0x80000000) |          // N flag
                   (result == 0 ? 0x40000000 : 0)   // Z flag
            
        case 0x9: // NEG Rd, Rs - Negate
            result = 0 &- operand2
            
        case 0xA: // CMP Rd, Rs - Compare
            let (res, borrow) = operand1.subtractingReportingOverflow(operand2)
            result = res
            updateFlags = false
            
            let signedOp1 = Int32(bitPattern: operand1)
            let signedOp2 = Int32(bitPattern: operand2)
            let signedResult = Int32(bitPattern: result)
            let overflow = (signedOp1 < 0 && signedOp2 > 0 && signedResult > 0) ||
                          (signedOp1 > 0 && signedOp2 < 0 && signedResult < 0)
            
            cpsr = (cpsr & ~0xF0000000) |
                   (result & 0x80000000) |          // N flag
                   (result == 0 ? 0x40000000 : 0) | // Z flag
                   (!borrow ? 0x20000000 : 0) |     // C flag
                   (overflow ? 0x10000000 : 0)      // V flag
            
        case 0xB: // CMN Rd, Rs - Compare negative
            let (res, carry_out) = operand1.addingReportingOverflow(operand2)
            result = res
            updateFlags = false
            
            let signedOp1 = Int32(bitPattern: operand1)
            let signedOp2 = Int32(bitPattern: operand2)
            let signedResult = Int32(bitPattern: result)
            let overflow = (signedOp1 > 0 && signedOp2 > 0 && signedResult < 0) ||
                          (signedOp1 < 0 && signedOp2 < 0 && signedResult > 0)
            
            cpsr = (cpsr & ~0xF0000000) |
                   (result & 0x80000000) |          // N flag
                   (result == 0 ? 0x40000000 : 0) | // Z flag
                   (carry_out ? 0x20000000 : 0) |   // C flag
                   (overflow ? 0x10000000 : 0)      // V flag
            
        case 0xC: // ORR Rd, Rs
            result = operand1 | operand2
            
        case 0xD: // MUL Rd, Rs - Multiply
            result = operand1 &* operand2
            cycles = calculateMultiplyCycles(operand2)
            
        case 0xE: // BIC Rd, Rs - Bit clear
            result = operand1 & ~operand2
            
        case 0xF: // MVN Rd, Rs - Move NOT
            result = ~operand2
            
        default:
            result = operand1
        }
        
        registers[rd] = result
        
        if updateFlags {
            cpsr = (cpsr & ~0xC0000000) |
                   (result & 0x80000000) |          // N flag
                   (result == 0 ? 0x40000000 : 0)   // Z flag
        }
        
        return cycles
    }
    
    // MARK: - Format 5: Hi Register Operations / Branch Exchange
    
    /// Format 5: Operations with Hi registers (R8-R15) and BX
    /// Encoding: 010001[op:2][H1:1][H2:1][Rs/Hs:3][Rd/Hd:3]
    @inlinable
    internal func executeThumbHiReg(_ instruction: UInt16) -> Int {
        let op = (instruction >> 8) & 0x3
        let h1 = (instruction >> 7) & 0x1
        let h2 = (instruction >> 6) & 0x1
        let rsHs = Int((instruction >> 3) & 0x7) + Int(h2) * 8
        let rdHd = Int(instruction & 0x7) + Int(h1) * 8
        
        switch op {
        case 0: // ADD Rd, Hs or ADD Hd, Rs
            registers[rdHd] = registers[rdHd] &+ registers[rsHs]
            if rdHd == 15 {
                registers[15] &= ~1 // Clear Thumb bit
                flushPipeline()
                return 3
            }
            return 1
            
        case 1: // CMP Rd, Hs or CMP Hd, Rs
            let operand1 = registers[rdHd]
            let operand2 = registers[rsHs]
            let (result, borrow) = operand1.subtractingReportingOverflow(operand2)
            
            let signedOp1 = Int32(bitPattern: operand1)
            let signedOp2 = Int32(bitPattern: operand2)
            let signedResult = Int32(bitPattern: result)
            let overflow = (signedOp1 < 0 && signedOp2 > 0 && signedResult > 0) ||
                          (signedOp1 > 0 && signedOp2 < 0 && signedResult < 0)
            
            cpsr = (cpsr & ~0xF0000000) |
                   (result & 0x80000000) |          // N flag
                   (result == 0 ? 0x40000000 : 0) | // Z flag
                   (!borrow ? 0x20000000 : 0) |     // C flag
                   (overflow ? 0x10000000 : 0)      // V flag
            return 1
            
        case 2: // MOV Rd, Hs or MOV Hd, Rs
            registers[rdHd] = registers[rsHs]
            if rdHd == 15 {
                registers[15] &= ~1
                flushPipeline()
                return 3
            }
            return 1
            
        case 3: // BX Rs or BX Hs - Branch and exchange
            let targetAddr = registers[rsHs]
            
            if (targetAddr & 1) == 0 {
                // Switch to ARM mode
                cpsr &= ~0x20  // Clear Thumb bit
                registers[15] = targetAddr & ~3
            } else {
                // Stay in Thumb mode
                registers[15] = targetAddr & ~1
            }
            
            flushPipeline()
            return 3
            
        default:
            return 1
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateMultiplyCycles(_ value: UInt32) -> Int {
        // Simplified cycle calculation for MUL
        if value & 0xFFFFFF00 == 0 || value & 0xFFFFFF00 == 0xFFFFFF00 {
            return 1
        } else if value & 0xFFFF0000 == 0 || value & 0xFFFF0000 == 0xFFFF0000 {
            return 2
        } else if value & 0xFF000000 == 0 || value & 0xFF000000 == 0xFF000000 {
            return 3
        } else {
            return 4
        }
    }
}

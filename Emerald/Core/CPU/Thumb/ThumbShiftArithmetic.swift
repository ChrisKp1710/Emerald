//
//  ThumbShiftArithmetic.swift
//  Emerald
//
//  Thumb Format 1, 2, 3: Shift operations and immediate arithmetic
//

import Foundation

extension GBAARM7TDMI {
    
    // MARK: - Format 1: Move Shifted Register
    
    /// Format 1: LSL, LSR, ASR with 5-bit immediate
    /// Encoding: 000[op:2][offset5:5][Rs:3][Rd:3]
    @inlinable
    internal func executeThumbShift(_ instruction: UInt16) -> Int {
        let op = (instruction >> 11) & 0x3
        let offset5 = UInt32((instruction >> 6) & 0x1F)
        let rs = Int((instruction >> 3) & 0x7)
        let rd = Int(instruction & 0x7)
        
        let value = registers[rs]
        var result: UInt32
        var carry: Bool = (cpsr & (1 << 29)) != 0
        
        switch op {
        case 0: // LSL - Logical Shift Left
            if offset5 == 0 {
                result = value
            } else {
                carry = (value & (1 << (32 - offset5))) != 0
                result = value << offset5
            }
            
        case 1: // LSR - Logical Shift Right
            if offset5 == 0 {
                carry = (value & 0x80000000) != 0
                result = 0
            } else {
                carry = (value & (1 << (offset5 - 1))) != 0
                result = value >> offset5
            }
            
        case 2: // ASR - Arithmetic Shift Right
            let signedValue = Int32(bitPattern: value)
            if offset5 == 0 {
                carry = signedValue < 0
                result = signedValue < 0 ? 0xFFFFFFFF : 0
            } else {
                carry = (value & (1 << (offset5 - 1))) != 0
                result = UInt32(bitPattern: signedValue >> Int32(offset5))
            }
            
        default:
            result = value
        }
        
        registers[rd] = result
        
        // Update flags
        cpsr = (cpsr & ~0xF0000000) |
               (result & 0x80000000) |          // N flag
               (result == 0 ? 0x40000000 : 0) | // Z flag
               (carry ? 0x20000000 : 0)         // C flag
        
        return 1
    }
    
    // MARK: - Format 2: Add/Subtract
    
    /// Format 2: ADD/SUB with register or 3-bit immediate
    /// Encoding: 00011[I][op][Rn/offset3:3][Rs:3][Rd:3]
    @inlinable
    internal func executeThumbAddSubtract(_ instruction: UInt16) -> Int {
        let isImmediate = (instruction >> 10) & 0x1 != 0
        let isSubtract = (instruction >> 9) & 0x1 != 0
        let rnOrOffset = Int((instruction >> 6) & 0x7)
        let rs = Int((instruction >> 3) & 0x7)
        let rd = Int(instruction & 0x7)
        
        let operand1 = registers[rs]
        let operand2: UInt32 = isImmediate ? UInt32(rnOrOffset) : registers[rnOrOffset]
        
        let result: UInt32
        var carry: Bool
        var overflow: Bool
        
        if isSubtract {
            // SUB operation
            let (res, borrow) = operand1.subtractingReportingOverflow(operand2)
            result = res
            carry = !borrow
            
            // Check signed overflow
            let signedOp1 = Int32(bitPattern: operand1)
            let signedOp2 = Int32(bitPattern: operand2)
            let signedResult = Int32(bitPattern: result)
            overflow = (signedOp1 < 0 && signedOp2 > 0 && signedResult > 0) ||
                      (signedOp1 > 0 && signedOp2 < 0 && signedResult < 0)
        } else {
            // ADD operation
            let (res, carry_out) = operand1.addingReportingOverflow(operand2)
            result = res
            carry = carry_out
            
            // Check signed overflow
            let signedOp1 = Int32(bitPattern: operand1)
            let signedOp2 = Int32(bitPattern: operand2)
            let signedResult = Int32(bitPattern: result)
            overflow = (signedOp1 > 0 && signedOp2 > 0 && signedResult < 0) ||
                      (signedOp1 < 0 && signedOp2 < 0 && signedResult > 0)
        }
        
        registers[rd] = result
        
        // Update all flags
        cpsr = (cpsr & ~0xF0000000) |
               (result & 0x80000000) |          // N flag
               (result == 0 ? 0x40000000 : 0) | // Z flag
               (carry ? 0x20000000 : 0) |       // C flag
               (overflow ? 0x10000000 : 0)      // V flag
        
        return 1
    }
    
    // MARK: - Format 3: Move/Compare/Add/Subtract Immediate
    
    /// Format 3: MOV, CMP, ADD, SUB with 8-bit immediate
    /// Encoding: 001[op:2][Rd:3][offset8:8]
    @inlinable
    internal func executeThumbImmediate(_ instruction: UInt16) -> Int {
        let op = (instruction >> 11) & 0x3
        let rd = Int((instruction >> 8) & 0x7)
        let offset8 = UInt32(instruction & 0xFF)
        
        let operand1 = registers[rd]
        var result: UInt32
        var updateRd = true
        var carry: Bool = false
        var overflow: Bool = false
        
        switch op {
        case 0: // MOV Rd, #offset8
            result = offset8
            
        case 1: // CMP Rd, #offset8
            let (res, borrow) = operand1.subtractingReportingOverflow(offset8)
            result = res
            carry = !borrow
            updateRd = false
            
            // Check signed overflow
            let signedOp1 = Int32(bitPattern: operand1)
            let signedOp2 = Int32(bitPattern: offset8)
            let signedResult = Int32(bitPattern: result)
            overflow = (signedOp1 < 0 && signedOp2 > 0 && signedResult > 0) ||
                      (signedOp1 > 0 && signedOp2 < 0 && signedResult < 0)
            
        case 2: // ADD Rd, #offset8
            let (res, carry_out) = operand1.addingReportingOverflow(offset8)
            result = res
            carry = carry_out
            
            // Check signed overflow
            let signedOp1 = Int32(bitPattern: operand1)
            let signedOp2 = Int32(bitPattern: offset8)
            let signedResult = Int32(bitPattern: result)
            overflow = (signedOp1 > 0 && signedOp2 > 0 && signedResult < 0) ||
                      (signedOp1 < 0 && signedOp2 < 0 && signedResult > 0)
            
        case 3: // SUB Rd, #offset8
            let (res, borrow) = operand1.subtractingReportingOverflow(offset8)
            result = res
            carry = !borrow
            
            // Check signed overflow
            let signedOp1 = Int32(bitPattern: operand1)
            let signedOp2 = Int32(bitPattern: offset8)
            let signedResult = Int32(bitPattern: result)
            overflow = (signedOp1 < 0 && signedOp2 > 0 && signedResult > 0) ||
                      (signedOp1 > 0 && signedOp2 < 0 && signedResult < 0)
            
        default:
            result = 0
        }
        
        if updateRd {
            registers[rd] = result
        }
        
        // Update flags
        cpsr = (cpsr & ~0xF0000000) |
               (result & 0x80000000) |          // N flag
               (result == 0 ? 0x40000000 : 0) | // Z flag
               (carry ? 0x20000000 : 0) |       // C flag (for CMP, ADD, SUB)
               (overflow ? 0x10000000 : 0)      // V flag (for CMP, ADD, SUB)
        
        return 1
    }
}

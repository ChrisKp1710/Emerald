//
//  ARMHelpers.swift
//  Emerald
//
//  ARM7TDMI Helper Methods
//

import Foundation
import os

extension GBAARM7TDMI {
    
    // MARK: - Condition Check
    
    internal func checkCondition(_ condition: UInt32) -> Bool {
        let n = (cpsr >> 31) & 1 != 0  // Negative
        let z = (cpsr >> 30) & 1 != 0  // Zero
        let c = (cpsr >> 29) & 1 != 0  // Carry
        let v = (cpsr >> 28) & 1 != 0  // Overflow
        
        switch condition {
        case 0x0: return z                           // EQ - Equal
        case 0x1: return !z                          // NE - Not equal
        case 0x2: return c                           // CS/HS - Carry set
        case 0x3: return !c                          // CC/LO - Carry clear
        case 0x4: return n                           // MI - Minus/negative
        case 0x5: return !n                          // PL - Plus/positive or zero
        case 0x6: return v                           // VS - Overflow
        case 0x7: return !v                          // VC - No overflow
        case 0x8: return c && !z                     // HI - Unsigned higher
        case 0x9: return !c || z                     // LS - Unsigned lower or same
        case 0xA: return n == v                      // GE - Signed greater than or equal
        case 0xB: return n != v                      // LT - Signed less than
        case 0xC: return !z && (n == v)              // GT - Signed greater than
        case 0xD: return z || (n != v)               // LE - Signed less than or equal
        case 0xE: return true                        // AL - Always
        case 0xF: return true                        // NV - Never (treated as always in ARM7TDMI)
        default: return false
        }
    }
    
    // MARK: - Shift Operations
    
    internal func applyShift(value: UInt32, shiftType: UInt32, amount: UInt32, updateCarry: Bool = false) -> UInt32 {
        guard amount > 0 else { return value }
        
        var result = value
        var carry: Bool = false
        
        switch shiftType {
        case 0: // LSL - Logical Shift Left
            result = value << amount
            if updateCarry && amount <= 32 {
                carry = (value >> (32 - amount)) & 1 != 0
            }
            
        case 1: // LSR - Logical Shift Right
            result = amount >= 32 ? 0 : value >> amount
            if updateCarry {
                carry = amount <= 32 ? (value >> (amount - 1)) & 1 != 0 : false
            }
            
        case 2: // ASR - Arithmetic Shift Right
            let signBit = Int32(value) < 0
            if amount >= 32 {
                result = signBit ? 0xFFFFFFFF : 0
            } else {
                result = UInt32(Int32(value) >> amount)
            }
            if updateCarry {
                carry = amount <= 32 ? (value >> (amount - 1)) & 1 != 0 : signBit
            }
            
        case 3: // ROR - Rotate Right
            let effectiveAmount = amount & 31
            result = (value >> effectiveAmount) | (value << (32 - effectiveAmount))
            if updateCarry && effectiveAmount > 0 {
                carry = (value >> (effectiveAmount - 1)) & 1 != 0
            }
            
        default:
            break
        }
        
        if updateCarry {
            if carry {
                cpsr |= (1 << 29)  // Set C flag
            } else {
                cpsr &= ~(1 << 29)  // Clear C flag
            }
        }
        
        return result
    }
    
    // MARK: - Flag Updates
    
    internal func updateFlags(result: UInt32, operation: UInt32, operand1: UInt32? = nil, operand2: UInt32? = nil) {
        // Update N flag (bit 31)
        if result & 0x80000000 != 0 {
            cpsr |= (1 << 31)
        } else {
            cpsr &= ~(1 << 31)
        }
        
        // Update Z flag (bit 30)
        if result == 0 {
            cpsr |= (1 << 30)
        } else {
            cpsr &= ~(1 << 30)
        }
        
        // Update C and V flags based on operation type
        if let op1 = operand1, let op2 = operand2 {
            switch operation {
            case 0, 4: // AND, ADD
                let carry = UInt64(op1) + UInt64(op2) > 0xFFFFFFFF
                if carry {
                    cpsr |= (1 << 29)
                } else {
                    cpsr &= ~(1 << 29)
                }
                
                let overflow = ((op1 ^ result) & (op2 ^ result) & 0x80000000) != 0
                if overflow {
                    cpsr |= (1 << 28)
                } else {
                    cpsr &= ~(1 << 28)
                }
                
            case 2, 10: // SUB, CMP
                let carry = op1 >= op2
                if carry {
                    cpsr |= (1 << 29)
                } else {
                    cpsr &= ~(1 << 29)
                }
                
                let overflow = ((op1 ^ op2) & (op1 ^ result) & 0x80000000) != 0
                if overflow {
                    cpsr |= (1 << 28)
                } else {
                    cpsr &= ~(1 << 28)
                }
                
            default:
                break
            }
        }
    }
    
    // MARK: - Pipeline Management
    
    internal func flushPipeline() {
        // ARM7TDMI has a 3-stage pipeline
        // When PC is modified, we need to flush and refill
        if cpsr & 0x20 != 0 {
            // Thumb mode: instructions are 2 bytes
            registers[15] = registers[15] + 4
        } else {
            // ARM mode: instructions are 4 bytes
            registers[15] = registers[15] + 8
        }
    }
    
    // MARK: - Mode Switching
    
    internal func changeMode(_ newMode: UInt32) {
        let oldMode = cpsr & 0x1F
        guard oldMode != newMode else { return }
        
        // Save current mode's banked registers
        switch oldMode {
        case 0x11: // FIQ
            // FIQ has banked R8-R14
            break
        case 0x12, 0x13, 0x17, 0x1B, 0x1F: // IRQ, SVC, ABT, UND, SYS
            // These modes have banked R13-R14
            break
        default:
            break
        }
        
        // Update mode bits
        cpsr = (cpsr & ~0x1F) | newMode
        
        // Restore new mode's banked registers
        switch newMode {
        case 0x11: // FIQ
            // Restore FIQ's R8-R14
            break
        case 0x12, 0x13, 0x17, 0x1B, 0x1F: // IRQ, SVC, ABT, UND, SYS
            // Restore mode's R13-R14
            break
        default:
            break
        }
    }
    
    // MARK: - Multiply Cycles
    
    internal func getMultiplyCycles(_ value: UInt32) -> Int {
        // ARM7TDMI multiply timing depends on the value
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

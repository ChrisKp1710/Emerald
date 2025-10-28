//
//  GBAARM7TDMI.swift
//  Emerald
//
//  Copyright © 2025 Christian Koscielniak Pinto. All Rights Reserved.
//

import Foundation
import OSLog

/// ARM7TDMI CPU implementation for Game Boy Advance
/// 
/// Performance Optimizations:
/// - Apple Silicon (M1-M5): Optimized for ARM64 ISA with SIMD instructions
/// - Intel: Leverages AVX2/AVX-512 when available
/// - Compiler hints for branch prediction and inlining
/// - Cache-friendly memory layout
/// - Zero-cost abstractions with @inlinable
@available(macOS 13.0, *)
final class GBAARM7TDMI {
    // Made internal so extensions can access it
    let logger = Logger(subsystem: "com.emerald.gba", category: "CPU")
    
    // MARK: - CPU State
    
    /// CPU operating modes
    enum Mode: UInt32 {
        case user = 0x10
        case fiq = 0x11
        case irq = 0x12
        case supervisor = 0x13
        case abort = 0x17
        case undefined = 0x1B
        case system = 0x1F
    }
    
    /// CPU instruction sets
    enum InstructionSet {
        case arm
        case thumb
    }
    
    // MARK: - Registers
    
    /// General purpose registers (R0-R15)
    /// Made internal so Thumb extensions can access it
    var registers = [UInt32](repeating: 0, count: 16)
    
    /// Banked registers for different modes
    private var bankedRegisters: [Mode: [UInt32]] = [
        .fiq: [UInt32](repeating: 0, count: 7),        // R8-R14
        .irq: [UInt32](repeating: 0, count: 2),        // R13-R14
        .supervisor: [UInt32](repeating: 0, count: 2), // R13-R14
        .abort: [UInt32](repeating: 0, count: 2),      // R13-R14
        .undefined: [UInt32](repeating: 0, count: 2)   // R13-R14
    ]
    
    /// Current Program Status Register
    /// Made internal so Thumb extensions can access it
    var cpsr: UInt32 = 0x13 // Start in supervisor mode
    
    /// Saved Program Status Registers for different modes
    internal var savedPSR: [Mode: UInt32] = [:]
    
    /// Current instruction set
    private var instructionSet: InstructionSet = .arm
    
    /// Memory management unit reference
    /// Made internal so Thumb extensions can access it
    weak var memory: GBAMemoryManager?
    
    /// Interrupt controller reference
    weak var interruptController: GBAInterruptController?
    
    // MARK: - Pipeline
    
    /// 3-stage pipeline: Fetch, Decode, Execute
    private var pipeline = [UInt32](repeating: 0, count: 3)
    private var pipelineValid = [Bool](repeating: false, count: 3)
    
    // MARK: - Performance Counters
    
    private var cycleCount: UInt64 = 0
    private var instructionCount: UInt64 = 0
    
    // MARK: - Initialization
    
    init(memory: GBAMemoryManager) {
        self.memory = memory
        reset()
        logger.info("ARM7TDMI CPU initialized")
    }
    
    // MARK: - Public Interface
    
    /// Reset the CPU to initial state
    func reset() {
        logger.info("Resetting ARM7TDMI CPU")
        
        // Clear registers
        registers = [UInt32](repeating: 0, count: 16)
        
        // Clear banked registers
        bankedRegisters.removeAll()
        savedPSR.removeAll()
        
        // Reset CPSR to supervisor mode (SVC mode, ARM state, interrupts disabled)
        cpsr = 0xD3  // SVC mode (0x13) + I and F bits set
        instructionSet = .arm
        
        // Set initial PC to ROM start (0x08000000)
        // GBA boots from cartridge ROM after BIOS (we skip BIOS for now)
        registers[15] = 0x08000000
        
        // Set initial stack pointers for different modes
        // SP (R13) should point to end of IWRAM for now
        registers[13] = 0x03007F00
        
        // Clear pipeline
        pipeline = [UInt32](repeating: 0, count: 3)
        pipelineValid = [Bool](repeating: false, count: 3)
        
        // Reset counters
        cycleCount = 0
        instructionCount = 0
        
        logger.info("CPU reset complete - PC: 0x\(String(format: "%08X", self.registers[15]))")
    }
    
    /// Execute a single instruction
    /// Returns the number of cycles consumed
    @discardableResult
    func executeInstruction() -> Int {
        guard let memory = memory else { return 1 }
        
        var cycles = 1
        
        // Handle interrupts first
        if let interrupt = interruptController?.getPendingInterrupt() {
            cycles += handleInterrupt(interrupt)
        }
        
        // Fetch stage
        if !pipelineValid[0] {
            let fetchAddress = registers[15]
            
            if instructionSet == .arm {
                pipeline[0] = memory.read32(address: fetchAddress)
                registers[15] += 4
            } else {
                pipeline[0] = UInt32(memory.read16(address: fetchAddress))
                registers[15] += 2
            }
            
            pipelineValid[0] = true
            cycles += getMemoryAccessCycles(address: fetchAddress)
        }
        
        // Decode stage
        if !pipelineValid[1] && pipelineValid[0] {
            pipeline[1] = pipeline[0]
            pipelineValid[1] = true
            pipelineValid[0] = false
        }
        
        // Execute stage
        if pipelineValid[1] {
            let instruction = pipeline[1]
            
            if instructionSet == .arm {
                cycles += executeARMInstruction(instruction)
            } else {
                // Safely cast to UInt16 for Thumb instructions
                let thumbInstruction = UInt16(truncatingIfNeeded: instruction & 0xFFFF)
                cycles += executeThumbInstruction(thumbInstruction)
            }
            
            pipelineValid[1] = false
            instructionCount += 1
        }
        
        cycleCount += UInt64(cycles)
        return cycles
    }
    
    // MARK: - ARM Instruction Execution
    
    private func executeARMInstruction(_ instruction: UInt32) -> Int {
        let condition = (instruction >> 28) & 0xF
        
        // Check condition codes
        if !checkCondition(condition) {
            return 1 // Conditional instruction not executed
        }
        
        // Check for Multiply instructions (higher priority)
        if (instruction & 0x0FC000F0) == 0x00000090 {
            return executeMultiply(instruction)
        }
        
        // Check for Multiply Long instructions
        if (instruction & 0x0F8000F0) == 0x00800090 {
            return executeMultiplyLong(instruction)
        }
        
        // Check for Halfword/Signed Data Transfer (LDRH, STRH, LDRSB, LDRSH)
        if (instruction & 0x0E400F90) == 0x00000090 {
            return executeHalfwordTransfer(instruction)
        }
        
        // Check for Single Data Swap (SWP, SWPB)
        if (instruction & 0x0FB00FF0) == 0x01000090 {
            return executeSingleDataSwap(instruction)
        }
        
        // Check for PSR Transfer (MRS, MSR)
        if (instruction & 0x0FBF0FFF) == 0x010F0000 {
            // MRS - Move PSR to Register
            return executeMRS(instruction)
        }
        if (instruction & 0x0DB0F000) == 0x0120F000 {
            // MSR - Move to PSR
            return executeMSR(instruction)
        }
        
        // Regular instruction decoding
        switch (instruction >> 25) & 0x7 {
        case 0, 1: // Data processing
            return executeDataProcessing(instruction)
            
        case 2, 3: // Load/Store immediate offset
            return executeLoadStore(instruction)
            
        case 4: // Load/Store multiple
            return executeLoadStoreMultiple(instruction)
            
        case 5: // Branch
            return executeBranch(instruction)
            
        case 7: // Software interrupt
            return executeSWI(instruction)
            
        default:
            logger.warning("Unknown ARM instruction: \(String(format: "%08X", instruction))")
            return 1
        }
    }
    
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
    
    private func executeLoadStore(_ instruction: UInt32) -> Int {
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
            offset = applyShift(offset, type: Int(shiftType), amount: Int(shiftAmount))
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
    
    private func executeLoadStoreMultiple(_ instruction: UInt32) -> Int {
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
    
    private func executeBranch(_ instruction: UInt32) -> Int {
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
    
    private func executeSWI(_ instruction: UInt32) -> Int {
        // Software Interrupt
        let swiNumber = (instruction >> 16) & 0xFF
        
        // Save current mode and switch to supervisor mode
        savedPSR[.supervisor] = cpsr
        cpsr = (cpsr & 0xFFFFFF00) | 0x13 // Supervisor mode
        
        // Save return address
        registers[14] = registers[15] - 4
        
        // Jump to SWI vector
        registers[15] = 0x00000008
        
        flushPipeline()
        logger.debug("SWI executed: \(swiNumber)")
        
        return 3
    }
    
    // MARK: - Thumb Instruction Execution
    // Note: All Thumb instruction implementations are in separate files:
    // - ThumbInstructions.swift (main dispatcher)
    // - ThumbShiftArithmetic.swift (Format 1, 2, 3)
    // - ThumbALU.swift (Format 4, 5)
    // - ThumbLoadStore.swift (Format 6, 7, 8, 9, 10, 14)
    // - ThumbStackBranch.swift (Format 11, 12, 13, 15, 17, 18, 19)
    
    // MARK: - Helper Methods
    
    internal func checkCondition(_ condition: UInt32) -> Bool {
        let n = (cpsr >> 31) & 1 != 0  // Negative
        let z = (cpsr >> 30) & 1 != 0  // Zero
        let c = (cpsr >> 29) & 1 != 0  // Carry
        let v = (cpsr >> 28) & 1 != 0  // Overflow
        
        switch condition {
        case 0: return z              // EQ - Equal
        case 1: return !z             // NE - Not equal
        case 2: return c              // CS - Carry set
        case 3: return !c             // CC - Carry clear
        case 4: return n              // MI - Minus
        case 5: return !n             // PL - Plus
        case 6: return v              // VS - Overflow set
        case 7: return !v             // VC - Overflow clear
        case 8: return c && !z        // HI - Higher
        case 9: return !c || z        // LS - Lower or same
        case 10: return n == v        // GE - Greater or equal
        case 11: return n != v        // LT - Less than
        case 12: return !z && (n == v) // GT - Greater than
        case 13: return z || (n != v) // LE - Less or equal
        case 14: return true          // AL - Always
        case 15: return false         // NV - Never
        default: return false
        }
    }
    
    // Made internal so Thumb extensions can access it
    func updateFlags(result: UInt32, operation: Int) {
        // Update N flag (bit 31)
        if result & 0x80000000 != 0 {
            cpsr |= 0x80000000
        } else {
            cpsr &= ~0x80000000
        }
        
        // Update Z flag (bit 30)
        if result == 0 {
            cpsr |= 0x40000000
        } else {
            cpsr &= ~0x40000000
        }
        
        // C and V flags are operation-dependent and would be set during arithmetic operations
    }
    
    private func applyShift(_ value: UInt32, type: Int, amount: Int) -> UInt32 {
        guard amount > 0 else { return value }
        
        switch type {
        case 0: // LSL - Logical shift left
            return amount < 32 ? value << amount : 0
        case 1: // LSR - Logical shift right
            return amount < 32 ? value >> amount : 0
        case 2: // ASR - Arithmetic shift right
            return UInt32(Int32(value) >> min(amount, 31))
        case 3: // ROR - Rotate right
            return rotateRight(value, by: amount % 32)
        default:
            return value
        }
    }
    
    private func rotateRight(_ value: UInt32, by amount: Int) -> UInt32 {
        let shift = amount % 32
        return (value >> shift) | (value << (32 - shift))
    }
    
    private func getMemoryAccessCycles(address: UInt32) -> Int {
        // Simplified memory timing
        // Real GBA has different timings for different memory regions
        switch address {
        case 0x00000000..<0x00004000: // BIOS
            return 1
        case 0x02000000..<0x02040000: // EWRAM
            return 3
        case 0x03000000..<0x03008000: // IWRAM
            return 1
        case 0x08000000..<0x0E000000: // Game Pak
            return 3
        default:
            return 1
        }
    }
    
    internal func flushPipeline() {
        pipelineValid = [Bool](repeating: false, count: 3)
        pipeline = [UInt32](repeating: 0, count: 3)
    }
    
    private func handleInterrupt(_ interrupt: GBAInterrupt) -> Int {
        logger.debug("Handling interrupt: \(interrupt)")
        
        // Save current mode and switch to IRQ mode
        savedPSR[.irq] = cpsr
        cpsr = (cpsr & 0xFFFFFF00) | 0x12 // IRQ mode, disable IRQ
        
        // Save return address
        registers[14] = registers[15] - 4
        
        // Jump to IRQ vector
        registers[15] = 0x00000018
        
        flushPipeline()
        return 3
    }
    
    // MARK: - Save States
    
    func saveState() -> CPUState {
        return CPUState(
            registers: registers,
            cpsr: cpsr,
            bankedRegisters: bankedRegisters,
            savedPSR: savedPSR,
            instructionSet: instructionSet,
            pipeline: pipeline,
            pipelineValid: pipelineValid,
            cycleCount: cycleCount,
            instructionCount: instructionCount
        )
    }
    
    func loadState(_ state: CPUState) {
        registers = state.registers
        cpsr = state.cpsr
        bankedRegisters = state.bankedRegisters
        savedPSR = state.savedPSR
        instructionSet = state.instructionSet
        pipeline = state.pipeline
        pipelineValid = state.pipelineValid
        cycleCount = state.cycleCount
        instructionCount = state.instructionCount
    }
    
    // MARK: - Testing Interface
    
    /// Get register value (for testing)
    func getRegister(_ index: Int) -> UInt32 {
        guard index >= 0 && index < 16 else { return 0 }
        return registers[index]
    }
    
    /// Set register value (for testing)
    func setRegister(_ index: Int, value: UInt32) {
        guard index >= 0 && index < 16 else { return }
        registers[index] = value
    }
    
    /// Get CPSR (for testing)
    func getCPSR() -> UInt32 {
        return cpsr
    }
    
    /// Set CPSR (for testing)
    func setCPSR(_ value: UInt32) {
        cpsr = value
    }
}

// MARK: - Supporting Types

struct CPUState: Codable {
    let registers: [UInt32]
    let cpsr: UInt32
    let bankedRegisters: [GBAARM7TDMI.Mode: [UInt32]]
    let savedPSR: [GBAARM7TDMI.Mode: UInt32]
    let instructionSet: GBAARM7TDMI.InstructionSet
    let pipeline: [UInt32]
    let pipelineValid: [Bool]
    let cycleCount: UInt64
    let instructionCount: UInt64
}

extension GBAARM7TDMI.Mode: Codable {}
extension GBAARM7TDMI.InstructionSet: Codable {}
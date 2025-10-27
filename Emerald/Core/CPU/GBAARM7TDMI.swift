//
//  GBAARM7TDMI.swift
//  Emerald
//
//  Created by Christian Koscielniak Pinto on 26/10/25.
//

import Foundation
import OSLog

/// ARM7TDMI CPU implementation for Game Boy Advance
final class GBAARM7TDMI {
    private let logger = Logger(subsystem: "com.emerald.gba", category: "CPU")
    
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
    private var registers = [UInt32](repeating: 0, count: 16)
    
    /// Banked registers for different modes
    private var bankedRegisters: [Mode: [UInt32]] = [
        .fiq: [UInt32](repeating: 0, count: 7),        // R8-R14
        .irq: [UInt32](repeating: 0, count: 2),        // R13-R14
        .supervisor: [UInt32](repeating: 0, count: 2), // R13-R14
        .abort: [UInt32](repeating: 0, count: 2),      // R13-R14
        .undefined: [UInt32](repeating: 0, count: 2)   // R13-R14
    ]
    
    /// Current Program Status Register
    private var cpsr: UInt32 = 0x13 // Start in supervisor mode
    
    /// Saved Program Status Registers for different modes
    private var savedPSR: [Mode: UInt32] = [:]
    
    /// Current instruction set
    private var instructionSet: InstructionSet = .arm
    
    /// Memory management unit reference
    private weak var memory: GBAMemoryManager?
    
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
        
        let opcode = (instruction >> 21) & 0xF
        let i = (instruction >> 25) & 1
        let s = (instruction >> 20) & 1
        
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
        let s = (instruction >> 22) & 1 != 0  // PSR & force user mode
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
    
    private func executeThumbInstruction(_ instruction: UInt16) -> Int {
        // Simplified Thumb implementation
        // In a full implementation, this would decode and execute Thumb instructions
        
        let opcode = (instruction >> 13) & 0x7
        
        switch opcode {
        case 0, 1: // Shift operations
            return executeThumbShift(instruction)
        case 2: // Add/subtract
            return executeThumbAddSubtract(instruction)
        case 3: // Move/compare/add/subtract immediate
            return executeThumbImmediate(instruction)
        case 4: // ALU operations
            return executeThumbALU(instruction)
        case 5: // Hi register operations/branch exchange
            return executeThumbHiReg(instruction)
        case 6: // PC-relative load
            return executeThumbPCLoad(instruction)
        case 7: // Load/store with register offset
            return executeThumbLoadStoreReg(instruction)
        default:
            logger.warning("Unknown Thumb instruction: \(String(format: "%04X", instruction))")
            return 1
        }
    }
    
    private func executeThumbShift(_ instruction: UInt16) -> Int {
        let op = (instruction >> 11) & 0x3
        let offset5 = (instruction >> 6) & 0x1F
        let rs = Int((instruction >> 3) & 0x7)
        let rd = Int(instruction & 0x7)
        
        let value = registers[rs]
        var result: UInt32
        
        switch op {
        case 0: // LSL
            result = value << offset5
        case 1: // LSR
            result = offset5 == 0 ? 0 : value >> offset5
        case 2: // ASR
            result = UInt32(Int32(value) >> (offset5 == 0 ? 31 : Int32(offset5)))
        default:
            result = value
        }
        
        registers[rd] = result
        updateFlags(result: result, operation: 0)
        
        return 1
    }
    
    private func executeThumbAddSubtract(_ instruction: UInt16) -> Int {
        // Simplified implementation
        return 1
    }
    
    private func executeThumbImmediate(_ instruction: UInt16) -> Int {
        // Simplified implementation
        return 1
    }
    
    private func executeThumbALU(_ instruction: UInt16) -> Int {
        // Simplified implementation
        return 1
    }
    
    private func executeThumbHiReg(_ instruction: UInt16) -> Int {
        // Simplified implementation
        return 1
    }
    
    private func executeThumbPCLoad(_ instruction: UInt16) -> Int {
        // Simplified implementation
        return 1
    }
    
    private func executeThumbLoadStoreReg(_ instruction: UInt16) -> Int {
        // Simplified implementation
        return 1
    }
    
    // MARK: - Helper Methods
    
    private func checkCondition(_ condition: UInt32) -> Bool {
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
    
    private func updateFlags(result: UInt32, operation: Int) {
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
    
    private func flushPipeline() {
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
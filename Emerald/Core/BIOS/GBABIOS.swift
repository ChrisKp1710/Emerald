//
//  GBABIOS.swift
//  Emerald
//
//  GBA BIOS High-Level Emulation (HLE)
//  Implements GBA BIOS functions without using the original Nintendo BIOS
//
//  Reference: mGBA (https://github.com/mgba-emu/mgba)
//  Documentation: GBATEK (http://problemkaputt.de/gbatek.htm)
//

import Foundation
import OSLog

/// GBA BIOS High-Level Emulation
///
/// This class implements the 42 GBA BIOS software interrupt (SWI) functions
/// without requiring the original Nintendo BIOS ROM.
final class GBABIOS {
    private let logger = Logger(subsystem: "com.emerald.gba", category: "BIOS")

    // MARK: - Component References

    /// Weak reference to CPU (to access/modify registers)
    private weak var cpu: GBAARM7TDMI?

    /// Weak reference to Memory Manager
    private weak var memory: GBAMemoryManager?

    /// Weak reference to Interrupt Controller
    private weak var interrupts: GBAInterruptController?

    // MARK: - Statistics (for debugging)

    private var swiCallCounts: [UInt8: Int] = [:]

    // MARK: - Initialization

    init(cpu: GBAARM7TDMI, memory: GBAMemoryManager, interrupts: GBAInterruptController) {
        self.cpu = cpu
        self.memory = memory
        self.interrupts = interrupts
        logger.info("🎮 BIOS HLE initialized")
    }

    // MARK: - Main SWI Handler

    /// Handle a software interrupt (SWI) call
    /// - Parameter swiNumber: The BIOS function number (0x00-0x2A)
    /// - Returns: Number of cycles taken (for accurate emulation)
    func handleSWI(_ swiNumber: UInt8) -> Int {
        guard let cpu = cpu, let memory = memory else {
            logger.error("❌ BIOS HLE called but CPU/Memory not available")
            return 3
        }

        // Track statistics
        swiCallCounts[swiNumber, default: 0] += 1

        // Log the call (with register values for debugging)
        logger.debug("🔧 SWI 0x\(String(format: "%02X", swiNumber)) - r0=0x\(String(format: "%08X", cpu.registers[0])) r1=0x\(String(format: "%08X", cpu.registers[1])) r2=0x\(String(format: "%08X", cpu.registers[2]))")

        // Dispatch to appropriate handler
        switch swiNumber {
        // === PHASE 1: CRITICAL FUNCTIONS ===
        case 0x05: return vblankIntrWait(cpu, memory)
        case 0x06: return div(cpu)
        case 0x0B: return cpuSet(cpu, memory)
        case 0x0C: return cpuFastSet(cpu, memory)
        case 0x11: return lz77UncompWRAM(cpu, memory)

        // === PHASE 2: EXTENDED FUNCTIONS (TODO) ===
        case 0x00: return softReset()
        case 0x01: return registerRamReset(cpu, memory)
        case 0x02: return halt(cpu)
        case 0x03: return stop(cpu)
        case 0x04: return intrWait(cpu, memory)
        case 0x07: return divArm(cpu)
        case 0x08: return sqrt(cpu)
        case 0x09: return arctan(cpu)
        case 0x0A: return arctan2(cpu)

        // === PHASE 3: DECOMPRESSION (TODO) ===
        case 0x10: return bitUnPack(cpu, memory)
        case 0x12: return lz77UncompVRAM(cpu, memory)
        case 0x13: return huffUncomp(cpu, memory)
        case 0x14: return rlUncompWRAM(cpu, memory)
        case 0x15: return rlUncompVRAM(cpu, memory)
        case 0x16: return diff8bitUnFilter(cpu, memory)
        case 0x18: return diff16bitUnFilter(cpu, memory)

        // === PHASE 4: AFFINE (TODO) ===
        case 0x0D: return biosChecksum(cpu)
        case 0x0E: return bgAffineSet(cpu, memory)
        case 0x0F: return objAffineSet(cpu, memory)

        // === PHASE 5: AUDIO/MISC (TODO) ===
        case 0x19: return soundBias(cpu)
        case 0x1F: return midiKey2Freq(cpu)

        default:
            logger.warning("⚠️ Unimplemented BIOS call: SWI 0x\(String(format: "%02X", swiNumber))")
            return 3
        }
    }

    // MARK: - Debug & Statistics

    /// Print statistics about BIOS usage (for debugging)
    func printStatistics() {
        logger.info("📊 BIOS HLE Statistics:")
        let sorted = swiCallCounts.sorted { $0.value > $1.value }
        for (swi, count) in sorted.prefix(10) {
            logger.info("  SWI 0x\(String(format: "%02X", swi)): \(count) calls")
        }
    }
}

// MARK: - PHASE 1 IMPLEMENTATIONS (Critical Functions)

extension GBABIOS {

    // MARK: VBlankIntrWait (0x05) - MOST CRITICAL

    /// Wait for VBlank interrupt
    /// Used by almost ALL GBA games for frame synchronization
    private func vblankIntrWait(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager) -> Int {
        logger.debug("🔄 VBlankIntrWait called - Setting up VBlank wait")

        // VBlankIntrWait is just IntrWait with r0=1, r1=1
        cpu.registers[0] = 1  // Discard old flags
        cpu.registers[1] = 1  // Wait for VBlank (bit 0)

        return intrWait(cpu, memory)
    }

    // MARK: IntrWait (0x04)

    /// Wait for any interrupt
    private func intrWait(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager) -> Int {
        let discardOld = cpu.registers[0]
        let interruptMask = cpu.registers[1]

        logger.debug("⏳ IntrWait - mask=0x\(String(format: "%04X", interruptMask)) discard=\(discardOld)")

        // IF_BIOS register at 0x03007FF8 (CRITICAL!)
        let ifBiosAddr: UInt32 = 0x03007FF8

        if discardOld != 0 {
            // Clear the interrupt flags we're waiting for in IF_BIOS
            var ifBios = memory.read16(address: ifBiosAddr)
            ifBios &= ~UInt16(interruptMask & 0xFFFF)
            memory.write16(address: ifBiosAddr, value: ifBios)
            logger.debug("  Cleared IF_BIOS flags")
        }

        // Halt the CPU - it will wake up when the interrupt arrives
        cpu.halted = true
        logger.debug("  CPU halted, waiting for interrupt")

        return 3
    }

    // MARK: Div (0x06) - Division

    /// Integer division
    /// r0 = numerator, r1 = denominator
    /// Returns: r0 = quotient, r1 = remainder, r3 = abs(quotient)
    private func div(_ cpu: GBAARM7TDMI) -> Int {
        let numerator = Int32(bitPattern: cpu.registers[0])
        let denominator = Int32(bitPattern: cpu.registers[1])

        logger.debug("➗ Div: \(numerator) / \(denominator)")

        if denominator == 0 {
            // Division by zero
            logger.warning("⚠️ Division by zero!")
            cpu.registers[0] = numerator < 0 ? 0xFFFFFFFF : 1
            cpu.registers[1] = UInt32(bitPattern: numerator)
            cpu.registers[3] = 1
        } else if denominator == -1 && numerator == Int32.min {
            // Special case: INT32_MIN / -1 overflows
            logger.debug("  Special case: INT32_MIN / -1")
            cpu.registers[0] = UInt32(bitPattern: Int32.min)
            cpu.registers[1] = 0
            cpu.registers[3] = UInt32(bitPattern: Int32.min)
        } else {
            // Normal division
            let quotient = numerator / denominator
            let remainder = numerator % denominator

            cpu.registers[0] = UInt32(bitPattern: quotient)
            cpu.registers[1] = UInt32(bitPattern: remainder)
            cpu.registers[3] = UInt32(bitPattern: abs(quotient))

            logger.debug("  Result: q=\(quotient), r=\(remainder), abs=\(abs(quotient))")
        }

        // TODO: Accurate cycle counting (4 + 13*loops + 7)
        return 20
    }

    // MARK: DivArm (0x07)

    /// Division with swapped operands (r0=denominator, r1=numerator)
    private func divArm(_ cpu: GBAARM7TDMI) -> Int {
        // Swap operands
        let temp = cpu.registers[0]
        cpu.registers[0] = cpu.registers[1]
        cpu.registers[1] = temp

        return div(cpu)
    }

    // MARK: CPUSet (0x0B) - Memory Copy/Fill

    /// Copy or fill memory (16-bit or 32-bit)
    /// r0 = source address
    /// r1 = destination address
    /// r2 = count | flags
    ///   bit 24: 0=16bit, 1=32bit
    ///   bit 26: 0=copy, 1=fill
    private func cpuSet(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager) -> Int {
        let source = cpu.registers[0]
        let dest = cpu.registers[1]
        let control = cpu.registers[2]

        let count = control & 0x1FFFFF
        let is32bit = (control & (1 << 24)) != 0
        let isFill = (control & (1 << 26)) != 0

        logger.debug("📦 CPUSet: src=0x\(String(format: "%08X", source)) dst=0x\(String(format: "%08X", dest)) count=\(count) 32bit=\(is32bit) fill=\(isFill)")

        if is32bit {
            // 32-bit mode
            if isFill {
                let fillValue = memory.read32(address: source)
                for i in 0..<count {
                    memory.write32(address: dest + i * 4, value: fillValue)
                }
            } else {
                for i in 0..<count {
                    let value = memory.read32(address: source + i * 4)
                    memory.write32(address: dest + i * 4, value: value)
                }
            }
        } else {
            // 16-bit mode
            if isFill {
                let fillValue = memory.read16(address: source)
                for i in 0..<count {
                    memory.write16(address: dest + i * 2, value: fillValue)
                }
            } else {
                for i in 0..<count {
                    let value = memory.read16(address: source + i * 2)
                    memory.write16(address: dest + i * 2, value: value)
                }
            }
        }

        logger.debug("  ✅ CPUSet completed")
        return Int(count) + 3
    }

    // MARK: CPUFastSet (0x0C) - Fast Memory Copy/Fill

    /// Fast copy or fill memory (always 32-bit, count must be multiple of 8)
    /// r0 = source address
    /// r1 = destination address
    /// r2 = wordcount | flags
    ///   bit 24: 0=copy, 1=fill
    private func cpuFastSet(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager) -> Int {
        let source = cpu.registers[0]
        let dest = cpu.registers[1]
        let control = cpu.registers[2]

        let wordCount = control & 0x1FFFFF
        let isFill = (control & (1 << 24)) != 0

        // Count must be multiple of 8
        let count = (wordCount / 8) * 8

        logger.debug("⚡ CPUFastSet: src=0x\(String(format: "%08X", source)) dst=0x\(String(format: "%08X", dest)) words=\(count) fill=\(isFill)")

        if isFill {
            // Fill mode
            let fillValue = memory.read32(address: source)
            for i in 0..<count {
                memory.write32(address: dest + i * 4, value: fillValue)
            }
        } else {
            // Copy mode - copy 8 words at a time (simulates LDMIA/STMIA)
            for i in stride(from: 0, to: count, by: 8) {
                for j in 0..<8 {
                    guard i + j < count else { break }
                    let offset = UInt32(i + j) * 4
                    let value = memory.read32(address: source + offset)
                    memory.write32(address: dest + offset, value: value)
                }
            }
        }

        logger.debug("  ✅ CPUFastSet completed")
        return Int(count / 8) + 3
    }

    // MARK: LZ77UncompWRAM (0x11) - LZ77 Decompression

    /// LZ77 decompression to WRAM
    /// r0 = source address (compressed data)
    /// r1 = destination address
    private func lz77UncompWRAM(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager) -> Int {
        let source = cpu.registers[0]
        let dest = cpu.registers[1]

        logger.debug("🗜️ LZ77UncompWRAM: src=0x\(String(format: "%08X", source)) dst=0x\(String(format: "%08X", dest))")

        // Read header (4 bytes)
        let header = memory.read32(address: source)
        let type = UInt8(header & 0xFF)
        let uncompressedSize = header >> 8

        guard type == 0x10 else {
            logger.error("❌ Invalid LZ77 header: type=0x\(String(format: "%02X", type))")
            return 3
        }

        logger.debug("  Uncompressed size: \(uncompressedSize) bytes")

        var srcPtr = source + 4
        var destPtr = dest
        var remaining = uncompressedSize

        while remaining > 0 {
            // Read flag byte (8 bits for 8 blocks)
            let flags = memory.read8(address: srcPtr)
            srcPtr += 1

            for bit in 0..<8 {
                guard remaining > 0 else { break }

                if (flags & (0x80 >> bit)) != 0 {
                    // Compressed block (2 bytes)
                    let block = memory.read16(address: srcPtr)
                    srcPtr += 2

                    let displacement = Int((block & 0x0FFF) >> 0) + 1
                    let length = Int((block & 0xF000) >> 12) + 3

                    // Copy from previous buffer
                    for _ in 0..<length {
                        guard remaining > 0 else { break }
                        let byte = memory.read8(address: destPtr - UInt32(displacement))
                        memory.write8(address: destPtr, value: byte)
                        destPtr += 1
                        remaining -= 1
                    }
                } else {
                    // Literal byte
                    let byte = memory.read8(address: srcPtr)
                    memory.write8(address: destPtr, value: byte)
                    srcPtr += 1
                    destPtr += 1
                    remaining -= 1
                }
            }
        }

        logger.debug("  ✅ LZ77 decompression completed")
        return Int(uncompressedSize / 4) + 10
    }
}

// MARK: - STUB IMPLEMENTATIONS (Phases 2-5)

extension GBABIOS {

    // PHASE 2: System & Math (TODO)

    private func softReset() -> Int {
        logger.warning("⚠️ SoftReset not yet implemented")
        return 3
    }

    private func registerRamReset(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager) -> Int {
        logger.warning("⚠️ RegisterRamReset not yet implemented")
        return 3
    }

    private func halt(_ cpu: GBAARM7TDMI) -> Int {
        logger.debug("💤 Halt")
        cpu.halted = true
        return 3
    }

    private func stop(_ cpu: GBAARM7TDMI) -> Int {
        logger.debug("🛑 Stop")
        cpu.stopped = true
        return 3
    }

    private func sqrt(_ cpu: GBAARM7TDMI) -> Int {
        logger.warning("⚠️ Sqrt not yet implemented")
        return 20
    }

    private func arctan(_ cpu: GBAARM7TDMI) -> Int {
        logger.warning("⚠️ ArcTan not yet implemented")
        return 20
    }

    private func arctan2(_ cpu: GBAARM7TDMI) -> Int {
        logger.warning("⚠️ ArcTan2 not yet implemented")
        return 20
    }

    // PHASE 3: Decompression (TODO)

    private func bitUnPack(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager) -> Int {
        logger.warning("⚠️ BitUnPack not yet implemented")
        return 3
    }

    private func lz77UncompVRAM(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager) -> Int {
        logger.warning("⚠️ LZ77UncompVRAM not yet implemented")
        return 3
    }

    private func huffUncomp(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager) -> Int {
        logger.warning("⚠️ HuffUncomp not yet implemented")
        return 3
    }

    private func rlUncompWRAM(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager) -> Int {
        logger.warning("⚠️ RLUncompWRAM not yet implemented")
        return 3
    }

    private func rlUncompVRAM(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager) -> Int {
        logger.warning("⚠️ RLUncompVRAM not yet implemented")
        return 3
    }

    private func diff8bitUnFilter(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager) -> Int {
        logger.warning("⚠️ Diff8bitUnFilter not yet implemented")
        return 3
    }

    private func diff16bitUnFilter(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager) -> Int {
        logger.warning("⚠️ Diff16bitUnFilter not yet implemented")
        return 3
    }

    // PHASE 4: Affine (TODO)

    private func biosChecksum(_ cpu: GBAARM7TDMI) -> Int {
        logger.debug("✅ BiosChecksum - returning fixed value")
        cpu.registers[0] = 0xBAAE187F  // Fixed checksum value
        return 3
    }

    private func bgAffineSet(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager) -> Int {
        logger.warning("⚠️ BgAffineSet not yet implemented")
        return 10
    }

    private func objAffineSet(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager) -> Int {
        logger.warning("⚠️ ObjAffineSet not yet implemented")
        return 10
    }

    // PHASE 5: Audio/Misc (TODO)

    private func soundBias(_ cpu: GBAARM7TDMI) -> Int {
        logger.warning("⚠️ SoundBias not yet implemented")
        return 3
    }

    private func midiKey2Freq(_ cpu: GBAARM7TDMI) -> Int {
        logger.warning("⚠️ MidiKey2Freq not yet implemented")
        return 10
    }
}

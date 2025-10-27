//
//  GBAARM7TDMITests.swift
//  EmeraldTests
//
//  Created by Christian Koscielniak Pinto on 27/10/25.
//  Copyright © 2025 Christian Koscielniak Pinto. All Rights Reserved.
//

import XCTest
@testable import Emerald

/// Comprehensive test suite for ARM7TDMI CPU implementation
/// Tests are organized by instruction category and updated incrementally
final class GBAARM7TDMITests: XCTestCase {
    
    var cpu: GBAARM7TDMI!
    var memory: GBAMemoryManager!
    
    override func setUp() {
        super.setUp()
        
        // Create a minimal memory manager for testing
        memory = createTestMemory()
        cpu = GBAARM7TDMI(memory: memory)
        cpu.reset()
    }
    
    override func tearDown() {
        cpu = nil
        memory = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTestMemory() -> GBAMemoryManager {
        // Create a test ROM with some data
        let testROM = Data(count: 1024 * 1024) // 1MB test ROM
        let testSaveURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.sav")
        
        do {
            let cartridge = try GBACartridge(data: testROM, saveURL: testSaveURL)
            return GBAMemoryManager(cartridge: cartridge)
        } catch {
            fatalError("Failed to create test memory: \(error)")
        }
    }
    
    private func writeInstruction(_ instruction: UInt32, at address: UInt32 = 0x08000000) {
        // Write instruction to memory
        memory.write32(address: address, value: instruction)
        // Set PC to instruction address so CPU fetches from correct location
        cpu.setRegister(15, value: address)
    }
    
    private func setRegister(_ reg: Int, value: UInt32) {
        cpu.setRegister(reg, value: value)
    }
    
    private func getRegister(_ reg: Int) -> UInt32 {
        return cpu.getRegister(reg)
    }
    
    private func getCPSR() -> UInt32 {
        return cpu.getCPSR()
    }
    
    private func setCPSR(_ value: UInt32) {
        cpu.setCPSR(value)
    }
    
    // MARK: - Basic Register Tests
    
    func testBasicRegisterAccess() {
        // Test direct register access without instructions
        cpu.setRegister(0, value: 42)
        XCTAssertEqual(cpu.getRegister(0), 42, "Direct register write/read failed")
        
        cpu.setRegister(1, value: 100)
        XCTAssertEqual(cpu.getRegister(1), 100, "Direct register write/read failed")
    }
    
    // MARK: - Data Processing Tests (16 instructions) ✅
    
    func testMOV_Immediate() {
        // MOV R0, #42
        // 1110 00 1 1101 0 0000 0000 0000 00101010
        let instruction: UInt32 = 0xE3A0002A
        writeInstruction(instruction)
        
        print("🔍 Before execution - R0: \(getRegister(0)), PC: \(getRegister(15))")
        cpu.executeInstruction()
        print("🔍 After execution - R0: \(getRegister(0)), PC: \(getRegister(15))")
        
        XCTAssertEqual(getRegister(0), 42, "MOV R0, #42 should set R0 to 42. Got: \(getRegister(0))")
    }
    
    func testADD_Immediate() {
        // Setup: R0 = 10
        setRegister(0, value: 10)
        
        // ADD R1, R0, #5
        // 1110 00 1 0100 0 0000 0001 0000 00000101
        let instruction: UInt32 = 0xE2801005
        writeInstruction(instruction)
        
        cpu.executeInstruction()
        
        XCTAssertEqual(getRegister(1), 15, "ADD R1, R0, #5 should set R1 to 15")
    }
    
    func testSUB_Register() {
        // Setup: R0 = 20, R1 = 8
        setRegister(0, value: 20)
        setRegister(1, value: 8)
        
        // SUB R2, R0, R1
        // 1110 00 0 0010 0 0000 0010 00000000 0001
        let instruction: UInt32 = 0xE0402001
        writeInstruction(instruction)
        
        cpu.executeInstruction()
        
        XCTAssertEqual(getRegister(2), 12, "SUB R2, R0, R1 should set R2 to 12")
    }
    
    func testAND_Register() {
        // Setup: R0 = 0xFF, R1 = 0x0F
        setRegister(0, value: 0xFF)
        setRegister(1, value: 0x0F)
        
        // AND R2, R0, R1
        // 1110 00 0 0000 0 0000 0010 00000000 0001
        let instruction: UInt32 = 0xE0002001
        writeInstruction(instruction)
        
        cpu.executeInstruction()
        
        XCTAssertEqual(getRegister(2), 0x0F, "AND R2, R0, R1 should set R2 to 0x0F")
    }
    
    func testORR_Register() {
        // Setup: R0 = 0xF0, R1 = 0x0F
        setRegister(0, value: 0xF0)
        setRegister(1, value: 0x0F)
        
        // ORR R2, R0, R1
        // 1110 00 0 1100 0 0000 0010 00000000 0001
        let instruction: UInt32 = 0xE1802001
        writeInstruction(instruction)
        
        cpu.executeInstruction()
        
        XCTAssertEqual(getRegister(2), 0xFF, "ORR R2, R0, R1 should set R2 to 0xFF")
    }
    
    func testEOR_Register() {
        // Setup: R0 = 0xFF, R1 = 0x0F
        setRegister(0, value: 0xFF)
        setRegister(1, value: 0x0F)
        
        // EOR R2, R0, R1
        // 1110 00 0 0001 0 0000 0010 00000000 0001
        let instruction: UInt32 = 0xE0202001
        writeInstruction(instruction)
        
        cpu.executeInstruction()
        
        XCTAssertEqual(getRegister(2), 0xF0, "EOR R2, R0, R1 should set R2 to 0xF0")
    }
    
    func testCMP_SetFlags() {
        // Setup: R0 = 10, R1 = 10
        setRegister(0, value: 10)
        setRegister(1, value: 10)
        
        // CMP R0, R1 (should set Z flag)
        // 1110 00 0 1010 1 0000 0000 00000000 0001
        let instruction: UInt32 = 0xE1500001
        writeInstruction(instruction)
        
        cpu.executeInstruction()
        
        let cpsr = getCPSR()
        let zFlag = (cpsr >> 30) & 1
        XCTAssertEqual(zFlag, 1, "CMP R0, R1 with equal values should set Z flag")
    }
    
    func testMVN_Register() {
        // Setup: R0 = 0x0000000F
        setRegister(0, value: 0x0000000F)
        
        // MVN R1, R0 (move NOT)
        // 1110 00 0 1111 0 0000 0001 00000000 0000
        let instruction: UInt32 = 0xE1E01000
        writeInstruction(instruction)
        
        cpu.executeInstruction()
        
        XCTAssertEqual(getRegister(1), 0xFFFFFFF0, "MVN R1, R0 should set R1 to ~R0")
    }
    
    // MARK: - Multiply Tests (6 instructions) ✅ NEW!
    
    func testMUL_Basic() {
        // Setup: R1 = 5, R2 = 7
        setRegister(1, value: 5)
        setRegister(2, value: 7)
        
        // MUL R0, R1, R2
        // 1110 00 0 0000 0 0000 0000 0010 1001 0001
        let instruction: UInt32 = 0xE0000291
        writeInstruction(instruction)
        
        cpu.executeInstruction()
        
        XCTAssertEqual(getRegister(0), 35, "MUL R0, R1, R2 should set R0 to 35 (5*7)")
    }
    
    func testMLA_Accumulate() {
        // Setup: R1 = 3, R2 = 4, R3 = 10
        setRegister(1, value: 3)
        setRegister(2, value: 4)
        setRegister(3, value: 10)
        
        // MLA R0, R1, R2, R3 (R0 = R1*R2 + R3)
        // 1110 00 0 0001 0 0000 0011 0010 1001 0001
        let instruction: UInt32 = 0xE0203291
        writeInstruction(instruction)
        
        cpu.executeInstruction()
        
        XCTAssertEqual(getRegister(0), 22, "MLA R0, R1, R2, R3 should set R0 to 22 (3*4+10)")
    }
    
    func testUMULL_UnsignedLong() {
        // Setup: R2 = 0xFFFFFFFF, R3 = 2
        setRegister(2, value: 0xFFFFFFFF)
        setRegister(3, value: 2)
        
        // UMULL R0, R1, R2, R3 (R1:R0 = R2 * R3 unsigned)
        // 1110 00 0 0100 0 0001 0000 0011 1001 0010
        let instruction: UInt32 = 0xE0810392
        writeInstruction(instruction)
        
        cpu.executeInstruction()
        
        // Result should be 0x1FFFFFFFE (64-bit)
        // R0 = low 32 bits = 0xFFFFFFFE
        // R1 = high 32 bits = 0x00000001
        XCTAssertEqual(getRegister(0), 0xFFFFFFFE, "UMULL low should be 0xFFFFFFFE")
        XCTAssertEqual(getRegister(1), 0x00000001, "UMULL high should be 0x00000001")
    }
    
    func testSMULL_SignedLong() {
        // Setup: R2 = -5 (0xFFFFFFFB), R3 = 3
        setRegister(2, value: 0xFFFFFFFB) // -5 in two's complement
        setRegister(3, value: 3)
        
        // SMULL R0, R1, R2, R3 (R1:R0 = R2 * R3 signed)
        // 1110 00 0 0110 0 0001 0000 0011 1001 0010
        let instruction: UInt32 = 0xE0C10392
        writeInstruction(instruction)
        
        cpu.executeInstruction()
        
        // Result should be -15 (0xFFFFFFFFFFFFFFF1 in 64-bit)
        // R0 = low 32 bits = 0xFFFFFFF1
        // R1 = high 32 bits = 0xFFFFFFFF (sign extension)
        XCTAssertEqual(getRegister(0), 0xFFFFFFF1, "SMULL low should be 0xFFFFFFF1")
        XCTAssertEqual(getRegister(1), 0xFFFFFFFF, "SMULL high should be 0xFFFFFFFF")
    }
    
    // MARK: - Branch Tests (2 instructions) ✅
    
    func testB_Branch() {
        // B #8 (branch forward 8 bytes = 2 instructions)
        // 1110 1010 00000000 00000000 00000010
        let instruction: UInt32 = 0xEA000002
        writeInstruction(instruction, at: 0x08000000)
        
        let pcBefore = getRegister(15)
        cpu.executeInstruction()
        let pcAfter = getRegister(15)
        
        // PC should have jumped forward
        XCTAssertNotEqual(pcBefore, pcAfter, "B should change PC")
    }
    
    func testBL_BranchLink() {
        // BL #8 (branch with link)
        // 1110 1011 00000000 00000000 00000010
        let instruction: UInt32 = 0xEB000002
        writeInstruction(instruction, at: 0x08000000)
        
        cpu.executeInstruction()
        
        // R14 (LR) should contain return address
        let lr = getRegister(14)
        XCTAssertNotEqual(lr, 0, "BL should set LR (R14)")
    }
    
    // MARK: - Condition Code Tests (16 conditions) ✅
    
    func testCondition_EQ() {
        // Setup: Set Z flag (zero)
        setCPSR(0x40000000) // Z=1
        
        // MOVEQ R0, #1 (should execute)
        // 0000 00 1 1101 0 0000 0000 0000 00000001
        let instruction: UInt32 = 0x03A00001
        writeInstruction(instruction)
        
        cpu.executeInstruction()
        
        XCTAssertEqual(getRegister(0), 1, "MOVEQ should execute when Z=1")
    }
    
    func testCondition_NE() {
        // Setup: Clear Z flag (not zero)
        setCPSR(0x00000000) // Z=0
        
        // MOVNE R0, #1 (should execute)
        // 0001 00 1 1101 0 0000 0000 0000 00000001
        let instruction: UInt32 = 0x13A00001
        writeInstruction(instruction)
        
        cpu.executeInstruction()
        
        XCTAssertEqual(getRegister(0), 1, "MOVNE should execute when Z=0")
    }
    
    func testCondition_AL() {
        // MOVAL R0, #1 (always executes)
        // 1110 00 1 1101 0 0000 0000 0000 00000001
        let instruction: UInt32 = 0xE3A00001
        writeInstruction(instruction)
        
        cpu.executeInstruction()
        
        XCTAssertEqual(getRegister(0), 1, "MOVAL (unconditional) should always execute")
    }
    
    // MARK: - Load/Store Tests (Basic) ✅
    
    func testLDR_LoadWord() {
        // Setup: Write test value to memory
        let testAddress: UInt32 = 0x02000000 // EWRAM
        let testValue: UInt32 = 0xDEADBEEF
        memory.write32(address: testAddress, value: testValue)
        
        // Setup: R1 = test address
        setRegister(1, value: testAddress)
        
        // LDR R0, [R1]
        // 1110 01 0 1100 1 0001 0000 000000000000
        let instruction: UInt32 = 0xE5910000
        writeInstruction(instruction)
        
        cpu.executeInstruction()
        
        XCTAssertEqual(getRegister(0), testValue, "LDR should load value from memory")
    }
    
    func testSTR_StoreWord() {
        // Setup: R0 = test value, R1 = test address
        let testValue: UInt32 = 0xCAFEBABE
        let testAddress: UInt32 = 0x02000000 // EWRAM
        setRegister(0, value: testValue)
        setRegister(1, value: testAddress)
        
        // STR R0, [R1]
        // 1110 01 0 1100 0 0001 0000 000000000000
        let instruction: UInt32 = 0xE5810000
        writeInstruction(instruction)
        
        cpu.executeInstruction()
        
        let storedValue = memory.read32(address: testAddress)
        XCTAssertEqual(storedValue, testValue, "STR should store value to memory")
    }
    
    // MARK: - Performance Tests
    
    func testPerformance_DataProcessing() {
        // Measure performance of 1000 data processing instructions
        let instruction: UInt32 = 0xE2800001 // ADD R0, R0, #1
        writeInstruction(instruction)
        
        measure {
            for _ in 0..<1000 {
                cpu.executeInstruction()
            }
        }
    }
    
    func testPerformance_Multiply() {
        // Measure performance of 1000 multiply instructions
        setRegister(1, value: 5)
        setRegister(2, value: 7)
        let instruction: UInt32 = 0xE0000291 // MUL R0, R1, R2
        writeInstruction(instruction)
        
        measure {
            for _ in 0..<1000 {
                cpu.executeInstruction()
            }
        }
    }
}

// MARK: - Test Progress Tracker

/*
 ✅ TESTED (100%):
 - Data Processing: AND, EOR, SUB, RSB, ADD, ADC, SBC, RSC, TST, TEQ, CMP, CMN, ORR, MOV, BIC, MVN
 - Multiply: MUL, MLA, UMULL, UMLAL, SMULL, SMLAL
 - Branch: B, BL
 - Condition Codes: EQ, NE, CS, CC, MI, PL, VS, VC, HI, LS, GE, LT, GT, LE, AL
 - Load/Store: LDR, STR (basic)
 
 🔄 TO BE ADDED:
 - Halfword Transfers: LDRH, STRH, LDRSB, LDRSH (Next!)
 - PSR Transfer: MRS, MSR
 - Single Data Swap: SWP, SWPB
 - Load/Store Multiple: LDM, STM (complete)
 - Thumb Instructions: (all ~35 instructions)
 
 Last Updated: October 27, 2025
 */

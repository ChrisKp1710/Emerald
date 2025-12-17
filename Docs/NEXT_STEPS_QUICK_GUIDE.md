# Guida Rapida - Prossimi Passi

**Per**: Emerald GBA Emulator
**Data**: 17 Dicembre 2024
**Fase Attuale**: Pre-BIOS HLE Implementation

---

## 🎯 OBIETTIVO IMMEDIATO

**Implementare le 5 funzioni BIOS critiche per far partire i giochi**

Tempo: 2-3 giorni
Risultato: Homebrew funzionanti, alcuni giochi avviabili

---

## 📋 CHECKLIST OPERATIVA

### Step 1: Setup Struttura (30 minuti)

```bash
# Crea cartella BIOS
mkdir -p Emerald/Core/BIOS

# Crea i file necessari
touch Emerald/Core/BIOS/GBABIOS.swift
touch Emerald/Core/BIOS/BIOSInterrupts.swift
touch Emerald/Core/BIOS/BIOSMath.swift
touch Emerald/Core/BIOS/BIOSMemory.swift
touch Emerald/Core/BIOS/BIOSDecompression.swift
```

**Aggiungi files a Xcode**:
1. Apri Emerald.xcodeproj
2. Drag cartella `BIOS/` nel navigator
3. Check "Copy items if needed"
4. Check "Create groups"
5. Target: Emerald

### Step 2: Implementa Dispatcher (1 ora)

**File**: `Emerald/Core/BIOS/GBABIOS.swift`

Copia il template da `BIOS_HLE_ROADMAP.md` Fase 1.1 → Classe `GBABIOS`.

**Componenti chiave**:
- [ ] Classe `GBABIOS` con weak references
- [ ] Funzione `handleSWI(_ swiNumber: UInt8) -> Int`
- [ ] Switch per dispatch funzioni
- [ ] Logging per debug

### Step 3: Modifica CPU per usare HLE (30 minuti)

**File 1**: `Emerald/Core/CPU/GBAARM7TDMI.swift`

Aggiungi:
```swift
final class GBAARM7TDMI {
    // ... esistente ...

    weak var bios: GBABIOS?  // ← AGGIUNGI QUESTA RIGA

    // ... resto ...
}
```

**File 2**: `Emerald/Core/CPU/ARM/ARMMemoryInstructions.swift`

Modifica `executeSWI()`:
```swift
internal func executeSWI(_ instruction: UInt32) -> Int {
    let swiNumber = UInt8((instruction >> 16) & 0xFF)

    // Chiama HLE se disponibile
    if let bios = self.bios {
        return bios.handleSWI(swiNumber)
    }

    // Fallback (per debug)
    logger.warning("BIOS HLE not available, falling back to dummy")
    return 3
}
```

**File 3**: `Emerald/Core/CPU/Thumb/ThumbStackBranch.swift`

Cerca `executeThumbSWI` e fai modifica simile (swiNumber è bits [7:0] per Thumb).

### Step 4: Inizializza BIOS in EmulatorState (15 minuti)

**File**: `Emerald/Managers/EmulatorState.swift`

Trova `setupEmulator()` e aggiungi:
```swift
private func setupEmulator() {
    // ... codice esistente ...

    cpu = GBAARM7TDMI(memory: memory)
    ppu = GBAPPU(memory: memory, interruptController: interruptController)

    // ← AGGIUNGI QUESTE RIGHE
    let bios = GBABIOS(cpu: cpu, memory: memory, interrupts: interruptController)
    cpu.bios = bios

    // ... resto ...
}
```

### Step 5: Implementa VBlankIntrWait (2 ore)

**File**: `Emerald/Core/BIOS/BIOSInterrupts.swift`

1. Copia implementazione da `BIOS_HLE_ROADMAP.md` Fase 1.2
2. Implementa registro IF_BIOS (0x03007FF8) in `GBAMemoryManager`
3. Modifica `handleInterrupt()` per risvegliare CPU da halt
4. Aggiungi `var halted: Bool = false` in `GBAARM7TDMI`
5. Nel loop principale, controlla `if cpu.halted { continue }`

**Modifiche necessarie**:

`Emerald/Core/CPU/GBAARM7TDMI.swift`:
```swift
final class GBAARM7TDMI {
    // ... esistente ...

    var halted: Bool = false  // ← AGGIUNGI

    // ... resto ...
}
```

`Emerald/Core/Memory/GBAMemoryManager.swift`:
Aggiungi gestione per 0x03007FF8 (IF_BIOS register).

### Step 6: Implementa Div (1 ora)

**File**: `Emerald/Core/BIOS/BIOSMath.swift`

Copia implementazione da `BIOS_HLE_ROADMAP.md` Fase 1.3.

**Test manuale**:
```swift
// In console debug
cpu.registers[0] = 100  // numerator
cpu.registers[1] = 7    // denominator
biosDiv(cpu)
// Verifica: r0 = 14 (quotient), r1 = 2 (remainder), r3 = 14 (abs)
```

### Step 7: Implementa CPUSet (1 ora)

**File**: `Emerald/Core/BIOS/BIOSMemory.swift`

Copia implementazione da `BIOS_HLE_ROADMAP.md` Fase 1.4.

### Step 8: Implementa CPUFastSet (45 minuti)

**File**: `Emerald/Core/BIOS/BIOSMemory.swift`

Copia implementazione da `BIOS_HLE_ROADMAP.md` Fase 1.5.

### Step 9: Implementa LZ77UncompWRAM (2 ore)

**File**: `Emerald/Core/BIOS/BIOSDecompression.swift`

Copia implementazione da `BIOS_HLE_ROADMAP.md` Fase 1.6.

**Nota**: Questa è la più complessa. Testa con dati LZ77 reali.

### Step 10: Testing (1-2 ore)

**ROM di test**:
1. Scarica Tonc demos: https://github.com/gbadev-org/libtonc
2. Prova ROM semplici che usano VBlankIntrWait
3. Controlla log console per SWI calls
4. Verifica che non crashi

**Log da controllare**:
```
BIOS SWI 0x05 called  // VBlankIntrWait
BIOS SWI 0x06 called  // Div
BIOS SWI 0x11 called  // LZ77UncompWRAM
```

---

## 🐛 DEBUGGING TIPS

### Se l'emulatore crasha

1. **Controlla SWI number**:
   ```swift
   logger.debug("SWI \(String(format: "0x%02X", swiNum)) called")
   logger.debug("  r0=\(String(format: "0x%08X", cpu.registers[0]))")
   logger.debug("  r1=\(String(format: "0x%08X", cpu.registers[1]))")
   ```

2. **Verifica parametri**:
   - Source/dest addresses validi?
   - Sizes ragionevoli?
   - Alignment corretto?

3. **Controlla memoria**:
   - IF_BIOS register funziona?
   - BIOS reads ritornano 0xFF?
   - VRAM/WRAM accessibili?

### Se VBlankIntrWait non funziona

- [ ] IME (Interrupt Master Enable) = 1?
- [ ] IE (Interrupt Enable) ha VBlank bit set?
- [ ] IF_BIOS register implementato a 0x03007FF8?
- [ ] PPU genera VBlank interrupt correttamente?
- [ ] CPU si risveglia da halt quando arriva interrupt?

### Se LZ77 decompression fallisce

- [ ] Header valido (tipo = 0x10)?
- [ ] Size ragionevole?
- [ ] Source/dest addresses validi?
- [ ] Flag byte parsing corretto?
- [ ] Displacement calcolo corretto?

---

## 📊 MILESTONE TRACKING

### Milestone 1: Dispatcher Funzionante

**Criterio**: SWI calls loggati correttamente

Test:
```swift
// Chiama SWI dummy
cpu.registers[15] = someAddress
executeSWI(0xEF000005)  // VBlankIntrWait in ARM mode
// Verifica log: "BIOS SWI 0x05 called"
```

✅ **PASS**: Log appare senza crash

### Milestone 2: VBlankIntrWait Funzionante

**Criterio**: CPU va in halt e si risveglia su VBlank

Test:
```swift
// Prima del VBlank
assert(cpu.halted == false)

// Chiama VBlankIntrWait
biosVBlankIntrWait(cpu, memory)
assert(cpu.halted == true)

// Simula VBlank interrupt
interruptController.requestInterrupt(.vblank)
handleInterrupt(.vblank)
assert(cpu.halted == false)  // CPU risvegliata
```

✅ **PASS**: CPU si risveglia correttamente

### Milestone 3: Div Funzionante

**Criterio**: Divisione corretta con tutti i casi

Test:
```swift
// Caso normale
testDiv(100, 7)  // → q=14, r=2, abs=14

// Divisione per zero
testDiv(100, 0)  // → gestito correttamente

// Overflow
testDiv(Int32.min, -1)  // → gestito correttamente
```

✅ **PASS**: Tutti i test passano

### Milestone 4: CPUSet/CPUFastSet Funzionanti

**Criterio**: Memoria copiata correttamente

Test:
```swift
// Copy 16-bit
let src = setupTestData([0x1234, 0x5678, 0x9ABC])
biosCPUSet(src, dest, count: 3, mode: .copy16)
assert(memory[dest] == [0x1234, 0x5678, 0x9ABC])

// Fill 32-bit
biosCPUSet(src, dest, count: 10, mode: .fill32)
assert(memory[dest...dest+40] == Array(repeating: 0x12345678, count: 10))
```

✅ **PASS**: Dati copiati/riempiti correttamente

### Milestone 5: LZ77 Funzionante

**Criterio**: Dati decompressi = dati attesi

Test:
```swift
let compressedData = loadTestLZ77Data()
biosLZ77UncompWRAM(cpu, memory)

let decompressed = memory.readRange(destAddr, size)
let expected = loadExpectedData()
assert(decompressed == expected)
```

✅ **PASS**: Decompressione corretta

### Milestone 6: Homebrew ROM Funzionante

**Criterio**: Almeno 1 homebrew avviabile senza crash

Test:
1. Carica ROM Tonc demo
2. Esegui per 1000 frame
3. Verifica nessun crash
4. Verifica grafica appare

✅ **PASS**: ROM gira senza problemi

---

## ✅ CHECKLIST FINALE FASE 1

Prima di considerare Fase 1 completata:

- [ ] Tutti i file BIOS creati e aggiunti a Xcode
- [ ] Dispatcher SWI funzionante
- [ ] VBlankIntrWait implementato e testato
- [ ] Div implementato e testato
- [ ] CPUSet implementato e testato
- [ ] CPUFastSet implementato e testato
- [ ] LZ77UncompWRAM implementato e testato
- [ ] IF_BIOS register (0x03007FF8) funzionante
- [ ] CPU halt/wake mechanism funzionante
- [ ] Logging SWI calls completo
- [ ] Nessun crash su SWI calls
- [ ] Almeno 1 homebrew ROM funzionante
- [ ] Codice commentato e pulito
- [ ] Commit Git con messaggio chiaro

---

## 🎓 REFERENCE QUICK

### SWI Numbers (5 critici)

| Hex | Dec | Nome | Registri |
|---|---|---|---|
| 0x05 | 5 | VBlankIntrWait | - |
| 0x06 | 6 | Div | r0=num, r1=den → r0=q, r1=r, r3=abs(q) |
| 0x0B | 11 | CPUSet | r0=src, r1=dst, r2=count\|mode |
| 0x0C | 12 | CPUFastSet | r0=src, r1=dst, r2=count\|mode |
| 0x11 | 17 | LZ77UncompWRAM | r0=src, r1=dst |

### Memory Map Key Addresses

```
0x03007FF8  IF_BIOS (Interrupt Flags BIOS) - 16-bit
0x04000000  I/O Registers base
0x04000200  IE (Interrupt Enable) - 16-bit
0x04000202  IF (Interrupt Flags) - 16-bit
0x04000208  IME (Interrupt Master Enable) - 16-bit
0x04000004  DISPSTAT (Display Status) - 16-bit
```

### CPU States

```swift
cpu.halted = true/false  // CPU in halt (wait for interrupt)
cpu.stopped = true/false // CPU stopped (wait for keypad)
```

### Interrupt Types

```swift
enum GBAInterruptType {
    case vblank   // Bit 0 - Vertical Blank
    case hblank   // Bit 1 - Horizontal Blank
    case vcount   // Bit 2 - V Counter Match
    // ... etc
}
```

---

## 📞 HELP & SUPPORT

### Se ti blocchi

1. **Controlla roadmap dettagliata**: `Docs/BIOS_HLE_ROADMAP.md`
2. **Controlla analisi stato**: `Docs/CURRENT_STATUS_ANALYSIS.md`
3. **Studia codice mGBA**: `github.com/mgba-emu/mgba/src/gba/bios.c`
4. **Consulta GBATEK**: `problemkaputt.de/gbatek.htm`

### Debug Logging

Aggiungi ovunque serve:
```swift
logger.debug("🔧 [BIOS] SWI \(swiNum) - r0=\(r0) r1=\(r1) r2=\(r2)")
logger.debug("📝 [BIOS] Copy from \(src) to \(dst), size \(size)")
logger.debug("✅ [BIOS] Operation completed successfully")
logger.error("❌ [BIOS] Error: \(errorDescription)")
```

---

## 🚀 DOPO FASE 1

Una volta completato:

1. **Commit & Push**:
   ```bash
   git add Emerald/Core/BIOS/
   git commit -m "Implement BIOS HLE core functions (Phase 1)

   - Add VBlankIntrWait (0x05)
   - Add Div (0x06)
   - Add CPUSet (0x0B)
   - Add CPUFastSet (0x0C)
   - Add LZ77UncompWRAM (0x11)
   - Modify SWI handlers to use HLE
   - Add IF_BIOS register support

   Homebrew ROMs now bootable."
   git push
   ```

2. **Update README**:
   - Aggiorna stato BIOS HLE: 0% → 20%
   - Aggiungi note su compatibilità
   - Update screenshot se possibile

3. **Inizia Fase 2**:
   - Matematica (Sqrt, ArcTan)
   - System functions (Reset, Halt, IntrWait)
   - Vedi `BIOS_HLE_ROADMAP.md` Fase 2

---

## 🎯 FOCUS

**Ricorda l'obiettivo**: Far partire i giochi il prima possibile.

**NON farti distrarre da**:
- Ottimizzazioni premature
- Funzioni BIOS non critiche
- Perfect accuracy (verrà dopo)
- Features extra

**CONCENTRATI su**:
- Le 5 funzioni critiche
- Testing con ROM reali
- Debug e fixing
- Codice pulito e funzionante

---

**Buon lavoro! 🚀**

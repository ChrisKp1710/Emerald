# BIOS HLE Implementation Roadmap

**Progetto**: Emerald GBA Emulator
**Obiettivo**: Implementare High-Level Emulation (HLE) del BIOS GBA senza usare il BIOS originale Nintendo
**Data Inizio**: 17 Dicembre 2024
**Riferimento**: mGBA (gold standard per accuratezza)

---

## Executive Summary

Emerald ha un'eccellente base tecnica:
- ✅ CPU ARM7TDMI completo (100% - tutte le 90 istruzioni ARM + Thumb)
- ✅ Sistema memoria funzionante (85%)
- ✅ Rendering Metal performante (100%)
- ✅ PPU Bitmap modes 3, 4, 5 (100%)
- ❌ **BIOS HLE mancante (0%)** ← BLOCKER CRITICO

**Problema**: L'istruzione SWI salta al BIOS (0x00000008), ma il BIOS ritorna solo 0xFF. I giochi GBA chiamano 42 funzioni BIOS per operazioni critiche (divisione, decompressione, VBlank wait, copia memoria). Senza HLE, i giochi crashano o non partono.

**Soluzione**: Implementare HLE basato su mGBA, il migliore emulatore GBA per accuratezza e compatibilità.

---

## Analisi Tecniche

### Progetti di Riferimento

| Progetto | Qualità | Implementazione | Note |
|---|---|---|---|
| **mGBA** ⭐⭐⭐⭐⭐ | Eccellente | C + Assembly ARM | Gold standard, più accurato |
| **NanoBoyAdvance** ⭐⭐⭐⭐⭐ | Cycle-accurate | C++ | Primo a passare AGS aging tests |
| **SkyEmu** ⭐⭐⭐⭐⭐ | Alta compatibilità | C | Passa 2020/2020 GBA Suite tests |
| **VBA-M** ⭐⭐⭐ | Buona | C++ | Legacy, bug noti in LZ77 |
| **Cult-of-GBA** ⭐⭐⭐⭐ | Educativo | Assembly puro | Open source, MIT license |

**Scelta**: **mGBA** come riferimento principale per implementazione HLE.

### Funzioni BIOS GBA (42 totali)

#### Priorità CRITICA (5 funzioni)
| ID | Nome | Uso | Impatto |
|---|---|---|---|
| 0x05 | VBlankIntrWait | Attesa VBlank | 🔴 CRITICO - Usata da TUTTI i giochi |
| 0x06 | Div | Divisione interi | 🔴 CRITICO - Maggior parte dei giochi |
| 0x0B | CPUSet | Copia memoria | 🔴 CRITICO - Transfer dati |
| 0x0C | CPUFastSet | Copia veloce | 🔴 CRITICO - Transfer bulk |
| 0x11 | LZ77UncompWRAM | Decompressione LZ77 | 🔴 CRITICO - Grafica compressa |

#### Priorità ALTA (8 funzioni)
| ID | Nome | Uso |
|---|---|---|
| 0x00 | SoftReset | Reset sistema |
| 0x01 | RegisterRamReset | Reset selettivo memoria |
| 0x04 | IntrWait | Attesa interrupt generica |
| 0x08 | Sqrt | Radice quadrata |
| 0x09 | ArcTan | Arctangente |
| 0x0A | ArcTan2 | Arctangente 2 argomenti |
| 0x12 | LZ77UncompVRAM | Decompressione LZ77 VRAM |
| 0x10 | BitUnPack | Decompressione bit-packed |

#### Priorità MEDIA (10 funzioni)
| ID | Nome | Uso |
|---|---|---|
| 0x02 | Halt | CPU halt |
| 0x03 | Stop | CPU stop |
| 0x07 | DivArm | Divisione (ordine inverso) |
| 0x0D | BiosChecksum | Checksum BIOS |
| 0x0E | BgAffineSet | Trasformazioni background |
| 0x0F | ObjAffineSet | Trasformazioni sprite |
| 0x13 | HuffUnComp | Decompressione Huffman |
| 0x14 | RLUnCompWRAM | Decompressione RLE |
| 0x15 | RLUnCompVRAM | Decompressione RLE VRAM |
| 0x19 | SoundBias | Configurazione audio |

#### Priorità BASSA (19 funzioni)
Audio/Music functions (0x1A-0x2A), filtri (0x16-0x18), MultiBoot (0x25), etc.

---

## FASE 1: BIOS HLE Core (PRIORITÀ MASSIMA)

**Obiettivo**: Implementare le 5 funzioni critiche per far partire i giochi
**Tempo Stimato**: 2-3 giorni
**Status**: 🔴 Non iniziato

### 1.1 Setup Architettura

**File da creare**:
```
Emerald/Core/BIOS/
├── GBABIOS.swift              # Classe principale + dispatcher
├── BIOSInterrupts.swift       # VBlankIntrWait, IntrWait, Halt
├── BIOSMath.swift             # Div, DivArm, Sqrt, ArcTan
├── BIOSMemory.swift           # CPUSet, CPUFastSet
└── BIOSDecompression.swift    # LZ77, Huffman, RLE, BitUnpack
```

**Modifiche richieste**:
- `Emerald/Core/CPU/GBAARM7TDMI.swift`: Aggiungere `weak var bios: GBABIOS?`
- `Emerald/Core/CPU/ARM/ARMMemoryInstructions.swift`: Modificare `executeSWI()` per chiamare HLE
- `Emerald/Core/CPU/Thumb/ThumbStackBranch.swift`: Modificare `executeThumbSWI()` per chiamare HLE
- `Emerald/Managers/EmulatorState.swift`: Inizializzare `GBABIOS` nel setup

**Checklist**:
- [ ] Creare cartella `Emerald/Core/BIOS/`
- [ ] Implementare `GBABIOS.swift` con dispatcher SWI
- [ ] Aggiungere proprietà `bios` in `GBAARM7TDMI`
- [ ] Modificare `executeSWI()` in ARM per usare HLE
- [ ] Modificare `executeThumbSWI()` per usare HLE
- [ ] Inizializzare BIOS in `EmulatorState.setupEmulator()`
- [ ] Aggiungere logging per debug SWI calls
- [ ] Creare test unit per verificare dispatcher

### 1.2 Implementare VBlankIntrWait (0x05)

**Priorità**: 🔴 MASSIMA - Bloccante per TUTTI i giochi

**Comportamento**:
```swift
// Pseudo-codice
func vblankIntrWait(cpu: GBAARM7TDMI, memory: GBAMemoryManager) {
    // 1. Resetta flag VBlank in IF_BIOS (0x03007FF8)
    var ifBios = memory.read16(address: 0x03007FF8)
    ifBios &= ~0x0001  // Clear VBlank bit
    memory.write16(address: 0x03007FF8, value: ifBios)

    // 2. Metti CPU in halt
    cpu.halted = true

    // 3. CPU si risveglia quando arriva VBlank interrupt
    //    (gestito in handleInterrupt esistente)
}
```

**Riferimenti**:
- mGBA: `src/gba/hle-bios.s` linea ~40-60
- GBATEK: http://problemkaputt.de/gbatek-bios-halt-functions.htm
- Tonc: https://coranac.com/tonc/text/swi.htm#ssec-swi-vblankintrwait

**Note critiche**:
- DEVE scrivere su IF_BIOS (0x03007FF8), NON su IF normale (0x04000202)
- Richiede interrupts abilitati (IME=1)
- Se interrupts disabilitati, l'emulatore si blocca

**Checklist**:
- [ ] Implementare logica VBlankIntrWait in `BIOSInterrupts.swift`
- [ ] Verificare che `cpu.halted` sia gestito nel loop principale
- [ ] Implementare registro IF_BIOS in `GBAMemoryManager` (0x03007FF8)
- [ ] Modificare `handleInterrupt()` per risvegliare CPU da halt
- [ ] Testare con ROM homebrew che usa VBlankIntrWait
- [ ] Verificare che CPU si risveglia correttamente
- [ ] Logging dettagliato per debug

### 1.3 Implementare Div (0x06)

**Priorità**: 🔴 CRITICA

**Comportamento**:
```swift
func biosDiv(_ cpu: GBAARM7TDMI) {
    let numerator = Int32(bitPattern: cpu.registers[0])
    let denominator = Int32(bitPattern: cpu.registers[1])

    if denominator == 0 {
        // Divisione per zero
        cpu.registers[0] = numerator < 0 ? 0xFFFFFFFF : 1
        cpu.registers[1] = UInt32(bitPattern: numerator)
        cpu.registers[3] = 1
    } else if denominator == -1 && numerator == Int32.min {
        // Overflow INT32_MIN / -1
        cpu.registers[0] = UInt32(bitPattern: Int32.min)
        cpu.registers[1] = 0
        cpu.registers[3] = UInt32(bitPattern: Int32.min)
    } else {
        let quotient = numerator / denominator
        let remainder = numerator % denominator

        cpu.registers[0] = UInt32(bitPattern: quotient)   // r0 = quoziente
        cpu.registers[1] = UInt32(bitPattern: remainder)  // r1 = resto
        cpu.registers[3] = UInt32(bitPattern: abs(quotient)) // r3 = abs(quotient)
    }

    // TODO: Calcolo cicli per accuratezza
}
```

**Riferimenti**:
- mGBA: `src/gba/bios.c` funzione `_Div()`
- GBATEK: http://problemkaputt.de/gbatek-bios-math-functions.htm

**Checklist**:
- [ ] Implementare in `BIOSMath.swift`
- [ ] Gestire caso divisione per zero
- [ ] Gestire caso INT32_MIN / -1
- [ ] Implementare caso normale
- [ ] Testare tutti i casi limite
- [ ] (Opzionale) Aggiungere conteggio cicli

### 1.4 Implementare CPUSet (0x0B)

**Priorità**: 🔴 CRITICA

**Comportamento**:
```swift
func biosCPUSet(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager) {
    let source = cpu.registers[0]
    let dest = cpu.registers[1]
    let control = cpu.registers[2]

    let count = control & 0x1FFFFF
    let is32bit = (control & (1 << 24)) != 0
    let isFill = (control & (1 << 26)) != 0

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
}
```

**Riferimenti**:
- GBATEK: http://problemkaputt.de/gbatek-bios-memory-copy.htm
- Tonc: https://coranac.com/tonc/text/swi.htm#ssec-swi-cpuset

**Checklist**:
- [ ] Implementare in `BIOSMemory.swift`
- [ ] Supportare mode 16-bit e 32-bit
- [ ] Supportare copy e fill mode
- [ ] Verificare alignment source/destination
- [ ] Testare con vari size e mode
- [ ] Ottimizzazione performance (opzionale)

### 1.5 Implementare CPUFastSet (0x0C)

**Priorità**: 🔴 CRITICA

**Comportamento**:
```swift
func biosCPUFastSet(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager) {
    let source = cpu.registers[0]
    let dest = cpu.registers[1]
    let control = cpu.registers[2]

    let wordCount = control & 0x1FFFFF
    let isFill = (control & (1 << 24)) != 0

    // Count DEVE essere multiplo di 8
    let count = (wordCount / 8) * 8

    if isFill {
        // Fill mode
        let fillValue = memory.read32(address: source)
        for i in 0..<count {
            memory.write32(address: dest + i * 4, value: fillValue)
        }
    } else {
        // Copy mode - copia 8 words alla volta (simula LDMIA/STMIA)
        for i in stride(from: 0, to: count, by: 8) {
            for j in 0..<8 {
                let value = memory.read32(address: source + (i + j) * 4)
                memory.write32(address: dest + (i + j) * 4, value: value)
            }
        }
    }
}
```

**Riferimenti**:
- GBATEK: http://problemkaputt.de/gbatek-bios-memory-copy.htm

**Checklist**:
- [ ] Implementare in `BIOSMemory.swift`
- [ ] Sempre 32-bit (no 16-bit mode)
- [ ] Count deve essere multiplo di 8
- [ ] Verificare word alignment
- [ ] Ottimizzazione: usare bulk copy se possibile

### 1.6 Implementare LZ77UncompWRAM (0x11)

**Priorità**: 🔴 CRITICA - Molti giochi comprimono grafica

**Algoritmo LZ77**:
```
Header: 4 byte
  - Byte 0: Tipo (0x10 = LZ77)
  - Byte 1-3: Dimensione dati decompressi (24-bit)

Block structure:
  - Flag byte (8 bit per 8 blocchi successivi)
  - Per ogni bit in flag:
    - Bit=0: 1 byte literal (non compresso)
    - Bit=1: 2 byte compressed block
      - 12 bit: displacement (-1 to -4096)
      - 4 bit: length (3 to 18 = value + 3)
```

**Implementazione**:
```swift
func biosLZ77UncompWRAM(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager) {
    let source = cpu.registers[0]
    let dest = cpu.registers[1]

    // Leggi header
    let header = memory.read32(address: source)
    let type = UInt8(header & 0xFF)
    let size = header >> 8

    guard type == 0x10 else {
        // Non è LZ77
        return
    }

    var srcPtr = source + 4
    var destPtr = dest
    var remaining = size

    while remaining > 0 {
        // Leggi flag byte
        let flags = memory.read8(address: srcPtr)
        srcPtr += 1

        for bit in 0..<8 {
            guard remaining > 0 else { break }

            if (flags & (0x80 >> bit)) != 0 {
                // Compressed block
                let block = memory.read16(address: srcPtr)
                srcPtr += 2

                let displacement = Int((block & 0x0FFF) >> 0) + 1
                let length = Int((block & 0xF000) >> 12) + 3

                // Copia da buffer precedente
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
}
```

**Riferimenti**:
- mGBA: `src/gba/bios.c` funzione `_unLz77()`
- GBATEK: http://problemkaputt.de/gbatek-bios-decompression-functions.htm

**Checklist**:
- [ ] Implementare in `BIOSDecompression.swift`
- [ ] Gestire header LZ77
- [ ] Implementare decompressione blocchi
- [ ] Gestire displacement e length
- [ ] Testare con dati compressi reali
- [ ] Verificare edge cases (fine dati)
- [ ] Logging per debug

### 1.7 Testing e Validazione Fase 1

**Checklist Finale**:
- [ ] Tutte e 5 le funzioni implementate
- [ ] Test unit per ogni funzione
- [ ] Test con ROM homebrew semplice
- [ ] Logging SWI calls per debug
- [ ] Verificare che non ci siano crash
- [ ] Misurare performance (opzionale)
- [ ] Documentare comportamento osservato

**ROM di Test Consigliate**:
- Tonc demos (usano VBlankIntrWait)
- Homebrew semplici con grafica LZ77
- Test suite emulatori

**Risultato Atteso**:
- Alcuni homebrew dovrebbero partire
- Grafica compressa LZ77 si decomprime
- VBlank sync funziona
- Nessun crash su SWI calls

---

## FASE 2: BIOS HLE Extended (PRIORITÀ ALTA)

**Obiettivo**: Completare funzioni matematiche e utility
**Tempo Stimato**: 1-2 giorni
**Status**: 🟡 In attesa Fase 1
**Dipendenze**: Completamento Fase 1

### 2.1 Funzioni Matematiche

**Da implementare**:

#### Sqrt (0x08)
```swift
func biosSqrt(_ cpu: GBAARM7TDMI) {
    let value = cpu.registers[0]

    // Algoritmo Newton-Raphson o binary search
    var result: UInt32 = 0
    var bit: UInt32 = 1 << 30

    while bit > value {
        bit >>= 2
    }

    while bit != 0 {
        if value >= result + bit {
            value -= result + bit
            result = (result >> 1) + bit
        } else {
            result >>= 1
        }
        bit >>= 2
    }

    cpu.registers[0] = result
}
```

#### ArcTan (0x09) e ArcTan2 (0x0A)
- Usare approssimazione polinomiale
- Fixed-point arithmetic (shift 14 bit)
- Riferimento mGBA per coefficienti

**Checklist**:
- [ ] Implementare Sqrt
- [ ] Implementare ArcTan
- [ ] Implementare ArcTan2
- [ ] Test accuracy vs valori attesi
- [ ] Documentare range e precision

### 2.2 Funzioni System

#### SoftReset (0x00)
```swift
func biosSoftReset() {
    // Reset CPU e memoria
    cpu.reset()
    memory.reset()
    // Salta a entry point
    cpu.registers[15] = 0x08000000
}
```

#### RegisterRamReset (0x01)
```swift
func biosRegisterRamReset(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager) {
    let flags = cpu.registers[0]

    if flags & (1 << 0) != 0 { /* Reset EWRAM */ }
    if flags & (1 << 1) != 0 { /* Reset IWRAM */ }
    if flags & (1 << 2) != 0 { /* Reset Palette */ }
    if flags & (1 << 3) != 0 { /* Reset VRAM */ }
    if flags & (1 << 4) != 0 { /* Reset OAM */ }
    // etc...
}
```

#### Halt (0x02) e Stop (0x03)
```swift
func biosHalt(_ cpu: GBAARM7TDMI) {
    cpu.halted = true
}

func biosStop(_ cpu: GBAARM7TDMI) {
    cpu.stopped = true
}
```

**Checklist**:
- [ ] Implementare SoftReset
- [ ] Implementare RegisterRamReset
- [ ] Implementare Halt
- [ ] Implementare Stop
- [ ] Testare reset completo

### 2.3 IntrWait (0x04)

**Implementazione**:
```swift
func biosIntrWait(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager) {
    let discardOld = cpu.registers[0]
    let interruptMask = cpu.registers[1]

    let ifBiosAddr: UInt32 = 0x03007FF8

    if discardOld != 0 {
        var ifBios = memory.read16(address: ifBiosAddr)
        ifBios &= ~UInt16(interruptMask & 0xFFFF)
        memory.write16(address: ifBiosAddr, value: ifBios)
    }

    cpu.halted = true
}
```

**Checklist**:
- [ ] Implementare IntrWait
- [ ] Supportare tutte le maschere interrupt
- [ ] Testare con timer interrupt
- [ ] Testare con interrupt combinati

### 2.4 Testing e Validazione Fase 2

**Checklist**:
- [ ] Tutte le funzioni Fase 2 implementate
- [ ] Test matematica: Sqrt, ArcTan accuracy
- [ ] Test reset funzionante
- [ ] Test halt/stop comportamento
- [ ] Test IntrWait con vari interrupt
- [ ] Nessuna regressione da Fase 1

---

## FASE 3: Decompressione Completa (PRIORITÀ MEDIA)

**Obiettivo**: Supportare tutti i formati di compressione GBA
**Tempo Stimato**: 2-3 giorni
**Status**: 🟡 In attesa Fase 2
**Dipendenze**: Completamento Fase 2

### 3.1 Algoritmi da Implementare

| Funzione | ID | Algoritmo | Complessità |
|---|---|---|---|
| LZ77UncompVRAM | 0x12 | LZ77 (VRAM target) | Media |
| HuffUnComp | 0x13 | Huffman tree-based | Alta |
| RLUnCompWRAM | 0x14 | Run-Length Encoding | Bassa |
| RLUnCompVRAM | 0x15 | RLE (VRAM target) | Bassa |
| Diff8bitUnFilter | 0x16 | Delta filter 8-bit | Media |
| Diff16bitUnFilter | 0x18 | Delta filter 16-bit | Media |
| BitUnPack | 0x10 | Bit-field extraction | Media |

### 3.2 LZ77UncompVRAM (0x12)

Identico a 0x11 ma scrive in VRAM (0x06000000-0x06018000).

**Nota**: VRAM ha restrizioni speciali su write 8-bit.

**Checklist**:
- [ ] Duplicare logica LZ77
- [ ] Gestire VRAM address range
- [ ] Verificare write restrictions VRAM

### 3.3 Huffman Decompression (0x13)

**Algoritmo**:
- Tree-based decompression
- Variabile bit width (1-32 bit per symbol)
- Complesso da implementare

**Riferimento**: mGBA `_unHuffman()`

**Checklist**:
- [ ] Studiare formato Huffman GBA
- [ ] Implementare tree traversal
- [ ] Gestire variable bit width
- [ ] Testare con dati Huffman reali

### 3.4 Run-Length Encoding (0x14/0x15)

**Algoritmo RLE**:
```
Flag byte:
  - Bit 7=0: Uncompressed run (count-1 literal bytes follow)
  - Bit 7=1: Compressed run (repeat next byte count-3 times)
```

**Implementazione**:
```swift
func biosRLUncomp(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager) {
    let source = cpu.registers[0]
    let dest = cpu.registers[1]

    let header = memory.read32(address: source)
    let type = UInt8(header & 0xFF)
    let size = header >> 8

    guard type == 0x30 else { return }

    var srcPtr = source + 4
    var destPtr = dest
    var remaining = size

    while remaining > 0 {
        let flag = memory.read8(address: srcPtr)
        srcPtr += 1

        let length = Int(flag & 0x7F)

        if (flag & 0x80) != 0 {
            // Compressed run
            let byte = memory.read8(address: srcPtr)
            srcPtr += 1

            for _ in 0..<(length + 3) {
                memory.write8(address: destPtr, value: byte)
                destPtr += 1
                remaining -= 1
            }
        } else {
            // Uncompressed run
            for _ in 0..<(length + 1) {
                let byte = memory.read8(address: srcPtr)
                memory.write8(address: destPtr, value: byte)
                srcPtr += 1
                destPtr += 1
                remaining -= 1
            }
        }
    }
}
```

**Checklist**:
- [ ] Implementare RLUncompWRAM
- [ ] Implementare RLUncompVRAM
- [ ] Testare con dati RLE
- [ ] Verificare edge cases

### 3.5 Delta Filters (0x16/0x18)

**Algoritmo**: Cumulative sum filter
```swift
func biosDiffUnfilter(_ cpu: GBAARM7TDMI, _ memory: GBAMemoryManager, is16bit: Bool) {
    let source = cpu.registers[0]
    let dest = cpu.registers[1]

    let header = memory.read32(address: source)
    let size = header >> 8

    var srcPtr = source + 4
    var destPtr = dest
    var accumulator: UInt32 = 0

    let stride = is16bit ? 2 : 1
    let count = size / UInt32(stride)

    for _ in 0..<count {
        let delta = is16bit ?
            UInt32(memory.read16(address: srcPtr)) :
            UInt32(memory.read8(address: srcPtr))

        accumulator = (accumulator &+ delta) & (is16bit ? 0xFFFF : 0xFF)

        if is16bit {
            memory.write16(address: destPtr, value: UInt16(accumulator))
        } else {
            memory.write8(address: destPtr, value: UInt8(accumulator))
        }

        srcPtr += UInt32(stride)
        destPtr += UInt32(stride)
    }
}
```

**Checklist**:
- [ ] Implementare Diff8bitUnFilter
- [ ] Implementare Diff16bitUnFilter
- [ ] Testare accuracy

### 3.6 BitUnPack (0x10)

**Comportamento**: Estrae campi di bit variabile da source e scrive in dest.

**Riferimento**: mGBA `_unBitPack()`

**Checklist**:
- [ ] Studiare formato BitPack
- [ ] Implementare extraction
- [ ] Testare con dati reali

### 3.7 Testing e Validazione Fase 3

**Checklist**:
- [ ] Tutti gli algoritmi implementati
- [ ] Test con ROM che usano ciascun formato
- [ ] Benchmark decompression speed
- [ ] Nessuna regressione

---

## FASE 4: Affine Transforms (PRIORITÀ MEDIA)

**Obiettivo**: Supportare trasformazioni affini per background e sprite
**Tempo Stimato**: 2-3 giorni
**Status**: 🟡 In attesa Fase 3
**Dipendenze**: Completamento Fase 3

### 4.1 BgAffineSet (0x0E)

**Comportamento**: Calcola matrice affine per background.

**Input**: Struttura con:
- sx, sy: Scaling
- angle: Rotazione (0-65535 = 0-360°)
- centerX, centerY: Centro rotazione

**Output**: Matrice 2x2 affine (pa, pb, pc, pd)

**Riferimento**: mGBA, GBATEK affine math

**Checklist**:
- [ ] Implementare in `BIOSAffine.swift`
- [ ] Calcolo sin/cos con LUT
- [ ] Calcolo matrice affine
- [ ] Testare rotazione e scaling
- [ ] Verificare accuracy vs hardware

### 4.2 ObjAffineSet (0x0F)

Simile a BgAffineSet ma per sprite (OBJ).

**Nota**: Destination pointer offset diverso (8 byte per OBJ vs 2 per BG).

**Checklist**:
- [ ] Implementare ObjAffineSet
- [ ] Gestire offset destination corretto
- [ ] Testare con sprite ruotati

### 4.3 Testing e Validazione Fase 4

**Checklist**:
- [ ] Affine transforms funzionanti
- [ ] Test con giochi che usano rotazione
- [ ] Verificare precisione matematica

---

## FASE 5: Audio e Funzioni Avanzate (PRIORITÀ BASSA)

**Obiettivo**: Completare rimanenti funzioni BIOS
**Tempo Stimato**: 2-3 giorni
**Status**: 🟡 In attesa Fase 4
**Dipendenze**: Completamento Fase 4

### 5.1 Funzioni Audio

| Funzione | ID | Nota |
|---|---|---|
| SoundBias | 0x19 | Configurazione bias audio |
| MidiKey2Freq | 0x1F | Conversione MIDI → frequenza |
| MusicPlayerOpen | 0x20 | Stub (raramente usato) |
| MusicPlayerStart | 0x21 | Stub |
| MusicPlayerStop | 0x22 | Stub |
| MusicPlayerContinue | 0x23 | Stub |
| MusicPlayerFadeOut | 0x24 | Stub |

**Nota**: La maggior parte dei giochi usa audio engine custom, NON le funzioni BIOS.

**Checklist**:
- [ ] Implementare MidiKey2Freq (formula esponenziale)
- [ ] Stub per MusicPlayer functions
- [ ] SoundBias (modifica bias register)

### 5.2 Altre Funzioni

| Funzione | ID | Implementazione |
|---|---|---|
| BiosChecksum | 0x0D | Ritorna checksum costante |
| MultiBoot | 0x25 | Stub (non usato in emulatore) |
| HardReset | 0x26 | Reset completo |
| CustomHalt | 0x27 | Halt custom |

**Checklist**:
- [ ] BiosChecksum: ritorna valore fisso
- [ ] HardReset: reset completo sistema
- [ ] Stub MultiBoot

---

## FASE 6: Testing, Optimization, Polish

**Obiettivo**: Test completi, ottimizzazioni, compatibilità
**Tempo Stimato**: 3-5 giorni
**Status**: 🟡 In attesa Fase 5

### 6.1 Test Suite Completo

**ROM di Test**:
- [ ] Tonc demos (tutte)
- [ ] mGBA test suite
- [ ] AGS aging cartridge
- [ ] Homebrew vari
- [ ] Giochi commerciali popolari:
  - [ ] Pokemon FireRed
  - [ ] The Legend of Zelda: Minish Cap
  - [ ] Metroid Fusion
  - [ ] Super Mario Advance
  - [ ] Golden Sun

### 6.2 Ottimizzazioni Performance

**Aree da ottimizzare**:
- [ ] CPUFastSet: bulk memory operations
- [ ] LZ77: buffer copying ottimizzato
- [ ] IntrWait: cycle accounting
- [ ] Div: fast path per divisioni semplici

**Target**: Mantenere 60 FPS costanti.

### 6.3 Logging e Debug

**Implementare**:
- [ ] Log dettagliato SWI calls (con flag enable/disable)
- [ ] Statistiche uso BIOS functions
- [ ] Performance metrics per funzione
- [ ] Warning per parametri invalidi

### 6.4 Documentazione

**Creare**:
- [ ] Doc API BIOS HLE
- [ ] Guida troubleshooting
- [ ] Note implementazione vs hardware reale
- [ ] Known issues e workarounds

### 6.5 Compatibilità

**Verificare**:
- [ ] Nessuna regressione su funzionalità esistenti
- [ ] PPU funziona con dati decompressi
- [ ] CPU sync corretto con halt/wait
- [ ] Interrupt timing accurato

---

## Timeline Completa

| Fase | Durata | Dipendenze | Status |
|---|---|---|---|
| Fase 1: Core (5 funzioni) | 2-3 giorni | Nessuna | 🔴 TODO |
| Fase 2: Extended | 1-2 giorni | Fase 1 | 🟡 Blocked |
| Fase 3: Decompression | 2-3 giorni | Fase 2 | 🟡 Blocked |
| Fase 4: Affine | 2-3 giorni | Fase 3 | 🟡 Blocked |
| Fase 5: Audio/Misc | 2-3 giorni | Fase 4 | 🟡 Blocked |
| Fase 6: Testing/Polish | 3-5 giorni | Fase 5 | 🟡 Blocked |
| **TOTALE** | **12-19 giorni** | - | - |

---

## Metriche di Successo

### Fase 1 (Minimo Vitale)
- ✅ Almeno 3 homebrew ROM avviabili
- ✅ Grafica LZ77 decompressa correttamente
- ✅ VBlank sync funzionante
- ✅ Zero crash su SWI calls comuni

### Fase 3 (Buona Compatibilità)
- ✅ 50%+ homebrew funzionanti
- ✅ Alcuni giochi commerciali avviabili
- ✅ Tutte le decompressioni funzionanti

### Fase 6 (Alta Compatibilità)
- ✅ 80%+ homebrew funzionanti
- ✅ Maggior parte giochi commerciali giocabili
- ✅ Tutte le 42 funzioni BIOS implementate o stubbed
- ✅ Performance 60 FPS costanti

---

## Note Importanti

### Differenze HLE vs Hardware Reale

**HLE è più veloce**:
- Non emula cicli BIOS instruction-by-instruction
- Chiamate istantanee vs ~60+ cicli hardware
- Alcuni giochi potrebbero rilevare differenze timing

**Soluzione**: Aggiungere cycle stalls dove necessario (mGBA lo fa).

### Registro IF_BIOS (0x03007FF8)

**CRITICO**: Molti emulatori sbagliano questo!
- Games scrivono qui, NON su IF normale (0x04000202)
- BIOS legge da qui per interrupt wait
- Se manca, VBlankIntrWait non funziona

### Debugging Tips

**Log SWI calls**:
```swift
logger.debug("SWI \(String(format: "0x%02X", swiNum)) - r0=\(r0) r1=\(r1) r2=\(r2)")
```

**Verifica parametri**:
- Source/dest addresses validi?
- Sizes ragionevoli?
- Alignment corretto?

**Comparazione con mGBA**:
- Gira stesso ROM in mGBA con log
- Confronta comportamento
- Identifica divergenze

---

## Risorse e Riferimenti

### Codice Sorgente
- **mGBA**: https://github.com/mgba-emu/mgba
  - `src/gba/bios.c` - HLE in C
  - `src/gba/hle-bios.s` - HLE in Assembly
- **Cult-of-GBA**: https://github.com/Cult-of-GBA/BIOS
- **GBA BIOS Disassembly**: https://github.com/camthesaxman/gba_bios

### Documentazione
- **GBATEK**: http://problemkaputt.de/gbatek.htm (LA bibbia GBA)
- **Tonc**: https://coranac.com/tonc/text/toc.htm (Tutorial eccellenti)
- **GBAdev.net**: https://gbadev.net/gbadoc/bios.html (Quick reference)

### Community
- **GBAdev Discord**: https://discord.io/gbadev
- **GBAdev Forum**: https://gbadev.net/forum/
- **/r/EmuDev**: https://reddit.com/r/EmuDev

---

## Prossimi Passi DOPO BIOS HLE

Una volta completato il BIOS HLE, le priorità successive sono:

### 1. PPU Tile Modes (CRITICO)
- Mode 0: 4 tile backgrounds
- Mode 1: 2 tile + 1 affine
- Mode 2: 2 affine backgrounds
- **Senza questo, 95% giochi mostrano schermo nero**

### 2. Input System (CRITICO)
- Keyboard mapping
- KEYINPUT register (0x04000130)
- Controller support
- **Senza questo, impossibile giocare**

### 3. Sprite Rendering (ALTA)
- Sprite pixel rendering
- Priority system
- Affine transforms
- H/V flip

### 4. Audio APU (MEDIA)
- 4 canali PSG
- Direct Sound A/B
- Mixing

### 5. Timer e DMA (MEDIA)
- 4 hardware timers
- DMA controller completo

---

## Changelog

| Data | Versione | Modifiche |
|---|---|---|
| 2024-12-17 | 1.0 | Roadmap iniziale creata |

---

**Autore**: Claude (Anthropic) + Christian Koscielniak Pinto
**Progetto**: Emerald GBA Emulator
**Licenza**: Vedi LICENSE nel root del progetto

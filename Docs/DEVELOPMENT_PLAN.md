# Piano di Sviluppo Operativo - Emerald GBA Emulator

**Aggiornato:** 20 Dicembre 2024
**Status Build:** ✅ Zero errori, zero warning

---

## 📊 STATO ATTUALE

### ✅ Completato (Pronto per uso)

| Componente | % | Note |
|-----------|---|------|
| CPU ARM7TDMI | 100% | 90 istruzioni ARM+Thumb complete |
| BIOS HLE Fase 1 | 100% | 13/42 funzioni (5 critiche + 8 support) |
| Memory Manager | 85% | Tutte le region mappate |
| PPU Bitmap Modes | 100% | Mode 3, 4, 5 funzionanti |
| Metal Renderer | 100% | 60 FPS, 5 shader effects |
| UI/UX | 100% | Native macOS, ROM library completa |

### ❌ Blocchi Critici (Impediscono giocabilità)

| Componente | Impatto | Priorità |
|-----------|---------|----------|
| **PPU Tile Mode 0** | 95% giochi non visibili | 🔴 CRITICA |
| **Input System** | Impossibile giocare | 🔴 CRITICA |
| **Sprite Rendering** | Personaggi invisibili | 🟡 ALTA |

---

## 🎯 OBIETTIVO IMMEDIATO

**Far girare Pokemon Emerald completamente**

Richiede:
1. PPU Tile Mode 0 (background visibili)
2. Input System (controllabile)
3. Sprite Rendering (personaggi visibili)

**Timeline:** 3 settimane

---

## 📅 PIANO SVILUPPO (21 Giorni)

### **Settimana 1: PPU Tile Mode 0** (Giorni 1-10)

#### Giorno 1-2: Setup Base
**File:** `Emerald/Core/PPU/PPUTileModes.swift`

**Modifiche:**
```swift
// 1. Aggiungi struct BackgroundLayer
struct BackgroundLayer {
    var enabled: Bool
    var priority: UInt8
    var charBase: UInt32
    var screenBase: UInt32
    var size: UInt8
    var colorMode: UInt8
    var scrollX: UInt16
    var scrollY: UInt16
}

// 2. Aggiungi in GBAPPU.swift
private var backgrounds: [BackgroundLayer] = Array(repeating: BackgroundLayer(), count: 4)

// 3. Implementa funzione base
func renderMode0Scanline(_ line: Int) {
    // TODO: rendering
}
```

**Test:** Compila senza errori

---

#### Giorno 3-4: Rendering Singolo Background

**File:** `PPUTileModes.swift`

**Aggiungi:**
```swift
func renderBackgroundLayer(_ bg: Int, scanline: Int) {
    let layer = backgrounds[bg]
    guard layer.enabled else { return }

    let scrollY = layer.scrollY
    let inY = (scanline + Int(scrollY)) & 0x1FF

    for x in 0..<240 {
        let pixel = readBackgroundPixel(bg: bg, x: x, y: inY)
        if pixel != 0 {
            framebuffer[scanline * 240 + x] = pixel
        }
    }
}

func readBackgroundPixel(bg: Int, x: Int, y: Int) -> UInt16 {
    // Implementa algoritmo da PPU_IMPLEMENTATION_PLAN.md
    return 0  // TODO
}
```

**Test:** Carica Pokemon, vedi QUALCOSA (anche se sbagliato)

---

#### Giorno 5-6: Scrolling + Multi-Size

**Aggiungi gestione size:**
```swift
var yBase = (tileY & 0x1F) * 32

switch layer.size {
case 2: if tileY >= 32 { yBase += 0x400 }  // 256x512
case 3: if tileY >= 32 { yBase += 0x800 }  // 512x512
default: break
}
```

**Test:** Scrolling funziona? Background si muove?

---

#### Giorno 7-8: 4 Backgrounds + Priorità

**File:** `GBAPPU.swift`

```swift
func renderMode0Scanline(_ line: Int) {
    // Rendering per priorità
    for priority in 0...3 {
        for bg in 0..<4 {
            if backgrounds[bg].priority == priority && backgrounds[bg].enabled {
                renderBackgroundLayer(bg, scanline: line)
            }
        }
    }
}
```

**Test:** Pokemon mostra tutti i layer?

---

#### Giorno 9-10: Bug Fix + Ottimizzazioni

**Controlla:**
- [ ] Flip H/V funzionano
- [ ] 256 colori supportati
- [ ] Wrapping corretto
- [ ] Trasparenza (pixel 0)

**Test:** Pokemon giocabile visivamente?

---

### **Settimana 2: Input System** (Giorni 11-12)

#### Giorno 11: Implementazione Base

**File:** Crea `Emerald/Core/IO/GBAInputController.swift`

**Copia codice da:** `INPUT_SYSTEM_GUIDE.md`

**Modifiche in `EmulatorState.swift`:**
```swift
private var inputController: GBAInputController?

func setupEmulator() {
    // ... esistente ...
    inputController = GBAInputController(memory: memory)
    inputController?.interruptController = interruptController
}

func handleKeyDown(_ keyCode: UInt16) {
    inputController?.handleKeyDown(keyCode)
}

func handleKeyUp(_ keyCode: UInt16) {
    inputController?.handleKeyUp(keyCode)
}
```

**Test:** KEYINPUT register si aggiorna?

---

#### Giorno 12: Event Handling + Test

**File:** `EmulatorScreenView.swift`

**Aggiungi:**
```swift
.onKeyPress(.space) { /* handle */ }
// O usa NSResponder per eventi raw
```

**Test:** Premi A/B, Pokemon reagisce?

---

### **Settimana 2-3: Sprite Rendering** (Giorni 13-19)

#### Giorno 13-14: Preprocessing OAM

**File:** `Emerald/Core/PPU/PPUSprites.swift`

```swift
func preprocessSprites(scanline: Int) -> [OAMEntry] {
    var visible: [OAMEntry] = []

    for i in 0..<128 {
        let sprite = readOAM(index: i)
        if isSpriteVisible(sprite, scanline: scanline) {
            visible.append(sprite)
        }
    }

    return visible.sorted { $0.priority < $1.priority }
}
```

**Test:** Lista sprite visibili corretta?

---

#### Giorno 15-16: Rendering Sprite Normale

**Aggiungi:**
```swift
func renderSprite(_ sprite: OAMEntry, scanline: Int) {
    // Algoritmo da SPRITE_RENDERING_GUIDE.md
}
```

**Test:** Sprite 16-color appaiono?

---

#### Giorno 17: Sprite 256-Color + Flip

**Estendi:**
```swift
if sprite.is256Color {
    // Modalità 256 colori
} else {
    // Modalità 16 colori
}

if sprite.flipH { /* inverti */ }
if sprite.flipV { /* inverti */ }
```

**Test:** Tutti i tipi sprite visibili?

---

#### Giorno 18-19: Sprite Affine + Priorità

**Aggiungi:**
```swift
func renderSpriteAffine(_ sprite: OAMEntry, scanline: Int) {
    // Trasformazione matrice da SPRITE_RENDERING_GUIDE.md
}
```

**Test:** Sprite ruotati corretti?

---

### **Settimana 3: Testing & Polish** (Giorni 20-21)

#### Giorno 20: Testing Completo

**Test Suite:**
- [ ] Pokemon Emerald avviabile
- [ ] Menu navigabili
- [ ] Battle screen visibile
- [ ] Sprite personaggi visibili
- [ ] Scrolling fluido
- [ ] 60 FPS costanti

---

#### Giorno 21: Bug Fix & Ottimizzazioni

**Profiling:**
- Instruments Time Profiler
- Identifica bottleneck
- Ottimizza hot paths

**Target:** 60 FPS su Pokemon Emerald

---

## 🔧 MODIFICHE FILE-BY-FILE

### File da Creare (Nuovi)

```
Emerald/Core/IO/GBAInputController.swift        [NUOVO]
```

### File da Modificare (Esistenti)

```
Emerald/Core/PPU/GBAPPU.swift                   [MODIFICA PESANTE]
  - Aggiungi renderMode0Scanline()
  - Integra backgroundLayers
  - Compositing multi-layer

Emerald/Core/PPU/PPUTileModes.swift             [MODIFICA PESANTE]
  - Implementa rendering tile
  - Lettura VRAM tile data
  - Palette lookup

Emerald/Core/PPU/PPUSprites.swift               [MODIFICA PESANTE]
  - Preprocessing OAM
  - Rendering sprite normali
  - Rendering sprite affine

Emerald/Managers/EmulatorState.swift            [MODIFICA LEGGERA]
  - Integra inputController
  - handleKeyDown/Up

Emerald/Views/Main/EmulatorScreenView.swift     [MODIFICA LEGGERA]
  - Event handling tastiera
```

---

## ⚠️ ATTENZIONE: Problemi Comuni

### 1. Wrapping Coordinate
❌ `if (x >= 256) x = 0`
✅ `x & 0x1FF`

### 2. Active-Low Input
❌ `KEYINPUT = buttonState`
✅ `KEYINPUT = 0x3FF ^ buttonState`

### 3. Trasparenza
❌ Renderizza pixel 0
✅ Salta pixel con index 0

### 4. Priorità
Renderizza da priorità ALTA (3) a BASSA (0)

---

## 📚 Documenti di Riferimento

Durante sviluppo, consulta:

- **PPU:** `PPU_IMPLEMENTATION_PLAN.md`
- **Sprite:** `SPRITE_RENDERING_GUIDE.md`
- **Input:** `INPUT_SYSTEM_GUIDE.md`
- **BIOS:** `BIOS_HLE_ROADMAP.md` (per fasi 2-6 future)

---

## ✅ Checklist Finale (Giorno 21)

- [ ] Pokemon Emerald avvia
- [ ] Menu navigabile con tastiera
- [ ] Battle funziona
- [ ] Sprite personaggi visibili
- [ ] Background scrolling
- [ ] 60 FPS costanti
- [ ] Zero crash
- [ ] Build clean (zero warning)

---

## 🚀 DOPO (Settimana 4+)

### Priorità Future:

1. **BIOS HLE Fasi 2-5** (funzioni mancanti)
2. **Audio APU** (suoni e musica)
3. **Save States** (salva/carica stato)
4. **Ottimizzazioni** (cycle-accurate timing)
5. **Compatibility testing** (altri giochi)

---

**Inizia sviluppo quando sei pronto!** 🎮

## 🎯 ORDINE DI PRIORITÀ (Implementazione Completa e Professionale)

**Priorità basata su: far vedere il gioco PRIMA, ma fatto BENE**

1. ⭐ **PPU Tile Mode 0 COMPLETO** (10 giorni) - Implementazione professionale seguendo mGBA
   - Tutti i background modes
   - Scrolling, wrapping, size
   - Flip H/V, 16/256 colori
   - Multi-layer con priorità
   - Mosaic, trasparenze
   - **Risultato:** Gioco COMPLETAMENTE visibile

2. 🎮 **Input System COMPLETO** (2 giorni) - Implementazione completa
   - KEYINPUT register con active-low
   - KEYCNT interrupt
   - Event handling macOS
   - **Risultato:** Gioco CONTROLLABILE

3. 👾 **Sprite Rendering COMPLETO** (7 giorni) - Implementazione professionale
   - Sprite normali 16/256 color
   - Sprite affine con matrici
   - Priorità vs background
   - Flip, mosaic, trasparenze
   - **Risultato:** Personaggi e UI VISIBILI

**Totale: 19 giorni per gioco COMPLETAMENTE funzionante**

Ogni componente implementato BENE, seguendo i migliori emulatori.

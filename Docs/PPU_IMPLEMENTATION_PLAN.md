# Piano Implementazione PPU Tile Mode 0

**Basato su:** mGBA software-mode0.c, NanoBoyAdvance PPU, SkyEmu
**Riferimenti:** [mGBA source](https://github.com/mgba-emu/mgba/blob/master/src/gba/renderers/software-mode0.c)

---

## 📊 Stato Attuale

✅ **Implementato:**
- Mode 3, 4, 5 (bitmap modes)
- Timing scanline base
- VBlank/HBlank interrupts

❌ **Mancante (CRITICO):**
- Mode 0, 1, 2 (tile-based) ← **BLOCCA 95% DEI GIOCHI**

---

## 🎯 Obiettivo

Implementare **Mode 0** (4 background tile-based) seguendo l'architettura di mGBA.

---

## 📐 Architettura mGBA (Provata e Testata)

### Struttura Generale

```swift
// Per ogni scanline:
func renderScanline(_ line: Int, background: Int) {
    // 1. Calcola coordinate iniziali
    let scrollX = registers.BGxHOFS
    let scrollY = registers.BGxVOFS
    let inY = (line + scrollY) & 0x1FF  // Wrapping 512

    // 2. CACHING: Pre-carica tiledata se Y cambia
    if inY != lastY {
        cacheTileRow(inY, background)
    }

    // 3. Rendering in 3 fasi
    renderPartialTileLeft()   // Bordo sinistro
    renderFullTiles()          // Bulk (la maggior parte)
    renderPartialTileRight()   // Bordo destro
}
```

### Algoritmo Lettura Tile da VRAM

```swift
func renderTile(x: Int, y: Int, bg: Int) -> [UInt16] {
    // 1. Calcolo indirizzo mappa tile
    let mapBase = background.screenBase
    let tileX = x / 8
    let tileY = y / 8

    // Calcolo yBase (critico per size > 256x256)
    var yBase = (tileY & 0x1F) * 32  // Riga nella mappa (32 tile/riga)

    switch background.size {
    case 0: break  // 256x256
    case 1: break  // 512x256
    case 2:  // 256x512
        if tileY >= 32 { yBase += 0x400 }
    case 3:  // 512x512
        if tileY >= 32 { yBase += 0x800 }
    }

    let mapAddr = mapBase + yBase + (tileX & 0x1F)
    let mapEntry = memory.read16(address: mapAddr)

    // 2. Estrazione dati dal map entry
    let tileIndex = mapEntry & 0x3FF
    let paletteBank = (mapEntry >> 12) & 0xF
    let flipH = (mapEntry & 0x400) != 0
    let flipV = (mapEntry & 0x800) != 0

    // 3. Calcolo indirizzo carattere
    let charBase = background.charBase
    let bpp = background.colorMode  // 4 = 16 colori, 8 = 256 colori
    let bytesPerTile = bpp == 4 ? 32 : 64

    var charAddr = charBase + (tileIndex * bytesPerTile)

    // 4. Calcolo offset riga nel tile
    var localY = y % 8
    if flipV { localY = 7 - localY }

    let bytesPerRow = bpp == 4 ? 4 : 8
    charAddr += localY * bytesPerRow

    // 5. Lettura pixel (8 pixel)
    var pixels: [UInt16] = []

    if bpp == 4 {  // 16 colori
        let rowData = memory.read32(address: charAddr)

        for px in 0..<8 {
            let x = flipH ? (7 - px) : px
            let nibble = (rowData >> (x * 4)) & 0xF

            if nibble != 0 {  // 0 = trasparente
                let paletteIndex = (paletteBank * 16) + nibble
                let color = paletteRAM[paletteIndex]
                pixels.append(color)
            } else {
                pixels.append(0)  // Trasparente
            }
        }
    } else {  // 256 colori
        let rowData = memory.read64(address: charAddr)

        for px in 0..<8 {
            let x = flipH ? (7 - px) : px
            let colorIndex = (rowData >> (x * 8)) & 0xFF

            if colorIndex != 0 {
                let color = paletteRAM[colorIndex]
                pixels.append(color)
            } else {
                pixels.append(0)
            }
        }
    }

    return pixels
}
```

---

## 🚀 Piano Implementazione Professionale (10 Giorni)

**IMPORTANTE:** Questa è un'implementazione COMPLETA e PROFESSIONALE seguendo mGBA, non una versione ridotta. Ogni feature va implementata correttamente.

---

## 🎯 Filosofia Implementazione

- ✅ Seguire ESATTAMENTE l'architettura di mGBA
- ✅ Implementare TUTTE le feature (non solo le basi)
- ✅ Codice pulito, commentato, testabile
- ✅ Zero shortcuts o "quick fixes"
- ✅ Test approfonditi ogni giorno
- ❌ NO versioni "minime" o "semplificate"

---

## 🚀 Piano Implementazione (10 Giorni)

### **Fase 1: Setup Base (Giorno 1-2)**

**File da modificare:**
- `Emerald/Core/PPU/GBAPPU.swift`
- `Emerald/Core/PPU/PPUTileModes.swift`

**Cosa fare:**
1. Aggiungi struttura `BackgroundLayer`:
```swift
struct BackgroundLayer {
    var enabled: Bool
    var priority: UInt8
    var charBase: UInt32
    var screenBase: UInt32
    var size: UInt8  // 0-3
    var colorMode: UInt8  // 4 o 8 bpp
    var scrollX: UInt16
    var scrollY: UInt16
    var mosaic: Bool
}
```

2. Implementa `renderMode0Scanline()`
3. Test con background SINGOLO (senza scrolling)

**Test:** Carica ROM, verifica se appare QUALCOSA (anche se sbagliato)

---

### **Fase 2: Scrolling (Giorno 3-4)**

**Cosa fare:**
1. Implementa wrapping coordinate: `(scroll + pos) & 0x1FF`
2. Calcolo `yBase` corretto per size 2 e 3
3. Gestisci tile parziali (bordi)

**Test:** Scrolling funziona? Background si muove?

---

### **Fase 3: 4 Background Layers (Giorno 5-6)**

**Cosa fare:**
1. Loop per BG0, BG1, BG2, BG3
2. Sistema priorità (0-3, più basso = davanti)
3. Compositing layers:
```swift
for priority in 0...3 {
    for bg in [BG0, BG1, BG2, BG3] {
        if bg.priority == priority && bg.enabled {
            renderLayer(bg, scanline)
        }
    }
}
```

**Test:** Giochi con multi-layer (Pokemon, Zelda) mostrano tutti i layer?

---

### **Fase 4: Flip H/V (Giorno 7)**

**Cosa fare:**
1. Gestisci flag flip orizzontale: inverti ordine pixel
2. Gestisci flag flip verticale: inverti riga nel tile

**Test:** Sprite/tile con flip appaiono correttamente?

---

### **Fase 5: 256 Colori (Giorno 8)**

**Cosa fare:**
1. Supporta modalità 8bpp (256 colori)
2. Palette unica (non bank da 16)

**Test:** Giochi con 256-color backgrounds?

---

### **Fase 6: Ottimizzazioni (Giorno 9-10)**

**Cosa fare:**
1. Tile caching (se Y non cambia)
2. Pre-calcolo lookup table per size
3. Profiling con Instruments

**Target:** 60 FPS costanti

---

## ⚠️ Problemi Comuni (da mGBA source)

### 1. **Wrapping Sbagliato**
❌ Errato: `if (x >= 256) x = 0`
✅ Corretto: `x & 0x1FF` (supporta 512)

### 2. **yBase per Size 3 (512x512)**
❌ Errato: `yBase += (y & 0x100)`
✅ Corretto: `yBase += (y & 0x100) << 1`

### 3. **Flip Verticale**
❌ Errato: `localY = 8 - localY`
✅ Corretto: `localY = 7 - localY` (0-7, non 1-8)

### 4. **Trasparenza**
❌ Errato: Renderizza pixel 0
✅ Corretto: Salta pixel con index 0 (è trasparente)

---

## 📚 Riferimenti Codice

**mGBA - software-mode0.c:**
- Linea 1-50: Setup e caching
- Linea 100-200: Rendering tile normale
- Linea 250-300: Flip handling
- Linea 400-450: Size calculation

**Da studiare:**
1. Macro `BACKGROUND_TEXT_SELECT_CHARACTER` (estrazione tile)
2. Macro `BACKGROUND_DRAW_PIXEL_16` (rendering 16 colori)
3. Macro `BACKGROUND_DRAW_PIXEL_256` (rendering 256 colori)

---

## ✅ Checklist Completamento

- [ ] Singolo background renderizza
- [ ] Scrolling funziona
- [ ] 4 backgrounds con priorità
- [ ] Flip H/V corretti
- [ ] 256 colori supportati
- [ ] Size 0,1,2,3 tutti corretti
- [ ] 60 FPS su Pokemon Emerald
- [ ] Nessun glitch grafico evidente

---

**Pronto per iniziare quando vuoi!** 🚀

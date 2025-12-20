# Guida Implementazione Sprite Rendering

**Basato su:** mGBA software-obj.c
**Riferimento:** [mGBA sprites](https://github.com/mgba-emu/mgba/blob/master/src/gba/renderers/software-obj.c)

---

## 📊 Stato Attuale

✅ **Implementato:**
- Parsing OAM (128 sprites)
- Lettura attributi (Attr0, Attr1, Attr2)
- Calcolo size da lookup table

❌ **Mancante (CRITICO):**
- Rendering pixel sprite ← **PERSONAGGI INVISIBILI**
- Priorità sprite vs background
- Trasformazioni affine

---

## 🎯 Obiettivo

Renderizzare sprite (OBJ) seguendo l'algoritmo di mGBA.

---

## 📐 Architettura mGBA

### Struttura OAM Entry

```swift
struct OAMEntry {
    var attr0: UInt16  // Y, mode, mosaic, colors, shape
    var attr1: UInt16  // X, flip, size, affine matrix
    var attr2: UInt16  // tile index, priority, palette
    var attr3: UInt16  // (unused)

    // Estratti
    var y: Int { Int(attr0 & 0xFF) }
    var x: Int {
        let raw = Int(attr1 & 0x1FF)
        return raw >= 256 ? raw - 512 : raw  // Sign-extend
    }

    var shape: Int { Int((attr0 >> 14) & 0x3) }
    var size: Int { Int((attr1 >> 14) & 0x3) }
    var priority: Int { Int((attr2 >> 10) & 0x3) }
    var tileIndex: Int { Int(attr2 & 0x3FF) }
    var paletteBank: Int { Int((attr2 >> 12) & 0xF) }

    var flipH: Bool { (attr1 & 0x1000) != 0 }
    var flipV: Bool { (attr1 & 0x2000) != 0 }
    var is256Color: Bool { (attr0 & 0x2000) != 0 }
    var affineMode: Bool { (attr0 & 0x100) != 0 }
}
```

### Lookup Table Dimensioni

```swift
// mGBA: GBAVideoObjSizes[shape * 4 + size]
let spriteSizes: [[CGSize]] = [
    // Shape 0 (Square)
    [CGSize(width: 8, height: 8),
     CGSize(width: 16, height: 16),
     CGSize(width: 32, height: 32),
     CGSize(width: 64, height: 64)],

    // Shape 1 (Horizontal)
    [CGSize(width: 16, height: 8),
     CGSize(width: 32, height: 8),
     CGSize(width: 32, height: 16),
     CGSize(width: 64, height: 32)],

    // Shape 2 (Vertical)
    [CGSize(width: 8, height: 16),
     CGSize(width: 8, height: 32),
     CGSize(width: 16, height: 32),
     CGSize(width: 32, height: 64)]
]

func getSpriteSize(shape: Int, size: Int) -> CGSize {
    return spriteSizes[shape][size]
}
```

---

## 🔑 Algoritmo Rendering (da mGBA)

### Fase 1: Preprocessing

```swift
func preprocessSprites(scanline: Int) -> [OAMEntry] {
    var visibleSprites: [OAMEntry] = []

    for i in 0..<128 {
        let sprite = oam[i]
        let size = getSpriteSize(shape: sprite.shape, size: sprite.size)

        // Sprite visibile su questa scanline?
        var spriteY = sprite.y
        if spriteY >= 160 { spriteY -= 256 }  // Sign-extend

        if scanline >= spriteY && scanline < spriteY + Int(size.height) {
            visibleSprites.append(sprite)
        }
    }

    // Ordina per priorità (rendering order)
    visibleSprites.sort { $0.priority < $1.priority }

    return visibleSprites
}
```

### Fase 2: Rendering Sprite Normale

```swift
func renderSprite(_ sprite: OAMEntry, scanline: Int) {
    let size = getSpriteSize(shape: sprite.shape, size: sprite.size)
    let width = Int(size.width)
    let height = Int(size.height)

    // Calcolo Y locale nel sprite
    var localY = scanline - sprite.y
    if sprite.flipV { localY = height - 1 - localY }

    // Tile organization
    let tileRow = localY / 8
    let pixelY = localY % 8

    // Dimensioni in tile
    let tilesWide = width / 8
    let tilesHigh = height / 8

    // Rendering orizzontale
    for x in 0..<width {
        var localX = x
        if sprite.flipH { localX = width - 1 - x }

        let tileCol = localX / 8
        let pixelX = localX % 8

        // Calcolo tile index
        var tileIndex = sprite.tileIndex

        if sprite.is256Color {
            // 256 colori: tile 1D mapping
            tileIndex += tileRow * tilesWide * 2 + tileCol * 2
        } else {
            // 16 colori: tile 1D mapping
            tileIndex += tileRow * tilesWide + tileCol
        }

        // Lettura pixel da VRAM
        let pixel = readSpritePixel(
            tileIndex: tileIndex,
            x: pixelX,
            y: pixelY,
            is256Color: sprite.is256Color
        )

        if pixel != 0 {  // 0 = trasparente
            let color = sprite.is256Color ?
                paletteRAM[0x100 + pixel] :  // Sprite palette
                paletteRAM[0x100 + sprite.paletteBank * 16 + pixel]

            // Check priorità prima di scrivere
            let screenX = sprite.x + x
            if screenX >= 0 && screenX < 240 {
                if sprite.priority <= backgroundPriority[scanline][screenX] {
                    framebuffer[scanline * 240 + screenX] = color
                }
            }
        }
    }
}
```

### Fase 3: Lettura Pixel da VRAM

```swift
func readSpritePixel(tileIndex: Int, x: Int, y: Int, is256Color: Bool) -> Int {
    // Sprite tiles iniziano a 0x10000 in VRAM
    let spriteBase: UInt32 = 0x06010000

    if is256Color {
        // 256 colori: 64 byte per tile (8x8 pixel, 1 byte/pixel)
        let tileAddr = spriteBase + UInt32(tileIndex * 64)
        let offset = y * 8 + x
        return Int(vram.read8(address: tileAddr + UInt32(offset)))

    } else {
        // 16 colori: 32 byte per tile (8x8 pixel, 4 bit/pixel)
        let tileAddr = spriteBase + UInt32(tileIndex * 32)
        let offset = y * 4 + x / 2  // 2 pixel per byte
        let byte = vram.read8(address: tileAddr + UInt32(offset))

        // Estrai nibble
        if x & 1 == 0 {
            return Int(byte & 0xF)  // Nibble basso
        } else {
            return Int(byte >> 4)   // Nibble alto
        }
    }
}
```

### Fase 4: Sprite Affine (Rotazione/Scaling)

```swift
func renderSpriteAffine(_ sprite: OAMEntry, scanline: Int) {
    // Leggi matrice affine da OAM
    let matrixIndex = (sprite.attr1 >> 9) & 0x1F
    let matrixBase = matrixIndex * 16  // 4 entries * 4 byte

    let pa = readOAMMatrix(base: matrixBase, offset: 0)  // dx
    let pb = readOAMMatrix(base: matrixBase, offset: 1)  // dmx
    let pc = readOAMMatrix(base: matrixBase, offset: 2)  // dy
    let pd = readOAMMatrix(base: matrixBase, offset: 3)  // dmy

    let size = getSpriteSize(shape: sprite.shape, size: sprite.size)
    let width = Int(size.width)
    let height = Int(size.height)

    // Centro sprite
    let centerX = width / 2
    let centerY = height / 2

    let localY = scanline - sprite.y - centerY

    for x in 0..<width {
        let localX = x - centerX

        // Trasformazione affine (fixed-point math)
        var texX = (pa * localX + pb * localY) >> 8
        var texY = (pc * localX + pd * localY) >> 8

        texX += centerX
        texY += centerY

        // Bounds check
        if texX >= 0 && texX < width && texY >= 0 && texY < height {
            // Renderizza pixel come sprite normale
            let pixel = readSpritePixelAtTexCoord(texX, texY)
            if pixel != 0 {
                let screenX = sprite.x + x
                if screenX >= 0 && screenX < 240 {
                    framebuffer[scanline * 240 + screenX] = pixel
                }
            }
        }
    }
}

func readOAMMatrix(base: Int, offset: Int) -> Int16 {
    let addr = base + offset * 8 + 6  // Attr3 di ogni entry
    let raw = oam.read16(address: UInt32(addr))
    return Int16(bitPattern: raw)  // Signed 16-bit
}
```

---

## 🚀 Piano Implementazione (7 Giorni)

### **Giorno 1-2: Rendering Base**
- [ ] Implementa `preprocessSprites()`
- [ ] Implementa `renderSprite()` normale
- [ ] Test: sprite 16 colori appare?

### **Giorno 3: Flip H/V**
- [ ] Gestisci flip orizzontale/verticale
- [ ] Test: sprite flippati corretti?

### **Giorno 4: 256 Colori**
- [ ] Supporta modalità 256-color
- [ ] Test: sprite con palette estesa?

### **Giorno 5-6: Affine**
- [ ] Implementa trasformazioni affine
- [ ] Lettura matrici da OAM
- [ ] Test: sprite ruotati/scalati?

### **Giorno 7: Priorità**
- [ ] Sistema priorità sprite vs background
- [ ] Layer compositing corretto
- [ ] Test: sprite dietro/davanti backgrounds?

---

## ⚠️ Problemi Comuni

### 1. **Coordinate Negative**
❌ Errato: `x = attr1 & 0x1FF`
✅ Corretto: Sign-extend se > 255

### 2. **Tile Index 1D Mapping**
Per sprite 64x64 (8x8 tile):
- Tile (0,0) = baseIndex + 0
- Tile (1,0) = baseIndex + 2 (256-color) o +1 (16-color)
- Tile (0,1) = baseIndex + 16 (8 tile wide * 2)

### 3. **Trasparenza**
Pixel 0 è SEMPRE trasparente (non renderizzare)

### 4. **VRAM Sprite Base**
Sprite tiles iniziano a **0x06010000** (non 0x06000000)

---

## 📚 Riferimenti mGBA

**software-obj.c:**
- Linea 50-100: Preprocessing OAM
- Linea 150-250: Rendering normale
- Linea 300-400: Rendering affine
- Linea 450-500: Priorità

---

## ✅ Checklist

- [ ] Sprite 16-color renderizzano
- [ ] Sprite 256-color renderizzano
- [ ] Flip H/V funzionano
- [ ] Sprite affine ruotano correttamente
- [ ] Priorità rispettata vs background
- [ ] Nessun glitch su Pokemon/Zelda
- [ ] 60 FPS con 128 sprite

---

**Pronto per gli sprite!** 👾

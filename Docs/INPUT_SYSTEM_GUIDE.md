# Guida Implementazione Input System

**Basato su:** mGBA io.c, GBATEK
**Riferimento:** [GBATEK Keypad](http://problemkaputt.de/gbatek-gba-keypad-input.htm)

---

## 📊 Stato Attuale

✅ **Implementato:**
- Settings con key mapping
- Struttura base

❌ **Mancante (CRITICO):**
- Cattura eventi tastiera ← **IMPOSSIBILE GIOCARE**
- Aggiornamento registro KEYINPUT
- Interrupt da tastiera

---

## 🎯 Obiettivo

Implementare input system completo con logica active-low del GBA.

---

## 📐 Architettura GBA Input

### Registri Hardware

```swift
// 0x04000130 - KEYINPUT (Read-only, 16-bit)
// Active-low: 0 = premuto, 1 = rilasciato

struct KeypadRegisters {
    var KEYINPUT: UInt16 = 0x3FF  // Tutti rilasciati all'inizio
    var KEYCNT: UInt16 = 0        // Interrupt control
}

// Bit mapping
enum GBAButton: UInt16 {
    case A      = 0x0001  // Bit 0
    case B      = 0x0002  // Bit 1
    case SELECT = 0x0004  // Bit 2
    case START  = 0x0008  // Bit 3
    case RIGHT  = 0x0010  // Bit 4
    case LEFT   = 0x0020  // Bit 5
    case UP     = 0x0040  // Bit 6
    case DOWN   = 0x0080  // Bit 7
    case R      = 0x0100  // Bit 8
    case L      = 0x0200  // Bit 9
}
```

### Logica Active-Low (da mGBA)

```swift
// mGBA: 0x3FF ^ input
// Converte da logic positiva (1=premuto) a logic negativa GBA (0=premuto)

func updateKEYINPUT(_ pressedButtons: UInt16) {
    // pressedButtons: bit set = tasto premuto (logica normale)
    // KEYINPUT: bit clear = tasto premuto (logica GBA)

    var value = 0x3FF ^ pressedButtons  // Inverti

    // Previeni direzioni opposte simultanee
    let lr = value & 0x030  // Left + Right
    let ud = value & 0x0C0  // Up + Down

    if lr == 0x030 { value &= ~0x030 }  // Entrambi premuti = nessuno
    if ud == 0x0C0 { value &= ~0x0C0 }

    memory.ioRegisters[0x130] = value
}
```

---

## 🔑 Implementazione Swift

### File da Creare/Modificare

**1. `Emerald/Core/IO/GBAInputController.swift`**

```swift
import Foundation
import AppKit
import OSLog

final class GBAInputController {
    private let logger = Logger(subsystem: "com.emerald.gba", category: "Input")

    private weak var memory: GBAMemoryManager?
    weak var interruptController: GBAInterruptController?

    // Stato corrente (logica positiva interna)
    private var buttonState: UInt16 = 0  // 0 = tutti rilasciati
    private var lastButtonState: UInt16 = 0

    // Key mapping (da settings)
    private var keyMapping: [UInt16: GBAButton] = [:]

    init(memory: GBAMemoryManager) {
        self.memory = memory
        loadDefaultKeyMapping()
    }

    private func loadDefaultKeyMapping() {
        // NSEvent.keyCode -> GBAButton
        keyMapping = [
            6: .A,       // Z
            7: .B,       // X
            51: .SELECT, // Delete/Backspace
            36: .START,  // Return
            124: .RIGHT, // Arrow Right
            123: .LEFT,  // Arrow Left
            126: .UP,    // Arrow Up
            125: .DOWN,  // Arrow Down
            15: .R,      // R
            37: .L       // L
        ]
    }

    func handleKeyDown(_ keyCode: UInt16) {
        guard let button = keyMapping[keyCode] else { return }

        // Set bit (logica positiva interna)
        buttonState |= button.rawValue

        updateKEYINPUT()
        checkKeypadInterrupt()

        logger.debug("Key down: \(button) - state: \(String(format: "%03X", buttonState))")
    }

    func handleKeyUp(_ keyCode: UInt16) {
        guard let button = keyMapping[keyCode] else { return }

        // Clear bit
        buttonState &= ~button.rawValue

        updateKEYINPUT()

        logger.debug("Key up: \(button) - state: \(String(format: "%03X", buttonState))")
    }

    private func updateKEYINPUT() {
        guard let memory = memory else { return }

        // Converti da logica positiva a active-low GBA
        var value = 0x3FF ^ buttonState

        // Previeni direzioni opposte
        let lr = buttonState & 0x030
        let ud = buttonState & 0x0C0

        if lr == 0x030 { value |= 0x030 }  // Entrambi = nessuno premuto
        if ud == 0x0C0 { value |= 0x0C0 }

        // Scrivi registro KEYINPUT (0x04000130)
        memory.write16(address: 0x04000130, value: value)
    }

    private func checkKeypadInterrupt() {
        guard let memory = memory else { return }
        guard let interrupts = interruptController else { return }

        // Leggi KEYCNT (0x04000132)
        let keycnt = memory.read16(address: 0x04000132)

        // Interrupt abilitato?
        guard (keycnt & 0x4000) != 0 else { return }

        let keyMask = keycnt & 0x3FF
        let andMode = (keycnt & 0x8000) != 0

        var shouldFire = false

        if andMode {
            // AND mode: tutti i tasti specificati devono essere premuti
            shouldFire = (buttonState & keyMask) == keyMask
        } else {
            // OR mode: almeno un tasto specificato premuto
            shouldFire = (buttonState & keyMask) != 0
        }

        if shouldFire {
            interrupts.requestInterrupt(.keypad)
            logger.info("Keypad interrupt fired")
        }
    }

    func reset() {
        buttonState = 0
        lastButtonState = 0
        updateKEYINPUT()
    }
}
```

**2. `Emerald/Views/Main/EmulatorScreenView.swift` - Aggiungi Event Handling**

```swift
import SwiftUI
import AppKit

struct EmulatorScreenView: View {
    @ObservedObject var emulatorState: EmulatorState

    var body: some View {
        MetalView()
            .focusable()
            .onAppear {
                // Focus view per ricevere eventi
                NSApp.activate(ignoringOtherApps: true)
            }
    }
}

// NSViewRepresentable per catturare eventi
struct MetalView: NSViewRepresentable {
    func makeNSView(context: Context) -> MetalGameView {
        let view = MetalGameView()
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: MetalGameView, context: Context) {}
}

class MetalGameView: NSView {
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Trova EmulatorState e invia evento
        if let window = self.window,
           let contentView = window.contentView as? NSHostingView<AnyView>,
           let emulatorState = getEmulatorState(from: contentView) {
            emulatorState.handleKeyDown(event.keyCode)
        }
    }

    override func keyUp(with event: NSEvent) {
        if let window = self.window,
           let contentView = window.contentView as? NSHostingView<AnyView>,
           let emulatorState = getEmulatorState(from: contentView) {
            emulatorState.handleKeyUp(event.keyCode)
        }
    }

    private func getEmulatorState(from view: NSView) -> EmulatorState? {
        // Helper per trovare EmulatorState
        // (dipende dalla tua architettura SwiftUI)
        return nil  // TODO: implementa lookup
    }
}
```

**3. `Emerald/Managers/EmulatorState.swift` - Integra Input**

```swift
final class EmulatorState: ObservableObject {
    // ... esistente ...

    private var inputController: GBAInputController?

    func setupEmulator() {
        // ... setup esistente ...

        inputController = GBAInputController(memory: memory)
        inputController?.interruptController = interruptController
    }

    func handleKeyDown(_ keyCode: UInt16) {
        inputController?.handleKeyDown(keyCode)
    }

    func handleKeyUp(_ keyCode: UInt16) {
        inputController?.handleKeyUp(keyCode)
    }
}
```

---

## 🚀 Piano Implementazione (2 Giorni)

### **Giorno 1: Setup Base**
- [ ] Crea `GBAInputController.swift`
- [ ] Implementa logica active-low
- [ ] Integra in `EmulatorState`
- [ ] Test: scrive correttamente KEYINPUT?

### **Giorno 2: Event Handling**
- [ ] Cattura eventi NSEvent in MetalView
- [ ] Routing a EmulatorState
- [ ] Key mapping configurabile
- [ ] Test: premi tasto, ROM riceve input?

---

## ⚠️ Problemi Comuni

### 1. **Focus Management**
SwiftUI views devono essere `.focusable()` e ricevere first responder

### 2. **Active-Low Confusion**
```
Tasto A premuto:
- buttonState interno = 0x0001 (bit set)
- KEYINPUT registro = 0x3FE (bit 0 clear)
```

### 3. **Direzioni Opposte**
Hardware GBA non permette Left+Right o Up+Down simultanei

### 4. **Read-Once per Frame**
Tutorial GBA consigliano leggere KEYINPUT una volta per frame (inizio o fine)

---

## 📚 Riferimenti

- mGBA `io.c` - Linea 200-250: KEYINPUT handling
- [GBATEK Keypad](http://problemkaputt.de/gbatek-gba-keypad-input.htm)
- [Kyle Halladay Tutorial](https://kylehalladay.com/blog/tutorial/gba/2017/04/18/GBA-By-Example-4.html)

---

## ✅ Checklist

- [ ] Eventi tastiera catturati
- [ ] KEYINPUT aggiornato (active-low)
- [ ] Direzioni opposte bloccate
- [ ] Keypad interrupt funziona
- [ ] Key mapping configurabile
- [ ] Test con ROM (menu navigabile?)

---

**Input pronto in 2 giorni!** 🎮

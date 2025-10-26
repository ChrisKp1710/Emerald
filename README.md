# 🎮 Emerald - Game Boy Advance Emulator

<div align="center">

![Status](https://img.shields.io/badge/Status-Alpha-yellow)
![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

**A modern, native GBA emulator for macOS built with Swift and SwiftUI**

[Features](#-features) • [Status](#-development-status) • [Documentation](#-documentation) • [Building](#-building) • [Roadmap](#-roadmap)

</div>

---

## 📝 Overview

Emerald is a Game Boy Advance emulator written from scratch in Swift, leveraging Apple's modern frameworks:
- **SwiftUI 4** for native macOS UI
- **Metal 3** for GPU-accelerated rendering
- **Core Audio** for low-latency audio
- **MVVM architecture** for clean, maintainable code

### Current Status: **Alpha** (v0.1.0)

✅ **Fully Implemented:** UI, ROM management, settings, Metal rendering  
🟡 **Partially Working:** CPU execution, memory system  
🔴 **Not Yet Working:** Graphics rendering, input, audio  

**Bottom line:** The emulator runs but shows a black screen because the PPU (graphics) isn't rendering yet.

---

## ✨ Features

### ✅ **Currently Working**

#### **User Interface**
- 🪟 Native macOS windows (main emulator, ROM library, settings)
- 🎨 Metal-accelerated rendering with 5 shader effects
- 📊 Real-time FPS counter
- 🐛 **Debug log console** (⌘` to toggle)
- 🎚️ Comprehensive settings panel
- 🖱️ Drag & drop ROM loading

#### **ROM Management**
- 📚 Full ROM library with metadata
- 🔍 Search and filter by category
- 📊 Grid and list view modes
- ⭐ Favorites and ratings
- 🕐 Play time tracking
- 💾 Battery save (.sav) support

#### **Rendering Pipeline**
- 🎮 240×160 GBA screen with correct aspect ratio
- 🎨 5 shader effects:
  - Pixel-perfect (nearest neighbor)
  - CRT effect (curvature, scanlines, vignette)
  - Scanlines only
  - Smooth scaling (bilinear)
  - Color correction (gamma + saturation)
- 🔄 VSync support
- 📏 Scalable window (1× to 6×)

#### **Architecture**
- 🏗️ Clean modular structure (14 organized folders)
- 🧩 MVVM pattern with SwiftUI
- 📦 Separated concerns (Core, Views, Models, Managers)
- 🔧 Professional code organization

### 🟡 **Partially Implemented**

#### **CPU - ARM7TDMI** (80% complete)
- ✅ Full ARM instruction set
- ✅ Complete THUMB instruction set
- ✅ 3-stage pipeline (Fetch, Decode, Execute)
- ✅ All 7 CPU modes
- ✅ Condition codes and barrel shifter
- ⚠️ Not fully tested with real games

#### **Memory System** (85% complete)
- ✅ All memory regions (BIOS, IWRAM, EWRAM, VRAM, etc.)
- ✅ Cartridge ROM mapping
- ✅ Save RAM detection (Flash/SRAM/EEPROM)
- ⚠️ I/O registers don't trigger hardware actions yet

### 🔴 **Not Yet Implemented**

- ❌ **PPU Graphics Rendering** (critical - shows blank screen)
- ❌ **Input System** (keyboard events not captured)
- ❌ **APU Audio** (no sound generation)
- ❌ **DMA Transfers** (stub only)
- ❌ **Timer System** (not counting)
- ❌ **Save States** (UI exists but not functional)

---

## 📊 Development Status

| Component         | Status | Progress | Notes                          |
|-------------------|--------|----------|--------------------------------|
| UI Framework      | ✅     | 100%     | Fully working                  |
| ROM Management    | ✅     | 100%     | Fully working                  |
| Metal Rendering   | ✅     | 100%     | Shaders working                |
| Settings System   | ✅     | 100%     | Persistent settings            |
| CPU (ARM7TDMI)    | 🟡     | 80%      | Implemented, needs testing     |
| Memory Manager    | 🟡     | 85%      | Works, needs I/O integration   |
| **PPU (Graphics)**| 🔴     | 10%      | **Critical: Not rendering**    |
| **Input System**  | 🔴     | 5%       | **Critical: Not working**      |
| APU (Audio)       | 🔴     | 5%       | Not generating sound           |
| DMA Controller    | 🔴     | 20%      | Stub only                      |
| Interrupts        | 🟡     | 50%      | Partially working              |
| **Overall**       | 🟡     | **45%**  | **Alpha stage**                |

**See [Docs/PROJECT_STATUS.md](Docs/PROJECT_STATUS.md) for detailed status.**

---

## 🎯 What Happens When You Load a ROM?

1. ✅ ROM loads successfully and appears in library
2. ✅ Emulation loop starts at 60 FPS
3. ✅ CPU executes ARM/THUMB instructions from ROM
4. ✅ Game code writes to VRAM, palette, OAM
5. ❌ **PPU shows black screen instead of graphics**
6. ❌ **Input doesn't work (keyboard not connected)**
7. ❌ **No sound (APU silent)**

**Result:** Black screen at 60 FPS. Game is "running blind" but not visible.

---

## 📚 Documentation

- **[Docs/PROJECT_STATUS.md](Docs/PROJECT_STATUS.md)** - Detailed project status
- **[Docs/LOG_CONSOLE_GUIDE.md](Docs/LOG_CONSOLE_GUIDE.md)** - Using the debug console
- **[Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md)** - Code architecture
- **[Docs/START_HERE.md](Docs/START_HERE.md)** - Quick start guide
- **[Docs/XCODE_TUTORIAL.md](Docs/XCODE_TUTORIAL.md)** - Building guide

---

## 🔨 Building

### Requirements
- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later
- Swift 5.9

### Build Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/emerald.git
   cd emerald
   ```

2. **Open in Xcode**
   ```bash
   open Emerald.xcodeproj
   ```

3. **Build and Run**
   - Press `⌘R` or click the Play button
   - Select "Emerald" scheme
   - Build for "My Mac (Apple Silicon)" or "My Mac (Intel)"

4. **Load a ROM**
   - Click "Open ROM..." or drag a .gba file
   - ROM appears in library
   - Currently shows black screen (PPU not implemented)

---

## 🗺️ Roadmap

### Phase 1: Core Functionality (Current)
- [x] Project setup and architecture
- [x] UI framework (SwiftUI)
- [x] ROM library management
- [x] Metal rendering pipeline
- [x] CPU implementation (ARM7TDMI)
- [x] Memory system
- [ ] **PPU graphics rendering** ← **NEXT PRIORITY**
- [ ] **Input system** ← **NEXT PRIORITY**
- [ ] CPU testing and bug fixes

### Phase 2: Playability
- [ ] APU audio implementation
- [ ] DMA transfers
- [ ] Timer system
- [ ] Interrupt fixes
- [ ] Save state functionality
- [ ] Homebrew game testing

### Phase 3: Compatibility
- [ ] Commercial game testing
- [ ] CPU cycle accuracy
- [ ] PPU timing accuracy
- [ ] Audio sync improvements
- [ ] BIOS HLE refinement

### Phase 4: Features
- [ ] Game controller support
- [ ] Cheats/GameShark
- [ ] Netplay (link cable emulation)
- [ ] Recording/replay
- [ ] Debugger UI

---

## 📂 Project Structure

```
Emerald/
├── Emerald/                      # Main source code
│   ├── Core/                     # Emulator core
│   │   ├── CPU/                  # ARM7TDMI processor
│   │   ├── Memory/               # Memory management
│   │   ├── Graphics/             # PPU and components
│   │   ├── Audio/                # APU audio engine
│   │   └── IO/                   # Input/interrupts
│   ├── Views/                    # SwiftUI views
│   │   ├── Main/                 # Main emulator view
│   │   ├── Library/              # ROM library view
│   │   └── Settings/             # Settings panel
│   ├── Models/                   # Data models
│   ├── Managers/                 # State management
│   ├── Rendering/                # Metal renderer
│   └── Utilities/                # Helper code
├── Docs/                         # Documentation
└── README.md                     # This file
```

**See [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md) for detailed architecture.**

---

## 🚀 Next Steps

### Immediate Priorities

1. **Implement PPU Rendering** (Est: 3-5 days)
   - Read tiles from VRAM
   - Implement palette lookup
   - Render backgrounds (Mode 0)
   - Render sprites (OBJ layer)
   - → **Games become visible!** 🎨

2. **Implement Input System** (Est: 1 day)
   - Capture keyboard events
   - Map to GBA buttons
   - Update KEYINPUT register
   - → **Games become playable!** 🎮

3. **Fix CPU Bugs** (Est: 2-3 days)
   - Test with ARM/THUMB test ROMs
   - Debug instruction errors
   - → **Games run correctly!** ✅

---

## 🐛 Known Issues

1. **No graphics rendering** - PPU stub shows black screen
2. **Input not working** - Keyboard events not captured
3. **No audio** - APU not generating sound
4. **Untested CPU** - May have instruction bugs
5. **No save states** - UI exists but not functional

---

## 🤝 Contributing

This is currently a personal learning project. Contributions, suggestions, and feedback are welcome!

---

## 📄 License

MIT License - See [LICENSE](LICENSE) for details

---

## 🙏 Acknowledgments

- GBA hardware documentation from [GBATEK](https://problemkaputt.de/gbatek.htm)
- Inspiration from existing emulators (VisualBoyAdvance, mGBA, NanoBoyAdvance)
- Apple's Metal and Core Audio frameworks

---

<div align="center">

**Made with ❤️ in Swift**

[Report Bug](https://github.com/yourusername/emerald/issues) • [Request Feature](https://github.com/yourusername/emerald/issues)

</div>

# 🎮 Emerald GBA Emulator

<div align="center">

![Status](https://img.shields.io/badge/Status-Alpha-yellow)
![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-Proprietary-red)

**A professional, native macOS Game Boy Advance emulator built with Swift and SwiftUI**

[Features](#-features) • [Status](#-development-status) • [Architecture](#-architecture) • [Roadmap](#-roadmap) • [License](#-license)

</div>

---

## 📝 Overview

Emerald is a high-performance Game Boy Advance emulator designed exclusively for macOS. Built from the ground up with modern Swift and SwiftUI, it aims to provide an authentic GBA gaming experience with a clean, native macOS interface.
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
## � Development Status

**Current Version:** 0.1.0 Alpha  
**Last Updated:** October 27, 2025

### ✅ **Completed** (100%)

#### **UI/UX Framework**
- ✅ Professional native macOS design
- ✅ Responsive sidebar with category filters
- ✅ ROM library with search and grid view
- ✅ Toolbar with responsive layout
- ✅ Settings panel
- ✅ Debug log console with filtering
- ✅ Drag & Drop ROM support

#### **ROM Management**
- ✅ Sandbox-compliant file loading (NSOpenPanel)
- ✅ Security-scoped bookmark persistence
- ✅ Battery backup (SRAM) support
- ✅ ROM metadata extraction
- ✅ Category system (RPG, Action, Puzzle, etc.)
- ✅ Search and filtering

#### **Core Architecture**
- ✅ EmulatorState management
- ✅ Component structure (CPU, PPU, APU, Memory)
- ✅ Metal renderer setup
- ✅ Audio engine foundation
- ✅ Clean separation of concerns

### 🟡 **In Progress** (30%)

#### **CPU - ARM7TDMI**
- ✅ Register system (R0-R15, banked registers)
- ✅ Basic structure and modes
- ✅ PC initialization (0x08000000)
- ✅ Branch offset correction
- ⚠️ **TODO:** ARM instruction set (~60 instructions)
- ⚠️ **TODO:** Thumb instruction set (~40 instructions)
- ⚠️ **TODO:** Pipeline simulation
- ⚠️ **TODO:** Condition code handling

#### **Memory Manager**
- ✅ IWRAM, EWRAM, VRAM structure
- ✅ Cartridge ROM mapping
- ⚠️ **TODO:** Complete I/O register handling
- ⚠️ **TODO:** DMA transfers

### 🔴 **Not Implemented** (0%)

- ❌ **PPU (Picture Processing Unit)**
  - Background rendering (modes 0-5)
  - Sprite rendering (OBJ)
  - Window effects
  - Blending and effects

- ❌ **APU (Audio Processing Unit)**
  - 4 sound channels
  - Direct Sound (A/B)
  - Audio mixing

- ❌ **Input System**
  - Keyboard controls
  - Controller support
  - Key mapping

- ❌ **Timers & Interrupts**
  - 4 hardware timers
  - Complete interrupt handling

- ❌ **Advanced Features**
  - Save states
  - Fast forward
  - Frame skip
  - Rewind

---

## 📊 Current Focus

**Phase 1: Complete CPU** ← **CURRENT PRIORITY** 🎯

Goal: Implement all ARM7TDMI instructions to achieve accurate CPU emulation.

### Roadmap

#### Phase 1: CPU Implementation (In Progress)
**Goal:** 100% functional ARM7TDMI processor

- [ ] Implement all ARM instructions (~60)
- [ ] Implement all Thumb instructions (~40)
- [ ] CPU pipeline simulation
- [ ] Pass ARM7TDMI test suites
- [ ] Cycle-accurate timing

#### Phase 2: Graphics & Display
**Goal:** See games rendering on screen

- [ ] Implement PPU mode 3 (simplest - 240x160 bitmap)
- [ ] Sprite rendering (OBJ)
- [ ] Background layers (modes 0-2)
- [ ] VRAM access patterns
- [ ] Timing and V-blank

#### Phase 3: Audio & Input
**Goal:** Make games playable

- [ ] Basic audio output (4 channels)
- [ ] Keyboard controls
- [ ] Controller support
- [ ] Audio mixing

#### Phase 4: Advanced Features
**Goal:** Full-speed, feature-complete emulation

- [ ] Save states (quick save/load)
- [ ] DMA transfers
- [ ] Timer system
- [ ] Fast forward
- [ ] Frame skip
- [ ] Rewind

#### Phase 5: Polish & Release
**Goal:** App Store submission

- [ ] Performance optimization
- [ ] UI refinements
- [ ] Comprehensive testing
- [ ] Documentation
- [ ] App Store preparation

---

## 📚 Technical Details

### CPU Emulation
- **Processor:** ARM7TDMI @ 16.78 MHz
- **Instruction Sets:** ARM (32-bit), Thumb (16-bit)
- **Registers:** 16 general-purpose + CPSR/SPSR
- **Modes:** User, FIQ, IRQ, Supervisor, Abort, Undefined, System

### Memory Map
```
0x00000000 - 0x00003FFF   BIOS (16 KB)
0x02000000 - 0x0203FFFF   EWRAM (256 KB)
0x03000000 - 0x03007FFF   IWRAM (32 KB)
0x04000000 - 0x040003FF   I/O Registers
0x05000000 - 0x050003FF   Palette RAM (1 KB)
0x06000000 - 0x06017FFF   VRAM (96 KB)
0x07000000 - 0x070003FF   OAM (1 KB)
0x08000000 - 0x09FFFFFF   ROM (32 MB)
0x0E000000 - 0x0E00FFFF   Save RAM (64 KB)
```

---

## 📄 License

**Copyright © 2025 Christian Koscielniak Pinto. All Rights Reserved.**

This software is proprietary. See [LICENSE](LICENSE) for full details.

- ✅ You may **view** the source code for reference and educational purposes
- ❌ You may **NOT** copy, modify, distribute, or use this software
- ❌ You may **NOT** use for any commercial or non-commercial purposes
- ❌ No license is granted for any use without explicit permission

**Important:** If this repository is public on GitHub, viewing the code does NOT grant you any rights to use it. All rights are reserved by the copyright holder.

For licensing inquiries or permissions, please contact the author.

---

## 🙏 Acknowledgments

### Resources
- [GBATEK](https://problemkaputt.de/gbatek.htm) - Comprehensive GBA technical documentation
- [Tonc](https://www.coranac.com/tonc/text/) - GBA programming tutorials
- [ARM7TDMI Manual](https://developer.arm.com/) - Official ARM documentation
- [No$GBA](https://problemkaputt.de/gba.htm) - Reference debugger

### Inspiration
- mGBA - Reference for emulation accuracy
- VisualBoyAdvance - Pioneer GBA emulator
- SkyEmu - Modern emulator architecture

---

## ⚠️ Disclaimer

This emulator is for **educational and preservation purposes only**. 

- Game Boy Advance is a trademark of Nintendo Co., Ltd.
- This project is **not affiliated with, endorsed by, or sponsored by Nintendo**
- Users must own legal copies of games they run
- ROM distribution is illegal and not supported by this project

---

## � Contact

**Developer:** Christian Koscielniak Pinto  
**GitHub:** [@ChrisKp1710](https://github.com/ChrisKp1710)  
**Repository:** [Emerald](https://github.com/ChrisKp1710/Emerald)

---

<div align="center">

**Status:** 🔨 Under Active Development  
**Last Updated:** October 27, 2025

Made with ❤️ for the GBA community

</div>

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

# 🏗️ Architettura Emerald - Diagramma Completo

## 📊 Struttura Progetto

```
Emerald GBA Emulator
┌─────────────────────────────────────────────────────────────────┐
│                         Emerald.xcodeproj                        │
└─────────────────────────────────────────────────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
              ┌─────▼─────┐            ┌─────▼─────┐
              │  Emerald  │            │   Tests   │
              │  (main)   │            │           │
              └─────┬─────┘            └───────────┘
                    │
        ┌───────────┼───────────┬───────────┬───────────┐
        │           │           │           │           │
    ┌───▼───┐   ┌──▼──┐    ┌──▼──┐    ┌──▼──┐    ┌──▼──────┐
    │ Core  │   │Views│    │Models│   │Mgrs │    │Utilities│
    └───┬───┘   └──┬──┘    └──┬──┘    └──┬──┘    └──┬──────┘
        │          │           │           │           │
        └──────────┴───────────┴───────────┴───────────┘
```

---

## 🎮 Core - Emulazione Hardware

```
Core/
├── CPU/                    🧠 Processore
│   └── GBAARM7TDMI.swift
│       ├── Pipeline a 3 stadi
│       ├── ARM instructions (32-bit)
│       ├── Thumb instructions (16-bit)
│       ├── Registri (R0-R15)
│       └── CPSR/SPSR
│
├── Memory/                 💾 Gestione Memoria
│   └── GBAMemoryManager.swift
│       ├── BIOS ROM (16 KB)
│       ├── EWRAM (256 KB)
│       ├── IWRAM (32 KB)
│       ├── I/O Registers (1 KB)
│       ├── Palette RAM (1 KB)
│       ├── VRAM (96 KB)
│       ├── OAM (1 KB)
│       └── Game Pak (32 MB max)
│
├── Graphics/               🎨 Sistema Video
│   └── GBAComponents.swift
│       ├── PPU (Picture Processing Unit)
│       ├── 4 Background Layers
│       ├── 128 Sprites (OBJ)
│       ├── 6 Video Modes (0-5)
│       ├── Tile Engine
│       ├── Bitmap Engine
│       └── Special Effects
│
├── Audio/                  🔊 Sistema Audio
│   └── GBAAudioEngine.swift
│       ├── 4 Tone Channels
│       ├── 2 DirectSound Channels
│       ├── Mixer
│       └── Core Audio Backend
│
└── IO/                     🔌 Input/Output
    └── GBAInterrupts.swift
        ├── VBlank/HBlank
        ├── Timer Interrupts
        ├── DMA Interrupts
        └── Keypad Interrupt
```

---

## 🖼️ Views - Interfaccia Utente

```
Views/
├── Main/                   🎮 Schermo Principale
│   ├── MainEmulatorView.swift
│   │   ├── Contenitore principale
│   │   ├── Drag & Drop
│   │   └── Toolbar
│   │
│   ├── EmulatorScreenView.swift
│   │   ├── Display Metal (240×160)
│   │   ├── Scaling & Filters
│   │   └── Aspect Ratio
│   │
│   └── ContentView.swift
│       └── Welcome Screen
│
├── Library/                📚 Libreria ROM
│   └── ROMLibraryView.swift
│       ├── Grid/List View
│       ├── Search & Filter
│       ├── Categories
│       └── Metadata
│
└── Settings/               ⚙️ Preferenze
    └── SettingsView.swift
        ├── Display Settings
        ├── Audio Settings
        ├── Input Mapping
        └── Advanced Options
```

---

## 📦 Models - Dati e Configurazione

```
Models/
├── GBARom.swift            🎮 ROM Information
│   ├── Title & Metadata
│   ├── Game Code
│   ├── Publisher
│   ├── Region
│   ├── Category
│   └── Play Statistics
│
├── SaveState.swift         💾 Salvataggi
│   ├── CPU State
│   ├── Memory Snapshot
│   ├── PPU State
│   ├── APU State
│   ├── Timestamp
│   └── Screenshot
│
└── EmulatorSettings.swift  ⚙️ Impostazioni
    ├── Display (filters, scale)
    ├── Audio (volume, latency)
    ├── Input (keyboard, controller)
    ├── Performance (threads, thermal)
    └── Advanced (BIOS, debug)
```

---

## 🎛️ Managers - Logica di Business

```
Managers/
├── EmulatorState.swift     🎮 Stato Emulatore
│   ├── Lifecycle Management
│   ├── Emulation Loop
│   ├── Component Coordination
│   ├── Performance Monitoring
│   └── Save State System
│
└── ROMLibrary.swift        📚 Gestione ROM
    ├── ROM Scanning
    ├── Metadata Parsing
    ├── File Watching
    ├── Search & Filter
    └── JSON Persistence
```

---

## 🎨 Rendering - Sistema Grafico

```
Rendering/
├── MetalRenderer.swift     🖼️ GPU Acceleration
│   ├── Metal Device
│   ├── Command Queue
│   ├── Texture (240×160)
│   └── Pipeline State
│
└── Shaders.metal           ✨ Shader Programs
    ├── Vertex Shader
    ├── Fragment Shader (base)
    ├── Sharp Filter
    ├── Smooth Filter
    ├── CRT Filter
    └── Scanline Effect
```

---

## 🛠️ Utilities - Helper & Extensions

```
Utilities/
├── FocusedValues.swift     🎯 SwiftUI Focus
│   ├── @FocusedBinding
│   ├── EmulatorState Focus
│   ├── ROMLibrary Focus
│   └── Settings Focus
│
└── EmulatorMenuCommands.swift  📋 Menu macOS
    ├── File Menu (Open, Close)
    ├── Emulation Menu (Pause, Reset)
    ├── Speed Control
    ├── Save States (10 slots)
    └── Keyboard Shortcuts
```

---

## 🔄 Flusso di Esecuzione

```
┌──────────────┐
│ EmeraldApp   │  @main entry point
└──────┬───────┘
       │
       ▼
┌──────────────────┐
│ MainEmulatorView │  Root view
└──────┬───────────┘
       │
       ├─────────────────────┐
       │                     │
       ▼                     ▼
┌─────────────┐      ┌──────────────┐
│EmulatorState│◄────►│ ROMLibrary   │
└──────┬──────┘      └──────────────┘
       │
       ├────────┬────────┬────────┬────────┐
       │        │        │        │        │
       ▼        ▼        ▼        ▼        ▼
    ┌─────┐ ┌──────┐ ┌─────┐ ┌─────┐ ┌──────┐
    │ CPU │ │Memory│ │ PPU │ │ APU │ │ I/O  │
    └─────┘ └──────┘ └─────┘ └─────┘ └──────┘
       │        │        │        │        │
       └────────┴────────┴────────┴────────┘
                        │
                        ▼
                ┌───────────────┐
                │MetalRenderer  │
                └───────────────┘
                        │
                        ▼
                ┌───────────────┐
                │   Display     │
                └───────────────┘
```

---

## 📊 Dipendenze tra Componenti

```
EmulatorState
    ├── depends on → CPU
    ├── depends on → MemoryManager
    ├── depends on → PPU
    ├── depends on → APU
    ├── depends on → InterruptController
    └── depends on → MetalRenderer

CPU
    ├── depends on → MemoryManager
    └── depends on → InterruptController

MemoryManager
    └── depends on → Cartridge

PPU
    ├── depends on → MemoryManager
    ├── depends on → MetalRenderer
    └── depends on → InterruptController

APU
    └── depends on → AudioEngine

MetalRenderer
    └── depends on → Metal Framework
```

---

## 🎯 Layer Architecture

```
┌─────────────────────────────────────────────┐
│              UI Layer (SwiftUI)             │  Views/
├─────────────────────────────────────────────┤
│           Business Logic Layer              │  Managers/
├─────────────────────────────────────────────┤
│            Data Layer (Models)              │  Models/
├─────────────────────────────────────────────┤
│         Emulation Core (Hardware)           │  Core/
├─────────────────────────────────────────────┤
│       System Layer (Metal, CoreAudio)       │  Rendering/
└─────────────────────────────────────────────┘
```

---

## 📝 File Count Summary

```
Total Files: ~20

Core/           5 files
Views/          5 files
Models/         3 files
Managers/       2 files
Rendering/      2 files
Utilities/      2 files
Root/           3 files (App, Assets, README)
```

---

## 🔥 Hot Paths (Performance Critical)

```
🔴 Critical (60 FPS required):
   EmulatorState.runEmulationLoop()
   └── CPU.executeInstruction()      ⚡ ~280k per frame
   └── PPU.update()                  ⚡ Every scanline
   └── MetalRenderer.present()       ⚡ Every frame

🟡 Important:
   APU.generateSamples()             🔊 ~44.1kHz
   DMA.transfer()                    📦 On-demand

🟢 Background:
   ROMLibrary.scanForROMs()          📚 Async
   SaveState.save()                  💾 Async
```

---

## 🚀 Future Expansion Points

```
Core/
├── CPU/
│   ├── GBAARM7TDMI.swift          (exists)
│   ├── ARMInstructions.swift      (TODO)
│   └── ThumbInstructions.swift    (TODO)
│
├── Graphics/
│   ├── GBAComponents.swift        (exists - to split)
│   ├── GBAPictureProcessingUnit.swift  (TODO)
│   ├── TileRenderer.swift         (TODO)
│   └── SpriteRenderer.swift       (TODO)
│
└── IO/
    ├── GBAInterrupts.swift        (exists)
    ├── GBATimerSystem.swift       (TODO)
    ├── GBADMAController.swift     (TODO)
    └── GBAInputController.swift   (TODO)
```

---

## 💡 Design Patterns Utilizzati

```
🎨 MVVM (Model-View-ViewModel)
   Views ←→ Managers ←→ Models

🏭 Factory Pattern
   EmulatorState crea i componenti

🔌 Dependency Injection
   Weak references per evitare retain cycles

👀 Observer Pattern
   @Published per reattività SwiftUI

🎯 Singleton (limitato)
   PublisherDatabase, CategoryDetector
```

---

## ✅ Best Practices Implementate

```
✅ Separation of Concerns
✅ Single Responsibility Principle
✅ Dependency Injection
✅ Async/Await per I/O
✅ OSLog per debugging strutturato
✅ Memory safety (weak references)
✅ Type safety (Swift strong typing)
✅ SwiftUI native patterns
```

---

**🎉 Questa è l'architettura completa di Emerald!**

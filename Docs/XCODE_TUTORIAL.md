# 🎓 Tutorial Passo-Passo: Riorganizzazione in Xcode

## 🎯 Obiettivo
Riorganizzare il progetto Emerald da una cartella piatta a una struttura modulare e professionale.

---

## ⏱️ Tempo stimato: 10-15 minuti

---

## 📋 PASSO 1: Backup e Preparazione

### 1.1 Apri il Progetto
```
1. Vai in Finder
2. Naviga a: Documents/01-Projects/Emerald/
3. Doppio-click su: Emerald.xcodeproj
4. Aspetta che Xcode carichi il progetto
```

### 1.2 Fai un Backup (Opzionale ma Consigliato)
```
Opzione A - Git:
1. In Xcode: Source Control → Commit
2. Messaggio: "Before reorganization"
3. Click "Commit"

Opzione B - Copia Finder:
1. Chiudi Xcode
2. In Finder, duplica la cartella Emerald
3. Rinomina in "Emerald_backup"
4. Riapri Xcode
```

---

## 📋 PASSO 2: Crea la Struttura delle Cartelle

### 2.1 Seleziona la Cartella Root
```
1. Nel Project Navigator (sidebar sinistra)
2. Click sulla cartella "Emerald" (quella gialla sotto il progetto)
```

### 2.2 Crea il Gruppo "Core"
```
1. Click destro su "Emerald"
2. "New Group" (oppure ⌥⌘N)
3. Rinomina in "Core"
4. Premi Enter
```

### 2.3 Crea i Sottogruppi di Core
```
Ripeti per ogni sottocartella:

1. Click destro su "Core"
2. "New Group"
3. Rinomina in:
   - CPU
   - Memory
   - Graphics
   - Audio
   - IO
```

### 2.4 Crea gli Altri Gruppi Principali
```
Click destro su "Emerald" (root) e crea:

1. Views
   └── Sottogruppi:
       - Main
       - Library
       - Settings

2. Models

3. Managers

4. Rendering

5. Utilities
```

### 2.5 Verifica la Struttura
```
Dovresti vedere:

Emerald/
├── 📁 Core/
│   ├── 📁 CPU/
│   ├── 📁 Memory/
│   ├── 📁 Graphics/
│   ├── 📁 Audio/
│   └── 📁 IO/
├── 📁 Views/
│   ├── 📁 Main/
│   ├── 📁 Library/
│   └── 📁 Settings/
├── 📁 Models/
├── 📁 Managers/
├── 📁 Rendering/
├── 📁 Utilities/
├── EmeraldApp.swift (e altri file)
└── Assets.xcassets/
```

---

## 📋 PASSO 3: Sposta i File (Drag & Drop)

### 3.1 Core/CPU/
```
1. Trova "GBAARM7TDMI.swift" nella root
2. Click e tieni premuto
3. Trascina dentro la cartella "Core/CPU/"
4. Rilascia
```

### 3.2 Core/Memory/
```
Trascina: GBAMemoryManager.swift → Core/Memory/
```

### 3.3 Core/Graphics/
```
Trascina: GBAComponents.swift → Core/Graphics/
```

### 3.4 Core/Audio/
```
Trascina: GBAAudioEngine.swift → Core/Audio/
```

### 3.5 Core/IO/
```
Trascina: GBAInterrupts.swift → Core/IO/
```

### 3.6 Models/
```
Trascina questi file in "Models/":
- GBARom.swift
- SaveState.swift
- EmulatorSettings.swift
```

### 3.7 Managers/
```
Trascina questi file in "Managers/":
- EmulatorState.swift
- ROMLibrary.swift
```

### 3.8 Views/Main/
```
Trascina questi file in "Views/Main/":
- MainEmulatorView.swift
- EmulatorScreenView.swift
- ContentView.swift
```

### 3.9 Views/Library/
```
Trascina: ROMLibraryView.swift → Views/Library/
```

### 3.10 Views/Settings/
```
Trascina: SettingsView.swift → Views/Settings/
```

### 3.11 Rendering/
```
Trascina questi file in "Rendering/":
- MetalRenderer.swift
- Shaders.metal
```

### 3.12 Utilities/
```
Trascina questi file in "Utilities/":
- FocusedValues.swift
- EmulatorMenuCommands.swift
```

---

## 📋 PASSO 4: Elimina i Duplicati

### 4.1 Elimina SettingsView 2.swift
```
1. Trova "SettingsView 2.swift" nella root
2. Click destro
3. "Delete"
4. Seleziona "Move to Trash"
5. Click "Move to Trash"
```

### 4.2 Elimina Shaders 2.metal
```
1. Trova "Shaders 2.metal" nella root
2. Click destro
3. "Delete"
4. Seleziona "Move to Trash"
5. Click "Move to Trash"
```

---

## 📋 PASSO 5: Verifica e Build

### 5.1 Controlla che tutto sia al Posto Giusto
```
La cartella root "Emerald" dovrebbe contenere SOLO:
✅ EmeraldApp.swift
✅ Assets.xcassets/
✅ README.md
✅ Le cartelle (Core, Views, Models, ecc.)

NON dovrebbe più contenere:
❌ GBAARM7TDMI.swift
❌ GBAMemoryManager.swift
❌ Altri file .swift
❌ SettingsView 2.swift
❌ Shaders 2.metal
```

### 5.2 Build il Progetto
```
1. Premi ⌘B (Command + B)
2. Aspetta che compili
3. Verifica che non ci siano errori nella console
```

### 5.3 Se ci sono Errori
```
Errori comuni e soluzioni:

❌ "No such module" o "Cannot find in scope"
→ Soluzione: Pulisci build (⌘⇧K), poi rebuilda (⌘B)

❌ File non trovato
→ Soluzione: Nel Project Navigator, verifica che il file
  esista e non sia rosso

❌ Path errato
→ Soluzione: Seleziona il file, vai al File Inspector (→)
  e verifica il "Location"
```

### 5.4 Clean Build Folder (Se necessario)
```
1. Menu: Product → Clean Build Folder
2. Oppure: ⌘⇧K (Command + Shift + K)
3. Aspetta che finisca
4. Rebuilda: ⌘B
```

---

## 📋 PASSO 6: Run e Test

### 6.1 Esegui l'App
```
1. Seleziona un target (es. "My Mac")
2. Premi ⌘R (Command + R)
3. Aspetta che l'app si avvii
```

### 6.2 Test Rapido
```
1. L'app si apre?                    ✅/❌
2. La finestra principale appare?    ✅/❌
3. Non ci sono crash immediati?      ✅/❌
4. I menu funzionano?                ✅/❌
```

### 6.3 Se tutto Funziona
```
🎉 CONGRATULAZIONI! 🎉

Il progetto è ora organizzato professionalmente!
```

---

## 📋 PASSO 7: Commit (Opzionale)

### 7.1 Se usi Git
```
1. Source Control → Commit
2. Messaggio: "Reorganize project structure"
3. Seleziona tutti i file modificati
4. Click "Commit"
```

---

## ❓ FAQ - Domande Frequenti

### Q: I file sono scomparsi!
**A:** Tranquillo! Sono solo in cartelle diverse. Usa ⌘⇧O (Quick Open) per trovarli.

### Q: Xcode mostra file in rosso
**A:** Significa che il riferimento è rotto. Elimina il riferimento e ri-aggiungi il file.

### Q: Il build fallisce
**A:** 
1. Pulisci: ⌘⇧K
2. Chiudi Xcode
3. Elimina la cartella DerivedData:
   ~/Library/Developer/Xcode/DerivedData/Emerald-*
4. Riapri e rebuilda

### Q: Posso annullare tutto?
**A:** Sì! Se hai fatto il backup:
1. Chiudi Xcode
2. Elimina la cartella Emerald
3. Rinomina Emerald_backup in Emerald
4. Riapri

### Q: Quanto tempo ci vuole?
**A:** 10-15 minuti seguendo questa guida passo-passo.

---

## 🎯 Risultato Finale

### Struttura Completa
```
Emerald/
├── 📱 EmeraldApp.swift
├── 🖼️ Assets.xcassets/
├── 📄 README.md
│
├── 🎮 Core/
│   ├── 💻 CPU/
│   │   └── GBAARM7TDMI.swift
│   ├── 💾 Memory/
│   │   └── GBAMemoryManager.swift
│   ├── 🎨 Graphics/
│   │   └── GBAComponents.swift
│   ├── 🔊 Audio/
│   │   └── GBAAudioEngine.swift
│   └── 🔌 IO/
│       └── GBAInterrupts.swift
│
├── 🖼️ Views/
│   ├── Main/
│   │   ├── MainEmulatorView.swift
│   │   ├── EmulatorScreenView.swift
│   │   └── ContentView.swift
│   ├── Library/
│   │   └── ROMLibraryView.swift
│   └── Settings/
│       └── SettingsView.swift
│
├── 📦 Models/
│   ├── GBARom.swift
│   ├── SaveState.swift
│   └── EmulatorSettings.swift
│
├── 🎛️ Managers/
│   ├── EmulatorState.swift
│   └── ROMLibrary.swift
│
├── 🎨 Rendering/
│   ├── MetalRenderer.swift
│   └── Shaders.metal
│
└── 🛠️ Utilities/
    ├── FocusedValues.swift
    └── EmulatorMenuCommands.swift
```

---

## ✅ Checklist Finale

- [ ] Tutti i file sono nelle cartelle corrette
- [ ] Non ci sono file duplicati
- [ ] Il progetto compila senza errori
- [ ] L'app si avvia correttamente
- [ ] Hai fatto un commit (opzionale)
- [ ] Sei felice del risultato! 😊

---

## 🚀 Prossimi Passi

Ora che il progetto è organizzato, possiamo:

1. **Separare GBAComponents.swift** in file individuali
2. **Implementare componenti mancanti** (Timer, DMA, Input)
3. **Completare CPU instructions**
4. **Implementare PPU rendering**
5. **Aggiungere APU audio generation**

**Dimmi quando sei pronto per continuare! 🎉**

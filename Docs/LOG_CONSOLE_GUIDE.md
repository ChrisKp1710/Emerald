# 🐛 Using the Debug Log Console

## Opening the Console

**Method 1 - Keyboard Shortcut:**
- Press `⌘` + `` ` `` (Command + Backtick)

**Method 2 - Menu:**
- Go to `Debug` → `Toggle Log Console`

## What You'll See

The log console will appear at the bottom of the emulator window showing:

```
🔍 [23:45:12.123] [ROM] 🎮 Starting ROM load process...
ℹ️ [23:45:12.125] [ROM] ROM: POKEMON EMER
✅ [23:45:12.130] [ROM] ✅ ROM file found
✅ [23:45:12.145] [ROM] ✅ ROM data read: 16777216 bytes (16 MB)
🛑 [23:45:12.150] [System] 🛑 Stopping current emulation
📦 [23:45:12.155] [ROM] 📦 Creating cartridge...
✅ [23:45:12.160] [ROM] ✅ Cartridge created successfully
🔧 [23:45:12.165] [System] 🔧 Initializing emulator components...
ℹ️ [23:45:12.170] [Memory] Initializing Memory Manager...
✅ [23:45:12.175] [Memory] ✅ Memory Manager ready
ℹ️ [23:45:12.180] [CPU] Initializing CPU (ARM7TDMI)...
✅ [23:45:12.185] [CPU] ✅ CPU ready
ℹ️ [23:45:12.190] [PPU] Initializing PPU (Graphics)...
⚠️ [23:45:12.195] [PPU] ⚠️ PPU initialized (stub - no rendering yet)
🎉 [23:45:12.200] [ROM] 🎉 ROM loaded successfully!
▶️ [23:45:12.205] [System] ▶️ Starting emulation
✅ [23:45:12.210] [System] ✅ Emulation started (60 FPS target)
```

## Log Categories

- **ROM** 🎮 - ROM loading and cartridge operations
- **CPU** 🧠 - CPU execution and instructions
- **Memory** 💾 - Memory reads/writes
- **PPU** 🎨 - Graphics rendering (currently stub)
- **Audio** 🔊 - Audio engine
- **Input** 🎮 - Keyboard/controller input
- **System** ⚙️ - General system messages

## Log Levels

- 🔍 **Debug** - Detailed debugging info
- ℹ️ **Info** - General information
- ⚠️ **Warning** - Non-critical issues
- ❌ **Error** - Errors and failures
- ✅ **Success** - Successful operations

## Console Controls

- **Filter** dropdown - Show only specific log levels
- **Auto-scroll** toggle - Automatically scroll to newest logs
- **Clear** button - Remove all logs
- **×** button - Close console

## Keyboard Shortcuts

- `⌘` + `` ` `` - Toggle console
- `⌘⇧C` - Clear logs

## What to Look For

### ✅ **Successful ROM Load**
```
✅ ROM file found
✅ ROM data read: X MB
✅ Cartridge created successfully
✅ Components initialized
🎉 ROM loaded successfully!
✅ Emulation started
```

### ❌ **ROM Load Failed**
```
❌ ROM file not found at path!
❌ Failed to read ROM data
❌ Failed to create cartridge: <error>
```

### ⚠️ **Current Limitations**
```
⚠️ PPU initialized (stub - no rendering yet)
⚠️ APU initialized (stub - no sound yet)
```

## Tips

1. **Keep console open** when loading ROMs to see what happens
2. **Look for errors** (❌) to identify problems
3. **Check timestamps** to see how long operations take
4. **Filter by category** to focus on specific components
5. **Clear logs** before loading a new ROM for cleaner output

## Why Black Screen?

If you see all ✅ but still black screen, look for:
```
⚠️ PPU initialized (stub - no rendering yet)
```

This means the PPU isn't actually drawing graphics - it's the next feature to implement!

---

**The console helps you understand exactly what the emulator is doing!** 🎉

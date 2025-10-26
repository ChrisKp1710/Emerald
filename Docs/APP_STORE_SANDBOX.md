# App Store Sandbox Configuration

## 📋 Overview
Emerald emulator is now fully configured for App Store distribution with proper sandbox entitlements and security-scoped file access.

## 🔒 Security Changes

### Entitlements (Emerald.entitlements)
The app now includes proper entitlements for App Store submission:

- ✅ **App Sandbox**: Enabled (`com.apple.security.app-sandbox`)
- ✅ **User Selected Files**: Read-write access (`com.apple.security.files.user-selected.read-write`)
- ✅ **Security-scoped Bookmarks**: Persistent file access (`com.apple.security.files.bookmarks.app-scope`)
- ✅ **Network Client**: For future online features (`com.apple.security.network.client`)
- ❌ **Audio Input**: Disabled (not needed for emulator)

### File Access Strategy

#### Before (❌ Non-compliant)
```swift
// SwiftUI FileImporter with direct file copy
.fileImporter(...) { result in
    try fileManager.copyItem(at: url, to: destination) // ❌ Permission denied
}
```

#### After (✅ Sandbox-compliant)
```swift
// NSOpenPanel with security-scoped resources
let panel = NSOpenPanel()
panel.allowsMultipleSelection = true
panel.runModal()

// Start accessing security-scoped resource
let accessing = url.startAccessingSecurityScopedResource()
defer { url.stopAccessingSecurityScopedResource() }

// Save bookmark for persistent access
let bookmark = try url.bookmarkData(options: .withSecurityScope)
UserDefaults.standard.set(bookmark, forKey: "bookmark_\(id)")
```

## 🎮 User Experience

### ROM Loading Process
1. User clicks **"Add ROM"** button
2. Native macOS file picker opens (NSOpenPanel)
3. User selects ROM file(s) from any location
4. App requests security-scoped access
5. File is copied to app's container
6. Security bookmark saved for future access

### Debug Console Integration
All file operations are now logged:
- 🔍 Opening file picker
- ✅ Security-scoped access granted
- 📋 Copying ROM to library
- 🔖 Security bookmark saved
- 🎉 ROM loaded successfully

## 🏗️ Build Configuration

### Xcode Settings
```xml
ENABLE_APP_SANDBOX = YES
ENABLE_HARDENED_RUNTIME = YES
ENABLE_USER_SELECTED_FILES = "read-write"
CODE_SIGN_ENTITLEMENTS = Emerald/Emerald.entitlements
```

### File Locations
- **Entitlements**: `Emerald/Emerald.entitlements`
- **ROM Library**: `~/Library/Containers/dev.kodechris.Emerald/Data/Library/Application Support/Emerald/ROMs/`
- **Metadata**: `~/Library/Containers/dev.kodechris.Emerald/Data/Library/Application Support/Emerald/metadata.json`

## 🧪 Testing Checklist

- [x] ✅ Build succeeds with entitlements
- [x] ✅ Code signing includes entitlements
- [ ] ⏳ Load ROM via NSOpenPanel (test in app)
- [ ] ⏳ Verify security-scoped access works
- [ ] ⏳ Check debug console logs
- [ ] ⏳ Validate persistent bookmark access

## 📦 App Store Submission

### Requirements Met
1. ✅ **App Sandbox** enabled
2. ✅ **Hardened Runtime** enabled
3. ✅ **Security-scoped file access** implemented
4. ✅ **Entitlements** properly configured
5. ✅ **Code signing** successful

### Next Steps for Submission
1. Test ROM loading with new system
2. Verify all app functionality works in sandbox
3. Add app icon and metadata
4. Create distribution certificate
5. Archive and upload to App Store Connect

## 🐛 Troubleshooting

### Error: "Operation not permitted"
**Old behavior**: File copy failed with NSPOSIXErrorDomain Code=1

**Solution**: Now using NSOpenPanel with security-scoped resources

### Error: "couldn't be copied because you don't have permission"
**Old behavior**: SwiftUI FileImporter didn't grant proper access

**Solution**: NSOpenPanel automatically grants security-scoped access

### Debug Console Shows Permission Errors
**Check**:
1. Open debug console (⌘`)
2. Click "Add ROM"
3. Select file
4. Watch for: ✅ "Security-scoped access granted: true"
5. If false, entitlements may not be applied

## 📚 Apple Documentation References

- [App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)
- [Security-Scoped Bookmarks](https://developer.apple.com/library/archive/documentation/Security/Conceptual/AppSandboxDesignGuide/AppSandboxInDepth/AppSandboxInDepth.html#//apple_ref/doc/uid/TP40011183-CH3-SW16)
- [Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements)
- [File System Programming Guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/AccessingFilesandDirectories/AccessingFilesandDirectories.html)

## 🎯 Summary

The emulator now follows Apple's best practices for:
- ✅ Sandbox security
- ✅ User privacy
- ✅ File access permissions
- ✅ App Store compliance

**Ready for App Store submission after testing ROM loading!** 🚀

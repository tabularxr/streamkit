# Fix: Multiple Commands Produce Same Output Files

This error typically occurs when there are duplicate file references or build settings conflicts in the Xcode project. Here's a systematic approach to fix it:

## Quick Fix Steps

### 1. Clean Build System
```bash
# Clean derived data (already done)
rm -rf ~/Library/Developer/Xcode/DerivedData/iOSSocket-*

# In Xcode:
# - Product → Clean Build Folder (⌘+Shift+K)
# - File → Packages → Reset Package Caches
```

### 2. Check for Duplicate File References
In Xcode:
1. **Select the project** in navigator
2. **Go to Build Phases** tab
3. **Check "Compile Sources"** section for duplicates
4. **Remove any duplicate entries**

### 3. Fix Package Dependencies
The error might be related to StreamKit package integration:

1. **Remove existing package dependency**:
   - Project settings → Package Dependencies
   - Select StreamKit if present → Remove

2. **Re-add StreamKit package**:
   - Click "+" → Add Local...
   - Navigate to: `../../../StreamKit`
   - Ensure it's only added to the main target (not test targets)

### 4. Check Target Membership
For each Swift file:
1. **Select the file** in navigator
2. **Check File Inspector** (right panel)
3. **Ensure correct target membership**:
   - `ContentView.swift` → ✅ iOSSocket only
   - `StreamKitDemoViewModel.swift` → ✅ iOSSocket only
   - `iOSSocketApp.swift` → ✅ iOSSocket only

### 5. Verify Build Settings
1. **Select project** → **Build Settings**
2. **Search for "duplicate"** or **"multiple"**
3. **Check these settings**:
   - **Product Name**: Should be unique
   - **Bundle Identifier**: Should be unique
   - **Deployment Target**: Should match (iOS 16.0+)

## Advanced Troubleshooting

### If Error Persists - Project File Inspection
```bash
# Check for duplicate file references in project.pbxproj
cd /Users/morotioyeyemi/tabular/packages/streamkit/examples/iOSSocket
grep -n "ContentView.swift" iOSSocket.xcodeproj/project.pbxproj
grep -n "StreamKitDemoViewModel.swift" iOSSocket.xcodeproj/project.pbxproj
```

Each file should appear only 2-3 times:
- Once in file references
- Once in build phases
- Possibly once in groups

### If Package Integration Issues
1. **Create fresh Package.swift reference**:
   ```swift
   // In Package Dependencies, use file path:
   file:///Users/morotioyeyemi/tabular/packages/streamkit/StreamKit
   ```

2. **Or use relative path**:
   ```
   ../../../StreamKit
   ```

### Nuclear Option - Fresh Project
If all else fails:
1. **Create new iOS project** with same name
2. **Copy source files** manually
3. **Re-add StreamKit package dependency**
4. **Copy Info.plist settings**

## Verification Steps

After applying fixes:
1. **Clean Build Folder** (⌘+Shift+K)
2. **Build** (⌘+B)
3. **Check for errors**
4. **Run on device/simulator**

## Common Causes

This error usually happens when:
- Files were added multiple times to project
- Package was added to multiple targets
- Build phases have duplicate entries
- Workspace conflicts with package manager

## Prevention

To avoid this in future:
- Always use "Add Files to Project" (not drag-and-drop)
- Check target membership when adding files
- Use consistent package management approach
- Avoid mixing CocoaPods/SPM/Carthage

## Next Steps

1. Try the Quick Fix Steps first
2. If error persists, use Advanced Troubleshooting
3. Verify StreamKit integration works after fix
4. Test app functionality on device

The cleaned derived data should resolve most cases of this error.
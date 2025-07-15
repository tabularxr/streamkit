# Fix: Info.plist Multiple Commands Error

This error occurs when Xcode's automatic file system synchronization is trying to include the same Info.plist file for multiple targets. Here's how to fix it:

## Root Cause
The project uses Xcode 15+'s `PBXFileSystemSynchronizedRootGroup` which automatically includes files from directories. When multiple targets share the same directory structure, they can conflict over the same Info.plist file.

## Solution Steps

### 1. Open Xcode Project
```bash
open iOSSocket.xcodeproj
```

### 2. Check Build Settings for Each Target

For **iOSSocket** target:
1. Select project → Select "iOSSocket" target
2. Go to **Build Settings** tab
3. Search for **"Info.plist"**
4. Set **Info.plist File** to: `iOSSocket/Info.plist`

For **iOSSocketTests** target:
1. Select "iOSSocketTests" target
2. Go to **Build Settings** tab
3. Search for **"Info.plist"**
4. Set **Info.plist File** to: `$(SRCROOT)/iOSSocketTests/Info.plist` (if it exists)
5. **OR** delete the setting if tests don't need a custom Info.plist

For **iOSSocketUITests** target:
1. Select "iOSSocketUITests" target
2. Go to **Build Settings** tab
3. Search for **"Info.plist"**
4. Set **Info.plist File** to: `$(SRCROOT)/iOSSocketUITests/Info.plist` (if it exists)
5. **OR** delete the setting if UI tests don't need a custom Info.plist

### 3. Alternative: Create Separate Info.plist Files

If the above doesn't work, create separate Info.plist files:

```bash
# Create test Info.plist files
cp iOSSocket/Info.plist iOSSocketTests/Info.plist
cp iOSSocket/Info.plist iOSSocketUITests/Info.plist
```

Then modify the test Info.plist files to remove app-specific keys:

**iOSSocketTests/Info.plist:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>iOSSocketTests</string>
</dict>
</plist>
```

**iOSSocketUITests/Info.plist:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>iOSSocketUITests</string>
</dict>
</plist>
```

### 4. Clean and Rebuild

After making changes:
1. **Clean Build Folder**: Product → Clean Build Folder (⌘+Shift+K)
2. **Clean Derived Data**: File → Packages → Reset Package Caches
3. **Build**: Product → Build (⌘+B)

### 5. Alternative Solution: Disable Test Targets

If you don't need the test targets right now:
1. Select project in navigator
2. Select each test target (iOSSocketTests, iOSSocketUITests)
3. Go to **Build Settings**
4. Set **Skip Install** to **Yes**
5. Or delete the test targets entirely

### 6. Nuclear Option: Manual Project Fix

If all else fails, manually edit the project file:

1. **Close Xcode**
2. **Edit project.pbxproj**:
   ```bash
   # Make backup first
   cp iOSSocket.xcodeproj/project.pbxproj iOSSocket.xcodeproj/project.pbxproj.backup
   ```
3. **Open in text editor** and look for duplicate Info.plist references
4. **Remove duplicates** carefully
5. **Reopen in Xcode**

## Quick Fix Commands

```bash
# Clean everything
rm -rf ~/Library/Developer/Xcode/DerivedData/iOSSocket-*

# Create separate test Info.plists
mkdir -p iOSSocketTests iOSSocketUITests
echo '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict></dict></plist>' > iOSSocketTests/Info.plist
echo '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict></dict></plist>' > iOSSocketUITests/Info.plist
```

## Verification

After applying the fix:
1. Build should complete without Info.plist errors
2. Main app target should use `iOSSocket/Info.plist`
3. Test targets should have their own Info.plist or none at all
4. StreamKit integration should work properly

The most common solution is setting explicit Info.plist paths in Build Settings for each target.
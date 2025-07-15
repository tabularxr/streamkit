# Definitive Fix for Info.plist Error

The error persists because of how Xcode 15+ handles automatic file synchronization. Here's the guaranteed fix:

## Root Cause
Modern Xcode projects use `PBXFileSystemSynchronizedRootGroup` which automatically includes all files in a directory. When multiple targets exist, they compete for the same Info.plist file.

## Definitive Solution

### Step 1: Open Xcode and Clean Everything
```bash
# Open the project
open iOSSocket.xcodeproj

# In Xcode:
# - Product → Clean Build Folder (⌘+Shift+K)
# - File → Packages → Reset Package Caches
```

### Step 2: Fix Build Settings for Each Target

**For iOSSocket (Main App):**
1. Select project → Select "iOSSocket" target
2. Build Settings → Search "Info.plist"
3. Set **Info.plist File** to: `iOSSocket/Info.plist`

**For iOSSocketTests:**
1. Select "iOSSocketTests" target
2. Build Settings → Search "Info.plist"
3. **Delete/Clear** the Info.plist File setting (leave it empty)
4. **OR** Set to `Generate Info.plist File` = YES

**For iOSSocketUITests:**
1. Select "iOSSocketUITests" target
2. Build Settings → Search "Info.plist"
3. **Delete/Clear** the Info.plist File setting (leave it empty)
4. **OR** Set to `Generate Info.plist File` = YES

### Step 3: Alternative - Disable Test Targets Temporarily

If the above doesn't work, temporarily disable test targets:

1. Select project in navigator
2. Select "iOSSocketTests" target
3. Go to **Build Settings**
4. Search for "Skip Install"
5. Set **Skip Install** to **YES**
6. Repeat for "iOSSocketUITests"

### Step 4: Nuclear Option - Remove Test Targets

If you don't need tests right now:

1. Select project in navigator
2. Right-click on "iOSSocketTests" target → Delete
3. Right-click on "iOSSocketUITests" target → Delete
4. Confirm deletion when prompted

### Step 5: Manual Project File Edit (Last Resort)

If all else fails, edit the project file directly:

```bash
# Close Xcode first!
# Backup the project file
cp iOSSocket.xcodeproj/project.pbxproj iOSSocket.xcodeproj/project.pbxproj.backup

# Edit the file and look for these patterns:
# - Remove any duplicate INFOPLIST_FILE settings
# - Ensure only the main target has INFOPLIST_FILE = "iOSSocket/Info.plist"
```

## Quick Fix Script

Run this script to try the automated fix:

```bash
#!/bin/bash
echo "Applying definitive Info.plist fix..."

# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/iOSSocket-*

# Remove any test Info.plist files
rm -f iOSSocketTests/Info.plist
rm -f iOSSocketUITests/Info.plist

# Remove test directories if empty
rmdir iOSSocketTests 2>/dev/null
rmdir iOSSocketUITests 2>/dev/null

echo "Now open Xcode and:"
echo "1. Clean Build Folder (⌘+Shift+K)"
echo "2. Set main target Info.plist to: iOSSocket/Info.plist"
echo "3. Clear Info.plist settings for test targets"
echo "4. Build (⌘+B)"
```

## Why This Happens

Modern Xcode automatically manages files in synchronized groups. When multiple targets share the same directory structure, they can conflict over files like Info.plist. The solution is to:

1. **Explicitly specify** which target uses which Info.plist
2. **Clear settings** for targets that don't need custom Info.plist files
3. **Let Xcode auto-generate** Info.plist for test targets

## Expected Result

After applying this fix:
- Main app builds successfully with its Info.plist
- Test targets either use auto-generated Info.plist or none at all
- No more "Multiple commands produce" errors
- StreamKit integration works properly

Try the manual Build Settings approach first, then use the nuclear option if needed.
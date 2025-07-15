# StreamKit Integration Setup

## Adding StreamKit Package Dependency

To complete the StreamKit integration in the iOSSocket app, you need to add the StreamKit package as a dependency in Xcode:

### Option 1: Local Package Reference (Recommended)

1. **Open the iOSSocket project** in Xcode:
   ```bash
   open iOSSocket.xcodeproj
   ```

2. **Add Local Package Dependency**:
   - In Xcode, select the project navigator (⌘+1)
   - Select the "iOSSocket" project at the top
   - Select the "iOSSocket" target
   - Go to the "Package Dependencies" tab
   - Click the "+" button to add a package dependency

3. **Add Local Package**:
   - Click "Add Local..." button
   - Navigate to and select: `../../../StreamKit` (the StreamKit package directory)
   - Click "Add Package"

4. **Link to Target**:
   - Ensure "StreamKit" is selected
   - Make sure it's added to the "iOSSocket" target
   - Click "Add Package"

### Option 2: Direct Package Manager (Alternative)

If Option 1 doesn't work, you can manually edit the project:

1. **Edit Package.swift** (if using Swift Package Manager):
   ```swift
   dependencies: [
       .package(path: "../../../StreamKit")
   ]
   ```

2. **Or add via Xcode Package Manager**:
   - File → Add Package Dependencies
   - Enter local path: `file:///Users/morotioyeyemi/tabular/packages/streamkit/StreamKit`

## Verification

After adding the dependency:

1. **Build the project** (⌘+B) to ensure there are no compilation errors
2. **Check that StreamKit imports correctly** - the `import StreamKit` line should not show any errors
3. **Run on a physical device** with LiDAR sensor for full functionality

## Testing

1. **Start the relay service**:
   ```bash
   cd /Users/morotioyeyemi/tabular/packages/relays
   make run
   ```

2. **Start the STAG service**:
   ```bash
   cd /Users/morotioyeyemi/tabular/packages/stag
   make run
   ```

3. **Run the iOSSocket app** on a physical device and test streaming

## Notes

- The app is now configured to use the real StreamKit implementation
- All mock implementations have been removed
- ARKit permissions are already configured in Info.plist
- The app requires a physical device with LiDAR sensor for full functionality
- Make sure both relay and STAG services are running before testing

## Troubleshooting

If you encounter build errors:

1. **Clean build folder** (⌘+Shift+K)
2. **Reset package caches**: File → Packages → Reset Package Caches
3. **Ensure correct iOS deployment target** (16.0+)
4. **Verify device has ARKit support** and LiDAR sensor

The StreamKit integration is now complete and ready for testing!
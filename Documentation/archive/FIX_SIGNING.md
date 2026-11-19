# Fix Code Signing for iOS Device

## Quick Fix (In Xcode):

1. **Open GTNW.xcodeproj in Xcode**
2. **Select GTNW project** (blue icon) in left sidebar
3. **Select GTNW_iOS target**
4. **Go to "Signing & Capabilities" tab**
5. **Check "Automatically manage signing"**
6. **Select your Team** from dropdown
   - Should show: your-apple-id@example.com or similar
7. **Xcode will automatically create a provisioning profile**
8. **Build and Run** (⌘R)

## Alternative: Run macOS Version (No Signing Required)

1. In Xcode, click the **scheme selector** (top bar near play button)
2. Select **GTNW_macOS** instead of GTNW_iOS
3. Select **My Mac** as destination
4. **Build and Run** (⌘R)
   - macOS apps don't require signing for local development
   - This is the recommended approach for testing

## Troubleshooting

If you still see signing errors:

### Option 1: Get Team ID
```bash
# Find your Apple Developer Team ID
security find-certificate -c "Apple Development" -p | openssl x509 -text | grep "OU="
```

### Option 2: Use Xcode's Automatic Signing
- Xcode > Preferences > Accounts
- Add your Apple ID if not already added
- Xcode will handle everything automatically

### Option 3: Manual Team ID
If you have a paid Apple Developer account, edit project.yml:
```yaml
DEVELOPMENT_TEAM: "YOUR_TEAM_ID_HERE"
```
Then run: `xcodegen generate`

## Recommended: Use macOS Target

For development and testing, **use the macOS target**:
- ✅ No code signing required
- ✅ Faster development cycle
- ✅ Same codebase (shared SwiftUI)
- ✅ Easier debugging

The iOS version is there for future deployment, but macOS is better for development.

## Current Status

- ✅ Project regenerated with signing configuration
- ✅ macOS target ready (no signing needed)
- ⚠️ iOS target needs Team ID set in Xcode

**Just switch to GTNW_macOS scheme and run!**

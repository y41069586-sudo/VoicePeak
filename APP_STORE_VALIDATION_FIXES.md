# App Store Connect Validation Fixes

## Root Cause
**Error 90474 (Unsupported Interface Orientation)** was triggered because:
- `TARGETED_DEVICE_FAMILY: "1,2"` (iPhone + iPad) was declared in both `project.yml` and XcodeGen config
- BUT Info.plist only defined `UISupportedInterfaceOrientations` with Portrait for iPhone
- iPad users attempting to rotate their device would crash — App Store Connect rejects this configuration

## Resolution
Changed app to **iPhone-only** support, which is appropriate for this camera-scanning use case.

## Files Modified

### 1. `project.yml` — XcodeGen Configuration
**Changes:**
- Line 14: `TARGETED_DEVICE_FAMILY: "1"` (was `"1,2"`)
- Line 36: `TARGETED_DEVICE_FAMILY: "1"` (was `"1,2"`)

### 2. `Verite/Resources/Info.plist`
**Removed (iPad-only entries):**
- `UISupportedInterfaceOrientations~ipad` array with Portrait-only orientation
- `UIRequiresFullScreen` key (only applicable when iPad is supported)

**Kept (correct for iPhone-only):**
- `UISupportedInterfaceOrientations` with Portrait orientation
- `UILaunchScreen` configuration (modern API, properly using LaunchBackground color)
- All camera, localization, and branding settings

## Validation Checklist ✓

| Check | Status |
|-------|--------|
| **Device Family** | iPhone only (`"1"`) |
| **Orientations** | Single Portrait in Info.plist (matches capability) |
| **iPad Entries Removed** | ~ipad orientation variant removed |
| **Launch Screen** | Modern UILaunchScreen API (valid) |
| **LSRequiresIPhoneOS** | `<true/>` (correct) |
| **Bundle Icon** | CFBundleIconName points to AppIcon set ✓ |
| **No Conflicting Keys** | UIRequiresFullScreen removed ✓ |

## Next Steps

1. Push these changes to your branch
2. Codemagic will regenerate the Xcode project with correct settings
3. Run the full archive build and validation
4. Upload to App Store Connect — should now pass validation (error 90474 resolved)

## Why This Fix Works

- When `TARGETED_DEVICE_FAMILY: "1"` (iPhone only) is set, iOS ignores the ~ipad variant
- App will only run on iPhone, preventing any rotation conflicts
- XcodeGen will regenerate the Xcode project with these corrected settings on next CI build
- No business logic or view code was modified — only project configuration

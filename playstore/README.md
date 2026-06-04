# Play Store Package

Prepared draft assets and text for the Cellular Google Play listing.

## Text

- `text/app_name.md`
- `text/short_description.md`
- `text/full_description.md`
- `store-listing.md`
- `privacy_policy.md`

Copy lengths:

- App name: 8/30 characters
- Short description: 71/80 characters
- Full description: about 960/4,000 characters

## Images

- `images/app-icon-512.png` - 512x512 PNG with alpha for the Play listing icon.
- `images/feature-graphic-1024x500.png` - 1024x500 PNG feature graphic.
- `images/cellular-title-screen.png` - title screen screenshot.
- `images/cellular-puzzle-mode.png` - Puzzle mode screenshot.
- `images/cellular-arcade-mode.png` - Arcade mode screenshot.

The feature graphic is composed from the title screen on the left and Arcade mode on the right. The Android launcher icons used by the export presets live in `graphics/android/`.

## Release Notes

- Android package id: `org.grassecon.cellular`
- App name: `Cellular`
- Current source version comes from `project.godot`.
- The app is intentionally silent and requests no sensitive Android permissions.
- The privacy policy assumes local progress storage only, with no ads, analytics, accounts, or network collection.

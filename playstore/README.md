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
- `images/feature-graphic-1024x500.png` - 1024x500 PNG feature graphic for the main store listing.
- `images/cellular-title-screen.png` - title screen screenshot.
- `images/cellular-puzzle-mode.png` - Puzzle mode screenshot.
- `images/cellular-arcade-mode.png` - Arcade mode screenshot.
- `images/phone/` - 1080x1920 phone screenshots.
- `images/tablet-7/` - 1440x2560 7-inch tablet screenshots.
- `images/tablet-10/` - 1440x2560 10-inch tablet screenshots.
- `images/play-games/play-games-logo-600x400.png` - transparent 600x400 logo for the Google Play Games game card.
- `images/play-games/play-games-logo-name-icon-600x400.png` - transparent 600x400 logo combining `cellular-name.png` with `app-icon-512.png`.
- `images/play-games/play-games-feature-1920x1080.png` - 16:9 no-marketing-text game card feature graphic.
- `images/play-games/play-games-feature-name-logo-1920x1080.png` - preview-style 16:9 feature graphic with Puzzle on the left, Arcade on the right, and centered name/logo overlay.

The feature graphic is composed from the title screen on the left and Arcade mode on the right. The Android launcher icons used by the export presets live in `graphics/android/`.

## Release Notes

- Android package id: `org.grassecon.cellular`
- App name: `Cellular`
- Current source version comes from `project.godot`.
- The app is intentionally silent and requests no sensitive Android permissions.
- The privacy policy assumes local progress storage only, with no ads, analytics, accounts, or network collection.

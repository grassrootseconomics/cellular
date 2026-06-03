# Cellular Web And Play Store Publication Checklist

Last checked: 2026-06-03.

## Summary

Cellular is close for Android and Play Store testing. Godot 4 C#/.NET projects still cannot export directly to Web, so the web release uses a GDScript-only runtime shim exported from a temporary non-.NET project copy. Android Play Store release can proceed after build, QA, listing, policy, and testing work.

## Release Blockers

- [ ] Finish validating the GDScript-only web runtime shim against Puzzle levels 1-44.
- [ ] Verify Android export with Godot .NET 4.6.3 using the `Android-PlayAAB` preset.
- [ ] Replace stale Play Store copy, screenshots, and privacy placeholders in `playstore/`; those files are not submission-ready.
- [ ] Confirm `org.grassecon.cellular` is the final package id before first Play upload. Android package ids are effectively permanent after publishing.
- [ ] Confirm release versioning: align `project.godot` `0.1.0` with export preset `version/name="1.2.5"` and increment `version/code`.

## Game QA

- [ ] Full playthrough Puzzle levels 1-44 on desktop and Android.
- [ ] Verify Level 44 win panel, Main Menu return, reset progress behavior, and saved progress.
- [ ] Verify Arcade: inventory generation, myco behavior, clears, game over, high score, reset progress, and mobile layout.
- [ ] Test Android touch UX on narrow phone and tablet-like layouts.
- [ ] Test title screen readability, buttons, animated title, icons, and no legacy art/audio showing.
- [ ] Check exported package contents do not include solution spoilers, generated solver output, old scenes, old graphics, or old audio.
- [ ] Run final checks when ready:
  - `dotnet build Cellular.csproj`
  - `dotnet test sim/CellularSim.Tests`
  - Android debug APK install
  - Release AAB export

## Web Checklist

- [ ] Validate the GDScript shim through representative parity fixtures and all Puzzle levels 1-44.
- [ ] Export a release Web build with `bash scripts/export_web_gdscript.sh`.
- [ ] Preserve or copy `CNAME` into the deployed web output if using GitHub Pages or a custom domain.
- [ ] Verify PWA icons, manifest, service worker, offline behavior, local save persistence, and mobile browser touch layout.
- [ ] Serve with the required headers if using web features that need cross-origin isolation; the current Web preset enables PWA cross-origin isolation.
- [ ] Test in Chrome, Firefox, and Android Chrome, including first load, refresh, offline reload, and reset progress.

## Play Store Checklist

- [ ] Ensure the Play AAB targets API 35 or higher. The current `Android-PlayAAB` preset has `target_sdk="35"`.
- [ ] Create and upload a signed AAB through Play App Signing.
- [ ] Verify app name `Cellular`, package id, app icon, adaptive icons, category, orientation, no unnecessary permissions, and no internet permission unless intentionally needed.
- [ ] Prepare store listing: short description, full description, feature graphic, phone screenshots, tablet screenshots, app icon, support email, and support site.
- [ ] Write final privacy policy naming Cellular and the developer/entity. If the app only stores local progress and collects nothing, say that clearly.
- [ ] Complete Play Console App content: Data safety, content rating, target audience/age, ads declaration, government apps, financial features, health, news, and data deletion if applicable.
- [ ] Run internal testing first, then closed testing. New personal Play developer accounts must run a closed test with at least 12 opted-in testers for 14 continuous days before applying for production access.
- [ ] Review pre-launch report crashes, warnings, device compatibility, Android vitals, and policy warnings before production rollout.
- [ ] Roll out gradually, watch crashes/freezes and user feedback, then expand.

## Repo And Release Hygiene

- [ ] Commit all intended cleanup/export changes; avoid committing local build outputs.
- [ ] Keep old source scenes/assets in repo for now, but excluded from exports.
- [ ] Tag the release commit.
- [ ] Record Godot version, .NET version, export preset, version code/name, and commit SHA.
- [ ] Archive final AAB and Web build artifacts outside the repo or under ignored `build/`.

## References

- Godot Web export docs: <https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html>
- Google Play target API requirement: <https://developer.android.com/google/play/requirements/target-sdk>
- Google Play testing requirements for new personal accounts: <https://support.google.com/googleplay/android-developer/answer/14151465>
- Google Play Data safety form: <https://support.google.com/googleplay/android-developer/answer/10787469>

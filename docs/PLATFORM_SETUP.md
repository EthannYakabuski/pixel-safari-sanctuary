# Android integrations and build handoff

This project targets Godot **4.5.1 Compatibility**, Android (API35 target, min24), and a single-threaded Web export. Windows desktop builds are outside its scope. Production Play publication remains a separate human step: verify the then-current target API policy before release; a successful API35 test build is not a claim of current store-submission eligibility.

## Runtime services

`Services` is the game-facing adapter. Its Android implementation calls the supplied Poing AdMob **5.1.0** and Godot Play Games Services **3.4.0** packages. The Web/editor implementation never simulates a successful rewarded ad. Gameplay, saves, achievements and best scores continue locally.

- Menu banner: native 320x50 banner anchored at the screen bottom. Menus must leave room for it; gameplay calls `set_menu_visible(false)`.
- Interstitials: every second completed round/outage/job, when an ad is loaded; no added fixed-time throttle. Failed/unavailable ads do not prevent play.
- Rewarded: opt-in, available only after a real native rewarded ad loads; benefits granted only on the earned-reward callback, once per request. Dismissal/failure grants nothing.
- Consent: refresh UMP consent at Android launch, show a required form, and initialize advertising only after `OBTAINED` or `NOT_REQUIRED`. A privacy-options action is exposed. Without configured/available consent information, requests pause and gameplay continues. Google's sample AdMob app does not prove the publisher's eventual privacy-message configuration; this requires human final configuration/testing.
- Play Games: disabled until real app configuration is provided. Local unlocks and best scores are retained in `user://platform_pending_v1.json` and resubmitted idempotently after sign-in. Only the configured symbolic keys map to remote IDs.

## Human configuration

1. Keep test IDs in use during development. Google's Android sample app ID and banner/interstitial/rewarded units are in `platform/config.json`. The Android application-ID manifest setting is in `project.godot` (`admob/general/android/app_id`), so update both config and project setting together for production.
2. In `platform/config.json`, fill `play_games.game_id`, set `enabled` to true, and map every game/catalog achievement and leaderboard key to its console ID. Set the same numeric game ID in `export_presets.cfg` (`godot_play_game_services/game_id`). The export's value `0` is a deliberate inactive placeholder, not a working Google project.
3. Configure package name, OAuth clients/signing fingerprints, authorized testers, Play Games resources, AdMob app/privacy messages, audience and production ad IDs in the owner's consoles. Supply signing material outside source control. Confirm applicable consent/audience settings before production.
4. Test real sign-in cancellation/failure, score/achievement submission, consent/privacy options, all test-ad formats, save persistence, offline behavior, and suspend/resume on the intended devices. Human production-ID/backend testing is distinct from passing local/CI tests.
5. Google Play publication remains the owner's responsibility. No workflow submits to Google Play or uses production signing keys.

## Build

Install/reuse Godot4.5.1, its matching export templates, Java17 and Android SDK platform35/build tools35, NDK28.1.13356709. The existing PC already supplies these tools; the hosted workflow provisions its own isolated runner dependencies.

```sh
godot --headless --editor --path . --import
godot --headless --path . --script platform/tests/services_smoke.gd
godot --headless --path . --install-android-build-template --export-debug Android build/android/game-debug.apk
godot --headless --path . --export-release Web build/web/index.html
```

Create output directories first. A debug APK is installable test software; it is not a production-signed release. The preset includes x86 for the existing API30 emulator and ARM64 for current phones. Release/AAB signing is performed only when the owner supplies signing configuration. `android/build` is generated from matching Godot templates and must not be committed with machine-local SDK paths/caches/keys.

Enable `rendering/textures/vram_compression/import_etc2_astc=true` in project settings before importing assets for Android. Keep desktop texture import enabled for Web. Tests, test-only platform scripts, captures, marketing packages, helper scripts, logs and documentation are excluded from shipping resource packs. Copy the app icon to `platform/app-icon-512.png` and point the project icon setting there so excluding `marketing/` does not remove its runtime resource. Game catalogs and runtime art/audio remain included.

Hosted Actions verifies pinned Godot download digests, builds the native Android APK, validates Web/editor service fallback behavior, discovers and runs `tests/test_*.gd`, `tests/*_test.gd`, and `tests/smoke.gd` (requiring at least one), exports Web, retains Android artifacts seven days, and deploys Pages. Test processes have bounded timeouts; logs containing script/parse/assertion errors fail even if Godot exits0. CI does not substitute for human playtesting or verify unpublished Google service IDs. The repository's Pages source must be GitHub Actions.

## Vendored dependencies and notices

- `addons/GodotPlayGameServices`: user's supplied3.4.0 copy, including required MIT license and native debug/release AARs.
- Its copied exporter checks Android build templates only for Android exports, avoiding irrelevant warnings during Web export.
- `addons/admob`: user's supplied5.1.0 source, MIT license retained. Native Android `ads`/core AARs came from the official `android-template-v4.5.1.zip` release asset: https://github.com/poingstudios/godot-admob-plugin/releases/download/v5.1.0/android-template-v4.5.1.zip . SHA256 `f7fdf644d50c0e231d8f02ae044057e489d0bcafcf50e908a4858477e7ee05ee` verified against GitHub's release digest.
- No mediation networks or iOS binaries are bundled. A documented one-line change removes the copied AdMob editor's automatic binary installer call because Android binaries are already vendored and iOS is outside this project. Runtime APIs and native exports remain intact. Original source asset folders are untouched.
- Original project code uses Apache2.0; third-party components retain their own licenses. Preserve notices in the repository and distributed game's credits/licenses screen.

Public upstream references: https://github.com/poingstudios/godot-admob-plugin and https://github.com/godot-sdk-integrations/godot-play-game-services .

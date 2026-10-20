# Pixel Safari Sanctuary

A little sanctuary. A world of curious creatures.

Explore a safari, capture creatures, and bring them home. Manage enclosures and collect income; discover specific-parent breeding recipes and breeding-only species across five rarity tiers. Build a collection of 200 creatures, advance your keeper level, and claim a seven-day login reward.

## Play

Choose a safari habitat, tap a creature, and time your capture action. Return home to assign enclosure residents, collect income, upgrade pens, and select breeding parents. The journal, milestones, daily gifts, and settings are available from the main navigation.

The game supports touch and mouse input, portrait layouts, offline/local progress, achievements and player progression. Web play keeps Android-only ads and Google Play Games features unavailable without blocking the game. Rewarded benefits require the real earned-reward callback; the browser does not grant simulated ad rewards.

## Development

Original code: Apache-2.0. Developer/repository owner: [EthannYakabuski](https://github.com/EthannYakabuski). Third-party assets and plugins retain their own licenses and notices.

Use Godot **4.5.1**, the **Compatibility** renderer, and matching export templates. Android uses Java 17, the Android SDK and a Gradle build. See [native setup and configuration](docs/PLATFORM_SETUP.md). No Windows build is part of the deliverables.

```sh
godot --headless --editor --path . --import
godot --headless --path . --script tests/model_test.gd
godot --headless --path . --script platform/tests/services_smoke.gd
godot --headless --path . --export-release Web build/web/index.html
godot --headless --path . --install-android-build-template --export-debug Android build/android/game-debug.apk
```

Create build/web and build/android before exporting. The Android application ID is `com.ethannyakabuski.pixelsafari`. Debug APKs include ARM64 and x86 for the supplied test environment. Exported debug builds are for testing; Google Play publication and final release signing remain with the human owner.

## Integration and handoff

AdMob is wired with Google's official Android test app/ad-unit IDs. Banner placement is on menus; interstitial opportunities occur every two completed rounds; rewarded offers grant their benefit only after the native earned-reward event. Consent-unavailable/no-fill conditions leave normal gameplay available. Google Play Games integration is prepared with local pending achievements/scores and symbolic ID maps; production setup is disabled until the owner supplies real IDs and console credentials. See platform/config.json and docs/PLATFORM_SETUP.md.

Store text, app/achievement/leaderboard icons, feature art and screenshot provenance are in marketing/. The human owner performs final backend configuration and testing, human playtesting and Google Play publication. Current build/verification status is recorded in HANDOFF.txt; do not infer production service verification from local or mocked tests.

## CI and Web

The hosted GitHub Actions workflow imports resources, requires game and service tests, exports Web and a native Android debug APK, then deploys Web to GitHub Pages. Build outputs and signing keys are excluded from source control. Actual workflow/deployment results are recorded in the handoff after publication.

## Future extension

Moonlit Wetlands: a bioluminescent habitat and another breeding branch. This is a future content idea; the initial game is intended to be independently playable.

The Android test preset uses minimum API 24 and target API 35 with Android texture imports enabled. This does not establish current Google Play release eligibility; release signing, backend configuration and current store requirements need final owner verification.

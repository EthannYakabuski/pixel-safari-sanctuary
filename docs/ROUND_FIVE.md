# Round Five: economy and ad discovery

## Requested changes

- Meadow upgrades cost exactly 25 times their previous price: `5500 * current_level^2`. Existing levels, residents and balances are retained.
- Opening a meadow costs exactly 100 times the earlier final integer price. With one meadow, the next costs 30,000 coins. Existing meadows and balances are not reset or charged retroactively.
- During an active Safari, the native banner moves to the top. The shell and modal reserve its measured height (or conservative 50dp fallback), top safe inset and 12dp padding. Menus retain the bottom banner. Bottom navigation insets remain reserved during Safari. Web/editor never fabricate a banner or an ad reward.
- Interstitial opportunities occur on saved completed-outing totals 5, 10, 15, and so on, at the natural return boundary. Capture hits/misses and inspection do not advance the cadence. An outing with at least one actual capture attempt uses the existing completed-outing definition; empty immediate returns do not count. Duplicate return notifications do not advance the counter. No startup catch-up ad is shown; unavailable ads leave normal play intact.
- Unowned Common, Uncommon and Rare silhouettes in the field guide offer an opt-in rewarded discovery. An available, earned native callback grants exactly the selected species as one resident. Eligibility includes nursery-only species in those three tiers. Endangered and Extinct species cannot request or receive this reward. Dismissal, failure, unavailable ads and duplicate/late callbacks grant no extra resident. This discovery does not award Safari capture statistics, coins or XP. Existing capture, breeding, bond and income rules remain available.

## Acceptance coverage

The focused `tests/round_five_test.gd` fixture checks exact prices and deductions, existing-save balances/levels, eligibility across all 200 species, duplicate grants, saved rewarded residents, top/menu banner selection and reserve calculations, saved fifth-outing boundaries, silhouette bindings and reward failure/duplicate paths. It uses synthetic callbacks and viewport geometry, not a real ad or native-device capture.

The fixture refuses Android and requires `DOTS_TEST_ROOT` to be the parent of process-isolated Godot user data. Set both APPDATA and LOCALAPPDATA on Windows, or XDG_DATA_HOME/XDG_CONFIG_HOME on Linux, to fresh children of that root. A guard flag alone does not isolate data. The hosted game-test step provides fresh directories for each test. Keep the existing strict script/parse/assertion/engine-error gate.

Verified locally on 2026-10-29 with Godot 4.5.1: strict import; this fixture (1,005 checks); `model_test.gd` (200); `round_two_test.gd` (7,344); `round_four_test.gd` (145); `ui_test.gd` (40); and the service callback/safe-area smoke test. All passed with zero strict engine/script/parse/assertion errors and fresh process-isolated profiles. The focused fixture verifies all 200 species and the 168 eligible locked silhouettes in a fresh profile, plus header/capture rectangles at 540x960, 600x960 and 800x1280. These are synthetic viewport and callback tests, not native acceptance. Existing large-sanctuary tests use a larger synthetic purse to exercise capacity with the new prices; purchase assertions remain intact.

## Native and owner limits

New native banner placement, actual earned-ad/presentation/dismissal callbacks, Android touch behavior, background/resume, persistence after real rewards, physical-device and audible validation remain separate acceptance checks. Web/source tests do not establish those outcomes. Previous screenshots and frozen APK/AAB exports retain their original source/hash provenance and do not contain these changes. Service IDs, AdMob test units, signing, production accounts and genuine profiles are unchanged by this update.

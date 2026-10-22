# Round Two rules and save contract

## Current qualified native checkpoint

Current runtime `e3e6fee4a8b9ebaff87f68951150e7cdb32c64a7` / APK `8B60DB643829B3333E31E1AEDBBD6DFB2AE133E680F464F48128221F76D5559C` has accepted Android/Web exports and passing [exact source CI](https://github.com/EthannYakabuski/pixel-safari-sanctuary/actions/runs/39719396352). One actual two-stage Common chain returned one resident with +20 coins/+34 XP once; result close, Home Back and a subsequent cold launch duplicated no reward. Home Back stayed on Home with the process alive, matching source policy; it was not graceful quit. Eighteen unchanged actual images are approved in their earlier selection contexts; their pending-catch language is historical, while the later catch proof is separate. Original display/radios/connectivity, genuine newest progress and stopped backup were verified. Offline remains unverified because the guest never disconnected. Broad native gate stays false for a goldfish VP9 diagnostic and retained earlier Google Mobile Ads callback qualification; no earned-ad, new high-parent breeding wait, auditory/physical-device, production, interactive-Web or general performance acceptance is claimed.

The game remains Godot 4.5.1 Compatibility, Android primary and Web secondary. Test AdMob units and disabled production Play Games placeholders are unchanged. Follow `PLATFORM_SETUP.md` before configuring services.

## Player loop

- Fresh keepers receive 40 coins, one meadow and two residents. Safaris are free; passive income and the daily gift prevent a coin lock. Existing save balances are retained.
- Meadows have no count limit and the interface pages through six at a time. Each card shows the computed coins/minute for its actual residents, species levels and meadow level.
- A safari lasts up to 90 seconds. Four starting lures can be upgraded to twelve. Each lure starts a complete capture chain, including its first stage; choosing another creature spends another lure. A miss ends the chain and never awards a creature. A successful chain returns one resident immediately.
- Common, uncommon, rare and endangered captures require two, three, four and five consecutive hits. Position, width and speed vary with the encounter, species and stage. The drawn gold bar and model use the same exact window.
- The first trail repeats eight common species. Later trails use curated pools with increasing uncommon, rare and endangered chances. Nursery-exclusive species remain excluded from every wild pool.
- Eight trails unlock through both keeper levels and completed outings: Meadow Footpath (1/0), Fern Brook (3/15), Sunstone Ridge (5/40), Moonlit Marsh (7/80), Tidepool Coast (10/130), Copperwood Grove (13/200), Frostglass Pass (16/290), Starfall Hollow (20/400). XP alone cannot skip the outing milestones.
- Each duplicate capture or duplicate hatch adds a shared species bond level, up to level 50. Every resident of that species gains 10% of base income per extra level. Both exact recipe parents need bond level 5; parents remain owned. The first nursery recipe takes six minutes and 300 coins before any earned rewarded-ad acceleration.
- Meadow income adds variety (5% per additional distinct species, up to 25%), a shared home-affinity theme (25% with at least two residents), and named friendship pairs (12% per pair, up to 36%). The field guide explains each owned species' home affinity and friendship partners. Home affinity is the catalog's `biome` field, separate from encounter location.
- Existing daily rewards, UTC rollover, eight-hour offline income cap, achievements, leaderboard keys and real earned-ad callback contract remain intact. Immediate empty returns grant no XP, coins or completed outing. Partially attempted returns grant no economy reward unless all lures were exhausted or a resident was caught.

## Save compatibility

`user://sanctuary-v1.json` remains the filename so existing installs find their progress. Its payload version is now 2. The load path validates a primary file, then its backup, before migration; writes remain atomic with a previous-file backup.

Version 1 migration retains coins, total XP, exact previously earned keeper rank, resident copies and placements, all existing meadows, bank, daily/quest history, settings, achievements, nursery deadlines and legitimately secured unbanked catches. Old duplicate copies become species bond progress. Previously open trails 0-2 remain open. A legacy outing may bank its earlier multiple catches once; subsequent outings use the new one-resident limit. No existing balance is reset to the new starter purse.

## Verification and remaining release work

Run `tests/model_test.gd`, `tests/round_two_test.gd`, `tests/ui_test.gd` and `platform/tests/services_smoke.gd` with isolated process-local user-data directories. The Round Two suite checks malformed saves, legacy migration, JSON numeric reloads, reward idempotency, strict misses, chain stages, 40 meadows, progression gates and 7,200 curated encounter samples. UI tests exercise pointer scrolling/navigation, chain return, nursery callbacks, meadow paging and explicit rarity/level cards.

Desktop/offscreen and fixture tests do not establish native-device, production service or auditory validation. Original local QA binaries belong to the earlier source revision. Accepted exports, exact source CI and the eighteen image-only views are recorded in the current checkpoint above. The actual catch, once-only close/Back/cold scope and remaining limitations are recorded in docs/NATIVE_QA.json and HANDOFF.txt. Keep private fixtures, logs, player data and old APKs outside public tracked documentation.

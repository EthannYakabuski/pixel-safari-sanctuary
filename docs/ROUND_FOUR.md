# Round Four: gifts and safari choices

## Daily rewards

Daily coin gifts are 100 times the earlier amounts: days 1, 2, 4 and 6 give 6,000 / 9,000 / 18,000 / 35,000 coins. Days 3, 5 and 7 instead bring one randomly selected Rare resident from the wild Rare roster, with no coin gift. Nursery-exclusive species remain exclusive to breeding. Every daily gift also grants 100 times its earlier XP (day number × 500). The field-note quest gives 12,000 coins and 3,500 XP.

The selected Rare species is recorded as part of the claimed UTC-day gift. Reopening the gift page does not select an outcome, and repeat claims/reloads grant nothing. Gifts use normal collection assignment: a new species joins the field guide; a duplicate increases its species bond level. They do not invent capture/outings statistics or complete the daily capture quest.

## Explore, inspect, capture or skip

Tapping a wild creature now shows its name, rarity, owned resident count, shared bond level, home affinity and required consecutive capture hits. Inspection consumes no lure, starts no minigame and leaves all three offers unchanged. The newly visible **Capture** button starts the existing capture chain and spends one lure. During a chain the chosen creature remains fixed; finish the chain or miss before changing targets.

**Skip clearing** generates a new set of offers and spends 1, 1, 2, 3, 5, 8… lures for successive skips. The next cost is always visible. It resets to 1 for each new expedition, but does not reset when selecting creatures or reloading saved model state. A skip is unavailable during an active capture or when its next cost exceeds remaining lures. No currency/XP/resident reward is granted merely for skipping. Existing 90-second outing and one-resident return rules remain.

## Save and verification contract

The filename and v2 payload remain compatible. Optional gift record/seed and outing skip/spend/generation fields are added on load without resetting existing coins, XP, residents, claimed days, nursery timers, active capture stages or settings. Skip spend is included in the validated lure budget.

Run isolated `tests/round_four_test.gd` together with model, Round Two, UI and service smoke tests. These source fixtures test rewards, deterministic retained gift identity, repeat/cold claims, bonds, Fibonacci affordability, offer stability and additive legacy migration; they are not native gameplay or production-ad evidence. Round Four Android/Web exports, affected native UI review and publication/CI results are recorded separately by the coordinator. Earlier handoff APKs and screenshot evidence retain their original source provenance.

## Qualified source/export and limited Web checkpoint (2026-10-24)

Public source `8403a38f173210c307217d6a928a7dc132d71f35` has [passing exact-commit hosted CI](https://github.com/EthannYakabuski/pixel-safari-sanctuary/actions/runs/40125619333). `../HANDOFF.txt` records the frozen AAB/Web/test-ZIP component source identities and hashes; no rebuild or archive change is made by this documentation update.

Limited interactive Web checks in an isolated browser profile on the frozen Web export verified stable encounter metadata and the same three offers; lures remained 4 while selecting creatures. Skip clearing spent one lure (4 to 3), replaced the offers and cleared selection; inspection kept three lures. Explicit Capture spent one lure (3 to 2) and started Stage 1 of 2 with Skip disabled. One genuine Secure-stage attempt missed; natural 90-second expiry returned zero residents, coins and XP. Successful capture/completed-chain payout, actual future daily gifts and native behavior remain unverified. Missing symbol glyphs, a partially scrolled Capture card at 720x1280 and aborted startup resource requests remain qualified; no blanket clean-log or native-touch/readability claim follows.

Still required: successful completed capture and once-only payout/close/reload checks, actual future daily gift paths, affected Android/native encounter/Skip/Capture checks, real SDK callbacks/ad return and banked-save behavior on the new binary, materially changed current-build Android captures, intended physical-device, audible-output and production-service testing. No new Round Four Android screenshots are accepted. Historical APKs, screenshots and earlier checkpoint text retain only their named source/build scope.

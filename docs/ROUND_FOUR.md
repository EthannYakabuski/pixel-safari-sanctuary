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

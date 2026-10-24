extends SceneTree

const Model = preload("res://game/model.gd")
const T = 20000 * 86400
var data: Dictionary
var assertions = 0
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)

func same_payload(a: Variant, b: Variant) -> bool:
	# JSON numbers reload as floats; compare normalized payloads without dropping fields.
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func fresh() -> RefCounted:
	return Model.new(data, T)

func _initialize() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://game/catalog.json"))
	var model = fresh()
	model.state.daily_gift_seed = 235713
	var residents = model.total_creatures()
	var gift_ids: Array[int] = []
	for day in range(1, 8):
		model.tick(T + (day - 1) * 86400)
		var xp = int(model.state.xp)
		var old_count = model.total_creatures()
		var old_stats = model.state.stats.duplicate(true)
		var gift = model.claim_daily()
		check(not gift.is_empty() and int(gift.day) == day, "consecutive day grants one typed reward")
		check(int(gift.xp) == day * 500 and int(model.state.xp) == xp + day * 500, "daily gift XP is exactly100x")
		if day in [3, 5, 7]:
			var id = int(gift.creature)
			gift_ids.append(id)
			check(int(gift.coins) == 0 and gift.rare_creature, "rare days replace the coin gift")
			check(int(model.species(id).rarity) == 2 and not model.species(id).breeding_only, "gift is actual wild Rare species without bypassing nursery exclusives")
			check(model.total_creatures() == old_count + 1 and model.count(id) > 0, "rare gift enters the resident collection")
		else:
			check(int(gift.coins) == [6000, 9000, 13000, 18000, 25000, 35000, 60000][day - 1], "ordinary daily coin gift is exactly100x")
			check(int(gift.creature) == -1 and model.total_creatures() == old_count, "ordinary daily gift grants no surprise creature")
		check(model.state.stats == old_stats, "login gifts do not invent captures/outings/quest progress")
		var after = JSON.stringify(model.state)
		check(model.claim_daily().is_empty() and JSON.stringify(model.state) == after, "repeat claim cannot duplicate coins/XP/rare resident")
		var path = "user://round-four-daily.json"
		check(model.save_to(path) == OK, "typed daily reward persists atomically")
		var restored = fresh()
		check(restored.load_from(path, model.clock), "daily save reloads")
		check(same_payload(restored.state.last_daily_gift, model.state.last_daily_gift), "reload retains the actual claimed rare identity, no reroll")
		check(restored.claim_daily().is_empty() and restored.total_creatures() == model.total_creatures(), "reload cannot claim or duplicate a gift")
		model = restored
	check(model.total_creatures() == residents + 3, "seven-day track gives exactly three residents")
	model.tick(T + 7 * 86400)
	check(int(model.claim_daily().coins) == 6000 and int(model.state.streak) == 1, "seven-day track returns to first coin gift")
	model.tick(T + 10 * 86400)
	check(int(model.claim_daily().coins) == 6000, "missed day starts a fresh week")
	model = fresh()
	model.state.daily_gift_seed = 97
	model.state.streak = 2
	model.state.last_daily = model.today() - 1
	# Source fixture compares claim against the same deterministic pool, not a real gameplay reward.
	var preview = fresh()
	preview.state = model.state.duplicate(true)
	var chosen = int(preview.claim_daily().creature)
	model.add_creature(chosen)
	var bond_before = model.species_level(chosen)
	check(int(model.claim_daily().creature) == chosen and model.species_level(chosen) == bond_before + 1, "duplicate rare gift increases shared species bond exactly once")
	check(model.claim_daily().is_empty() and model.species_level(chosen) == bond_before + 1, "duplicate gift cannot repeat bond increase")
	model = fresh()
	model.refresh_quest()
	model.state.stats.captures += 3
	var coins = int(model.state.coins)
	var xp = int(model.state.xp)
	check(model.claim_quest() and int(model.state.xp) == xp + 3500, "field-note XP is100x")
	check(int(model.state.coins) >= coins + 12000, "field-note coins are100x plus normal level-up rewards")
	var after_quest = JSON.stringify(model.state)
	check(not model.claim_quest() and JSON.stringify(model.state) == after_quest, "field-note reward remains once-only")
	model = fresh()
	model.state.lure_level = 8
	check(model.start_safari(0, 421), "twelve-lure outing starts")
	var offers: Array[int] = []
	for slot in range(3): offers.append(model.safari_species(slot))
	for cost in [1, 1, 2, 3, 5]:
		var before = int(model.state.safari.lures)
		check(model.safari_skip_cost() == cost and model.skip_safari(), "next clearing consumes next Fibonacci lure cost")
		check(int(model.state.safari.lures) == before - cost, "skip charges exact cost once")
		check(model.valid_save(model.state), "skip accounting remains a valid save")
		check(model.save_to("user://round-four-skip.json") == OK, "skip counter is saved")
		var reloaded = fresh()
		check(reloaded.load_from("user://round-four-skip.json", T), "skip save cold reload succeeds")
		check(same_payload(reloaded.state.safari, model.state.safari) and reloaded.safari_skip_cost() == model.safari_skip_cost(), "reload retains cost, offers, lures and generation")
		for slot in range(3): check(model.safari_species(slot) == reloaded.safari_species(slot), "reload preserves actual offers")
		model = reloaded
	check(model.safari_skip_cost() == 8 and int(model.state.safari.lures) == 0, "cost sequence reaches8 without exceeding twelve-lure budget")
	var exhausted = JSON.stringify(model.state)
	check(not model.skip_safari() and JSON.stringify(model.state) == exhausted, "unaffordable skip cannot alter offers/counter/state")
	model.finish_safari()
	check(model.start_safari(0, 421) and model.safari_skip_cost() == 1, "each new expedition resets skip costs")
	for slot in range(3): check(model.safari_species(slot) == offers[slot], "new outing original seed reproduces initial offers")
	var other_before = [model.safari_species(1), model.safari_species(2)]
	check(model.begin_capture(0), "explicit capture begins")
	check([model.safari_species(1), model.safari_species(2)] == other_before, "starting a chain does not change other displayed creatures")
	var active = JSON.stringify(model.state)
	check(not model.begin_capture(1) and not model.skip_safari() and JSON.stringify(model.state) == active, "active chain cannot be replaced or skipped to dodge lure cost")
	check(model.tap_capture(-1.0) == "miss" and model.can_skip_safari(), "after genuine modeled miss, skip becomes available")
	check(model.skip_safari() and model.valid_save(model.state), "miss+skip costs share the exact lure budget")
	var invalid = model.state.duplicate(true)
	invalid.safari.skipped_lures += 1
	check(not model.valid_save(invalid), "corrupt skip-spend count rejected")
	invalid = model.state.duplicate(true)
	invalid.safari.skips = -1
	check(not model.valid_save(invalid), "negative skip counter rejected")
	model = fresh()
	model.start_safari(0, 421)
	model.begin_capture(0)
	var legacy = model.state.duplicate(true)
	for key in ["skips", "skipped_lures", "encounter_round"]: legacy.safari.erase(key)
	legacy.erase("daily_gift_seed")
	legacy.erase("last_daily_gift")
	check(model.valid_save(legacy), "existing v2 active-chain save accepted without new optional fields")
	model.state = legacy
	check(model.save_to("user://round-four-legacy.json") == OK, "legacy fixture saved in isolated user data")
	var upgraded = fresh()
	check(upgraded.load_from("user://round-four-legacy.json", T), "legacy profile loads additively")
	check(same_payload(upgraded.state.safari.capture, legacy.safari.capture) and same_payload(upgraded.state.owned, legacy.owned) and upgraded.state.coins == legacy.coins, "migration preserves active capture, residents and coins")
	check(upgraded.valid_save(upgraded.state) and upgraded.safari_skip_cost() == 1, "migrated profile has valid initial skip counter")
	print("Round Four model: ", assertions, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

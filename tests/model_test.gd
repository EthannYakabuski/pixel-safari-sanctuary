extends SceneTree

const Model = preload("res://game/model.gd")
var failures: Array[String] = []
var assertions = 0
var data: Dictionary
const T = 20000 * 86400

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func fresh() -> RefCounted:
	return Model.new(data, T)

func _initialize() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://game/catalog.json"))
	var model = fresh()
	check(data.creatures.size() == 200, "200 creature roster")
	check(data.recipes.size() == 34, "34 explicit recipes")
	check(data.achievements.size() >= 20, "complete achievement catalog")
	for rarity in range(5):
		var present = false
		for creature in data.creatures:
			if int(creature.rarity) == rarity:
				present = true
		check(present, "rarity tier %d represented" % rarity)
	for recipe in data.recipes:
		check(int(recipe.parents[0]) < int(recipe.target) and int(recipe.parents[1]) < int(recipe.target), "recipe tree has no forward dependency cycle")
		check(data.creatures[int(recipe.target)].breeding_only, "recipe target is breeding exclusive")
	check(model.collection_size() == 2 and model.total_creatures() == 2, "starter creatures")
	check(model.player_level() == 1, "initial keeper level")
	check(model.income_per_second() > 0.0, "residents earn income")
	model.tick(T + 60)
	check(int(model.state.bank) == 11, "income for elapsed minute")
	var coins_before = model.state.coins
	check(model.collect_income() == 11 and model.state.coins == coins_before + 11, "collection transfers bank exactly once")
	check(model.collect_income() == 0, "cannot collect twice")
	model.tick(T + 60 + 86400)
	check(int(model.state.bank) == 5391, "offline income capped at eight hours")
	var bank_before = model.state.bank
	model.tick(T)
	check(model.state.bank == bank_before, "clock rollback does not grant duplicate income")
	model = fresh()
	check(model.claim_daily() == 60, "day-one login gift")
	check(model.claim_daily() == 0, "same-day gift cannot be repeated")
	for day in range(1, 7):
		model.tick(T + day * 86400)
		check(model.claim_daily() == Model.DAILY_COINS[day], "consecutive gift day %d" % (day + 1))
	model.tick(T + 7 * 86400)
	check(model.claim_daily() == 60 and model.state.streak == 1, "seven-day track resets")
	model.tick(T + 10 * 86400)
	check(model.claim_daily() == 60, "missed day restarts streak")
	model = fresh()
	check(not model.start_safari(2, 42), "highlands keeper gate")
	check(model.start_safari(0, 42), "free meadow safari starts")
	check(not model.start_safari(0, 42), "no overlapping outings")
	var other = fresh()
	other.start_safari(0, 42)
	check(model.safari_species(0) == other.safari_species(0), "seeded encounter determinism")
	for attempt in range(model.lure_capacity()):
		var id = model.safari_species(attempt % 3)
		check(not model.species(id).breeding_only, "wild encounters exclude nursery-only species")
		check(model.begin_capture(attempt % 3), "lure starts a whole chain")
		check(model.tap_capture(-1.0) == "miss", "outside-window tap never succeeds")
	check(model.state.safari.lures == 0, "one lure per whole-chain attempt")
	check(not model.begin_capture(0), "cannot capture after lures exhausted")
	var result = model.finish_safari()
	check(int(model.state.stats.outings) == 1, "outing counted once")
	check(int(model.state.stats.captures) == result.caught.size(), "captures banked on return")
	check(model.total_creatures() == 2 + result.caught.size(), "caught creatures arrive home")
	check(model.finish_safari().is_empty(), "return rewards cannot duplicate")
	model = fresh()
	model.start_safari(0, 42)
	var empty_return = model.finish_safari()
	check(empty_return.coins == 0 and empty_return.xp == 0 and model.state.stats.outings == 0, "instant empty returns cannot farm rewards or outings")
	model = fresh()
	model.state.coins = 100000
	var first = data.recipes[0]
	check(not model.can_breed(first), "level-one starters cannot bypass parent bond gate")
	for repeat in range(4):
		model.add_creature(0)
		model.add_creature(1)
	check(model.can_breed(first), "starter parents have first recipe")
	var first_parent_count = model.count(0)
	check(model.begin_breed(int(first.target)), "valid pair breeds")
	check(model.count(0) == first_parent_count, "parents are never consumed")
	check(model.hatch(0) == -1, "unready egg cannot hatch")
	model.tick(T + model.breeding_seconds(first))
	check(model.hatch(0) == int(first.target), "ready egg yields fixed species")
	check(model.count(int(first.target)) == 1, "new species is in collection")
	check(model.hatch(0) == -1, "hatched egg cannot duplicate")
	model.begin_breed(int(first.target))
	model.begin_breed(int(first.target))
	check(not model.begin_breed(int(first.target)), "nursery capacity is two")
	model.speed_nursery()
	check(model.hatch(0) >= 0 and model.hatch(0) >= 0, "earned acceleration matures current eggs")
	var locked = data.recipes[-1]
	check(not model.begin_breed(int(locked.target)), "missing exact parents block recipe")
	model = fresh()
	model.state.coins = 100000
	check(model.add_pen(), "resident-move fixture buys its second meadow")
	check(not model.assign(0, 1), "one individual cannot occupy two pens")
	check(model.remove_resident(0, 0) and model.assign(0, 1), "resident moves between pens")
	model.state.coins = 100000
	check(model.upgrade_pen(0) and model.pen_capacity(0) == 3, "pen upgrade increases capacity")
	while model.state.pens.size() < 12:
		check(model.add_pen(), "expand enclosure")
	check(model.add_pen() and model.state.pens.size() == 13, "meadows expand beyond the former six-meadow cap")
	model = fresh()
	model.refresh_quest()
	model.state.stats.captures += 3
	check(model.claim_quest() and not model.claim_quest(), "daily quest pays once")
	model.tick(T + 86400)
	check(model.quest_progress() == 0 and not model.state.quest_claimed, "new UTC day refreshes quest")
	model.add_xp(6000)
	check(model.player_level() > 5, "XP advances keeper levels")
	var unlocked = model.check_achievements()
	check(unlocked.has("first_friend") and unlocked.has("level_5"), "local achievements follow actual stats")
	check(model.check_achievements().is_empty(), "achievement unlocks are idempotent")
	var test_directory: String = OS.get_environment("TEMP")
	if test_directory.is_empty(): test_directory = OS.get_user_data_dir()
	var save_path = test_directory.path_join("pixel-safari-model-test-%d.json" % OS.get_process_id())
	check(model.save_to(save_path) == OK, "save succeeds")
	var restored = fresh()
	check(restored.load_from(save_path, T + 86400), "saved data loads")
	check(int(restored.state.coins) == int(model.state.coins), "save roundtrip preserves economy")
	check(restored.collection_size() == model.collection_size(), "save roundtrip preserves discovered species count")
	for creature_id in model.state.owned:
		check(restored.count(int(creature_id)) == model.count(int(creature_id)), "save roundtrip preserves creature counts")
	check(model.save_to(save_path) == OK, "second save creates backup")
	var corrupt = FileAccess.open(save_path, FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	check(restored.load_from(save_path, T + 86400), "corrupt primary recovers from valid backup")
	var bad = model.state.duplicate(true)
	bad.coins = -1
	check(not model.valid_save(bad), "negative economy save rejected")
	bad = model.state.duplicate(true)
	bad.owned = {"9999": 1}
	check(not model.valid_save(bad), "invalid species save rejected")
	var bad_values: Array = []
	for field in ["nursery", "stats", "safari", "achievements", "coins", "last_seen", "quest_claimed", "version"]:
		bad = model.state.duplicate(true)
		bad[field] = {"unsafe": true}
		if field == "achievements": bad[field] = []
		bad_values.append(bad)
	bad = model.state.duplicate(true)
	bad.nursery = [{}]
	bad_values.append(bad)
	bad = model.state.duplicate(true)
	bad.nursery = [{"target": 9999, "ready_at": T}]
	bad_values.append(bad)
	bad = model.state.duplicate(true)
	bad.nursery = [{"target": 110, "ready_at": "soon"}]
	bad_values.append(bad)
	bad = model.state.duplicate(true)
	bad.safari = {"habitat": 0, "seed": 1, "lures": 6, "caught": [9999], "attempts": 0, "started": T}
	bad_values.append(bad)
	bad = model.state.duplicate(true)
	bad.stats = {}
	bad_values.append(bad)
	for invalid in bad_values:
		check(not model.valid_save(invalid), "malformed nested data rejected before field access")
		var broken = FileAccess.open(save_path, FileAccess.WRITE)
		broken.store_string(JSON.stringify(invalid))
		broken.close()
		check(restored.load_from(save_path, T + 86400), "malformed primary recovers valid backup")
		check(restored.state.nursery.is_empty() and restored.state.stats.has("captures"), "recovery selects safe backup fields")
	var valid_nested = fresh()
	valid_nested.state.coins = 100000
	for repeat in range(4):
		valid_nested.add_creature(0)
		valid_nested.add_creature(1)
	check(valid_nested.begin_breed(110), "live save fixture has a legitimate nursery timer")
	valid_nested.start_safari(0, 451)
	valid_nested.begin_capture(0)
	valid_nested.tap_capture(float(valid_nested.capture_window().center))
	var parsed_save: Variant = JSON.parse_string(JSON.stringify(valid_nested.state))
	check(valid_nested.valid_save(parsed_save), "legitimate JSON float integers, live nursery and safari remain compatible")
	check(valid_nested.save_to(save_path) == OK and restored.load_from(save_path, T), "live timers and unbanked safari survive real save roundtrip")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(save_path + suffix)
	print("MODEL_TESTS assertions=", assertions, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

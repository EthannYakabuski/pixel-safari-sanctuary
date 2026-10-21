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

func fresh() -> RefCounted:
	return Model.new(data, T)

func capture(model: RefCounted, slot: int) -> int:
	if not model.begin_capture(slot): return -1
	var id = int(model.capture_window().id)
	var count = int(model.capture_window().required)
	for step in range(count):
		var window = model.capture_window()
		var result = model.tap_capture(float(window.center))
		check(result == ("caught" if step == count - 1 else "stage"), "every consecutive stage must succeed before a capture")
	return id

func _initialize() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://game/catalog.json"))
	var model = fresh()
	check(int(model.state.coins) == 40, "new keepers receive a small purse")
	check(model.income_per_second() > 0.0 and model.start_safari(0, 140), "starter residents and free first trail prevent a coin soft lock")
	check(Model.ZONES.size() == 8, "five new zones extend the original three")
	check(not model.zone_available(1) and not model.zone_available(7), "new profiles cannot unlock trails immediately")
	check(model.begin_capture(0), "selecting a creature starts a chain")
	var lures = int(model.state.safari.lures)
	check(model.begin_capture(0) and int(model.state.safari.lures) == lures, "reselecting the same chain does not consume another lure")
	var first = model.capture_window()
	check(int(first.required) == 2, "common creatures need two consecutive hits")
	check(model.tap_capture(float(first.left) - 0.0001) == "miss", "just outside the left boundary is a guaranteed miss")
	check(model.state.safari.caught.is_empty(), "a miss grants no hidden catch")
	for invalid in [-1.0, 2.0, NAN, INF]:
		model = fresh()
		model.start_safari(0, 140)
		model.begin_capture(0)
		check(model.tap_capture(invalid) == "miss" and model.state.safari.caught.is_empty(), "invalid or out-of-range markers cannot capture")
	model = fresh()
	model.start_safari(0, 140)
	model.begin_capture(0)
	var window = model.capture_window()
	check(model.tap_capture(float(window.left)) == "stage", "the visible left edge is inclusive")
	window = model.capture_window()
	check(model.tap_capture(float(window.right) + 0.0001) == "miss", "a later-stage miss breaks the entire chain")
	check(model.state.safari.caught.is_empty(), "a partial chain never adds a resident")
	model = fresh()
	model.start_safari(0, 140)
	var id = capture(model, 0)
	check(model.state.safari.caught.size() == 1, "complete chain secures one resident")
	check(not model.begin_capture(1), "an outing cannot secure a second new resident")
	var owned_before = model.total_creatures()
	var result = model.finish_safari()
	check(result.caught == [id] and model.total_creatures() == owned_before + 1, "the one secured resident arrives only on return")
	check(model.finish_safari().is_empty(), "a repeated return cannot bank again")
	model = fresh()
	model.state.coins = 1000000000
	for index in range(39): check(model.add_pen(), "meadow expansion continues beyond six")
	check(model.state.pens.size() == 40 and model.valid_save(model.state), "large sanctuary remains save-compatible")
	model = fresh()
	var base_income = model.income_per_second()
	check(model.species_level(0) == 1 and not model.can_breed(data.recipes[0]), "level-one parents cannot breed")
	for duplicate in range(4):
		model.add_creature(0)
		model.add_creature(1)
	check(model.species_level(0) == 5 and model.species_level(1) == 5, "repeat creatures grow separate species bond levels")
	check(model.income_per_second() > base_income, "species levels improve the income of existing residents")
	model.state.coins = 100000
	check(model.can_breed(data.recipes[0]), "level-five exact parents unlock their breeding recipe")
	check(model.breeding_seconds(data.recipes[0]) == 360, "first nursery project is a meaningful six-minute timer")
	check(model.breeding_cost(data.recipes[0]) == 300, "new breeding costs support the longer progression")
	var pair = model.meadow_income(0)
	check(absf(float(pair.pair) - 0.12) < 0.000001 and float(pair.diversity) > 0.0, "specific friendship pair and variety add distinct bonuses")
	model.state.pens[0].residents = [0, 8]
	model.state.owned["8"] = 1
	model.state.species_xp["8"] = 0
	check(float(model.meadow_income(0).theme) == 0.25, "same-home-habitat residents earn a theme bonus")
	model = fresh()
	model.state.coins = 1000000
	var start_capacity = model.lure_capacity()
	check(model.upgrade_lures() and model.lure_capacity() == start_capacity + 1, "satchel upgrade adds a whole-chain lure")
	model.start_safari(0, 42)
	check(not model.upgrade_lures(), "equipment cannot change the capacity of an active outing")
	model.finish_safari()
	for upgrade in range(Model.MAX_LURE_LEVEL - 1): check(model.upgrade_lures(), "further lure upgrades are purchasable")
	check(model.lure_capacity() == 12 and not model.upgrade_lures(), "satchel shows an honest twelve-lure equipment ceiling")
	model = fresh()
	model.add_xp(100000)
	check(not model.zone_available(7), "offline income or XP alone cannot skip expedition milestones")
	model.state.stats.outings = 400
	check(model.zone_available(7), "long-term keeper and expedition milestones open the last trail")
	var first_species: Dictionary = {}
	var late_rare = 0
	for zone in range(8):
		for seed_value in range(300):
			model.state.safari = {}
			model.start_safari(zone, 1000 + seed_value)
			for slot in range(3):
				var encountered = model.safari_species(slot)
				check(not model.species(encountered).breeding_only, "curated wild pools never bypass breeding exclusives")
				if zone == 0: first_species[encountered] = true
				if zone == 7 and int(model.species(encountered).rarity) >= 2: late_rare += 1
	check(first_species.size() == 8, "first trail deliberately repeats its eight common species")
	for key in first_species: check(int(model.species(int(key)).rarity) == 0, "first-trail duplicates are common")
	check(late_rare > 300, "rare/endangered encounters become substantially more common late")
	var centers: Dictionary = {}
	for seed_value in range(30):
		model = fresh()
		model.start_safari(0, 600 + seed_value)
		model.begin_capture(0)
		window = model.capture_window()
		centers[str(window.center)] = true
		check(float(window.left) >= 0.0 and float(window.right) <= 1.0, "all windows remain reachable inside the displayed bar")
	check(centers.size() > 10, "encounters move the capture window instead of repeating a centered target")
	model = fresh()
	model.state.keeper_level_base = 20
	model.state.stats.outings = 400
	var endangered_found = false
	for seed_value in range(200):
		model.state.safari = {}
		model.start_safari(7, seed_value + 100)
		model.begin_capture(0)
		window = model.capture_window()
		if int(model.species(int(window.id)).rarity) == 3:
			endangered_found = true
			check(int(window.required) == 5 and float(window.width) < 0.20 and float(window.speed) > 2.0, "endangered chains require five narrower, faster stages")
			break
	check(endangered_found, "late trail has real endangered encounters")
	var legacy = {"version": 1, "coins": 821, "xp": 5700, "owned": {"0": 5, "1": 3},
		"pens": [{"level": 2, "residents": [0,0,1]}, {"level": 1, "residents": [0,1]}, {"level": 1, "residents": []}],
		"bank": 17.5, "last_seen": T, "last_daily": 19999, "streak": 3, "login_days": 8,
		"stats": {"outings": 4, "captures": 9, "breeds": 2, "income": 700, "best_outing": 6},
		"achievements": {"first_friend": true}, "nursery": [{"target": 110, "ready_at": T + 600}],
		"safari": {"habitat": 2, "seed": 42, "lures": 3, "caught": [0,1], "attempts": 3, "started": T},
		"sound": false, "quest_day": 20000, "quest_baseline": 7, "quest_claimed": true}
	model = fresh()
	check(model.valid_save(legacy), "legitimate old profile passes the legacy validator")
	var folder = OS.get_environment("TEMP")
	if folder.is_empty(): folder = OS.get_user_data_dir()
	var path = folder.path_join("safari-r2-model-%d.json" % OS.get_process_id())
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy)); file.close()
	check(model.load_from(path, T), "legacy profile migrates through the actual load path")
	check(int(model.state.version) == 2 and model.valid_save(model.state), "migrated profile is a valid version-two save")
	check(model.player_level() == 12 and int(model.state.xp) == 5700 and int(model.state.coins) == 821, "migration retains exact keeper rank, total XP and coins")
	check(model.count(0) == 5 and model.assigned_count(0) == 3 and model.state.pens.size() == 3, "migration retains copies, residents and existing meadows")
	check(model.species_level(0) == 5 and model.species_level(1) == 3, "previous duplicates become earned bond levels")
	check(model.zone_available(2) and not model.zone_available(3), "previously unlocked zones survive new expedition gates")
	check(int(model.state.nursery[0].ready_at) == T + 600 and model.state.achievements.has("first_friend") and not model.state.sound, "eggs, achievements and settings survive migration")
	result = model.finish_safari()
	check(result.caught.size() == 2, "migration preserves all legitimately secured legacy catches")
	model.start_safari(0, 32)
	capture(model, 0)
	check(model.state.safari.caught.size() == 1 and not model.begin_capture(1), "the next new outing applies the one-resident limit")
	check(model.save_to(path) == OK, "version-two save writes atomically")
	var restored = fresh()
	check(restored.load_from(path, T), "live capture/profile version-two save reloads")
	check(JSON.parse_string(JSON.stringify(restored.state)) == JSON.parse_string(JSON.stringify(model.state)), "live capture/profile version-two save roundtrip retains every field")
	check(restored.zone_available(0) and restored.zone_available(2), "JSON numeric zone IDs retain their unlocks after reload")
	var invalid = model.state.duplicate(true)
	invalid.species_xp["0"] = "5"
	check(not model.valid_save(invalid), "malformed bond values are rejected")
	invalid = model.state.duplicate(true)
	invalid.safari.caught = [0,1]
	check(not model.valid_save(invalid), "a new save cannot claim two catches in one outing")
	invalid = model.state.duplicate(true)
	invalid.safari.lures = 1.5
	check(not model.valid_save(invalid), "fractional lure counts are rejected")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("ROUND_TWO_MODEL_TESTS assertions=", assertions, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

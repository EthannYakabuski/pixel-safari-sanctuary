extends RefCounted

const SAVE_VERSION = 2
const SAFARI_DURATION = 90
const MAX_LURE_LEVEL = 8
const BREED_LEVEL = 5
const MEADOW_UPGRADE_PRICE_MULTIPLIER = 25
const MEADOW_EXPANSION_PRICE_MULTIPLIER = 100
const ZONES = [
    {"name": "Meadow Footpath", "level": 1, "outings": 0, "description": "Eight familiar common friends. Build bonds before venturing further.", "color": "c9dcb1"},
    {"name": "Fern Brook", "level": 3, "outings": 15, "description": "Shaded streams and the first uncommon visitors.", "color": "aacdb8"},
    {"name": "Sunstone Ridge", "level": 5, "outings": 40, "description": "Warm rock shelves shelter a few rare companions.", "color": "ddc49f"},
    {"name": "Moonlit Marsh", "level": 7, "outings": 80, "description": "Patient explorers meet shy creatures in the reeds.", "color": "b8bad1"},
    {"name": "Tidepool Coast", "level": 10, "outings": 130, "description": "Salt air, rare finds and the first endangered visitors.", "color": "a8d0d0"},
    {"name": "Copperwood Grove", "level": 13, "outings": 200, "description": "Amber leaves conceal a very different field guide.", "color": "d9b48e"},
    {"name": "Frostglass Pass", "level": 16, "outings": 290, "description": "Hard-won bonds await beyond the snowy treeline.", "color": "c9dbe2"},
    {"name": "Starfall Hollow", "level": 20, "outings": 400, "description": "A late expedition where rare friends are less elusive.", "color": "bbb4d4"}
]
const ZONE_POOLS = [
    [[0,1,2,3,4,5,6,7], [], [], []],
    [[8,9,10,11,12,13,14,15,16,17,18,19], [80,81,82,83,84,85,86,87], [], []],
    [[20,21,22,23,24,25,26,27,28,29,30,31], [88,89,90,91,92,93,94,95], [145,146,147,148], []],
    [[32,33,34,35,36,37,38,39,40,41,42,43], [96,97,98,99,100,101,102,103], [149,150,151,152], []],
    [[44,45,46,47,48,49,50,51,52,53,54,55], [104,105,106,107,108,109,116,117], [153,154,155,156,157,158], [178,179,180]],
    [[56,57,58,59,60,61,62,63,64,65,66,67], [118,119,120,121,122,123,124,125], [159,160,161,162,163], [181,182,183]],
    [[68,69,70,71,72,73,74,75,76,77,78,79], [126,127,128,129,130,131,132,133,134], [164,165,166,167,168,169], [184,185,186]],
    [[0,1,2,3,4,5,6,7,72,73,74,75,76,77,78,79], [100,101,102,103,126,127,128,129,130,131,132,133,134], [145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169], [187,188,189]]
]
const ZONE_WEIGHTS = [[1.0,0.0,0.0,0.0],[0.90,0.10,0.0,0.0],[0.74,0.22,0.04,0.0],[0.63,0.28,0.09,0.0],[0.48,0.32,0.18,0.02],[0.35,0.36,0.25,0.04],[0.25,0.36,0.32,0.07],[0.17,0.34,0.37,0.12]]
const MEADOW_PAIRS = [[0,1],[2,3],[4,5],[6,7],[80,81],[88,89],[96,97],[104,105],[145,146],[153,154],[178,179],[187,188]]
const DAILY_COINS = [6000, 9000, 13000, 18000, 25000, 35000, 60000]
const DAILY_RARE_DAYS = [3, 5, 7]
const DAILY_XP_MULTIPLIER = 100
const QUEST_COINS = 12000
const QUEST_XP = 3500
const RARITIES = ["Common", "Uncommon", "Rare", "Endangered", "Extinct"]
var catalog: Dictionary = {}
var state: Dictionary = {}
var clock: int = 0

func _init(data: Dictionary = {}, now: int = 0) -> void:
	catalog = data
	clock = now if now > 0 else int(Time.get_unix_time_from_system())
	state = fresh_state(clock)

func fresh_state(now: int) -> Dictionary:
	return {"version": SAVE_VERSION, "coins": 40, "xp": 0, "owned": {"0": 1, "1": 1},
		"pens": [{"level": 1, "residents": [0, 1]}],
		"species_xp": {"0": 0, "1": 0}, "lure_level": 0, "unlocked_zones": [0],
		"keeper_level_base": 1, "keeper_xp_base": 0,
		"bank": 0.0, "last_seen": now, "last_daily": -1, "streak": 0, "login_days": 0,
		"stats": {"outings": 0, "captures": 0, "breeds": 0, "income": 0, "best_outing": 0},
		"achievements": {}, "nursery": [], "safari": {}, "sound": true,
		"quest_day": -1, "quest_baseline": 0, "quest_claimed": false,
		"daily_gift_seed": randi(), "last_daily_gift": {}}

func species(id: int) -> Dictionary:
	return catalog.get("creatures", [])[clampi(id, 0, catalog.get("creatures", []).size() - 1)]

func count(id: int) -> int:
	return int(state.owned.get(str(id), 0))

func collection_size() -> int:
	return state.owned.size()

func total_creatures() -> int:
	var total = 0
	for amount in state.owned.values():
		total += int(amount)
	return total

func player_level() -> int:
	var xp = maxi(0, int(state.xp) - int(state.keeper_xp_base))
	var level = int(state.keeper_level_base)
	while xp >= level_cost(level):
		xp -= level_cost(level)
		level += 1
	return level

func level_cost(level: int) -> int:
	return 150 + level * 65

func species_level(id: int) -> int:
	return 0 if count(id) == 0 else 1 + mini(49, int(state.species_xp.get(str(id), 0)))

func species_biome(id: int) -> int:
	return int(species(id).get("biome", id % ZONES.size()))

func breeding_level_ready(id: int) -> bool:
	return species_level(id) >= BREED_LEVEL

func level_progress() -> Vector2:
	var xp = maxi(0, int(state.xp) - int(state.keeper_xp_base))
	var level = int(state.keeper_level_base)
	while xp >= level_cost(level):
		xp -= level_cost(level)
		level += 1
	return Vector2(xp, level_cost(level))

func add_xp(amount: int) -> int:
	var before = player_level()
	state.xp += maxi(0, amount)
	var after = player_level()
	for level in range(before + 1, after + 1):
		state.coins += level * 20
	return after - before

func assigned_count(id: int) -> int:
	var total = 0
	for pen in state.pens:
		for resident in pen.residents:
			if int(resident) == id:
				total += 1
	return total

func pen_capacity(index: int) -> int:
	return 2 + int(state.pens[index].level) - 1

func income_per_second() -> float:
	var total = 0.0
	for index in range(state.pens.size()):
		total += float(meadow_income(index).rate)
	return total

func meadow_income(index: int) -> Dictionary:
	var pen: Dictionary = state.pens[index]
	var base = 0.0
	var unique: Dictionary = {}
	var biomes: Dictionary = {}
	for resident in pen.residents:
		var id = int(resident)
		unique[id] = true
		biomes[species_biome(id)] = true
		base += (0.08 + int(species(id).rarity) * 0.07) * (1.0 + (species_level(id) - 1) * 0.10)
	base *= 1.0 + (int(pen.level) - 1) * 0.20
	var diversity = minf(0.25, maxf(0.0, (unique.size() - 1) * 0.05))
	var theme = 0.25 if pen.residents.size() >= 2 and biomes.size() == 1 else 0.0
	var pair = 0.0
	for combination in MEADOW_PAIRS:
		if unique.has(combination[0]) and unique.has(combination[1]): pair += 0.12
	pair = minf(pair, 0.36)
	return {"rate": base * (1.0 + diversity + theme + pair), "base": base, "diversity": diversity, "theme": theme, "pair": pair}

func tick(now: int) -> void:
	clock = maxi(clock, now)
	var elapsed = clampi(clock - int(state.last_seen), 0, 28800)
	state.bank = minf(float(state.bank) + elapsed * income_per_second(), 250000.0)
	state.last_seen = clock
	refresh_quest()

func collect_income() -> int:
	var amount = int(state.bank)
	if amount <= 0:
		return 0
	state.bank = float(state.bank) - amount
	state.coins += amount
	state.stats.income += amount
	add_xp(maxi(1, int(sqrt(float(amount)))))
	return amount

func upgrade_cost(index: int) -> int:
	return MEADOW_UPGRADE_PRICE_MULTIPLIER * 220 * int(state.pens[index].level) * int(state.pens[index].level)

func upgrade_pen(index: int) -> bool:
	if index < 0 or index >= state.pens.size() or int(state.pens[index].level) >= 5:
		return false
	var cost = upgrade_cost(index)
	if int(state.coins) < cost:
		return false
	state.coins -= cost
	state.pens[index].level += 1
	add_xp(20)
	return true

func new_pen_cost() -> int:
	return MEADOW_EXPANSION_PRICE_MULTIPLIER * int(minf(9000000000000.0, 180.0 + pow(float(state.pens.size()), 1.45) * 120.0))

func add_pen() -> bool:
	if int(state.coins) < new_pen_cost():
		return false
	state.coins -= new_pen_cost()
	state.pens.append({"level": 1, "residents": []})
	add_xp(35)
	return true

func assign(id: int, pen_index: int) -> bool:
	if pen_index < 0 or pen_index >= state.pens.size():
		return false
	if count(id) <= assigned_count(id) or state.pens[pen_index].residents.size() >= pen_capacity(pen_index):
		return false
	state.pens[pen_index].residents.append(id)
	return true

func remove_resident(pen_index: int, slot: int) -> bool:
	if pen_index < 0 or pen_index >= state.pens.size() or slot < 0 or slot >= state.pens[pen_index].residents.size():
		return false
	state.pens[pen_index].residents.remove_at(slot)
	return true

func add_creature(id: int) -> void:
	var previous = count(id)
	state.owned[str(id)] = previous + 1
	state.species_xp[str(id)] = mini(2147483647, int(state.species_xp.get(str(id), 0)) + (1 if previous > 0 else 0))
	for pen in state.pens:
		if pen.residents.size() < 2 + int(pen.level) - 1:
			pen.residents.append(id)
			break

func can_reward_unlock(id: int) -> bool:
	# The species lookup normally clamps IDs; reward eligibility must reject an
	# invalid ID rather than accidentally falling back to a starter creature.
	if id < 0 or id >= catalog.get("creatures", []).size() or count(id) > 0:
		return false
	return int(species(id).rarity) in [0, 1, 2]

func claim_reward_unlock(id: int) -> bool:
	if not can_reward_unlock(id):
		return false
	# An ad discovery grants one resident, not safari captures, XP or coins.
	# Checking ownership again makes duplicate/late callbacks harmless.
	add_creature(id)
	return true

func start_safari(habitat: int, seed_value: int) -> bool:
	if not state.safari.is_empty() or not zone_available(habitat): return false
	state.safari = {"habitat": habitat, "seed": seed_value, "lures": lure_capacity(), "capacity": lure_capacity(), "caught": [], "attempts": 0, "started": clock, "capture": {}, "legacy": false, "skips": 0, "skipped_lures": 0, "encounter_round": 0}
	return true

func zone_available(index: int) -> bool:
	if index < 0 or index >= ZONES.size(): return false
	refresh_zones()
	return _zone_unlocked(index)

func _zone_unlocked(index: int) -> bool:
	for zone in state.unlocked_zones:
		if int(zone) == index: return true
	return false

func refresh_zones() -> void:
	for index in range(ZONES.size()):
		if player_level() >= int(ZONES[index].level) and int(state.stats.outings) >= int(ZONES[index].outings) and not _zone_unlocked(index):
			state.unlocked_zones.append(index)

func lure_capacity() -> int:
	return 4 + int(state.lure_level)

func lure_upgrade_cost() -> int:
	return 180 * (int(state.lure_level) + 1) * (int(state.lure_level) + 1)

func upgrade_lures() -> bool:
	if not state.safari.is_empty() or int(state.lure_level) >= MAX_LURE_LEVEL or int(state.coins) < lure_upgrade_cost(): return false
	state.coins -= lure_upgrade_cost()
	state.lure_level += 1
	return true

func safari_species(slot: int) -> int:
	if state.safari.is_empty() or slot < 0 or slot > 2: return 0
	var active: Dictionary = state.safari.get("capture", {})
	if not active.is_empty() and int(active.slot) == slot: return int(active.id)
	return _encounter_id(int(state.safari.habitat), int(state.safari.seed), slot, int(state.safari.get("encounter_round", state.safari.attempts)))

func safari_skip_cost() -> int:
	if state.safari.is_empty(): return 0
	var current = 1
	var following = 1
	for index in range(int(state.safari.get("skips", 0))):
		var next = current + following
		current = following
		following = next
	return current

func can_skip_safari() -> bool:
	return not state.safari.is_empty() and state.safari.caught.is_empty() and state.safari.capture.is_empty() and int(state.safari.lures) >= safari_skip_cost()

func skip_safari() -> bool:
	if not can_skip_safari(): return false
	var cost = safari_skip_cost()
	state.safari.lures -= cost
	state.safari.skipped_lures = int(state.safari.get("skipped_lures", 0)) + cost
	state.safari.skips = int(state.safari.get("skips", 0)) + 1
	state.safari.encounter_round = int(state.safari.get("encounter_round", state.safari.attempts)) + 1
	return true

func _encounter_id(habitat: int, seed_value: int, slot: int, attempts: int) -> int:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value + slot * 7253 + attempts * 2213
	var roll = rng.randf()
	var cumulative = 0.0
	var rarity = 0
	for tier in range(4):
		cumulative += float(ZONE_WEIGHTS[habitat][tier])
		if roll <= cumulative:
			rarity = tier
			break
	var eligible: Array = ZONE_POOLS[habitat][rarity]
	return int(eligible[rng.randi_range(0, eligible.size() - 1)])

func begin_capture(slot: int) -> bool:
	if state.safari.is_empty() or not state.safari.caught.is_empty() or slot < 0 or slot > 2: return false
	var active: Dictionary = state.safari.capture
	if not active.is_empty(): return int(active.slot) == slot
	if int(state.safari.lures) <= 0: return false
	var id = safari_species(slot)
	state.safari.lures -= 1
	state.safari.attempts += 1
	state.safari.capture = {"id": id, "slot": slot, "stage": 0, "required": 2 + int(species(id).rarity)}
	return true

func capture_window() -> Dictionary:
	if state.safari.is_empty() or state.safari.capture.is_empty(): return {}
	var active: Dictionary = state.safari.capture
	var rarity = int(species(int(active.id)).rarity)
	var rng = RandomNumberGenerator.new()
	rng.seed = int(state.safari.seed) + int(active.id) * 1741 + int(active.stage) * 3359 + int(state.safari.attempts) * 997
	var width = maxf(0.105, 0.32 - rarity * 0.045 - int(active.stage) * 0.018 - (int(active.id) % 4) * 0.006)
	var center = rng.randf_range(0.18, 0.82)
	return {"left": center - width * 0.5, "right": center + width * 0.5, "center": center, "width": width,
		"speed": 1.35 + rarity * 0.4 + int(active.stage) * 0.12 + (int(active.id) % 5) * 0.05,
		"stage": int(active.stage), "required": int(active.required), "id": int(active.id)}

func tap_capture(marker: float) -> String:
	var window = capture_window()
	if window.is_empty(): return "blocked"
	# A miss can NEVER turn into a random capture. UI and model use this same window.
	if not is_finite(marker) or marker < float(window.left) or marker > float(window.right):
		state.safari.capture = {}
		state.safari.encounter_round = int(state.safari.get("encounter_round", state.safari.attempts)) + 1
		return "miss"
	state.safari.capture.stage += 1
	if int(state.safari.capture.stage) < int(state.safari.capture.required): return "stage"
	state.safari.caught.append(int(window.id))
	state.safari.capture = {}
	return "caught"

func finish_safari() -> Dictionary:
	if state.safari.is_empty(): return {}
	# Migrated, legitimately earned v1 catches are preserved; all new outings cap at one.
	var caught: Array = state.safari.caught.duplicate()
	var completed = int(state.safari.attempts) > 0
	var earned_round = not caught.is_empty() or (completed and int(state.safari.lures) == 0)
	var levels: Array = []
	for id in caught:
		var before = species_level(int(id))
		add_creature(int(id))
		if species_level(int(id)) > before and before > 0: levels.append({"id": int(id), "level": species_level(int(id))})
	if completed: state.stats.outings += 1
	state.stats.captures += caught.size()
	state.stats.best_outing = maxi(int(state.stats.best_outing), caught.size())
	var coins = (8 if earned_round else 0) + caught.size() * 12
	state.coins += coins
	var xp = (6 if earned_round else 0) + caught.size() * 28
	add_xp(xp)
	state.safari = {}
	refresh_zones()
	return {"caught": caught, "coins": coins, "xp": xp, "completed": completed, "levels": levels}

func recipe_for(target: int) -> Dictionary:
	for recipe in catalog.recipes:
		if int(recipe.target) == target:
			return recipe
	return {}

func can_breed(recipe: Dictionary) -> bool:
	if recipe.is_empty() or state.nursery.size() >= 2 or int(state.coins) < breeding_cost(recipe): return false
	if not breeding_level_ready(int(recipe.parents[0])) or not breeding_level_ready(int(recipe.parents[1])): return false
	if int(recipe.parents[0]) == int(recipe.parents[1]) and count(int(recipe.parents[0])) < 2: return false
	return true

func breeding_cost(recipe: Dictionary) -> int:
	return int(recipe.cost) * 3

func breeding_seconds(recipe: Dictionary) -> int:
	return int(recipe.seconds) * 12

func begin_breed(target: int) -> bool:
	var recipe = recipe_for(target)
	if not can_breed(recipe):
		return false
	state.coins -= breeding_cost(recipe)
	state.nursery.append({"target": target, "ready_at": clock + breeding_seconds(recipe)})
	return true

func hatch(index: int) -> int:
	if index < 0 or index >= state.nursery.size() or int(state.nursery[index].ready_at) > clock:
		return -1
	var target = int(state.nursery[index].target)
	state.nursery.remove_at(index)
	add_creature(target)
	state.stats.breeds += 1
	add_xp(45 + int(species(target).rarity) * 20)
	return target

func speed_nursery() -> void:
	for egg in state.nursery:
		egg.ready_at = clock

func today() -> int:
	return int(floor(float(clock) / 86400.0))

func daily_available() -> bool:
	return today() > int(state.last_daily)

func next_daily_day() -> int:
	if int(state.last_daily) == today() - 1:
		return int(state.streak) % 7 + 1
	return 1

func daily_reward(day: int) -> Dictionary:
	if day < 1 or day > 7: return {}
	return {"day": day, "coins": 0 if day in DAILY_RARE_DAYS else int(DAILY_COINS[day - 1]), "xp": day * 5 * DAILY_XP_MULTIPLIER, "rare_creature": day in DAILY_RARE_DAYS}

func claim_daily() -> Dictionary:
	if not daily_available(): return {}
	var day = next_daily_day()
	var reward = daily_reward(day)
	var creature = -1
	if reward.rare_creature:
		var candidates: Array[int] = []
		for entry in catalog.creatures:
			# Nursery-exclusive species keep their breeding route; all wild Rare species can visit.
			if int(entry.rarity) == 2 and not entry.breeding_only: candidates.append(int(entry.id))
		if candidates.is_empty(): return {}
		var rng = RandomNumberGenerator.new()
		rng.seed = int(state.get("daily_gift_seed", state.last_seen)) + today() * 997 + int(state.login_days) * 7253
		creature = candidates[rng.randi_range(0, candidates.size() - 1)]
	state.streak = day
	state.last_daily = today()
	state.login_days += 1
	state.coins += int(reward.coins)
	if creature >= 0: add_creature(creature)
	add_xp(int(reward.xp))
	reward["creature"] = creature
	reward["utc_day"] = today()
	state.last_daily_gift = reward.duplicate(true)
	return reward

func refresh_quest() -> void:
	if today() > int(state.quest_day):
		state.quest_day = today()
		state.quest_baseline = int(state.stats.captures)
		state.quest_claimed = false

func quest_progress() -> int:
	return maxi(0, int(state.stats.captures) - int(state.quest_baseline))

func claim_quest() -> bool:
	if state.quest_claimed or quest_progress() < 3:
		return false
	state.quest_claimed = true
	state.coins += QUEST_COINS
	add_xp(QUEST_XP)
	return true

func stat_value(key: String) -> int:
	match key:
		"collection": return collection_size()
		"player_level": return player_level()
		"safari_captures": return int(state.stats.captures)
		"total_income": return int(state.stats.income)
		"breeding_master": return int(state.stats.breeds)
		"outings": return int(state.stats.outings)
		"login_days": return int(state.login_days)
		"rare", "endangered", "extinct":
			var index = {"rare": 2, "endangered": 3, "extinct": 4}[key]
			var number = 0
			for id in state.owned:
				if int(species(int(id)).rarity) == index:
					number += 1
			return number
	return 0

func check_achievements() -> Array:
	var unlocked: Array = []
	for achievement in catalog.achievements:
		if not state.achievements.has(achievement.key) and stat_value(achievement.stat) >= int(achievement.goal):
			state.achievements[achievement.key] = true
			unlocked.append(achievement.key)
	return unlocked

func save_to(path: String) -> Error:
	var payload = JSON.stringify(state, "\t")
	var temporary = path + ".tmp"
	var output = FileAccess.open(temporary, FileAccess.WRITE)
	if output == null:
		return FileAccess.get_open_error()
	output.store_string(payload)
	output.close()
	if FileAccess.file_exists(path):
		var backup_error = DirAccess.copy_absolute(path, path + ".bak")
		if backup_error != OK:
			return backup_error
	return DirAccess.rename_absolute(temporary, path)

func load_from(path: String, now: int) -> bool:
	var incoming: Variant = null
	for candidate in [path, path + ".bak"]:
		if FileAccess.file_exists(candidate):
			var parser = JSON.new()
			incoming = parser.data if parser.parse(FileAccess.get_file_as_string(candidate)) == OK else null
			if valid_save(incoming):
				break
	if not valid_save(incoming):
		return false
	state = incoming.duplicate(true)
	if int(state.version) == 1: _migrate_legacy()
	# Optional additive fields preserve existing v2 saves, balances, claims and active chains.
	if not state.has("daily_gift_seed"): state.daily_gift_seed = int(state.last_seen) % 4294967296
	if not state.has("last_daily_gift"): state.last_daily_gift = {}
	if not state.safari.is_empty():
		if not state.safari.has("skips"): state.safari.skips = 0
		if not state.safari.has("skipped_lures"): state.safari.skipped_lures = 0
		if not state.safari.has("encounter_round"): state.safari.encounter_round = int(state.safari.attempts)
	clock = maxi(now, int(state.last_seen))
	tick(clock)
	return true

func _migrate_legacy() -> void:
	var xp = int(state.xp)
	var rank = 1
	while xp >= 100 + rank * 60:
		xp -= 100 + rank * 60
		rank += 1
	state.version = SAVE_VERSION
	state.keeper_level_base = rank
	# Keep both the exact earned rank and its partial progress under the slower curve.
	state.keeper_xp_base = int(state.xp) - mini(xp, level_cost(rank) - 1)
	state.species_xp = {}
	for key in state.owned: state.species_xp[str(key)] = clampi(int(state.owned[key]) - 1, 0, 2147483647)
	state.lure_level = 0
	state.unlocked_zones = [0]
	if rank >= 3: state.unlocked_zones.append(1)
	if rank >= 6: state.unlocked_zones.append(2)
	if not state.safari.is_empty():
		state.safari.capture = {}
		state.safari.capacity = int(state.safari.lures) + int(state.safari.attempts)
		state.safari.legacy = true

func valid_save(value: Variant) -> bool:
	if not value is Dictionary or not _whole(value.get("version"), 1, SAVE_VERSION): return false
	var legacy = int(value.version) == 1
	for key in ["coins", "xp", "owned", "pens", "bank", "last_seen", "last_daily", "streak", "login_days", "stats", "achievements", "nursery", "safari", "sound", "quest_day", "quest_baseline", "quest_claimed"]:
		if not value.has(key): return false
	if not value.owned is Dictionary or not value.pens is Array or not value.nursery is Array or not value.stats is Dictionary or not value.safari is Dictionary or not value.achievements is Dictionary: return false
	if not _whole(value.coins) or not _whole(value.xp, 0, 2147483647) or not _number(value.bank, 0.0, 250000.0): return false
	if not value.sound is bool or not value.quest_claimed is bool: return false
	if value.has("daily_gift_seed") and not _whole(value.daily_gift_seed, 0, 4294967295): return false
	if value.has("last_daily_gift"):
		var gift: Variant = value.last_daily_gift
		if not gift is Dictionary: return false
		if not gift.is_empty():
			if not _whole(gift.get("day"), 1, 7) or not _whole(gift.get("utc_day"), 0, 2932896): return false
			if not _whole(gift.get("coins")) or not _whole(gift.get("xp")) or not _whole(gift.get("creature"), -1, catalog.creatures.size() - 1): return false
			if not gift.get("rare_creature") is bool: return false
			if int(gift.creature) >= 0 and int(species(int(gift.creature)).rarity) != 2: return false
	if not _whole(value.last_seen, 0, 253402300799) or not _whole(value.last_daily, -1, 2932896) or not _whole(value.quest_day, -1, 2932896): return false
	if not _whole(value.streak, 0, 7) or not _whole(value.login_days) or not _whole(value.quest_baseline): return false
	for key in ["outings", "captures", "breeds", "income", "best_outing"]:
		if not _whole(value.stats.get(key)): return false
	for key in value.achievements:
		if not key is String or not value.achievements[key] is bool: return false
	if value.pens.is_empty() or (legacy and value.pens.size() > 6) or value.nursery.size() > 2: return false
	for id in value.owned:
		if not str(id).is_valid_int() or int(id) < 0 or int(id) >= catalog.creatures.size() or not _whole(value.owned[id], 1): return false
	var assigned: Dictionary = {}
	for pen in value.pens:
		if not pen is Dictionary or not pen.get("residents") is Array or not _whole(pen.get("level"), 1, 5): return false
		if pen.residents.size() > int(pen.level) + 1: return false
		for id in pen.residents:
			if not _whole(id, 0, catalog.creatures.size() - 1): return false
			var key: String = str(int(id))
			assigned[key] = int(assigned.get(key, 0)) + 1
			if int(assigned[key]) > int(value.owned.get(key, 0)): return false
	for egg in value.nursery:
		if not egg is Dictionary or not _whole(egg.get("target"), 0, catalog.creatures.size() - 1) or not _whole(egg.get("ready_at"), 0, 253402300799): return false
		if recipe_for(int(egg.target)).is_empty(): return false
	if not legacy:
		if not value.get("species_xp") is Dictionary or not value.get("unlocked_zones") is Array: return false
		if not _whole(value.get("lure_level"), 0, MAX_LURE_LEVEL) or not _whole(value.get("keeper_level_base"), 1, 1000000) or not _whole(value.get("keeper_xp_base"), 0, int(value.xp)): return false
		for id in value.species_xp:
			if not value.owned.has(str(id)) or not _whole(value.species_xp[id], 0, 2147483647): return false
		for id in value.owned:
			if not value.species_xp.has(str(id)): return false
		var first_zone = false
		for zone in value.unlocked_zones:
			if not _whole(zone, 0, ZONES.size() - 1): return false
			if int(zone) == 0: first_zone = true
		if not first_zone: return false
	if not value.safari.is_empty():
		var outing: Dictionary = value.safari
		if not _whole(outing.get("habitat"), 0, 2 if legacy else ZONES.size() - 1) or not _whole(outing.get("seed")) or not _whole(outing.get("started"), 0, 253402300799): return false
		if legacy:
			if not _whole(outing.get("lures"), 0, 6) or not _whole(outing.get("attempts"), 0, 6): return false
			if not outing.get("caught") is Array or outing.caught.size() > int(outing.attempts) or int(outing.lures) + int(outing.attempts) != 6: return false
		else:
			if not outing.get("capture") is Dictionary or not outing.get("legacy") is bool: return false
			if not _whole(outing.get("capacity"), 1, 12) or not _whole(outing.get("lures"), 0, int(outing.capacity)) or not _whole(outing.get("attempts"), 0, int(outing.capacity)): return false
			var spent_skipping = outing.get("skipped_lures", 0)
			var skip_count = outing.get("skips", 0)
			if not _whole(spent_skipping, 0, int(outing.capacity)) or not _whole(skip_count, 0, int(outing.capacity)): return false
			var expected_spend = 0
			var first = 1
			var second = 1
			for skip in range(int(skip_count)):
				expected_spend += first
				var next = first + second
				first = second
				second = next
			if expected_spend != int(spent_skipping): return false
			if not _whole(outing.get("encounter_round", outing.attempts), 0, int(outing.attempts) + int(skip_count)): return false
			if int(outing.lures) + int(outing.attempts) + int(spent_skipping) != int(outing.capacity): return false
			if not outing.get("caught") is Array or outing.caught.size() > (6 if outing.legacy else 1) or outing.caught.size() > int(outing.attempts): return false
			var active: Dictionary = outing.capture
			if not active.is_empty():
				if not outing.caught.is_empty() or not _whole(active.get("id"), 0, catalog.creatures.size() - 1) or not _whole(active.get("slot"), 0, 2) or not _whole(active.get("required"), 2, 5): return false
				if not _whole(active.get("stage"), 0, int(active.required) - 1) or int(outing.attempts) == 0: return false
				if int(active.required) != 2 + int(species(int(active.id)).rarity) or species(int(active.id)).breeding_only: return false
		for id in outing.caught:
			if not _whole(id, 0, catalog.creatures.size() - 1): return false
	return true

func _whole(value: Variant, minimum: int = 0, maximum: int = 9007199254740991) -> bool:
	return _number(value, float(minimum), float(maximum)) and float(value) == floor(float(value))

func _number(value: Variant, minimum: float, maximum: float) -> bool:
	if not (value is int or value is float): return false
	return is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

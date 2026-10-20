extends RefCounted

const SAVE_VERSION = 1
const DAILY_COINS = [60, 90, 130, 180, 250, 350, 600]
const RARITIES = ["Common", "Uncommon", "Rare", "Endangered", "Extinct"]
var catalog: Dictionary = {}
var state: Dictionary = {}
var clock: int = 0

func _init(data: Dictionary = {}, now: int = 0) -> void:
	catalog = data
	clock = now if now > 0 else int(Time.get_unix_time_from_system())
	state = fresh_state(clock)

func fresh_state(now: int) -> Dictionary:
	return {"version": SAVE_VERSION, "coins": 150, "xp": 0, "owned": {"0": 1, "1": 1},
		"pens": [{"level": 1, "residents": [0, 1]}, {"level": 1, "residents": []}, {"level": 1, "residents": []}],
		"bank": 0.0, "last_seen": now, "last_daily": -1, "streak": 0, "login_days": 0,
		"stats": {"outings": 0, "captures": 0, "breeds": 0, "income": 0, "best_outing": 0},
		"achievements": {}, "nursery": [], "safari": {}, "sound": true,
		"quest_day": -1, "quest_baseline": 0, "quest_claimed": false}

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
	var xp = int(state.xp)
	var level = 1
	while xp >= 100 + level * 60:
		xp -= 100 + level * 60
		level += 1
	return level

func level_progress() -> Vector2:
	var xp = int(state.xp)
	var level = 1
	while xp >= 100 + level * 60:
		xp -= 100 + level * 60
		level += 1
	return Vector2(xp, 100 + level * 60)

func add_xp(amount: int) -> int:
	var before = player_level()
	state.xp += maxi(0, amount)
	var after = player_level()
	for level in range(before + 1, after + 1):
		state.coins += level * 30
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
	for pen in state.pens:
		for id in pen.residents:
			var rarity = int(species(int(id)).rarity)
			total += (0.6 + rarity * 0.6) * (1.0 + (int(pen.level) - 1) * 0.35)
	return total

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
	return 80 * int(state.pens[index].level) * int(state.pens[index].level)

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
	return 150 * (state.pens.size() - 1)

func add_pen() -> bool:
	if state.pens.size() >= 6 or int(state.coins) < new_pen_cost():
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
	state.owned[str(id)] = count(id) + 1
	for pen in state.pens:
		if pen.residents.size() < 2 + int(pen.level) - 1:
			pen.residents.append(id)
			break

func start_safari(habitat: int, seed_value: int) -> bool:
	if not state.safari.is_empty():
		return false
	if habitat < 0 or habitat > 2 or player_level() < [1, 3, 6][habitat]:
		return false
	state.safari = {"habitat": habitat, "seed": seed_value, "lures": 6, "caught": [], "attempts": 0, "started": clock}
	return true

func safari_species(slot: int) -> int:
	if state.safari.is_empty():
		return 0
	var rng = RandomNumberGenerator.new()
	rng.seed = int(state.safari.seed) + slot * 7253 + int(state.safari.attempts) * 2213
	var roll = rng.randf()
	var habitat = int(state.safari.habitat)
	var rarity = 0
	if roll > 0.82 - habitat * 0.07:
		rarity = 1
	if player_level() >= 4 and roll > 0.965 - habitat * 0.025:
		rarity = 2
	if player_level() >= 7 and roll > 0.996 - habitat * 0.005:
		rarity = 3
	var eligible: Array = []
	for creature in catalog.creatures:
		if int(creature.rarity) == rarity and not creature.breeding_only:
			eligible.append(int(creature.id))
	return int(eligible[rng.randi_range(0, eligible.size() - 1)])

func attempt_capture(id: int, quality: float) -> bool:
	if state.safari.is_empty() or int(state.safari.lures) <= 0:
		return false
	state.safari.lures -= 1
	state.safari.attempts += 1
	var rng = RandomNumberGenerator.new()
	rng.seed = int(state.safari.seed) + int(state.safari.attempts) * 997
	var rarity = int(species(id).rarity)
	var chance = clampf(0.52 + clampf(quality, 0.0, 1.0) * 0.45 - rarity * 0.08, 0.2, 0.99)
	var caught = rng.randf() < chance
	if caught:
		state.safari.caught.append(id)
	return caught

func finish_safari() -> Dictionary:
	if state.safari.is_empty():
		return {}
	var caught: Array = state.safari.caught.duplicate()
	var completed = int(state.safari.attempts) > 0
	for id in caught:
		add_creature(int(id))
	if completed:
		state.stats.outings += 1
	state.stats.captures += caught.size()
	state.stats.best_outing = maxi(int(state.stats.best_outing), caught.size())
	var coins = (15 if completed else 0) + caught.size() * 12
	state.coins += coins
	var xp = (20 if completed else 0) + caught.size() * 15
	add_xp(xp)
	state.safari = {}
	return {"caught": caught, "coins": coins, "xp": xp, "completed": completed}

func recipe_for(target: int) -> Dictionary:
	for recipe in catalog.recipes:
		if int(recipe.target) == target:
			return recipe
	return {}

func can_breed(recipe: Dictionary) -> bool:
	if recipe.is_empty() or state.nursery.size() >= 2 or int(state.coins) < int(recipe.cost):
		return false
	if count(int(recipe.parents[0])) < 1 or count(int(recipe.parents[1])) < 1:
		return false
	if int(recipe.parents[0]) == int(recipe.parents[1]) and count(int(recipe.parents[0])) < 2:
		return false
	return true

func begin_breed(target: int) -> bool:
	var recipe = recipe_for(target)
	if not can_breed(recipe):
		return false
	state.coins -= int(recipe.cost)
	state.nursery.append({"target": target, "ready_at": clock + int(recipe.seconds)})
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

func claim_daily() -> int:
	if not daily_available():
		return 0
	var day = next_daily_day()
	state.streak = day
	state.last_daily = today()
	state.login_days += 1
	var amount = int(DAILY_COINS[day - 1])
	state.coins += amount
	add_xp(day * 5)
	return amount

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
	state.coins += 120
	add_xp(35)
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
	state = incoming
	clock = maxi(now, int(state.last_seen))
	tick(clock)
	return true

func valid_save(value: Variant) -> bool:
	if not value is Dictionary or int(value.get("version", 0)) != SAVE_VERSION:
		return false
	for key in fresh_state(clock):
		if not value.has(key):
			return false
	if not value.owned is Dictionary or not value.pens is Array or not value.nursery is Array or not value.stats is Dictionary:
		return false
	if int(value.coins) < 0 or int(value.xp) < 0 or value.pens.size() < 1 or value.pens.size() > 6:
		return false
	for id in value.owned:
		if not str(id).is_valid_int() or int(id) < 0 or int(id) >= catalog.creatures.size() or int(value.owned[id]) < 1:
			return false
	for pen in value.pens:
		if not pen is Dictionary or not pen.get("residents") is Array or int(pen.get("level", 0)) < 1 or int(pen.get("level", 0)) > 5:
			return false
		for id in pen.residents:
			if int(id) < 0 or int(id) >= catalog.creatures.size():
				return false
	return true

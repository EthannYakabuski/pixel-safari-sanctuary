extends SceneTree
## Synthetic model, callback and layout checks; not native-ad evidence.
const Model = preload("res://game/model.gd")
const T = 20000 * 86400
var checks := 0
var failures: Array[String] = []
var data: Dictionary

class IsolatedServices extends Node:
	signal availability_changed
	signal menu_bottom_reserve_changed
	var available := true
	var menu := true
	var safari := false
	var top := 0.0
	var bottom := 0.0
	var request_count := 0
	var context := ""
	var callback: Callable
	var rounds: Array[int] = []
	func can_reward() -> bool: return available
	func set_menu_visible(value: bool) -> void: menu = value
	func set_safari_visible(value: bool) -> void: safari = value
	func menu_bottom_reserve(_reference: CanvasItem = null) -> float: return bottom if menu else 0.0
	func safari_top_reserve(_reference: CanvasItem = null) -> float: return top if safari else 0.0
	func safari_bottom_reserve(_reference: CanvasItem = null) -> float: return 0.0
	func unlock(_key: String) -> void: pass
	func submit(_key: String, _score: int) -> void: pass
	func reward_requested(value: String, answer: Callable) -> void:
		request_count += 1
		context = value
		callback = answer
	func round_finished(count: int = -1) -> void: rounds.append(count)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var isolated := OS.get_environment("DOTS_TEST_ROOT").replace("\\", "/").trim_suffix("/")
	var actual := OS.get_user_data_dir().replace("\\", "/")
	if OS.get_name() == "Android" or isolated.is_empty() or not actual.to_lower().begins_with(isolated.to_lower() + "/"):
		printerr("FAIL: Round Five fixture requires non-Android isolated user data beneath DOTS_TEST_ROOT")
		quit(1)
		return
	data = JSON.parse_string(FileAccess.get_file_as_string("res://game/catalog.json"))
	_test_prices_and_collection()
	_test_native_adapter_contract()
	await _test_interface_and_callbacks()
	print("SAFARI_ROUND_FIVE_TESTS checks=%d failures=%d; synthetic callbacks/layout, no native SDK acceptance" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _fresh() -> RefCounted:
	return Model.new(data, T)

func _test_prices_and_collection() -> void:
	var model = _fresh()
	for level in range(1, 5):
		model.state.pens[0].level = level
		var cost := 25 * 220 * level * level
		check(model.upgrade_cost(0) == cost, "all meadow upgrade levels cost exactly 25 times the earlier price")
		model.state.coins = cost - 1
		check(not model.upgrade_pen(0) and model.state.pens[0].level == level, "insufficient funds cannot buy a higher meadow level")
		model.state.coins = cost
		check(model.upgrade_pen(0) and model.state.coins == 0 and model.state.pens[0].level == level + 1, "purchase deducts the displayed new upgrade cost exactly once")
	model = _fresh()
	for count in [1, 2, 6, 13, 40]:
		while model.state.pens.size() < count: model.state.pens.append({"level": 1, "residents": []})
		var old_price := int(minf(9000000000000.0, 180.0 + pow(float(count), 1.45) * 120.0))
		check(model.new_pen_cost() == 100 * old_price, "new meadow price scales the final earlier integer price by 100")
	var price: int = model.new_pen_cost()
	model.state.coins = price - 1
	check(not model.add_pen() and model.state.pens.size() == 40, "unaffordable expansion does not change saved meadows")
	model.state.coins = price
	check(model.add_pen() and model.state.coins == 0 and model.state.pens.size() == 41, "expansion deducts the new exact price")
	for id in range(data.creatures.size()):
		model = _fresh()
		var eligible: bool = id > 1 and int(data.creatures[id].rarity) <= 2
		check(model.can_reward_unlock(id) == eligible, "rarity/ownership eligibility for species %d" % id)
		var before: Dictionary = model.state.duplicate(true)
		check(model.claim_reward_unlock(id) == eligible, "claimed resident respects rarity/ownership for species %d" % id)
		if eligible:
			check(model.count(id) == 1 and model.state.coins == before.coins and model.state.xp == before.xp and model.state.stats == before.stats, "ad discovery grants one specific resident without coins, XP or safari captures")
			var once: Dictionary = model.state.duplicate(true)
			check(not model.claim_reward_unlock(id) and model.state == once, "duplicate earned callback cannot create another resident")
		else:
			check(model.state == before, "owned/protected species remain unchanged")
	model = _fresh()
	for id in [-1, data.creatures.size(), 99999]:
		check(not model.can_reward_unlock(id) and not model.claim_reward_unlock(id), "invalid species cannot use the clamped lookup to claim a reward")
	model.claim_reward_unlock(2)
	model.state.coins = 123456
	model.state.pens[0].level = 3
	var save_path := "user://round-five-reward-fixture.json"
	check(model.save_to(save_path) == OK, "synthetic rewarded resident can be saved")
	var loaded = _fresh()
	check(loaded.load_from(save_path, T) and loaded.count(2) == 1 and loaded.state.coins == 123456 and loaded.state.pens[0].level == 3, "reload preserves residents, old balances and existing meadow levels")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			check(DirAccess.remove_absolute(save_path + suffix) == OK, "remove only this isolated synthetic fixture file")

func _test_native_adapter_contract() -> void:
	var service: Node = root.get_node("Services")
	for total in range(0, 16):
		check(service.interstitial_due(total) == (total in [5, 10, 15]), "interstitial opportunities occur at fifth completed-outing boundaries only")
	service.set_menu_visible(false)
	service.set_safari_visible(true)
	check(service.banner_position().value == AdPosition.Values.TOP, "active safari selects the vendored native TOP banner position")
	check(service.safari_top_reserve() == 0.0 and service.safari_bottom_reserve() == 0.0, "Web/editor never reserve a pretend native ad")
	check(service._menu_reserve_from_pixels(131, 63, 2.625, 1.8) == 126.0, "measured banner, top safe inset and padding all contribute to Safari reserve")
	check(service._menu_reserve_from_pixels(0, 63, 2.625, 1.8) == 126.0, "unloaded top banner retains conservative 50dp fallback")
	check(service._safari_safe_top_pixels(0, 0, 1731, 2.625) == 63.0, "unknown safe rectangle uses conservative 24dp top allowance")
	service.set_safari_visible(false)
	service.set_menu_visible(true)
	check(service.banner_position().value == AdPosition.Values.BOTTOM, "leaving Safari restores the existing menu bottom banner")
	service.round_finished(4)
	service.round_finished(5)
	service.round_finished(5)
	check(service._round_count == 5, "duplicate completed-outing notification cannot advance ad cadence")
	service.round_finished(10)
	check(service._round_count == 10, "absolute saved outing totals retain cadence after a new session")
	service._round_count = 0
	var readiness_events := [0]
	service.availability_changed.connect(func(): readiness_events[0] += 1)
	service._interstitial_showing = true
	service._interstitial_closed()
	check(not service._interstitial_showing and readiness_events[0] == 1, "interstitial dismissal notifies the visible field guide to refresh reward readiness")

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _test_interface_and_callbacks() -> void:
	root.size = Vector2i(540, 960)
	root.content_scale_size = Vector2i(540, 960)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var original: Node = root.get_node("Services")
	original.name = "SafariRoundFiveOriginalServices"
	var service := IsolatedServices.new()
	service.name = "Services"
	root.add_child(service)
	var game = load("res://main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	await _settle()
	game.set_process(false)
	game.model.state = game.model.fresh_state(int(Time.get_unix_time_from_system()))
	game._navigate("journal")
	await _settle()
	check(game.creature_reward_buttons.size() == 168, "all unowned Common/Uncommon/Rare silhouettes are clickable reward targets")
	for button in game.creature_reward_buttons:
		check(button.custom_minimum_size.x >= 95 and button.custom_minimum_size.y >= 96 and int(game.model.species(int(button.get_meta("creature_id"))).rarity) <= 2, "silhouette has a practical touch target and excludes protected tiers")
	var button: Button = game.body.find_child("RewardCreature2", true, false)
	check(is_instance_valid(button) and not button.disabled, "an eligible silhouette is enabled when a rewarded ad is ready")
	button.pressed.emit()
	check(service.request_count == 1 and service.context == "collection_unlock_2" and game.model.count(2) == 0, "click binds the exact species and never unlocks before its earned callback")
	game._reward_creature(80)
	check(service.request_count == 1 and game.model.count(80) == 0, "only one discovery request can be active")
	var answer: Callable = service.callback
	answer.call(false)
	check(game.model.count(2) == 0, "dismissal/failure leaves the chosen species locked")
	game._reward_creature(2)
	var earned: Callable = service.callback
	var coins: int = game.model.state.coins
	var xp: int = game.model.state.xp
	var captures: int = game.model.state.stats.captures
	earned.call(true)
	earned.call(true)
	earned.call(false)
	await _settle()
	check(game.model.count(2) == 1 and game.model.count(80) == 0 and game.creature_reward_pending == -1, "duplicate or late callbacks unlock exactly the requested species once")
	check(game.model.state.coins == coins and game.model.state.xp == xp and game.model.state.stats.captures == captures, "discovery does not pretend to be a safari payout")
	service.available = false
	service.availability_changed.emit()
	game._reward_creature(80)
	check(service.request_count == 2 and game.model.count(80) == 0, "unavailable ads cannot grant a resident")
	for id in [178, 190]: game._reward_creature(id)
	check(service.request_count == 2, "Endangered and Extinct cannot request discovery ads")
	service.top = 126.0
	game._start_safari(0)
	await _settle()
	check(service.safari and not service.menu and game.ui.offset_top == 142.0, "active Safari reserves the top ad above its header and capture controls")
	game._settings()
	await _settle()
	check(game.modal_panel.offset_top >= 142.0, "Safari modal controls remain below the top banner")
	game._close_modal()
	game._select_creature(0)
	for profile in [Vector2i(540, 960), Vector2i(600, 960), Vector2i(800, 1280)]:
		root.size = profile
		root.content_scale_size = profile
		await _settle()
		var scroll: ScrollContainer = game.body.get_parent()
		scroll.ensure_control_visible(game.capture_button)
		await _settle()
		var header_rect: Rect2 = game.ui.get_child(0).get_global_rect()
		var clip_rect: Rect2 = scroll.get_global_rect()
		var capture_rect: Rect2 = game.capture_button.get_global_rect()
		check(header_rect.position.y >= 142.0 and header_rect.end.y <= clip_rect.position.y, "Safari header is below the reserved ad strip at %s" % profile)
		check(capture_rect.size.y >= 48.0 and capture_rect.position.y >= clip_rect.position.y - 1.0 and capture_rect.end.y <= clip_rect.end.y + 1.0, "capture touch target can scroll fully into the unobstructed gameplay viewport at %s" % profile)
	root.size = Vector2i(540, 960)
	root.content_scale_size = Vector2i(540, 960)
	await _settle()
	game._attempt_capture()
	game.capture_phase = -PI * 0.5
	game._attempt_capture()
	check(service.rounds.is_empty(), "a missed capture does not trigger an interstitial boundary")
	game._finish_safari()
	await _settle()
	check(service.rounds == [1] and not service.safari and service.menu and game.ui.offset_top == 16.0, "completed return notifies one saved outing and restores menu placement")
	game._finish_safari()
	check(service.rounds == [1], "repeated return cannot create a second ad opportunity")
	game._release_audio()
	await create_timer(0.25).timeout
	game.queue_free()
	await _settle()
	service.queue_free()
	await _settle()
	original.name = "Services"

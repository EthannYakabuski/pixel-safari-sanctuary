extends SceneTree

var failures: Array[String] = []
var assertions = 0

class IsolatedServices extends Node:
	signal availability_changed
	var available: bool = false
	var reward_callback: Callable
	func can_reward() -> bool: return available
	func set_menu_visible(_visible: bool) -> void: pass
	func menu_bottom_reserve(_reference: CanvasItem = null) -> float: return 0.0
	func unlock(_key: String) -> void: pass
	func submit(_key: String, _score: int) -> void: pass
	func reward_requested(_context: String, callback: Callable) -> void: reward_callback = callback
	func answer(earned: bool) -> void:
		var callback: Callable = reward_callback
		reward_callback = Callable()
		if callback.is_valid(): callback.call(earned)

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): printerr("UI test timeout"); quit(2))
	_run.call_deferred()

func settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func pointer_button(point: Vector2, pressed: bool) -> void:
	var event = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	root.push_input(event, true)

func drag_at(point: Vector2) -> void:
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	pointer_button(point, true)
	for step in range(1, 9):
		motion = InputEventMouseMotion.new()
		motion.position = point - Vector2(0, step * 18)
		motion.global_position = motion.position
		motion.relative = Vector2(0, -18)
		motion.screen_relative = motion.relative
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		await process_frame
	pointer_button(point - Vector2(0, 144), false)
	await settle()

func _run() -> void:
	root.size = Vector2i(540, 960)
	root.content_scale_size = Vector2i(540, 960)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	Input.emulate_touch_from_mouse = true
	# Keep real pending achievements/scores untouched as well as the game save.
	var original_services: Node = root.get_node_or_null("Services")
	if original_services != null: original_services.name = "PixelUiTestOriginalServices"
	var isolated_services = IsolatedServices.new()
	isolated_services.name = "Services"
	root.add_child(isolated_services)
	var game = load("res://main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.model.state = game.model.fresh_state(int(Time.get_unix_time_from_system()))
	game.model.tick(int(Time.get_unix_time_from_system()))
	game._navigate("home")
	await process_frame
	check(game.body.get_child_count() > 5, "home screen builds full sanctuary UI")
	check(game.bank_label != null, "collect-income display exists")
	game._apply_banner_layout(170.0)
	await settle()
	var home_scroll: ScrollContainer = game.body.get_parent()
	var income_panel: PanelContainer = game.bank_label.get_parent().get_parent().get_parent().get_parent()
	await drag_at(income_panel.get_global_rect().position + Vector2(40, 24))
	check(home_scroll.scroll_vertical > 50 and game.page == "home", "drag on noninteractive card content scrolls the sanctuary")
	home_scroll.scroll_vertical = 0
	await settle()
	var safari_shortcut: Button
	for item in game.body.find_children("*", "Button", true, false):
		if "Go on safari" in item.text: safari_shortcut = item
	check(is_instance_valid(safari_shortcut), "safari shortcut exists")
	if not is_instance_valid(safari_shortcut): quit(1); return
	await drag_at(safari_shortcut.get_global_rect().get_center())
	check(home_scroll.scroll_vertical > 50 and game.page == "home", "drag beginning on a button scrolls without activating it")
	home_scroll.scroll_vertical = 0
	await settle()
	var shortcut_point: Vector2 = safari_shortcut.get_global_rect().get_center()
	pointer_button(shortcut_point, true)
	await process_frame
	pointer_button(shortcut_point, false)
	await settle()
	check(game.page == "safari" and home_scroll.scroll_vertical == 0, "ordinary button tap navigates and resets the inherited scroll offset")
	game._navigate("home")
	game._apply_banner_layout(0.0)
	game._daily()
	await process_frame
	check(is_instance_valid(game.modal), "daily gift modal opens")
	game._close_modal()
	game._navigate("safari")
	await process_frame
	check(game.page == "safari" and game.model.state.safari.is_empty(), "safari habitat menu")
	game._start_safari(0)
	await process_frame
	check(not game.model.state.safari.is_empty() and is_instance_valid(game.wild_view), "safari starts with interactive clearing")
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.wild_view.slot_position(0) * (game.wild_view.size / Vector2(480, 410))
	game.wild_view._gui_input(click)
	check(game.selected_slot == 0 and not game.capture_button.disabled, "touch/mouse selects creature and enables catch")
	for attempt in range(6):
		if game.model.state.safari.is_empty():
			break
		game._select_creature(attempt % 3)
		game.capture_phase = 0.0
		game._attempt_capture()
		await process_frame
	check(game.model.state.safari.is_empty() and game.page == "home", "using all lures returns to sanctuary")
	check(game.model.state.stats.outings == 1, "UI outing banks once")
	check(is_instance_valid(game.modal), "safari return summary displayed")
	game._close_modal()
	game.model.state.coins = 100000
	game._upgrade(0)
	game._manage_pen(0)
	await process_frame
	check(is_instance_valid(game.modal), "enclosure management UI opens")
	game._close_modal()
	game._navigate("nursery")
	await process_frame
	check(game.page == "nursery" and game.body.get_child_count() > 30, "all breeding recipes rendered")
	game._breed(110)
	check(game.model.state.nursery.size() == 1, "UI starts fixed-parent breeding")
	game.model.tick(game.model.clock + 60)
	game._update_nursery_rows()
	await process_frame
	await process_frame
	var held_button: Button = game.nursery_rows[0].hatch
	var pointer: Vector2 = held_button.get_global_rect().get_center()
	var down = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pointer
	down.global_position = pointer
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(down, true)
	await process_frame
	game._process(1.05)
	await process_frame
	check(is_instance_valid(held_button) and held_button.is_inside_tree() and game.nursery_rows[0].hatch == held_button, "nursery tick retains the pressed button instance")
	var up = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pointer
	up.global_position = pointer
	root.push_input(up, true)
	await process_frame
	check(game.model.count(110) == 1 and game.model.state.stats.breeds == 1, "UI hatches exclusive species")
	game._breed(110)
	var ready_at: int = int(game.model.state.nursery[0].ready_at)
	isolated_services.available = true
	game._reward_nursery()
	isolated_services.answer(false)
	check(int(game.model.state.nursery[0].ready_at) == ready_at, "unearned native callback does not change nursery timer")
	game._reward_nursery()
	isolated_services.answer(true)
	check(int(game.model.state.nursery[0].ready_at) == game.model.clock and not game.nursery_rows[0].hatch.disabled, "earned callback makes egg actionable without rebuilding controls")
	check(game.nursery_reward_button.disabled, "already-ready eggs do not offer a worthless rewarded ad")
	isolated_services.available = false
	game._navigate("journal")
	await process_frame
	check(game.page == "journal" and game.body.get_child_count() >= 13, "all five collection tiers rendered")
	game._milestones()
	await process_frame
	check(is_instance_valid(game.modal), "milestone and leaderboard UI opens")
	game._close_modal()
	game._settings()
	await process_frame
	check(is_instance_valid(game.modal), "settings/help/privacy UI opens")
	check(not game._can_reward(), "unavailable rewarded ads cannot grant mock rewards")
	game._close_modal()
	game.queue_free()
	await process_frame
	await process_frame
	root.remove_child(isolated_services)
	isolated_services.free()
	if original_services != null: original_services.name = "Services"
	print("UI_TESTS assertions=", assertions, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

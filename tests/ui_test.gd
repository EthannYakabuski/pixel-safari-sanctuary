extends SceneTree

var failures: Array[String] = []
var assertions = 0

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.model.state = game.model.fresh_state(int(Time.get_unix_time_from_system()))
	game.model.tick(int(Time.get_unix_time_from_system()))
	game._navigate("home")
	await process_frame
	check(game.body.get_child_count() > 5, "home screen builds full sanctuary UI")
	check(game.bank_label != null, "collect-income display exists")
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
	game._hatch(0)
	check(game.model.count(110) == 1 and game.model.state.stats.breeds == 1, "UI hatches exclusive species")
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
	print("UI_TESTS assertions=", assertions, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

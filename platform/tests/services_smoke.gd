extends SceneTree

var responses: Array[bool] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var services := root.get_node("Services")
	assert(not services.can_reward(), "Editor/headless must not grant simulated ad rewards")
	services.reward_requested("smoke", func(granted: bool) -> void: responses.append(granted))
	await process_frame
	await process_frame
	assert(responses == [false], "Unavailable ad must deliver exactly one unsuccessful callback")
	services.set_menu_visible(false)
	services.round_finished()
	services.round_finished()
	assert(not services.can_reward(), "Round completion must not fabricate a rewarded entitlement")
	services.set_menu_visible(true)
	_test_reward_callback_contract(services)
	print("SERVICES_SMOKE_PASS: local fallbacks safe; earned/dismissed/failed reward callbacks settle once")
	quit(0)

func _test_reward_callback_contract(services: Node) -> void:
	# Invoke callback handlers directly; no test object can load or show a native ad.
	responses.clear()
	services.set("_reward_callback", func(granted: bool) -> void: responses.append(granted))
	services.set("_reward_granted", false)
	services.set("_reward_showing", true)
	services.call("_earned_reward", null)
	services.call("_earned_reward", null)
	services.call("_rewarded_closed")
	assert(responses == [true], "An earned reward must settle once, including duplicate callback and dismissal")
	assert(not services.can_reward(), "Dismissal must not leave a rewarded ad reusable")
	responses.clear()
	services.set("_reward_callback", func(granted: bool) -> void: responses.append(granted))
	services.set("_reward_granted", false)
	services.set("_reward_showing", true)
	services.call("_rewarded_closed")
	services.call("_rewarded_closed")
	services.call("_earned_reward", null)
	assert(responses == [false], "Dismissal/show failure must settle false once and ignore a late earned callback")

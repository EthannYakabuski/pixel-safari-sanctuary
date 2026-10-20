extends Control

const Model = preload("res://game/model.gd")
const Habitat = preload("res://game/habitat.gd")
const INK = Color("183f39")
const MUTED = Color("6d8276")
const CREAM = Color("f6f1df")
const GREEN = Color("78a75c")
const GOLD = Color("f3c86a")
const RARITY_COLORS = [Color("81976c"), Color("4e9e83"), Color("6f8cbd"), Color("b082af"), Color("bc8a3d")]
const SAVE_PATH = "user://sanctuary-v1.json"
var model: RefCounted
var page = "home"
var ui: VBoxContainer
var body: VBoxContainer
var coin_label: Label
var level_label: Label
var bank_label: Label
var safari_time_label: Label
var wild_view: Control
var capture_button: Button
var safari_info: Label
var selected_slot = -1
var capture_phase = 0.0
var second_timer = 0.0
var toast_label: Label
var modal: Control
var effects: AudioStreamPlayer
var ambient: AudioStreamPlayer
var capture_mode = ""
var capture_path = ""
var screenshot_mode = false
var test_mode = false
var save_failed = false

func _ready() -> void:
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://game/catalog.json"))
	model = Model.new(catalog)
	for argument in OS.get_cmdline_user_args():
		if argument == "--test-mode":
			test_mode = true
		if argument.begins_with("--capture="):
			capture_mode = argument.trim_prefix("--capture=")
		if argument.begins_with("--capture-path="):
			capture_path = argument.trim_prefix("--capture-path=")
	screenshot_mode = not capture_path.is_empty() or test_mode
	if screenshot_mode:
		_prepare_capture_fixture()
	else:
		model.load_from(SAVE_PATH, int(Time.get_unix_time_from_system()))
		if not model.state.safari.is_empty():
			model.finish_safari()
	model.tick(int(Time.get_unix_time_from_system()))
	theme = Theme.new()
	theme.default_font_size = 17
	effects = AudioStreamPlayer.new()
	add_child(effects)
	ambient = AudioStreamPlayer.new()
	ambient.stream = load("res://assets/audio/ambient.wav")
	if ambient.stream is AudioStreamWAV:
		ambient.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ambient.stream.loop_begin = 0
		ambient.stream.loop_end = int(ambient.stream.get_length() * ambient.stream.mix_rate)
	ambient.volume_db = -8.0
	add_child(ambient)
	if DisplayServer.get_name() != "headless":
		ambient.play()
	_apply_audio()
	_create_shell()
	_render()
	_check_progress()
	if not capture_path.is_empty():
		_capture.call_deferred()
	elif model.daily_available():
		_toast("Welcome home. Your daily gift is ready!")

func _services() -> Node:
	return get_node_or_null("/root/Services")

func _service(method: String, args: Array = []) -> Variant:
	var service = _services()
	if service != null and service.has_method(method):
		return service.callv(method, args)
	return null

func _create_shell() -> void:
	var backdrop = ColorRect.new()
	backdrop.color = CREAM
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	ui = VBoxContainer.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.offset_left = 20
	ui.offset_right = -20
	ui.offset_top = 16
	ui.offset_bottom = -92 if OS.get_name() == "Android" else -18
	ui.add_theme_constant_override("separation", 12)
	add_child(ui)
	var heading = HBoxContainer.new()
	ui.add_child(heading)
	var brand = VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(brand)
	brand.add_child(_label("PIXEL SAFARI", 25, INK))
	brand.add_child(_label("S A N C T U A R Y", 12, MUTED))
	var settings = _button("\u2699", _settings, "soft")
	settings.custom_minimum_size = Vector2(46, 46)
	heading.add_child(settings)
	var stats = HBoxContainer.new()
	stats.add_theme_constant_override("separation", 10)
	ui.add_child(stats)
	coin_label = _label("", 20, INK)
	coin_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_child(coin_label)
	level_label = _label("", 15, MUTED)
	stats.add_child(level_label)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)
	var navigation = HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 7)
	ui.add_child(navigation)
	for item in [["HOME", "home"], ["SAFARI", "safari"], ["NURSERY", "nursery"], ["JOURNAL", "journal"]]:
		var destination = str(item[1])
		var nav = _button(str(item[0]), func(): _navigate(destination), "nav")
		nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.add_theme_font_size_override("font_size", 12)
		navigation.add_child(nav)
	toast_label = _label("", 16, Color.WHITE)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast_label.offset_left = 28
	toast_label.offset_right = -28
	toast_label.offset_top = -142
	toast_label.offset_bottom = -90
	toast_label.add_theme_stylebox_override("normal", _style(INK, 14))
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.visible = false
	add_child(toast_label)

func _label(text_value: String, font_size: int = 17, color_value: Color = INK) -> Label:
	var node = Label.new()
	node.text = text_value
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color_value)
	return node

func _paragraph(text_value: String, font_size: int = 16, color_value: Color = MUTED) -> Label:
	var node = _label(text_value, font_size, color_value)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node

func _style(color_value: Color, radius: int = 16) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color_value
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _button(text_value: String, callback: Callable, kind: String = "primary") -> Button:
	var node = Button.new()
	node.text = text_value
	node.custom_minimum_size.y = 48
	node.add_theme_font_size_override("font_size", 16)
	var bg = INK if kind == "primary" else Color("e5ead9")
	if kind == "gold":
		bg = GOLD
	if kind == "nav":
		bg = Color("e5ead9")
	node.add_theme_stylebox_override("normal", _style(bg, 13))
	node.add_theme_stylebox_override("hover", _style(bg.lightened(0.08), 13))
	node.add_theme_stylebox_override("pressed", _style(bg.darkened(0.08), 13))
	node.add_theme_stylebox_override("disabled", _style(Color("e7e6db"), 13))
	node.add_theme_stylebox_override("focus", _focus_style())
	node.add_theme_color_override("font_color", Color.WHITE if kind == "primary" else INK)
	node.add_theme_color_override("font_hover_color", Color.WHITE if kind == "primary" else INK)
	node.add_theme_color_override("font_pressed_color", Color.WHITE if kind == "primary" else INK)
	node.add_theme_color_override("font_disabled_color", Color("8b9689"))
	node.pressed.connect(func(): _sound("click"); callback.call())
	return node

func _focus_style() -> StyleBoxFlat:
	var style = _style(Color.TRANSPARENT, 13)
	style.set_border_width_all(3)
	style.border_color = GOLD
	return style

func _card(parent: Node = null) -> VBoxContainer:
	if parent == null:
		parent = body
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(Color("fffdf3"), 18))
	parent.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)
	return box

func _section(title: String, subtitle: String = "") -> void:
	body.add_child(_label(title, 24))
	if not subtitle.is_empty():
		body.add_child(_paragraph(subtitle))

func _sprite(id: int, pixels: int = 72) -> TextureRect:
	var frame = AtlasTexture.new()
	frame.atlas = load(str(model.species(id).file))
	frame.region = Rect2(0, 0, 192, 192)
	var node = TextureRect.new()
	node.texture = frame
	node.custom_minimum_size = Vector2(pixels, pixels)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return node

func _refresh_header() -> void:
	coin_label.text = "\u25cf  %s coins" % _number(int(model.state.coins))
	var progress = model.level_progress()
	level_label.text = "KEEPER %d  \u00b7  %d/%d XP" % [model.player_level(), int(progress.x), int(progress.y)]

func _render() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	wild_view = null
	bank_label = null
	safari_time_label = null
	_refresh_header()
	_service("set_menu_visible", [model.state.safari.is_empty()])
	match page:
		"home": _home()
		"safari": _safari()
		"nursery": _nursery()
		"journal": _journal()
	_save()

func _navigate(destination: String) -> void:
	if not model.state.safari.is_empty() and destination != "safari":
		_finish_safari()
	page = destination
	selected_slot = -1
	_render()

func _home() -> void:
	_section("A little wild. A lot of wonder.", "A safe home for every creature you discover.")
	var view = Habitat.new()
	view.model = model
	view.custom_minimum_size.y = 275
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(view)
	var income_card = _card()
	var income_row = HBoxContainer.new()
	income_card.add_child(income_row)
	var income_text = VBoxContainer.new()
	income_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	income_row.add_child(income_text)
	income_text.add_child(_label("VISITOR FUND", 12, MUTED))
	bank_label = _label("", 24)
	income_text.add_child(bank_label)
	income_row.add_child(_button("Collect", _collect, "gold"))
	income_card.add_child(_paragraph("%s coins/min  \u00b7  Your residents earn while you are away." % _number(int(model.income_per_second() * 60)), 13))
	var gift_row = HBoxContainer.new()
	gift_row.add_theme_constant_override("separation", 8)
	body.add_child(gift_row)
	var daily = _button("Daily gift" + ("  \u2022" if model.daily_available() else "  \u2713"), _daily, "soft")
	daily.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gift_row.add_child(daily)
	var safari = _button("Go on safari  \u2192", func(): _navigate("safari"))
	safari.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gift_row.add_child(safari)
	body.add_child(_label("YOUR ENCLOSURES", 13, MUTED))
	var pens = GridContainer.new()
	pens.columns = 2
	pens.add_theme_constant_override("h_separation", 10)
	pens.add_theme_constant_override("v_separation", 10)
	body.add_child(pens)
	for index in range(model.state.pens.size()):
		var pen = model.state.pens[index]
		var box = _card(pens)
		box.add_child(_label("Meadow %d  \u00b7  Lv %d" % [index + 1, int(pen.level)], 16))
		var residents = HBoxContainer.new()
		box.add_child(residents)
		for resident in pen.residents.slice(0, 3):
			residents.add_child(_sprite(int(resident), 46))
		if pen.residents.is_empty():
			residents.add_child(_label("Room for new friends", 12, MUTED))
		box.add_child(_label("%d/%d residents" % [pen.residents.size(), model.pen_capacity(index)], 13, MUTED))
		var this_pen = index
		box.add_child(_button("Manage", func(): _manage_pen(this_pen), "soft"))
		var upgrade = _button("Upgrade %d" % model.upgrade_cost(index) if int(pen.level) < 5 else "Fully upgraded", func(): _upgrade(this_pen), "soft")
		upgrade.disabled = int(pen.level) >= 5 or int(model.state.coins) < model.upgrade_cost(index)
		upgrade.add_theme_font_size_override("font_size", 13)
		box.add_child(upgrade)
	if model.state.pens.size() < 6:
		var expansion = _button("Open another meadow  \u00b7  %d coins" % model.new_pen_cost(), _expand, "soft")
		expansion.disabled = int(model.state.coins) < model.new_pen_cost()
		body.add_child(expansion)
	_update_ticking_labels()

func _collect() -> void:
	var coins = model.collect_income()
	if coins > 0:
		_sound("capture")
		_toast("Collected %s coins. Thank you, visitors!" % _number(coins))
	else:
		_toast("Your visitors are on their way. Come back in a moment.")
	_check_progress()
	_render()

func _upgrade(index: int) -> void:
	if model.upgrade_pen(index):
		_toast("A comfier home, more room, happier visitors.")
	_check_progress()
	_render()

func _expand() -> void:
	if model.add_pen():
		_toast("A new meadow is ready for residents.")
	_check_progress()
	_render()

func _manage_pen(index: int) -> void:
	var box = _open_modal("Meadow %d" % (index + 1))
	box.add_child(_paragraph("Residents bring in visitor coins. Move them freely; creatures always stay in your collection."))
	var residents = model.state.pens[index].residents
	for slot in range(residents.size()):
		var id = int(residents[slot])
		var item = HBoxContainer.new()
		box.add_child(item)
		item.add_child(_sprite(id, 48))
		var name_label = _label(str(model.species(id).name), 14)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_child(name_label)
		var this_slot = slot
		item.add_child(_button("Rest", func(): model.remove_resident(index, this_slot); _close_modal(); _render(); _manage_pen(index), "soft"))
	if residents.size() < model.pen_capacity(index):
		box.add_child(_label("ADD A RESIDENT", 13, MUTED))
		for key in model.state.owned:
			var id = int(key)
			if model.count(id) > model.assigned_count(id):
				var this_id = id
				box.add_child(_button(str(model.species(id).name) + "  +", func(): model.assign(this_id, index); _close_modal(); _render(); _manage_pen(index), "soft"))
	box.add_child(_button("Done", _close_modal))

func _daily() -> void:
	var box = _open_modal("A week of little wonders")
	box.add_child(_paragraph("Visit each UTC day for a bigger gift. After day 7 the track begins again; a missed day starts a fresh week."))
	var next = model.next_daily_day()
	for day in range(1, 8):
		var row = HBoxContainer.new()
		box.add_child(row)
		var day_label = _label("DAY %d" % day, 15, INK if day == next else MUTED)
		day_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(day_label)
		row.add_child(_label("%d coins" % Model.DAILY_COINS[day - 1], 17))
	var claim = _button("Claim day %d gift" % next if model.daily_available() else "Gift collected today", func():
		var amount = model.claim_daily()
		_close_modal()
		_toast("A gift of %d coins. Glad you are here!" % amount)
		_check_progress()
		_render(), "gold")
	claim.disabled = not model.daily_available()
	box.add_child(claim)
	box.add_child(_button("Back", _close_modal, "soft"))

func _safari() -> void:
	if model.state.safari.is_empty():
		_section("Follow your curiosity.", "Six lures. Forty-five seconds. A whole lot of new friends.")
		var habitats = [["Sunlit Meadow", "Gentle paths, familiar faces, and a little luck.", 1], ["Fernwood Trail", "A deeper forest with more uncommon encounters.", 3], ["Amber Highlands", "Rare company beyond the sunset ridge.", 6]]
		for index in range(3):
			var habitat = habitats[index]
			var box = _card()
			var art = HBoxContainer.new()
			box.add_child(art)
			art.add_child(_sprite([0, 88, 156][index], 88))
			var title = VBoxContainer.new()
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			art.add_child(title)
			title.add_child(_label(str(habitat[0]), 20))
			title.add_child(_paragraph(str(habitat[1]), 14))
			var which = index
			var depart = _button("Explore  \u2192" if model.player_level() >= int(habitat[2]) else "Opens at keeper level %d" % int(habitat[2]), func(): _start_safari(which))
			depart.disabled = model.player_level() < int(habitat[2])
			box.add_child(depart)
		var quest = _card()
		quest.add_child(_label("TODAY'S FIELD NOTE", 12, MUTED))
		quest.add_child(_paragraph("Bring home 3 creatures today. 120 coins + 35 XP.", 16, INK))
		quest.add_child(_label("%d / 3 friends brought home" % mini(3, model.quest_progress()), 15, MUTED))
		var claim = _button("Claim field-note reward" if not model.state.quest_claimed else "Field note complete", func():
			if model.claim_quest():
				_toast("Field note complete! +120 coins +35 XP")
			_check_progress()
			_render(), "gold")
		claim.disabled = model.state.quest_claimed or model.quest_progress() < 3
		quest.add_child(claim)
		return
	_section("A little closer...", "Tap a creature, then catch when the white marker meets gold.")
	var top = HBoxContainer.new()
	body.add_child(top)
	safari_time_label = _label("", 20)
	safari_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(safari_time_label)
	top.add_child(_label("%d LURES LEFT" % int(model.state.safari.lures), 14, MUTED))
	wild_view = Habitat.new()
	wild_view.model = model
	wild_view.mode = "safari"
	wild_view.selected = selected_slot
	wild_view.custom_minimum_size.y = 410
	wild_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wild_view.creature_selected.connect(_select_creature)
	body.add_child(wild_view)
	safari_info = _paragraph("Choose any creature in the clearing.", 17, INK)
	body.add_child(safari_info)
	capture_button = _button("Choose a creature", _attempt_capture, "gold")
	capture_button.disabled = selected_slot < 0
	body.add_child(capture_button)
	var caught_names: Array = []
	for id in model.state.safari.caught:
		caught_names.append(str(model.species(int(id)).name))
	body.add_child(_paragraph("This outing: %d new friends" % caught_names.size(), 15))
	body.add_child(_button("Return to sanctuary", _finish_safari, "soft"))
	_update_ticking_labels()
	if selected_slot >= 0:
		_select_creature(selected_slot)

func _start_safari(habitat: int) -> void:
	if model.start_safari(habitat, int(Time.get_ticks_msec())):
		selected_slot = -1
		page = "safari"
		_render()

func _select_creature(slot: int) -> void:
	selected_slot = slot
	capture_phase = 0.7
	wild_view.selected = slot
	var creature = model.species(model.safari_species(slot))
	safari_info.text = "%s  \u00b7  %s" % [creature.name, Model.RARITIES[int(creature.rarity)]]
	capture_button.text = "Catch!  \u2193"
	capture_button.disabled = false

func _attempt_capture() -> void:
	if selected_slot < 0 or model.state.safari.is_empty():
		return
	var id = model.safari_species(selected_slot)
	var quality = 1.0 - absf(sin(capture_phase))
	var caught = model.attempt_capture(id, quality)
	_sound("capture" if caught else "escape")
	_toast("%s joined your safari!" % model.species(id).name if caught else "%s slipped away. Try another friend." % model.species(id).name)
	selected_slot = -1
	if int(model.state.safari.lures) <= 0:
		_finish_safari()
	else:
		_render()

func _finish_safari() -> void:
	var result = model.finish_safari()
	if result.is_empty():
		return
	selected_slot = -1
	page = "home"
	_check_progress()
	_render()
	if result.get("completed", true):
		_service("round_finished")
	var box = _open_modal("Welcome home, explorer.")
	box.add_child(_paragraph("%d creatures safely brought back. +%d coins and +%d XP." % [result.caught.size(), int(result.coins), int(result.xp)], 18, INK))
	var row = HFlowContainer.new()
	box.add_child(row)
	for id in result.caught:
		row.add_child(_sprite(int(id), 78))
	if result.caught.is_empty():
		box.add_child(_paragraph("Every outing teaches you something. There is always another trail."))
	box.add_child(_button("Meet the residents", _close_modal))

func _nursery() -> void:
	_section("Grow the family tree.", "Some wonders can only be born here. Parents stay in your sanctuary.")
	for index in range(model.state.nursery.size()):
		var egg = model.state.nursery[index]
		var card = _card()
		var row = HBoxContainer.new()
		card.add_child(row)
		row.add_child(_sprite(int(egg.target), 80))
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(_label(str(model.species(int(egg.target)).name), 18))
		var remaining = maxi(0, int(egg.ready_at) - model.clock)
		info.add_child(_label("Ready to hatch!" if remaining == 0 else "Hatches in %d seconds" % remaining, 14, MUTED))
		var slot = index
		var hatch = _button("Hatch egg", func(): _hatch(slot), "gold")
		hatch.disabled = remaining > 0
		card.add_child(hatch)
	if model.state.nursery.is_empty():
		var empty = _card()
		empty.add_child(_label("The nursery is quiet.", 20))
		empty.add_child(_paragraph("Discover the parents below to start a new generation. There is room for two eggs."))
	else:
		var reward = _button("Watch an ad: hatch all eggs now", _reward_nursery, "soft")
		reward.disabled = not _can_reward()
		body.add_child(reward)
		if not _can_reward():
			body.add_child(_paragraph("Rewarded video is unavailable. Eggs hatch naturally while you play or rest.", 13))
	body.add_child(_label("BREEDING TREE  \u00b7  %d RECIPES" % model.catalog.recipes.size(), 13, MUTED))
	var recipes: Array = model.catalog.recipes.duplicate()
	recipes.sort_custom(func(a: Dictionary, b: Dictionary): return int(model.can_breed(a)) > int(model.can_breed(b)))
	for recipe in recipes:
		var card = _card()
		var target = int(recipe.target)
		var target_data = model.species(target)
		var title = HBoxContainer.new()
		card.add_child(title)
		title.add_child(_sprite(target, 66))
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_child(info)
		info.add_child(_label(str(target_data.name), 18))
		info.add_child(_label("%s \u00b7 Nursery exclusive" % Model.RARITIES[int(target_data.rarity)], 12, RARITY_COLORS[int(target_data.rarity)]))
		var parents = HBoxContainer.new()
		card.add_child(parents)
		for parent in recipe.parents:
			var parent_id = int(parent)
			var parent_box = VBoxContainer.new()
			parent_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			parents.add_child(parent_box)
			parent_box.add_child(_label(("\u2713 " if model.count(parent_id) > 0 else "\u25cb ") + str(model.species(parent_id).name), 13, INK if model.count(parent_id) > 0 else MUTED))
		var this_target = target
		var breed = _button("Breed  \u00b7  %d coins  \u00b7  %ds" % [int(recipe.cost), int(recipe.seconds)], func(): _breed(this_target), "soft")
		breed.disabled = not model.can_breed(recipe)
		card.add_child(breed)

func _breed(target: int) -> void:
	if model.begin_breed(target):
		_toast("A new beginning! Your egg is safe in the nursery.")
	_render()

func _hatch(index: int) -> void:
	var id = model.hatch(index)
	if id >= 0:
		_sound("capture")
		_toast("Welcome, %s!" % model.species(id).name)
	_check_progress()
	_render()

func _can_reward() -> bool:
	var service = _services()
	return service != null and service.has_method("can_reward") and bool(service.call("can_reward"))

func _reward_nursery() -> void:
	if not _can_reward() or model.state.nursery.is_empty():
		return
	_service("reward_requested", ["nursery_hatch", func(granted: bool):
		if granted:
			model.speed_nursery()
			_toast("Reward earned. Your eggs are ready!")
		else:
			_toast("No reward earned. Your eggs keep growing normally.")
		_render()])

func _journal() -> void:
	_section("Your living field guide.", "%d of 200 species discovered. Every little wonder counts." % model.collection_size())
	var summary = _card()
	summary.add_child(_label("THE STORY SO FAR", 12, MUTED))
	summary.add_child(_paragraph("%d outings  \u00b7  %d safari friends  \u00b7  %d eggs hatched" % [int(model.state.stats.outings), int(model.state.stats.captures), int(model.state.stats.breeds)], 16, INK))
	summary.add_child(_button("Milestones & leaderboards", _milestones, "soft"))
	for rarity in range(5):
		var discovered = 0
		var total = 0
		for creature in model.catalog.creatures:
			if int(creature.rarity) == rarity:
				total += 1
				if model.count(int(creature.id)) > 0:
					discovered += 1
		body.add_child(_label("%s   %d / %d" % [Model.RARITIES[rarity].to_upper(), discovered, total], 14, RARITY_COLORS[rarity]))
		var grid = GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 8)
		body.add_child(grid)
		for creature in model.catalog.creatures:
			if int(creature.rarity) != rarity:
				continue
			var cell = VBoxContainer.new()
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(cell)
			var portrait = _sprite(int(creature.id), 72)
			portrait.modulate = Color.WHITE if model.count(int(creature.id)) > 0 else Color(0.17, 0.27, 0.22, 0.22)
			cell.add_child(portrait)
			var name_label = _paragraph(str(creature.name) if model.count(int(creature.id)) > 0 else ("Nursery" if creature.breeding_only else "Undiscovered"), 10, MUTED)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.custom_minimum_size = Vector2(95, 32)
			cell.add_child(name_label)

func _milestones() -> void:
	var box = _open_modal("Keeper milestones")
	box.add_child(_paragraph("Milestones work offline. Connect Play Games on Android to sync achievements and scores."))
	box.add_child(_button("Connect Play Games", func(): _service("sign_in"); _toast(_service_status()), "soft"))
	box.add_child(_button("Play Games achievements", func(): _service("open_achievements"), "soft"))
	for board in model.catalog.leaderboards:
		var key = str(board.key)
		box.add_child(_button("%s  \u00b7  %s" % [board.name, _number(model.stat_value(key))], func(): _service("open_leaderboards", [key]), "soft"))
	for achievement in model.catalog.achievements:
		var earned = model.state.achievements.has(achievement.key)
		box.add_child(_label(("\u2713 " if earned else "\u25cb ") + str(achievement.name), 16, INK if earned else MUTED))
		box.add_child(_paragraph("%s  %d/%d" % [achievement.description, mini(int(achievement.goal), model.stat_value(achievement.stat)), int(achievement.goal)], 13))
	box.add_child(_button("Back", _close_modal))

func _service_status() -> String:
	var result = _service("status")
	return str(result) if result != null else "Offline play is ready. Play Games connects on Android."

func _settings() -> void:
	var box = _open_modal("Make yourself at home")
	box.add_child(_paragraph("PIXEL SAFARI SANCTUARY\nA cozy home for little wild things.\n\nTap creatures in a safari, then catch when the marker passes gold. Resident creatures earn visitor coins. The nursery reveals new species through special parent pairs."))
	box.add_child(_button("Sound: " + ("On" if model.state.sound else "Off"), func():
		model.state.sound = not model.state.sound
		_apply_audio()
		_save()
		_close_modal()
		_settings(), "soft"))
	box.add_child(_button("Privacy options", func(): _service("privacy_options"), "soft"))
	box.add_child(_paragraph("Progress is stored on this device. Offline visitor income accrues for up to eight hours. Login gifts use UTC days.\n\nCreature artwork: Kenney. Original game code and audio: Apache-2.0. See distributed notices for native plugins and other components.", 13))
	box.add_child(_paragraph(_service_status(), 13))
	if save_failed:
		box.add_child(_paragraph("Progress could not be saved. Please check device storage before closing the game.", 14, Color("a64e42")))
	box.add_child(_button("Back to the sanctuary", _close_modal))

func _open_modal(title: String) -> VBoxContainer:
	_close_modal()
	modal = ColorRect.new()
	modal.color = Color(0.05, 0.16, 0.12, 0.60)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 28
	panel.offset_right = -28
	panel.offset_top = 70
	panel.offset_bottom = -70
	panel.add_theme_stylebox_override("panel", _style(CREAM, 24))
	modal.add_child(panel)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)
	box.add_child(_label(title, 23))
	return box

func _close_modal() -> void:
	if is_instance_valid(modal):
		modal.queue_free()
	modal = null

func _check_progress() -> void:
	var newly_unlocked = model.check_achievements()
	for key in newly_unlocked:
		_service("unlock", [str(key)])
	for board in model.catalog.leaderboards:
		_service("submit", [str(board.key), model.stat_value(str(board.key))])
	_save()

func _save() -> void:
	if screenshot_mode:
		return
	var error = model.save_to(SAVE_PATH)
	save_failed = error != OK
	if save_failed:
		push_error("Progress save failed: %s" % error_string(error))

func _process(delta: float) -> void:
	if model == null:
		return
	second_timer += delta
	if not model.state.safari.is_empty():
		capture_phase += delta * 2.4
		if is_instance_valid(wild_view):
			wild_view.phase = capture_phase
	if second_timer >= 1.0:
		second_timer = 0.0
		model.tick(int(Time.get_unix_time_from_system()))
		_update_ticking_labels()
		if not model.state.safari.is_empty() and model.clock - int(model.state.safari.started) >= 45:
			_finish_safari()
		elif page == "nursery" and not is_instance_valid(modal):
			# Rebuild only while eggs exist, so readiness becomes actionable without navigating away.
			if not model.state.nursery.is_empty():
				_render()
		_save()

func _update_ticking_labels() -> void:
	if is_instance_valid(bank_label):
		bank_label.text = "%s coins" % _number(int(model.state.bank))
	if is_instance_valid(safari_time_label) and not model.state.safari.is_empty():
		safari_time_label.text = "%02d seconds" % maxi(0, 45 - (model.clock - int(model.state.safari.started)))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if model != null:
			_save()
	if what == NOTIFICATION_APPLICATION_RESUMED and model != null:
		model.tick(int(Time.get_unix_time_from_system()))
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(modal):
			_close_modal()
		elif page != "home":
			_navigate("home")

func _sound(name_value: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if effects != null and model.state.sound:
		effects.stream = load("res://assets/audio/%s.wav" % name_value)
		effects.play()
	if ambient != null and model.state.sound and not ambient.playing:
		ambient.play()

func _apply_audio() -> void:
	if ambient != null:
		ambient.stream_paused = not model.state.sound

func _exit_tree() -> void:
	if is_instance_valid(effects):
		effects.stop()
		effects.stream = null
	if is_instance_valid(ambient):
		ambient.stop()
		ambient.stream = null

func _toast(message: String) -> void:
	if toast_label == null:
		return
	toast_label.text = message
	toast_label.visible = true
	var current = message
	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(toast_label) and toast_label.text == current:
			toast_label.visible = false)

func _number(value: int) -> String:
	if value >= 1000000:
		return "%.1fm" % (float(value) / 1000000.0)
	if value >= 10000:
		return "%.1fk" % (float(value) / 1000.0)
	return str(value)

func _prepare_capture_fixture() -> void:
	model.state.coins = 2410
	model.add_xp(1040)
	for id in [6, 15, 27, 42, 83, 88, 99, 110, 112, 135, 137, 151]:
		model.add_creature(id)
	model.state.pens[0].level = 3
	model.state.pens[1].level = 2
	model.state.pens[2].level = 2
	model.state.bank = 326.0
	model.state.stats = {"outings": 12, "captures": 41, "breeds": 3, "income": 1860, "best_outing": 6}
	model.state.streak = 3
	model.state.last_daily = model.today() - 1
	model.state.nursery = [{"target": 170, "ready_at": model.clock + 37}]
	page = capture_mode if capture_mode in ["home", "safari", "nursery", "journal"] else "home"
	if page == "safari":
		model.start_safari(1, 4179)
		selected_slot = 1

func _capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	var image = get_viewport().get_texture().get_image()
	var error = image.save_png(capture_path)
	print("SCREENSHOT ", capture_path, " result=", error)
	get_tree().quit(0 if error == OK else 1)

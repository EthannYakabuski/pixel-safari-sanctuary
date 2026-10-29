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
var safari_lure_label: Label
var wild_view: Control
var capture_button: Button
var safari_skip_button: Button
var safari_info: Label
var selected_slot = -1
var meadow_page = 0
var capture_phase = 0.0
var second_timer = 0.0
var toast_label: Label
var modal: Control
var modal_panel: PanelContainer
var effects: AudioStreamPlayer
var ambient: AudioStreamPlayer
var capture_mode = ""
var capture_path = ""
var screenshot_mode = false
var test_mode = false
var save_failed = false
var nursery_rows: Array = []
var nursery_reward_button: Button
var nursery_reward_status: Label
var creature_reward_buttons: Array[Button] = []
var creature_reward_pending = -1
var creature_reward_serial = 0

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
	if is_instance_valid(_services()) and _services().has_signal("menu_bottom_reserve_changed"):
		_services().connect("menu_bottom_reserve_changed", _apply_banner_layout)
	if is_instance_valid(_services()) and _services().has_signal("availability_changed"):
		_services().connect("availability_changed", _on_service_availability_changed)
	get_viewport().size_changed.connect(_apply_banner_layout)
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
	_apply_banner_layout()

func _apply_banner_layout(reserve_override: float = -1.0, top_reserve_override: float = -1.0) -> void:
	if not is_instance_valid(ui): return
	var reserve := reserve_override
	var service := _services()
	if reserve < 0.0:
		reserve = float(service.call("menu_bottom_reserve", self)) if is_instance_valid(service) and service.has_method("menu_bottom_reserve") else 0.0
		if is_instance_valid(service) and service.has_method("safari_bottom_reserve"):
			reserve = maxf(reserve, float(service.call("safari_bottom_reserve", self)))
	var top_reserve := top_reserve_override
	if top_reserve < 0.0:
		top_reserve = float(service.call("safari_top_reserve", self)) if is_instance_valid(service) and service.has_method("safari_top_reserve") else 0.0
	ui.offset_top = 16.0 + maxf(0.0, top_reserve)
	var baseline := 92.0 if OS.get_name() == "Android" else 18.0
	var inset := maxf(baseline, 18.0 + maxf(0.0, reserve))
	ui.offset_bottom = -inset
	if is_instance_valid(toast_label):
		toast_label.offset_top = -(inset + 124.0)
		toast_label.offset_bottom = -(inset + 72.0)
	if is_instance_valid(modal_panel):
		modal_panel.offset_top = maxf(70.0, 16.0 + maxf(0.0, top_reserve))
		modal_panel.offset_bottom = -maxf(70.0, 18.0 + maxf(0.0, reserve))


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
	node.mouse_filter = Control.MOUSE_FILTER_PASS
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
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
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
	var focused := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and body.is_ancestor_of(focused): focused.release_focus()
	for child in body.get_children():
		# Keep pressed controls in the tree until deferred deletion completes.
		# Removing a still-live control during its input signal lets Godot's
		# pending input/focus dispatch call can_process() outside the tree.
		if child is CanvasItem: child.hide()
		child.queue_free()
	wild_view = null
	bank_label = null
	safari_time_label = null
	safari_lure_label = null
	nursery_rows = []
	nursery_reward_button = null
	nursery_reward_status = null
	creature_reward_buttons = []
	_refresh_header()
	_service("set_menu_visible", [model.state.safari.is_empty()])
	_service("set_safari_visible", [not model.state.safari.is_empty()])
	_apply_banner_layout()
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
	_reset_page_scroll()

func _reset_page_scroll() -> void:
	var scroll: ScrollContainer = body.get_parent()
	scroll.scroll_vertical = 0
	scroll.set_deferred("scroll_vertical", 0)

func _home() -> void:
	_section("A little wild. A lot of wonder.", "Build bonds, discover faraway habitats, and make room for every friend.")
	meadow_page = clampi(meadow_page, 0, maxi(0, int((model.state.pens.size() - 1) / 6)))
	var view = Habitat.new()
	view.model = model
	view.pen_offset = meadow_page * 6
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
	income_card.add_child(_paragraph("%.1f coins/min  ·  Residents earn while you are away, up to eight hours." % (model.income_per_second() * 60.0), 13))
	var gift_row = HBoxContainer.new()
	gift_row.add_theme_constant_override("separation", 8)
	body.add_child(gift_row)
	var daily = _button("Daily gift" + ("  •" if model.daily_available() else "  ✓"), _daily, "soft")
	daily.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gift_row.add_child(daily)
	var safari = _button("Go on safari  →", func(): _navigate("safari"))
	safari.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gift_row.add_child(safari)
	body.add_child(_label("YOUR MEADOWS  ·  %d HOME%s" % [model.state.pens.size(), "" if model.state.pens.size() == 1 else "S"], 13, MUTED))
	var page_row = HBoxContainer.new()
	body.add_child(page_row)
	var previous = _button("← Previous", func(): meadow_page -= 1; _render(), "soft")
	previous.disabled = meadow_page == 0
	page_row.add_child(previous)
	var page_label = _label("%d–%d / %d" % [meadow_page * 6 + 1, mini((meadow_page + 1) * 6, model.state.pens.size()), model.state.pens.size()], 13, MUTED)
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_row.add_child(page_label)
	var following = _button("Next →", func(): meadow_page += 1; _render(), "soft")
	following.disabled = (meadow_page + 1) * 6 >= model.state.pens.size()
	page_row.add_child(following)
	var pens = GridContainer.new()
	pens.columns = 2
	pens.add_theme_constant_override("h_separation", 10)
	pens.add_theme_constant_override("v_separation", 10)
	body.add_child(pens)
	for index in range(meadow_page * 6, mini((meadow_page + 1) * 6, model.state.pens.size())):
		var pen = model.state.pens[index]
		var earning = model.meadow_income(index)
		var box = _card(pens)
		box.add_child(_label("Meadow %d  ·  Lv %d" % [index + 1, int(pen.level)], 16))
		var residents = HBoxContainer.new()
		box.add_child(residents)
		for resident in pen.residents.slice(0, 3): residents.add_child(_sprite(int(resident), 46))
		if pen.residents.is_empty(): residents.add_child(_label("Room for new friends", 12, MUTED))
		box.add_child(_label("%d/%d residents" % [pen.residents.size(), model.pen_capacity(index)], 13, MUTED))
		box.add_child(_label("%.1f coins / min" % (float(earning.rate) * 60.0), 17, INK))
		var bonuses: Array = []
		if float(earning.diversity) > 0.0: bonuses.append("Variety +%d%%" % roundi(float(earning.diversity) * 100.0))
		if float(earning.theme) > 0.0: bonuses.append("Habitat theme +25%")
		if float(earning.pair) > 0.0: bonuses.append("Friendship +%d%%" % roundi(float(earning.pair) * 100.0))
		box.add_child(_paragraph(" · ".join(bonuses) if not bonuses.is_empty() else "Try a habitat theme or a friendship pair.", 11, MUTED))
		var this_pen = index
		box.add_child(_button("Manage", func(): _manage_pen(this_pen), "soft"))
		var upgrade = _button("Upgrade %d" % model.upgrade_cost(index) if int(pen.level) < 5 else "Fully upgraded", func(): _upgrade(this_pen), "soft")
		upgrade.disabled = int(pen.level) >= 5 or int(model.state.coins) < model.upgrade_cost(index)
		upgrade.add_theme_font_size_override("font_size", 13)
		box.add_child(upgrade)
	var expansion = _button("Open another meadow  ·  %s coins" % _number(model.new_pen_cost()), _expand, "soft")
	expansion.disabled = int(model.state.coins) < model.new_pen_cost()
	body.add_child(expansion)
	body.add_child(_paragraph("No meadow limit. Browse six at a time. Duplicate captures raise a species' bond level; every resident of that species earns more.", 13))
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
		meadow_page = int((model.state.pens.size() - 1) / 6)
		_sound("upgrade")
		_toast("A new meadow is ready for residents.")
		_check_progress()
		_render()

func _manage_pen(index: int) -> void:
	var box = _open_modal("Meadow %d" % (index + 1))
	var earning = model.meadow_income(index)
	box.add_child(_paragraph("%.1f coins/min with these residents. Different species add variety, matching home habitats add 25%%, and named friendship pairs add 12%% each." % (float(earning.rate) * 60.0)))
	var residents = model.state.pens[index].residents
	for slot in range(residents.size()):
		var id = int(residents[slot])
		var rarity = int(model.species(id).rarity)
		var item = HBoxContainer.new()
		box.add_child(item)
		item.add_child(_sprite(id, 48))
		var name_label = _paragraph("%s\n%s · Species Lv %d" % [str(model.species(id).name), Model.RARITIES[rarity], model.species_level(id)], 13, RARITY_COLORS[rarity].darkened(0.25))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_child(name_label)
		var this_slot = slot
		item.add_child(_button("Rest", func(): model.remove_resident(index, this_slot); _close_modal(); _render(); _manage_pen(index), "soft"))
	if residents.size() < model.pen_capacity(index):
		box.add_child(_label("ADD A RESIDENT", 13, MUTED))
		for key in model.state.owned:
			var id = int(key)
			if model.count(id) > model.assigned_count(id):
				var rarity = int(model.species(id).rarity)
				var this_id = id
				var choose = _button("%s  +\n%s · Lv %d · %s" % [str(model.species(id).name), Model.RARITIES[rarity], model.species_level(id), Model.ZONES[model.species_biome(id)].name], func(): model.assign(this_id, index); _close_modal(); _render(); _manage_pen(index), "soft")
				choose.custom_minimum_size.y = 72
				choose.add_theme_font_size_override("font_size", 13)
				choose.add_theme_stylebox_override("normal", _style(RARITY_COLORS[rarity].lightened(0.74)))
				box.add_child(choose)
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
		var reward = model.daily_reward(day)
		row.add_child(_label("Rare creature" if reward.rare_creature else "%d coins" % int(reward.coins), 17))
	var claim = _button("Claim day %d gift" % next if model.daily_available() else "Gift collected today", func():
		var reward = model.claim_daily()
		_close_modal()
		if not reward.is_empty():
			if int(reward.creature) >= 0: _toast("Rare gift: %s joined your sanctuary! +%d XP" % [model.species(int(reward.creature)).name, int(reward.xp)])
			else: _toast("A gift of %d coins and %d XP. Glad you are here!" % [int(reward.coins), int(reward.xp)])
		_check_progress()
		_render(), "gold")
	claim.disabled = not model.daily_available()
	box.add_child(claim)
	box.add_child(_button("Back", _close_modal, "soft"))

func _safari() -> void:
	if model.state.safari.is_empty():
		_section("One expedition. One special friend.", "%d lures · 90 seconds · Chain every gold-window hit to bring one resident home." % model.lure_capacity())
		var equipment = _card()
		equipment.add_child(_label("EXPLORER'S SATCHEL", 12, MUTED))
		equipment.add_child(_paragraph("%d lures per outing. A lure starts a creature's complete capture chain; a miss spends that lure. Normal safaris are always free." % model.lure_capacity(), 14, INK))
		var upgrade = _button("Add a lure  ·  %d coins" % model.lure_upgrade_cost() if int(model.state.lure_level) < Model.MAX_LURE_LEVEL else "Satchel fully upgraded", func():
			if model.upgrade_lures(): _sound("upgrade"); _toast("Satchel upgraded!"); _render(), "soft")
		upgrade.disabled = int(model.state.lure_level) >= Model.MAX_LURE_LEVEL or int(model.state.coins) < model.lure_upgrade_cost()
		equipment.add_child(upgrade)
		for index in range(Model.ZONES.size()):
			var habitat: Dictionary = Model.ZONES[index]
			var unlocked = model.zone_available(index)
			var box = _card()
			var art = HBoxContainer.new()
			box.add_child(art)
			art.add_child(_sprite(int(Model.ZONE_POOLS[index][0][0]), 78))
			var title = VBoxContainer.new()
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			art.add_child(title)
			title.add_child(_label(str(habitat.name), 20))
			title.add_child(_paragraph(str(habitat.description), 14))
			if not unlocked: box.add_child(_paragraph("Keeper %d/%d · %d/%d outings" % [model.player_level(), int(habitat.level), int(model.state.stats.outings), int(habitat.outings)], 13, MUTED))
			var which = index
			var depart = _button("Explore  →" if unlocked else "Keep exploring to open this trail", func(): _start_safari(which))
			depart.disabled = not unlocked
			box.add_child(depart)
		var quest = _card()
		quest.add_child(_label("TODAY'S FIELD NOTE", 12, MUTED))
		quest.add_child(_paragraph("Bring home 3 creatures today. %d coins + %d XP." % [Model.QUEST_COINS, Model.QUEST_XP], 16, INK))
		quest.add_child(_label("%d / 3 friends brought home" % mini(3, model.quest_progress()), 15, MUTED))
		var claim = _button("Claim field-note reward" if not model.state.quest_claimed else "Field note complete", func():
			if model.claim_quest(): _toast("Field note complete! +%d coins +%d XP" % [Model.QUEST_COINS, Model.QUEST_XP])
			_check_progress()
			_render(), "gold")
		claim.disabled = model.state.quest_claimed or model.quest_progress() < 3
		quest.add_child(claim)
		return
	_section(str(Model.ZONES[int(model.state.safari.habitat)].name), "Tap a creature to inspect it, then choose Capture. Land EVERY stage inside gold.")
	var top = HBoxContainer.new()
	body.add_child(top)
	safari_time_label = _label("", 20)
	safari_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(safari_time_label)
	safari_lure_label = _label("", 14, MUTED)
	top.add_child(safari_lure_label)
	wild_view = Habitat.new()
	wild_view.model = model
	wild_view.mode = "safari"
	wild_view.selected = selected_slot
	wild_view.custom_minimum_size.y = 410
	wild_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wild_view.creature_selected.connect(_select_creature)
	body.add_child(wild_view)
	safari_skip_button = _button("Skip this clearing", _skip_safari, "soft")
	body.add_child(safari_skip_button)
	safari_info = _paragraph("Choose a creature to see its rarity, bond level and collection details.", 16, INK)
	body.add_child(safari_info)
	capture_button = _button("Capture", _attempt_capture, "gold")
	capture_button.visible = false
	capture_button.disabled = true
	body.add_child(capture_button)
	body.add_child(_paragraph("One resident per expedition. Your satchel lets you try again if a chain breaks.", 14))
	body.add_child(_button("Return to sanctuary", _finish_safari, "soft"))
	_update_ticking_labels()
	_update_capture_labels()

func _update_capture_labels() -> void:
	if is_instance_valid(safari_lure_label) and not model.state.safari.is_empty():
		safari_lure_label.text = "%d LURES LEFT" % int(model.state.safari.lures)
	var window = model.capture_window()
	if is_instance_valid(safari_skip_button) and not model.state.safari.is_empty():
		safari_skip_button.text = "Skip clearing - %d lure%s" % [model.safari_skip_cost(), "" if model.safari_skip_cost() == 1 else "s"]
		safari_skip_button.disabled = not model.can_skip_safari()
	if not is_instance_valid(capture_button): return
	capture_button.visible = selected_slot >= 0
	if window.is_empty():
		if selected_slot >= 0 and not model.state.safari.is_empty():
			var id = model.safari_species(selected_slot)
			var entry = model.species(id)
			var owned = model.count(id)
			safari_info.text = "%s - %s\n%s - Bond level %d\nHome: %s - %d gold-window hits to capture" % [entry.name, Model.RARITIES[int(entry.rarity)], "Not yet collected" if owned == 0 else "%d resident%s collected" % [owned, "" if owned == 1 else "s"], model.species_level(id), Model.ZONES[model.species_biome(id)].name, 2 + int(entry.rarity)]
			capture_button.text = "Capture"
			capture_button.disabled = int(model.state.safari.lures) <= 0
		return
	var creature = model.species(int(window.id))
	safari_info.text = "%s · %s\nStage %d/%d · land in gold" % [creature.name, Model.RARITIES[int(creature.rarity)], int(window.stage) + 1, int(window.required)]
	capture_button.text = "Secure stage %d / %d" % [int(window.stage) + 1, int(window.required)]
	capture_button.disabled = false

func _start_safari(habitat: int) -> void:
	if model.start_safari(habitat, int(Time.get_ticks_msec())):
		selected_slot = -1
		page = "safari"
		_render()
		_reset_page_scroll()

func _select_creature(slot: int) -> void:
	if model.state.safari.is_empty() or slot < 0 or slot > 2 or not model.capture_window().is_empty(): return
	# Inspection changes no model state, offer, lure or capture stage.
	selected_slot = slot
	wild_view.selected = slot
	_update_capture_labels()

func _skip_safari() -> void:
	if not model.skip_safari(): return
	selected_slot = -1
	_save()
	_render()

func _attempt_capture() -> void:
	if selected_slot < 0 or model.state.safari.is_empty(): return
	var window = model.capture_window()
	if window.is_empty():
		if model.begin_capture(selected_slot):
			capture_phase = -PI * 0.5
			_update_capture_labels()
			_save()
		return
	var id = int(window.id)
	var result = model.tap_capture((sin(capture_phase) + 1.0) * 0.5)
	if result == "stage":
		_sound("capture")
		capture_phase = -PI * 0.5
		_update_capture_labels()
		_toast("Good hit! The next gold window moves.")
		_save()
		return
	if result == "caught":
		_sound("capture")
		_finish_safari()
		return
	if result == "blocked": return
	_sound("escape")
	_toast("%s slipped away. A miss breaks the whole chain." % model.species(id).name)
	selected_slot = -1
	if int(model.state.safari.lures) <= 0: _finish_safari()
	else: _render()

func _finish_safari() -> void:
	var result = model.finish_safari()
	if result.is_empty():
		return
	selected_slot = -1
	page = "home"
	_check_progress()
	_render()
	_reset_page_scroll()
	if result.get("completed", true):
		# The model's saved total makes the fifth-outing cadence survive relaunch.
		_service("round_finished", [int(model.state.stats.outings)])
	var box = _open_modal("Welcome home, explorer.")
	box.add_child(_paragraph("%d resident%s safely brought home. +%d coins and +%d XP." % [result.caught.size(), "" if result.caught.size() == 1 else "s", int(result.coins), int(result.xp)], 18, INK))
	var row = HFlowContainer.new()
	box.add_child(row)
	for id in result.caught:
		row.add_child(_sprite(int(id), 78))
	for bond in result.get("levels", []):
		box.add_child(_paragraph("%s reached species level %d! Every resident of that species now earns more." % [model.species(int(bond.id)).name, int(bond.level)], 16, INK))
	if result.caught.is_empty():
		box.add_child(_paragraph("Every outing teaches you something. There is always another trail."))
	box.add_child(_button("Meet the residents", _close_modal))

func _nursery() -> void:
	_section("Grow the family tree.", "Parents need species level 5. Duplicate safari captures grow bonds; parents stay in your sanctuary.")
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
		var countdown = _label("Ready to hatch!" if remaining == 0 else "Hatches in %d seconds" % remaining, 14, MUTED)
		info.add_child(countdown)
		var slot = index
		var hatch = _button("Hatch egg", func(): _hatch(slot), "gold")
		hatch.disabled = remaining > 0
		card.add_child(hatch)
		nursery_rows.append({"slot": index, "countdown": countdown, "hatch": hatch})
	if model.state.nursery.is_empty():
		var empty = _card()
		empty.add_child(_label("The nursery is quiet.", 20))
		empty.add_child(_paragraph("Discover the parents below to start a new generation. There is room for two eggs."))
	else:
		var reward = _button("Watch an ad: hatch all eggs now", _reward_nursery, "soft")
		nursery_reward_button = reward
		reward.disabled = not _can_reward()
		body.add_child(reward)
		nursery_reward_status = _paragraph("Rewarded video is unavailable. Eggs hatch naturally while you play or rest.", 13)
		nursery_reward_status.visible = not _can_reward()
		body.add_child(nursery_reward_status)
	body.add_child(_label("BREEDING TREE  \u00b7  %d RECIPES" % model.catalog.recipes.size(), 13, MUTED))
	var recipes: Array = model.catalog.recipes.duplicate()
	recipes.sort_custom(_recipe_precedes)
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
			parent_box.add_child(_label(("✓ " if model.breeding_level_ready(parent_id) else "○ ") + "%s · Lv %d/5" % [str(model.species(parent_id).name), model.species_level(parent_id)], 13, INK if model.count(parent_id) > 0 else MUTED))
		var this_target = target
		var breed = _button("Breed  \u00b7  %d coins  \u00b7  %ds" % [model.breeding_cost(recipe), model.breeding_seconds(recipe)], func(): _breed(this_target), "soft")
		breed.disabled = not model.can_breed(recipe)
		card.add_child(breed)
	_update_nursery_rows()

func _recipe_precedes(a: Dictionary, b: Dictionary) -> bool:
	var a_ready = model.can_breed(a)
	var b_ready = model.can_breed(b)
	if a_ready != b_ready: return a_ready
	var a_bonds = mini(5, model.species_level(int(a.parents[0]))) + mini(5, model.species_level(int(a.parents[1])))
	var b_bonds = mini(5, model.species_level(int(b.parents[0]))) + mini(5, model.species_level(int(b.parents[1])))
	if a_bonds != b_bonds: return a_bonds > b_bonds
	return int(a.target) < int(b.target)

func _update_nursery_rows() -> void:
	if model == null or page != "nursery": return
	for row in nursery_rows:
		var slot: int = int(row.slot)
		if slot < 0 or slot >= model.state.nursery.size(): continue
		var remaining: int = maxi(0, int(model.state.nursery[slot].ready_at) - model.clock)
		if is_instance_valid(row.countdown):
			row.countdown.text = "Ready to hatch!" if remaining == 0 else "Hatches in %d seconds" % remaining
		if is_instance_valid(row.hatch): row.hatch.disabled = remaining > 0
	var waiting: bool = model.state.nursery.any(func(egg: Dictionary) -> bool: return int(egg.ready_at) > model.clock)
	if is_instance_valid(nursery_reward_button):
		nursery_reward_button.disabled = not waiting or not _can_reward()
	if is_instance_valid(nursery_reward_status): nursery_reward_status.visible = waiting and not _can_reward()

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

func _on_service_availability_changed() -> void:
	_update_nursery_rows()
	_refresh_creature_reward_buttons()

func _refresh_creature_reward_buttons() -> void:
	for button in creature_reward_buttons:
		if is_instance_valid(button):
			button.disabled = creature_reward_pending >= 0 or not model.can_reward_unlock(int(button.get_meta("creature_id"))) or not _can_reward()

func _reward_creature(id: int) -> void:
	if creature_reward_pending >= 0 or not model.can_reward_unlock(id):
		return
	if not _can_reward():
		_toast("No rewarded ad is ready. You can keep exploring normally.")
		return
	creature_reward_pending = id
	creature_reward_serial += 1
	var serial: int = creature_reward_serial
	_refresh_creature_reward_buttons()
	_service("reward_requested", ["collection_unlock_%d" % id, func(granted: bool):
		if creature_reward_pending != id or serial != creature_reward_serial:
			return
		creature_reward_pending = -1
		if granted and model.claim_reward_unlock(id):
			_check_progress()
			_sound("capture")
			_render()
			_toast("Reward earned. %s joined your sanctuary!" % model.species(id).name)
		elif granted:
			_toast("This friend is already discovered. No duplicate resident was added.")
		else:
			_toast("No reward earned. Your collection is unchanged.")
		_refresh_creature_reward_buttons()])

func _reward_nursery() -> void:
	if not _can_reward() or not model.state.nursery.any(func(egg: Dictionary) -> bool: return int(egg.ready_at) > model.clock):
		return
	_service("reward_requested", ["nursery_hatch", func(granted: bool):
		if granted:
			model.speed_nursery()
			_toast("Reward earned. Your eggs are ready!")
		else:
			_toast("No reward earned. Your eggs keep growing normally.")
		_update_nursery_rows()
		_save()])

func _journal() -> void:
	_section("Your living field guide.", "%d of 200 species discovered. Duplicate captures grow species levels and income." % model.collection_size())
	body.add_child(_paragraph("Tap an undiscovered Common, Uncommon or Rare silhouette to watch a rewarded ad and welcome that friend. Endangered and Extinct creatures cannot be discovered this way.", 14))
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
			if model.can_reward_unlock(int(creature.id)):
				var reward_id := int(creature.id)
				var discover := _button("", func(): _reward_creature(reward_id), "soft")
				discover.name = "RewardCreature%d" % reward_id
				discover.set_meta("creature_id", reward_id)
				discover.custom_minimum_size = Vector2(95, 96)
				discover.tooltip_text = "Watch a rewarded ad to discover this %s creature." % Model.RARITIES[rarity].to_lower()
				portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
				discover.add_child(portrait)
				portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				portrait.offset_left = 8
				portrait.offset_top = 8
				portrait.offset_right = -8
				portrait.offset_bottom = -8
				cell.add_child(discover)
				creature_reward_buttons.append(discover)
			else:
				cell.add_child(portrait)
			var locked_label := "Watch ad" if model.can_reward_unlock(int(creature.id)) else ("Nursery" if creature.breeding_only else "Undiscovered")
			var name_label = _paragraph(str(creature.name) if model.count(int(creature.id)) > 0 else locked_label, 10, MUTED)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.custom_minimum_size = Vector2(95, 32)
			cell.add_child(name_label)
			if model.count(int(creature.id)) > 0:
				cell.add_child(_label("Lv %d · ×%d" % [model.species_level(int(creature.id)), model.count(int(creature.id))], 12, RARITY_COLORS[rarity]))
				var this_id = int(creature.id)
				var detail = _button("Bond & home", func(): _species_details(this_id), "soft")
				detail.add_theme_font_size_override("font_size", 10)
				cell.add_child(detail)
	_refresh_creature_reward_buttons()

func _species_details(id: int) -> void:
	var creature = model.species(id)
	var box = _open_modal(str(creature.name))
	box.add_child(_sprite(id, 120))
	box.add_child(_label("%s · Species level %d" % [Model.RARITIES[int(creature.rarity)], model.species_level(id)], 18, RARITY_COLORS[int(creature.rarity)]))
	box.add_child(_paragraph("%d residents · %d duplicate bonds. Each repeat capture adds one species level, up to 50; all residents of this species share that bond." % [model.count(id), int(model.state.species_xp.get(str(id), 0))]))
	box.add_child(_paragraph("Home habitat: %s. A meadow of residents with the same home gains a 25%% theme bonus. Different species add variety." % Model.ZONES[model.species_biome(id)].name))
	box.add_child(_paragraph("Breeding ready!" if model.breeding_level_ready(id) else "Reach species level 5 to use this parent in discovered breeding recipes."))
	var friends: Array = []
	for pair in Model.MEADOW_PAIRS:
		if pair.has(id): friends.append(str(model.species(int(pair[1] if int(pair[0]) == id else pair[0])).name))
	if not friends.is_empty(): box.add_child(_paragraph("Friendship bonus with: %s (+12%% together)." % ", ".join(friends)))
	box.add_child(_button("Back to field guide", _close_modal))

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
	modal_panel = panel
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
	_apply_banner_layout()
	return box

func _close_modal() -> void:
	if is_instance_valid(modal):
		modal.hide()
		modal.queue_free()
	modal = null
	modal_panel = null

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
		var window = model.capture_window()
		capture_phase += delta * (float(window.speed) if not window.is_empty() else 1.35)
		if is_instance_valid(wild_view):
			wild_view.phase = capture_phase
	if second_timer >= 1.0:
		second_timer = 0.0
		model.tick(int(Time.get_unix_time_from_system()))
		_update_ticking_labels()
		if not model.state.safari.is_empty() and model.clock - int(model.state.safari.started) >= Model.SAFARI_DURATION:
			_finish_safari()
		_save()

func _update_ticking_labels() -> void:
	_update_nursery_rows()
	if is_instance_valid(bank_label):
		bank_label.text = "%s coins" % _number(int(model.state.bank))
	if is_instance_valid(safari_time_label) and not model.state.safari.is_empty():
		safari_time_label.text = "%02d seconds" % maxi(0, Model.SAFARI_DURATION - (model.clock - int(model.state.safari.started)))

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
	_release_audio()

func _release_audio() -> void:
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
	# Isolated UI/demo fixture only; never used for native gameplay evidence.
	while model.state.pens.size() < 3: model.state.pens.append({"level": 1, "residents": []})
	model.state.unlocked_zones = [0, 1, 2]
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
		model.begin_capture(1)
		selected_slot = 1

func _capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	var image = get_viewport().get_texture().get_image()
	var error = image.save_png(capture_path)
	print("SCREENSHOT ", capture_path, " result=", error)
	get_tree().quit(0 if error == OK else 1)

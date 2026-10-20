extends Control

signal creature_selected(slot: int)
var model: RefCounted
var mode = "home"
var selected = -1
var phase = 0.0
var textures: Dictionary = {}
var animation = 0.0
const INK = Color("183f39")

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP if mode == "safari" else Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	animation += delta
	queue_redraw()

func texture(id: int) -> Texture2D:
	var path = str(model.species(id).file)
	if not textures.has(path):
		textures[path] = load(path)
	return textures[path]

func animal(id: int, center: Vector2, scale_value: float = 1.0) -> void:
	var texture_value = texture(id)
	var size_value = Vector2(90, 90) * scale_value
	var bounce = sin(animation * 2.0 + id) * 3.0
	draw_ellipse(center + Vector2(0, 30 * scale_value), Vector2(28, 8) * scale_value, Color(0.1, 0.25, 0.18, 0.12))
	draw_texture_rect_region(texture_value, Rect2(center - size_value * 0.5 + Vector2(0, bounce), size_value), Rect2(int(animation * 3.0) % 4 * 192, 0, 192, 192))

func draw_ellipse(center: Vector2, radii: Vector2, color_value: Color) -> void:
	var points = PackedVector2Array()
	for i in range(33):
		var angle = float(i) / 32.0 * TAU
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color_value)

func tree(position: Vector2, scale_value: float = 1.0) -> void:
	draw_line(position, position - Vector2(0, 42) * scale_value, Color("9a8058"), 8 * scale_value)
	draw_circle(position - Vector2(0, 54) * scale_value, 27 * scale_value, Color("6e9b60"))
	draw_circle(position - Vector2(12, 64) * scale_value, 20 * scale_value, Color("87af69"))
	draw_circle(position - Vector2(-15, 55) * scale_value, 17 * scale_value, Color("a0c27a"))

func _draw() -> void:
	if model == null:
		return
	var s = size / Vector2(480, 300 if mode == "home" else 410)
	draw_set_transform(Vector2.ZERO, 0.0, s)
	if mode == "home":
		draw_style_box(_ground(Color("d7e7c5")), Rect2(0, 0, 480, 300))
		draw_circle(Vector2(408, 40), 28, Color("f6d986"))
		draw_polyline(PackedVector2Array([Vector2(240, 310), Vector2(245, 230), Vector2(220, 175), Vector2(235, 70)]), Color("eedfb7"), 38, true)
		draw_rect(Rect2(185, 31, 100, 55), Color("f4e8c8"))
		draw_colored_polygon(PackedVector2Array([Vector2(173, 34), Vector2(235, 4), Vector2(297, 34)]), Color("9c6b58"))
		draw_rect(Rect2(225, 59, 19, 27), Color("a58b65"))
		for i in range(6):
			var x = 27 + (i % 2) * 249
			var y = 108 + floori(float(i) / 2.0) * 56
			var owned_pen = i < model.state.pens.size()
			draw_style_box(_ground(Color("bdd2a1") if owned_pen else Color("cbdcb5")), Rect2(x, y, 176, 49))
			for p in range(7):
				draw_line(Vector2(x + p * 29, y + 40), Vector2(x + p * 29, y + 53), Color("b69c72"), 4)
			draw_line(Vector2(x, y + 47), Vector2(x + 176, y + 47), Color("b69c72"), 3)
			if owned_pen:
				var residents = model.state.pens[i].residents
				for j in range(mini(3, residents.size())):
					animal(int(residents[j]), Vector2(x + 45 + j * 45, y + 19), 0.64)
		for position in [Vector2(29, 67), Vector2(103, 43), Vector2(361, 84), Vector2(457, 283), Vector2(32, 290)]:
			tree(position, 0.8)
	else:
		var habitat = int(model.state.safari.get("habitat", 0))
		var colors = [Color("dcebc9"), Color("c6e1cb"), Color("ead7bd")]
		draw_style_box(_ground(colors[habitat]), Rect2(0, 0, 480, 410))
		draw_ellipse(Vector2(244, 240), Vector2(184, 130), Color(0.97, 0.94, 0.81, 0.55))
		for position in [Vector2(18, 90), Vector2(70, 50), Vector2(430, 80), Vector2(470, 240), Vector2(30, 360), Vector2(398, 395)]:
			tree(position, 1.1)
		for slot in range(3):
			var position = slot_position(slot)
			if selected == slot:
				draw_arc(position, 62, 0, TAU, 48, Color("f3c86a"), 5, true)
			animal(model.safari_species(slot), position, 1.2)
		if selected >= 0:
			draw_style_box(_ground(Color("183f39")), Rect2(42, 348, 396, 42))
			draw_rect(Rect2(210, 355, 60, 28), Color("f3c86a"))
			var marker = 240 + sin(phase) * 180
			draw_line(Vector2(marker, 351), Vector2(marker, 385), Color.WHITE, 5, true)
	draw_set_transform(Vector2.ZERO)

func slot_position(slot: int) -> Vector2:
	var positions = [Vector2(132, 134), Vector2(343, 170), Vector2(220, 278)]
	return positions[slot] + Vector2(sin(animation * 0.4 + slot) * 6, cos(animation * 0.3 + slot) * 5)

func _ground(color_value: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color_value
	style.set_corner_radius_all(22)
	return style

func _gui_input(event: InputEvent) -> void:
	if mode != "safari" or model.state.safari.is_empty():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point = event.position / (size / Vector2(480, 410))
		for slot in range(3):
			if point.distance_to(slot_position(slot)) < 69:
				creature_selected.emit(slot)
				accept_event()
				break

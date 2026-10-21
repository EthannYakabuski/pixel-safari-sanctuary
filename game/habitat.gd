extends Control

signal creature_selected(slot: int)
var model: RefCounted
var mode = "home"
var selected = -1
var pen_offset = 0
var phase = 0.0
var textures: Dictionary = {}
var animation = 0.0
var scenery: Texture2D
const INK = Color("183f39")

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP if mode == "safari" else Control.MOUSE_FILTER_IGNORE
	scenery = load("res://assets/environment/tiny-town.png")

func _process(delta: float) -> void:
	animation += delta
	queue_redraw()

func texture(id: int) -> Texture2D:
	var path = str(model.species(id).file)
	if not textures.has(path): textures[path] = load(path)
	return textures[path]

func animal(id: int, center: Vector2, scale_value: float = 1.0) -> void:
	var texture_value = texture(id)
	var size_value = Vector2(90, 90) * scale_value
	var bounce = sin(animation * 2.0 + id) * 3.0
	draw_ellipse(center + Vector2(0, 30 * scale_value), Vector2(28, 8) * scale_value, Color(0.1, 0.25, 0.18, 0.16))
	draw_texture_rect_region(texture_value, Rect2(center - size_value * 0.5 + Vector2(0, bounce), size_value), Rect2(int(animation * 3.0) % 4 * 192, 0, 192, 192))

func draw_ellipse(center: Vector2, radii: Vector2, color_value: Color) -> void:
	var points = PackedVector2Array()
	for i in range(33):
		var angle = float(i) / 32.0 * TAU
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color_value)

func tree(position: Vector2, scale_value: float = 1.0, autumn: bool = false) -> void:
	if scenery == null: return
	var source = Rect2(48 if autumn else 64, 0, 16, 32)
	var dimensions = Vector2(38, 76) * scale_value
	draw_ellipse(position + Vector2(0, 2), Vector2(19, 5) * scale_value, Color(0.1, 0.25, 0.18, 0.12))
	draw_texture_rect_region(scenery, Rect2(position - Vector2(dimensions.x * 0.5, dimensions.y), dimensions), source)

func ground(height: int, tint: Color) -> void:
	draw_style_box(_ground(tint), Rect2(0, 0, 480, height))
	if scenery == null: return
	for y in range(0, height, 32):
		for x in range(0, 480, 32):
			var flower = (x / 32 + y / 32 * 7) % 17 == 0
			draw_texture_rect_region(scenery, Rect2(x, y, 32, 32), Rect2(32 if flower else 0, 0, 16, 16), tint.lerp(Color.WHITE, 0.55))

func fence(start: Vector2, width: float) -> void:
	if scenery == null: return
	for x in range(0, int(width), 24):
		draw_texture_rect_region(scenery, Rect2(start + Vector2(x, 0), Vector2(24, 24)), Rect2(128, 48, 16, 16))

func _draw() -> void:
	if model == null: return
	var height = 300 if mode == "home" else 410
	var scale_value = size / Vector2(480, height)
	draw_set_transform(Vector2.ZERO, 0.0, scale_value)
	if mode == "home":
		ground(300, Color("d7e7c5"))
		# Supplied Tiny Town path tiles, trees and fences replace the old circle-tree sketch.
		for y in range(16, 300, 32):
			if scenery != null: draw_texture_rect_region(scenery, Rect2(224, y, 32, 32), Rect2(16, 16, 16, 16))
		for local_index in range(6):
			var index = pen_offset + local_index
			if index >= model.state.pens.size(): continue
			var x = 24 + (local_index % 2) * 252
			var y = 83 + floori(float(local_index) / 2.0) * 65
			var residents = model.state.pens[index].residents
			draw_ellipse(Vector2(x + 87, y + 22), Vector2(83, 24), Color(0.38, 0.58, 0.31, 0.15))
			fence(Vector2(x, y + 26), 178)
			for j in range(mini(3, residents.size())):
				animal(int(residents[j]), Vector2(x + 42 + j * 46, y + 7), 0.66)
		for position in [Vector2(30, 74), Vector2(102, 55), Vector2(362, 75), Vector2(461, 281), Vector2(27, 292)]:
			tree(position, 0.82, position.x > 300)
	else:
		var zone = int(model.state.safari.get("habitat", 0))
		ground(410, Color(model.ZONES[zone].color))
		draw_ellipse(Vector2(244, 226), Vector2(184, 122), Color(0.98, 0.95, 0.84, 0.42))
		for position in [Vector2(18, 103), Vector2(70, 72), Vector2(430, 96), Vector2(472, 253), Vector2(25, 349), Vector2(410, 333)]:
			tree(position, 1.14, zone in [2, 5])
		for slot in range(3):
			var position = slot_position(slot)
			if selected == slot:
				draw_arc(position, 62, 0, TAU, 48, Color("f3c86a"), 4, true)
				var progress = model.capture_window()
				if not progress.is_empty():
					for stage in range(int(progress.required)):
						draw_circle(position + Vector2((stage - (int(progress.required) - 1) * 0.5) * 13, 59), 4, Color("f3c86a") if stage < int(progress.stage) else Color("6d8276"))
			animal(model.safari_species(slot), position, 1.14)
		var window = model.capture_window()
		if selected >= 0 and not window.is_empty():
			draw_style_box(_ground(INK), Rect2(42, 348, 396, 42))
			draw_rect(Rect2(42 + float(window.left) * 396, 355, float(window.width) * 396, 28), Color("f3c86a"))
			var marker = 42 + (sin(phase) + 1.0) * 0.5 * 396
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
	if mode != "safari" or model.state.safari.is_empty(): return
	var pressed = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if not pressed: return
	var point = event.position / (size / Vector2(480, 410))
	for slot in range(3):
		if point.distance_to(slot_position(slot)) < 69:
			creature_selected.emit(slot)
			accept_event()
			break

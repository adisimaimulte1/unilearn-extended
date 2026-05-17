@tool
extends Node2D
class_name UnilearnPixelPlanet2D

signal planet_rebuilt
signal picked
signal released
signal dragged(global_position: Vector2)

const DEFAULT_PIXELS := 400
const DEFAULT_SEED := 2880143960

const POINTER_NONE := -999
const POINTER_MOUSE := -2

const PRESET_SCENES := {
	"terran_wet": preload("res://addons/UnilearnLib/planets/Rivers/Rivers.tscn"),
	"rivers": preload("res://addons/UnilearnLib/planets/Rivers/Rivers.tscn"),
	"terran_dry": preload("res://addons/UnilearnLib/planets/DryTerran/DryTerran.tscn"),
	"dry_terran": preload("res://addons/UnilearnLib/planets/DryTerran/DryTerran.tscn"),
	"islands": preload("res://addons/UnilearnLib/planets/LandMasses/LandMasses.tscn"),
	"no_atmosphere": preload("res://addons/UnilearnLib/planets/NoAtmosphere/NoAtmosphere.tscn"),
	"moon": preload("res://addons/UnilearnLib/planets/NoAtmosphere/NoAtmosphere.tscn"),
	"gas_giant_1": preload("res://addons/UnilearnLib/planets/GasPlanet/GasPlanet.tscn"),
	"gas_planet": preload("res://addons/UnilearnLib/planets/GasPlanet/GasPlanet.tscn"),
	"gas_giant_2": preload("res://addons/UnilearnLib/planets/GasPlanetLayers/GasPlanetLayers.tscn"),
	"ringed_gas_planet": preload("res://addons/UnilearnLib/planets/GasPlanetLayers/GasPlanetLayers.tscn"),
	"gas_layers": preload("res://addons/UnilearnLib/planets/GasPlanetLayers/GasPlanetLayers.tscn"),
	"ice_world": preload("res://addons/UnilearnLib/planets/IceWorld/IceWorld.tscn"),
	"lava_world": preload("res://addons/UnilearnLib/planets/LavaWorld/LavaWorld.tscn"),
	"black_hole": preload("res://addons/UnilearnLib/planets/BlackHole/BlackHole.tscn"),
	"galaxy": preload("res://addons/UnilearnLib/planets/Galaxy/Galaxy.tscn"),
	"star": preload("res://addons/UnilearnLib/planets/Star/Star.tscn"),
}

@export_enum(
	"terran_wet",
	"terran_dry",
	"islands",
	"no_atmosphere",
	"gas_giant_1",
	"gas_giant_2",
	"ice_world",
	"lava_world",
	"black_hole",
	"galaxy",
	"star"
) var preset: String = "terran_wet":
	set(value):
		preset = _normalize_preset(value)
		if is_inside_tree():
			rebuild()

@export var radius_px: float = 150.0:
	set(value):
		radius_px = max(1.0, value)
		_update_content_transform()
		queue_redraw()

@export var render_pixels: int = DEFAULT_PIXELS:
	set(value):
		render_pixels = max(12, value)
		if is_inside_tree():
			_apply_default_pixel_setup()
			_update_content_transform()
			queue_redraw()

@export var seed_value: int = DEFAULT_SEED:
	set(value):
		seed_value = value
		if is_inside_tree():
			_apply_default_seed()

@export var use_custom_colors: bool = false:
	set(value):
		use_custom_colors = value
		_apply_colors()

@export var custom_colors: PackedColorArray = PackedColorArray():
	set(value):
		custom_colors = value
		_apply_colors()

@export var debug_border_enabled: bool = false:
	set(value):
		debug_border_enabled = value
		queue_redraw()

@export var debug_border_color: Color = Color(0.2, 1.0, 1.0, 0.9):
	set(value):
		debug_border_color = value
		queue_redraw()

@export var debug_crosshair_color: Color = Color(1.0, 1.0, 1.0, 0.8):
	set(value):
		debug_crosshair_color = value
		queue_redraw()

@export var debug_border_width: float = 2.0:
	set(value):
		debug_border_width = max(1.0, value)
		queue_redraw()

@export var backing_disk_enabled: bool = true:
	set(value):
		backing_disk_enabled = value
		queue_redraw()

@export var backing_disk_color: Color = Color.BLACK:
	set(value):
		backing_disk_color = value
		queue_redraw()

@export var backing_disk_padding_px: float = 0.0:
	set(value):
		backing_disk_padding_px = max(0.0, value)
		queue_redraw()

@export var draggable: bool = true
@export var pick_padding_px: float = 18.0

@export var turning_speed: float = 1.0

@export var axial_tilt_deg: float = 0.0:
	set(value):
		axial_tilt_deg = value
		_apply_axial_tilt()

@export var drag_scale_multiplier: float = 0.94
@export var drag_scale_time: float = 0.12

@export var animation_update_hz: float = 24.0
var _animation_accum: float = 0.0
var _scene_animation_paused: bool = false

var _planet: Node = null
var _dragging: bool = false
var _active_pointer_id: int = POINTER_NONE
var _drag_offset: Vector2 = Vector2.ZERO
var _current_content_scale: float = 1.0
var _animation_time: float = 1000.0
var _drag_scale_tween: Tween = null



func _ready() -> void:
	rebuild()


func _process(delta: float) -> void:
	if _scene_animation_paused:
		return

	if not is_instance_valid(_planet):
		return

	if turning_speed == 0.0:
		return

	_animation_accum += delta

	var interval: float = 1.0 / max(animation_update_hz, 1.0)

	if _animation_accum < interval:
		return

	var step := _animation_accum
	_animation_accum = 0.0

	_animation_time += step * turning_speed

	if _planet.has_method("update_time"):
		_planet.call("update_time", _animation_time)


func set_scene_animation_paused(paused: bool) -> void:
	_scene_animation_paused = paused
	set_process(not paused)


func _draw() -> void:
	if backing_disk_enabled and _should_draw_backing_disk():
		draw_circle(Vector2.ZERO, radius_px + backing_disk_padding_px, backing_disk_color)

	if not debug_border_enabled:
		return

	var r := radius_px
	var rect := Rect2(Vector2(-r, -r), Vector2(r * 2.0, r * 2.0))
	draw_rect(rect, debug_border_color, false, debug_border_width)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 128, debug_border_color, debug_border_width, true)
	draw_line(Vector2(-r - 10.0, 0.0), Vector2(r + 10.0, 0.0), debug_crosshair_color, debug_border_width)
	draw_line(Vector2(0.0, -r - 10.0), Vector2(0.0, r + 10.0), debug_crosshair_color, debug_border_width)
	draw_circle(Vector2.ZERO, max(2.0, debug_border_width * 1.5), debug_crosshair_color)


func _should_draw_backing_disk() -> bool:
	var key := _normalize_preset(preset)

	match key:
		"star", "black_hole", "galaxy":
			return false
		_:
			return true

func _unhandled_input(_event: InputEvent) -> void:
	pass

func handle_external_input(event: InputEvent) -> void:
	_handle_drag_input(event)

func _handle_drag_input(event: InputEvent) -> void:
	if not draggable:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_start_drag(event.position, POINTER_MOUSE)
		else:
			if _active_pointer_id == POINTER_MOUSE:
				_stop_drag()
		return

	if event is InputEventMouseMotion:
		if _dragging and _active_pointer_id == POINTER_MOUSE:
			global_position = event.position + _drag_offset
			dragged.emit(global_position)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_try_start_drag(event.position, event.index)
		else:
			if event.index == _active_pointer_id:
				_stop_drag()
		return

	if event is InputEventScreenDrag:
		if _dragging and event.index == _active_pointer_id:
			global_position = event.position + _drag_offset
			dragged.emit(global_position)
			get_viewport().set_input_as_handled()
		return


func rebuild() -> void:
	_clear_planet()

	var scene: PackedScene = PRESET_SCENES.get(_normalize_preset(preset), PRESET_SCENES["terran_wet"])
	_planet = scene.instantiate()
	_planet.name = "DefaultPreset"
	add_child(_planet)

	_make_materials_unique(_planet)
	_normalize_planet_root_control()

	_planet.set_process(false)

	_apply_default_seed()
	_apply_default_pixel_setup()
	_apply_default_dither()
	_apply_axial_tilt()
	_apply_colors()
	_update_content_transform()

	planet_rebuilt.emit()


func _make_materials_unique(node: Node) -> void:
	if not is_instance_valid(node):
		return

	if node is CanvasItem:
		var item := node as CanvasItem

		if item.material != null:
			item.material = item.material.duplicate(true)
			item.material.resource_local_to_scene = true

	for child in node.get_children():
		_make_materials_unique(child)


func _normalize_planet_root_control() -> void:
	if not is_instance_valid(_planet):
		return

	if not (_planet is Control):
		return

	var control := _planet as Control
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
	control.position = Vector2.ZERO
	control.size = Vector2(float(render_pixels), float(render_pixels))
	control.custom_minimum_size = control.size
	control.pivot_offset = Vector2.ZERO


func _clear_planet() -> void:
	if is_instance_valid(_planet):
		_planet.queue_free()
		_planet = null

	for child in get_children():
		child.queue_free()


func _apply_default_pixel_setup() -> void:
	if not is_instance_valid(_planet):
		return

	if _planet.has_method("set_pixels"):
		_planet.call("set_pixels", render_pixels)

	_normalize_planet_root_control()


func _apply_default_seed() -> void:
	if not is_instance_valid(_planet):
		return

	seed(seed_value)
	if _planet.has_method("set_seed"):
		_planet.call("set_seed", seed_value)


func _apply_default_dither() -> void:
	if not is_instance_valid(_planet):
		return

	if _planet.has_method("set_dither"):
		_planet.call("set_dither", true)


func _apply_axial_tilt() -> void:
	if not is_instance_valid(_planet):
		return

	if _planet.has_method("set_rotates"):
		_planet.call("set_rotates", deg_to_rad(axial_tilt_deg))


func _apply_colors() -> void:
	if not is_instance_valid(_planet):
		return

	if not use_custom_colors:
		if _planet.get("original_colors") != null and _planet.has_method("set_colors"):
			_planet.call("set_colors", _planet.get("original_colors"))
		return

	if custom_colors.is_empty():
		return

	if _planet.has_method("set_colors"):
		_planet.call("set_colors", _fit_colors_for_current_preset(custom_colors))


func _fit_colors_for_current_preset(colors: PackedColorArray) -> PackedColorArray:
	if not is_instance_valid(_planet):
		return colors

	if not _planet.has_method("get_colors"):
		return colors

	var original = _planet.call("get_colors")
	if not (original is PackedColorArray):
		return colors

	var needed := (original as PackedColorArray).size()
	if needed <= 0 or colors.size() == needed:
		return colors

	var fitted := PackedColorArray()
	for i in needed:
		fitted.append(colors[i % colors.size()])
	return fitted


func _update_content_transform() -> void:
	if not is_instance_valid(_planet):
		return

	_normalize_planet_root_control()

	var body_rect := _get_planet_body_rect()

	if body_rect.size.x <= 0.0 or body_rect.size.y <= 0.0:
		body_rect = Rect2(Vector2.ZERO, Vector2(float(render_pixels), float(render_pixels)))

	var body_diameter: float = max(body_rect.size.x, body_rect.size.y)
	var target_diameter := radius_px * 2.0
	_current_content_scale = target_diameter / max(1.0, body_diameter)

	_planet.scale = Vector2.ONE * _current_content_scale
	_planet.position = -body_rect.get_center() * _current_content_scale

	queue_redraw()


func _get_planet_body_rect() -> Rect2:
	if not is_instance_valid(_planet):
		return Rect2(Vector2.ZERO, Vector2(float(render_pixels), float(render_pixels)))

	var result := Rect2()
	var has_rect := false

	for child in _planet.get_children():
		var child_rect := _get_canvas_item_rect_recursive_filtered(child, Transform2D.IDENTITY, true)
		if child_rect.size.x <= 0.0 or child_rect.size.y <= 0.0:
			continue

		if not has_rect:
			result = child_rect
			has_rect = true
		else:
			result = result.merge(child_rect)

	if has_rect:
		return result

	return Rect2(Vector2.ZERO, Vector2(float(render_pixels), float(render_pixels)))


func _get_planet_visual_rect() -> Rect2:
	if not is_instance_valid(_planet):
		return Rect2(Vector2.ZERO, Vector2(float(render_pixels), float(render_pixels)))

	var result := Rect2()
	var has_rect := false

	for child in _planet.get_children():
		var child_rect := _get_canvas_item_rect_recursive_filtered(child, Transform2D.IDENTITY, false)
		if child_rect.size.x <= 0.0 or child_rect.size.y <= 0.0:
			continue

		if not has_rect:
			result = child_rect
			has_rect = true
		else:
			result = result.merge(child_rect)

	if has_rect:
		return result

	return Rect2(Vector2.ZERO, Vector2(float(render_pixels), float(render_pixels)))


func _get_canvas_item_rect_recursive(node: Node, parent_transform: Transform2D) -> Rect2:
	return _get_canvas_item_rect_recursive_filtered(node, parent_transform, false)


func _get_canvas_item_rect_recursive_filtered(
	node: Node,
	parent_transform: Transform2D,
	ignore_rings: bool
) -> Rect2:
	if ignore_rings and _is_non_body_decoration_node(node):
		return Rect2()

	var local_transform := parent_transform

	if node is CanvasItem:
		local_transform = parent_transform * _get_canvas_item_local_transform(node as CanvasItem)

	var result := Rect2()
	var has_rect := false

	if node is Control:
		var control := node as Control
		var rect := _transform_rect(Rect2(Vector2.ZERO, control.size), local_transform)

		if rect.size.x > 0.0 and rect.size.y > 0.0:
			result = rect
			has_rect = true

	elif node is Sprite2D:
		var sprite := node as Sprite2D

		if sprite.texture != null:
			var texture_size := sprite.texture.get_size()
			var sprite_rect := Rect2(
				-texture_size * 0.5 if sprite.centered else Vector2.ZERO,
				texture_size
			)

			result = _transform_rect(sprite_rect, local_transform)
			has_rect = true

	for child in node.get_children():
		var child_rect := _get_canvas_item_rect_recursive_filtered(child, local_transform, ignore_rings)

		if child_rect.size.x <= 0.0 or child_rect.size.y <= 0.0:
			continue

		if not has_rect:
			result = child_rect
			has_rect = true
		else:
			result = result.merge(child_rect)

	return result if has_rect else Rect2()


func _get_canvas_item_local_transform(item: CanvasItem) -> Transform2D:
	if item is Node2D:
		return (item as Node2D).transform

	if item is Control:
		var control := item as Control

		var xform := Transform2D.IDENTITY
		xform = xform.translated(control.position + control.pivot_offset)
		xform = xform.rotated(control.rotation)
		xform = xform.scaled(control.scale)
		xform = xform.translated(-control.pivot_offset)

		return xform

	return Transform2D.IDENTITY


func _is_non_body_decoration_node(node: Node) -> bool:
	var node_name := node.name.to_lower()

	if node_name.contains("ring") or node_name.contains("rings"):
		return true

	if _normalize_preset(preset) == "star":
		if node_name.contains("flare") or node_name.contains("flares"):
			return true

		if node_name.contains("blob") or node_name.contains("blobs"):
			return true

	return false


func _transform_rect(rect: Rect2, xform: Transform2D) -> Rect2:
	var p0 := xform * rect.position
	var p1 := xform * Vector2(rect.position.x + rect.size.x, rect.position.y)
	var p2 := xform * Vector2(rect.position.x, rect.position.y + rect.size.y)
	var p3 := xform * (rect.position + rect.size)

	var min_x := min(min(p0.x, p1.x), min(p2.x, p3.x))
	var min_y := min(min(p0.y, p1.y), min(p2.y, p3.y))
	var max_x := max(max(p0.x, p1.x), max(p2.x, p3.x))
	var max_y := max(max(p0.y, p1.y), max(p2.y, p3.y))

	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _try_start_drag(screen_position: Vector2, pointer_id: int) -> void:
	if _active_pointer_id != POINTER_NONE:
		return

	if not contains_screen_point(screen_position):
		return

	_dragging = true
	_active_pointer_id = pointer_id
	_drag_offset = global_position - screen_position
	_tween_drag_scale(drag_scale_multiplier)
	picked.emit()
	get_viewport().set_input_as_handled()


func _stop_drag() -> void:
	if not _dragging:
		return

	_dragging = false
	_active_pointer_id = POINTER_NONE
	_tween_drag_scale(1.0)
	released.emit()
	get_viewport().set_input_as_handled()


func _tween_drag_scale(target_scale: float) -> void:
	if _drag_scale_tween != null:
		_drag_scale_tween.kill()

	_drag_scale_tween = create_tween()
	_drag_scale_tween.set_trans(Tween.TRANS_BACK)
	_drag_scale_tween.set_ease(Tween.EASE_OUT)
	_drag_scale_tween.tween_property(self, "scale", Vector2.ONE * target_scale, drag_scale_time)


func contains_screen_point(screen_position: Vector2) -> bool:
	var local := to_local(screen_position)
	return local.length() <= radius_px + pick_padding_px


func is_dragging() -> bool:
	return _dragging


func get_active_pointer_id() -> int:
	return _active_pointer_id


func owns_pointer(pointer_id: int) -> bool:
	return _dragging and _active_pointer_id == pointer_id


func get_default_colors() -> PackedColorArray:
	if is_instance_valid(_planet) and _planet.has_method("get_colors"):
		var colors = _planet.call("get_colors")
		if colors is PackedColorArray:
			return colors
	return PackedColorArray()


func set_preset(value: String) -> void:
	preset = value


func set_seed(value: int) -> void:
	seed_value = value


func set_pixels(value: int) -> void:
	render_pixels = value


func set_radius(value: float) -> void:
	radius_px = value


func set_debug_border_enabled(value: bool) -> void:
	debug_border_enabled = value


func set_custom_colors_enabled(value: bool) -> void:
	use_custom_colors = value


func set_planet_colors(colors: PackedColorArray) -> void:
	custom_colors = colors
	use_custom_colors = true


func clear_custom_colors() -> void:
	use_custom_colors = false
	custom_colors = PackedColorArray()
	_apply_colors()


func set_rotates(value: float) -> void:
	axial_tilt_deg = rad_to_deg(value)
	_apply_axial_tilt()


func set_axial_tilt_deg(value: float) -> void:
	axial_tilt_deg = value


func set_turning_speed(value: float) -> void:
	turning_speed = value


func set_light(pos: Vector2) -> void:
	if is_instance_valid(_planet) and _planet.has_method("set_light"):
		_planet.call("set_light", pos)


func _normalize_preset(value: String) -> String:
	var key := value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")

	match key:
		"wet", "terran", "terran_wet", "river", "rivers", "earth_rivers":
			return "terran_wet"
		"dry", "mars", "desert", "terran_dry", "dry_terran":
			return "terran_dry"
		"island", "islands", "land", "land_masses", "earth":
			return "islands"
		"moon", "luna", "no_atmosphere", "mercury":
			return "no_atmosphere"
		"gas", "gas_giant", "gas_giant_1", "gas_planet", "jupiter":
			return "gas_giant_1"
		"saturn", "ringed", "ringed_gas_planet", "gas_giant_2", "gas_layers":
			return "gas_giant_2"
		"ice", "ice_world", "uranus", "neptune":
			return "ice_world"
		"lava", "lava_world":
			return "lava_world"
		"black_hole", "blackhole":
			return "black_hole"
		"galaxy":
			return "galaxy"
		"sun", "star":
			return "star"
		_:
			return "terran_wet"

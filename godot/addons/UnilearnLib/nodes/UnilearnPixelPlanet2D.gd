@tool
extends Node2D
class_name UnilearnPixelPlanet2D

signal rebuilt
signal preset_changed(preset_name: String)

const Presets := preload("res://addons/UnilearnLib/core/UnilearnPixelPlanetPresets.gd")

@export_enum("islands", "earth", "rivers", "dry_terran", "moon", "gas_planet", "ringed_gas_planet", "ice_world", "lava_world", "black_hole", "galaxy", "star") var preset: String = "islands":
	set(value):
		preset = Presets.normalize_name(value)
		if is_inside_tree():
			rebuild()

@export_range(4, 4096, 1) var radius_px: int = 128:
	set(value):
		radius_px = max(4, value)
		_update_sprite_transform()

@export_range(16, 5000, 1) var render_pixels: int = 768:
	set(value):
		render_pixels = clampi(value, 16, 5000)
		if is_inside_tree():
			_apply_planet_settings()
			_resize_viewport()
		_update_sprite_transform()

var seed_value: int = 1234

@export var spin_speed: float = 0.25
@export var axial_tilt_deg: float = 0.0:
	set(value):
		axial_tilt_deg = value
		if is_inside_tree():
			_call_planet("set_rotates", [deg_to_rad(axial_tilt_deg)])

@export var should_dither: bool = true:
	set(value):
		should_dither = value
		if is_inside_tree():
			_call_planet("set_dither", [should_dither])

@export var use_original_preset_parameters: bool = true:
	set(value):
		use_original_preset_parameters = value
		if is_inside_tree():
			_apply_planet_settings()


@export var light_angle_deg: float = 45.0:
	set(value):
		light_angle_deg = value
		_update_light()

@export_range(0.0, 4.0, 0.01) var light_distance: float = 1.0:
	set(value):
		light_distance = value
		_update_light()

@export_range(0.0, 2.0, 0.01) var light_softness: float = 0.6:
	set(value):
		light_softness = value
		_set_shader_parameter_everywhere(["light_border_1"], clampf(0.5 - value * 0.30, 0.0, 1.0))
		_set_shader_parameter_everywhere(["light_border_2"], clampf(0.5 + value * 0.30, 0.0, 1.0))

@export_range(0.0, 4.0, 0.01) var light_intensity: float = 1.0:
	set(value):
		light_intensity = value
		_set_shader_parameter_everywhere(["light_intensity", "brightness", "strength"], value)

var _viewport: SubViewport
var _holder: Node2D
var _sprite: Sprite2D
var _planet: Node
var _time := 1000.0

func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"seed":
			seed_value = int(value)
			if is_inside_tree():
				_call_planet("set_seed", [seed_value])
			return true
		_:
			return false

func _get(property: StringName) -> Variant:
	match property:
		&"seed":
			return seed_value
		_:
			return null

func _get_property_list() -> Array[Dictionary]:
	return [
		{
			"name": "seed",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
		}
	]

func _ready() -> void:
	_ensure_render_nodes()
	rebuild()

func _process(delta: float) -> void:
	_time += delta * spin_speed
	_call_planet("update_time", [_time])

func rebuild() -> void:
	_ensure_render_nodes()
	_clear_planet()

	var path := Presets.get_scene_path(preset)
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Could not load planet preset: " + path)
		return

	_planet = scene.instantiate()
	_holder.add_child(_planet)
	_apply_planet_settings()
	_resize_viewport()
	_update_sprite_transform()
	preset_changed.emit(preset)
	rebuilt.emit()

func randomize_colors() -> void:
	_call_planet("randomize_colors", [])

func get_colors() -> PackedColorArray:
	if _planet != null and _planet.has_method("get_colors"):
		return _planet.call("get_colors")
	return PackedColorArray()

func set_colors(colors: PackedColorArray) -> void:
	_call_planet("set_colors", [colors])

func get_layers() -> Array:
	if _planet != null and _planet.has_method("get_layers"):
		return _planet.call("get_layers")
	return []

func toggle_layer(index: int) -> void:
	_call_planet("toggle_layer", [index])

func set_layer_visible(index: int, visible: bool) -> void:
	if _planet == null:
		return
	if index < 0 or index >= _planet.get_child_count():
		return
	var child := _planet.get_child(index)
	if child is CanvasItem:
		(child as CanvasItem).visible = visible

func set_light_angle_distance(angle_deg: float, distance: float = 1.0) -> void:
	light_angle_deg = angle_deg
	light_distance = distance
	_update_light()

func get_planet_node() -> Node:
	return _planet

func get_shader_parameter_dump() -> Dictionary:
	var out := {}
	if _planet == null:
		return out
	_dump_shader_params_recursive(_planet, out, _planet.name)
	return out

func set_shader_parameter_on_layer(layer_name: String, parameter_name: StringName, value: Variant) -> bool:
	if _planet == null:
		return false
	var layer := _find_child_recursive(_planet, layer_name)
	if layer == null or not (layer is CanvasItem):
		return false
	var mat := (layer as CanvasItem).material as ShaderMaterial
	if mat == null:
		return false
	mat.set_shader_parameter(parameter_name, value)
	return true

func _ensure_render_nodes() -> void:
	if _viewport == null:
		_viewport = SubViewport.new()
		_viewport.name = "PlanetViewport"
		_viewport.disable_3d = true
		_viewport.transparent_bg = true
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_viewport)

	if _holder == null:
		_holder = Node2D.new()
		_holder.name = "PlanetHolder"
		_viewport.add_child(_holder)

	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "PlanetSprite"
		_sprite.centered = true
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)

	_sprite.texture = _viewport.get_texture()

func _clear_planet() -> void:
	if _planet != null and is_instance_valid(_planet):
		_planet.queue_free()
		_planet = null
	for c in _holder.get_children():
		c.queue_free()

func _apply_planet_settings() -> void:
	if _planet == null:
		return
	seed(seed_value)
	_call_planet("set_pixels", [float(render_pixels)])

	# The Deep-Fold site presets have carefully tuned per-layer shader values.
	# For exact visual matching, keep those defaults unless the user disables this.
	if not (use_original_preset_parameters and preset == "islands"):
		_call_planet("set_seed", [seed_value])

	_call_planet("set_rotates", [deg_to_rad(axial_tilt_deg)])
	_call_planet("set_dither", [should_dither])
	_apply_site_preset_parameters()
	_update_light()

	var rel := _get_relative_scale()
	if _planet is Control:
		(_planet as Control).position = Vector2(render_pixels, render_pixels) * 0.5 * (rel - 1.0)

func _resize_viewport() -> void:
	if _viewport == null:
		return
	var rel := _get_relative_scale()
	_viewport.size = Vector2i(ceili(render_pixels * rel), ceili(render_pixels * rel))
	if _holder != null:
		_holder.position = Vector2.ZERO
	if _sprite != null:
		_sprite.texture = _viewport.get_texture()

func _update_sprite_transform() -> void:
	if _sprite == null:
		return
	var rel := _get_relative_scale()
	_sprite.position = Vector2.ZERO
	_sprite.scale = Vector2.ONE * ((float(radius_px) * 2.0) / max(1.0, float(render_pixels)))
	_sprite.offset = Vector2.ZERO
	# Ringed planets, galaxies, and black holes keep their extra viewport area centered.
	if _viewport != null:
		_sprite.centered = true

func _update_light() -> void:
	if _planet == null:
		return
	var r := deg_to_rad(light_angle_deg)
	var p := Vector2(0.5, 0.5) + Vector2(cos(r), -sin(r)) * 0.5 * light_distance
	_call_planet("set_light", [p])
	_set_shader_parameter_everywhere(["light_origin"], p)
	_set_shader_parameter_everywhere(["light_border_1"], clampf(0.5 - light_softness * 0.30, 0.0, 1.0))
	_set_shader_parameter_everywhere(["light_border_2"], clampf(0.5 + light_softness * 0.30, 0.0, 1.0))
	_set_shader_parameter_everywhere(["light_intensity", "brightness", "strength"], light_intensity)


func _apply_site_preset_parameters() -> void:
	if not use_original_preset_parameters:
		return
	if preset == "islands":
		_apply_islands_site_preset()

func _apply_islands_site_preset() -> void:
	# Exact LandMasses/Islands defaults from the original Deep-Fold scene.
	_set_layer_shader_parameter("Water", &"time_speed", 0.1)
	_set_layer_shader_parameter("Water", &"dither_size", 2.0)
	_set_layer_shader_parameter("Water", &"size", 5.228)
	_set_layer_shader_parameter("Water", &"OCTAVES", 3)
	_set_layer_shader_parameter("Water", &"seed", 10.0)
	_set_layer_shader_parameter("Water", &"colors", PackedColorArray([
		Color(0.572549, 0.909804, 0.752941, 1.0),
		Color(0.309804, 0.643137, 0.721569, 1.0),
		Color(0.172549, 0.207843, 0.301961, 1.0),
	]))

	_set_layer_shader_parameter("Land", &"time_speed", 0.2)
	_set_layer_shader_parameter("Land", &"land_cutoff", 0.633)
	_set_layer_shader_parameter("Land", &"size", 4.292)
	_set_layer_shader_parameter("Land", &"OCTAVES", 6)
	_set_layer_shader_parameter("Land", &"seed", 7.947)
	_set_layer_shader_parameter("Land", &"colors", PackedColorArray([
		Color(0.784314, 0.831373, 0.364706, 1.0),
		Color(0.388235, 0.670588, 0.247059, 1.0),
		Color(0.184314, 0.341176, 0.32549, 1.0),
		Color(0.156863, 0.207843, 0.25098, 1.0),
	]))

	_set_layer_shader_parameter("Cloud", &"cloud_cover", 0.415)
	_set_layer_shader_parameter("Cloud", &"time_speed", 0.47)
	_set_layer_shader_parameter("Cloud", &"stretch", 2.0)
	_set_layer_shader_parameter("Cloud", &"cloud_curve", 1.3)
	_set_layer_shader_parameter("Cloud", &"size", 7.745)
	_set_layer_shader_parameter("Cloud", &"OCTAVES", 2)
	_set_layer_shader_parameter("Cloud", &"seed", 5.939)
	_set_layer_shader_parameter("Cloud", &"colors", PackedColorArray([
		Color(0.87451, 0.878431, 0.909804, 1.0),
		Color(0.639216, 0.654902, 0.760784, 1.0),
		Color(0.407843, 0.435294, 0.6, 1.0),
		Color(0.25098, 0.286275, 0.45098, 1.0),
	]))

func set_preset_parameter(layer_name: String, parameter_name: StringName, value: Variant) -> bool:
	return _set_layer_shader_parameter(layer_name, parameter_name, value)

func _set_layer_shader_parameter(layer_name: String, parameter_name: StringName, value: Variant) -> bool:
	if _planet == null:
		return false
	var layer := _find_child_recursive(_planet, layer_name)
	if layer == null or not (layer is CanvasItem):
		return false
	var mat := (layer as CanvasItem).material as ShaderMaterial
	if mat == null:
		return false
	mat.set_shader_parameter(parameter_name, value)
	return true

func _call_planet(method_name: StringName, args: Array) -> Variant:
	if _planet == null or not _planet.has_method(method_name):
		return null
	return _planet.callv(method_name, args)

func _get_relative_scale() -> float:
	if _planet != null:
		var value = _planet.get("relative_scale")
		if value != null:
			return float(value)
	return 1.0

func _set_shader_parameter_everywhere(names: Array, value: Variant) -> void:
	if _planet == null:
		return
	_set_shader_parameter_recursive(_planet, names, value)

func _set_shader_parameter_recursive(node: Node, names: Array, value: Variant) -> void:
	if node is CanvasItem:
		var mat := (node as CanvasItem).material as ShaderMaterial
		if mat != null:
			for n in names:
				mat.set_shader_parameter(n, value)
	for c in node.get_children():
		_set_shader_parameter_recursive(c, names, value)

func _dump_shader_params_recursive(node: Node, out: Dictionary, path: String) -> void:
	if node is CanvasItem:
		var mat := (node as CanvasItem).material as ShaderMaterial
		if mat != null and mat.shader != null:
			var params := {}
			for uniform in mat.shader.get_shader_uniform_list():
				var pname := StringName(uniform.get("name", ""))
				if pname != &"":
					params[String(pname)] = mat.get_shader_parameter(pname)
			out[path] = params
	for c in node.get_children():
		_dump_shader_params_recursive(c, out, path + "/" + c.name)

func _find_child_recursive(node: Node, child_name: String) -> Node:
	if node.name == child_name:
		return node
	for c in node.get_children():
		var found := _find_child_recursive(c, child_name)
		if found != null:
			return found
	return null

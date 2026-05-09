extends Control

const LOGIN_SCENE := "res://app/auth/LoginScreen.tscn"
const PIXEL_PLANET_SCRIPT := preload("res://addons/UnilearnLib/nodes/UnilearnPixelPlanet2D.gd")
const BOTTOM_MENU_SCRIPT := preload("res://app/ui/UnilearnBottomMenu.gd")

@onready var ai_assistant: Node = get_node_or_null("AIAssistant")

var blocked_touch_indices: Dictionary = {}

var sfx_enabled: bool = true
var apollo_enabled: bool = true
var reduce_motion_enabled: bool = false

# --- Cached references ---
var _space_background_ref: Node = null
var _viewport_center: Vector2 = Vector2.ZERO

# --- Bottom menu ---
var bottom_menu: UnilearnBottomMenu = null

# --- Planet preview state ---
var planet_preview: Node2D

var planet_space_position: Vector2 = Vector2.ZERO
var planet_space_scale_multiplier: float = 1.0

var planet_archetype_name: String = "islands"
var planet_radius_px: int = 230
var planet_pixels: int = 768
var planet_seed: int = 1234
var planet_spin_speed: float = 0.25
var planet_axial_tilt_deg: float = 0.0

var planet_light_angle_deg: float = 45.0
var planet_light_distance: float = 1.0
var planet_light_softness: float = 0.6
var planet_light_intensity: float = 1.0

var _planet_intro_offset: Vector2 = Vector2.ZERO
var _planet_intro_scale: float = 1.0

var _last_light_angle: float = INF
var _last_light_distance: float = INF
var _last_light_softness: float = INF
var _last_light_intensity: float = INF

# --- Transform cache ---
var _last_space_position: Vector2 = Vector2(INF, INF)
var _last_space_zoom: float = INF
var _last_zoom_visual_strength: float = INF
var _last_space_rotation: float = INF
var _last_planet_space_position: Vector2 = Vector2(INF, INF)
var _last_intro_offset: Vector2 = Vector2(INF, INF)
var _last_intro_scale: float = INF
var _last_planet_scale_multiplier: float = INF
var _last_applied_position: Vector2 = Vector2(INF, INF)
var _last_applied_scale: float = INF
var _last_applied_rotation: float = INF

func _ready() -> void:
	_full_rect(self)
	_load_local_settings()

	RenderingServer.set_default_clear_color(Color("#050712"))

	_cache_viewport()
	_cache_space_background()
	_setup_space_background()

	_ensure_planet_preview_exists()
	_setup_planet_preview()

	_setup_ai_assistant()
	_setup_bottom_menu()

	await get_tree().process_frame
	_animate_in()


func _load_local_settings() -> void:
	if not has_node("/root/UnilearnUserSettings"):
		return

	var settings := get_node("/root/UnilearnUserSettings")

	sfx_enabled = settings.sfx_enabled
	
	if has_node("/root/UnilearnSFX"):
		get_node("/root/UnilearnSFX").set_enabled(sfx_enabled)
	
	apollo_enabled = settings.apollo_enabled
	reduce_motion_enabled = settings.reduce_motion_enabled


func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_cache_viewport()
		_force_planet_transform_update()


func _process(_delta: float) -> void:
	_update_space_locked_planet(false)


func _input(event: InputEvent) -> void:
	if _space_background_ref == null:
		return

	if _space_background_ref.get("navigation_enabled") != true:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if _is_position_over_blocking_ui(event.position):
				blocked_touch_indices[event.index] = true
				return

			# Important:
			# If the previous menu tap left this index blocked because the UI consumed release,
			# clear it immediately when a new touch starts outside UI.
			if blocked_touch_indices.has(event.index):
				blocked_touch_indices.erase(event.index)

		else:
			if blocked_touch_indices.has(event.index):
				blocked_touch_indices.erase(event.index)
				return

		if _space_background_ref.has_method("handle_navigation_input"):
			_space_background_ref.call("handle_navigation_input", event)

	elif event is InputEventScreenDrag:
		if blocked_touch_indices.has(event.index):
			return

		if _space_background_ref.has_method("handle_navigation_input"):
			_space_background_ref.call("handle_navigation_input", event)
	

func _cache_viewport() -> void:
	_viewport_center = get_viewport_rect().size * 0.5


func _cache_space_background() -> void:
	_space_background_ref = get_node_or_null("/root/SpaceBackground")


func _full_rect(node: Control) -> void:
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 1.0
	node.anchor_bottom = 1.0
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0


func _is_position_over_blocking_ui(pos: Vector2) -> bool:
	if is_instance_valid(bottom_menu) and bottom_menu.is_position_blocking(pos):
		return true

	return false


func _setup_bottom_menu() -> void:
	if is_instance_valid(bottom_menu):
		return

	bottom_menu = BOTTOM_MENU_SCRIPT.new()
	bottom_menu.name = "BottomMenu"
	add_child(bottom_menu)
	
	bottom_menu.sfx_enabled = sfx_enabled
	bottom_menu.apollo_enabled = apollo_enabled
	bottom_menu.set_reduce_motion_enabled(reduce_motion_enabled)

	bottom_menu.item_pressed.connect(_on_bottom_menu_item_pressed)
	bottom_menu.item_pressed.connect(func(_item_id: String) -> void:
		blocked_touch_indices.clear()
	)


func _on_bottom_menu_item_pressed(item_id: String) -> void:
	match item_id:
		"help":
			print("Open help / tutorial")

		"cards":
			print("Open planet cards")

		"achievements":
			print("Open achievements")

		"playgrounds":
			print("Open universe playgrounds")

		"settings":
			print("Open settings")

		"settings_reset_camera":
			_reset_space_camera()

		"settings_sfx_on":
			_set_sfx_enabled(true)

		"settings_sfx_off":
			_set_sfx_enabled(false)

		"settings_apollo_on":
			_set_apollo_enabled(true)

		"settings_apollo_off":
			_set_apollo_enabled(false)

		"settings_reduce_motion_on":
			_set_reduce_motion_enabled(true)

		"settings_reduce_motion_off":
			_set_reduce_motion_enabled(false)

		"settings_logout":
			_logout_user()

		_:
			print("Unknown bottom menu item: ", item_id)


func _set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled

	if has_node("/root/UnilearnUserSettings"):
		get_node("/root/UnilearnUserSettings").set_sfx_enabled(enabled)

	if has_node("/root/UnilearnSFX"):
		get_node("/root/UnilearnSFX").set_enabled(enabled)


func _set_reduce_motion_enabled(enabled: bool) -> void:
	reduce_motion_enabled = enabled

	if has_node("/root/UnilearnUserSettings"):
		get_node("/root/UnilearnUserSettings").set_reduce_motion_enabled(enabled)

	if is_instance_valid(bottom_menu):
		bottom_menu.set_reduce_motion_enabled(enabled)

	if _space_background_ref != null and _space_background_ref.has_method("set_reduce_motion_enabled"):
		_space_background_ref.call("set_reduce_motion_enabled", enabled)

func _reset_space_camera() -> void:
	if _space_background_ref == null:
		return

	if _space_background_ref.has_method("reset_navigation_view"):
		_space_background_ref.call("reset_navigation_view")
	else:
		if _space_background_ref.get("space_position") is Vector2:
			_space_background_ref.set("space_position", Vector2.ZERO)

		if _space_background_ref.get("target_space_position") is Vector2:
			_space_background_ref.set("target_space_position", Vector2.ZERO)

		if _space_background_ref.get("space_zoom") != null:
			_space_background_ref.set("space_zoom", 1.0)

		if _space_background_ref.get("target_space_zoom") != null:
			_space_background_ref.set("target_space_zoom", 1.0)

		if _space_background_ref.get("space_rotation") != null:
			_space_background_ref.set("space_rotation", 0.0)

		if _space_background_ref.get("target_space_rotation") != null:
			_space_background_ref.set("target_space_rotation", 0.0)

	blocked_touch_indices.clear()
	_force_planet_transform_update()


func _logout_user() -> void:
	blocked_touch_indices.clear()

	if is_instance_valid(bottom_menu):
		bottom_menu.close_menu()

	if is_instance_valid(ai_assistant):
		if ai_assistant.has_method("stop"):
			ai_assistant.call("stop")

	if AIState.has_method("set_enabled"):
		AIState.set_enabled(false)
	else:
		AIState.enabled = false
		AIState.reset()

	if _space_background_ref != null and _space_background_ref.has_method("set_navigation_enabled"):
		_space_background_ref.call("set_navigation_enabled", false)

	var firebase_auth := get_node_or_null("/root/FirebaseAuth")
	if firebase_auth != null:
		if firebase_auth.has_method("logout"):
			firebase_auth.call("logout")
		elif firebase_auth.has_method("sign_out"):
			firebase_auth.call("sign_out")
		else:
			if firebase_auth.get("id_token") != null:
				firebase_auth.set("id_token", "")
			if firebase_auth.get("refresh_token") != null:
				firebase_auth.set("refresh_token", "")
			if firebase_auth.get("uid") != null:
				firebase_auth.set("uid", "")
			if firebase_auth.get("email") != null:
				firebase_auth.set("email", "")

	var firebase_service := get_node_or_null("/root/FirebaseService")
	if firebase_service != null:
		if firebase_service.has_method("logout"):
			firebase_service.call("logout")
		elif firebase_service.has_method("sign_out"):
			firebase_service.call("sign_out")

	get_tree().change_scene_to_file(LOGIN_SCENE)


func _setup_space_background() -> void:
	if _space_background_ref == null:
		push_warning("SpaceBackground autoload was not found. Planet will still render centered.")
		return

	if _space_background_ref.has_method("set_space_reveal"):
		_space_background_ref.call("set_space_reveal", 1.0)

	if _space_background_ref.has_method("set_nebula_reveal"):
		_space_background_ref.call("set_nebula_reveal", 0.7)

	_space_background_ref.set("star_reveal", 1.0)
	_space_background_ref.set("travel_speed_multiplier", 0.0)

	if _space_background_ref.has_method("set_navigation_enabled"):
		_space_background_ref.call("set_navigation_enabled", false)


func _ensure_planet_preview_exists() -> void:
	if is_instance_valid(planet_preview):
		return

	var created_planet: Node2D = PIXEL_PLANET_SCRIPT.new()
	created_planet.name = "PlanetPreview"
	add_child(created_planet)

	planet_preview = created_planet


func _setup_planet_preview() -> void:
	if not is_instance_valid(planet_preview):
		push_error("PlanetPreview could not be created.")
		return

	planet_preview.process_mode = Node.PROCESS_MODE_ALWAYS
	planet_preview.z_index = 20
	planet_preview.modulate.a = 0.0

	_planet_intro_offset = Vector2(0.0, 80.0)
	_planet_intro_scale = 0.82

	_apply_all_planet_settings(true)
	_force_planet_transform_update()


func _apply_all_planet_settings(force_rebuild: bool) -> void:
	if not is_instance_valid(planet_preview):
		return

	planet_preview.set("preset", _normalize_planet_name(planet_archetype_name))
	planet_preview.set("radius_px", planet_radius_px)
	planet_preview.set("render_pixels", planet_pixels)
	planet_preview.set("seed", planet_seed)
	planet_preview.set("spin_speed", planet_spin_speed)
	planet_preview.set("axial_tilt_deg", planet_axial_tilt_deg)

	planet_preview.set("light_angle_deg", planet_light_angle_deg)
	planet_preview.set("light_distance", planet_light_distance)
	planet_preview.set("light_softness", planet_light_softness)
	planet_preview.set("light_intensity", planet_light_intensity)

	if force_rebuild and planet_preview.has_method("rebuild"):
		planet_preview.call("rebuild")

	_update_dynamic_lighting(true)


func _setup_ai_assistant() -> void:
	if not is_instance_valid(ai_assistant):
		return

	ai_assistant.process_mode = Node.PROCESS_MODE_ALWAYS

	if ai_assistant is CanvasItem:
		(ai_assistant as CanvasItem).z_index = 999

	if AIState.has_method("set_enabled"):
		AIState.set_enabled(apollo_enabled)
	else:
		AIState.enabled = apollo_enabled

	await get_tree().process_frame

	if not is_instance_valid(ai_assistant):
		return

	if apollo_enabled:
		if ai_assistant.has_method("start"):
			ai_assistant.call("start")
	else:
		if ai_assistant.has_method("stop"):
			ai_assistant.call("stop")


func _animate_in() -> void:
	if _space_background_ref != null and _space_background_ref.has_method("set_navigation_enabled"):
		_space_background_ref.call("set_navigation_enabled", false)

	if not is_instance_valid(planet_preview):
		return

	if reduce_motion_enabled:
		planet_preview.modulate.a = 1.0
		_planet_intro_offset = Vector2.ZERO
		_planet_intro_scale = 1.0
		blocked_touch_indices.clear()

		if _space_background_ref != null and _space_background_ref.has_method("set_navigation_enabled"):
			_space_background_ref.call("set_navigation_enabled", true)

		_force_planet_transform_update()
		return

	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_OUT)

	t.tween_property(planet_preview, "modulate:a", 1.0, 0.45)

	t.parallel().tween_method(
		func(v: float) -> void:
			_planet_intro_offset = Vector2(0.0, 80.0).lerp(Vector2.ZERO, v)
			_planet_intro_scale = lerp(0.82, 1.0, v)
			_update_space_locked_planet(true),
		0.0,
		1.0,
		0.65
	)

	t.finished.connect(func() -> void:
		_planet_intro_offset = Vector2.ZERO
		_planet_intro_scale = 1.0
		blocked_touch_indices.clear()

		if _space_background_ref != null and _space_background_ref.has_method("set_navigation_enabled"):
			_space_background_ref.call("set_navigation_enabled", true)

		_force_planet_transform_update()
	)


func _update_dynamic_lighting(force: bool = false) -> void:
	if not is_instance_valid(planet_preview):
		return

	var changed := force
	changed = changed or not is_equal_approx(_last_light_angle, planet_light_angle_deg)
	changed = changed or not is_equal_approx(_last_light_distance, planet_light_distance)
	changed = changed or not is_equal_approx(_last_light_softness, planet_light_softness)
	changed = changed or not is_equal_approx(_last_light_intensity, planet_light_intensity)

	if not changed:
		return

	planet_preview.set("light_softness", planet_light_softness)
	planet_preview.set("light_intensity", planet_light_intensity)

	if planet_preview.has_method("set_light_angle_distance"):
		planet_preview.call("set_light_angle_distance", planet_light_angle_deg, planet_light_distance)
	else:
		planet_preview.set("light_angle_deg", planet_light_angle_deg)
		planet_preview.set("light_distance", planet_light_distance)

	_last_light_angle = planet_light_angle_deg
	_last_light_distance = planet_light_distance
	_last_light_softness = planet_light_softness
	_last_light_intensity = planet_light_intensity


func _force_planet_transform_update() -> void:
	_last_space_position = Vector2(INF, INF)
	_last_space_zoom = INF
	_last_zoom_visual_strength = INF
	_last_space_rotation = INF
	_last_planet_space_position = Vector2(INF, INF)
	_last_intro_offset = Vector2(INF, INF)
	_last_intro_scale = INF
	_last_planet_scale_multiplier = INF

	_update_space_locked_planet(true)


func _update_space_locked_planet(force: bool = false) -> void:
	if not is_instance_valid(planet_preview):
		return

	var space_position := Vector2.ZERO
	var space_zoom := 1.0
	var zoom_visual_strength := 1.0
	var space_rotation := 0.0

	if _space_background_ref != null:
		var v_pos = _space_background_ref.get("space_position")
		if v_pos is Vector2:
			space_position = v_pos

		var v_zoom = _space_background_ref.get("space_zoom")
		if v_zoom != null:
			space_zoom = float(v_zoom)

		var v_zoom_strength = _space_background_ref.get("zoom_visual_strength")
		if v_zoom_strength != null:
			zoom_visual_strength = float(v_zoom_strength)

		var v_rot = _space_background_ref.get("space_rotation")
		if v_rot != null:
			space_rotation = float(v_rot)

	var unchanged := not force
	unchanged = unchanged and space_position == _last_space_position
	unchanged = unchanged and is_equal_approx(space_zoom, _last_space_zoom)
	unchanged = unchanged and is_equal_approx(zoom_visual_strength, _last_zoom_visual_strength)
	unchanged = unchanged and is_equal_approx(space_rotation, _last_space_rotation)
	unchanged = unchanged and planet_space_position == _last_planet_space_position
	unchanged = unchanged and _planet_intro_offset == _last_intro_offset
	unchanged = unchanged and is_equal_approx(_planet_intro_scale, _last_intro_scale)
	unchanged = unchanged and is_equal_approx(planet_space_scale_multiplier, _last_planet_scale_multiplier)

	if unchanged:
		return

	_last_space_position = space_position
	_last_space_zoom = space_zoom
	_last_zoom_visual_strength = zoom_visual_strength
	_last_space_rotation = space_rotation
	_last_planet_space_position = planet_space_position
	_last_intro_offset = _planet_intro_offset
	_last_intro_scale = _planet_intro_scale
	_last_planet_scale_multiplier = planet_space_scale_multiplier

	var visual_zoom: float = lerp(1.0, space_zoom, zoom_visual_strength)

	var local := planet_space_position - space_position

	var cosr := cos(space_rotation)
	var sinr := sin(space_rotation)

	var rx := local.x * cosr - local.y * sinr
	var ry := local.x * sinr + local.y * cosr

	var screen_pos: Vector2 = _viewport_center + Vector2(rx, ry) * visual_zoom
	var rotated_intro_offset := _planet_intro_offset.rotated(space_rotation)
	var total_scale: float = visual_zoom * planet_space_scale_multiplier * _planet_intro_scale

	var final_position := screen_pos + rotated_intro_offset

	if final_position != _last_applied_position:
		planet_preview.position = final_position
		_last_applied_position = final_position

	if not is_equal_approx(total_scale, _last_applied_scale):
		planet_preview.scale = Vector2.ONE * total_scale
		_last_applied_scale = total_scale

	if not is_equal_approx(space_rotation, _last_applied_rotation):
		planet_preview.rotation = space_rotation
		_last_applied_rotation = space_rotation


func _normalize_planet_name(value: String) -> String:
	var key := value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")

	match key:
		"island", "islands":
			return "islands"
		"earth", "terra", "land", "land_masses":
			return "earth"
		"river", "rivers", "earth_rivers":
			return "rivers"
		"mars", "dry", "dry_terran", "desert":
			return "dry_terran"
		"ice", "ice_world", "uranus", "neptune":
			return "ice_world"
		"moon", "luna", "no_atmosphere", "mercury":
			return "moon"
		"lava", "lava_world":
			return "lava_world"
		"gas", "gas_planet", "jupiter":
			return "gas_planet"
		"saturn", "ringed", "ringed_gas_planet", "gas_layers":
			return "ringed_gas_planet"
		"sun", "star":
			return "star"
		"black_hole":
			return "black_hole"
		"galaxy":
			return "galaxy"
		_:
			return "islands"


func _set_apollo_enabled(enabled: bool) -> void:
	apollo_enabled = enabled

	if has_node("/root/UnilearnUserSettings"):
		get_node("/root/UnilearnUserSettings").set_apollo_enabled(enabled)

	if is_instance_valid(bottom_menu):
		bottom_menu.apollo_enabled = enabled

	if is_instance_valid(ai_assistant):
		if ai_assistant.has_method("set_apollo_button_enabled"):
			ai_assistant.call("set_apollo_button_enabled", enabled)
		else:
			if enabled and ai_assistant.has_method("start"):
				ai_assistant.call("start")
			elif not enabled and ai_assistant.has_method("stop"):
				ai_assistant.call("stop")

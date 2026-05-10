extends Control

const LOGIN_SCENE := "res://app/auth/LoginScreen.tscn"
const PIXEL_PLANET_SCRIPT := preload("res://addons/UnilearnLib/nodes/UnilearnPixelPlanet2D.gd")
const BOTTOM_MENU_SCRIPT := preload("res://app/ui/UnilearnBottomMenu.gd")

@onready var ai_assistant: Node = get_node_or_null("AIAssistant")

var _ai_overlay_layer: CanvasLayer = null
var blocked_touch_indices: Dictionary = {}

var sfx_enabled: bool = true
var apollo_enabled: bool = true
var reduce_motion_enabled: bool = false

# --- Background freeze state ---
var _background_frozen: bool = false
var _saved_navigation_enabled: bool = false
var _saved_planet_turning_speed: float = 0.0

# --- Cached references ---
var _space_background_ref: Node = null
var _viewport_center: Vector2 = Vector2.ZERO

# --- Bottom menu ---
var bottom_menu: UnilearnBottomMenu = null

# --- Planet preview state ---
var planet_preview: Node2D

var planet_space_position: Vector2 = Vector2.ZERO
var planet_space_scale_multiplier: float = 1.0

var planet_archetype_name: String = "star"
var planet_radius_px: int = 150
var planet_pixels: int = 400
var planet_seed: int = 1006

var planet_turning_speed: float = 0.65
var planet_axial_tilt_deg: float = 18.0

var planet_debug_border_enabled: bool = true
var planet_use_custom_colors: bool = true
var planet_custom_colors: PackedColorArray = PackedColorArray([
	Color("#e8d29b"),
	Color("#c9a66b"),
	Color("#8d6d44"),
	Color("#f3e4bc"),
	Color("#6d5437"),
	Color("#d6bd82"),
])

# Pick-up feel.
var planet_drag_scale_multiplier: float = 0.94
var planet_drag_scale_time: float = 0.12

# SFX behavior.
# Quick tap = click.
# Hold/drag = open on pickup, close on release.
var planet_pick_sfx_id: String = "click"
var planet_release_sfx_id: String = "click"
var planet_hold_pick_sfx_id: String = "open"
var planet_hold_release_sfx_id: String = "close"
var planet_hold_threshold: float = 0.22
var planet_tap_move_threshold: float = 12.0

var _dragging_planet: bool = false
var _drag_pointer_id: int = -1
var _drag_space_offset: Vector2 = Vector2.ZERO
var _drag_start_time_msec: int = 0
var _drag_start_screen_position: Vector2 = Vector2.ZERO
var _drag_moved_distance: float = 0.0
var _drag_started_as_hold: bool = false

var _planet_drag_visual_scale: float = 1.0
var _planet_drag_scale_tween: Tween = null

var _planet_intro_offset: Vector2 = Vector2.ZERO
var _planet_intro_scale: float = 1.0

# --- Transform cache ---
var _last_space_position: Vector2 = Vector2(INF, INF)
var _last_space_zoom: float = INF
var _last_zoom_visual_strength: float = INF
var _last_space_rotation: float = INF
var _last_planet_space_position: Vector2 = Vector2(INF, INF)
var _last_intro_offset: Vector2 = Vector2(INF, INF)
var _last_intro_scale: float = INF
var _last_planet_scale_multiplier: float = INF
var _last_drag_visual_scale: float = INF
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
	if _background_frozen:
		return

	_update_space_locked_planet(false)


func _input(event: InputEvent) -> void:
	if _background_frozen:
		return

	if _handle_planet_drag_input(event):
		return

	if _space_background_ref == null:
		return

	if _space_background_ref.get("navigation_enabled") != true:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if _is_position_over_blocking_ui(event.position):
				blocked_touch_indices[event.index] = true
				return

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

	elif event is InputEventMouseButton or event is InputEventMouseMotion:
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

		"cards", "popup_cards_opened":
			_set_background_frozen(true)

		"cards_closed", "popup_cards_closed":
			_set_background_frozen(false)

		"achievements":
			print("Open achievements")

		"playgrounds":
			print("Open universe playgrounds")

		"settings", "popup_settings_opened":
			_set_background_frozen(true)

		"settings_closed", "popup_settings_closed":
			_set_background_frozen(false)

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


func _set_background_frozen(frozen: bool) -> void:
	if _background_frozen == frozen:
		return

	_background_frozen = frozen
	blocked_touch_indices.clear()

	if frozen:
		if _space_background_ref != null:
			var nav_value = _space_background_ref.get("navigation_enabled")
			if nav_value != null:
				_saved_navigation_enabled = bool(nav_value)

			if _space_background_ref.has_method("set_navigation_enabled"):
				_space_background_ref.call("set_navigation_enabled", false)

			if _space_background_ref.has_method("set_background_paused"):
				_space_background_ref.call("set_background_paused", true)
			else:
				_space_background_ref.set_process(false)

		if is_instance_valid(planet_preview):
			_saved_planet_turning_speed = planet_turning_speed
			planet_preview.set("turning_speed", 0.0)
			planet_preview.set_process(false)

		if _planet_drag_scale_tween != null:
			_planet_drag_scale_tween.kill()

		_dragging_planet = false
		_drag_pointer_id = -1
		_drag_space_offset = Vector2.ZERO
		_planet_drag_visual_scale = 1.0
		_force_planet_transform_update()
		return

	if _space_background_ref != null:
		if _space_background_ref.has_method("set_background_paused"):
			_space_background_ref.call("set_background_paused", false)
		else:
			_space_background_ref.set_process(true)

		if _space_background_ref.has_method("set_navigation_enabled"):
			_space_background_ref.call("set_navigation_enabled", _saved_navigation_enabled)

	if is_instance_valid(planet_preview):
		planet_preview.set_process(true)
		planet_preview.set("turning_speed", _saved_planet_turning_speed)

	_force_planet_transform_update()


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
	_set_background_frozen(false)

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

	_apply_default_planet_preset()
	_force_planet_transform_update()


func _apply_default_planet_preset() -> void:
	if not is_instance_valid(planet_preview):
		return

	planet_preview.set("preset", _normalize_planet_name(planet_archetype_name))
	planet_preview.set("radius_px", planet_radius_px)
	planet_preview.set("render_pixels", planet_pixels)
	planet_preview.set("seed_value", planet_seed)
	planet_preview.set("turning_speed", planet_turning_speed)
	planet_preview.set("axial_tilt_deg", planet_axial_tilt_deg)
	planet_preview.set("debug_border_enabled", planet_debug_border_enabled)
	planet_preview.set("draggable", false)
	planet_preview.set("use_custom_colors", planet_use_custom_colors)
	planet_preview.set("custom_colors", planet_custom_colors)

	if planet_preview.has_method("rebuild"):
		planet_preview.call("rebuild")


func _setup_ai_assistant() -> void:
	if not is_instance_valid(ai_assistant):
		return

	_ensure_ai_overlay_layer()

	ai_assistant.process_mode = Node.PROCESS_MODE_ALWAYS

	if ai_assistant.get_parent() != _ai_overlay_layer:
		ai_assistant.reparent(_ai_overlay_layer, true)

	if ai_assistant is CanvasItem:
		var item := ai_assistant as CanvasItem
		item.z_index = 100
		item.z_as_relative = false

	_ai_overlay_layer.layer = 9999

	if AIState.has_method("set_enabled"):
		AIState.set_enabled(apollo_enabled)
	else:
		AIState.enabled = apollo_enabled

	await get_tree().process_frame

	if not is_instance_valid(ai_assistant):
		return

	_ai_overlay_layer.layer = 9999

	if apollo_enabled:
		if ai_assistant.has_method("start"):
			ai_assistant.call("start")
	else:
		if ai_assistant.has_method("stop"):
			ai_assistant.call("stop")


func _ensure_ai_overlay_layer() -> void:
	if is_instance_valid(_ai_overlay_layer):
		_ai_overlay_layer.layer = 9999
		_ai_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		return

	_ai_overlay_layer = CanvasLayer.new()
	_ai_overlay_layer.name = "AIOverlayLayer"
	_ai_overlay_layer.layer = 9999
	_ai_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ai_overlay_layer)


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


func _handle_planet_drag_input(event: InputEvent) -> bool:
	if not is_instance_valid(planet_preview):
		return false

	if event is InputEventScreenTouch:
		if event.pressed:
			if _is_position_over_blocking_ui(event.position):
				return false

			if _is_screen_position_over_planet(event.position):
				_start_planet_drag(event.index, event.position)
				get_viewport().set_input_as_handled()
				return true

		else:
			if _dragging_planet and _drag_pointer_id == event.index:
				_stop_planet_drag()
				get_viewport().set_input_as_handled()
				return true

		return false

	if event is InputEventScreenDrag:
		if _dragging_planet and _drag_pointer_id == event.index:
			_update_planet_drag(event.position)
			get_viewport().set_input_as_handled()
			return true

		return false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _is_position_over_blocking_ui(event.position):
				return false

			if _is_screen_position_over_planet(event.position):
				_start_planet_drag(-99, event.position)
				get_viewport().set_input_as_handled()
				return true

		else:
			if _dragging_planet and _drag_pointer_id == -99:
				_stop_planet_drag()
				get_viewport().set_input_as_handled()
				return true

		return false

	if event is InputEventMouseMotion:
		if _dragging_planet and _drag_pointer_id == -99:
			_update_planet_drag(event.position)
			get_viewport().set_input_as_handled()
			return true

	return false


func _is_screen_position_over_planet(screen_position: Vector2) -> bool:
	if not is_instance_valid(planet_preview):
		return false

	if planet_preview.has_method("contains_screen_point"):
		return planet_preview.call("contains_screen_point", screen_position)

	return planet_preview.global_position.distance_to(screen_position) <= float(planet_radius_px) * planet_preview.global_scale.x


func _start_planet_drag(pointer_id: int, screen_position: Vector2) -> void:
	_dragging_planet = true
	_drag_pointer_id = pointer_id
	_drag_space_offset = planet_space_position - _screen_to_space_position(screen_position)

	_drag_start_time_msec = Time.get_ticks_msec()
	_drag_start_screen_position = screen_position
	_drag_moved_distance = 0.0
	_drag_started_as_hold = false

	blocked_touch_indices[pointer_id] = true

	_play_planet_sfx(planet_pick_sfx_id)
	_tween_planet_drag_scale(planet_drag_scale_multiplier)

	if is_instance_valid(planet_preview) and planet_preview.has_method("set_debug_border_enabled"):
		planet_preview.call("set_debug_border_enabled", true)


func _update_planet_drag(screen_position: Vector2) -> void:
	_drag_moved_distance = max(
		_drag_moved_distance,
		_drag_start_screen_position.distance_to(screen_position)
	)

	if not _drag_started_as_hold and _is_current_planet_interaction_hold():
		_drag_started_as_hold = true

	planet_space_position = _screen_to_space_position(screen_position) + _drag_space_offset
	_force_planet_transform_update()


func _stop_planet_drag() -> void:
	var was_hold := _drag_started_as_hold or _is_current_planet_interaction_hold()

	blocked_touch_indices.erase(_drag_pointer_id)

	_dragging_planet = false
	_drag_pointer_id = -1
	_drag_space_offset = Vector2.ZERO

	if was_hold:
		_play_planet_sfx(planet_release_sfx_id)

	_drag_start_time_msec = 0
	_drag_start_screen_position = Vector2.ZERO
	_drag_moved_distance = 0.0
	_drag_started_as_hold = false

	_tween_planet_drag_scale(1.0)


func _tween_planet_drag_scale(target_scale: float) -> void:
	if reduce_motion_enabled:
		_planet_drag_visual_scale = target_scale
		_force_planet_transform_update()
		return

	if _planet_drag_scale_tween != null:
		_planet_drag_scale_tween.kill()

	_planet_drag_scale_tween = create_tween()
	_planet_drag_scale_tween.set_trans(Tween.TRANS_BACK)
	_planet_drag_scale_tween.set_ease(Tween.EASE_OUT)
	_planet_drag_scale_tween.tween_method(
		func(v: float) -> void:
			_planet_drag_visual_scale = v
			_update_space_locked_planet(true),
		_planet_drag_visual_scale,
		target_scale,
		planet_drag_scale_time
	)


func _play_planet_sfx(sfx_id: String) -> void:
	if not sfx_enabled:
		return

	var sfx := get_node_or_null("/root/UnilearnSFX")
	if sfx == null:
		return

	if sfx.has_method("play"):
		sfx.call("play", sfx_id)


func _is_current_planet_interaction_hold() -> bool:
	if _drag_start_time_msec <= 0:
		return false

	var held_seconds := float(Time.get_ticks_msec() - _drag_start_time_msec) / 1000.0
	return held_seconds >= planet_hold_threshold or _drag_moved_distance >= planet_tap_move_threshold


func _screen_to_space_position(screen_position: Vector2) -> Vector2:
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

	var visual_zoom: float = max(0.001, lerp(1.0, space_zoom, zoom_visual_strength))
	var rotated_intro_offset := _planet_intro_offset.rotated(space_rotation)
	var screen_local := (screen_position - _viewport_center - rotated_intro_offset) / visual_zoom
	var unrotated := screen_local.rotated(-space_rotation)

	return space_position + unrotated


func _force_planet_transform_update() -> void:
	_last_space_position = Vector2(INF, INF)
	_last_space_zoom = INF
	_last_zoom_visual_strength = INF
	_last_space_rotation = INF
	_last_planet_space_position = Vector2(INF, INF)
	_last_intro_offset = Vector2(INF, INF)
	_last_intro_scale = INF
	_last_planet_scale_multiplier = INF
	_last_drag_visual_scale = INF

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
	unchanged = unchanged and is_equal_approx(_planet_drag_visual_scale, _last_drag_visual_scale)

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
	_last_drag_visual_scale = _planet_drag_visual_scale

	var visual_zoom: float = lerp(1.0, space_zoom, zoom_visual_strength)
	var local := planet_space_position - space_position

	var cosr := cos(space_rotation)
	var sinr := sin(space_rotation)

	var rx := local.x * cosr - local.y * sinr
	var ry := local.x * sinr + local.y * cosr

	var screen_pos: Vector2 = _viewport_center + Vector2(rx, ry) * visual_zoom
	var rotated_intro_offset := _planet_intro_offset.rotated(space_rotation)
	var total_scale: float = visual_zoom * planet_space_scale_multiplier * _planet_intro_scale * _planet_drag_visual_scale
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


func set_planet_turning_speed(value: float) -> void:
	planet_turning_speed = value

	if is_instance_valid(planet_preview):
		planet_preview.set("turning_speed", planet_turning_speed)


func set_planet_axial_tilt_deg(value: float) -> void:
	planet_axial_tilt_deg = value

	if is_instance_valid(planet_preview):
		planet_preview.set("axial_tilt_deg", planet_axial_tilt_deg)


func _normalize_planet_name(value: String) -> String:
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


func _set_space_navigation_enabled(enabled: bool) -> void:
	if _background_frozen:
		return

	if _space_background_ref != null and _space_background_ref.has_method("set_navigation_enabled"):
		_space_background_ref.call("set_navigation_enabled", enabled)

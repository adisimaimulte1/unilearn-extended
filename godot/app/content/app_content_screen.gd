extends Control

const LOGIN_SCENE := "res://app/auth/LoginScreen.tscn"
const SPLASH_SCENE := "res://app/splash/SplashScreen.tscn"
const BOTTOM_MENU_SCRIPT := preload("res://app/ui/UnilearnBottomMenu.gd")
const UNIVERSE_PLAYGROUND_SCRIPT := preload("res://app/playground/UniversePlayground.gd")
const UNILEARN_MUSIC_SCRIPT := preload("res://app/audio/UnilearnMusic.gd")
const TUTORIAL_CONTROLLER_SCRIPT := preload("res://app/tutorial/UnilearnTutorialController.gd")

@onready var ai_assistant: Node = get_node_or_null("AIAssistant")

var _ai_overlay_layer: CanvasLayer = null
var blocked_touch_indices: Dictionary = {}
var planet_touch_indices: Dictionary = {}

var _galaxy_restore_done: bool = false
var _galaxy_state_node: Node = null

var music_enabled: bool = true
var sfx_enabled: bool = true
var apollo_enabled: bool = false
var reduce_motion_enabled: bool = false

var _background_frozen: bool = false
var _app_runtime_paused_by_os: bool = false
var _app_runtime_pause_froze_scene: bool = false
var _app_runtime_pause_paused_ai: bool = false
var _app_runtime_resume_token: int = 0
var _startup_scene_release_token: int = 0
var _saved_navigation_enabled: bool = false
var _universe_end_interface_lock_pending: bool = false
var _universe_end_interface_locked: bool = false
var _universe_end_interface_exit_running: bool = false
var _apollo_permission_flow_running: bool = false
var _universe_end_saved_navigation_enabled: bool = false

const UNIVERSE_END_CAMERA_START_DELAY := 0.04
const UNIVERSE_END_MUSIC_FADE_SECONDS := 8.0
const APP_RUNTIME_RESUME_DELAY_SEC := 1.12
const APP_STARTUP_SCENE_RELEASE_DELAY_SEC := 0.72

var _space_background_ref: Node = null
var _music_node: Node = null
var _viewport_center: Vector2 = Vector2.ZERO

var bottom_menu: UnilearnBottomMenu = null
var _tutorial_controller: CanvasLayer = null

var universe_playground: Node = null
var _planet_popup_scan_pending: bool = false
var _connected_planet_popups: Dictionary = {}

var _fps_layer: CanvasLayer = null
var _fps_label: Label = null
var _fps_update_accum: float = 0.0
var _fps_visible: bool = false

var _main_scene_intro_started: bool = false
var _bottom_menu_intro_done: bool = false
var _ai_intro_done: bool = false
var _planets_intro_done: bool = false

const MAIN_INTRO_PLANET_DELAY := 0.16
const MAIN_INTRO_START_DELAY_SEC := 0.3
const LOGOUT_FADE_DURATION := 0.50
const LOGOUT_UI_EXIT_DURATION := 0.78
const LOGOUT_PLANET_FADE_DURATION := 0.74

var _logout_transition_layer: CanvasLayer = null
var _logout_transition_rect: ColorRect = null

var _achievement_toast_layer: CanvasLayer = null
var _achievement_toast_panel: PanelContainer = null
var _achievement_toast_title_label: Label = null
var _achievement_toast_name_label: Label = null
var _achievement_toast_category_label: Label = null
var _achievement_toast_icon: Control = null
var _achievement_toast_icon_texture_rect: TextureRect = null
var _achievement_toast_icon_shader: Shader = null
var _achievement_toast_icon_material_cache: Dictionary = {}
var _achievement_toast_category_key: String = "achievement_total"
var _achievement_toast_is_rare: bool = false
var _achievement_toast_queue: Array[Dictionary] = []
var _achievement_toast_running: bool = false
var _achievement_toast_tween: Tween = null
var _achievement_tracker_connected_id: int = 0
var _achievement_toast_settings_connected_id: int = 0

const ACHIEVEMENT_TOAST_WIDTH := 790.0
const ACHIEVEMENT_TOAST_HEIGHT := 188.0
const ACHIEVEMENT_TOAST_TOP_MARGIN := 320.0
const ACHIEVEMENT_TOAST_RIGHT_MARGIN := 34.0
const ACHIEVEMENT_TOAST_IN_TIME := 0.58
const ACHIEVEMENT_TOAST_NORMAL_HOLD_TIME := 2.0
const ACHIEVEMENT_TOAST_RARE_HOLD_TIME := 4.0
const ACHIEVEMENT_TOAST_OUT_TIME := 0.46
const ACHIEVEMENT_TOAST_ICON_SIZE := 132.0


func _ready() -> void:
	# Scrollbar tracks normally page-jump when tapped above/below the thumb.
	# The app uses touch/wheel/content dragging instead, so make every current and
	# future scrollbar display-only and remove that accidental teleport globally.
	if not get_tree().node_added.is_connected(_on_global_node_added):
		get_tree().node_added.connect(_on_global_node_added)
	_disable_scrollbar_track_input(self)

	call_deferred("_make_buttons_dry", self)
	_full_rect(self)
	_ensure_music_manager()
	_load_local_settings()
	_start_music_if_enabled()

	RenderingServer.set_default_clear_color(Color("#050712"))

	_cache_viewport()
	_cache_space_background()
	_setup_space_background()

	_setup_bottom_menu()
	_setup_achievement_toast()
	_prime_main_scene_intro_visuals()

	# Finish AI overlay/dot setup before the shared interface entrance starts.
	# Planet restoration happens later and must never delay only the AI half.
	await _setup_ai_assistant()

	_prepare_first_frame_layout()

	if not reduce_motion_enabled:
		await get_tree().create_timer(MAIN_INTRO_START_DELAY_SEC).timeout

	_animate_in()

	call_deferred("_finish_startup_deferred")


func _finish_startup_deferred() -> void:
	await get_tree().process_frame

	_setup_universe_playground()
	await _restore_saved_galaxy_bodies()

	await get_tree().process_frame

	_setup_fps_counter()
	_connect_achievement_tracker()

	await get_tree().process_frame

	if not child_entered_tree.is_connected(_on_any_child_entered_tree):
		child_entered_tree.connect(_on_any_child_entered_tree)

	_scan_and_connect_planet_card_popups()
	_setup_first_account_tutorial()


func _setup_first_account_tutorial() -> void:
	var settings := get_node_or_null("/root/UnilearnUserSettings")
	if settings == null or not settings.has_method("should_offer_tutorial_for_current_account"):
		return
	if not bool(settings.call("should_offer_tutorial_for_current_account")):
		return
	if is_instance_valid(_tutorial_controller):
		return
	_tutorial_controller = TUTORIAL_CONTROLLER_SCRIPT.new()
	_tutorial_controller.name = "UnilearnTutorialController"
	add_child(_tutorial_controller)
	if _tutorial_controller.has_method("setup"):
		_tutorial_controller.call("setup", self, bottom_menu, ai_assistant)


func start_tutorial_from_voice_command() -> void:
	AIState.set_command("How to use the app", "actions/tutorial/start")
	AIState.set_state(AIState.State.THINKING)

	if bottom_menu != null and bottom_menu.has_method("simulate_ai_go_home"):
		await bottom_menu.call("simulate_ai_go_home")

	# Navigation animations and popup cleanup must never make the dots leave the
	# requested thinking state before the tutorial audio takes ownership.
	AIState.set_state(AIState.State.THINKING)

	if is_instance_valid(_tutorial_controller):
		if _tutorial_controller.has_method("start_from_voice_command"):
			await _tutorial_controller.call("start_from_voice_command")
		return

	_tutorial_controller = TUTORIAL_CONTROLLER_SCRIPT.new()
	_tutorial_controller.name = "UnilearnTutorialController"
	add_child(_tutorial_controller)
	if _tutorial_controller.has_method("setup_for_voice_command"):
		_tutorial_controller.call("setup_for_voice_command", self, bottom_menu, ai_assistant)
	if is_instance_valid(_tutorial_controller):
		await _tutorial_controller.tree_exited
	_tutorial_controller = null


func _process(delta: float) -> void:
	_update_fps_counter(delta)
	if _universe_end_interface_lock_pending:
		_try_start_universe_end_interface_lock()


func _setup_fps_counter() -> void:
	if is_instance_valid(_fps_layer):
		return

	_fps_layer = CanvasLayer.new()
	_fps_layer.name = "FPSCounterLayer"
	_fps_layer.layer = 10000
	_fps_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_fps_layer)

	_fps_label = Label.new()
	_fps_label.name = "FPSCounterLabel"
	_fps_label.text = "FPS: --"
	_fps_label.visible = _fps_visible
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.z_index = 999

	_fps_label.anchor_left = 0.0
	_fps_label.anchor_top = 0.0
	_fps_label.anchor_right = 0.0
	_fps_label.anchor_bottom = 0.0
	_fps_label.offset_left = 22.0
	_fps_label.offset_top = 46.0
	_fps_label.offset_right = 260.0
	_fps_label.offset_bottom = 100.0

	_fps_label.add_theme_font_size_override("font_size", 34)
	_fps_label.add_theme_color_override("font_color", Color.WHITE)
	_fps_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_fps_label.add_theme_constant_override("shadow_offset_x", 2)
	_fps_label.add_theme_constant_override("shadow_offset_y", 2)

	_fps_layer.add_child(_fps_label)


func _update_fps_counter(delta: float) -> void:
	if not is_instance_valid(_fps_label):
		return

	_fps_update_accum += delta

	if _fps_update_accum < 0.25:
		return

	_fps_update_accum = 0.0

	var fps := Engine.get_frames_per_second()
	_fps_label.text = "FPS: %d" % int(round(fps))


func set_fps_counter_visible(visible: bool) -> void:
	_fps_visible = visible

	if is_instance_valid(_fps_label):
		_fps_label.visible = visible


func _prepare_first_frame_layout() -> void:
	_cache_viewport()

	if is_instance_valid(bottom_menu):
		if bottom_menu.has_method("_layout"):
			bottom_menu.call("_layout")

		if bottom_menu.has_method("_apply_progress"):
			bottom_menu.call("_apply_progress", 0.0)

		bottom_menu.visible = true


func _prime_main_scene_intro_visuals() -> void:
	if reduce_motion_enabled:
		return

	if is_instance_valid(bottom_menu):
		bottom_menu.visible = true
		if bottom_menu.has_method("prepare_entry_animation"):
			bottom_menu.call("prepare_entry_animation")

	if is_instance_valid(ai_assistant):
		if ai_assistant.has_method("prepare_entry_animation"):
			ai_assistant.call("prepare_entry_animation")
		elif ai_assistant is CanvasItem:
			var ai_item := ai_assistant as CanvasItem
			ai_item.modulate.a = 0.0


func _setup_achievement_toast() -> void:
	if is_instance_valid(_achievement_toast_layer):
		_connect_achievement_tracker()
		_connect_achievement_toast_settings_signal()
		return

	_achievement_toast_layer = CanvasLayer.new()
	_achievement_toast_layer.name = "AchievementToastLayer"
	_achievement_toast_layer.layer = 10050
	_achievement_toast_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_achievement_toast_layer)

	var root := Control.new()
	root.name = "AchievementToastRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_achievement_toast_layer.add_child(root)

	_achievement_toast_panel = PanelContainer.new()
	_achievement_toast_panel.name = "AchievementUnlockedToast"
	_achievement_toast_panel.visible = false
	_achievement_toast_panel.modulate.a = 0.0
	_achievement_toast_panel.custom_minimum_size = Vector2(ACHIEVEMENT_TOAST_WIDTH, ACHIEVEMENT_TOAST_HEIGHT)
	_achievement_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_achievement_toast_panel.add_theme_stylebox_override("panel", _achievement_toast_panel_style())
	root.add_child(_achievement_toast_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_achievement_toast_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	margin.add_child(row)

	_achievement_toast_icon = _create_achievement_toast_icon()
	row.add_child(_achievement_toast_icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)

	_achievement_toast_title_label = Label.new()
	_achievement_toast_title_label.text = "ACHIEVEMENT UNLOCKED!"
	_achievement_toast_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_achievement_toast_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_achievement_toast_title_label.add_theme_font_size_override("font_size", 31)
	_achievement_toast_title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.80))
	_apply_toast_font(_achievement_toast_title_label)
	text_box.add_child(_achievement_toast_title_label)

	_achievement_toast_name_label = Label.new()
	_achievement_toast_name_label.text = "Achievement"
	_achievement_toast_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_achievement_toast_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_achievement_toast_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_achievement_toast_name_label.clip_text = true
	_achievement_toast_name_label.add_theme_font_size_override("font_size", 52)
	_achievement_toast_name_label.add_theme_color_override("font_color", Color.WHITE)
	_apply_toast_font(_achievement_toast_name_label)
	text_box.add_child(_achievement_toast_name_label)

	_achievement_toast_category_label = Label.new()
	_achievement_toast_category_label.text = "UNILEARN"
	_achievement_toast_category_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_achievement_toast_category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_achievement_toast_category_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_achievement_toast_category_label.clip_text = true
	_achievement_toast_category_label.add_theme_font_size_override("font_size", 27)
	_achievement_toast_category_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.62))
	_apply_toast_font(_achievement_toast_category_label)
	text_box.add_child(_achievement_toast_category_label)

	_layout_achievement_toast(true)
	_connect_achievement_tracker()
	_connect_achievement_toast_settings_signal()



func _connect_achievement_toast_settings_signal() -> void:
	var settings := get_node_or_null("/root/UnilearnUserSettings")
	if settings == null:
		return
	var settings_id := int(settings.get_instance_id())
	if _achievement_toast_settings_connected_id == settings_id:
		return
	if not settings.has_signal("settings_changed"):
		return
	var callable := Callable(self, "_on_achievement_toast_settings_changed")
	if not settings.is_connected("settings_changed", callable):
		settings.connect("settings_changed", callable)
	_achievement_toast_settings_connected_id = settings_id


func _on_achievement_toast_settings_changed() -> void:
	# Live theme refresh only. Do not rebuild the toast and do not touch its
	# position/modulate/tween, otherwise active entry/exit animations restart.
	_update_achievement_toast_theme_colors()


func _update_achievement_toast_theme_colors() -> void:
	if not is_instance_valid(_achievement_toast_panel):
		return
	_achievement_toast_panel.add_theme_stylebox_override("panel", _achievement_toast_panel_style())
	if is_instance_valid(_achievement_toast_title_label):
		_achievement_toast_title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.80))
	if is_instance_valid(_achievement_toast_name_label):
		_achievement_toast_name_label.add_theme_color_override("font_color", _get_toast_accent_color())
	if is_instance_valid(_achievement_toast_category_label):
		_achievement_toast_category_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.62))
	_update_achievement_toast_icon_visual()

func _connect_achievement_tracker() -> void:
	var tracker := get_node_or_null("/root/UnilearnAchievements")
	if tracker == null:
		tracker = get_node_or_null("/root/UnilearnAchievementTracker")
	if tracker == null:
		tracker = get_node_or_null("/root/AchievementTracker")
	if tracker == null:
		return

	var tracker_id := int(tracker.get_instance_id())
	if _achievement_tracker_connected_id == tracker_id:
		return

	if tracker.has_signal("achievement_unlocked"):
		var callable := Callable(self, "_on_achievement_unlocked")
		if not tracker.is_connected("achievement_unlocked", callable):
			tracker.connect("achievement_unlocked", callable)
		_achievement_tracker_connected_id = tracker_id


func _get_music_node() -> Node:
	if _music_node != null and is_instance_valid(_music_node):
		return _music_node
	_music_node = get_node_or_null("/root/UnilearnMusic")
	return _music_node


func _duck_music_for_achievement_queue() -> void:
	var music := _get_music_node()
	if music != null and music.has_method("duck_for_achievement"):
		music.call("duck_for_achievement")


func _release_music_for_achievement_queue() -> void:
	var music := _get_music_node()
	if music != null and music.has_method("release_achievement_duck"):
		music.call("release_achievement_duck")


func _stop_music_for_universe_end_lock() -> void:
	# Keep background music playing during the death dance.
	# The music is faded/paused only when the actual universe-end collision starts.
	pass


func _on_achievement_unlocked(achievement: Dictionary) -> void:
	if achievement.is_empty():
		return

	var should_start_queue := not _achievement_toast_running and _achievement_toast_queue.is_empty()
	_achievement_toast_queue.append(achievement.duplicate(true))

	if should_start_queue:
		_duck_music_for_achievement_queue()

	if not _achievement_toast_running:
		_show_next_achievement_toast()


func _show_next_achievement_toast() -> void:
	if _achievement_toast_running:
		return
	if _achievement_toast_queue.is_empty():
		return
	if not is_instance_valid(_achievement_toast_panel):
		return

	_achievement_toast_running = true
	var achievement: Dictionary = _achievement_toast_queue.pop_front()

	var title := str(achievement.get("title", "Achievement"))
	var category_key := str(achievement.get("category", "achievement_total"))
	var rarity := str(achievement.get("rarity", "normal")).strip_edges().to_lower()
	_achievement_toast_is_rare = rarity == "rare"
	var subtitle := str(achievement.get("description", ""))
	if subtitle.strip_edges().is_empty():
		subtitle = str(achievement.get("category_label", "Achievement"))

	if is_instance_valid(_achievement_toast_name_label):
		_achievement_toast_name_label.text = title
		_achievement_toast_name_label.add_theme_color_override("font_color", _get_toast_accent_color())
	if is_instance_valid(_achievement_toast_category_label):
		_achievement_toast_category_label.text = subtitle
		_achievement_toast_category_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.62))

	_achievement_toast_category_key = category_key
	_layout_achievement_toast(true)
	_achievement_toast_panel.visible = true
	_achievement_toast_panel.modulate.a = 0.0
	_achievement_toast_panel.scale = Vector2(0.982, 0.982)

	_update_achievement_toast_icon_visual()

	if reduce_motion_enabled:
		_achievement_toast_panel.modulate.a = 1.0
		_achievement_toast_panel.position = _achievement_toast_in_position()
		_play_achievement_unlock_sfx(achievement)
		await get_tree().create_timer(_achievement_toast_hold_time(achievement)).timeout
		_achievement_toast_panel.visible = false
		_achievement_toast_running = false
		if _achievement_toast_queue.is_empty():
			_release_music_for_achievement_queue()
		else:
			_show_next_achievement_toast()
		return

	if _achievement_toast_tween != null and _achievement_toast_tween.is_valid():
		_achievement_toast_tween.kill()

	var in_position := _achievement_toast_in_position()
	var out_position := _achievement_toast_out_position()
	_achievement_toast_panel.position = out_position

	_achievement_toast_tween = create_tween()
	_achievement_toast_tween.set_trans(Tween.TRANS_CUBIC)
	_achievement_toast_tween.set_ease(Tween.EASE_OUT)
	_play_achievement_unlock_sfx(achievement)
	_achievement_toast_tween.tween_property(_achievement_toast_panel, "position", in_position, ACHIEVEMENT_TOAST_IN_TIME)
	_achievement_toast_tween.parallel().tween_property(_achievement_toast_panel, "scale", Vector2.ONE, ACHIEVEMENT_TOAST_IN_TIME)
	_achievement_toast_tween.parallel().tween_property(_achievement_toast_panel, "modulate:a", 1.0, 0.30)
	_achievement_toast_tween.tween_interval(_achievement_toast_hold_time(achievement))
	_achievement_toast_tween.set_trans(Tween.TRANS_CUBIC)
	_achievement_toast_tween.set_ease(Tween.EASE_IN)
	_achievement_toast_tween.tween_property(_achievement_toast_panel, "position", out_position, ACHIEVEMENT_TOAST_OUT_TIME)
	_achievement_toast_tween.parallel().tween_property(_achievement_toast_panel, "modulate:a", 0.0, ACHIEVEMENT_TOAST_OUT_TIME)
	await _achievement_toast_tween.finished

	if is_instance_valid(_achievement_toast_panel):
		_achievement_toast_panel.visible = false
		_achievement_toast_panel.scale = Vector2.ONE

	_achievement_toast_running = false
	if _achievement_toast_queue.is_empty():
		_release_music_for_achievement_queue()
	else:
		_show_next_achievement_toast()


func _achievement_toast_hold_time(achievement: Dictionary = {}) -> float:
	var rarity := str(achievement.get("rarity", "normal")).strip_edges().to_lower()
	return ACHIEVEMENT_TOAST_RARE_HOLD_TIME if rarity == "rare" else ACHIEVEMENT_TOAST_NORMAL_HOLD_TIME


func _layout_achievement_toast(offscreen: bool = false) -> void:
	if not is_instance_valid(_achievement_toast_panel):
		return

	var viewport_size := get_viewport_rect().size
	var width: float = min(ACHIEVEMENT_TOAST_WIDTH, max(viewport_size.x - 38.0, 280.0))
	var height := ACHIEVEMENT_TOAST_HEIGHT
	_achievement_toast_panel.size = Vector2(width, height)
	_achievement_toast_panel.custom_minimum_size = _achievement_toast_panel.size
	_achievement_toast_panel.pivot_offset = Vector2(width * 0.5, height * 0.5)
	_achievement_toast_panel.position = _achievement_toast_out_position() if offscreen else _achievement_toast_in_position()
	_layout_achievement_toast_icon_texture()


func _achievement_toast_in_position() -> Vector2:
	var viewport_size := get_viewport_rect().size
	var width: float = min(ACHIEVEMENT_TOAST_WIDTH, max(viewport_size.x - 38.0, 280.0))
	var x: float = max(19.0, viewport_size.x - width - ACHIEVEMENT_TOAST_RIGHT_MARGIN)
	var y: float = ACHIEVEMENT_TOAST_TOP_MARGIN
	return Vector2(x, y)


func _achievement_toast_out_position() -> Vector2:
	var in_position := _achievement_toast_in_position()
	var viewport_size := get_viewport_rect().size
	return Vector2(viewport_size.x + 26.0, in_position.y)


func _achievement_toast_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.005, 0.007, 0.012, 0.88)
	style.border_color = Color(1.0, 1.0, 1.0, 0.92)
	style.set_border_width_all(5)
	style.set_corner_radius_all(28)
	style.shadow_color = Color(0, 0, 0, 0.62)
	style.shadow_size = 24
	style.shadow_offset = Vector2(0, 10)
	return style


func _create_achievement_toast_icon() -> Control:
	var icon := Control.new()
	icon.name = "AchievementToastIcon"
	icon.custom_minimum_size = Vector2(ACHIEVEMENT_TOAST_ICON_SIZE, ACHIEVEMENT_TOAST_ICON_SIZE)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		var side: float = min(icon.size.x, icon.size.y)
		var center := icon.size * 0.5
		var radius := side * 0.465
		var accent := _get_toast_accent_color()
		var category := _achievement_toast_category_key.strip_edges()
		if category.is_empty():
			category = "achievement_total"

		icon.draw_arc(center, radius, 0.0, TAU, 144, accent, 6.2, true)

		if _achievement_toast_icon_texture(category) == null:
			_draw_achievement_toast_fallback_icon(icon, center, radius * 0.92, accent)
	)

	_achievement_toast_icon_texture_rect = TextureRect.new()
	_achievement_toast_icon_texture_rect.name = "AchievementToastIconTexture"
	_achievement_toast_icon_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_achievement_toast_icon_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_achievement_toast_icon_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.add_child(_achievement_toast_icon_texture_rect)

	icon.resized.connect(func() -> void:
		_layout_achievement_toast_icon_texture()
	)

	_update_achievement_toast_icon_visual()
	return icon


func _achievement_toast_icon_texture(category: String) -> Texture2D:
	var path := _achievement_toast_icon_path(category)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _update_achievement_toast_icon_visual() -> void:
	if not is_instance_valid(_achievement_toast_icon):
		return

	var category := _achievement_toast_category_key.strip_edges()
	if category.is_empty():
		category = "achievement_total"

	var texture := _achievement_toast_icon_texture(category)
	var accent := _get_toast_accent_color()

	if is_instance_valid(_achievement_toast_icon_texture_rect):
		_achievement_toast_icon_texture_rect.texture = texture
		_achievement_toast_icon_texture_rect.visible = texture != null
		_achievement_toast_icon_texture_rect.material = _make_achievement_toast_icon_tint_material(accent).duplicate(true)

	_layout_achievement_toast_icon_texture()
	_achievement_toast_icon.queue_redraw()


func _layout_achievement_toast_icon_texture() -> void:
	if not is_instance_valid(_achievement_toast_icon) or not is_instance_valid(_achievement_toast_icon_texture_rect):
		return

	var side: float = min(_achievement_toast_icon.size.x, _achievement_toast_icon.size.y)
	if side <= 0.0:
		side = ACHIEVEMENT_TOAST_ICON_SIZE

	var category := _achievement_toast_category_key.strip_edges()
	if category.is_empty():
		category = "achievement_total"

	var icon_size := side * 0.62 * _achievement_toast_icon_scale(category)
	_achievement_toast_icon_texture_rect.size = Vector2(icon_size, icon_size)
	_achievement_toast_icon_texture_rect.custom_minimum_size = _achievement_toast_icon_texture_rect.size
	_achievement_toast_icon_texture_rect.position = (_achievement_toast_icon.size - _achievement_toast_icon_texture_rect.size) * 0.5


func _make_achievement_toast_icon_tint_material(color: Color) -> ShaderMaterial:
	var key := color.to_html(true)
	if _achievement_toast_icon_material_cache.has(key):
		return _achievement_toast_icon_material_cache[key]

	if _achievement_toast_icon_shader == null:
		_achievement_toast_icon_shader = Shader.new()
		_achievement_toast_icon_shader.code = "shader_type canvas_item;\nuniform vec4 tint_color : source_color = vec4(1.0);\nvoid fragment() {\n\tvec4 tex = texture(TEXTURE, UV);\n\tCOLOR = vec4(tint_color.rgb, tint_color.a * tex.a);\n}"

	var material := ShaderMaterial.new()
	material.shader = _achievement_toast_icon_shader
	material.set_shader_parameter("tint_color", color)
	_achievement_toast_icon_material_cache[key] = material
	return material


func _achievement_toast_icon_path(category: String) -> String:
	match category:
		"achievement_total":
			return "res://assets/app/achievements/trophy.png"
		"bronze", "silver", "gold":
			return "res://assets/app/achievements/medal.png"
		"add_body":
			return "res://assets/app/achievements/planet_plus.png"
		"planet_collision":
			return "res://assets/app/achievements/planet_collision.png"
		"sun_collision":
			return "res://assets/app/achievements/star_collision.png"
		"black_hole":
			return "res://assets/app/achievements/black_hole.png"
		"stat_mastery":
			return "res://assets/app/achievements/stats.png"
		"ai_assistant":
			return "res://assets/app/achievements/ai.png"
		"instability":
			return "res://assets/app/achievements/unstable_system.png"
		"type_amount":
			return "res://assets/app/achievements/card.png"
		"fictional_system":
			return "res://assets/app/achievements/fictional.png"
		"franchise_system":
			return "res://assets/app/achievements/real.png"
		_:
			return "res://assets/app/achievements/trophy.png"


func _achievement_toast_icon_scale(category: String) -> float:
	match category:
		"add_body":
			return 0.92
		"planet_collision", "sun_collision", "black_hole", "ai_assistant", "instability":
			return 0.96
		_:
			return 1.0


func _draw_achievement_toast_fallback_icon(icon: Control, center: Vector2, radius: float, accent: Color) -> void:
	var cup := Rect2(center + Vector2(-radius * 0.25, -radius * 0.31), Vector2(radius * 0.50, radius * 0.39))
	icon.draw_rect(cup, accent, false, 5.0)
	icon.draw_arc(center + Vector2(-radius * 0.28, -radius * 0.11), radius * 0.19, PI * 0.5, PI * 1.5, 36, Color.WHITE, 3.8, true)
	icon.draw_arc(center + Vector2(radius * 0.28, -radius * 0.11), radius * 0.19, -PI * 0.5, PI * 0.5, 36, Color.WHITE, 3.8, true)
	icon.draw_line(center + Vector2(0, radius * 0.06), center + Vector2(0, radius * 0.34), accent, 5.2, true)
	icon.draw_line(center + Vector2(-radius * 0.30, radius * 0.36), center + Vector2(radius * 0.30, radius * 0.36), Color.WHITE, 5.2, true)


func _get_toast_accent_color() -> Color:
	if not _achievement_toast_is_rare:
		return Color.WHITE
	var settings := get_node_or_null("/root/UnilearnUserSettings")
	if settings != null:
		if settings.has_method("get_accent_color"):
			var method_color: Variant = settings.call("get_accent_color")
			if method_color is Color:
				return method_color
		if settings.has_method("get_text_highlighted_color"):
			var text_color: Variant = settings.call("get_text_highlighted_color")
			if text_color is Color:
				return text_color
		for property_name in ["text_highlighted_color", "textHighlightedColor", "highlighted_text_color", "highlightedTextColor", "text_highlight_color", "textHighlightColor", "highlight_color", "highlightColor", "accent_color", "accentColor"]:
			var value: Variant = settings.get(property_name)
			if value is Color:
				return value
	return Color("#FFC62D")


func _apply_toast_font(label: Label) -> void:
	if label == null:
		return
	var font_path := "res://assets/fonts/JockeyOne-Regular.ttf"
	if ResourceLoader.exists(font_path):
		var font := load(font_path) as FontFile
		if font != null:
			label.add_theme_font_override("font", font)


func _play_login_success_sfx_if_pending() -> void:
	var settings := get_node_or_null("/root/UnilearnUserSettings")
	if settings == null:
		return

	if not bool(settings.get("play_login_success_intro_sfx")):
		return

	settings.set("play_login_success_intro_sfx", false)
	_play_login_success_sfx()


func _play_login_success_sfx() -> void:
	if not sfx_enabled:
		return
	var sfx := get_node_or_null("/root/UnilearnSFX")
	if sfx == null:
		return
	if sfx.has_method("play"):
		sfx.call("play", "success", 0.98, 1.04)


func _play_achievement_unlock_sfx(achievement: Dictionary = {}) -> void:
	if not sfx_enabled:
		return
	var sfx := get_node_or_null("/root/UnilearnSFX")
	if sfx == null:
		return
	var rarity := str(achievement.get("rarity", "normal")).strip_edges().to_lower()
	var sfx_id := "achievement_rare" if rarity == "rare" else "achievement"
	if sfx.has_method("play_stacked"):
		sfx.call("play_stacked", sfx_id, 0.98, 1.02)
	elif sfx.has_method("play"):
		sfx.call("play", sfx_id, 0.98, 1.02)


func _ensure_music_manager() -> void:
	_music_node = get_node_or_null("/root/UnilearnMusic")
	if _music_node != null:
		return

	_music_node = UNILEARN_MUSIC_SCRIPT.new()
	_music_node.name = "UnilearnMusic"
	_music_node.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_music_node)

func _start_music_if_enabled() -> void:
	if _music_node == null:
		_music_node = get_node_or_null("/root/UnilearnMusic")
	if _music_node == null:
		return

	if _music_node.has_method("rescan_and_start"):
		_music_node.call("rescan_and_start")
		return

	if _music_node.has_method("set_enabled"):
		_music_node.call("set_enabled", music_enabled)
	if music_enabled and _music_node.has_method("start"):
		_music_node.call("start")

func _load_local_settings() -> void:
	if not has_node("/root/UnilearnUserSettings"):
		return

	var settings := get_node("/root/UnilearnUserSettings")

	music_enabled = bool(settings.get("music_enabled"))
	sfx_enabled = settings.sfx_enabled

	if has_node("/root/UnilearnSFX"):
		get_node("/root/UnilearnSFX").set_enabled(sfx_enabled)

	apollo_enabled = settings.apollo_enabled
	reduce_motion_enabled = settings.reduce_motion_enabled


func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_cache_viewport()
		if is_instance_valid(_achievement_toast_panel):
			_layout_achievement_toast(not _achievement_toast_panel.visible)
		return

	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_pause_app_runtime_for_os()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_persist_live_galaxy_runtime_snapshot()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_resume_app_runtime_from_os()



func _pause_app_runtime_for_os() -> void:
	# Save the real in-scene runtime state once, at the moment the OS tells us
	# the app is leaving. This avoids per-frame disk writes but still restores
	# the latest simulated positions/velocities after a real app restart.
	_persist_live_galaxy_runtime_snapshot()
	_app_runtime_resume_token += 1
	_force_app_runtime_paused_for_os()


func _force_app_runtime_paused_for_os() -> void:
	var was_already_paused := _app_runtime_paused_by_os
	_app_runtime_paused_by_os = true

	# Android/iOS can emit PAUSED + FOCUS_OUT + extra focus changes. Do not
	# freeze the background twice, because the second freeze would capture
	# navigation_enabled=false and keep camera/background movement locked after resume.
	if not _background_frozen and not _app_runtime_pause_froze_scene:
		_app_runtime_pause_froze_scene = true
		_freeze_space_background()
		_freeze_scene_objects()
	elif not was_already_paused and _background_frozen:
		_app_runtime_pause_froze_scene = false

	_pause_ai_runtime_for_os()

	if _music_node == null:
		_music_node = get_node_or_null("/root/UnilearnMusic")
	if _music_node != null and _music_node.has_method("pause_for_app"):
		# Hard app-pause mute/pause. This prevents the tiny music blip while the
		# task switcher is bringing the game back to fullscreen.
		_music_node.call("pause_for_app")


func _resume_app_runtime_from_os() -> void:
	# Resume immediately on the first real foreground/focus return.
	# Duplicate RESUMED/FOCUS_IN notifications become harmless no-ops instead of
	# re-freezing the app or delaying the release until fullscreen finishes animating.
	if not _app_runtime_paused_by_os:
		return

	_app_runtime_resume_token += 1
	_app_runtime_paused_by_os = false

	if _app_runtime_pause_froze_scene:
		_unfreeze_space_background()
		_unfreeze_scene_objects()

	_app_runtime_pause_froze_scene = false

	_resume_ai_runtime_from_os()

	if _music_node == null:
		_music_node = get_node_or_null("/root/UnilearnMusic")
	if _music_node != null and _music_node.has_method("resume_from_app"):
		_music_node.call("resume_from_app")



func _pause_ai_runtime_for_os() -> void:
	_app_runtime_pause_paused_ai = false

	if not is_instance_valid(ai_assistant):
		ai_assistant = get_node_or_null("AIAssistant")

	if not is_instance_valid(ai_assistant):
		return

	_app_runtime_pause_paused_ai = true
	if ai_assistant.has_method("set_runtime_paused_by_app"):
		ai_assistant.call("set_runtime_paused_by_app", true)
	else:
		ai_assistant.set_process(false)


func _resume_ai_runtime_from_os() -> void:
	if not _app_runtime_pause_paused_ai:
		return

	_app_runtime_pause_paused_ai = false

	if not is_instance_valid(ai_assistant):
		ai_assistant = get_node_or_null("AIAssistant")

	if not is_instance_valid(ai_assistant):
		return

	if ai_assistant.has_method("set_runtime_paused_by_app"):
		ai_assistant.call("set_runtime_paused_by_app", false)
	else:
		ai_assistant.set_process(true)


func _input(event: InputEvent) -> void:
	if _universe_end_interface_locked:
		_clear_planet_touch_state_for_event(event)
		get_viewport().set_input_as_handled()
		return

	if _background_frozen:
		_clear_planet_touch_state_for_event(event)
		return

	# Planet interaction is dispatched manually below, so Control.mouse_filter
	# cannot stop the mouse event before it reaches the simulator. This matters
	# both on desktop and on devices that emulate a mouse press after a touch:
	# tapping the menu handle could otherwise also pick a body behind it.
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _is_position_over_blocking_ui(event.position):
				return

	if event is InputEventScreenTouch:
		if event.pressed:
			if _is_position_over_blocking_ui(event.position):
				blocked_touch_indices[event.index] = true
				get_viewport().set_input_as_handled()
				return

			if _is_touch_over_planet(event.position):
				planet_touch_indices[event.index] = true
				_set_background_external_touch(event.index, event.position, false)

				if _consume_universe_space_input(event):
					get_viewport().set_input_as_handled()
					return

				get_viewport().set_input_as_handled()
				return

		else:
			if planet_touch_indices.has(event.index):
				if _consume_universe_space_input(event):
					planet_touch_indices.erase(event.index)
					_remove_background_external_touch(event.index)
					get_viewport().set_input_as_handled()
					return

				planet_touch_indices.erase(event.index)
				_remove_background_external_touch(event.index)
				get_viewport().set_input_as_handled()
				return

			if blocked_touch_indices.has(event.index):
				blocked_touch_indices.erase(event.index)
				get_viewport().set_input_as_handled()
				return

	elif event is InputEventScreenDrag:
		if planet_touch_indices.has(event.index):
			_set_background_external_touch(event.index, event.position, true)

			if _consume_universe_space_input(event):
				get_viewport().set_input_as_handled()
				return

			get_viewport().set_input_as_handled()
			return

		if blocked_touch_indices.has(event.index):
			get_viewport().set_input_as_handled()
			return

	if _consume_universe_space_input(event):
		get_viewport().set_input_as_handled()
		return

	if _space_background_ref == null:
		return

	if _space_background_ref.get("navigation_enabled") != true:
		return

	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if _space_background_ref.has_method("handle_navigation_input"):
			_space_background_ref.call("handle_navigation_input", event)

	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		if _space_background_ref.has_method("handle_navigation_input"):
			_space_background_ref.call("handle_navigation_input", event)


func _clear_planet_touch_state_for_event(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not event.pressed:
			planet_touch_indices.erase(event.index)
			blocked_touch_indices.erase(event.index)
			_remove_background_external_touch(event.index)

	elif event is InputEventScreenDrag:
		if planet_touch_indices.has(event.index):
			_remove_background_external_touch(event.index)


func _is_touch_over_planet(screen_position: Vector2) -> bool:
	if not is_instance_valid(universe_playground):
		return false

	if universe_playground.has_method("is_screen_position_over_body"):
		return bool(universe_playground.call("is_screen_position_over_body", screen_position))

	return false


func _set_background_external_touch(index: int, screen_position: Vector2, apply_gesture: bool) -> void:
	if _space_background_ref == null:
		return

	if _space_background_ref.has_method("set_external_navigation_touch"):
		_space_background_ref.call("set_external_navigation_touch", index, screen_position, apply_gesture)


func _remove_background_external_touch(index: int) -> void:
	if _space_background_ref == null:
		return

	if _space_background_ref.has_method("remove_external_navigation_touch"):
		_space_background_ref.call("remove_external_navigation_touch", index)


func _consume_universe_space_input(event: InputEvent) -> bool:
	if not is_instance_valid(universe_playground):
		return false

	if not universe_playground.has_method("consume_space_input"):
		return false

	return bool(universe_playground.call("consume_space_input", event))


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


func _setup_universe_playground() -> void:
	if is_instance_valid(universe_playground):
		return

	universe_playground = UNIVERSE_PLAYGROUND_SCRIPT.new()
	universe_playground.name = "UniversePlayground"
	universe_playground.process_mode = Node.PROCESS_MODE_INHERIT
	_apply_saved_galaxy_config_to_universe()
	_connect_galaxy_state_to_universe()
	
	if universe_playground.has_signal("planet_card_open_requested"):
		var open_callable := Callable(self, "_on_simulation_planet_card_open_requested")

		if not universe_playground.is_connected("planet_card_open_requested", open_callable):
			universe_playground.connect("planet_card_open_requested", open_callable)
	
	if universe_playground.has_signal("scene_planets_changed"):
		var changed_callable := Callable(self, "_on_universe_scene_planets_changed")

		if not universe_playground.is_connected("scene_planets_changed", changed_callable):
			universe_playground.connect("scene_planets_changed", changed_callable)

	if universe_playground is CanvasItem:
		var canvas_item := universe_playground as CanvasItem
		canvas_item.z_index = 8
		canvas_item.z_as_relative = false

	add_child(universe_playground)
	move_child(universe_playground, 0)


func _on_simulation_planet_card_open_requested(planet_data) -> void:
	if planet_data == null:
		return

	_open_planet_cards_popup_to_card(planet_data)


func _open_planet_cards_popup_to_card(planet_data) -> void:
	if planet_data == null:
		return

	_set_background_frozen(true)

	var popup := _find_planet_cards_popup()

	if popup == null:
		if is_instance_valid(bottom_menu):
			if bottom_menu.has_method("_open_planet_cards_popup"):
				bottom_menu.call("_open_planet_cards_popup")
			elif bottom_menu.has_method("_on_item_pressed"):
				bottom_menu.call("_on_item_pressed", "cards")

		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame

		popup = _find_planet_cards_popup()

	if popup == null:
		push_warning("Could not find planet cards popup after opening it.")
		return

	_scan_and_connect_planet_card_popups()

	await _open_popup_details_when_ready(popup, planet_data)


func _find_planet_cards_popup() -> Node:
	var scene := get_tree().current_scene

	if scene != null:
		var found := _find_node_with_name_recursive(scene, "UnilearnPlanetCardsPopup")
		if found != null:
			return found

	if is_instance_valid(bottom_menu):
		var found_in_menu := _find_node_with_name_recursive(bottom_menu, "UnilearnPlanetCardsPopup")
		if found_in_menu != null:
			return found_in_menu

	return null


func _find_node_with_name_recursive(node: Node, wanted_name: String) -> Node:
	if node == null:
		return null

	if node.name == wanted_name:
		return node

	for child in node.get_children():
		var result := _find_node_with_name_recursive(child, wanted_name)

		if result != null:
			return result

	return null


func _open_popup_details_when_ready(popup: Node, planet_data) -> void:
	if popup == null or planet_data == null:
		return

	for _i in range(12):
		if not is_instance_valid(popup):
			return

		if popup.has_method("_open_details"):
			# Opening a card from the simulator should use the same details
			# behavior as selecting it inside Planet Cards. The popup itself
			# already owns the one transition sound.
			popup.call("_open_details", planet_data, false)
			return

		await get_tree().process_frame

	push_warning("Planet cards popup exists, but _open_details was not ready/found.")
	

func _apply_saved_galaxy_config_to_universe() -> void:
	if not is_instance_valid(universe_playground):
		return

	var galaxy_state := _get_galaxy_state_node()
	if galaxy_state == null:
		return

	var loaded_config: Variant = null
	if galaxy_state.has_method("load_into"):
		var current_config: Variant = universe_playground.get("config")
		if current_config is SimulationPhysicsConfig:
			loaded_config = galaxy_state.call("load_into", current_config)
	elif galaxy_state.has_method("get_config"):
		loaded_config = galaxy_state.call("get_config")

	if loaded_config is SimulationPhysicsConfig and universe_playground.has_method("set_simulation_config"):
		universe_playground.call("set_simulation_config", loaded_config, false)


func _connect_galaxy_state_to_universe() -> void:
	var galaxy_state := _get_galaxy_state_node()
	if galaxy_state == null:
		return

	if galaxy_state.has_signal("galaxy_config_changed"):
		var callable := Callable(self, "_on_galaxy_state_config_changed")
		if not galaxy_state.is_connected("galaxy_config_changed", callable):
			galaxy_state.connect("galaxy_config_changed", callable)


func _on_galaxy_popup_config_value_changed(property_name: String, value) -> void:
	_apply_galaxy_config_value_to_universe(property_name, value)


func _on_galaxy_state_config_changed(property_name: String, value, _config: SimulationPhysicsConfig) -> void:
	_apply_galaxy_config_value_to_universe(property_name, value)


func _apply_galaxy_config_value_to_universe(property_name: String, value) -> void:
	if not is_instance_valid(universe_playground):
		return

	if universe_playground.has_method("apply_config_value"):
		universe_playground.call("apply_config_value", property_name, value)
		return

	var current_config: Variant = universe_playground.get("config")
	if current_config is SimulationPhysicsConfig and current_config.has_method("apply_safe_value"):
		current_config.call("apply_safe_value", property_name, value)


func _setup_bottom_menu() -> void:
	if is_instance_valid(bottom_menu):
		return

	bottom_menu = BOTTOM_MENU_SCRIPT.new()
	bottom_menu.name = "BottomMenu"
	bottom_menu.visible = false
	add_child(bottom_menu)

	bottom_menu.music_enabled = music_enabled
	bottom_menu.sfx_enabled = sfx_enabled
	bottom_menu.apollo_enabled = apollo_enabled
	bottom_menu.set_reduce_motion_enabled(reduce_motion_enabled)

	bottom_menu.item_pressed.connect(_on_bottom_menu_item_pressed)
	bottom_menu.item_pressed.connect(func(_item_id: String) -> void:
		blocked_touch_indices.clear()
	)
	
	if bottom_menu.has_signal("galaxy_popup_opened"):
		bottom_menu.connect("galaxy_popup_opened", func(popup) -> void:
			if is_instance_valid(universe_playground) and universe_playground.has_method("get_added_planets_snapshot"):
				var snapshot: Array = universe_playground.call("get_added_planets_snapshot")
				_sync_galaxy_popup_system_objects(popup, snapshot)

			if popup != null and popup.has_signal("config_value_changed"):
				var config_callable := Callable(self, "_on_galaxy_popup_config_value_changed")
				if not popup.is_connected("config_value_changed", config_callable):
					popup.connect("config_value_changed", config_callable)
		)

	_scan_and_connect_planet_card_popups()


func _on_bottom_menu_item_pressed(item_id: String) -> void:
	match item_id:
		"multiplayer", "popup_multiplayer_opened":
			_set_background_frozen(true)

		"multiplayer_closed", "popup_multiplayer_closed":
			_set_background_frozen(false)

		"cards", "popup_cards_opened":
			_set_background_frozen(true)
			_deferred_scan_planet_card_popups()
			_delayed_scan_planet_card_popups()

		"cards_closed", "popup_cards_closed":
			_set_background_frozen(false)

		"achievements", "popup_achievements_opened":
			_set_background_frozen(true)

		"achievements_closed", "popup_achievements_closed":
			_set_background_frozen(false)

		"playgrounds":
			pass

		"popup_galaxy_opened":
			_set_background_frozen(true)

		"popup_galaxy_closed", "playgrounds_closed":
			_set_background_frozen(false)

		"galaxy_center_anchor":
			if is_instance_valid(universe_playground) and universe_playground.has_method("center_anchor_body"):
				universe_playground.call("center_anchor_body")

		"galaxy_reset_orbits":
			if is_instance_valid(universe_playground) and universe_playground.has_method("reset_orbits"):
				universe_playground.call("reset_orbits")

		"galaxy_clear_trails":
			if is_instance_valid(universe_playground) and universe_playground.has_method("clear_trails"):
				universe_playground.call("clear_trails")

		"settings", "popup_settings_opened":
			_set_background_frozen(true)

		"settings_closed", "popup_settings_closed":
			_set_background_frozen(false)

		"settings_reset_camera":
			_reset_space_camera()

		"settings_music_on":
			_set_music_enabled(true)

		"settings_music_off":
			_set_music_enabled(false)

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

		"settings_delete_account":
			_delete_account_user()

		_:
			if item_id.begins_with("galaxy_config_"):
				_apply_saved_galaxy_config_to_universe()
				return



func _on_any_child_entered_tree(_node: Node) -> void:
	_deferred_scan_planet_card_popups()


func _on_global_node_added(node: Node) -> void:
	if node == null:
		return
	if node is ScrollBar:
		(node as ScrollBar).mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif node is ScrollContainer:
		call_deferred("_disable_scrollbar_track_input", node)


func _disable_scrollbar_track_input(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	if root is ScrollBar:
		(root as ScrollBar).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if root is ScrollContainer:
		var scroll := root as ScrollContainer
		var vertical := scroll.get_v_scroll_bar()
		var horizontal := scroll.get_h_scroll_bar()
		if is_instance_valid(vertical):
			vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_instance_valid(horizontal):
			horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in root.get_children():
		_disable_scrollbar_track_input(child)


func _deferred_scan_planet_card_popups() -> void:
	if _planet_popup_scan_pending:
		return

	_planet_popup_scan_pending = true
	call_deferred("_scan_and_connect_planet_card_popups")


func _delayed_scan_planet_card_popups() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_scan_and_connect_planet_card_popups()


func _scan_and_connect_planet_card_popups() -> void:
	_planet_popup_scan_pending = false

	var root := get_tree().current_scene

	if root == null:
		root = self

	_scan_node_for_planet_card_popup(root)

	if is_instance_valid(bottom_menu) and bottom_menu != root:
		_scan_node_for_planet_card_popup(bottom_menu)


func _scan_node_for_planet_card_popup(node: Node) -> void:
	if node == null:
		return

	_try_connect_planet_card_popup(node)

	for child in node.get_children():
		_scan_node_for_planet_card_popup(child)


func _try_connect_planet_card_popup(node: Node) -> void:
	if node == null:
		return

	var id := node.get_instance_id()

	if _connected_planet_popups.has(id):
		if is_instance_valid(_connected_planet_popups[id]):
			return

		_connected_planet_popups.erase(id)

	var has_add_signal := node.has_signal("planet_add_requested")
	var has_remove_signal := node.has_signal("planet_remove_requested")
	var has_tutorial_add_signal := node.has_signal("tutorial_planet_add_requested")

	if not has_add_signal and not has_remove_signal and not has_tutorial_add_signal:
		return

	if has_add_signal:
		var add_callable := Callable(self, "_on_planet_card_add_requested")

		if not node.is_connected("planet_add_requested", add_callable):
			node.connect("planet_add_requested", add_callable)

	if has_remove_signal:
		var remove_callable := Callable(self, "_on_planet_card_remove_requested")

		if not node.is_connected("planet_remove_requested", remove_callable):
			node.connect("planet_remove_requested", remove_callable)

	if has_tutorial_add_signal:
		var tutorial_add_callable := Callable(self, "_on_tutorial_planet_card_add_requested")

		if not node.is_connected("tutorial_planet_add_requested", tutorial_add_callable):
			node.connect("tutorial_planet_add_requested", tutorial_add_callable)

	if node.has_signal("closed"):
		var closed_callable := Callable(self, "_on_planet_cards_popup_closed").bind(id)

		if not node.is_connected("closed", closed_callable):
			node.connect("closed", closed_callable)

	_connected_planet_popups[id] = node


func _on_planet_cards_popup_closed(popup_id: int) -> void:
	if _connected_planet_popups.has(popup_id):
		_connected_planet_popups.erase(popup_id)


func _on_planet_card_add_requested(data) -> void:
	if data == null:
		return

	_setup_universe_playground()

	if not is_instance_valid(universe_playground):
		push_warning("Cannot add planet because UniversePlayground is missing.")
		return

	if universe_playground.has_method("is_simulation_body_limit_reached") and bool(universe_playground.call("is_simulation_body_limit_reached")):
		push_warning("Cannot add planet because the simulator is full.")
		return

	var spawn_position := _get_default_planet_spawn_position()

	if universe_playground.has_method("add_planet_card"):
		var body = universe_playground.call("add_planet_card", data, spawn_position)

		if body != null:
			_focus_spawned_simulation_body(body)

		return

	push_warning("UniversePlayground does not have add_planet_card(data, spawn_position).")


func _on_tutorial_planet_card_add_requested(data) -> void:
	if data == null:
		return
	_setup_universe_playground()
	if not is_instance_valid(universe_playground):
		return
	if universe_playground.has_method("is_simulation_body_limit_reached") and bool(universe_playground.call("is_simulation_body_limit_reached")):
		return
	var spawn_position := _get_default_planet_spawn_position()
	if universe_playground.has_method("add_planet_card"):
		var body = universe_playground.call("add_planet_card", data, spawn_position, true)
		if body != null:
			_focus_spawned_simulation_body(body)


func _on_planet_card_remove_requested(data) -> void:
	if data == null:
		return

	if not is_instance_valid(universe_playground):
		return

	if universe_playground.has_method("remove_planet_card"):
		universe_playground.call("remove_planet_card", data)
		return

	push_warning("UniversePlayground does not have remove_planet_card(data).")


func tutorial_remove_planet_from_scene(data) -> void:
	_on_planet_card_remove_requested(data)


func _get_default_planet_spawn_position() -> Vector2:
	_cache_viewport()

	_setup_universe_playground()

	if is_instance_valid(universe_playground) and universe_playground.has_method("screen_to_space"):
		return universe_playground.call("screen_to_space", _viewport_center)

	return Vector2.ZERO


func is_simulation_body_limit_reached() -> bool:
	_setup_universe_playground()
	if not is_instance_valid(universe_playground):
		return false
	if universe_playground.has_method("is_simulation_body_limit_reached"):
		return bool(universe_playground.call("is_simulation_body_limit_reached"))
	return false


func get_simulation_body_count() -> int:
	_setup_universe_playground()
	if not is_instance_valid(universe_playground):
		return 0
	if universe_playground.has_method("get_simulation_body_count"):
		return int(universe_playground.call("get_simulation_body_count"))
	return 0


func is_planet_card_in_scene(data) -> bool:
	if data == null:
		return false

	_setup_universe_playground()

	if not is_instance_valid(universe_playground):
		return false

	if universe_playground.has_method("is_planet_card_added"):
		return bool(universe_playground.call("is_planet_card_added", data))

	return false


func _focus_spawned_simulation_body(body) -> void:
	if body == null:
		return

	if not is_instance_valid(body):
		return

	if body is CanvasItem:
		var canvas_item := body as CanvasItem
		canvas_item.visible = true



func _system_has_black_and_white_holes(snapshot: Array) -> bool:
	var has_black := false
	var has_white := false

	for item in snapshot:
		if not (item is Dictionary):
			continue
		var data: Dictionary = item
		if _snapshot_body_is_black_hole(data):
			has_black = true
		elif _snapshot_body_is_white_hole(data):
			has_white = true
		if has_black and has_white:
			return true

	return false


func _snapshot_body_is_black_hole(data: Dictionary) -> bool:
	var text := _snapshot_body_identity_text(data)
	if text.contains("white_hole") or text.contains("white hole"):
		return false
	return int(data.get("body_kind", -1)) == 4 or text.contains("black_hole") or text.contains("black hole") or text.contains("ton 618")


func _snapshot_body_is_white_hole(data: Dictionary) -> bool:
	var text := _snapshot_body_identity_text(data)
	return int(data.get("body_kind", -1)) == 8 or text.contains("white_hole") or text.contains("white hole")


func _snapshot_body_identity_text(data: Dictionary) -> String:
	var parts: Array[String] = []
	for key in ["name", "title", "source_name", "subtitle", "card_id", "instance_id", "object_category", "source_object_category", "planet_preset"]:
		parts.append(str(data.get(key, "")))
	return " ".join(parts).to_lower()


func _try_start_universe_end_interface_lock() -> void:
	if not _universe_end_interface_lock_pending:
		return
	if _universe_end_interface_locked or _universe_end_interface_exit_running:
		return
	if _background_frozen:
		return
	if is_instance_valid(bottom_menu):
		if bottom_menu.has_method("has_open_popup") and bool(bottom_menu.call("has_open_popup")):
			return
		if bottom_menu.has_method("is_menu_open") and bool(bottom_menu.call("is_menu_open")):
			return

	_start_universe_end_interface_lock()


func _start_universe_end_interface_lock() -> void:
	if _universe_end_interface_locked or _universe_end_interface_exit_running:
		return

	_universe_end_interface_exit_running = true
	_universe_end_interface_locked = true
	_universe_end_interface_lock_pending = false
	_stop_music_for_universe_end_lock()
	blocked_touch_indices.clear()
	for index in planet_touch_indices.keys():
		_remove_background_external_touch(int(index))
	planet_touch_indices.clear()

	if _space_background_ref != null:
		var nav_value = _space_background_ref.get("navigation_enabled")
		if nav_value != null:
			_universe_end_saved_navigation_enabled = bool(nav_value)
		if _space_background_ref.has_method("set_navigation_enabled"):
			_space_background_ref.call("set_navigation_enabled", false)

	if reduce_motion_enabled:
		_hide_universe_end_interface_immediately()
		_start_universe_end_camera_focus()
		_universe_end_interface_exit_running = false
		return

	await _play_logout_ui_exit_animation(false)
	_hide_universe_end_interface_immediately()
	_start_universe_end_camera_focus()
	_universe_end_interface_exit_running = false


func _hide_universe_end_interface_immediately() -> void:
	if is_instance_valid(bottom_menu):
		bottom_menu.visible = false
		bottom_menu.set_process_input(false)
		bottom_menu.set_process_unhandled_input(false)
	if is_instance_valid(ai_assistant):
		if ai_assistant.has_method("stop"):
			ai_assistant.call("stop")
		if ai_assistant is CanvasItem:
			var ai_item := ai_assistant as CanvasItem
			ai_item.visible = false


func _start_universe_end_camera_focus() -> void:
	if not is_instance_valid(universe_playground):
		return
	if not universe_playground.has_method("focus_universe_end_pair_camera"):
		return
	if UNIVERSE_END_CAMERA_START_DELAY <= 0.0:
		universe_playground.call("focus_universe_end_pair_camera")
		return
	await get_tree().create_timer(UNIVERSE_END_CAMERA_START_DELAY, true, false, true).timeout
	if is_instance_valid(universe_playground) and universe_playground.has_method("focus_universe_end_pair_camera"):
		universe_playground.call("focus_universe_end_pair_camera")


func _release_universe_end_interface_lock() -> void:
	if not _universe_end_interface_locked and not _universe_end_interface_lock_pending:
		return

	_universe_end_interface_lock_pending = false
	_universe_end_interface_locked = false
	_universe_end_interface_exit_running = false
	blocked_touch_indices.clear()
	planet_touch_indices.clear()

	if _space_background_ref != null and _space_background_ref.has_method("set_navigation_enabled"):
		_space_background_ref.call("set_navigation_enabled", _universe_end_saved_navigation_enabled)

	if not reduce_motion_enabled:
		_play_interface_sfx("open")

	if is_instance_valid(bottom_menu):
		bottom_menu.set_process_input(true)
		bottom_menu.set_process_unhandled_input(true)
		bottom_menu.visible = true
		if not reduce_motion_enabled and bottom_menu.has_method("play_entry_animation"):
			bottom_menu.call("play_entry_animation")

	if is_instance_valid(ai_assistant):
		if ai_assistant is CanvasItem:
			var ai_item := ai_assistant as CanvasItem
			ai_item.visible = true
		if apollo_enabled and ai_assistant.has_method("start"):
			ai_assistant.call("start")
		if not reduce_motion_enabled and ai_assistant.has_method("play_entry_animation"):
			ai_assistant.call("play_entry_animation")
	
func _set_background_frozen(frozen: bool) -> void:
	if _background_frozen == frozen:
		return

	_background_frozen = frozen
	blocked_touch_indices.clear()

	for index in planet_touch_indices.keys():
		_remove_background_external_touch(int(index))

	planet_touch_indices.clear()

	if frozen:
		_freeze_space_background()
		_freeze_scene_objects()
		return

	_unfreeze_space_background()
	_unfreeze_scene_objects()
	call_deferred("_try_start_universe_end_interface_lock")


func _freeze_scene_objects() -> void:
	if not is_instance_valid(universe_playground):
		return

	if universe_playground.has_method("set_scene_objects_paused"):
		universe_playground.call("set_scene_objects_paused", true)


func _unfreeze_scene_objects() -> void:
	if not is_instance_valid(universe_playground):
		return

	if universe_playground.has_method("set_scene_objects_paused"):
		universe_playground.call("set_scene_objects_paused", false)


func _freeze_space_background() -> void:
	if _space_background_ref == null:
		return

	var nav_value = _space_background_ref.get("navigation_enabled")
	if nav_value != null:
		_saved_navigation_enabled = bool(nav_value)

	if _space_background_ref.has_method("set_navigation_enabled"):
		_space_background_ref.call("set_navigation_enabled", false)

	if _space_background_ref.has_method("set_background_paused"):
		_space_background_ref.call("set_background_paused", true)
	else:
		_space_background_ref.set_process(false)


func _unfreeze_space_background() -> void:
	if _space_background_ref == null:
		return

	if _space_background_ref.has_method("set_background_paused"):
		_space_background_ref.call("set_background_paused", false)
	else:
		_space_background_ref.set_process(true)

	if _space_background_ref.has_method("set_navigation_enabled"):
		_space_background_ref.call("set_navigation_enabled", _saved_navigation_enabled)


func _set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled

	if has_node("/root/UnilearnUserSettings"):
		var settings := get_node("/root/UnilearnUserSettings")
		if settings.has_method("set_music_enabled"):
			settings.set_music_enabled(enabled)

	if _music_node == null:
		_music_node = get_node_or_null("/root/UnilearnMusic")

	if _music_node != null and _music_node.has_method("set_enabled"):
		_music_node.set_enabled(enabled)

	if is_instance_valid(bottom_menu):
		bottom_menu.music_enabled = enabled


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

	blocked_touch_indices.clear()
	for index in planet_touch_indices.keys():
		_remove_background_external_touch(int(index))
	planet_touch_indices.clear()

	if _space_background_ref.has_method("set_navigation_enabled"):
		_space_background_ref.call("set_navigation_enabled", false)

	if _space_background_ref.has_method("reset_navigation_view_smooth"):
		var reset_duration := 1.05
		_space_background_ref.call("reset_navigation_view_smooth", reset_duration)
		await get_tree().create_timer(reset_duration, false).timeout
		if _space_background_ref != null and is_instance_valid(_space_background_ref) and _space_background_ref.has_method("set_navigation_enabled"):
			_space_background_ref.call("set_navigation_enabled", true)
		return

	if _space_background_ref.has_method("set_space_position"):
		_space_background_ref.call("set_space_position", Vector2.ZERO, false)
	elif _space_background_ref.get("target_space_position") is Vector2:
		_space_background_ref.set("target_space_position", Vector2.ZERO)

	if _space_background_ref.has_method("set_space_zoom"):
		_space_background_ref.call("set_space_zoom", 1.0, Vector2.ZERO, false)
	elif _space_background_ref.get("target_space_zoom") != null:
		_space_background_ref.set("target_space_zoom", 1.0)

	if _space_background_ref.has_method("set_space_rotation"):
		_space_background_ref.call("set_space_rotation", 0.0, Vector2.ZERO, false)
	elif _space_background_ref.get("target_space_rotation") != null:
		_space_background_ref.set("target_space_rotation", 0.0)

	if _space_background_ref.has_method("set_navigation_enabled"):
		_space_background_ref.call("set_navigation_enabled", true)


func _delete_account_user() -> void:
	blocked_touch_indices.clear()
	_set_background_frozen(false)

	var token := _get_cached_unilearn_id_token_for_account_delete()
	if token.is_empty():
		_request_unilearn_account_delete_with_fresh_token_in_background()
	else:
		_request_unilearn_account_delete_in_background(token)

	await _logout_user()


func _request_unilearn_account_delete_in_background(id_token: String) -> void:
	id_token = id_token.strip_edges()
	if id_token.is_empty():
		return

	var http := HTTPRequest.new()
	http.name = "DeleteAccountHTTPRequest"
	http.timeout = 30.0
	http.process_mode = Node.PROCESS_MODE_ALWAYS

	var parent: Variant = get_tree().root if get_tree() != null else self
	parent.add_child(http)

	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		if response_code < 200 or response_code >= 300:
			push_warning("Account delete request finished with HTTP %d after local logout." % response_code)
		if is_instance_valid(http):
			http.queue_free()
	)

	var url := "https://optima-livekit-token-server.onrender.com/unilearn/users/account"
	var headers := PackedStringArray([
		"Authorization: Bearer %s" % id_token,
		"Content-Type: application/json",
	])
	var err := http.request(url, headers, HTTPClient.METHOD_DELETE, "{}")
	if err != OK:
		push_warning("Could not start account delete request. Logging out locally anyway. Error code: %d" % err)
		if is_instance_valid(http):
			http.queue_free()


func _request_unilearn_account_delete_with_fresh_token_in_background() -> void:
	var token := await _get_fresh_unilearn_id_token_for_account_delete()
	if token.strip_edges().is_empty():
		push_warning("Could not get an id token for account deletion before logout finished.")
		return
	_request_unilearn_account_delete_in_background(token)


func _get_cached_unilearn_id_token_for_account_delete() -> String:
	for path in ["/root/UnilearnAuth", "/root/FirebaseAuth", "/root/UnilearnUser"]:
		var auth := get_node_or_null(path)
		if auth == null:
			continue
		if auth.has_method("get_id_token"):
			var token := str(auth.call("get_id_token")).strip_edges()
			if not token.is_empty():
				return token
		for property_name in ["id_token", "token", "access_token"]:
			if property_name in auth:
				var value := str(auth.get(property_name)).strip_edges()
				if not value.is_empty():
					return value
	return ""


func _get_fresh_unilearn_id_token_for_account_delete() -> String:
	for path in ["/root/UnilearnAuth", "/root/FirebaseAuth", "/root/UnilearnUser"]:
		var auth := get_node_or_null(path)
		if auth == null:
			continue
		if auth.has_method("get_fresh_id_token"):
			return str(await auth.call("get_fresh_id_token"))
	return _get_cached_unilearn_id_token_for_account_delete()


func _clear_achievement_runtime_for_logout() -> void:
	for path in ["/root/UnilearnAchievements", "/root/UnilearnAchievementTracker", "/root/AchievementTracker"]:
		var tracker := get_node_or_null(path)
		if tracker == null:
			continue
		if tracker.has_method("clear_runtime_for_logout"):
			tracker.call("clear_runtime_for_logout")
			return
		if tracker.has_method("force_reload_from_backend_after_login"):
			# Older tracker: do not sync anything during logout; login will force a backend reload.
			return


func _logout_user() -> void:
	blocked_touch_indices.clear()
	_set_background_frozen(false)

	await _play_logout_ui_exit_animation()
	_clear_active_scene_bodies_for_logout()

	if is_instance_valid(ai_assistant):
		if ai_assistant.has_method("stop"):
			ai_assistant.call("stop")

	if AIState.has_method("set_enabled"):
		AIState.set_enabled(false)
	else:
		AIState.enabled = false
		AIState.reset()

	_clear_achievement_runtime_for_logout()

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


func _play_logout_ui_exit_animation(include_planets: bool = true) -> void:
	blocked_touch_indices.clear()
	planet_touch_indices.clear()

	if reduce_motion_enabled:
		if is_instance_valid(bottom_menu):
			bottom_menu.visible = false
		if is_instance_valid(ai_assistant) and ai_assistant is CanvasItem:
			var ai_item := ai_assistant as CanvasItem
			ai_item.visible = false
		return

	_play_interface_sfx("close")

	if is_instance_valid(bottom_menu):
		if bottom_menu.has_method("play_exit_animation"):
			bottom_menu.call("play_exit_animation")
		else:
			bottom_menu.close_menu()

	if is_instance_valid(ai_assistant):
		if ai_assistant.has_method("play_exit_animation"):
			ai_assistant.call("play_exit_animation")

	if include_planets and is_instance_valid(universe_playground) and universe_playground.has_method("play_logout_exit_animation"):
		universe_playground.call("play_logout_exit_animation", LOGOUT_PLANET_FADE_DURATION)

	await get_tree().create_timer(LOGOUT_UI_EXIT_DURATION).timeout


func _clear_active_scene_bodies_for_logout() -> void:
	if is_instance_valid(universe_playground) and universe_playground.has_method("clear_all"):
		universe_playground.call("clear_all")

	var galaxy_state := _get_galaxy_state_node()
	if galaxy_state != null:
		if galaxy_state.has_method("clear_bodies"):
			galaxy_state.call("clear_bodies", true)
		elif galaxy_state.has_method("set_bodies"):
			galaxy_state.call("set_bodies", [], true)


func begin_multiplayer_sync_planet_exit_animation() -> float:
	_set_background_frozen(false)
	blocked_touch_indices.clear()
	planet_touch_indices.clear()

	if reduce_motion_enabled:
		return 0.0
	if not is_instance_valid(universe_playground):
		return 0.0
	if not universe_playground.has_method("play_logout_exit_animation"):
		return 0.0

	# Calling without await starts every body/trail tween immediately. The method
	# then waits internally, while BottomMenu tracks the full staggered duration.
	universe_playground.call("play_logout_exit_animation", LOGOUT_PLANET_FADE_DURATION)
	return LOGOUT_PLANET_FADE_DURATION * 1.28


func clear_scene_for_multiplayer_sync(peer_name: String = "", peer_uid: String = "", request_id: String = "") -> void:
	_set_background_frozen(false)
	blocked_touch_indices.clear()
	planet_touch_indices.clear()

	if is_instance_valid(bottom_menu) and bottom_menu.has_method("set_multiplayer_sync_active") and not bool(bottom_menu.call("is_multiplayer_sync_active")):
		bottom_menu.call("set_multiplayer_sync_active", true, peer_name, peer_uid)

	if is_instance_valid(universe_playground) and universe_playground.has_method("begin_multiplayer_universe_sync"):
		universe_playground.call("begin_multiplayer_universe_sync", peer_uid, request_id)


func stop_multiplayer_universe_sync() -> void:
	if is_instance_valid(bottom_menu) and bottom_menu.has_method("stop_multiplayer_sync_ui"):
		bottom_menu.call("stop_multiplayer_sync_ui")


func end_multiplayer_universe_sync() -> void:
	_set_background_frozen(false)
	blocked_touch_indices.clear()
	planet_touch_indices.clear()

	if not is_instance_valid(universe_playground):
		return

	# Freeze the shared universe in place while it performs the same staggered
	# disappearance used by logout. This prevents planets from drifting or
	# colliding underneath the exit animation.
	if universe_playground.has_method("set_scene_objects_paused"):
		universe_playground.call("set_scene_objects_paused", true)

	if not reduce_motion_enabled and universe_playground.has_method("play_logout_exit_animation"):
		await universe_playground.call("play_logout_exit_animation", LOGOUT_PLANET_FADE_DURATION)

	# Restore the exact pre-sync universe only after every shared planet has
	# disappeared, then replay the same body entrance used on the main screen.
	if universe_playground.has_method("end_multiplayer_universe_sync"):
		universe_playground.call("end_multiplayer_universe_sync")

	await get_tree().process_frame

	if not reduce_motion_enabled and universe_playground.has_method("play_scene_entry_animation"):
		universe_playground.call("play_scene_entry_animation", MAIN_INTRO_PLANET_DELAY)
		await get_tree().create_timer(APP_STARTUP_SCENE_RELEASE_DELAY_SEC, true, false, true).timeout

	if is_instance_valid(universe_playground) and universe_playground.has_method("set_scene_objects_paused"):
		universe_playground.call("set_scene_objects_paused", false)


func _play_logout_fade_out() -> void:
	_ensure_logout_transition_overlay()

	if not is_instance_valid(_logout_transition_rect):
		return

	_logout_transition_rect.visible = true
	_logout_transition_rect.modulate.a = 0.0
	_logout_transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	if reduce_motion_enabled:
		_logout_transition_rect.modulate.a = 1.0
		return

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_logout_transition_rect, "modulate:a", 1.0, LOGOUT_FADE_DURATION)
	await tween.finished


func _ensure_logout_transition_overlay() -> void:
	if is_instance_valid(_logout_transition_layer) and is_instance_valid(_logout_transition_rect):
		return

	_logout_transition_layer = CanvasLayer.new()
	_logout_transition_layer.name = "LogoutTransitionLayer"
	_logout_transition_layer.layer = 20000
	_logout_transition_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_logout_transition_layer)

	_logout_transition_rect = ColorRect.new()
	_logout_transition_rect.name = "LogoutTransitionFade"
	_logout_transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_logout_transition_rect.color = Color("#050712")
	_logout_transition_rect.modulate.a = 0.0
	_logout_transition_rect.visible = false
	_logout_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logout_transition_layer.add_child(_logout_transition_rect)


func _setup_space_background() -> void:
	if _space_background_ref == null:
		push_warning("SpaceBackground autoload was not found.")
		return

	if _space_background_ref.has_method("set_space_reveal"):
		_space_background_ref.call("set_space_reveal", 1.0)

	_space_background_ref.set("star_reveal", 1.0)
	_space_background_ref.set("travel_speed_multiplier", 0.0)

	if _space_background_ref.has_method("set_navigation_enabled"):
		_space_background_ref.call("set_navigation_enabled", false)


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
		item.modulate.a = 1.0

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

	if _universe_end_interface_locked:
		_hide_universe_end_interface_immediately()


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
	if _main_scene_intro_started:
		return

	_main_scene_intro_started = true
	blocked_touch_indices.clear()
	_play_login_success_sfx_if_pending()

	if _space_background_ref != null and _space_background_ref.has_method("set_navigation_enabled"):
		_space_background_ref.call("set_navigation_enabled", true)

	_play_bottom_menu_entry_animation()
	_play_ai_entry_animation()


func _play_bottom_menu_entry_animation() -> void:
	if _bottom_menu_intro_done:
		return

	if not is_instance_valid(bottom_menu):
		return

	_bottom_menu_intro_done = true

	if reduce_motion_enabled:
		bottom_menu.visible = true
		return

	bottom_menu.visible = true
	_play_interface_sfx("open")

	if bottom_menu.has_method("play_entry_animation"):
		bottom_menu.call("play_entry_animation")


func _play_ai_entry_animation() -> void:
	if _ai_intro_done:
		return

	if not is_instance_valid(ai_assistant):
		return

	_ai_intro_done = true

	if reduce_motion_enabled:
		return

	if ai_assistant is CanvasItem:
		var ai_item := ai_assistant as CanvasItem
		ai_item.modulate.a = 1.0

	if ai_assistant.has_method("play_entry_animation"):
		ai_assistant.call("play_entry_animation")


func _play_planets_entry_animation() -> void:
	if _planets_intro_done:
		return

	if not is_instance_valid(universe_playground):
		return

	_planets_intro_done = true

	if reduce_motion_enabled:
		return

	if universe_playground.has_method("play_scene_entry_animation"):
		universe_playground.call("play_scene_entry_animation", MAIN_INTRO_PLANET_DELAY)


func _set_apollo_enabled(enabled: bool) -> void:
	if enabled and not _is_microphone_permission_granted_for_apollo():
		_begin_apollo_permission_request_from_content()
		return

	_commit_apollo_enabled(enabled)


func _commit_apollo_enabled(enabled: bool) -> void:
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


func _begin_apollo_permission_request_from_content() -> void:
	if _apollo_permission_flow_running:
		return

	_apollo_permission_flow_running = true
	_request_microphone_permission_for_apollo()

	await get_tree().process_frame

	var attempts := 0

	while attempts < 80 and not _is_microphone_permission_granted_for_apollo():
		attempts += 1
		await get_tree().create_timer(0.25).timeout

	_apollo_permission_flow_running = false

	if not is_inside_tree():
		return

	if _is_microphone_permission_granted_for_apollo():
		_commit_apollo_enabled(true)
	else:
		_commit_apollo_enabled(false)


func _is_microphone_permission_granted_for_apollo() -> bool:
	var settings := get_node_or_null("/root/UnilearnUserSettings")

	if settings != null and settings.has_method("is_microphone_permission_granted"):
		return bool(settings.call("is_microphone_permission_granted"))

	if OS.get_name() != "Android":
		return true

	if not OS.has_method("get_granted_permissions"):
		return true

	return OS.get_granted_permissions().has("android.permission.RECORD_AUDIO")


func _request_microphone_permission_for_apollo() -> void:
	var settings := get_node_or_null("/root/UnilearnUserSettings")

	if settings != null and settings.has_method("request_microphone_permission"):
		settings.call("request_microphone_permission")
		return

	if OS.get_name() == "Android" and OS.has_method("request_permissions"):
		OS.request_permissions()


func _set_space_navigation_enabled(enabled: bool) -> void:
	if _background_frozen:
		return

	if _space_background_ref != null and _space_background_ref.has_method("set_navigation_enabled"):
		_space_background_ref.call("set_navigation_enabled", enabled)


func _persist_live_galaxy_runtime_snapshot() -> void:
	if not _galaxy_restore_done:
		return

	if not is_instance_valid(universe_playground):
		return

	if not universe_playground.has_method("get_added_planets_snapshot"):
		return

	var snapshot: Array = universe_playground.call("get_added_planets_snapshot")

	var galaxy_state := _get_galaxy_state_node()
	var sync_active := is_instance_valid(universe_playground) and universe_playground.has_method("is_multiplayer_universe_sync_active") and bool(universe_playground.call("is_multiplayer_universe_sync_active"))
	if not sync_active and galaxy_state != null and galaxy_state.has_method("set_bodies"):
		galaxy_state.call("set_bodies", snapshot, true)


func _get_galaxy_state_node() -> Node:
	if _galaxy_state_node != null and is_instance_valid(_galaxy_state_node):
		return _galaxy_state_node

	_galaxy_state_node = get_node_or_null("/root/GalaxyState")
	return _galaxy_state_node


func _on_universe_scene_planets_changed(snapshot: Array) -> void:
	var has_end_pair := _system_has_black_and_white_holes(snapshot)
	if has_end_pair:
		_universe_end_interface_lock_pending = true
		call_deferred("_try_start_universe_end_interface_lock")
	elif _universe_end_interface_locked or _universe_end_interface_lock_pending:
		_release_universe_end_interface_lock()

	if not _galaxy_restore_done:
		return

	var galaxy_state := _get_galaxy_state_node()
	var sync_active := is_instance_valid(universe_playground) and universe_playground.has_method("is_multiplayer_universe_sync_active") and bool(universe_playground.call("is_multiplayer_universe_sync_active"))
	if not sync_active and galaxy_state != null and galaxy_state.has_method("set_bodies"):
		galaxy_state.call("set_bodies", snapshot, true)

	var popup := _find_node_with_name_recursive(get_tree().current_scene, "UnilearnGalaxyPopup")
	if popup == null and is_instance_valid(bottom_menu):
		popup = _find_node_with_name_recursive(bottom_menu, "UnilearnGalaxyPopup")

	_sync_galaxy_popup_system_objects(popup, snapshot)

	var planet_cards_popup := _find_planet_cards_popup()
	if planet_cards_popup != null and planet_cards_popup.has_method("refresh_open_details_planet_state"):
		planet_cards_popup.call("refresh_open_details_planet_state")


func _sync_galaxy_popup_system_objects(popup: Object, snapshot: Array) -> void:
	if popup == null or not is_instance_valid(popup):
		return

	# Godot can briefly expose the popup as its CanvasLayer base while the script
	# is still loading/recovering from reloads. Do not hard-call methods through
	# `call()` unless the current runtime instance actually has them.
	if popup.has_method("set_system_objects"):
		popup.call("set_system_objects", snapshot)
		return

	if popup.has_method("update_system_objects"):
		popup.call("update_system_objects", snapshot)
		return

	# Retry once on the next frame, because the galaxy popup is created and then
	# added to the tree from the bottom menu. This avoids the crash without losing
	# the system snapshot when the method becomes available a moment later.
	call_deferred("_deferred_sync_galaxy_popup_system_objects", popup, snapshot)


func _deferred_sync_galaxy_popup_system_objects(popup: Object, snapshot: Array) -> void:
	if popup == null or not is_instance_valid(popup):
		return
	if popup.has_method("set_system_objects"):
		popup.call("set_system_objects", snapshot)
	elif popup.has_method("update_system_objects"):
		popup.call("update_system_objects", snapshot)


func _restore_saved_galaxy_bodies() -> void:
	if _galaxy_restore_done:
		return

	_galaxy_restore_done = true

	if not is_instance_valid(universe_playground):
		return

	var galaxy_state := _get_galaxy_state_node()
	if galaxy_state == null:
		return

	var saved_bodies: Array = []

	if galaxy_state.has_method("get_bodies"):
		saved_bodies = galaxy_state.call("get_bodies")
	elif galaxy_state.has_method("load_settings"):
		galaxy_state.call("load_settings")
		if galaxy_state.has_method("get_bodies"):
			saved_bodies = galaxy_state.call("get_bodies")

	if saved_bodies.is_empty():
		return

	var cards := await _load_planet_cards_for_restore()

	_startup_scene_release_token += 1
	var release_token := _startup_scene_release_token
	if universe_playground.has_method("set_scene_objects_paused"):
		universe_playground.call("set_scene_objects_paused", true)

	if universe_playground.has_method("restore_added_planets"):
		await universe_playground.call("restore_added_planets", saved_bodies, cards, not reduce_motion_enabled)

	# The playground now animates each restored body as it is created, beginning
	# with the anchor, so do not replay a second all-at-once entrance here.
	_planets_intro_done = true
	_release_startup_scene_after_intro(release_token)




func _release_startup_scene_after_intro(token: int) -> void:
	await get_tree().create_timer(APP_STARTUP_SCENE_RELEASE_DELAY_SEC).timeout
	await get_tree().process_frame
	if token != _startup_scene_release_token:
		return
	if _app_runtime_paused_by_os or _background_frozen:
		return
	if is_instance_valid(universe_playground) and universe_playground.has_method("set_scene_objects_paused"):
		universe_playground.call("set_scene_objects_paused", false)


func _load_planet_cards_for_restore() -> Array:
	var cache := get_node_or_null("/root/PlanetCardsCache")

	if cache == null:
		return []

	if cache.has_method("ensure_loaded"):
		var result = await cache.call("ensure_loaded")

		if result is Array:
			return result

	if cache.has_method("get_cards"):
		var cards = cache.call("get_cards")
		if cards is Array:
			return cards

	var property_list := cache.get_property_list()
	for property in property_list:
		if property.has("name") and str(property["name"]) == "cards":
			var direct_cards = cache.get("cards")
			if direct_cards is Array:
				return direct_cards

	return []


func _make_buttons_dry(root: Node) -> void:
	if root == null:
		return
	if root is Button:
		var b := root as Button
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("hover", b.get_theme_stylebox("normal"))
		b.add_theme_stylebox_override("pressed", b.get_theme_stylebox("normal"))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_hover_color", b.get_theme_color("font_color"))
		b.add_theme_color_override("font_pressed_color", b.get_theme_color("font_color"))
	for child in root.get_children():
		_make_buttons_dry(child)


func _play_interface_sfx(id: String) -> void:
	var sfx := get_node_or_null("/root/UnilearnSFX")

	if sfx != null and sfx.has_method("play"):
		sfx.call("play", id)

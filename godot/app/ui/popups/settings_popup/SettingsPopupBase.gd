extends CanvasLayer

@warning_ignore_start("unused_signal")

signal sfx_changed(enabled: bool)
signal apollo_changed(enabled: bool)
signal reduce_motion_changed(enabled: bool)
signal reset_camera_requested
signal logout_requested
signal closed

@warning_ignore_restore("unused_signal")

const FONT_PATH := "res://assets/fonts/JockeyOne-Regular.ttf"

const POPUP_SLIDE_DURATION := 0.42
const POPUP_FADE_DURATION := 0.22
const DIM_FADE_DURATION := 0.26
const POPUP_SIDE_PADDING := 80.0

const BUTTON_PRESS_SCALE := Vector2(0.88, 0.88)
const BUTTON_RELEASE_SCALE := Vector2(1.10, 1.10)

const AI_SIMULATED_BUTTON_DOWN_TIME := 0.14
const AI_SIMULATED_BUTTON_UP_WAIT_TIME := 0.10

const FALLBACK_COLOR_ON := Color.WHITE

@export var panel_width_ratio: float = 0.96
@export var panel_max_width: float = 1380.0

@export var content_max_width: float = 860.0

@export var button_height: float = 116.0
@export var button_font_size: int = 54
@export var panel_padding_x: int = 34
@export var panel_padding_y: int = 34

var sfx_enabled: bool = true
var apollo_enabled: bool = true
var reduce_motion_enabled: bool = false

@warning_ignore_start("unused_private_class_variable")

var _root: Control
var _dim: ColorRect
var _slide_root: Control
var _panel: PanelContainer
var _content: VBoxContainer

var _sfx_button: Button
var _apollo_button: Button
var _motion_button: Button
var _theme_button: Button
var _reset_button: Button
var _logout_button: Button

var _lines: Array[ColorRect] = []

var _center_position := Vector2.ZERO
var _closing := false
var _popup_tween: Tween
var _button_tween: Tween
var _app_font: Font = null

var _settings_node: Node = null
var _sfx_node: Node = null

var _style_cache: Dictionary = {}

var _last_prepared_viewport_size := Vector2(-1, -1)
var _last_panel_size := Vector2(-1, -1)

@warning_ignore_restore("unused_private_class_variable")


func _motion_duration(duration: float) -> float:
	return 0.0 if reduce_motion_enabled else duration


func _should_reduce_motion() -> bool:
	return reduce_motion_enabled


func setup(
	_sfx_enabled: bool = true,
	_apollo_enabled: bool = true,
	_reduce_motion_enabled: bool = false
) -> void:
	sfx_enabled = _sfx_enabled
	apollo_enabled = _apollo_enabled
	reduce_motion_enabled = _reduce_motion_enabled

	if is_inside_tree():
		_sync_from_settings()
		_refresh_theme_live()


func _ready() -> void:
	layer = 1200
	process_mode = Node.PROCESS_MODE_ALWAYS

	_settings_node = get_node_or_null("/root/UnilearnUserSettings")
	_sfx_node = get_node_or_null("/root/UnilearnSFX")
	_app_font = load(FONT_PATH) as Font

	_sync_from_settings()
	_connect_settings_signal()

	_build_ui()
	_refresh_theme_live()

	await get_tree().process_frame
	await get_tree().process_frame

	if not is_inside_tree() or _closing:
		return

	await _prepare_center_position()

	if not is_inside_tree() or _closing:
		return

	await _play_intro()


func _connect_settings_signal() -> void:
	if _settings_node == null:
		return

	if not _settings_node.has_signal("settings_changed"):
		return

	var callable := Callable(self, "_on_settings_changed")

	if not _settings_node.settings_changed.is_connected(callable):
		_settings_node.settings_changed.connect(callable)


func _on_settings_changed() -> void:
	_sync_from_settings()
	_refresh_theme_live()


func _sync_from_settings() -> void:
	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")

	if _settings_node == null:
		return

	if "sfx_enabled" in _settings_node:
		sfx_enabled = bool(_settings_node.sfx_enabled)

	if "apollo_enabled" in _settings_node:
		apollo_enabled = bool(_settings_node.apollo_enabled)

	if "reduce_motion_enabled" in _settings_node:
		reduce_motion_enabled = bool(_settings_node.reduce_motion_enabled)


func _refresh_theme_live() -> void:
	_style_cache.clear()

	if is_instance_valid(_panel):
		_panel.add_theme_stylebox_override("panel", _panel_style())

	for line in _lines:
		if is_instance_valid(line):
			line.color = _theme_line_color()

	for button in [
		_sfx_button,
		_apollo_button,
		_motion_button,
		_theme_button,
		_reset_button,
		_logout_button
	]:
		if is_instance_valid(button):
			_update_button_styles(button)

	_refresh_theme()
	_update_button_texts()


func simulate_ai_setting_tap(action_id: String) -> bool:
	if _closing:
		return false

	_sync_from_settings()

	if _is_ai_action_already_applied(action_id):
		return true

	var button := _button_for_ai_action(action_id)

	if not is_instance_valid(button):
		return false

	_on_button_down(button)
	_play_sfx("toggle")

	await get_tree().create_timer(_motion_duration(AI_SIMULATED_BUTTON_DOWN_TIME)).timeout

	if not is_instance_valid(button) or _closing:
		return false

	_apply_ai_setting_action(action_id)

	_on_button_up(button)

	await get_tree().create_timer(_motion_duration(AI_SIMULATED_BUTTON_UP_WAIT_TIME)).timeout

	return true


func _is_ai_action_already_applied(action_id: String) -> bool:
	_sync_from_settings()

	match action_id:
		"sfx_on":
			return sfx_enabled

		"sfx_off":
			return not sfx_enabled

		"wake_word_detection_on":
			return apollo_enabled

		"wake_word_detection_off":
			return not apollo_enabled

		"reduce_motion_on":
			return reduce_motion_enabled

		"reduce_motion_off":
			return not reduce_motion_enabled

		"theme_dark":
			return _theme_dark_mode()

		"theme_light":
			return not _theme_dark_mode()

		_:
			return false


func _apply_ai_setting_action(action_id: String) -> bool:
	match action_id:
		"sfx_on":
			_set_sfx_setting(true)

		"sfx_off":
			_set_sfx_setting(false)

		"wake_word_detection_on":
			_set_apollo_setting(true)

		"wake_word_detection_off":
			_set_apollo_setting(false)

		"reduce_motion_on":
			_set_reduce_motion_setting(true)

		"reduce_motion_off":
			_set_reduce_motion_setting(false)

		"theme_dark":
			_set_theme_accent_setting(true)

		"theme_light":
			_set_theme_accent_setting(false)

		_:
			return false

	return true


func _button_for_ai_action(action_id: String) -> Button:
	match action_id:
		"sfx_on", "sfx_off":
			return _sfx_button

		"wake_word_detection_on", "wake_word_detection_off":
			return _apollo_button

		"reduce_motion_on", "reduce_motion_off":
			return _motion_button

		"theme_dark", "theme_light":
			return _theme_button

		_:
			return null


func _set_sfx_setting(value: bool) -> void:
	if sfx_enabled == value:
		return

	if _settings_node != null and _settings_node.has_method("set_sfx_enabled"):
		_settings_node.set_sfx_enabled(value)
	else:
		sfx_enabled = value
		_refresh_theme_live()

	_update_sfx_node_live(value)
	sfx_changed.emit(value)


func _set_apollo_setting(value: bool) -> void:
	if apollo_enabled == value:
		return

	if _settings_node != null:
		if _settings_node.has_method("set_wake_word_detection_enabled"):
			_settings_node.set_wake_word_detection_enabled(value)
		elif _settings_node.has_method("set_apollo_enabled"):
			_settings_node.set_apollo_enabled(value)
		else:
			apollo_enabled = value
			_refresh_theme_live()
	else:
		apollo_enabled = value
		_refresh_theme_live()

	apollo_changed.emit(value)


func _set_reduce_motion_setting(value: bool) -> void:
	if reduce_motion_enabled == value:
		return

	if _settings_node != null and _settings_node.has_method("set_reduce_motion_enabled"):
		_settings_node.set_reduce_motion_enabled(value)
	else:
		reduce_motion_enabled = value
		_refresh_theme_live()

	reduce_motion_changed.emit(value)


func _set_theme_accent_setting(dark_mode_value: bool) -> void:
	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")

	if _settings_node == null:
		return

	if _theme_dark_mode() == dark_mode_value:
		return

	if _settings_node.has_method("set_theme_dark_mode"):
		_settings_node.set_theme_dark_mode(dark_mode_value)
		return

	if _settings_node.has_method("set_theme_accent_name"):
		_settings_node.set_theme_accent_name("purple" if dark_mode_value else "orange")


func _toggle_theme_accent_setting() -> void:
	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")

	if _settings_node == null:
		return

	if _settings_node.has_method("set_theme_dark_mode"):
		var current := true

		if "theme_dark_mode" in _settings_node:
			current = bool(_settings_node.theme_dark_mode)

		_settings_node.set_theme_dark_mode(not current)
		return

	if _settings_node.has_method("toggle_theme_accent"):
		_settings_node.toggle_theme_accent()


func _update_sfx_node_live(value: bool) -> void:
	if _sfx_node == null:
		_sfx_node = get_node_or_null("/root/UnilearnSFX")

	if _sfx_node == null:
		return

	if _sfx_node.has_method("set_enabled"):
		_sfx_node.set_enabled(value)
	elif "enabled" in _sfx_node:
		_sfx_node.enabled = value


func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		await get_tree().process_frame

		if not is_inside_tree() or _closing:
			return

		await _prepare_center_position()


func close_popup(action_after_close: String = "") -> void:
	if _closing:
		return

	_closing = true
	_play_sfx("close")

	if action_after_close == "reset_camera":
		reset_camera_requested.emit()
		action_after_close = ""

	if _popup_tween:
		_popup_tween.kill()

	if _button_tween:
		_button_tween.kill()

	if not is_inside_tree() or get_viewport() == null:
		if action_after_close == "logout":
			_clear_user_runtime_cache()
			logout_requested.emit()

		closed.emit()
		queue_free()
		return

	if _should_reduce_motion():
		_slide_root.position = _center_position
		_slide_root.modulate.a = 0.0
		_dim.modulate.a = 0.0

		if action_after_close == "logout":
			_clear_user_runtime_cache()
			logout_requested.emit()

		closed.emit()
		queue_free()
		return

	_slide_root.position = _center_position
	_slide_root.modulate.a = 1.0

	_popup_tween = create_tween()
	_popup_tween.set_parallel(true)

	_popup_tween.tween_property(_slide_root, "position", _get_right_offscreen_position(), POPUP_SLIDE_DURATION)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)

	_popup_tween.tween_property(_slide_root, "modulate:a", 0.0, POPUP_FADE_DURATION)\
		.set_delay(max(0.0, POPUP_SLIDE_DURATION - POPUP_FADE_DURATION))\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)

	_popup_tween.tween_property(_dim, "modulate:a", 0.0, DIM_FADE_DURATION)\
		.set_delay(max(0.0, POPUP_SLIDE_DURATION - DIM_FADE_DURATION))\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)

	await _popup_tween.finished

	if action_after_close == "logout":
		_clear_user_runtime_cache()
		logout_requested.emit()

	closed.emit()
	queue_free()


func _clear_user_runtime_cache() -> void:
	if has_node("/root/PlanetCardsCache"):
		PlanetCardsCache.clear_cache()


# -----------------------------------------------------------------------------
# Split-script virtual method declarations for inherited settings popup layers.
# -----------------------------------------------------------------------------
func _build_ui() -> void:
	pass

func _prepare_center_position() -> void:
	pass

func _play_intro() -> void:
	pass

func _refresh_theme() -> void:
	pass

func _update_button_texts() -> void:
	pass

func _get_left_offscreen_position() -> Vector2:
	return Vector2.ZERO

func _get_right_offscreen_position() -> Vector2:
	return Vector2.ZERO

func _panel_style() -> StyleBoxFlat:
	return StyleBoxFlat.new()

func _button_style(_color: Color) -> StyleBoxFlat:
	return StyleBoxFlat.new()

func _theme_accent_color() -> Color:
	if _settings_node != null and _settings_node.has_method("get_accent_color"):
		return _settings_node.call("get_accent_color")

	return Color.WHITE

func _theme_accent_label() -> String:
	if _settings_node != null:
		if "theme_accent_name" in _settings_node:
			var accent := str(_settings_node.theme_accent_name).strip_edges().to_upper()
			return accent if not accent.is_empty() else "ACCENT"

		if "theme_dark_mode" in _settings_node:
			return "PURPLE" if bool(_settings_node.theme_dark_mode) else "ORANGE"

	return "ACCENT"

func _theme_dark_mode() -> bool:
	if _settings_node != null and "theme_dark_mode" in _settings_node:
		return bool(_settings_node.theme_dark_mode)

	return true

func _theme_panel_color() -> Color:
	if _settings_node != null and _settings_node.has_method("get_panel_color"):
		return _settings_node.call("get_panel_color")

	return Color(0, 0, 0, 0.84)

func _theme_text_color() -> Color:
	if _settings_node != null and _settings_node.has_method("get_text_color"):
		return _settings_node.call("get_text_color")

	return Color.WHITE

func _theme_line_color() -> Color:
	if _settings_node != null and _settings_node.has_method("get_line_color"):
		return _settings_node.call("get_line_color")

	return Color.WHITE

func _theme_hover_color() -> Color:
	return Color(1, 1, 1, 0.08)

func _theme_pressed_color() -> Color:
	return Color(1, 1, 1, 0.16)

func _apply_app_font(_control: Control) -> void:
	pass

func _play_sfx(_id: String) -> void:
	pass

func _create_button(_label: String, _danger: bool = false) -> Button:
	return Button.new()

func _add_line() -> void:
	pass

func _on_button_down(_button: Button) -> void:
	pass

func _on_button_up(_button: Button) -> void:
	pass

func _toggle_theme_accent() -> void:
	_toggle_theme_accent_setting()

func _update_button_styles(_button: Button) -> void:
	pass

func _set_button_color(_button: Button, _color: Color) -> void:
	pass

func _tween_button_scale(_button: Button, _target_scale: Vector2, _duration: float) -> void:
	pass

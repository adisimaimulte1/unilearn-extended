extends CanvasLayer

@warning_ignore("unused_signal")
signal item_pressed(item_id: String)

const PLANET_CARDS_POPUP_SCRIPT := preload("res://app/ui/popups/UnilearnPlanetCardsPopup.gd")
const SETTINGS_POPUP_SCRIPT := preload("res://app/ui/popups/UnilearnSettingsPopup.gd")

const BUTTON_PRESS_SCALE := Vector2(0.88, 0.88)
const BUTTON_RELEASE_SCALE := Vector2(1.10, 1.10)
const BUTTON_DOWN_TIME := 0.055
const BUTTON_UP_TIME := 0.11
const BUTTON_SETTLE_TIME := 0.10

const AI_MENU_HANDLE_DOWN_TIME := 0.22
const AI_MENU_ICON_DOWN_TIME := 0.20
const AI_MENU_HANDLE_AFTER_SNAP_WAIT := 0.58
const AI_MENU_ICON_AFTER_TAP_WAIT := 0.46

@export var arrow_texture_path: String = "res://assets/app/buttons/button_arrow.png"
@export var settings_texture_path: String = "res://assets/app/buttons/button_settings.png"
@export var help_texture_path: String = "res://assets/app/buttons/button_question.png"
@export var cards_texture_path: String = "res://assets/app/buttons/button_card.png"
@export var achievements_texture_path: String = "res://assets/app/buttons/button_star.png"
@export var playgrounds_texture_path: String = "res://assets/app/buttons/button_galaxy.png"

@export var handle_size: float = 132.0
@export var handle_icon_max_width: int = 118

@export var icon_size: float = 114.0
@export var menu_icon_max_width: int = 100

@export var icon_spacing: float = 18.0
@export var group_horizontal_padding: float = 24.0
@export var group_vertical_padding: float = 20.0

@export var bottom_padding: float = 46.0
@export var open_lift: float = 175.0
@export var arrow_menu_gap: float = 22.0
@export var drag_distance_to_open: float = 175.0
@export var snap_threshold: float = 0.42
@export var drag_deadzone: float = 6.0

@export var group_border_width: int = 6
@export var group_border_color: Color = Color(1.0, 1.0, 1.0, 0.97)
@export var group_background_color: Color = Color(1.0, 1.0, 1.0, 0.015)

@export var icon_hover_color: Color = Color(1.0, 1.0, 1.0, 0.10)
@export var icon_pressed_color: Color = Color(1.0, 0.78, 0.18, 0.20)

@export var snap_duration: float = 0.34

@warning_ignore_start("unused_private_class_variable")

var _drag_started_from_open: bool = false
var is_open: bool = false

var _icons_origin_y: Array[float] = []

var _root: Control
var _panel: Panel
var _handle: Button

var _icon_buttons: Array[Button] = []
var _button_tweens: Dictionary = {}

var _progress: float = -999.0
var _dragging: bool = false
var _drag_started: bool = false
var _drag_start_y: float = 0.0
var _drag_start_progress: float = 0.0
var _active_touch_index: int = -1

var _snap_tween: Tween
var _settings_popup: UnilearnSettingsPopup = null
var _planet_cards_popup: UnilearnPlanetCardsPopup = null

var sfx_enabled: bool = true
var apollo_enabled: bool = true
var reduce_motion_enabled: bool = false

var _settings_node: Node = null
var _sfx_node: Node = null

var _texture_cache: Dictionary = {}
var _style_cache: Dictionary = {}

var _last_layout_size := Vector2(-1, -1)
var _last_applied_progress: float = -999.0
var _last_applied_viewport_size := Vector2(-1, -1)

var _ai_navigation_busy := false

@warning_ignore_restore("unused_private_class_variable")


func _ready() -> void:
	layer = 950
	process_mode = Node.PROCESS_MODE_ALWAYS

	_cache_singletons()
	_load_local_settings()
	_build_ui()

	await get_tree().process_frame

	_layout()
	_apply_progress(0.0)


func _cache_singletons() -> void:
	_settings_node = get_node_or_null("/root/UnilearnUserSettings")
	_sfx_node = get_node_or_null("/root/UnilearnSFX")


func _load_local_settings() -> void:
	if _settings_node == null:
		return

	sfx_enabled = bool(_settings_node.get("sfx_enabled"))
	apollo_enabled = bool(_settings_node.get("apollo_enabled"))
	reduce_motion_enabled = bool(_settings_node.get("reduce_motion_enabled"))


func get_app_location() -> String:
	if is_instance_valid(_settings_popup):
		return "settings"

	if is_instance_valid(_planet_cards_popup):
		return "planet_cards"

	if is_open:
		return "menu"

	return "home"


func is_menu_open() -> bool:
	return is_open


func has_open_popup() -> bool:
	return is_instance_valid(_settings_popup) or is_instance_valid(_planet_cards_popup)


func simulate_ai_enter_menu() -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	await _navigate_home_for_ai()

	if is_open:
		_ai_navigation_busy = false
		return

	await _simulate_handle_tap_to_state(true)

	_ai_navigation_busy = false


func simulate_ai_exit_menu() -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	await _navigate_home_for_ai()

	if not is_open:
		_ai_navigation_busy = false
		return

	await _simulate_handle_tap_to_state(false)

	_ai_navigation_busy = false


func simulate_ai_enter_settings() -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	if is_instance_valid(_settings_popup):
		_ai_navigation_busy = false
		return

	if is_instance_valid(_planet_cards_popup):
		await _close_planet_cards_popup_for_ai()

	await _ensure_menu_open_for_ai()
	await _simulate_icon_tap("settings")

	_ai_navigation_busy = false


func simulate_ai_exit_settings() -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	if is_instance_valid(_settings_popup):
		await _close_settings_popup_for_ai()

	_ai_navigation_busy = false


func simulate_ai_enter_planet_cards() -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	if is_instance_valid(_planet_cards_popup):
		_ai_navigation_busy = false
		return

	if is_instance_valid(_settings_popup):
		await _close_settings_popup_for_ai()

	await _ensure_menu_open_for_ai()
	await _simulate_icon_tap("cards")

	_ai_navigation_busy = false


func simulate_ai_exit_planet_cards() -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	if is_instance_valid(_planet_cards_popup):
		await _close_planet_cards_popup_for_ai()

	_ai_navigation_busy = false


func simulate_ai_go_home() -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	await _navigate_home_for_ai()

	if is_open:
		await _simulate_handle_tap_to_state(false)

	_ai_navigation_busy = false


func simulate_ai_create_planet(prompt: String) -> void:
	if _ai_navigation_busy:
		return

	_ai_navigation_busy = true

	if prompt.strip_edges().is_empty():
		prompt = "planet"

	if is_instance_valid(_settings_popup):
		await _close_settings_popup_for_ai()

	if not is_instance_valid(_planet_cards_popup):
		await _ensure_menu_open_for_ai()
		await _simulate_icon_tap("cards")

	if is_instance_valid(_planet_cards_popup):
		if _planet_cards_popup.has_method("simulate_ai_create_planet"):
			await _planet_cards_popup.simulate_ai_create_planet(prompt)

	_ai_navigation_busy = false


func _navigate_home_for_ai() -> void:
	if is_instance_valid(_settings_popup):
		await _close_settings_popup_for_ai()

	if is_instance_valid(_planet_cards_popup):
		await _close_planet_cards_popup_for_ai()

	await get_tree().process_frame


func _close_settings_popup_for_ai() -> void:
	if not is_instance_valid(_settings_popup):
		return

	var popup := _settings_popup
	popup.close_popup()

	if is_instance_valid(popup):
		await popup.closed

	await get_tree().process_frame


func _close_planet_cards_popup_for_ai() -> void:
	if not is_instance_valid(_planet_cards_popup):
		return

	var popup := _planet_cards_popup
	popup.close_popup()

	if is_instance_valid(popup):
		await popup.closed

	await get_tree().process_frame


func _ensure_menu_open_for_ai() -> void:
	if is_open:
		return

	await _simulate_handle_tap_to_state(true)


func _ensure_menu_closed_for_ai() -> void:
	if not is_open:
		return

	await _simulate_handle_tap_to_state(false)


func _simulate_handle_tap_to_state(open_target: bool) -> void:
	if not is_instance_valid(_handle):
		return

	_dragging = false
	_drag_started = false
	_active_touch_index = -1

	_handle.pivot_offset = _handle.size * 0.5

	if reduce_motion_enabled:
		_snap_to(1.0 if open_target else 0.0)
		return

	_tween_button_scale(_handle, BUTTON_PRESS_SCALE, AI_MENU_HANDLE_DOWN_TIME)

	await get_tree().create_timer(AI_MENU_HANDLE_DOWN_TIME).timeout

	if not is_instance_valid(_handle):
		return

	_snap_to(1.0 if open_target else 0.0)
	_tween_button_release(_handle)

	await get_tree().create_timer(max(snap_duration, AI_MENU_HANDLE_AFTER_SNAP_WAIT)).timeout


func _simulate_icon_tap(item_id: String) -> void:
	if item_id.strip_edges().is_empty():
		return

	var button := _find_icon_button(item_id)

	if not is_instance_valid(button):
		_activate_icon(item_id)
		await get_tree().process_frame
		return

	_dragging = false
	_drag_started = false
	_active_touch_index = -1

	_on_icon_button_down(button)

	await get_tree().create_timer(0.0 if reduce_motion_enabled else AI_MENU_ICON_DOWN_TIME).timeout

	if not is_instance_valid(button):
		return

	_on_icon_button_up(button)
	_activate_icon(item_id)

	await get_tree().create_timer(0.0 if reduce_motion_enabled else AI_MENU_ICON_AFTER_TAP_WAIT).timeout


func _find_icon_button(item_id: String) -> Button:
	var clean_id := item_id.strip_edges().to_lower()

	for button in _icon_buttons:
		if not is_instance_valid(button):
			continue

		var clean_name := button.name.strip_edges().to_lower()

		if clean_name == clean_id:
			return button

		if clean_name == clean_id + "button":
			return button

		if clean_name.contains(clean_id):
			return button

	return null


func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_layout()
		_apply_progress(_progress)


func _input(event: InputEvent) -> void:
	if not _dragging:
		return

	if event is InputEventScreenDrag:
		if event.index == _active_touch_index:
			_update_drag(event.position.y)
			get_viewport().set_input_as_handled()

	elif event is InputEventScreenTouch:
		if not event.pressed and event.index == _active_touch_index:
			_finish_drag()
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if _active_touch_index == -2:
			_update_drag(event.position.y)
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _active_touch_index == -2:
			_finish_drag()
			get_viewport().set_input_as_handled()


func is_position_blocking(screen_position: Vector2) -> bool:
	if is_instance_valid(_settings_popup):
		return true

	if is_instance_valid(_planet_cards_popup):
		return true

	if not is_instance_valid(_root):
		return false

	if is_instance_valid(_handle) and _handle.get_global_rect().has_point(screen_position):
		return true

	if is_instance_valid(_panel) and _panel.visible and _panel.get_global_rect().has_point(screen_position):
		return true

	return false


func open_menu() -> void:
	_snap_to(1.0)


func close_menu() -> void:
	_snap_to(0.0)


func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()


# -----------------------------------------------------------------------------
# Split-script virtual method declarations for inherited menu layers.
# -----------------------------------------------------------------------------
func _build_ui() -> void:
	pass

func _layout() -> void:
	pass

func _apply_progress(_value: float) -> void:
	pass

func _snap_to(_target: float) -> void:
	pass

func _update_drag(_current_y: float) -> void:
	pass

func _finish_drag() -> void:
	pass

func _load_texture(_path: String) -> Texture2D:
	return null

func _full_rect(_node: Control) -> void:
	pass

func _group_panel_style(_color: Color, _border_color: Color, _border_width: int) -> StyleBoxFlat:
	return StyleBoxFlat.new()

func _circle_style(_color: Color, _border_color: Color = Color.TRANSPARENT, _border_width: int = 0) -> StyleBoxFlat:
	return StyleBoxFlat.new()

func _play_sfx(_id: String) -> void:
	pass

func _open_settings_popup() -> void:
	pass

func _open_planet_cards_popup() -> void:
	pass

func _add_icon(_item_id: String, _texture_path: String, _fallback_text: String) -> void:
	pass

func _on_icon_button_down(_button: Button) -> void:
	pass

func _on_icon_button_up(_button: Button) -> void:
	pass

func _activate_icon(_item_id: String) -> void:
	pass

func _tween_button_scale(_button: Button, _target_scale: Vector2, _duration: float) -> void:
	pass

func _tween_button_release(_button: Button) -> void:
	pass

func _bounce_button_cancel(_button: Button) -> void:
	pass

func _position_icons_symmetrically() -> void:
	pass

func _update_icon_contents() -> void:
	pass

func _apply_icon_slide(_p: float) -> void:
	pass

func _on_handle_gui_input(_event: InputEvent) -> void:
	pass

func _start_drag(_touch_index: int, _y_position: float) -> void:
	pass

func set_reduce_motion_enabled(enabled: bool) -> void:
	reduce_motion_enabled = enabled

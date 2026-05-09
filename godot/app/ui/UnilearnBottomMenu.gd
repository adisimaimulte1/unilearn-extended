extends CanvasLayer
class_name UnilearnBottomMenu

signal item_pressed(item_id: String)

const SETTINGS_POPUP_SCRIPT := preload("res://app/ui/popups/UnilearnSettingsPopup.gd")

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

var _drag_started_from_open: bool = false
var is_open: bool = false

var _icons_origin_y: Array[float] = []

var _root: Control
var _panel: Panel
var _handle: Button

var _icon_buttons: Array[Button] = []

var _progress: float = 0.0
var _dragging: bool = false
var _drag_started: bool = false
var _drag_start_y: float = 0.0
var _drag_start_progress: float = 0.0
var _active_touch_index: int = -1

var _snap_tween: Tween
var _settings_popup: UnilearnSettingsPopup = null

var sfx_enabled: bool = true
var apollo_enabled: bool = true
var reduce_motion_enabled: bool = false


func _ready() -> void:
	layer = 950
	process_mode = Node.PROCESS_MODE_ALWAYS

	_load_local_settings()

	_build_ui()

	await get_tree().process_frame
	_layout()
	_apply_progress(0.0)


func _load_local_settings() -> void:
	if not has_node("/root/UnilearnUserSettings"):
		return

	var settings := get_node("/root/UnilearnUserSettings")

	sfx_enabled = settings.sfx_enabled
	apollo_enabled = settings.apollo_enabled
	reduce_motion_enabled = settings.reduce_motion_enabled


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

	if not is_instance_valid(_root):
		return false

	if _handle != null and _handle.get_global_rect().has_point(screen_position):
		return true

	if _panel != null and _panel.visible and _panel.get_global_rect().has_point(screen_position):
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


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "BottomMenuRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root)
	_full_rect(_root)

	_panel = Panel.new()
	_panel.name = "FloatingMenuPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.visible = false
	_panel.add_theme_stylebox_override(
		"panel",
		_group_panel_style(group_background_color, group_border_color, group_border_width)
	)
	_root.add_child(_panel)

	_add_icon("help", help_texture_path, "?")
	_add_icon("cards", cards_texture_path, "C")
	_add_icon("achievements", achievements_texture_path, "A")
	_add_icon("playgrounds", playgrounds_texture_path, "U")
	_add_icon("settings", settings_texture_path, "S")

	_handle = Button.new()
	_handle.name = "MenuHandle"
	_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_handle.focus_mode = Control.FOCUS_NONE
	_handle.flat = true
	_handle.custom_minimum_size = Vector2(handle_size, handle_size)
	_handle.icon = _load_texture(arrow_texture_path)
	_handle.expand_icon = true
	_handle.add_theme_constant_override("icon_max_width", handle_icon_max_width)
	_handle.text = "" if _handle.icon != null else "⌃"

	_handle.add_theme_font_size_override("font_size", 52)
	_handle.add_theme_color_override("font_color", Color.WHITE)
	_handle.add_theme_color_override("font_hover_color", Color.WHITE)
	_handle.add_theme_color_override("font_pressed_color", Color("#FFC62D"))

	_handle.add_theme_stylebox_override(
		"normal",
		_circle_style(Color.TRANSPARENT, Color.TRANSPARENT, 0)
	)
	_handle.add_theme_stylebox_override(
		"hover",
		_circle_style(Color(1.0, 1.0, 1.0, 0.08), Color(1.0, 1.0, 1.0, 0.25), 1)
	)
	_handle.add_theme_stylebox_override(
		"pressed",
		_circle_style(Color(1.0, 1.0, 1.0, 0.12), Color(1.0, 1.0, 1.0, 0.45), 1)
	)

	_handle.gui_input.connect(_on_handle_gui_input)
	_root.add_child(_handle)
	_handle.move_to_front()


func _add_icon(item_id: String, texture_path: String, fallback_text: String) -> void:
	var button := Button.new()
	button.name = item_id.capitalize() + "Button"
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	button.clip_contents = false
	button.custom_minimum_size = Vector2(icon_size, icon_size)
	button.text = ""

	button.add_theme_stylebox_override(
		"normal",
		_circle_style(Color.TRANSPARENT, Color.TRANSPARENT, 0)
	)
	button.add_theme_stylebox_override(
		"hover",
		_circle_style(icon_hover_color, Color.TRANSPARENT, 0)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_circle_style(icon_pressed_color, Color.TRANSPARENT, 0)
	)

	var texture := _load_texture(texture_path)
	if texture != null:
		var icon_rect := TextureRect.new()
		icon_rect.name = "CenteredAssetIcon"
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.texture = texture
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.add_child(icon_rect)
	else:
		var label := Label.new()
		label.name = "CenteredFallbackText"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = fallback_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 36)
		label.add_theme_color_override("font_color", Color.WHITE)
		button.add_child(label)

	button.scale = Vector2.ONE
	button.modulate.a = 0.0

	button.pressed.connect(func() -> void:
		if _drag_started:
			return

		_play_sfx("click")

		if not reduce_motion_enabled:
			_bounce_button(button)

		if item_id == "settings":
			_open_settings_popup()
			return

		item_pressed.emit(item_id)
	)

	_panel.add_child(button)
	_icon_buttons.append(button)


func _open_settings_popup() -> void:
	if is_instance_valid(_settings_popup):
		return

	close_menu()
	_play_sfx("whoosh")
	item_pressed.emit("settings")

	_settings_popup = SETTINGS_POPUP_SCRIPT.new()
	_settings_popup.name = "UnilearnSettingsPopup"
	add_child(_settings_popup)

	_settings_popup.setup(sfx_enabled, apollo_enabled, reduce_motion_enabled)

	_settings_popup.sfx_changed.connect(func(enabled: bool) -> void:
		sfx_enabled = enabled

		if has_node("/root/UnilearnUserSettings"):
			get_node("/root/UnilearnUserSettings").set_sfx_enabled(enabled)

		if has_node("/root/UnilearnSFX"):
			get_node("/root/UnilearnSFX").set_enabled(enabled)

		item_pressed.emit("settings_sfx_" + ("on" if enabled else "off"))
	)

	_settings_popup.apollo_changed.connect(func(enabled: bool) -> void:
		apollo_enabled = enabled

		if has_node("/root/UnilearnUserSettings"):
			get_node("/root/UnilearnUserSettings").set_apollo_enabled(enabled)

		item_pressed.emit("settings_apollo_" + ("on" if enabled else "off"))
	)

	_settings_popup.reduce_motion_changed.connect(func(enabled: bool) -> void:
		set_reduce_motion_enabled(enabled)

		if has_node("/root/UnilearnUserSettings"):
			get_node("/root/UnilearnUserSettings").set_reduce_motion_enabled(enabled)

		item_pressed.emit("settings_reduce_motion_" + ("on" if enabled else "off"))
	)

	_settings_popup.reset_camera_requested.connect(func() -> void:
		item_pressed.emit("settings_reset_camera")
	)

	_settings_popup.logout_requested.connect(func() -> void:
		item_pressed.emit("settings_logout")
	)

	_settings_popup.closed.connect(func() -> void:
		_settings_popup = null
	)


func _layout() -> void:
	if not is_instance_valid(_root):
		return

	var count := _icon_buttons.size()
	var icons_total_width := (icon_size * float(count)) + (icon_spacing * float(max(count - 1, 0)))
	var panel_width := icons_total_width + (group_horizontal_padding * 2.0)
	var panel_height := icon_size + (group_vertical_padding * 2.0)

	_panel.size = Vector2(panel_width, panel_height)
	_panel.pivot_offset = _panel.size * 0.5

	_handle.size = Vector2(handle_size, handle_size)
	_handle.pivot_offset = _handle.size * 0.5

	_position_icons_symmetrically()
	_update_icon_contents()
	_handle.move_to_front()
	_apply_progress(_progress)


func _position_icons_symmetrically() -> void:
	if _icon_buttons.is_empty() or not is_instance_valid(_panel):
		return

	_icons_origin_y.clear()

	var count := _icon_buttons.size()
	var center_x := _panel.size.x * 0.5
	var center_y := _panel.size.y * 0.5
	var step := icon_size + icon_spacing
	var middle_index := float(count - 1) * 0.5

	for i in count:
		var button := _icon_buttons[i]
		if not is_instance_valid(button):
			continue

		button.size = Vector2(icon_size, icon_size)
		button.pivot_offset = button.size * 0.5

		var offset_from_middle := float(i) - middle_index
		var icon_center_x := center_x + (offset_from_middle * step)
		var icon_center_y := center_y

		button.position = Vector2(
			icon_center_x - (icon_size * 0.5),
			icon_center_y - (icon_size * 0.5)
		)

		_icons_origin_y.append(button.position.y)


func _update_icon_contents() -> void:
	for button in _icon_buttons:
		if not is_instance_valid(button):
			continue

		var icon_rect := button.get_node_or_null("CenteredAssetIcon") as TextureRect
		if icon_rect != null:
			icon_rect.size = Vector2(menu_icon_max_width, menu_icon_max_width)
			icon_rect.position = (button.size - icon_rect.size) * 0.5
			icon_rect.pivot_offset = icon_rect.size * 0.5

		var label := button.get_node_or_null("CenteredFallbackText") as Label
		if label != null:
			label.position = Vector2.ZERO
			label.size = button.size


func _apply_progress(value: float) -> void:
	_progress = clamp(value, 0.0, 1.0)

	if not is_instance_valid(_panel) or not is_instance_valid(_handle):
		return

	var viewport_size := get_viewport().get_visible_rect().size

	var closed_handle_y := viewport_size.y - bottom_padding - handle_size
	var open_handle_y := closed_handle_y - open_lift

	var closed_panel_y := viewport_size.y + 8.0
	var open_panel_y := open_handle_y + handle_size + arrow_menu_gap

	_handle.position = Vector2(
		(viewport_size.x - handle_size) * 0.5,
		lerp(closed_handle_y, open_handle_y, _progress)
	)

	_handle.rotation = lerp(0.0, PI, _progress)
	_handle.scale = Vector2.ONE * lerp(1.0, 0.92, _progress)

	_panel.position = Vector2(
		(viewport_size.x - _panel.size.x) * 0.5,
		lerp(closed_panel_y, open_panel_y, _progress)
	)

	_panel.visible = _progress > 0.01
	_panel.modulate.a = smoothstep(0.05, 0.6, _progress)

	_apply_icon_slide(_progress)


func _apply_icon_slide(p: float) -> void:
	var local_p := smoothstep(0.16, 0.8, p)

	for button in _icon_buttons:
		if not is_instance_valid(button):
			continue

		button.modulate.a = local_p
		button.scale = Vector2.ONE

func _snap_to(target: float) -> void:
	target = clamp(target, 0.0, 1.0)

	if _snap_tween != null and _snap_tween.is_valid():
		_snap_tween.kill()

	is_open = target >= 0.5
	_play_sfx("open" if is_open else "close")

	if reduce_motion_enabled:
		_apply_progress(target)

		if target <= 0.0 and is_instance_valid(_panel):
			_panel.visible = false

		return

	_snap_tween = create_tween()
	_snap_tween.set_trans(Tween.TRANS_SINE)
	_snap_tween.set_ease(Tween.EASE_OUT)

	_snap_tween.tween_method(
		func(v: float) -> void:
			_apply_progress(v),
		_progress,
		target,
		snap_duration
	)

	if target <= 0.0:
		_snap_tween.finished.connect(func() -> void:
			if is_instance_valid(_panel):
				_panel.visible = false
		)


func _on_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_start_drag(event.index, event.position.y)
			get_viewport().set_input_as_handled()
		else:
			if _dragging and event.index == _active_touch_index:
				_finish_drag()
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		if _dragging and event.index == _active_touch_index:
			_update_drag(event.position.y)
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if event.pressed:
			_start_drag(-2, event.position.y)
			get_viewport().set_input_as_handled()
		else:
			if _dragging and _active_touch_index == -2:
				_finish_drag()
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if _dragging and _active_touch_index == -2:
			_update_drag(event.position.y)
			get_viewport().set_input_as_handled()


func _start_drag(touch_index: int, y_position: float) -> void:
	if _snap_tween != null and _snap_tween.is_valid():
		_snap_tween.kill()

	_dragging = true
	_drag_started = false
	_drag_started_from_open = is_open
	_active_touch_index = touch_index
	_drag_start_y = y_position
	_drag_start_progress = _progress


func _update_drag(current_y: float) -> void:
	var dragged_up := _drag_start_y - current_y

	if abs(dragged_up) > drag_deadzone:
		_drag_started = true

	if _drag_started_from_open:
		_apply_progress(1.0)
		return

	var next_progress := _drag_start_progress + (dragged_up / drag_distance_to_open)
	_apply_progress(next_progress)


func _finish_drag() -> void:
	_dragging = false
	_active_touch_index = -1

	if not _drag_started:
		toggle_menu()
		_drag_started_from_open = false
		return

	if _drag_started_from_open:
		_snap_to(1.0)
		_drag_started_from_open = false
		return

	if _progress >= snap_threshold:
		_snap_to(1.0)
	else:
		_snap_to(0.0)

	_drag_started_from_open = false


func _bounce_button(button: Button) -> void:
	button.pivot_offset = button.size * 0.5

	var t := create_tween()
	t.set_trans(Tween.TRANS_BACK)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(button, "scale", Vector2.ONE * 0.88, 0.055)
	t.tween_property(button, "scale", Vector2.ONE * 1.10, 0.11)
	t.tween_property(button, "scale", Vector2.ONE, 0.10)


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null

	if not ResourceLoader.exists(path):
		push_warning("Menu texture missing: " + path)
		return null

	return load(path) as Texture2D


func _full_rect(node: Control) -> void:
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 1.0
	node.anchor_bottom = 1.0
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0


func _group_panel_style(color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(38)
	return style


func _circle_style(color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(999)
	return style


func set_reduce_motion_enabled(enabled: bool) -> void:
	reduce_motion_enabled = enabled

	if reduce_motion_enabled:
		if _snap_tween != null and _snap_tween.is_valid():
			_snap_tween.kill()

		_apply_progress(1.0 if is_open else 0.0)


func _play_sfx(id: String) -> void:
	if has_node("/root/UnilearnSFX"):
		get_node("/root/UnilearnSFX").play(id)

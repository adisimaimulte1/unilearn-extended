extends CanvasLayer
class_name UnilearnPlanetCardsPopup

signal closed

const FONT_PATH := "res://assets/fonts/JockeyOne-Regular.ttf"
const PREVIEW_SCRIPT := preload("res://addons/UnilearnLib/planet_cards/PlanetCardPreview.gd")
const DETAILS_SCRIPT := preload("res://addons/UnilearnLib/planet_cards/PlanetCardDetails.gd")

const POPUP_SLIDE_DURATION := 0.42
const POPUP_FADE_DURATION := 0.22
const DIM_FADE_DURATION := 0.26
const POPUP_SIDE_PADDING := 80.0

const CARD_ENTER_OFFSET := Vector2(0, 42)
const CARD_ENTER_SCALE := Vector2(0.92, 0.92)
const CARD_ENTER_TIME := 0.28
const CARD_ENTER_STAGGER := 0.035

const COLOR_PANEL := Color(0.0, 0.0, 0.0, 0.82)
const COLOR_BORDER := Color.WHITE
const COLOR_TEXT := Color.WHITE
const COLOR_SUBTITLE := Color(1.0, 1.0, 1.0, 0.58)
const COLOR_PLACEHOLDER := Color(1.0, 1.0, 1.0, 0.42)
const COLOR_SCROLL_TRACK := Color(1.0, 1.0, 1.0, 0.06)
const COLOR_SCROLL_GRAB := Color(1.0, 1.0, 1.0, 0.34)
const COLOR_SCROLL_GRAB_HOVER := Color(1.0, 1.0, 1.0, 0.52)

const ADD_BUTTON_PRESS_SCALE := Vector2(0.88, 0.88)
const ADD_BUTTON_RELEASE_SCALE := Vector2(1.10, 1.10)
const ADD_BUTTON_DOWN_TIME := 0.055
const ADD_BUTTON_UP_TIME := 0.11
const ADD_BUTTON_SETTLE_TIME := 0.10

const SEARCH_PLACEHOLDER := "Search planets..."

@export var panel_width_ratio: float = 0.96
@export var panel_height_ratio: float = 0.96
@export var panel_max_width: float = 1380.0
@export var panel_max_height: float = 1260.0
@export var panel_padding_x: int = 34
@export var panel_padding_y: int = 34
@export var columns: int = 2

var reduce_motion_enabled: bool = false

var _root: Control
var _dim: ColorRect
var _slide_root: Control
var _panel: PanelContainer
var _body_root: Control

var _main_view: Control
var _details_view: PlanetCardDetails
var _grid: GridContainer
var _search_box: LineEdit
var _search_clear_button: Control
var _scroll: ScrollContainer
var _scroll_margin: MarginContainer
var _scroll_content: VBoxContainer
var _no_results_label: Label

var _add_button: Control
var _add_button_hovered := false
var _add_button_pressed := false
var _add_button_pointer_id := -999
var _add_button_bounce_tween: Tween

var _scroll_pointer_id := -999
var _scroll_dragging := false
var _scroll_start_y := 0.0
var _scroll_last_y := 0.0
var _scroll_start_value := 0
var _scroll_last_time := 0.0
var _scroll_velocity := 0.0
var _scroll_drag_deadzone := 8.0
var _scroll_wheel_impulse := 1350.0
var _scroll_friction := 7.5
var _scroll_max_velocity := 3600.0

var _keyboard_was_visible := false

var _all_planets: Array[PlanetData] = []
var _center_position := Vector2.ZERO
var _closing := false
var _popup_tween: Tween
var _app_font: Font = null

var _grid_ready := false
var _rebuild_generation := 0


func setup(_reduce_motion_enabled: bool = false) -> void:
	reduce_motion_enabled = _reduce_motion_enabled


func _ready() -> void:
	layer = 1200
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

	_app_font = load(FONT_PATH) as Font
	_all_planets = PlanetDataLibrary.get_all_planets()

	_build_ui()

	await get_tree().process_frame
	await get_tree().process_frame

	_prepare_center_position()
	_style_scroll_bar()
	_update_no_results_height()

	await _play_intro()

	if not is_inside_tree() or _closing:
		return

	if not _should_reduce_motion():
		await get_tree().create_timer(0.06).timeout

	if not is_inside_tree() or _closing:
		return

	_grid_ready = true
	_rebuild_grid("")


func _process(delta: float) -> void:
	_update_search_focus_from_keyboard()
	_apply_scroll_inertia(delta)


func _input(event: InputEvent) -> void:
	_handle_slippery_scroll_input(event)
	_handle_add_button_release_input(event)


func _handle_add_button_release_input(event: InputEvent) -> void:
	if _add_button_pointer_id == -999:
		return

	if event is InputEventScreenDrag:
		if event.index == _add_button_pointer_id:
			_update_add_button_pressed_visual(event.position)

	elif event is InputEventScreenTouch:
		if not event.pressed and event.index == _add_button_pointer_id:
			_finish_add_button_press(event.position)
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if _add_button_pointer_id == -2:
			_update_add_button_pressed_visual(event.position)

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _add_button_pointer_id == -2:
			_finish_add_button_press(event.position)
			get_viewport().set_input_as_handled()


func _handle_slippery_scroll_input(event: InputEvent) -> void:
	if not is_instance_valid(_scroll):
		return

	if event is InputEventMouseButton:
		if not _is_inside_scroll(event.position):
			return

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_scroll_velocity += _scroll_wheel_impulse
			_scroll_velocity = clamp(_scroll_velocity, -_scroll_max_velocity, _scroll_max_velocity)
			get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_scroll_velocity -= _scroll_wheel_impulse
			_scroll_velocity = clamp(_scroll_velocity, -_scroll_max_velocity, _scroll_max_velocity)
			get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _is_inside_scroll(event.position) and not _is_inside_add_button(event.position):
					_scroll_pointer_id = -2
					_scroll_dragging = false
					_scroll_start_y = event.position.y
					_scroll_last_y = event.position.y
					_scroll_start_value = _scroll.scroll_vertical
					_scroll_last_time = Time.get_ticks_msec() / 1000.0
					_scroll_velocity = 0.0
			else:
				if _scroll_pointer_id == -2:
					if _scroll_dragging:
						get_viewport().set_input_as_handled()

					_scroll_pointer_id = -999
					_scroll_dragging = false

	elif event is InputEventMouseMotion:
		if _scroll_pointer_id == -2:
			_apply_manual_scroll(event.position.y)

			if _scroll_dragging:
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenTouch:
		if event.pressed:
			if _is_inside_scroll(event.position) and not _is_inside_add_button(event.position):
				_scroll_pointer_id = event.index
				_scroll_dragging = false
				_scroll_start_y = event.position.y
				_scroll_last_y = event.position.y
				_scroll_start_value = _scroll.scroll_vertical
				_scroll_last_time = Time.get_ticks_msec() / 1000.0
				_scroll_velocity = 0.0
		else:
			if event.index == _scroll_pointer_id:
				if _scroll_dragging:
					get_viewport().set_input_as_handled()

				_scroll_pointer_id = -999
				_scroll_dragging = false

	elif event is InputEventScreenDrag:
		if event.index == _scroll_pointer_id:
			_apply_manual_scroll(event.position.y)

			if _scroll_dragging:
				get_viewport().set_input_as_handled()


func _apply_manual_scroll(current_y: float) -> void:
	if not is_instance_valid(_scroll):
		return

	var total_delta := _scroll_start_y - current_y

	if abs(total_delta) >= _scroll_drag_deadzone:
		_scroll_dragging = true

	if not _scroll_dragging:
		return

	var now := Time.get_ticks_msec() / 1000.0
	var dt: float = max(0.001, now - _scroll_last_time)
	var frame_delta := _scroll_last_y - current_y

	_scroll_velocity = clamp(frame_delta / dt, -_scroll_max_velocity, _scroll_max_velocity)
	_scroll.scroll_vertical = int(clamp(float(_scroll.scroll_vertical) + frame_delta, 0.0, _get_max_scroll()))

	_scroll_last_y = current_y
	_scroll_last_time = now


func _apply_scroll_inertia(delta: float) -> void:
	if not is_instance_valid(_scroll):
		return

	if _scroll_pointer_id != -999:
		return

	if abs(_scroll_velocity) < 8.0:
		_scroll_velocity = 0.0
		return

	var max_scroll := _get_max_scroll()

	if max_scroll <= 0.0:
		_scroll_velocity = 0.0
		_scroll.scroll_vertical = 0
		return

	var next_scroll := float(_scroll.scroll_vertical) + (_scroll_velocity * delta)

	if next_scroll <= 0.0:
		next_scroll = 0.0
		_scroll_velocity = 0.0

	elif next_scroll >= max_scroll:
		next_scroll = max_scroll
		_scroll_velocity = 0.0

	else:
		_scroll_velocity = lerp(_scroll_velocity, 0.0, 1.0 - exp(-_scroll_friction * delta))

	_scroll.scroll_vertical = int(next_scroll)


func _get_max_scroll() -> float:
	if not is_instance_valid(_scroll):
		return 0.0

	var bar := _scroll.get_v_scroll_bar()

	if bar == null:
		return 0.0

	return max(0.0, bar.max_value - bar.page)


func _is_inside_scroll(screen_position: Vector2) -> bool:
	if not is_instance_valid(_scroll):
		return false

	return _scroll.get_global_rect().has_point(screen_position)


func _is_inside_add_button(screen_position: Vector2) -> bool:
	if not is_instance_valid(_add_button):
		return false

	return _add_button.get_global_rect().has_point(screen_position)


func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		await get_tree().process_frame

		if not is_inside_tree():
			return

		_prepare_center_position()
		_style_scroll_bar()
		_update_no_results_height()


func close_popup() -> void:
	if _closing:
		return

	_closing = true
	_rebuild_generation += 1
	_play_sfx("close")

	if _popup_tween:
		_popup_tween.kill()

	if _add_button_bounce_tween != null and _add_button_bounce_tween.is_valid():
		_add_button_bounce_tween.kill()

	if is_instance_valid(_add_button):
		_add_button.scale = Vector2.ONE

	if not is_inside_tree() or get_viewport() == null:
		closed.emit()
		queue_free()
		return

	if _should_reduce_motion():
		_slide_root.position = _center_position
		_slide_root.modulate.a = 0.0
		_dim.modulate.a = 0.0
		closed.emit()
		queue_free()
		return

	_slide_root.position = _center_position
	_slide_root.modulate.a = 1.0

	_popup_tween = create_tween()
	_popup_tween.set_parallel(true)
	_popup_tween.tween_property(_slide_root, "position", _get_right_offscreen_position(), POPUP_SLIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_popup_tween.tween_property(_slide_root, "modulate:a", 0.0, POPUP_FADE_DURATION).set_delay(max(0.0, POPUP_SLIDE_DURATION - POPUP_FADE_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_popup_tween.tween_property(_dim, "modulate:a", 0.0, DIM_FADE_DURATION).set_delay(max(0.0, POPUP_SLIDE_DURATION - DIM_FADE_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await _popup_tween.finished

	closed.emit()
	queue_free()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "PlanetCardsPopupRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_dim = ColorRect.new()
	_dim.name = "TapOutsideDim"
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0.88)
	_dim.modulate.a = 0.0
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)

	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			_release_search_focus()
			close_popup()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_release_search_focus()
			close_popup()
			get_viewport().set_input_as_handled()
	)

	_slide_root = Control.new()
	_slide_root.name = "PlanetCardsSlideRoot"
	_slide_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide_root.modulate.a = 0.0
	_root.add_child(_slide_root)

	_panel = PanelContainer.new()
	_panel.name = "PlanetCardsPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_slide_root.add_child(_panel)

	_body_root = Control.new()
	_body_root.name = "PlanetCardsBodyRoot"
	_body_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(_body_root)

	_build_main_view()


func _build_main_view() -> void:
	if is_instance_valid(_main_view):
		_main_view.queue_free()

	_main_view = Control.new()
	_main_view.name = "PlanetCardsMainView"
	_main_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body_root.add_child(_main_view)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", panel_padding_x)
	margin.add_theme_constant_override("margin_right", panel_padding_x)
	margin.add_theme_constant_override("margin_top", panel_padding_y)
	margin.add_theme_constant_override("margin_bottom", panel_padding_y)
	_main_view.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "PlanetCardsContent"
	content.add_theme_constant_override("separation", 34)
	margin.add_child(content)

	var title_box := VBoxContainer.new()
	title_box.custom_minimum_size = Vector2(0, 230)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 6)
	content.add_child(title_box)

	var title := Label.new()
	title.text = "PLANET CARDS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 118)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.clip_text = false
	_apply_app_font(title)
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Pick a planet and open its learning card."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 52)
	subtitle.add_theme_color_override("font_color", COLOR_SUBTITLE)
	_apply_app_font(subtitle)
	title_box.add_child(subtitle)

	var search_row_height := 150.0
	var search_gap := 22.0

	var search_row := Control.new()
	search_row.name = "SearchRow"
	search_row.custom_minimum_size = Vector2(0, search_row_height)
	search_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(search_row)

	var search_shell := PanelContainer.new()
	search_shell.name = "SearchShell"
	search_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	search_shell.add_theme_stylebox_override("panel", _search_style())
	search_row.add_child(search_shell)

	_add_button = Control.new()
	_add_button.name = "CreatePlanetButton"
	_add_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_add_button.scale = Vector2.ONE
	search_row.add_child(_add_button)

	_add_button.draw.connect(func() -> void:
		var rect := Rect2(Vector2.ZERO, _add_button.size)
		_add_button.draw_style_box(_square_button_style(false), rect)

		var center := _add_button.size * 0.5
		var plus_length := _add_button.size.y * 0.38
		var plus_thickness := _add_button.size.y * 0.075

		_add_button.draw_line(center + Vector2(-plus_length * 0.5, 0), center + Vector2(plus_length * 0.5, 0), COLOR_TEXT, plus_thickness, true)
		_add_button.draw_line(center + Vector2(0, -plus_length * 0.5), center + Vector2(0, plus_length * 0.5), COLOR_TEXT, plus_thickness, true)
	)

	var layout_search_row := func() -> void:
		var row_width := search_row.size.x
		var row_height := search_row.size.y

		if row_height <= 0.0:
			row_height = search_row_height

		var button_size := row_height
		var search_width: float = max(0.0, row_width - button_size - search_gap)

		search_shell.position = Vector2.ZERO
		search_shell.size = Vector2(search_width, row_height)
		search_shell.custom_minimum_size = search_shell.size

		_add_button.position = Vector2(search_width + search_gap, 0.0)
		_add_button.size = Vector2(button_size, row_height)
		_add_button.custom_minimum_size = _add_button.size
		_add_button.pivot_offset = _add_button.size * 0.5
		_add_button.queue_redraw()

	search_row.resized.connect(func() -> void:
		layout_search_row.call()
	)

	var search_margin := MarginContainer.new()
	search_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	search_margin.add_theme_constant_override("margin_left", 34)
	search_margin.add_theme_constant_override("margin_right", 20)
	search_margin.add_theme_constant_override("margin_top", 0)
	search_margin.add_theme_constant_override("margin_bottom", 0)
	search_shell.add_child(search_margin)

	var search_inner := HBoxContainer.new()
	search_inner.alignment = BoxContainer.ALIGNMENT_CENTER
	search_inner.add_theme_constant_override("separation", 20)
	search_margin.add_child(search_inner)

	var search_icon := _create_search_icon()
	search_inner.add_child(search_icon)

	_search_box = LineEdit.new()
	_search_box.placeholder_text = SEARCH_PLACEHOLDER
	_search_box.custom_minimum_size = Vector2(0, 120)
	_search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_box.clear_button_enabled = false
	_search_box.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_search_box.flat = true
	_search_box.caret_blink = true
	_search_box.caret_blink_interval = 0.42
	_search_box.virtual_keyboard_enabled = true
	_search_box.add_theme_font_size_override("font_size", 66)
	_search_box.add_theme_color_override("font_color", COLOR_TEXT)
	_search_box.add_theme_color_override("font_placeholder_color", COLOR_PLACEHOLDER)
	_search_box.add_theme_color_override("caret_color", COLOR_TEXT)
	_search_box.add_theme_color_override("font_selected_color", Color.BLACK)
	_search_box.add_theme_color_override("selection_color", COLOR_TEXT)
	_search_box.add_theme_stylebox_override("normal", _transparent_line_edit_style())
	_search_box.add_theme_stylebox_override("focus", _transparent_line_edit_style())
	_search_box.add_theme_stylebox_override("read_only", _transparent_line_edit_style())
	_apply_app_font(_search_box)

	_search_box.focus_entered.connect(func() -> void:
		_search_box.placeholder_text = ""
		_keyboard_was_visible = _is_virtual_keyboard_visible()
	)

	_search_box.focus_exited.connect(func() -> void:
		if _search_box.text.strip_edges().is_empty():
			_search_box.placeholder_text = SEARCH_PLACEHOLDER
		_keyboard_was_visible = false
	)

	_search_box.text_submitted.connect(func(_text: String) -> void:
		_release_search_focus()
	)

	_search_box.text_changed.connect(_on_search_text_changed)
	search_inner.add_child(_search_box)

	_search_clear_button = _create_search_clear_button()
	search_inner.add_child(_search_clear_button)
	_update_search_clear_button()

	_add_button.mouse_entered.connect(func() -> void:
		_add_button_hovered = true
		_add_button.queue_redraw()
	)

	_add_button.mouse_exited.connect(func() -> void:
		_add_button_hovered = false
		_add_button.queue_redraw()
	)

	_add_button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			_start_add_button_press(event.index)
			get_viewport().set_input_as_handled()

		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_start_add_button_press(-2)
			get_viewport().set_input_as_handled()
	)

	layout_search_row.call()

	_scroll = ScrollContainer.new()
	_scroll.name = "PlanetCardsScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_scroll.add_theme_constant_override("scrollbar_margin_left", 30)
	content.add_child(_scroll)

	_scroll_margin = MarginContainer.new()
	_scroll_margin.name = "ScrollContentMargin"
	_scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll_margin.add_theme_constant_override("margin_right", 44)
	_scroll.add_child(_scroll_margin)

	_scroll_content = VBoxContainer.new()
	_scroll_content.name = "ScrollContent"
	_scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll_content.add_theme_constant_override("separation", 0)
	_scroll_margin.add_child(_scroll_content)

	_grid = GridContainer.new()
	_grid.name = "PlanetCardsGrid"
	_grid.columns = columns
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_grid.visible = false
	_grid.add_theme_constant_override("h_separation", 24)
	_grid.add_theme_constant_override("v_separation", 26)
	_scroll_content.add_child(_grid)

	_no_results_label = Label.new()
	_no_results_label.name = "NoResultsLabel"
	_no_results_label.text = ""
	_no_results_label.visible = true
	_no_results_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_no_results_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_no_results_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_results_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_no_results_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_no_results_label.add_theme_font_size_override("font_size", 64)
	_no_results_label.add_theme_color_override("font_color", COLOR_SUBTITLE)
	_apply_app_font(_no_results_label)
	_scroll_content.add_child(_no_results_label)

	_scroll.resized.connect(func() -> void:
		_update_no_results_height()
	)

	call_deferred("_style_scroll_bar")
	call_deferred("_update_no_results_height")


func _start_add_button_press(pointer_id: int) -> void:
	if not is_instance_valid(_add_button):
		return

	_add_button_pointer_id = pointer_id
	_add_button_pressed = true
	_add_button.queue_redraw()

	_play_sfx("click")

	if not reduce_motion_enabled:
		_bounce_add_button_down()


func _update_add_button_pressed_visual(screen_position: Vector2) -> void:
	if not is_instance_valid(_add_button):
		return

	var inside := _add_button.get_global_rect().has_point(screen_position)

	if _add_button_pressed != inside:
		_add_button_pressed = inside
		_add_button.queue_redraw()


func _finish_add_button_press(screen_position: Vector2) -> void:
	if not is_instance_valid(_add_button):
		_add_button_pointer_id = -999
		return

	var released_inside := _add_button.get_global_rect().has_point(screen_position)

	_add_button_pointer_id = -999
	_add_button_pressed = false
	_add_button.queue_redraw()

	if released_inside:
		if not reduce_motion_enabled:
			_bounce_add_button_release()

		_press_create_planet_button(_add_button)
	else:
		if not reduce_motion_enabled:
			_bounce_add_button_cancel()


func _press_create_planet_button(button: Control) -> void:
	_release_search_focus()

	print("Create new planet button pressed.")


func _bounce_add_button_down() -> void:
	if not is_instance_valid(_add_button):
		return

	if _add_button_bounce_tween != null and _add_button_bounce_tween.is_valid():
		_add_button_bounce_tween.kill()

	_add_button.pivot_offset = _add_button.size * 0.5

	_add_button_bounce_tween = create_tween()
	_add_button_bounce_tween.set_trans(Tween.TRANS_BACK)
	_add_button_bounce_tween.set_ease(Tween.EASE_OUT)
	_add_button_bounce_tween.tween_property(_add_button, "scale", ADD_BUTTON_PRESS_SCALE, ADD_BUTTON_DOWN_TIME)


func _bounce_add_button_release() -> void:
	if not is_instance_valid(_add_button):
		return

	if _add_button_bounce_tween != null and _add_button_bounce_tween.is_valid():
		_add_button_bounce_tween.kill()

	_add_button.pivot_offset = _add_button.size * 0.5

	_add_button_bounce_tween = create_tween()
	_add_button_bounce_tween.set_trans(Tween.TRANS_BACK)
	_add_button_bounce_tween.set_ease(Tween.EASE_OUT)
	_add_button_bounce_tween.tween_property(_add_button, "scale", ADD_BUTTON_RELEASE_SCALE, ADD_BUTTON_UP_TIME)
	_add_button_bounce_tween.tween_property(_add_button, "scale", Vector2.ONE, ADD_BUTTON_SETTLE_TIME)


func _bounce_add_button_cancel() -> void:
	if not is_instance_valid(_add_button):
		return

	if _add_button_bounce_tween != null and _add_button_bounce_tween.is_valid():
		_add_button_bounce_tween.kill()

	_add_button.pivot_offset = _add_button.size * 0.5

	_add_button_bounce_tween = create_tween()
	_add_button_bounce_tween.set_trans(Tween.TRANS_BACK)
	_add_button_bounce_tween.set_ease(Tween.EASE_OUT)
	_add_button_bounce_tween.tween_property(_add_button, "scale", Vector2.ONE, ADD_BUTTON_SETTLE_TIME)


func _create_search_icon() -> Control:
	var center_wrap := CenterContainer.new()
	center_wrap.custom_minimum_size = Vector2(92, 120)
	center_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon := Control.new()
	icon.custom_minimum_size = Vector2(76, 76)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	icon.draw.connect(func() -> void:
		var color := Color.WHITE
		var width := 7.0

		icon.draw_arc(Vector2(31, 31), 21.0, 0.0, TAU, 64, color, width, true)
		icon.draw_line(Vector2(47, 47), Vector2(68, 68), color, width, true)
	)

	center_wrap.add_child(icon)
	return center_wrap


func _create_search_clear_button() -> Control:
	var button := Control.new()
	button.name = "SearchClearButton"
	button.custom_minimum_size = Vector2(92, 120)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.visible = false

	button.draw.connect(func() -> void:
		var center := button.size * 0.5
		var half_size := 21.0
		var width := 7.0

		button.draw_line(
			center + Vector2(-half_size, -half_size),
			center + Vector2(half_size, half_size),
			COLOR_TEXT,
			width,
			true
		)

		button.draw_line(
			center + Vector2(half_size, -half_size),
			center + Vector2(-half_size, half_size),
			COLOR_TEXT,
			width,
			true
		)
	)

	button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			_clear_search()
			get_viewport().set_input_as_handled()

		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_clear_search()
			get_viewport().set_input_as_handled()
	)

	return button


func _on_search_text_changed(text: String) -> void:
	_update_search_clear_button()

	if not _grid_ready:
		return

	_rebuild_grid(text)


func _update_search_clear_button() -> void:
	if not is_instance_valid(_search_clear_button) or not is_instance_valid(_search_box):
		return

	_search_clear_button.visible = not _search_box.text.strip_edges().is_empty()
	_search_clear_button.queue_redraw()


func _clear_search() -> void:
	if not is_instance_valid(_search_box):
		return

	_search_box.text = ""
	_search_box.grab_focus()

	_update_search_clear_button()

	if _grid_ready:
		_rebuild_grid("")


func _rebuild_grid(query: String = "") -> void:
	if not is_instance_valid(_grid):
		return

	_rebuild_generation += 1
	var local_generation := _rebuild_generation

	for child in _grid.get_children():
		child.queue_free()

	var q := query.strip_edges().to_lower()
	var match_count := 0

	_grid.visible = false

	if is_instance_valid(_no_results_label):
		_no_results_label.visible = true
		_no_results_label.text = "" if q.is_empty() else "SEARCHING..."
		_update_no_results_height()

	await get_tree().process_frame

	if local_generation != _rebuild_generation or _closing or not is_instance_valid(_grid):
		return

	for planet_data in _all_planets:
		if local_generation != _rebuild_generation or _closing or not is_instance_valid(_grid):
			return

		if not _planet_matches_query(planet_data, q):
			continue

		var card := PREVIEW_SCRIPT.new()
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.focus_mode = Control.FOCUS_NONE
		card.setup(planet_data)
		card.selected.connect(_open_details)
		_force_card_scroll_compatibility(card)

		if _should_reduce_motion():
			card.modulate.a = 1.0
			card.scale = Vector2.ONE
		else:
			card.modulate.a = 0.0
			card.scale = CARD_ENTER_SCALE

		_grid.add_child(card)

		match_count += 1

		if match_count == 1:
			_grid.visible = true

			if is_instance_valid(_no_results_label):
				_no_results_label.visible = false

		if not _should_reduce_motion():
			_animate_card_in(card, match_count - 1)

		if match_count % 2 == 0:
			await get_tree().process_frame

	_grid.visible = match_count > 0

	if is_instance_valid(_no_results_label):
		_no_results_label.visible = match_count == 0
		_no_results_label.text = "NO PLANETS FOUND" if not q.is_empty() else "NO PLANETS AVAILABLE"
		_update_no_results_height()

	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = 0
		_scroll_velocity = 0.0
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS

	call_deferred("_style_scroll_bar")
	call_deferred("_update_no_results_height")


func _animate_card_in(card: Control, index: int) -> void:
	if not is_instance_valid(card):
		return

	card.pivot_offset = card.size * 0.5

	var delay := float(index) * CARD_ENTER_STAGGER

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(card, "modulate:a", 1.0, CARD_ENTER_TIME) \
		.set_delay(delay) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)

	tween.tween_property(card, "scale", Vector2.ONE, CARD_ENTER_TIME) \
		.set_delay(delay) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


func _force_card_scroll_compatibility(node: Node) -> void:
	if node is Control:
		var control := node as Control
		control.focus_mode = Control.FOCUS_NONE

	for child in node.get_children():
		_force_card_scroll_compatibility(child)


func _update_no_results_height() -> void:
	if not is_instance_valid(_no_results_label) or not is_instance_valid(_scroll):
		return

	var available_height := _scroll.size.y

	if available_height <= 0.0:
		available_height = 420.0

	_no_results_label.custom_minimum_size = Vector2(0, max(available_height + 1.0, 420.0))


func _planet_matches_query(planet_data: PlanetData, query: String) -> bool:
	if query.is_empty():
		return true

	var haystack := "%s %s %s %s %s %s %s" % [
		planet_data.name,
		planet_data.subtitle,
		planet_data.description,
		planet_data.planet_preset,
		planet_data.distance_from_sun,
		planet_data.object_category,
		planet_data.archetype_id
	]

	return haystack.to_lower().contains(query)


func _open_details(planet_data: PlanetData) -> void:
	_release_search_focus()
	_play_sfx("open")

	if is_instance_valid(_details_view):
		_details_view.queue_free()

	_main_view.visible = false

	_details_view = DETAILS_SCRIPT.new() as PlanetCardDetails
	_details_view.name = "PlanetCardDetailsView"
	_details_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_details_view.setup(planet_data)
	_details_view.back_requested.connect(_close_details)
	_body_root.add_child(_details_view)


func _close_details() -> void:
	_play_sfx("close")

	if is_instance_valid(_details_view):
		_details_view.queue_free()

	_details_view = null

	if is_instance_valid(_main_view):
		_main_view.visible = true


func _prepare_center_position() -> void:
	if get_viewport() == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width: float = min(viewport_size.x * panel_width_ratio, panel_max_width)
	var panel_height: float = min(viewport_size.y * panel_height_ratio, panel_max_height)

	if is_instance_valid(_grid):
		_grid.columns = 1 if panel_width < 820.0 else columns

	_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	_panel.size = Vector2(panel_width, panel_height)

	_slide_root.size = _panel.size
	_center_position = (viewport_size - _slide_root.size) * 0.5

	_slide_root.position = _center_position
	_panel.position = Vector2.ZERO
	_body_root.size = _panel.size


func _play_intro() -> void:
	_play_sfx("open")

	if _popup_tween:
		_popup_tween.kill()

	_dim.color = Color(0, 0, 0, 0.88)

	if _should_reduce_motion():
		_slide_root.position = _center_position
		_slide_root.modulate.a = 1.0
		_dim.modulate.a = 1.0
		await get_tree().process_frame
		return

	_slide_root.position = _get_left_offscreen_position()
	_slide_root.modulate.a = 0.0
	_dim.modulate.a = 0.0

	_popup_tween = create_tween()
	_popup_tween.set_parallel(true)
	_popup_tween.tween_property(_slide_root, "position", _center_position, POPUP_SLIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_popup_tween.tween_property(_slide_root, "modulate:a", 1.0, POPUP_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_popup_tween.tween_property(_dim, "modulate:a", 1.0, DIM_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await _popup_tween.finished


func _update_search_focus_from_keyboard() -> void:
	if not is_instance_valid(_search_box):
		return

	if not _search_box.has_focus():
		_keyboard_was_visible = false
		return

	var keyboard_visible := _is_virtual_keyboard_visible()

	if _keyboard_was_visible and not keyboard_visible:
		_release_search_focus()
		return

	if keyboard_visible:
		_keyboard_was_visible = true


func _is_virtual_keyboard_visible() -> bool:
	if not OS.has_feature("mobile"):
		return false

	return DisplayServer.virtual_keyboard_get_height() > 0


func _release_search_focus() -> void:
	if not is_instance_valid(_search_box):
		return

	if _search_box.has_focus():
		_search_box.release_focus()

	if OS.has_feature("mobile"):
		DisplayServer.virtual_keyboard_hide()

	_keyboard_was_visible = false


func _style_scroll_bar() -> void:
	if not is_instance_valid(_scroll):
		return

	var bar := _scroll.get_v_scroll_bar()

	if bar == null:
		return

	bar.visible = true
	bar.modulate.a = 1.0
	bar.custom_minimum_size = Vector2(18, 0)
	bar.add_theme_stylebox_override("scroll", _scroll_track_style())
	bar.add_theme_stylebox_override("grabber", _scroll_grabber_style(COLOR_SCROLL_GRAB))
	bar.add_theme_stylebox_override("grabber_highlight", _scroll_grabber_style(COLOR_SCROLL_GRAB_HOVER))
	bar.add_theme_stylebox_override("grabber_pressed", _scroll_grabber_style(COLOR_SCROLL_GRAB_HOVER))


func _should_reduce_motion() -> bool:
	return reduce_motion_enabled


func _get_left_offscreen_position() -> Vector2:
	return Vector2(-_slide_root.size.x - POPUP_SIDE_PADDING, _center_position.y)


func _get_right_offscreen_position() -> Vector2:
	var viewport_width := _center_position.x + _slide_root.size.x + POPUP_SIDE_PADDING

	if get_viewport() != null:
		viewport_width = get_viewport().get_visible_rect().size.x

	return Vector2(viewport_width + POPUP_SIDE_PADDING, _center_position.y)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER
	style.set_border_width_all(5)
	style.set_corner_radius_all(44)

	style.shadow_color = Color(0, 0, 0, 0.64)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 6)

	return style


func _search_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color.TRANSPARENT
	style.border_color = COLOR_BORDER
	style.set_border_width_all(6)
	style.set_corner_radius_all(38)

	return style


func _square_button_style(_pressed: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color.TRANSPARENT
	style.border_color = COLOR_BORDER
	style.set_border_width_all(6)
	style.set_corner_radius_all(38)

	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0

	return style


func _transparent_line_edit_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)

	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0

	return style


func _scroll_track_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = COLOR_SCROLL_TRACK
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(999)

	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 8
	style.content_margin_bottom = 8

	return style


func _scroll_grabber_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = color
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(999)

	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3

	return style


func _apply_app_font(control: Control) -> void:
	if _app_font != null:
		control.add_theme_font_override("font", _app_font)


func _play_sfx(id: String) -> void:
	if has_node("/root/UnilearnSFX"):
		get_node("/root/UnilearnSFX").play(id)

extends CanvasLayer

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

const GRID_REVEAL_OFFSET := Vector2(0, 24)
const GRID_REVEAL_TIME := 0.24
const CARD_BUILD_BATCH_SIZE := 1

const COLOR_PANEL := Color(0.0, 0.0, 0.0, 0.82)
const COLOR_BORDER := Color.WHITE
const COLOR_TEXT := Color.WHITE
const COLOR_SUBTITLE := Color(1.0, 1.0, 1.0, 0.58)
const COLOR_PLACEHOLDER := Color(1.0, 1.0, 1.0, 0.42)
const COLOR_SCROLL_TRACK := Color(1.0, 1.0, 1.0, 0.06)
const COLOR_SCROLL_GRAB := Color(1.0, 1.0, 1.0, 0.34)
const COLOR_SCROLL_GRAB_HOVER := Color(1.0, 1.0, 1.0, 0.52)

const COLOR_STATUS := Color(1.0, 0.82, 0.34, 0.96)
const COLOR_STATUS_ERROR := Color(1.0, 0.38, 0.38, 1.0)
const COLOR_STATUS_PANEL := Color(0.015, 0.018, 0.03, 0.94)

const ADD_BUTTON_PRESS_SCALE := Vector2(0.88, 0.88)
const ADD_BUTTON_RELEASE_SCALE := Vector2(1.10, 1.10)
const ADD_BUTTON_SETTLE_TIME := 0.10
const ADD_BUTTON_DOWN_TIME := 0.055
const ADD_BUTTON_UP_TIME := 0.11

const ADD_BUTTON_GENERATING_SCALE := Vector2(0.94, 0.94)
const ADD_BUTTON_COLOR_TWEEN_TIME := 0.34

const SEARCH_PLACEHOLDER := "Search or create..."

const LOW_BAR_HEIGHT := 86.0
const LOW_BAR_BOTTOM_PADDING := 36.0
const LOW_BAR_WIDTH_RATIO := 0.82
const LOW_BAR_MAX_WIDTH := 980.0
const LOW_BAR_SHOW_TIME := 2.45

@export var panel_width_ratio: float = 0.96
@export var panel_height_ratio: float = 0.96
@export var panel_max_width: float = 1380.0
@export var panel_max_height: float = 1260.0
@export var panel_padding_x: int = 34
@export var panel_padding_y: int = 34
@export var columns: int = 2
@export var generate_planet_backend_url: String = UnilearnBackendService.GENERATE_PLANET_CARD_URL

var reduce_motion_enabled: bool = false

@warning_ignore_start("unused_private_class_variable")

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
var _add_button_color_tween: Tween

var _add_button_generating := false
var _add_button_generation_query := ""
var _add_button_generation_id := ""
var _add_button_highlight_blend := 0.0

var _generate_http: HTTPRequest
var _generate_busy := false
var _generating_query := ""

var _low_bar: PanelContainer
var _low_bar_label: Label
var _low_bar_tween: Tween
var _low_bar_serial := 0

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
var _grid_reveal_tween: Tween
var _app_font: Font = null

var _grid_ready := false
var _rebuild_generation := 0
var _intro_done := false

var _cached_max_scroll_bar: VScrollBar = null
var _planet_cache_node: Node = null

@warning_ignore_restore("unused_private_class_variable")


func setup(_reduce_motion_enabled: bool = false) -> void:
	reduce_motion_enabled = _reduce_motion_enabled


func _ready() -> void:
	layer = 1200
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

	_app_font = load(FONT_PATH) as Font
	_planet_cache_node = get_node_or_null("/root/PlanetCardsCache")

	if _planet_cache_node != null:
		_connect_planet_cache_signals()
		_all_planets = PlanetCardsCache.get_all_cards()
		_sync_generation_state_from_cache(true)
	else:
		_all_planets = []
		print("PlanetCardsCache autoload missing.")

	_build_ui()

	await get_tree().process_frame
	await get_tree().process_frame

	if not is_inside_tree() or _closing:
		return

	_prepare_center_position()
	_style_scroll_bar()
	_update_no_results_height()
	_layout_low_bar()
	_sync_generation_state_from_cache(true)

	await _play_intro()

	if not is_inside_tree() or _closing:
		return

	if not _should_reduce_motion():
		await get_tree().process_frame

	if not is_inside_tree() or _closing:
		return

	_intro_done = true
	_grid_ready = true
	set_process(true)

	if _all_planets.is_empty() and _planet_cache_node != null and not PlanetCardsCache.is_loaded():
		_set_loading_cards_message()
		_load_cards_if_cache_was_not_ready()
	else:
		_rebuild_grid("")


func _connect_planet_cache_signals() -> void:
	if _planet_cache_node == null:
		return

	if _planet_cache_node.has_signal("cards_changed"):
		var cards_callable := Callable(self, "_on_cached_cards_changed")
		if not PlanetCardsCache.cards_changed.is_connected(cards_callable):
			PlanetCardsCache.cards_changed.connect(cards_callable)

	if _planet_cache_node.has_signal("card_generation_started"):
		var started_callable := Callable(self, "_on_cache_card_generation_started")
		if not PlanetCardsCache.card_generation_started.is_connected(started_callable):
			PlanetCardsCache.card_generation_started.connect(started_callable)

	if _planet_cache_node.has_signal("card_generation_finished"):
		var finished_callable := Callable(self, "_on_cache_card_generation_finished")
		if not PlanetCardsCache.card_generation_finished.is_connected(finished_callable):
			PlanetCardsCache.card_generation_finished.connect(finished_callable)

	if _planet_cache_node.has_signal("card_generation_failed"):
		var failed_callable := Callable(self, "_on_cache_card_generation_failed")
		if not PlanetCardsCache.card_generation_failed.is_connected(failed_callable):
			PlanetCardsCache.card_generation_failed.connect(failed_callable)


func _sync_generation_state_from_cache(immediate: bool = false) -> void:
	if not has_node("/root/PlanetCardsCache"):
		_add_button_generating = false
		_add_button_generation_query = ""
		_add_button_generation_id = ""
		_sync_generate_button_ui(immediate)
		return

	var generating := false

	if PlanetCardsCache.has_method("is_generating_any_card"):
		generating = PlanetCardsCache.is_generating_any_card()

	_add_button_generating = generating

	if generating:
		if PlanetCardsCache.has_method("get_active_generation_queries"):
			var queries: Array[String] = PlanetCardsCache.get_active_generation_queries()
			_add_button_generation_query = queries[0] if not queries.is_empty() else ""

		if PlanetCardsCache.has_method("get_active_generation_ids"):
			var ids: Array[String] = PlanetCardsCache.get_active_generation_ids()
			_add_button_generation_id = ids[0] if not ids.is_empty() else ""
	else:
		_add_button_generation_query = ""
		_add_button_generation_id = ""

	_sync_generate_button_ui(immediate)


func _on_cache_card_generation_started(query: String, predicted_id: String) -> void:
	_add_button_generating = true
	_add_button_generation_query = query
	_add_button_generation_id = predicted_id
	_sync_generate_button_ui(false)


func _on_cache_card_generation_finished(card: PlanetData) -> void:
	if card == null:
		_sync_generation_state_from_cache(false)
		return

	_sync_generation_state_from_cache(false)


func _on_cache_card_generation_failed(query: String, _error: String) -> void:
	if _add_button_generation_query.strip_edges().to_lower() == query.strip_edges().to_lower():
		_sync_generation_state_from_cache(false)


func _on_cached_cards_changed(cards: Array[PlanetData]) -> void:
	_all_planets = cards

	if _intro_done and _grid_ready and is_instance_valid(_search_box):
		_rebuild_grid(_search_box.text)


func _set_loading_cards_message() -> void:
	if is_instance_valid(_grid):
		_grid.visible = false

	if is_instance_valid(_no_results_label):
		_no_results_label.visible = true
		_no_results_label.text = "LOADING CARDS..."
		_update_no_results_height()


func _load_cards_if_cache_was_not_ready() -> void:
	var cards: Array[PlanetData] = await PlanetCardsCache.ensure_loaded()

	if not is_inside_tree() or _closing:
		return

	_all_planets = cards

	if _intro_done:
		_rebuild_grid("")


func _process(delta: float) -> void:
	if not _intro_done:
		return

	_update_search_focus_from_keyboard()
	_apply_scroll_inertia(delta)


func _input(event: InputEvent) -> void:
	if not _intro_done:
		return

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

	if _cached_max_scroll_bar == null:
		_cached_max_scroll_bar = _scroll.get_v_scroll_bar()

	if _cached_max_scroll_bar == null:
		return 0.0

	return max(0.0, _cached_max_scroll_bar.max_value - _cached_max_scroll_bar.page)


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

		_cached_max_scroll_bar = null
		_prepare_center_position()
		_style_scroll_bar()
		_update_no_results_height()
		_layout_low_bar()
		_sync_generate_button_ui(true)


func close_popup() -> void:
	if _closing:
		return

	_closing = true
	_intro_done = false
	_rebuild_generation += 1
	set_process(false)

	_play_sfx("close")

	if _popup_tween:
		_popup_tween.kill()

	if _grid_reveal_tween != null and _grid_reveal_tween.is_valid():
		_grid_reveal_tween.kill()

	if _add_button_bounce_tween != null and _add_button_bounce_tween.is_valid():
		_add_button_bounce_tween.kill()

	if _add_button_color_tween != null and _add_button_color_tween.is_valid():
		_add_button_color_tween.kill()

	if _low_bar_tween != null and _low_bar_tween.is_valid():
		_low_bar_tween.kill()

	if is_instance_valid(_add_button):
		_add_button.scale = ADD_BUTTON_GENERATING_SCALE if _add_button_generating else Vector2.ONE

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


func _set_add_button_highlight_blend(value: float) -> void:
	_add_button_highlight_blend = clamp(value, 0.0, 1.0)

	if is_instance_valid(_add_button):
		_add_button.queue_redraw()


func _sync_generate_button_ui(immediate: bool = false) -> void:
	pass

func _get_theme_highlight_color() -> Color:
	if has_node("/root/UnilearnUserSettings"):
		var settings := get_node("/root/UnilearnUserSettings")

		if settings != null and settings.has_method("get_accent_color"):
			return settings.get_accent_color()

	return COLOR_STATUS

func _is_add_button_locked() -> bool:
	return _add_button_generating

func _build_ui() -> void:
	pass

func _prepare_center_position() -> void:
	pass

func _style_scroll_bar() -> void:
	pass

func _update_no_results_height() -> void:
	pass

func _layout_low_bar() -> void:
	pass

func _play_intro() -> void:
	pass

func _should_reduce_motion() -> bool:
	return reduce_motion_enabled

func _rebuild_grid(_query: String = "") -> void:
	pass

func _update_search_focus_from_keyboard() -> void:
	pass

func _update_add_button_pressed_visual(_screen_position: Vector2) -> void:
	pass

func _finish_add_button_press(_screen_position: Vector2) -> void:
	pass

func _start_add_button_press(_pointer_id: int) -> void:
	pass

func _show_low_bar(_message: String, _is_error: bool = false, _sticky: bool = false) -> void:
	pass

func _hide_low_bar() -> void:
	pass

func _press_create_planet_button(_button: Control) -> void:
	pass

func _planet_matches_query(_planet_data: PlanetData, _query: String) -> bool:
	return false

func _open_details(_planet_data: PlanetData) -> void:
	pass

func _close_details() -> void:
	pass

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER
	style.set_border_width_all(4)
	style.set_corner_radius_all(42)
	return style

func _search_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.08)
	style.border_color = Color(1, 1, 1, 0.22)
	style.set_border_width_all(2)
	style.set_corner_radius_all(28)
	return style

func _square_button_style(_pressed: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(28)
	return style

func _low_bar_style(_is_error: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_STATUS_PANEL
	style.border_color = COLOR_STATUS_ERROR if _is_error else COLOR_STATUS
	style.set_border_width_all(2)
	style.set_corner_radius_all(28)
	return style

func _transparent_line_edit_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	return style

func _scroll_track_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SCROLL_TRACK
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(999)
	return style

func _scroll_grabber_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(999)
	return style

func _apply_app_font(_control: Control) -> void:
	pass

func _play_sfx(_id: String) -> void:
	pass

func _get_right_offscreen_position() -> Vector2:
	return Vector2.ZERO

func _release_search_focus() -> void:
	pass

func _update_search_clear_button() -> void:
	pass

func _create_search_clear_button() -> Control:
	return Control.new()

func _create_search_icon() -> Control:
	return Control.new()

func _get_search_match_count(_query: String) -> int:
	return 0

func _is_virtual_keyboard_visible() -> bool:
	return false

func _build_main_view() -> void:
	pass

func _build_low_bar() -> void:
	pass

func _submit_generate_planet_request(_query: String) -> void:
	pass

func _on_generate_planet_request_completed(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	pass

func _add_generated_card_to_cache(_planet_data: PlanetData) -> void:
	pass

func _upsert_planet_data(cards: Array[PlanetData], _planet_data: PlanetData) -> Array[PlanetData]:
	return cards

func _set_generate_busy(value: bool) -> void:
	_generate_busy = value

func _get_unilearn_id_token() -> String:
	return ""

func _bounce_add_button_down() -> void:
	pass

func _bounce_add_button_release() -> void:
	pass

func _bounce_add_button_cancel() -> void:
	pass

func _on_search_text_changed(_text: String) -> void:
	pass

func _clear_search() -> void:
	pass

func _reveal_grid() -> void:
	pass

func _animate_card_in(_card: Control, _index: int) -> void:
	pass

func _force_card_scroll_compatibility(_node: Node) -> void:
	pass

func _get_left_offscreen_position() -> Vector2:
	return Vector2.ZERO

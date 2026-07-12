extends CanvasLayer

signal closed
signal planet_add_requested(data)
signal planet_remove_requested(data)
signal trade_card_chosen(data, peer_uid, peer_name)

const FONT_PATH := "res://assets/fonts/JockeyOne-Regular.ttf"
const PREVIEW_SCRIPT := preload("res://addons/UnilearnLib/planet_cards/PlanetCardPreview.gd")
const DETAILS_SCRIPT := preload("res://addons/UnilearnLib/planet_cards/PlanetCardDetails.gd")
const TRADE_CONTINUE_ARROW_TEXTURE_PATH := "res://assets/app/buttons/button_arrow.png"
const TRADE_UNKNOWN_CARD_ICON_PATH := "res://assets/app/buttons/button_question.png"
const TRADE_FLOW_TIMEOUT_SECONDS := 50.0
const TRADE_PEER_CARD_FILL_TIME := 0.42
const TRADE_FINISH_PAUSE_TIME := 1.0
const TRADE_RECEIVED_ANIMATION_TIME := 0.5
const TRADE_RECEIVED_AUTO_CLOSE_DELAY := 2.0

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
var _details_overlay_backdrop: Control
var _details_opened_from_scene := false
var _details_saved_scroll := 0
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
var _search_rebuild_serial := 0
var _intro_done := false
var _first_grid_rebuild_done := false
var _suppress_next_generated_card_details := false

var _trade_selection_mode := false
var _trade_peer_name := ""
var _trade_peer_uid := ""
var _trade_request_id: String = ""
var _trade_ui_ready_sent: bool = false
var _trade_peer_card_render_generation: int = 0
var _trade_selected_card_id := ""
var _trade_selected_card: PlanetData = null
var _trade_continue_available := false
var _trade_continue_arrow_texture: Texture2D = null
var _trade_unknown_icon_texture: Texture2D = null
var _trade_confirm_view: Control = null
var _trade_confirm_player_card: Control = null
var _trade_confirm_peer_card: Control = null
var _trade_peer_selected_card: PlanetData = null
var _trade_confirm_visible := false
var _trade_waiting_subtitle_label: Label = null
var _trade_waiting_subtitle_base := ""
var _trade_waiting_dots_timer: Timer = null
var _trade_waiting_dots_step := 0
var _trade_waiting_dots_generation := 0
var _trade_flow_timeout_timer: Timer = null
var _trade_flow_timeout_generation := 0
var _trade_timeout_label: Label = null
var _trade_preview_tap_tween: Tween = null
var _trade_timeout_visual_paused := false
var _trade_timeout_paused_seconds := 0
var _trade_finish_animation_started := false
var _trade_visual_start_at_ms := 0
var _trade_visual_server_now_ms := 0
var _trade_visual_start_scheduled := false
var _trade_local_earliest_start_ticks_ms: int = 0
var _trade_received_overlay: Control = null
var _trade_received_card: Control = null
var _trade_received_label: Label = null
var _trade_received_ready_to_close := false
var _trade_received_animation_running := false
var _trade_received_auto_close_generation := 0
var _trade_finish_card_input_blocked := false
var _settings_node: Node = null

var _cached_max_scroll_bar: VScrollBar = null
var _planet_cache_node: Node = null

@warning_ignore_restore("unused_private_class_variable")


func setup(_reduce_motion_enabled: bool = false) -> void:
	reduce_motion_enabled = _reduce_motion_enabled


func setup_trade_selection(peer_name: String = "", peer_uid: String = "", request_id: String = "", _reduce_motion_enabled: bool = false) -> void:
	reduce_motion_enabled = _reduce_motion_enabled
	_trade_selection_mode = true
	_trade_peer_name = peer_name.strip_edges()
	_trade_peer_uid = peer_uid.strip_edges()
	_trade_request_id = request_id.strip_edges()
	_trade_ui_ready_sent = false
	_trade_peer_card_render_generation += 1
	_trade_selected_card_id = ""
	_trade_selected_card = null
	_trade_continue_available = false
	_trade_finish_card_input_blocked = false
	_trade_received_ready_to_close = false
	_trade_received_animation_running = false
	_trade_visual_start_at_ms = 0
	_trade_visual_server_now_ms = 0
	_trade_visual_start_scheduled = false
	_trade_local_earliest_start_ticks_ms = 0
	_trade_finish_animation_started = false
	_trade_peer_selected_card = null
	_trade_confirm_visible = false
	if _trade_peer_name.is_empty():
		_trade_peer_name = "PLAYER"


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
	_connect_trade_selection_theme_signal()

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
		await get_tree().process_frame
		if is_inside_tree() and not _closing:
			_rebuild_grid("")



func _is_trade_selection_mode() -> bool:
	return _trade_selection_mode


func _trade_title_text() -> String:
	return "CHOOSE CARD"


func _trade_subtitle_text() -> String:
	var peer := _trade_peer_name.strip_edges().to_upper()
	if peer.is_empty():
		peer = "PLAYER"
	return "Pick one card to trade with %s!" % peer


func _trade_search_placeholder() -> String:
	return "Search cards..."


func _default_trade_card_ids() -> Dictionary:
	return {
		"sun": true,
		"mercury": true,
		"venus": true,
		"earth": true,
		"moon": true,
		"mars": true,
		"jupiter": true,
		"saturn": true,
		"uranus": true,
		"neptune": true,
	}


func _is_trade_card_eligible(planet_data: PlanetData) -> bool:
	if planet_data == null:
		return false
	var id := planet_data.instance_id.strip_edges().to_lower()
	if _default_trade_card_ids().has(id):
		return false
	return true


func _trade_card_id(planet_data: PlanetData) -> String:
	if planet_data == null:
		return ""
	var id := planet_data.instance_id.strip_edges()
	if id.is_empty():
		id = planet_data.name.strip_edges()
	return id


func _set_trade_selected_card(planet_data: PlanetData) -> void:
	if not _trade_selection_mode:
		return
	if planet_data == null or not _is_trade_card_eligible(planet_data):
		_play_sfx("error")
		return

	var next_card_id := _trade_card_id(planet_data)
	if not next_card_id.is_empty() and next_card_id == _trade_selected_card_id:
		_trade_selected_card = null
		_trade_selected_card_id = ""
		_trade_continue_available = false
		_play_sfx("toggle")
	else:
		_trade_selected_card = planet_data
		_trade_selected_card_id = next_card_id
		_trade_continue_available = not _trade_selected_card_id.is_empty()
		_play_sfx("success")

	_refresh_trade_card_selection_visuals()
	_sync_generate_button_ui(false)


func _is_trade_card_selected(planet_data: PlanetData) -> bool:
	if planet_data == null:
		return false
	return not _trade_selected_card_id.is_empty() and _trade_card_id(planet_data) == _trade_selected_card_id


func _refresh_trade_card_selection_visuals() -> void:
	pass


func _apply_trade_card_selection_visual(_card: Control) -> void:
	pass

func _press_trade_continue_button() -> void:
	if not _trade_selection_mode:
		return
	if _trade_confirm_visible:
		return
	if _trade_selected_card == null or _trade_selected_card_id.is_empty():
		_play_sfx("error")
		return
	_play_sfx("success")
	trade_card_chosen.emit(_trade_selected_card, _trade_peer_uid, _trade_peer_name)
	_show_trade_confirm_view()


func _start_trade_continue_button_press() -> void:
	if not _trade_selection_mode or _trade_confirm_visible:
		return
	if _trade_selected_card == null or _trade_selected_card_id.is_empty():
		_play_sfx("error")
		return

	if is_instance_valid(_add_button):
		if _add_button_bounce_tween != null and _add_button_bounce_tween.is_valid():
			_add_button_bounce_tween.kill()
		if reduce_motion_enabled:
			_press_trade_continue_button()
			return
		_add_button_bounce_tween = create_tween()
		_add_button_bounce_tween.set_trans(Tween.TRANS_BACK)
		_add_button_bounce_tween.set_ease(Tween.EASE_OUT)
		_add_button_bounce_tween.tween_property(_add_button, "scale", ADD_BUTTON_PRESS_SCALE, ADD_BUTTON_DOWN_TIME)
		_add_button_bounce_tween.tween_property(_add_button, "scale", ADD_BUTTON_RELEASE_SCALE, ADD_BUTTON_UP_TIME)
		_add_button_bounce_tween.tween_property(_add_button, "scale", Vector2.ONE, ADD_BUTTON_SETTLE_TIME)
		_add_button_bounce_tween.finished.connect(func() -> void:
			_press_trade_continue_button()
		)
	else:
		_press_trade_continue_button()


func set_trade_peer_selected_card_preview(planet_data: PlanetData) -> void:
	if planet_data == null or _closing:
		return
	var incoming_id: String = planet_data.instance_id.strip_edges()
	var current_id: String = _trade_peer_selected_card.instance_id.strip_edges() if _trade_peer_selected_card != null else ""
	if not incoming_id.is_empty() and incoming_id == current_id and is_instance_valid(_trade_confirm_peer_card):
		return

	_trade_peer_selected_card = planet_data
	_trade_peer_card_render_generation += 1
	var generation: int = _trade_peer_card_render_generation

	# Stop the animated waiting subtitle as soon as the peer card arrives.
	# This updates the first player's text in the same transition as the timer,
	# status rectangle, and card preview.
	_stop_trade_waiting_dots()
	if is_instance_valid(_trade_waiting_subtitle_label):
		var peer_name: String = _trade_peer_name.strip_edges().to_upper()
		if peer_name.is_empty():
			peer_name = "THE OTHER PLAYER"
		_trade_waiting_subtitle_label.text = "%s chose a card" % peer_name

	if not _trade_confirm_visible:
		return

	# Card arrival is one atomic UI update on both devices:
	# freeze the timer, replace the question-mark card, and fill the peer status
	# rectangle in the same frame. There is deliberately no fill tween.
	_pause_trade_timeout_visual()
	_set_trade_confirm_peer_status_tab_filled()
	_set_trade_peer_card_preview_instant(planet_data)

	if generation != _trade_peer_card_render_generation or _closing:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if generation != _trade_peer_card_render_generation or _closing:
		return
	_mark_trade_peer_card_visibly_ready(generation)
	_start_trade_ui_ready_wait(generation)


func _mark_trade_peer_card_visibly_ready(generation: int) -> void:
	if generation != _trade_peer_card_render_generation or _closing or not _trade_confirm_visible:
		return
	# This is deliberately based on the local monotonic clock and is set only
	# after the filled peer card has survived two rendered frames. Therefore the
	# second chooser always sees the completed card for a full second, even when
	# the shared server start timestamp reaches this device early.
	_trade_local_earliest_start_ticks_ms = Time.get_ticks_msec() + 1000
	_schedule_multiplayer_trade_visual_start()


func _start_trade_ui_ready_wait(generation: int) -> void:
	if _trade_ui_ready_sent or _trade_request_id.is_empty() or _trade_peer_selected_card == null or not _trade_confirm_visible:
		return
	if _trade_local_earliest_start_ticks_ms <= 0:
		return
	var remaining_ms: int = maxi(0, _trade_local_earliest_start_ticks_ms - Time.get_ticks_msec())
	if remaining_ms > 0:
		await get_tree().create_timer(float(remaining_ms) / 1000.0, true, false, true).timeout
	if generation != _trade_peer_card_render_generation or _closing or _trade_ui_ready_sent:
		return
	_trade_ui_ready_sent = true
	var database := get_node_or_null("/root/FirebaseDatabase")
	if database != null and database.has_method("mark_multiplayer_trade_ui_ready"):
		var result: Variant = await database.call("mark_multiplayer_trade_ui_ready", _trade_request_id)
		if not (result is Dictionary) or not bool((result as Dictionary).get("success", false)):
			_trade_ui_ready_sent = false


func start_multiplayer_trade_visual(start_at_ms: int, server_now_ms: int) -> void:
	_trade_visual_start_at_ms = start_at_ms
	_trade_visual_server_now_ms = server_now_ms
	_schedule_multiplayer_trade_visual_start()


func _schedule_multiplayer_trade_visual_start() -> void:
	if _trade_visual_start_scheduled or _trade_finish_animation_started:
		return
	if _trade_peer_selected_card == null or not _trade_confirm_visible or _closing:
		return
	if _trade_visual_start_at_ms <= 0 or _trade_visual_server_now_ms <= 0:
		return
	# Do not schedule until the local filled card has actually rendered. The
	# server barrier synchronizes both phones, while this local floor guarantees
	# the mandatory one-second pause cannot be consumed by UI construction.
	if _trade_local_earliest_start_ticks_ms <= 0:
		return
	_trade_visual_start_scheduled = true
	var now_ticks_ms: int = Time.get_ticks_msec()
	var shared_remaining_ms: int = maxi(0, _trade_visual_start_at_ms - _trade_visual_server_now_ms)
	var shared_target_ticks_ms: int = now_ticks_ms + shared_remaining_ms
	var target_ticks_ms: int = maxi(shared_target_ticks_ms, _trade_local_earliest_start_ticks_ms)
	var delay_seconds: float = float(maxi(0, target_ticks_ms - now_ticks_ms)) / 1000.0
	if delay_seconds > 0.0:
		await get_tree().create_timer(delay_seconds, true, false, true).timeout
	if not is_inside_tree() or _closing:
		return
	_handle_trade_peer_card_selected_visual(_trade_peer_selected_card, false)


func get_trade_request_id() -> String:
	return _trade_request_id


func get_trade_selected_card_id() -> String:
	return _trade_selected_card_id


func set_trade_peer_selected_card(planet_data: PlanetData) -> void:
	set_trade_peer_selected_card_preview(planet_data)


func update_trade_peer_selected_card(planet_data: PlanetData) -> void:
	set_trade_peer_selected_card(planet_data)


func _show_trade_confirm_view() -> void:
	if not _trade_selection_mode or _trade_selected_card == null:
		return
	_release_search_focus()
	_trade_confirm_visible = true
	_grid_ready = false
	_rebuild_generation += 1
	if is_instance_valid(_main_view):
		_main_view.visible = false
	_build_trade_confirm_view()

	# The player choosing second already knows the first player's card before
	# this page opens. Build it filled from the first frame and freeze the
	# timer immediately, matching the first player's stopped timer state.
	if _trade_peer_selected_card != null:
		_pause_trade_timeout_visual()
		_set_trade_confirm_peer_status_tab_filled()
		_trade_peer_card_render_generation += 1
		var generation: int = _trade_peer_card_render_generation
		await get_tree().process_frame
		await get_tree().process_frame
		if generation == _trade_peer_card_render_generation and not _closing:
			_mark_trade_peer_card_visibly_ready(generation)
			_start_trade_ui_ready_wait(generation)

	_schedule_multiplayer_trade_visual_start()


func _build_trade_confirm_view() -> void:
	if not is_instance_valid(_body_root):
		return
	_stop_trade_waiting_dots()
	if is_instance_valid(_trade_confirm_view):
		var old_confirm_view := _trade_confirm_view
		_trade_confirm_view = null
		if old_confirm_view.get_parent() != null:
			old_confirm_view.get_parent().remove_child(old_confirm_view)
		old_confirm_view.queue_free()

	_trade_confirm_view = Control.new()
	_trade_confirm_view.name = "TradeConfirmView"
	_trade_confirm_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_trade_confirm_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_trade_confirm_view.modulate.a = 0.0 if not reduce_motion_enabled else 1.0
	_body_root.add_child(_trade_confirm_view)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", panel_padding_x)
	margin.add_theme_constant_override("margin_right", panel_padding_x)
	margin.add_theme_constant_override("margin_top", panel_padding_y)
	margin.add_theme_constant_override("margin_bottom", panel_padding_y)
	_trade_confirm_view.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "TradeConfirmContent"
	content.add_theme_constant_override("separation", 24)
	margin.add_child(content)

	var title_box := VBoxContainer.new()
	title_box.custom_minimum_size = Vector2(0, 202)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 4)
	content.add_child(title_box)

	var title := Label.new()
	title.text = "TRADE CARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 112)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.clip_text = false
	_apply_app_font(title)
	title_box.add_child(title)

	_trade_waiting_subtitle_label = Label.new()
	if _trade_peer_selected_card != null:
		var peer_name: String = _trade_peer_name.strip_edges().to_upper()
		if peer_name.is_empty():
			peer_name = "THE OTHER PLAYER"
		_trade_waiting_subtitle_label.text = "%s chose a card" % peer_name
	else:
		_trade_waiting_subtitle_base = "Waiting for %s to choose" % _trade_peer_name.strip_edges().to_upper()
		if _trade_peer_name.strip_edges().is_empty():
			_trade_waiting_subtitle_base = "Waiting for the other player to choose"
		_trade_waiting_subtitle_label.text = _trade_waiting_subtitle_base + "."
	_trade_waiting_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trade_waiting_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_trade_waiting_subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_waiting_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trade_waiting_subtitle_label.add_theme_font_size_override("font_size", 48)
	_trade_waiting_subtitle_label.add_theme_color_override("font_color", COLOR_SUBTITLE)
	_apply_app_font(_trade_waiting_subtitle_label)
	title_box.add_child(_trade_waiting_subtitle_label)
	if _trade_peer_selected_card == null:
		_start_trade_waiting_dots()

	content.add_child(_create_trade_confirm_status_tabs())

	var cards_box := HBoxContainer.new()
	cards_box.name = "TradeConfirmCardsBox"
	cards_box.custom_minimum_size = Vector2(0, 540)
	cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_box.add_theme_constant_override("separation", 22)
	content.add_child(cards_box)

	_trade_confirm_player_card = _create_trade_confirm_planet_preview(_trade_selected_card, "YOUR CARD")
	cards_box.add_child(_trade_confirm_player_card)

	_trade_confirm_peer_card = _create_trade_confirm_peer_preview()
	cards_box.add_child(_trade_confirm_peer_card)

	content.add_child(_create_trade_confirm_rules_panel())
	_update_trade_timeout_label()

	if not reduce_motion_enabled:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(_trade_confirm_view, "modulate:a", 1.0, 0.18)


func _create_trade_confirm_status_tabs() -> Control:
	var row := HBoxContainer.new()
	row.name = "TradeConfirmStatusTabs"
	row.custom_minimum_size = Vector2(0, 86)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)

	row.add_child(_create_trade_confirm_status_tab("YOUR CARD", _trade_selected_card != null))
	row.add_child(_create_trade_confirm_status_tab(_trade_peer_card_label_text(), _trade_peer_selected_card != null))
	return row


func _create_trade_confirm_status_tab(label_text: String, chosen: bool) -> PanelContainer:
	var tab := PanelContainer.new()
	tab.name = "TradeConfirmStatusTab"
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.set_meta("trade_confirm_status_tab", true)
	tab.set_meta("trade_confirm_tab_chosen", chosen)
	tab.add_theme_stylebox_override("panel", _trade_confirm_tab_style(chosen))

	var label := Label.new()
	label.name = "TradeConfirmStatusTabLabel"
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color.BLACK if chosen else _get_theme_highlight_color())
	label.set_meta("trade_confirm_tab_label", true)
	label.set_meta("trade_confirm_tab_chosen", chosen)
	_apply_app_font(label)
	tab.add_child(label)
	return tab


func _trade_confirm_tab_style(chosen: bool) -> StyleBoxFlat:
	var highlight := _get_theme_highlight_color()
	var style := StyleBoxFlat.new()
	style.bg_color = highlight if chosen else Color.TRANSPARENT
	style.border_color = highlight
	style.set_border_width_all(5)
	style.set_corner_radius_all(28)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _trade_peer_card_label_text() -> String:
	var peer := _trade_peer_name.strip_edges().to_upper()
	if peer.is_empty():
		return "OTHER CARD"
	return "%s'S CARD" % peer


func _refresh_trade_confirm_status_tabs() -> void:
	if not is_instance_valid(_trade_confirm_view):
		return
	var old_tabs := _trade_confirm_view.find_child("TradeConfirmStatusTabs", true, false)
	if old_tabs == null:
		return
	var parent := old_tabs.get_parent()
	if parent == null:
		return
	var index := old_tabs.get_index()
	# queue_free() is deferred. Detach the old row immediately so the two
	# status rectangles can never be drawn together for one frame.
	parent.remove_child(old_tabs)
	old_tabs.queue_free()
	var new_tabs := _create_trade_confirm_status_tabs()
	parent.add_child(new_tabs)
	parent.move_child(new_tabs, min(index, parent.get_child_count() - 1))


func _set_trade_confirm_peer_status_tab_filled() -> void:
	if not is_instance_valid(_trade_confirm_view):
		return
	var tabs := _trade_confirm_view.find_child("TradeConfirmStatusTabs", true, false)
	if tabs == null or not (tabs is Control) or tabs.get_child_count() < 2:
		_refresh_trade_confirm_status_tabs()
		return

	var peer_tab := tabs.get_child(1)
	if not (peer_tab is PanelContainer):
		_refresh_trade_confirm_status_tabs()
		return

	var filled_tab := peer_tab as PanelContainer
	filled_tab.set_meta("trade_confirm_tab_chosen", true)
	filled_tab.add_theme_stylebox_override("panel", _trade_confirm_tab_style(true))

	var label := filled_tab.get_node_or_null("TradeConfirmStatusTabLabel")
	if label is Label:
		(label as Label).set_meta("trade_confirm_tab_chosen", true)
		(label as Label).add_theme_color_override("font_color", Color.BLACK)


func _create_trade_confirm_rules_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "TradeConfirmRulesPanel"
	panel.custom_minimum_size = Vector2(0, 190)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta("trade_confirm_rules_panel", true)
	panel.add_theme_stylebox_override("panel", _trade_confirm_rules_panel_style())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "TradeConfirmTimerRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	row.add_child(_create_trade_timer_side_arrow(true))

	var column := VBoxContainer.new()
	column.name = "TradeConfirmTimerContent"
	column.custom_minimum_size = Vector2(430, 0)
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	row.add_child(column)

	var title := Label.new()
	title.name = "TradeConfirmTimerTitle"
	title.text = "TRADE POPUP CANCEL TIMER:"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	_apply_app_font(title)
	column.add_child(title)

	_trade_timeout_label = Label.new()
	_trade_timeout_label.name = "TradeConfirmTimeoutLabel"
	_trade_timeout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trade_timeout_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_trade_timeout_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_timeout_label.add_theme_font_size_override("font_size", 62)
	_trade_timeout_label.add_theme_color_override("font_color", _get_theme_highlight_color())
	_trade_timeout_label.set_meta("trade_confirm_highlight_label", true)
	_apply_app_font(_trade_timeout_label)
	column.add_child(_trade_timeout_label)

	row.add_child(_create_trade_timer_side_arrow(false))

	return panel


func _create_trade_timer_side_arrow(left_side: bool) -> Control:
	var arrow := Control.new()
	arrow.name = "TradeConfirmTimerLeftArrow" if left_side else "TradeConfirmTimerRightArrow"
	arrow.custom_minimum_size = Vector2(78, 0)
	arrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arrow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.draw.connect(func() -> void:
		_draw_trade_timer_side_arrow(arrow, left_side)
	)
	return arrow


func _draw_trade_timer_side_arrow(target: Control, left_side: bool) -> void:
	if not is_instance_valid(target):
		return

	if _trade_continue_arrow_texture == null and ResourceLoader.exists(TRADE_CONTINUE_ARROW_TEXTURE_PATH):
		_trade_continue_arrow_texture = load(TRADE_CONTINUE_ARROW_TEXTURE_PATH) as Texture2D

	var center := target.size * 0.5
	var draw_size = min(target.size.x, target.size.y) * 0.55
	if draw_size <= 0.0:
		return

	if _trade_continue_arrow_texture != null:
		var rect := Rect2(Vector2(-draw_size * 0.5, -draw_size * 0.5), Vector2(draw_size, draw_size))
		# Same arrow asset as achievements. Left side points inward/right, right side points inward/left.
		var rotation := PI * 0.5 if left_side else -PI * 0.5
		target.draw_set_transform(center, rotation, Vector2.ONE)
		target.draw_texture_rect(_trade_continue_arrow_texture, rect, false, COLOR_TEXT)
		target.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	var length = draw_size * 0.52
	var thickness = max(5.0, draw_size * 0.12)
	var direction := 1.0 if left_side else -1.0
	var tip := center + Vector2(length * 0.28 * direction, 0.0)
	var top := center + Vector2(-length * 0.28 * direction, -length * 0.52)
	var bottom := center + Vector2(-length * 0.28 * direction, length * 0.52)
	target.draw_line(top, tip, COLOR_TEXT, thickness, true)
	target.draw_line(tip, bottom, COLOR_TEXT, thickness, true)


func _trade_confirm_rules_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.74)
	style.border_color = COLOR_TEXT
	style.set_border_width_all(4)
	style.set_corner_radius_all(30)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


func _trade_timeout_seconds_left() -> int:
	if _trade_timeout_visual_paused:
		return _trade_timeout_paused_seconds
	if is_instance_valid(_trade_flow_timeout_timer):
		return int(ceil(max(0.0, _trade_flow_timeout_timer.time_left)))
	return int(TRADE_FLOW_TIMEOUT_SECONDS)


func _update_trade_timeout_label() -> void:
	if not is_instance_valid(_trade_timeout_label):
		return
	_trade_timeout_label.text = "EXPIRATION IN %02ds" % _trade_timeout_seconds_left()


func _create_trade_confirm_planet_preview(planet_data: PlanetData, _label_text: String) -> Control:
	var wrapper := Control.new()
	wrapper.name = "TradeConfirmPlanetWrapper"
	wrapper.custom_minimum_size = Vector2(0, 540)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var card = PREVIEW_SCRIPT.new()
	card.name = "TradeConfirmPlanetPreview"
	card.custom_minimum_size = Vector2(0, 540)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.setup(planet_data)
	wrapper.add_child(card)

	wrapper.resized.connect(func() -> void:
		# The wrapper can briefly resize after its preview has been detached and
		# queued for deletion during a trade-card replacement.
		if not is_instance_valid(wrapper) or not is_instance_valid(card):
			return
		var target_height: float = minf(540.0, maxf(0.0, wrapper.size.y))
		if target_height <= 0.0:
			target_height = 540.0
		card.position = Vector2.ZERO
		card.size = Vector2(wrapper.size.x, target_height)
	)
	wrapper.call_deferred("emit_signal", "resized")
	return wrapper


func _create_trade_confirm_peer_preview() -> Control:
	if _trade_peer_selected_card != null:
		return _create_trade_confirm_planet_preview(_trade_peer_selected_card, _trade_peer_card_label_text())
	return _create_trade_unknown_preview()


func _refresh_trade_confirm_peer_card() -> void:
	if not is_instance_valid(_trade_confirm_peer_card):
		return
	var old_peer_card := _trade_confirm_peer_card
	var parent := old_peer_card.get_parent()
	var index := old_peer_card.get_index()
	_trade_confirm_peer_card = null
	if parent != null:
		parent.remove_child(old_peer_card)
	old_peer_card.queue_free()
	_trade_confirm_peer_card = _create_trade_confirm_peer_preview()
	if parent != null:
		parent.add_child(_trade_confirm_peer_card)
		parent.move_child(_trade_confirm_peer_card, index)
	_refresh_trade_confirm_status_tabs()


func _create_trade_unknown_preview() -> Control:
	var wrapper := Control.new()
	wrapper.name = "TradeConfirmUnknownWrapper"
	wrapper.custom_minimum_size = Vector2(0, 540)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	wrapper.set_meta("unknown_pressing", false)
	wrapper.set_meta("unknown_press_start_pos", Vector2.ZERO)
	wrapper.set_meta("unknown_max_drag_distance", 0.0)
	wrapper.set_meta("unknown_tween", null)
	wrapper.gui_input.connect(func(event: InputEvent) -> void:
		_handle_trade_unknown_preview_input(wrapper, event)
	)

	var card := PanelContainer.new()
	card.name = "UnknownTradeCardPreview"
	card.custom_minimum_size = Vector2(0, 540)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _trade_unknown_card_style())
	wrapper.add_child(card)

	var root := Control.new()
	root.name = "UnknownCardRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(root)

	var planet_area := Panel.new()
	planet_area.name = "UnknownHeroArea"
	planet_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	planet_area.add_theme_stylebox_override("panel", _trade_unknown_hero_style())
	root.add_child(planet_area)

	var stars := Control.new()
	stars.name = "UnknownHeroStars"
	stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.draw.connect(func() -> void:
		_draw_trade_unknown_stars(stars)
	)
	planet_area.add_child(stars)

	var icon := TextureRect.new()
	icon.name = "UnknownQuestionIcon"
	icon.texture = _get_trade_unknown_icon_texture()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = COLOR_TEXT
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	planet_area.add_child(icon)

	var text_back := Panel.new()
	text_back.name = "UnknownTextBackground"
	text_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_back.add_theme_stylebox_override("panel", _trade_unknown_text_style())
	root.add_child(text_back)

	var name_label := Label.new()
	name_label.name = "UnknownPlanetName"
	name_label.text = "UNKNOWN"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 58)
	name_label.add_theme_color_override("font_color", Color.BLACK)
	_apply_app_font(name_label)
	root.add_child(name_label)

	var border := Control.new()
	border.name = "UnknownBorderOverlay"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep the same outer geometry as a normal card while clipping the half of
	# the stroke that would otherwise extend below the card bounds.
	border.clip_contents = true
	border.draw.connect(func() -> void:
		var rect := Rect2(Vector2.ZERO, border.size)
		border.draw_arc(rect.position + Vector2(36, 36), 36, PI, PI * 1.5, 24, COLOR_BORDER, 6.0, true)
		border.draw_arc(rect.position + Vector2(rect.size.x - 36, 36), 36, PI * 1.5, TAU, 24, COLOR_BORDER, 6.0, true)
		border.draw_arc(rect.position + Vector2(rect.size.x - 36, rect.size.y - 36), 36, 0.0, PI * 0.5, 24, COLOR_BORDER, 6.0, true)
		border.draw_arc(rect.position + Vector2(36, rect.size.y - 36), 36, PI * 0.5, PI, 24, COLOR_BORDER, 6.0, true)
		border.draw_line(Vector2(36, 0), Vector2(rect.size.x - 36, 0), COLOR_BORDER, 6.0, true)
		border.draw_line(Vector2(rect.size.x, 36), Vector2(rect.size.x, rect.size.y - 36), COLOR_BORDER, 6.0, true)
		border.draw_line(Vector2(36, rect.size.y), Vector2(rect.size.x - 36, rect.size.y), COLOR_BORDER, 6.0, true)
		border.draw_line(Vector2(0, 36), Vector2(0, rect.size.y - 36), COLOR_BORDER, 6.0, true)
	)
	root.add_child(border)

	var layout_card := func() -> void:
		if not is_instance_valid(wrapper) or not is_instance_valid(card):
			return
		var wrapper_size: Vector2 = wrapper.size
		var target_height: float = minf(540.0, maxf(0.0, wrapper_size.y))
		# PlanetCardPreview can resolve to a slightly shorter visual height than
		# its 540 px wrapper. Match that actual sibling preview height exactly
		# so UNKNOWN never hangs below the selected planet card.
		if is_instance_valid(_trade_confirm_player_card) and _trade_confirm_player_card.get_child_count() > 0:
			var reference_child: Node = _trade_confirm_player_card.get_child(0)
			if reference_child is Control and (reference_child as Control).size.y > 0.0:
				target_height = minf(target_height, (reference_child as Control).size.y)
		if target_height <= 0.0:
			target_height = 540.0
		wrapper.pivot_offset = Vector2(wrapper_size.x, target_height) * 0.5
		card.position = Vector2.ZERO
		card.size = Vector2(wrapper_size.x, target_height)

		var size := card.size
		root.position = Vector2.ZERO
		root.size = size
		# Match PlanetCardPreview exactly: same text strip height and hero split.
		var text_height: float = minf(116.0, size.y * 0.32)
		var hero_height = max(0.0, size.y - text_height)
		planet_area.position = Vector2.ZERO
		planet_area.size = Vector2(size.x, hero_height)
		stars.position = Vector2.ZERO
		stars.size = planet_area.size
		stars.queue_redraw()
		text_back.position = Vector2(0.0, hero_height)
		text_back.size = Vector2(size.x, text_height)
		name_label.position = text_back.position
		name_label.size = text_back.size
		var icon_size = min(hero_height, size.x) * 0.468
		icon.position = Vector2((size.x - icon_size) * 0.5, (hero_height - icon_size) * 0.5)
		icon.size = Vector2(icon_size, icon_size)
		border.position = Vector2.ZERO
		border.size = size
		border.queue_redraw()
	wrapper.resized.connect(layout_card)
	card.resized.connect(layout_card)
	wrapper.call_deferred("emit_signal", "resized")
	card.call_deferred("emit_signal", "resized")
	return wrapper



func _handle_trade_unknown_preview_input(preview: Control, event: InputEvent) -> void:
	if not is_instance_valid(preview):
		return
	if _trade_finish_card_input_blocked:
		if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventMouseMotion or event is InputEventScreenDrag:
			preview.set_meta("unknown_pressing", false)
			preview.set_meta("unknown_max_drag_distance", 999999.0)
			_trade_unknown_preview_bounce_cancel(preview)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_trade_unknown_preview_press_down(preview, event.position)
		else:
			_trade_unknown_preview_release(preview, event.position)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_trade_unknown_preview_press_down(preview, event.position)
		else:
			_trade_unknown_preview_release(preview, event.position)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and bool(preview.get_meta("unknown_pressing", false)):
		_trade_unknown_preview_drag(preview, event.position)
		return

	if event is InputEventScreenDrag and bool(preview.get_meta("unknown_pressing", false)):
		_trade_unknown_preview_drag(preview, event.position)
		return


func _trade_unknown_preview_press_down(preview: Control, position: Vector2) -> void:
	preview.set_meta("unknown_pressing", true)
	preview.set_meta("unknown_press_start_pos", position)
	preview.set_meta("unknown_max_drag_distance", 0.0)
	_trade_unknown_preview_bounce_down(preview)


func _trade_unknown_preview_drag(preview: Control, position: Vector2) -> void:
	var start_pos: Vector2 = preview.get_meta("unknown_press_start_pos", Vector2.ZERO)
	var max_drag = max(float(preview.get_meta("unknown_max_drag_distance", 0.0)), start_pos.distance_to(position))
	preview.set_meta("unknown_max_drag_distance", max_drag)
	if max_drag > 18.0:
		preview.set_meta("unknown_pressing", false)
		_trade_unknown_preview_bounce_cancel(preview)


func _trade_unknown_preview_release(preview: Control, _position: Vector2) -> void:
	if not bool(preview.get_meta("unknown_pressing", false)):
		return
	preview.set_meta("unknown_pressing", false)
	var max_drag := float(preview.get_meta("unknown_max_drag_distance", 0.0))
	if max_drag <= 18.0:
		_play_sfx("click")
		_trade_unknown_preview_bounce_tap(preview)
	else:
		_trade_unknown_preview_bounce_cancel(preview)


func _trade_unknown_preview_kill_tween(preview: Control) -> void:
	var existing_tween: Variant = preview.get_meta("unknown_tween", null)
	if existing_tween is Tween and existing_tween.is_valid():
		existing_tween.kill()


func _trade_unknown_preview_bounce_down(preview: Control) -> void:
	if not is_instance_valid(preview):
		return
	_trade_unknown_preview_kill_tween(preview)
	preview.pivot_offset = preview.size * 0.5
	if reduce_motion_enabled:
		preview.scale = Vector2.ONE
		return
	var tween := create_tween()
	preview.set_meta("unknown_tween", tween)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(preview, "scale", Vector2.ONE * 0.96, 0.055)


func _trade_unknown_preview_bounce_tap(preview: Control) -> void:
	if not is_instance_valid(preview):
		return
	_trade_unknown_preview_kill_tween(preview)
	preview.pivot_offset = preview.size * 0.5
	if reduce_motion_enabled:
		preview.scale = Vector2.ONE
		return
	var tween := create_tween()
	preview.set_meta("unknown_tween", tween)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(preview, "scale", Vector2.ONE * 1.025, 0.11)
	tween.tween_property(preview, "scale", Vector2.ONE, 0.10)


func _trade_unknown_preview_bounce_cancel(preview: Control) -> void:
	if not is_instance_valid(preview):
		return
	_trade_unknown_preview_kill_tween(preview)
	preview.pivot_offset = preview.size * 0.5
	if reduce_motion_enabled:
		preview.scale = Vector2.ONE
		return
	var tween := create_tween()
	preview.set_meta("unknown_tween", tween)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(preview, "scale", Vector2.ONE, 0.10)


func _draw_trade_unknown_stars(target: Control) -> void:
	if not is_instance_valid(target):
		return

	# Stable pseudo-random stars. Do not use the old modulo pattern here; it creates visible rows/diagonals
	# when the unknown preview is squeezed into the trade row.
	var rng := RandomNumberGenerator.new()
	rng.seed = 814729
	var star_count := 58
	for _i in range(star_count):
		var pos := Vector2(target.size.x * rng.randf(), target.size.y * rng.randf())
		var star_size := rng.randf_range(1.4, 3.8)
		var alpha := rng.randf_range(0.45, 1.0)
		target.draw_circle(pos, star_size, Color(1, 1, 1, alpha))



func _handle_trade_peer_card_selected_visual(planet_data: PlanetData, _was_unknown: bool = true) -> void:
	if _trade_finish_animation_started:
		return
	if planet_data == null or not _trade_confirm_visible or _closing:
		return

	# The peer card, filled rectangle, stopped timer, and one-second readiness
	# delay have already happened before the shared synchronized start signal.
	# Never rebuild or refill them here, because that visibly resets the UI on
	# the player who selected second.
	_trade_finish_animation_started = true
	_stop_trade_waiting_dots()
	_pause_trade_timeout_visual()
	_cancel_and_block_trade_confirm_card_touches()

	if is_instance_valid(_trade_waiting_subtitle_label):
		var peer := _trade_peer_name.strip_edges().to_upper()
		if peer.is_empty():
			peer = "THE OTHER PLAYER"
		_trade_waiting_subtitle_label.text = "%s chose a card" % peer

	_remove_traded_card_from_scene_if_present()
	await _play_trade_received_animation(planet_data)


func _pause_trade_timeout_visual() -> void:
	if _trade_timeout_visual_paused:
		return
	_trade_timeout_paused_seconds = _trade_timeout_seconds_left()
	_trade_timeout_visual_paused = true
	if is_instance_valid(_trade_flow_timeout_timer):
		_trade_flow_timeout_timer.stop()
		_trade_flow_timeout_timer.queue_free()
	_trade_flow_timeout_timer = null
	_update_trade_timeout_label()


func _set_trade_peer_card_preview_instant(planet_data: PlanetData) -> void:
	if planet_data == null or not is_instance_valid(_trade_confirm_peer_card):
		return

	var wrapper := _trade_confirm_peer_card
	var old_children := wrapper.get_children()
	var preview := PREVIEW_SCRIPT.new() as Control
	if not is_instance_valid(preview):
		return
	preview.name = "TradeConfirmPeerFilledPreview"
	preview.custom_minimum_size = Vector2(0, 540)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate.a = 1.0
	preview.setup(planet_data)
	wrapper.add_child(preview)
	_apply_trade_unknown_star_formation(preview)
	wrapper.move_child(preview, 0)

	var layout_preview := func() -> void:
		if not is_instance_valid(wrapper) or not is_instance_valid(preview):
			return
		var target_height: float = minf(540.0, maxf(0.0, wrapper.size.y))
		if target_height <= 0.0:
			target_height = 540.0
		preview.position = Vector2.ZERO
		preview.size = Vector2(wrapper.size.x, target_height)
	wrapper.resized.connect(layout_preview)
	layout_preview.call()

	# Detach the old question-mark/preview nodes immediately. No opacity,
	# color, scale, or fill animation is used.
	for child in old_children:
		if not is_instance_valid(child):
			continue
		if child.get_parent() == wrapper:
			wrapper.remove_child(child)
		child.queue_free()


func _apply_trade_unknown_star_formation(preview: Control) -> void:
	if not is_instance_valid(preview):
		return

	# Keep the exact deterministic star field used by the unknown card. Only the planet and name change.
	var normal_stars := preview.find_child("StaticStarsClip", true, false)
	if normal_stars is CanvasItem:
		(normal_stars as CanvasItem).visible = false

	var card_root := preview.find_child("CardRoot", true, false)
	var planet_background := preview.find_child("PlanetBackground", true, false)
	var planet_clip := preview.find_child("PlanetClip", true, false)
	if not (card_root is Control) or not (planet_background is Control):
		return

	var stars := Control.new()
	stars.name = "TradeUnknownStarFormation"
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.clip_contents = true
	stars.draw.connect(func() -> void:
		_draw_trade_unknown_stars(stars)
	)
	(card_root as Control).add_child(stars)

	# Draw above the black hero background but below the actual planet.
	if planet_clip != null and planet_clip.get_parent() == card_root:
		(card_root as Control).move_child(stars, planet_clip.get_index())

	var sync_stars := func() -> void:
		if not is_instance_valid(stars) or not is_instance_valid(planet_background):
			return
		stars.position = (planet_background as Control).position
		stars.size = (planet_background as Control).size
		stars.queue_redraw()

	preview.resized.connect(sync_stars)
	preview.call_deferred("_layout_card")
	call_deferred("_sync_trade_unknown_star_formation", preview, stars, planet_background)


func _sync_trade_unknown_star_formation(preview: Control, stars: Control, planet_background: Control) -> void:
	if not is_instance_valid(preview) or not is_instance_valid(stars) or not is_instance_valid(planet_background):
		return
	stars.position = planet_background.position
	stars.size = planet_background.size
	stars.queue_redraw()


func _cancel_trade_confirm_card_touches_and_release_scale() -> void:
	# If the user is holding either preview right before the finish animation, release it visually
	# and make the upcoming finger/mouse release a no-op instead of triggering another tap.
	if is_instance_valid(_trade_confirm_player_card):
		_cancel_trade_preview_touches_recursive(_trade_confirm_player_card)
	if is_instance_valid(_trade_confirm_peer_card):
		_cancel_trade_preview_touches_recursive(_trade_confirm_peer_card)


func _cancel_and_block_trade_confirm_card_touches() -> void:
	_trade_finish_card_input_blocked = true
	_scroll_pointer_id = -999
	_scroll_dragging = false
	_add_button_pointer_id = -999
	_add_button_pressed = false
	_cancel_trade_confirm_card_touches_and_release_scale()
	_set_trade_card_tree_input_blocked(_trade_confirm_player_card)
	_set_trade_card_tree_input_blocked(_trade_confirm_peer_card)


func _set_trade_card_tree_input_blocked(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is Control:
		var control := node as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		if child is Node:
			_set_trade_card_tree_input_blocked(child)


func _cancel_trade_preview_touches_recursive(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return

	if node is Control:
		var control := node as Control

		# Native PlanetCardPreview press state.
		if control.get("_pressing") != null:
			control.set("_pressing", false)
			if control.get("_max_drag_distance") != null:
				control.set("_max_drag_distance", 999999.0)
			if control.has_method("_bounce_cancel"):
				control.call("_bounce_cancel")
			else:
				_release_trade_control_scale(control)

		# Custom UNKNOWN-card press state.
		if control.has_meta("unknown_pressing"):
			control.set_meta("unknown_pressing", false)
			control.set_meta("unknown_max_drag_distance", 999999.0)
			_trade_unknown_preview_bounce_cancel(control)

	for child in node.get_children():
		if child is Node:
			_cancel_trade_preview_touches_recursive(child)


func _release_trade_control_scale(control: Control) -> void:
	if not is_instance_valid(control):
		return
	control.pivot_offset = control.size * 0.5
	if reduce_motion_enabled:
		control.scale = Vector2.ONE
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, 0.12)


func _remove_traded_card_from_scene_if_present() -> void:
	if _trade_selected_card == null:
		return
	planet_remove_requested.emit(_trade_selected_card)


func _play_trade_received_animation(received_card_data: PlanetData) -> void:
	if _trade_received_animation_running:
		return
	if received_card_data == null or not is_instance_valid(_trade_confirm_view):
		return
	_trade_received_animation_running = true

	_trade_received_ready_to_close = false
	_trade_received_auto_close_generation += 1
	var local_close_generation := _trade_received_auto_close_generation
	var confirm_view := _trade_confirm_view
	if not is_instance_valid(confirm_view):
		_trade_received_animation_running = false
		return

	var received_overlay := Control.new()
	received_overlay.name = "TradeReceivedOverlay"
	received_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	received_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	received_overlay.modulate.a = 1.0
	received_overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_viewport().set_input_as_handled()
	)
	confirm_view.add_child(received_overlay)
	_trade_received_overlay = received_overlay

	var source_rect := Rect2(Vector2.ZERO, Vector2(300, 540))
	if is_instance_valid(_trade_confirm_peer_card):
		source_rect = _trade_confirm_peer_card.get_global_rect()
	var view_rect := confirm_view.get_global_rect()
	var source_size := Vector2(max(1.0, source_rect.size.x), max(1.0, source_rect.size.y))
	var local_source_center := source_rect.position - view_rect.position + source_size * 0.5

	var motion_root := Control.new()
	motion_root.name = "TradeReceivedCardMotionRoot"
	motion_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	motion_root.position = local_source_center
	motion_root.scale = Vector2.ONE
	received_overlay.add_child(motion_root)

	# Opaque card-shaped backing. This prevents the faded trade UI from being
	# visible through transparent gaps around the planet and star layers.
	var received_backing := Panel.new()
	received_backing.name = "TradeReceivedOpaqueBacking"
	received_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backing_style := StyleBoxFlat.new()
	backing_style.bg_color = Color.BLACK
	backing_style.set_corner_radius_all(36)
	received_backing.add_theme_stylebox_override("panel", backing_style)
	motion_root.add_child(received_backing)

	var received_card := PREVIEW_SCRIPT.new() as Control
	if not is_instance_valid(received_card):
		_trade_received_animation_running = false
		return
	received_card.name = "TradeReceivedCardPreview"
	received_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	received_card.modulate.a = 1.0
	received_card.setup(received_card_data)
	motion_root.add_child(received_card)
	_trade_received_card = received_card

	_prepare_received_card_visual_bounds(received_card)
	_clean_received_card_corner_masks(received_card)
	if not is_instance_valid(received_card):
		_trade_received_animation_running = false
		return
	received_card.position = -source_size * 0.5
	received_card.size = source_size
	received_card.scale = Vector2.ONE
	received_card.pivot_offset = Vector2.ZERO
	received_backing.position = received_card.position
	received_backing.size = source_size
	received_backing.move_to_front()
	received_card.move_to_front()

	# The enlarged card is a separate preview. Hide only the original small
	# peer card immediately instead of letting it fade behind the scale-up.
	if is_instance_valid(_trade_confirm_peer_card):
		_set_canvas_tree_alpha(_trade_confirm_peer_card, 0.0)

	var received_label := Label.new()
	received_label.name = "TradeReceivedLabel"
	received_label.text = "YOU RECEIVED:"
	received_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	received_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	received_label.add_theme_font_size_override("font_size", 112)
	received_label.add_theme_color_override("font_color", COLOR_TEXT)
	received_label.modulate.a = 0.0
	_apply_app_font(received_label)
	received_overlay.add_child(received_label)
	_trade_received_label = received_label

	var desired_width = max(0.0, confirm_view.size.x - 92.0)
	var label_height := 142.0
	var bottom_margin := 48.0
	var label_gap := 18.0
	var max_card_height = max(240.0, confirm_view.size.y - bottom_margin - label_height - label_gap - 18.0)
	var target_scale = min(desired_width / source_size.x, max_card_height / source_size.y)
	target_scale = max(0.001, target_scale)
	var target_height = source_size.y * target_scale
	var target_center := Vector2(confirm_view.size.x * 0.5, confirm_view.size.y - bottom_margin - target_height * 0.5)
	var label_y = max(14.0, target_center.y - target_height * 0.5 - label_height - label_gap)

	received_label.position = Vector2(0.0, label_y)
	received_label.size = Vector2(confirm_view.size.x, label_height)

	if reduce_motion_enabled:
		_fade_old_trade_confirm_view_alpha(0.0)
		if is_instance_valid(motion_root):
			motion_root.position = target_center
			motion_root.scale = Vector2.ONE * target_scale
		if is_instance_valid(received_label):
			received_label.modulate.a = 1.0
		_mark_trade_received_ready_to_close(local_close_generation)
		_play_sfx("success")
		_clear_completed_multiplayer_trade_state()
		return

	# The result card must be the only visible foreground content. Hide the
	# complete old trade page immediately instead of fading it underneath.
	_fade_old_trade_confirm_view_alpha(0.0)

	var finish_tween := create_tween()
	finish_tween.set_parallel(true)
	finish_tween.set_trans(Tween.TRANS_LINEAR)
	finish_tween.set_ease(Tween.EASE_IN_OUT)
	finish_tween.tween_property(received_label, "modulate:a", 1.0, TRADE_RECEIVED_ANIMATION_TIME)
	finish_tween.tween_property(motion_root, "position", target_center, TRADE_RECEIVED_ANIMATION_TIME)
	finish_tween.tween_property(motion_root, "scale", Vector2.ONE * target_scale, TRADE_RECEIVED_ANIMATION_TIME)
	await finish_tween.finished

	if not is_inside_tree() or _closing:
		return
	if is_instance_valid(motion_root):
		motion_root.position = target_center
		motion_root.scale = Vector2.ONE * target_scale
	if is_instance_valid(received_card):
		received_card.position = -source_size * 0.5
		received_card.size = source_size
		received_card.scale = Vector2.ONE
		received_card.pivot_offset = Vector2.ZERO
	_mark_trade_received_ready_to_close(local_close_generation)
	_play_sfx("success")
	_clear_completed_multiplayer_trade_state()


func _clear_completed_multiplayer_trade_state() -> void:
	var database := get_node_or_null("/root/FirebaseDatabase")
	if database != null and database.has_method("clear_multiplayer_trade_state"):
		database.call("clear_multiplayer_trade_state", _trade_peer_uid)


func _fade_old_trade_confirm_view_alpha(alpha: float) -> void:
	if not is_instance_valid(_trade_confirm_view):
		return
	var amount = clamp(alpha, 0.0, 1.0)

	# Keep the popup shell, its black background, border and outer padding fully visible.
	# Only the actual trade-page content fades behind the received-card animation.
	var content := _trade_confirm_view.find_child("TradeConfirmContent", true, false)
	if content is CanvasItem:
		var item := content as CanvasItem
		var next_modulate := item.modulate
		next_modulate.a = amount
		item.modulate = next_modulate


func _set_canvas_tree_alpha(node: Node, alpha: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is CanvasItem:
		var item := node as CanvasItem
		var next_modulate := item.modulate
		next_modulate.a = alpha
		item.modulate = next_modulate
	for child in node.get_children():
		if child is Node:
			_set_canvas_tree_alpha(child, alpha)


func _prepare_received_card_visual_bounds(card: Control) -> void:
	if not is_instance_valid(card):
		return
	# Keep the enlarged received card rectangularly clipped only. Rounded corners are handled below
	# by removing the preview's old black corner-mask overlay and drawing a clean border instead.
	card.clip_contents = true
	for node in card.find_children("*", "Control", true, false):
		if node is Control:
			(node as Control).clip_contents = true


func _clean_received_card_corner_masks(card: Control) -> void:
	if not is_instance_valid(card):
		return

	# PlanetCardPreview's normal BorderOverlay draws black corner masks. That is fine on the
	# normal black popup, but during the received-card animation those masks look like a non-rounded
	# black rectangle over the faded UI. Hide it and replace it with a pure rounded border.
	for node in card.find_children("BorderOverlay", "Control", true, false):
		if node is Control:
			(node as Control).visible = false

	if card.get_node_or_null("TradeReceivedCleanRoundedBorder") != null:
		return

	var border := Control.new()
	border.name = "TradeReceivedCleanRoundedBorder"
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.z_index = 10000
	border.draw.connect(func() -> void:
		_draw_trade_received_clean_rounded_border(border)
	)
	card.add_child(border)
	border.move_to_front()
	border.queue_redraw()


func _draw_trade_received_clean_rounded_border(target: Control) -> void:
	if not is_instance_valid(target):
		return
	var border_width := 6.0
	var rect := Rect2(
		Vector2(border_width * 0.5, border_width * 0.5),
		target.size - Vector2(border_width, border_width)
	)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var radius = min(36.0, min(rect.size.x, rect.size.y) * 0.5)
	var border_color := COLOR_BORDER
	target.draw_arc(Vector2(rect.position.x + radius, rect.position.y + radius), radius, PI, PI * 1.5, 24, border_color, border_width, true)
	target.draw_arc(Vector2(rect.end.x - radius, rect.position.y + radius), radius, PI * 1.5, TAU, 24, border_color, border_width, true)
	target.draw_arc(Vector2(rect.end.x - radius, rect.end.y - radius), radius, 0.0, PI * 0.5, 24, border_color, border_width, true)
	target.draw_arc(Vector2(rect.position.x + radius, rect.end.y - radius), radius, PI * 0.5, PI, 24, border_color, border_width, true)
	target.draw_line(Vector2(rect.position.x + radius, rect.position.y), Vector2(rect.end.x - radius, rect.position.y), border_color, border_width, true)
	target.draw_line(Vector2(rect.end.x, rect.position.y + radius), Vector2(rect.end.x, rect.end.y - radius), border_color, border_width, true)
	target.draw_line(Vector2(rect.end.x - radius, rect.end.y), Vector2(rect.position.x + radius, rect.end.y), border_color, border_width, true)
	target.draw_line(Vector2(rect.position.x, rect.end.y - radius), Vector2(rect.position.x, rect.position.y + radius), border_color, border_width, true)


func _take_existing_trade_peer_preview_for_received_animation() -> Control:
	if not is_instance_valid(_trade_confirm_peer_card):
		return null

	var preferred := _trade_confirm_peer_card.get_node_or_null("TradeConfirmPeerFilledPreview")
	if preferred is Control:
		_trade_confirm_peer_card.remove_child(preferred)
		return preferred

	for child in _trade_confirm_peer_card.get_children():
		if child is Control and str(child.name).find("Preview") >= 0:
			_trade_confirm_peer_card.remove_child(child)
			return child

	return null

func _mark_trade_received_ready_to_close(local_close_generation: int) -> void:
	if _closing:
		return
	_trade_received_ready_to_close = true
	var timer := get_tree().create_timer(TRADE_RECEIVED_AUTO_CLOSE_DELAY, true, false, true)
	await timer.timeout
	if local_close_generation != _trade_received_auto_close_generation:
		return
	if _closing or not _trade_received_ready_to_close:
		return
	close_popup()

func _start_trade_waiting_dots() -> void:
	_stop_trade_waiting_dots()
	_trade_waiting_dots_generation += 1
	_trade_waiting_dots_step = 0
	_advance_trade_waiting_dots()
	_trade_waiting_dots_timer = Timer.new()
	_trade_waiting_dots_timer.name = "TradeWaitingDotsTimer"
	_trade_waiting_dots_timer.one_shot = false
	_trade_waiting_dots_timer.wait_time = 1.0
	_trade_waiting_dots_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_trade_waiting_dots_timer)
	var local_generation := _trade_waiting_dots_generation
	_trade_waiting_dots_timer.timeout.connect(func() -> void:
		if local_generation != _trade_waiting_dots_generation:
			return
		_advance_trade_waiting_dots()
	)
	_trade_waiting_dots_timer.start()


func _stop_trade_waiting_dots() -> void:
	_trade_waiting_dots_generation += 1
	_trade_waiting_dots_step = 0
	if is_instance_valid(_trade_waiting_dots_timer):
		_trade_waiting_dots_timer.stop()
		_trade_waiting_dots_timer.queue_free()
	_trade_waiting_dots_timer = null


func _advance_trade_waiting_dots() -> void:
	if not is_instance_valid(_trade_waiting_subtitle_label):
		return
	_trade_waiting_dots_step += 1
	if _trade_waiting_dots_step > 3:
		_trade_waiting_dots_step = 1
	var dots := "."
	if _trade_waiting_dots_step == 2:
		dots = ".."
	elif _trade_waiting_dots_step == 3:
		dots = "..."
	_trade_waiting_subtitle_label.text = "%s%s" % [_trade_waiting_subtitle_base, dots]

func _start_trade_flow_timeout() -> void:
	if not _trade_selection_mode or _closing:
		return
	_stop_trade_flow_timeout()
	_trade_flow_timeout_generation += 1
	var local_generation := _trade_flow_timeout_generation
	_trade_flow_timeout_timer = Timer.new()
	_trade_flow_timeout_timer.name = "TradeFlowTimeoutTimer"
	_trade_flow_timeout_timer.one_shot = true
	_trade_flow_timeout_timer.wait_time = TRADE_FLOW_TIMEOUT_SECONDS
	_trade_flow_timeout_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_trade_flow_timeout_timer)
	_trade_flow_timeout_timer.timeout.connect(func() -> void:
		if local_generation != _trade_flow_timeout_generation:
			return
		_on_trade_flow_timeout()
	)
	_trade_flow_timeout_timer.start()


func _stop_trade_flow_timeout() -> void:
	_trade_flow_timeout_generation += 1
	_trade_timeout_label = null
	_trade_timeout_visual_paused = false
	_trade_timeout_paused_seconds = 0
	if is_instance_valid(_trade_flow_timeout_timer):
		_trade_flow_timeout_timer.stop()
		_trade_flow_timeout_timer.queue_free()
	_trade_flow_timeout_timer = null


func _on_trade_flow_timeout() -> void:
	if _closing:
		return
	_trade_flow_timeout_timer = null
	_trade_ui_ready_sent = false
	_trade_peer_card_render_generation += 1
	var database := get_node_or_null("/root/FirebaseDatabase")
	if database != null:
		if database.has_method("cancel_multiplayer_trade") and not _trade_request_id.is_empty():
			database.call("cancel_multiplayer_trade", _trade_request_id)
		if database.has_method("clear_multiplayer_trade_state"):
			database.call("clear_multiplayer_trade_state", _trade_peer_uid)
	_play_sfx("error")
	close_popup()


func _get_trade_unknown_icon_texture() -> Texture2D:
	if _trade_unknown_icon_texture == null and ResourceLoader.exists(TRADE_UNKNOWN_CARD_ICON_PATH):
		_trade_unknown_icon_texture = load(TRADE_UNKNOWN_CARD_ICON_PATH) as Texture2D
	return _trade_unknown_icon_texture


func _trade_unknown_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(36)
	return style


func _trade_unknown_hero_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.corner_radius_top_left = 36
	style.corner_radius_top_right = 36
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	return style


func _trade_unknown_text_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 30
	style.corner_radius_bottom_right = 30
	return style


func _draw_trade_continue_arrow(target: Control, color: Color) -> void:
	if not is_instance_valid(target):
		return

	if _trade_continue_arrow_texture == null and ResourceLoader.exists(TRADE_CONTINUE_ARROW_TEXTURE_PATH):
		_trade_continue_arrow_texture = load(TRADE_CONTINUE_ARROW_TEXTURE_PATH) as Texture2D

	if _trade_continue_arrow_texture != null:
		var draw_size: float = min(target.size.x, target.size.y) * 0.62
		var center := target.size * 0.5
		var rect := Rect2(Vector2(-draw_size * 0.5, -draw_size * 0.5), Vector2(draw_size, draw_size))
		# Same texture as the achievements popup back button, rotated the opposite way for proceed.
		target.draw_set_transform(center, PI * 0.5, Vector2.ONE)
		target.draw_texture_rect(_trade_continue_arrow_texture, rect, false, color)
		target.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	var center := target.size * 0.5
	var length := target.size.y * 0.40
	var thickness := target.size.y * 0.085
	var start := center + Vector2(-length * 0.24, -length * 0.52)
	var mid := center + Vector2(length * 0.28, 0.0)
	var end := center + Vector2(-length * 0.24, length * 0.52)
	target.draw_line(start, mid, color, thickness, true)
	target.draw_line(mid, end, color, thickness, true)


func _connect_trade_selection_theme_signal() -> void:
	_settings_node = get_node_or_null("/root/UnilearnUserSettings")
	if _settings_node == null:
		return
	if not _settings_node.has_signal("settings_changed"):
		return
	var callable := Callable(self, "_on_trade_selection_theme_settings_changed")
	if not _settings_node.settings_changed.is_connected(callable):
		_settings_node.settings_changed.connect(callable)


func _on_trade_selection_theme_settings_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	if is_instance_valid(_add_button):
		_add_button.queue_redraw()
	if _trade_selection_mode:
		_refresh_trade_card_selection_visuals()
		_refresh_trade_confirm_theme_colors()


func _refresh_trade_confirm_theme_colors() -> void:
	if not is_instance_valid(_trade_confirm_view):
		return
	var highlight := _get_theme_highlight_color()
	for node in _trade_confirm_view.find_children("*", "Label", true, false):
		if node is Label and node.has_meta("trade_confirm_highlight_label"):
			(node as Label).add_theme_color_override("font_color", highlight)
		elif node is Label and node.has_meta("trade_confirm_tab_label"):
			var chosen := bool(node.get_meta("trade_confirm_tab_chosen", false))
			(node as Label).add_theme_color_override("font_color", Color.BLACK if chosen else highlight)
	for node in _trade_confirm_view.find_children("TradeConfirmStatusTab", "PanelContainer", true, false):
		if node is PanelContainer and node.has_meta("trade_confirm_status_tab"):
			var chosen := bool(node.get_meta("trade_confirm_tab_chosen", false))
			(node as PanelContainer).add_theme_stylebox_override("panel", _trade_confirm_tab_style(chosen))
	for node in _trade_confirm_view.find_children("TradeConfirmRulesPanel", "PanelContainer", true, false):
		if node is PanelContainer and node.has_meta("trade_confirm_rules_panel"):
			(node as PanelContainer).add_theme_stylebox_override("panel", _trade_confirm_rules_panel_style())


func _get_planet_card_count() -> int:
	if has_node("/root/PlanetCardsCache") and PlanetCardsCache.has_method("get_card_count"):
		return int(PlanetCardsCache.get_card_count())
	return _all_planets.size()


func _is_planet_card_limit_reached() -> bool:
	if has_node("/root/PlanetCardsCache") and PlanetCardsCache.has_method("is_at_card_limit"):
		return bool(PlanetCardsCache.is_at_card_limit())
	return _get_planet_card_count() >= 100

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
	_suppress_next_generated_card_details = false

func _on_cache_card_generation_failed(query: String, _error: String) -> void:
	if _add_button_generation_query.strip_edges().to_lower() == query.strip_edges().to_lower():
		_sync_generation_state_from_cache(false)

func _on_cached_cards_changed(cards: Array[PlanetData]) -> void:
	_all_planets = cards
	_on_planet_cards_cache_invalidated()
	_sync_generate_button_ui(false)

	if _intro_done and _grid_ready and is_instance_valid(_search_box):
		if has_method("_apply_planet_cards_delta") and bool(call("_apply_planet_cards_delta", cards)):
			return
		var saved_scroll := _scroll.scroll_vertical if is_instance_valid(_scroll) else 0
		_rebuild_grid(_search_box.text)
		call_deferred("_restore_planet_cards_scroll", saved_scroll)


func _set_loading_cards_message() -> void:
	if is_instance_valid(_scroll):
		_scroll.visible = false

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

	if _trade_selection_mode:
		_update_trade_timeout_label()

	if _is_details_layer_open():
		_scroll_velocity = 0.0
		_scroll_pointer_id = -999
		_scroll_dragging = false
		_add_button_pointer_id = -999
		return

	_update_search_focus_from_keyboard()
	_apply_scroll_inertia(delta)


func _input(event: InputEvent) -> void:
	if not _intro_done:
		return

	if _trade_finish_card_input_blocked and not _trade_received_ready_to_close:
		if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventMouseMotion or event is InputEventScreenDrag:
			_cancel_trade_confirm_card_touches_and_release_scale()
			get_viewport().set_input_as_handled()
			return

	# Details now lives on top of the cards list instead of replacing it.
	# While it is open, the underlying cards popup must not run its own scroll
	# input code, otherwise it steals/handles the same drag before the details
	# hero can apply horizontal movement to the animated planet.
	if _is_details_layer_open():
		_scroll_velocity = 0.0
		_scroll_pointer_id = -999
		_scroll_dragging = false
		_add_button_pointer_id = -999

		if is_instance_valid(_details_view) and _details_view.has_method("handle_parent_popup_input"):
			_details_view.call("handle_parent_popup_input", event)

		return

	_handle_slippery_scroll_input(event)
	_handle_add_button_release_input(event)


func _is_details_layer_open() -> bool:
	return is_instance_valid(_details_view) and _details_view.visible


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
			_ensure_scroll_process()
			get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_scroll_velocity -= _scroll_wheel_impulse
			_scroll_velocity = clamp(_scroll_velocity, -_scroll_max_velocity, _scroll_max_velocity)
			_ensure_scroll_process()
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
	_ensure_scroll_process()
	_scroll.scroll_vertical = int(clamp(float(_scroll.scroll_vertical) + frame_delta, 0.0, _get_max_scroll()))

	_scroll_last_y = current_y
	_scroll_last_time = now

func _ensure_scroll_process() -> void:
	if process_mode == Node.PROCESS_MODE_DISABLED:
		return
	if not is_processing():
		set_process(true)


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

	_trade_finish_card_input_blocked = false
	_trade_received_ready_to_close = false
	_trade_received_animation_running = false
	_trade_visual_start_at_ms = 0
	_trade_visual_server_now_ms = 0
	_trade_visual_start_scheduled = false
	_trade_local_earliest_start_ticks_ms = 0
	_trade_received_auto_close_generation += 1
	_closing = true
	_intro_done = false
	_rebuild_generation += 1
	set_process(false)
	_stop_trade_waiting_dots()
	_stop_trade_flow_timeout()

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


const AI_TYPE_CHARACTER_DELAY := 0.035
const AI_TYPE_SPACE_DELAY := 0.055
const AI_TYPE_AFTER_TEXT_DELAY := 0.45
const AI_TYPE_BEFORE_PLUS_DELAY := 0.26
const AI_PLUS_HOLD_TIME := 0.22


func simulate_ai_create_planet(prompt: String, suppress_details_after_generation: bool = false) -> void:
	prompt = prompt.strip_edges()

	if prompt.is_empty():
		prompt = "planet"

	if not is_instance_valid(_search_box):
		return

	if _is_add_button_locked():
		return

	_suppress_next_generated_card_details = suppress_details_after_generation
	_release_search_focus()

	_search_box.text = ""
	_search_box.placeholder_text = ""
	_search_box.caret_column = 0
	_update_search_clear_button()

	if _grid_ready:
		_rebuild_grid("")

	await get_tree().create_timer(AI_TYPE_BEFORE_PLUS_DELAY).timeout

	await _type_search_text_like_ai(prompt)

	if not is_inside_tree() or _closing:
		return

	await get_tree().create_timer(AI_TYPE_AFTER_TEXT_DELAY).timeout

	if not is_inside_tree() or _closing:
		return

	if _is_add_button_locked():
		return

	var match_count := _get_search_match_count(prompt)

	if match_count > 0:
		_play_sfx("error")
		return

	if is_instance_valid(_add_button):
		_start_add_button_press(-2)
		await get_tree().create_timer(AI_PLUS_HOLD_TIME).timeout

		if is_instance_valid(_add_button):
			_finish_add_button_press(_add_button.get_global_rect().get_center())
	else:
		_submit_generate_planet_request(prompt)


func _type_search_text_like_ai(text: String) -> void:
	if not is_instance_valid(_search_box):
		return

	var typed := ""

	for i in range(text.length()):
		if not is_inside_tree() or _closing:
			return

		if not is_instance_valid(_search_box):
			return

		var character := text.substr(i, 1)
		typed += character

		_search_box.text = typed
		_search_box.caret_column = typed.length()
		_update_search_clear_button()

		if _grid_ready:
			_rebuild_grid(typed)

		var delay := AI_TYPE_SPACE_DELAY if character == " " else AI_TYPE_CHARACTER_DELAY
		await get_tree().create_timer(delay).timeout


func _get_theme_highlight_color() -> Color:
	if has_node("/root/UnilearnUserSettings"):
		var settings := get_node("/root/UnilearnUserSettings")

		if settings != null:
			if settings.has_method("get_text_highlighted_color"):
				var text_highlight_value: Variant = settings.call("get_text_highlighted_color")
				if text_highlight_value is Color:
					return text_highlight_value

			if settings.has_method("get_accent_color"):
				var accent_value: Variant = settings.call("get_accent_color")
				if accent_value is Color:
					return accent_value

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

func _on_planet_cards_cache_invalidated() -> void:
	pass

func _open_details(_planet_data: PlanetData, _play_transition_sfx: bool = false) -> void:
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

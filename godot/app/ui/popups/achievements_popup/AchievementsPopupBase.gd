extends CanvasLayer

signal closed

const FONT_PATH := "res://assets/fonts/JockeyOne-Regular.ttf"

const POPUP_SLIDE_DURATION := 0.42
const POPUP_FADE_DURATION := 0.22
const DIM_FADE_DURATION := 0.26
const POPUP_SIDE_PADDING := 80.0

const CARD_ENTER_OFFSET := Vector2(0, 42)
const CARD_ENTER_SCALE := Vector2(0.92, 0.92)
const CARD_ENTER_TIME := 0.28
const CARD_ENTER_STAGGER := 0.035
const CARD_ANIMATION_LIMIT := 5
const MAX_VISIBLE_RESULTS := 100000
const CATEGORY_CARD_BATCH_SIZE := 1
const ACHIEVEMENT_CARD_BATCH_SIZE := 1

const COLOR_PANEL := Color(0.0, 0.0, 0.0, 0.82)
const COLOR_BORDER := Color.WHITE
const COLOR_TEXT := Color.WHITE
const COLOR_SUBTITLE := Color(1.0, 1.0, 1.0, 0.58)
const COLOR_PLACEHOLDER := Color(1.0, 1.0, 1.0, 0.42)
const COLOR_SCROLL_TRACK := Color(1.0, 1.0, 1.0, 0.06)
const COLOR_SCROLL_GRAB := Color(1.0, 1.0, 1.0, 0.34)
const COLOR_SCROLL_GRAB_HOVER := Color(1.0, 1.0, 1.0, 0.52)
const COLOR_STATUS := Color(1.0, 0.82, 0.34, 0.96)
const COLOR_STATUS_PANEL := Color(0.015, 0.018, 0.03, 0.94)

const SEARCH_PLACEHOLDER := "Search achievements..."

const BACK_BUTTON_PRESS_SCALE := Vector2(0.88, 0.88)
const BACK_BUTTON_RELEASE_SCALE := Vector2(1.10, 1.10)
const BACK_BUTTON_DOWN_TIME := 0.055
const BACK_BUTTON_UP_TIME := 0.11
const BACK_BUTTON_SETTLE_TIME := 0.10
const BACK_BUTTON_COLOR_TWEEN_TIME := 0.34
const BACK_ARROW_TEXTURE_PATH := "res://assets/app/buttons/button_arrow.png"

@export var panel_width_ratio: float = 0.96
@export var panel_height_ratio: float = 0.96
@export var panel_max_width: float = 1380.0
@export var panel_max_height: float = 1260.0
@export var panel_padding_x: int = 34
@export var panel_padding_y: int = 34

var reduce_motion_enabled: bool = false
var _service: Node = null
var _filter_query := ""
var _selected_category := ""
var _view_generation: int = 0
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
var _cached_max_scroll_bar: VScrollBar = null
var _scroll_reset_stub_ready := true


func _reset_scroll_motion() -> void:
	_scroll_pointer_id = -999
	_scroll_dragging = false
	_scroll_velocity = 0.0
	_cached_max_scroll_bar = null


func _reset_scroll_dragging() -> void:
	_scroll_dragging = false


var _back_button_pointer_id := -999
var _back_button_pressed := false
var _back_button_bounce_tween: Tween
var _back_button_color_tween: Tween
var _back_button_active_blend: float = 0.0
var _back_button_icon: TextureRect = null
var _back_button_fallback_arrow: Label = null
var _back_button_arrow_texture: Texture2D = null
var _icon_texture_cache: Dictionary = {}
var _tint_material_cache: Dictionary = {}
var _icon_tint_shader: Shader = null
var _refresh_has_run: bool = false
var _last_refresh_msec: int = -1000000
var _intro_finished: bool = false
var _rebuild_deferred_pending: bool = false
const SERVICE_REFRESH_INTERVAL_MSEC := 1400

@warning_ignore_start("unused_private_class_variable")

var _root: Control
var _dim: ColorRect
var _slide_root: Control
var _panel: PanelContainer
var _body_root: Control
var _main_view: Control
var _search_row: Control
var _search_shell: PanelContainer
var _search_box: LineEdit
var _search_clear_button: Control
var _back_button: Control
var _scroll: ScrollContainer
var _scroll_margin: MarginContainer
var _scroll_content: VBoxContainer
var _list: VBoxContainer
var _unlocked_value_label: Label
var _unlocked_caption_label: Label
var _tier_value_labels: Dictionary = {}
var _tier_progress_bars: Dictionary = {}
var _empty_label: Label
var _category_scroll: ScrollContainer
var _category_list: VBoxContainer
var _category_empty_label: Label
var _details_scroll: ScrollContainer
var _details_list: VBoxContainer
var _details_empty_label: Label
var _category_scroll_value := 0

var _center_position := Vector2.ZERO
var _closing := false
var _popup_tween: Tween
var _app_font: Font = null
var _style_cache: Dictionary = {}
var _settings_node: Node = null
var _last_theme_highlight_color := COLOR_STATUS
var _first_list_rebuild_done := false
var _animate_current_rebuild := false


@warning_ignore_restore("unused_private_class_variable")


func setup(_reduce_motion_enabled: bool = false) -> void:
	reduce_motion_enabled = _reduce_motion_enabled


func _ready() -> void:
	layer = 1200
	process_mode = Node.PROCESS_MODE_ALWAYS

	_app_font = load(FONT_PATH) as Font
	_service = _get_service()
	_settings_node = get_node_or_null("/root/UnilearnUserSettings")
	_connect_settings_signal()
	_last_theme_highlight_color = _theme_accent_color()

	_build_ui()
	_refresh_theme_live(true)

	await get_tree().process_frame
	await get_tree().process_frame

	if not is_inside_tree() or _closing:
		return

	_prepare_center_position()
	_style_scroll_bar()
	_connect_service()

	await _play_intro()

	if not is_inside_tree() or _closing:
		return

	_intro_finished = true
	set_process(false)
	await get_tree().process_frame
	_request_rebuild()


func _get_service() -> Node:
	for path in ["/root/UnilearnAchievements", "/root/UnilearnAchievementTracker", "/root/AchievementTracker"]:
		var existing := get_node_or_null(path)
		if existing != null:
			return existing

	push_warning("Achievement autoload is missing. Add res://addons/UnilearnLib/achievements/UnilearnAchievementTracker.gd as the UnilearnAchievements autoload.")
	return null


func _connect_service() -> void:
	if _service == null or not _service.has_signal("achievements_changed"):
		return

	var callback := Callable(self, "_on_achievements_changed")
	if not _service.is_connected("achievements_changed", callback):
		_service.connect("achievements_changed", callback)


func _on_achievements_changed(results: Array) -> void:
	if _intro_finished and not _closing:
		if has_method("_apply_achievement_results_delta") and bool(call("_apply_achievement_results_delta", results)):
			return
		_request_rebuild()


func _build_ui() -> void:
	pass


func _request_rebuild() -> void:
	pass


func _rebuild() -> void:
	pass


func _make_achievement_card(_result: Dictionary, _index: int) -> Control:
	return Control.new()


func _animate_card_in(_card: Control, _index: int) -> void:
	pass


func _prepare_center_position() -> void:
	pass


func _play_intro() -> void:
	pass


func close_popup() -> void:
	pass


func _style_scroll_bar() -> void:
	pass


func _panel_style() -> StyleBoxFlat:
	return StyleBoxFlat.new()


func _search_style() -> StyleBoxFlat:
	return StyleBoxFlat.new()


func _square_button_style() -> StyleBoxFlat:
	return StyleBoxFlat.new()


func _unlocked_box_style() -> StyleBoxFlat:
	return StyleBoxFlat.new()


func _tier_summary_style() -> StyleBoxFlat:
	return StyleBoxFlat.new()


func _achievement_card_style(_card_tier_color: Color, _tier: int, _rare_unlocked: bool = false) -> StyleBoxFlat:
	return StyleBoxFlat.new()


func _progress_back_style() -> StyleBoxFlat:
	return StyleBoxFlat.new()


func _progress_fill_style(_color: Color) -> StyleBoxFlat:
	return StyleBoxFlat.new()


func _scroll_track_style() -> StyleBoxFlat:
	return StyleBoxFlat.new()


func _scroll_grabber_style(_color: Color) -> StyleBoxFlat:
	return StyleBoxFlat.new()


func _apply_app_font(_control: Control) -> void:
	pass


func _play_sfx(_id: String) -> void:
	pass


func _tier_color(tier: int) -> Color:
	match tier:
		1:
			return Color("#CD7F32")
		2:
			return Color("#C0C7D4")
		3:
			return Color("#FFC62D")
		_:
			return Color(1, 1, 1, 0.35)


func _connect_settings_signal() -> void:
	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")

	if _settings_node == null:
		return

	if not _settings_node.has_signal("settings_changed"):
		return

	var callable := Callable(self, "_on_settings_changed")

	if not _settings_node.settings_changed.is_connected(callable):
		_settings_node.settings_changed.connect(callable)


func _on_settings_changed() -> void:
	if not is_inside_tree() or _closing:
		return

	_refresh_theme_live(true)


func _theme_accent_color() -> Color:
	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")

	if _settings_node != null and _settings_node.has_method("get_accent_color"):
		var value: Variant = _settings_node.call("get_accent_color")

		if value is Color:
			return value

	return COLOR_STATUS


func _get_theme_highlight_color() -> Color:
	return _theme_accent_color()


func _refresh_theme_live(force: bool = false) -> void:
	var old_highlight := _last_theme_highlight_color
	var new_highlight := _theme_accent_color()

	if not force and _colors_close(old_highlight, new_highlight):
		return

	_last_theme_highlight_color = new_highlight
	_style_cache.clear()

	if is_instance_valid(_panel):
		_panel.add_theme_stylebox_override("panel", _panel_style())

	if is_instance_valid(_search_shell):
		_search_shell.add_theme_stylebox_override("panel", _search_style())

	_refresh_back_button_highlight(new_highlight)
	_refresh_theme_recursive(self, old_highlight, new_highlight)

	call_deferred("_style_scroll_bar")


func _refresh_back_button_highlight(new_highlight: Color) -> void:
	if is_instance_valid(_back_button):
		_back_button.queue_redraw()

	if is_instance_valid(_back_button_icon):
		_back_button_icon.modulate = new_highlight

	if is_instance_valid(_back_button_fallback_arrow):
		_back_button_fallback_arrow.add_theme_color_override("font_color", new_highlight)


func _refresh_theme_recursive(node: Node, old_highlight: Color, new_highlight: Color) -> void:
	if node == null:
		return

	if node is Label:
		_refresh_label_highlight(node as Label, old_highlight, new_highlight)

	if node is RichTextLabel:
		_refresh_rich_text_highlight(node as RichTextLabel, old_highlight, new_highlight)

	if node is ColorRect:
		var rect := node as ColorRect

		if _colors_close(rect.color, old_highlight):
			rect.color = new_highlight

	if node is TextureRect:
		var texture_rect := node as TextureRect

		if _colors_close(texture_rect.modulate, old_highlight):
			texture_rect.modulate = new_highlight

	if node is Control:
		_refresh_control_highlight(node as Control, old_highlight, new_highlight)

	for child in node.get_children():
		_refresh_theme_recursive(child, old_highlight, new_highlight)


func _refresh_label_highlight(label: Label, old_highlight: Color, new_highlight: Color) -> void:
	if not is_instance_valid(label):
		return

	for color_name in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color",
		"font_hover_pressed_color",
		"font_disabled_color"
	]:
		var current := label.get_theme_color(color_name)

		if _colors_close(current, old_highlight):
			label.add_theme_color_override(color_name, new_highlight)


func _refresh_rich_text_highlight(rich: RichTextLabel, old_highlight: Color, new_highlight: Color) -> void:
	if not is_instance_valid(rich):
		return

	var old_hex := old_highlight.to_html(false)
	var new_hex := new_highlight.to_html(false)

	rich.text = rich.text.replace("#" + old_hex, "#" + new_hex)
	rich.text = rich.text.replace("#" + old_hex.to_upper(), "#" + new_hex.to_upper())


func _refresh_control_highlight(control: Control, old_highlight: Color, new_highlight: Color) -> void:
	if not is_instance_valid(control):
		return

	_refresh_named_panel_style(control)

	for style_name in [
		"panel",
		"normal",
		"hover",
		"pressed",
		"focus",
		"disabled"
	]:
		if not control.has_theme_stylebox(style_name):
			continue

		var style := control.get_theme_stylebox(style_name)

		if not (style is StyleBoxFlat):
			continue

		var flat := style as StyleBoxFlat
		var next_style := flat.duplicate() as StyleBoxFlat
		var changed := false

		if _colors_close(next_style.bg_color, old_highlight):
			next_style.bg_color = new_highlight
			changed = true

		if _colors_close(next_style.border_color, old_highlight):
			next_style.border_color = new_highlight
			changed = true

		if _colors_close(next_style.shadow_color, old_highlight):
			next_style.shadow_color = new_highlight
			changed = true

		if changed:
			control.add_theme_stylebox_override(style_name, next_style)


func _refresh_named_panel_style(control: Control) -> void:
	if not (control is PanelContainer):
		return

	var panel := control as PanelContainer

	match panel.name:
		"AchievementsPanel":
			panel.add_theme_stylebox_override("panel", _panel_style())

		"SearchShell":
			panel.add_theme_stylebox_override("panel", _search_style())

		"UnlockedAchievementCard":
			panel.add_theme_stylebox_override("panel", _unlocked_box_style())

		"TierSummaryCard":
			panel.add_theme_stylebox_override("panel", _tier_summary_style())

		"AchievementCategoryCard", "AchievementCard":
			var tier := int(panel.get_meta("achievement_tier", 0))
			var rare_unlocked := bool(panel.get_meta("achievement_rare_unlocked", false))
			var raw_tier_color: Variant = panel.get_meta("achievement_tier_color", _tier_color(tier))
			var tier_color = raw_tier_color if raw_tier_color is Color else _tier_color(tier)

			panel.add_theme_stylebox_override("panel", _achievement_card_style(tier_color, tier, rare_unlocked))


func _colors_close(a: Color, b: Color, tolerance: float = 0.01) -> bool:
	return (
		abs(a.r - b.r) <= tolerance
		and abs(a.g - b.g) <= tolerance
		and abs(a.b - b.b) <= tolerance
		and abs(a.a - b.a) <= tolerance
	)

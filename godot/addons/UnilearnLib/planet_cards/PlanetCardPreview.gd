extends PanelContainer
class_name PlanetCardPreview

signal selected(data: PlanetData)
signal sticker_saved(data: PlanetData, file_path: String)
signal sticker_save_failed(data: PlanetData, error_code: int)

const PIXEL_PLANET_SCRIPT := preload("res://addons/UnilearnLib/nodes/UnilearnPixelPlanet2D.gd")
const FONT_PATH := "res://assets/fonts/JockeyOne-Regular.ttf"

const COLOR_CARD_BG := Color.BLACK
const COLOR_CARD_BG_HOVER := Color(0.025, 0.025, 0.025, 1.0)
const COLOR_BORDER := Color.WHITE
const COLOR_BORDER_HOVER := Color.WHITE

const COLOR_PLANET_BACK := Color.BLACK
const COLOR_TEXT_AREA := Color.WHITE
const COLOR_TEXT := Color.BLACK

const BORDER_WIDTH := 6.0
const CARD_RADIUS := 36.0

const NAME_FONT_SIZE_MAX := 58
const NAME_FONT_SIZE_MIN := 28
const NAME_TEXT_SIDE_PADDING := 28.0

const EARTH_DIAMETER_KM := 12742.0
const EARTH_PREVIEW_WIDTH_FILL := 0.52
const PLANET_MAX_VIEW_FILL := 0.72
const STAR_MAX_VIEW_FILL := 0.90
const SINGULARITY_MAX_VIEW_FILL := 0.92
const SINGULARITY_PREVIEW_VISUAL_DIAMETER_MULTIPLIER := 1.72
const SINGULARITY_PREVIEW_NO_DISK_VISUAL_DIAMETER_MULTIPLIER := 1.02
const MIN_BODY_VIEW_FILL := 0.14

const PLANET_SIZE_POWER := 0.18
const STAR_SIZE_POWER := 0.10
const SMALL_BODY_SIZE_POWER := 0.28

const CARD_STAR_COUNT := 67
const CARD_STAR_TEXTURE_SIZE := 24
const CARD_STAR_MIN_RADIUS := 1.1
const CARD_STAR_MAX_RADIUS := 3.4
const CARD_STAR_MIN_ALPHA := 0.32
const CARD_STAR_MAX_ALPHA := 0.92

const TAP_SCALE_DOWN := 0.96
const TAP_SCALE_UP := 1.0
const TAP_DOWN_TIME := 0.055
const TAP_UP_TIME := 0.11
const TAP_SETTLE_TIME := 0.10

const STICKER_HOLD_SECONDS := 3.0
const STICKER_HOLD_VISUAL_DELAY := 0.25
const STICKER_HOLD_REVERSE_SECONDS := 0.62
const STICKER_HOLD_TAP_CUTOFF := 0.045
const STICKER_FILL_RETURN_SECONDS := 0.34
const STICKER_CAPTURE_WIDTH := 2160
const STICKER_EXPORT_WIDTH := 3840
const STICKER_FOLDER_NAME := "Unilearn Stickers"
const STICKER_RENDER_DOTS_INTERVAL := 0.5
const STICKER_THREAD_POLL_INTERVAL := 0.08

const STICKER_TOAST_LAYER := 10060
const STICKER_TOAST_WIDTH := 553.0
const STICKER_TOAST_HEIGHT := 188.0
const STICKER_TOAST_TOP_MARGIN := 320.0
const STICKER_TOAST_RIGHT_MARGIN := 34.0
const STICKER_TOAST_ICON_SIZE := 132.0
const STICKER_TOAST_IN_TIME := 0.58
const STICKER_TOAST_OUT_TIME := 0.46
const STICKER_TOAST_COMPLETE_HOLD := 2.0
const PLANET_CARDS_ICON_PATH := "res://assets/app/buttons/button_card.png"
const STICKER_RENDER_LOCK_META := "unilearn_sticker_render_lock"

const TEXT_HEIGHT := 116.0

var data: PlanetData

var _root: Control
var _planet_back: Panel
var _stars_clip: Control
var _stars_layer: MultiMeshInstance2D
var _stars_multimesh: MultiMesh
var _card_star_texture: Texture2D
var _planet_clip: Control
var _planet_node: Node2D
var _name_label: Label
var _text_back: Panel
var _tap_catcher: Control
var _border_overlay: Control
var _hold_border_material: ShaderMaterial
var _hold_text_material: ShaderMaterial
var _app_font: Font = null

var _card_star_seed := 0

var _pressing := false
var _press_start_pos := Vector2.ZERO
var _max_drag_distance := 0.0
var _tap_threshold := 20.0
var _hovered := false
var _bounce_tween: Tween = null
var sticker_export_enabled := true
var sticker_capture_mode := false
var sticker_render_scale := 1.0
var _hold_generation := 0
var _hold_fill_progress := 0.0
var _hold_fill_tween: Tween = null
var _hold_fill_color_cache := Color.TRANSPARENT
var _ignore_next_release := false
var _sticker_export_running := false
var _sticker_cancel_sfx_played := false
var _sticker_detached_for_background := false

var _sticker_toast_layer: CanvasLayer = null
var _sticker_toast_panel: PanelContainer = null
var _sticker_toast_title: Label = null
var _sticker_toast_name: Label = null
var _sticker_toast_status: Label = null
var _sticker_toast_icon_shell: PanelContainer = null
var _sticker_toast_icon_texture: TextureRect = null
var _sticker_toast_tween: Tween = null
var _sticker_toast_generation := 0
var _sticker_toast_planet_name := ""
var _sticker_toast_rendering_active := false
var _sticker_toast_render_dots := 1
var _sticker_toast_render_accum := 0.0
var _sticker_dots_timer: Timer = null
var _sticker_thread_poll_timer: Timer = null
var _sticker_save_thread: Thread = null
var _settings_node: Node = null

var _body_category_cache := "planet"
var _diameter_km_cache := 0.0
var _visual_offset_cache := Vector2.ZERO

var _last_layout_size := Vector2(-1.0, -1.0)
var _last_name_width := -1.0

var _normal_card_style: StyleBoxFlat
var _hover_card_style: StyleBoxFlat
var _planet_background_style_cache: StyleBoxFlat
var _text_background_style_cache: StyleBoxFlat


func _get_global_sticker_render_info() -> Dictionary:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return {}
	var value: Variant = tree.root.get_meta(STICKER_RENDER_LOCK_META, {})
	return value if value is Dictionary else {}


func _is_global_sticker_render_active() -> bool:
	var info := _get_global_sticker_render_info()
	return bool(info.get("active", false))


func _acquire_global_sticker_render_lock(planet_name: String) -> bool:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return true
	if _is_global_sticker_render_active():
		return false
	tree.root.set_meta(STICKER_RENDER_LOCK_META, {
		"active": true,
		"owner_instance_id": str(get_instance_id()),
		"planet_name": planet_name,
		"started_msec": Time.get_ticks_msec()
	})
	return true


func _release_global_sticker_render_lock() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	if tree.root.has_meta(STICKER_RENDER_LOCK_META):
		tree.root.remove_meta(STICKER_RENDER_LOCK_META)


func setup(value: PlanetData) -> void:
	data = value

	if data != null:
		_cache_planet_metadata()

	if is_inside_tree():
		_rebuild()


func _ready() -> void:
	_app_font = load(FONT_PATH) as Font
	set_process(false)
	_rebuild()


func _process(_delta: float) -> void:
	var should_keep_processing := false

	# Keep the completed hold fully highlighted for the entire asynchronous render,
	# while following text-highlight theme changes live.
	if _hold_fill_progress > 0.0001 or _sticker_export_running:
		should_keep_processing = true
		_refresh_live_hold_fill_color()

	if _sticker_save_thread != null:
		should_keep_processing = true
		if not _sticker_save_thread.is_alive():
			var thread_result: Variant = _sticker_save_thread.wait_to_finish()
			_sticker_save_thread = null
			_stop_sticker_thread_poll_timer()
			if thread_result is Dictionary:
				_on_sticker_save_thread_finished(thread_result)
			else:
				_on_sticker_save_thread_finished({"error": ERR_CANT_CREATE, "path": ""})

	if is_instance_valid(_sticker_toast_panel):
		_refresh_sticker_toast_theme()
		if _sticker_toast_panel.visible:
			should_keep_processing = true

	set_process(should_keep_processing)


func _exit_tree() -> void:
	# Reparenting an active sticker driver from the closing popup to the scene
	# root can emit tree-exit notifications. Its global timers must stay wired
	# until the background render and toast animation are completely finished.
	if _sticker_detached_for_background:
		return
	_disconnect_sticker_toast_timers()


func keep_sticker_render_alive_after_popup_close() -> bool:
	var toast_active := is_instance_valid(_sticker_toast_panel) and _sticker_toast_panel.visible
	if (not _sticker_export_running and not toast_active) or not is_inside_tree():
		return false
	var tree := get_tree()
	if tree == null or tree.root == null:
		return false
	_sticker_detached_for_background = true
	sticker_export_enabled = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_parent() != tree.root:
		reparent(tree.root, false)
	set_process(true)
	return true


func _rebuild() -> void:
	if data == null:
		return

	_clear_children()
	_cache_planet_metadata()
	_build_styles()

	_card_star_seed = _make_star_seed()

	custom_minimum_size = Vector2(0, 540)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	pivot_offset = size * 0.5
	scale = Vector2.ONE

	add_theme_stylebox_override("panel", _normal_card_style)

	if not mouse_entered.is_connected(Callable(self, "_on_mouse_entered")):
		mouse_entered.connect(_on_mouse_entered)

	if not mouse_exited.is_connected(Callable(self, "_on_mouse_exited")):
		mouse_exited.connect(_on_mouse_exited)

	_root = Control.new()
	_root.name = "CardRoot"
	_make_manual_control(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.clip_contents = false
	add_child(_root)

	_planet_back = Panel.new()
	_planet_back.name = "PlanetBackground"
	_make_manual_control(_planet_back)
	_planet_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_planet_back.clip_contents = true
	_planet_back.add_theme_stylebox_override("panel", _planet_background_style_cache)
	_root.add_child(_planet_back)

	_stars_clip = Control.new()
	_stars_clip.name = "StaticStarsClip"
	_make_manual_control(_stars_clip)
	_stars_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stars_clip.clip_contents = true
	_root.add_child(_stars_clip)

	_stars_layer = MultiMeshInstance2D.new()
	_stars_layer.name = "StaticStars"
	_stars_layer.z_index = 0
	_stars_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_stars_layer.texture = _get_card_star_texture()

	_stars_multimesh = MultiMesh.new()
	_stars_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_stars_multimesh.use_colors = true
	_stars_multimesh.mesh = _make_card_star_mesh()
	_stars_multimesh.instance_count = CARD_STAR_COUNT
	_stars_layer.multimesh = _stars_multimesh
	_stars_clip.add_child(_stars_layer)

	_planet_clip = Control.new()
	_planet_clip.name = "PlanetClip"
	_make_manual_control(_planet_clip)
	_planet_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_planet_clip.clip_contents = true
	_root.add_child(_planet_clip)

	_text_back = Panel.new()
	_text_back.name = "TextBackground"
	_make_manual_control(_text_back)
	_text_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_back.add_theme_stylebox_override("panel", _text_background_style_cache)
	_root.add_child(_text_back)

	_name_label = _make_label(
		data.name.to_upper(),
		roundi(NAME_FONT_SIZE_MAX * _render_scale()),
		COLOR_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_name_label.name = "PlanetName"
	_make_manual_control(_name_label)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.z_index = 3
	_root.add_child(_name_label)

	_planet_node = PIXEL_PLANET_SCRIPT.new()
	_planet_node.name = "PlanetCardPlanetPreview"
	_planet_node.z_index = 2
	_planet_node.process_mode = Node.PROCESS_MODE_INHERIT
	_planet_node.set("composite_visual_for_parent_modulate", true)
	_planet_clip.add_child(_planet_node)

	_apply_planet_data(_planet_node, data, data.planet_radius_px)

	_tap_catcher = Control.new()
	_tap_catcher.name = "TapCatcher"
	_make_manual_control(_tap_catcher)
	_tap_catcher.mouse_filter = Control.MOUSE_FILTER_PASS
	_tap_catcher.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_tap_catcher.gui_input.connect(_on_card_gui_input)
	add_child(_tap_catcher)

	_border_overlay = Control.new()
	_border_overlay.name = "BorderOverlay"
	_make_manual_control(_border_overlay)
	_border_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border_overlay.z_index = 999
	_border_overlay.draw.connect(_draw_border_overlay)
	add_child(_border_overlay)
	_setup_hold_fill_material()

	_tap_catcher.move_to_front()
	_tap_catcher.move_to_front()

	_last_layout_size = Vector2(-1.0, -1.0)
	_last_name_width = -1.0

	if not resized.is_connected(Callable(self, "_layout_card")):
		resized.connect(_layout_card)

	call_deferred("_layout_card")


func _cache_planet_metadata() -> void:
	_body_category_cache = _compute_body_category()
	_diameter_km_cache = _compute_object_diameter_km(_body_category_cache)
	_visual_offset_cache = _preview_visual_offset(data.instance_id)


func _build_styles() -> void:
	_normal_card_style = _make_card_style(COLOR_CARD_BG)
	_hover_card_style = _make_card_style(COLOR_CARD_BG_HOVER)
	_planet_background_style_cache = _make_planet_background_style()
	_text_background_style_cache = _make_text_background_style()


func _make_manual_control(control: Control) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _layout_card() -> void:
	if not is_instance_valid(_root):
		return

	var card_size := size

	if card_size.x <= 0.0 or card_size.y <= 0.0:
		card_size = custom_minimum_size

	if card_size == _last_layout_size:
		return

	_last_layout_size = card_size
	pivot_offset = card_size * 0.5

	var scaled_text_height := TEXT_HEIGHT * _render_scale()
	var planet_height := max(0.0, card_size.y - scaled_text_height)

	_root.position = Vector2.ZERO
	_root.size = card_size

	var planet_rect := Rect2(Vector2.ZERO, Vector2(card_size.x, planet_height))
	var text_rect := Rect2(Vector2(0.0, planet_height), Vector2(card_size.x, scaled_text_height))

	_planet_back.position = planet_rect.position
	_planet_back.size = planet_rect.size

	_stars_clip.position = planet_rect.position
	_stars_clip.size = planet_rect.size
	_update_static_stars_multimesh(planet_rect.size)

	_planet_clip.position = planet_rect.position
	_planet_clip.size = planet_rect.size

	_text_back.position = text_rect.position
	_text_back.size = text_rect.size

	_name_label.position = text_rect.position
	_name_label.size = text_rect.size
	_fit_name_label_font_size()

	_tap_catcher.position = Vector2.ZERO
	_tap_catcher.size = card_size

	if is_instance_valid(_border_overlay):
		_border_overlay.position = Vector2.ZERO
		_border_overlay.size = card_size
		_border_overlay.queue_redraw()


	_update_hold_fill_shader_parameters()

	_center_preview_planet()


func _center_preview_planet() -> void:
	if not is_instance_valid(_planet_clip) or not is_instance_valid(_planet_node) or data == null:
		return

	var clip_size := _planet_clip.size

	if clip_size.x <= 0.0 or clip_size.y <= 0.0:
		return

	var desired_display_diameter := _get_preview_display_diameter(clip_size)
	var source_body_diameter := max(float(data.planet_radius_px) * 2.0, 1.0)
	if _body_category_cache == "black_hole":
		source_body_diameter *= _singularity_preview_diameter_multiplier(data)
	var preview_scale: float = desired_display_diameter / source_body_diameter

	_planet_node.scale = Vector2.ONE * preview_scale
	_planet_node.position = (clip_size * 0.5) + (_visual_offset_cache * _render_scale())


func _get_preview_display_diameter(clip_size: Vector2) -> float:
	var base_size := min(clip_size.x, clip_size.y)
	var earth_display_diameter := clip_size.x * EARTH_PREVIEW_WIDTH_FILL
	var min_display_diameter: float = base_size * MIN_BODY_VIEW_FILL
	var max_fill := PLANET_MAX_VIEW_FILL
	if _body_category_cache == "star":
		max_fill = STAR_MAX_VIEW_FILL
	elif _body_category_cache == "black_hole":
		max_fill = SINGULARITY_MAX_VIEW_FILL
	var max_display_diameter: float = base_size * max_fill

	if _body_category_cache == "black_hole":
		return max_display_diameter

	if _diameter_km_cache > 0.0:
		var visual_ratio := _get_visual_size_ratio(_diameter_km_cache, _body_category_cache)
		var display_diameter := earth_display_diameter * visual_ratio

		if _body_category_cache == "star":
			display_diameter = max(display_diameter, earth_display_diameter * 1.18)

		elif _body_category_cache == "planet" and _diameter_km_cache > EARTH_DIAMETER_KM:
			display_diameter = max(display_diameter, earth_display_diameter * 1.04)

		return clamp(display_diameter, min_display_diameter, max_display_diameter)

	return clamp(_fallback_display_diameter(clip_size, _body_category_cache), min_display_diameter, max_display_diameter)


func _get_visual_size_ratio(object_diameter_km: float, category: String) -> float:
	var real_ratio: float = max(object_diameter_km / EARTH_DIAMETER_KM, 0.01)

	match category:
		"star":
			return max(1.18, pow(real_ratio, STAR_SIZE_POWER))

		"moon", "satellite":
			return pow(real_ratio, SMALL_BODY_SIZE_POWER)

		"dwarf_planet":
			return min(0.92, pow(real_ratio, SMALL_BODY_SIZE_POWER))

		_:
			return max(0.18, pow(real_ratio, PLANET_SIZE_POWER))


func _compute_body_category() -> String:
	if data == null:
		return "planet"

	var category := data.object_category.strip_edges().to_lower()
	var archetype := data.archetype_id.strip_edges().to_lower()
	var preset := data.planet_preset.strip_edges().to_lower()
	var instance_id := data.instance_id.strip_edges().to_lower()

	if category == "singularity" or category == "black_hole" or category == "white_hole" or archetype == "black_hole" or archetype == "white_hole" or preset == "black_hole" or preset == "white_hole" or instance_id.contains("black_hole") or instance_id.contains("white_hole"):
		return "black_hole"

	if category == "star" or archetype == "star" or preset == "star" or instance_id.contains("sun") or instance_id.contains("star"):
		return "star"

	if category == "satellite" or category == "moon" or archetype.contains("moon") or preset == "moon":
		return "satellite"

	if category == "dwarf_planet" or archetype.contains("dwarf"):
		return "dwarf_planet"

	return "planet"


func _compute_object_diameter_km(category: String) -> float:
	if data == null:
		return 0.0

	var parsed := _parse_first_number(data.diameter_km)

	if parsed > 0.0:
		return parsed

	var archetype := data.archetype_id.strip_edges().to_lower()
	var preset := data.planet_preset.strip_edges().to_lower()
	var name := data.name.strip_edges().to_lower()
	var id := data.instance_id.strip_edges().to_lower()

	if category == "star":
		return EARTH_DIAMETER_KM * 109.0

	if category == "black_hole":
		return EARTH_DIAMETER_KM * 220.0

	if name.contains("jupiter") or id.contains("jupiter"):
		return 139820.0

	if name.contains("saturn") or id.contains("saturn"):
		return 116460.0

	if name.contains("uranus") or id.contains("uranus"):
		return 50724.0

	if name.contains("neptune") or id.contains("neptune"):
		return 49244.0

	if name.contains("earth") or id.contains("earth"):
		return EARTH_DIAMETER_KM

	if name.contains("venus") or id.contains("venus"):
		return 12104.0

	if name.contains("mars") or id.contains("mars"):
		return 6779.0

	if name.contains("mercury") or id.contains("mercury"):
		return 4879.0

	if archetype.contains("gas") or preset.contains("gas"):
		return EARTH_DIAMETER_KM * 8.5

	if archetype.contains("ice"):
		return EARTH_DIAMETER_KM * 4.0

	if category == "satellite" or category == "moon":
		return EARTH_DIAMETER_KM * 0.32

	if category == "dwarf_planet":
		return EARTH_DIAMETER_KM * 0.22

	return 0.0


func _parse_first_number(value: String) -> float:
	return _parse_scaled_number(value)


func _parse_scaled_number(value: String) -> float:
	var text := value.strip_edges()

	if text.is_empty():
		return 0.0

	text = _clean_number_text(text)
	text = _normalize_superscript_exponents(text)

	var sci_value := _parse_scientific_notation_number(text)

	if sci_value > 0.0:
		return sci_value

	return _parse_normal_number(text)


func _clean_number_text(value: String) -> String:
	var text := value

	text = text.replace("~", "")
	text = text.replace("≈", "")
	text = text.replace("approx.", "")
	text = text.replace("Approx.", "")
	text = text.replace("approximately", "")
	text = text.replace("Approximately", "")
	text = text.replace("about", "")
	text = text.replace("About", "")
	text = text.replace("around", "")
	text = text.replace("Around", "")
	text = text.replace("roughly", "")
	text = text.replace("Roughly", "")

	text = text.replace("×", "x")
	text = text.replace("X", "x")
	text = text.replace("*", "x")

	text = text.replace(" to the power of ", "^")
	text = text.replace(" power of ", "^")
	text = text.replace(" at a power of ", "^")
	text = text.replace(" raised to ", "^")

	return text.strip_edges()


func _normalize_superscript_exponents(value: String) -> String:
	var text := value

	var superscripts := {
		"⁰": "0",
		"¹": "1",
		"²": "2",
		"³": "3",
		"⁴": "4",
		"⁵": "5",
		"⁶": "6",
		"⁷": "7",
		"⁸": "8",
		"⁹": "9",
		"⁻": "-"
	}

	for key in superscripts.keys():
		text = text.replace(key, superscripts[key])

	return text


func _parse_scientific_notation_number(text: String) -> float:
	var regex := RegEx.new()

	# Handles:
	# 1.2e10
	# 1.2E10
	# 1.2x10^10
	# 1.2 x 10^10
	# 1.2x10 10
	# 1.2 x 10 at a power of 10
	regex.compile("([-+]?\\d+(?:[\\.,]\\d+)?)\\s*(?:e|x\\s*10\\s*\\^?|x\\s*10)\\s*([-+]?\\d+)")

	var match_result := regex.search(text)

	if match_result == null:
		return 0.0

	var base_text := match_result.get_string(1).replace(",", ".")
	var exponent_text := match_result.get_string(2)

	var base := base_text.to_float()
	var exponent := exponent_text.to_int()

	if base == 0.0:
		return 0.0

	return base * pow(10.0, float(exponent))


func _parse_normal_number(text: String) -> float:
	var regex := RegEx.new()
	regex.compile("[-+]?\\d[\\d\\.,\\s]*(?:[eE][-+]?\\d+)?")

	var match_result := regex.search(text)

	if match_result == null:
		return 0.0

	var raw := match_result.get_string().strip_edges()

	if raw.is_empty():
		return 0.0

	raw = raw.replace(" ", "")

	var comma_count := raw.count(",")
	var dot_count := raw.count(".")

	if raw.to_lower().contains("e"):
		raw = raw.replace(",", ".")
		return raw.to_float()

	if dot_count > 1 and comma_count == 0:
		raw = raw.replace(".", "")
		return raw.to_float()

	if comma_count > 1 and dot_count == 0:
		raw = raw.replace(",", "")
		return raw.to_float()

	if comma_count > 0 and dot_count == 1 and raw.find(",") < raw.find("."):
		raw = raw.replace(",", "")
		return raw.to_float()

	if dot_count > 0 and comma_count == 1 and raw.rfind(".") < raw.find(","):
		raw = raw.replace(".", "")
		raw = raw.replace(",", ".")
		return raw.to_float()

	if dot_count == 1 and comma_count == 0:
		var parts := raw.split(".")

		if parts.size() == 2 and parts[1].length() == 3 and parts[0].length() <= 3:
			raw = raw.replace(".", "")
			return raw.to_float()

		return raw.to_float()

	if comma_count == 1 and dot_count == 0:
		var parts := raw.split(",")

		if parts.size() == 2 and parts[1].length() == 3 and parts[0].length() <= 3:
			raw = raw.replace(",", "")
			return raw.to_float()

		raw = raw.replace(",", ".")
		return raw.to_float()

	raw = raw.replace(",", "")
	return raw.to_float()


func _fallback_display_diameter(clip_size: Vector2, category: String) -> float:
	var base_size := min(clip_size.x, clip_size.y)
	var earth_display_diameter := clip_size.x * EARTH_PREVIEW_WIDTH_FILL
	var radius_ratio := float(max(data.planet_radius_px, 1)) / 142.0

	if category == "star" or category == "black_hole":
		return base_size * STAR_MAX_VIEW_FILL

	if category == "satellite" or category == "moon":
		return earth_display_diameter * 0.68

	if category == "dwarf_planet":
		return earth_display_diameter * 0.58

	return earth_display_diameter * pow(max(radius_ratio, 0.05), PLANET_SIZE_POWER)


func _fit_name_label_font_size() -> void:
	if not is_instance_valid(_name_label):
		return

	var scale_factor := _render_scale()
	var available_width: float = max(_name_label.size.x - (NAME_TEXT_SIDE_PADDING * 2.0 * scale_factor), 1.0)

	if is_equal_approx(available_width, _last_name_width):
		return

	_last_name_width = available_width

	var font_size := roundi(NAME_FONT_SIZE_MAX * scale_factor)
	var minimum_font_size := roundi(NAME_FONT_SIZE_MIN * scale_factor)

	while font_size > minimum_font_size:
		if _get_text_width(_name_label.text, font_size) <= available_width:
			break

		font_size -= 1

	_name_label.add_theme_font_size_override("font_size", font_size)


func _get_text_width(text: String, font_size: int) -> float:
	if _app_font != null:
		return _app_font.get_string_size(
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size
		).x

	return float(text.length() * font_size) * 0.58


func _update_static_stars_multimesh(area_size: Vector2) -> void:
	if not is_instance_valid(_stars_layer) or _stars_multimesh == null:
		return

	if area_size.x <= 0.0 or area_size.y <= 0.0:
		return

	if _stars_multimesh.instance_count != CARD_STAR_COUNT:
		_stars_multimesh.instance_count = CARD_STAR_COUNT

	for i in range(CARD_STAR_COUNT):
		var x := _hash01(i, 11, _card_star_seed) * area_size.x
		var y := _hash01(i, 23, _card_star_seed) * area_size.y
		var radius: float = lerp(CARD_STAR_MIN_RADIUS, CARD_STAR_MAX_RADIUS, _hash01(i, 37, _card_star_seed)) * _render_scale()
		var alpha := lerp(CARD_STAR_MIN_ALPHA, CARD_STAR_MAX_ALPHA, _hash01(i, 41, _card_star_seed))

		if _hash01(i, 53, _card_star_seed) > 0.82:
			radius *= 1.55
			alpha = min(1.0, alpha + 0.18)

		var diameter = radius * 2.0
		var star_transform := Transform2D(
			Vector2(diameter, 0.0),
			Vector2(0.0, diameter),
			Vector2(x, y)
		)
		_stars_multimesh.set_instance_transform_2d(i, star_transform)
		_stars_multimesh.set_instance_color(i, Color(1.0, 1.0, 1.0, alpha))


func _make_card_star_mesh() -> Mesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	return mesh


func _get_card_star_texture() -> Texture2D:
	if _card_star_texture != null:
		return _card_star_texture

	var texture_size := maxi(CARD_STAR_TEXTURE_SIZE, roundi(CARD_STAR_TEXTURE_SIZE * _render_scale()))
	var image := Image.create(texture_size, texture_size, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))

	var center := Vector2(float(texture_size - 1) * 0.5, float(texture_size - 1) * 0.5)
	var radius := float(texture_size) * 0.42
	var feather := max(3.0, 3.0 * _render_scale())

	for y in range(texture_size):
		for x in range(texture_size):
			var distance := Vector2(float(x), float(y)).distance_to(center)
			var alpha := 1.0 - smoothstep(radius - feather, radius, distance)
			if alpha > 0.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clamp(alpha, 0.0, 1.0)))

	_card_star_texture = ImageTexture.create_from_image(image)
	return _card_star_texture



func _draw_top_rounded_corner_masks(_rect: Rect2, _radius: float) -> void:
	if not is_instance_valid(_border_overlay):
		return

	var card_size := _border_overlay.size

	if card_size.x <= 0.0 or card_size.y <= 0.0:
		return

	var scale_factor := _render_scale()
	var radius := min((CARD_RADIUS + BORDER_WIDTH) * scale_factor, min(card_size.x, card_size.y) * 0.5)
	var mask_color := COLOR_CARD_BG
	_draw_single_top_corner_mask(Vector2.ZERO, true, radius, mask_color)
	_draw_single_top_corner_mask(Vector2(card_size.x, 0.0), false, radius, mask_color)


func _draw_single_top_corner_mask(corner: Vector2, left_corner: bool, radius: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()

	if left_corner:
		points.append(corner)
		points.append(corner + Vector2(radius, 0.0))
		var center := corner + Vector2(radius, radius)
		for i in range(22):
			var t := float(i) / 21.0
			var angle := lerp(PI * 1.5, PI, t)
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		points.append(corner + Vector2(0.0, radius))
	else:
		points.append(corner)
		points.append(corner + Vector2(-radius, 0.0))
		var center := corner + Vector2(-radius, radius)
		for i in range(22):
			var t := float(i) / 21.0
			var angle := lerp(PI * 1.5, TAU, t)
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		points.append(corner + Vector2(0.0, radius))

	_border_overlay.draw_colored_polygon(points, color)


func _draw_border_overlay() -> void:
	if not is_instance_valid(_border_overlay):
		return

	var border_color := COLOR_BORDER_HOVER if _hovered else COLOR_BORDER
	var rect := Rect2(
		Vector2(BORDER_WIDTH * _render_scale() * 0.5, BORDER_WIDTH * _render_scale() * 0.5),
		_border_overlay.size - Vector2(BORDER_WIDTH * _render_scale(), BORDER_WIDTH * _render_scale())
	)

	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return

	var radius := min(CARD_RADIUS * _render_scale(), min(rect.size.x, rect.size.y) * 0.5)
	if not sticker_capture_mode:
		_draw_top_rounded_corner_masks(rect, radius)

	_border_overlay.draw_arc(
		Vector2(rect.position.x + radius, rect.position.y + radius),
		radius,
		PI,
		PI * 1.5,
		24,
		border_color,
		BORDER_WIDTH * _render_scale(),
		true
	)

	_border_overlay.draw_arc(
		Vector2(rect.end.x - radius, rect.position.y + radius),
		radius,
		PI * 1.5,
		TAU,
		24,
		border_color,
		BORDER_WIDTH * _render_scale(),
		true
	)

	_border_overlay.draw_arc(
		Vector2(rect.end.x - radius, rect.end.y - radius),
		radius,
		0.0,
		PI * 0.5,
		24,
		border_color,
		BORDER_WIDTH * _render_scale(),
		true
	)

	_border_overlay.draw_arc(
		Vector2(rect.position.x + radius, rect.end.y - radius),
		radius,
		PI * 0.5,
		PI,
		24,
		border_color,
		BORDER_WIDTH * _render_scale(),
		true
	)

	_border_overlay.draw_line(
		Vector2(rect.position.x + radius, rect.position.y),
		Vector2(rect.end.x - radius, rect.position.y),
		border_color,
		BORDER_WIDTH * _render_scale(),
		true
	)

	_border_overlay.draw_line(
		Vector2(rect.end.x, rect.position.y + radius),
		Vector2(rect.end.x, rect.end.y - radius),
		border_color,
		BORDER_WIDTH * _render_scale(),
		true
	)

	_border_overlay.draw_line(
		Vector2(rect.end.x - radius, rect.end.y),
		Vector2(rect.position.x + radius, rect.end.y),
		border_color,
		BORDER_WIDTH * _render_scale(),
		true
	)

	_border_overlay.draw_line(
		Vector2(rect.position.x, rect.end.y - radius),
		Vector2(rect.position.x, rect.position.y + radius),
		border_color,
		BORDER_WIDTH * _render_scale(),
		true
	)


func _setup_hold_fill_material() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float fill_amount : hint_range(0.0, 1.0) = 0.0;
uniform float control_height = 1.0;
uniform vec4 replacement_color : source_color = vec4(1.0);
varying float local_vertex_y;

void vertex() {
	local_vertex_y = VERTEX.y;
}

void fragment() {
	vec4 original_pixel = COLOR;
	float white_pixel = step(0.9, min(original_pixel.r, min(original_pixel.g, original_pixel.b)));
	float fill_boundary_y = control_height * (1.0 - fill_amount);
	float converted = step(fill_boundary_y, local_vertex_y) * step(0.000001, fill_amount) * white_pixel;
	COLOR = vec4(
		mix(original_pixel.rgb, replacement_color.rgb, converted),
		original_pixel.a * mix(1.0, replacement_color.a, converted)
	);
}
"""
	_hold_border_material = ShaderMaterial.new()
	_hold_border_material.shader = shader
	_hold_text_material = ShaderMaterial.new()
	_hold_text_material.shader = shader
	_border_overlay.material = _hold_border_material
	_text_back.material = _hold_text_material
	_update_hold_fill_shader_parameters()


func _update_hold_fill_shader_parameters() -> void:
	if _hold_border_material == null or _hold_text_material == null:
		return
	var card_height := maxf(size.y, custom_minimum_size.y)
	var text_height := maxf(TEXT_HEIGHT * _render_scale(), 1.0)
	var text_fill_progress := clampf(_hold_fill_progress * card_height / text_height, 0.0, 1.0)
	_hold_border_material.set_shader_parameter("fill_amount", _hold_fill_progress)
	_hold_border_material.set_shader_parameter("control_height", card_height)
	_hold_text_material.set_shader_parameter("fill_amount", text_fill_progress)
	_hold_text_material.set_shader_parameter("control_height", text_height)
	_hold_fill_color_cache = _get_sticker_highlight_color()
	_hold_border_material.set_shader_parameter("replacement_color", _hold_fill_color_cache)
	_hold_text_material.set_shader_parameter("replacement_color", _hold_fill_color_cache)


func _refresh_live_hold_fill_color() -> void:
	if _hold_border_material == null or _hold_text_material == null:
		return
	var live_color := _get_sticker_highlight_color()
	if not live_color.is_equal_approx(_hold_fill_color_cache):
		_hold_fill_color_cache = live_color
		_hold_border_material.set_shader_parameter("replacement_color", live_color)
		_hold_text_material.set_shader_parameter("replacement_color", live_color)


func _get_sticker_highlight_color() -> Color:
	if has_node("/root/UnilearnUserSettings"):
		var settings := get_node("/root/UnilearnUserSettings")
		if settings.has_method("get_text_highlighted_color"):
			var value: Variant = settings.call("get_text_highlighted_color")
			if value is Color:
				return value
		# UnilearnUserSettings currently maps the highlighted UI color through
		# get_accent_color(): orange in light mode and purple in dark mode.
		if settings.has_method("get_accent_color"):
			var accent_value: Variant = settings.call("get_accent_color")
			if accent_value is Color:
				return accent_value
		for property_name in ["text_highlighted_color", "textHighlightedColor", "highlighted_text_color", "highlightedTextColor", "text_highlight_color", "textHighlightColor"]:
			var property_value: Variant = settings.get(property_name)
			if property_value is Color:
				return property_value
	return Color(1.0, 0.82, 0.34, 0.98)


func _make_star_seed() -> int:
	if data == null:
		return 918273

	var source := "%s_%s_%s" % [data.instance_id, data.name, str(data.planet_seed)]
	var seed := 2166136261

	for i in range(source.length()):
		seed = int(seed ^ source.unicode_at(i))
		seed = int(seed * 16777619)
		seed = seed & 0x7fffffff

	return max(seed, 1)


func _hash01(a: int, b: int, seed: int) -> float:
	var n := seed
	n ^= a * 374761393
	n ^= b * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / 2147483647.0


func _make_label(value: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_apply_app_font(label)
	return label


func _on_card_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_card_press(event.position)
		else:
			_finish_card_press()
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_card_press(event.position)
		else:
			_finish_card_press()
		return

	if event is InputEventMouseMotion and _pressing:
		_update_card_drag(event.position)
		return

	if event is InputEventScreenDrag and _pressing:
		_update_card_drag(event.position)
		return


func _begin_card_press(position: Vector2) -> void:
	_hold_generation += 1
	_ignore_next_release = false
	_pressing = true
	_press_start_pos = position
	_max_drag_distance = 0.0
	_bounce_down()

	# Once this exact card owns a render, further presses are ordinary taps only.
	# They must never restart or cancel its locked completed hold state.
	if sticker_export_enabled and not _sticker_export_running:
		_start_sticker_hold_animation(_hold_generation)


func _finish_card_press() -> void:
	_hold_generation += 1

	if _ignore_next_release:
		_ignore_next_release = false
		_pressing = false
		accept_event()
		return

	var was_intentional_hold := sticker_export_enabled and not _sticker_export_running and _hold_fill_progress >= STICKER_HOLD_TAP_CUTOFF
	if was_intentional_hold:
		_pressing = false
		_bounce_cancel()
		_reverse_sticker_hold_animation()
		accept_event()
		return

	if _pressing and _max_drag_distance <= _tap_threshold:
		if not _sticker_export_running:
			_cancel_sticker_hold_immediately()
		_play_sfx("click")
		_bounce_tap()
		_stamp_preview_animation_time()
		selected.emit(data)
		accept_event()
	else:
		_bounce_cancel()

	_pressing = false


func _update_card_drag(position: Vector2) -> void:
	_max_drag_distance = max(_max_drag_distance, _press_start_pos.distance_to(position))

	if _max_drag_distance > _tap_threshold:
		_hold_generation += 1
		_pressing = false
		_bounce_cancel()
		if not _sticker_export_running:
			_reverse_sticker_hold_animation()


func _cancel_sticker_hold_immediately() -> void:
	if _hold_fill_tween != null and _hold_fill_tween.is_valid():
		_hold_fill_tween.kill()
	_hold_fill_tween = null
	_set_hold_fill_progress(0.0)


func _start_sticker_hold_animation(generation: int) -> void:
	if _hold_fill_tween != null and _hold_fill_tween.is_valid():
		_hold_fill_tween.kill()

	# Do not flash progress for an ordinary tap. The hold must survive this small
	# recognition window before the straight fill becomes visible.
	await get_tree().create_timer(STICKER_HOLD_VISUAL_DELAY).timeout
	if generation != _hold_generation:
		return
	if not _pressing or _max_drag_distance > _tap_threshold:
		return
	if not sticker_export_enabled or _sticker_export_running:
		return
	_sticker_cancel_sfx_played = false

	var remaining := maxf(0.0, 1.0 - _hold_fill_progress)
	if remaining <= 0.0001:
		_complete_sticker_hold(generation)
		return

	_play_sfx("click")
	_hold_fill_tween = create_tween()
	_hold_fill_tween.tween_method(
		Callable(self, "_set_hold_fill_progress"),
		_hold_fill_progress,
		1.0,
		maxf(0.01, STICKER_HOLD_SECONDS - STICKER_HOLD_VISUAL_DELAY) * remaining
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	_hold_fill_tween.finished.connect(func() -> void:
		_complete_sticker_hold(generation)
	)


func _reverse_sticker_hold_animation() -> void:
	if _hold_fill_tween != null and _hold_fill_tween.is_valid():
		_hold_fill_tween.kill()
	if _hold_fill_progress <= 0.0001:
		_set_hold_fill_progress(0.0)
		return

	if not _sticker_cancel_sfx_played:
		_sticker_cancel_sfx_played = true
		_play_sfx("error")
	_hold_fill_tween = create_tween()
	_hold_fill_tween.tween_method(
		Callable(self, "_set_hold_fill_progress"),
		_hold_fill_progress,
		0.0,
		STICKER_HOLD_REVERSE_SECONDS * _hold_fill_progress
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _complete_sticker_hold(generation: int) -> void:
	if generation != _hold_generation:
		return
	if not _pressing or _max_drag_distance > _tap_threshold:
		return
	if not sticker_export_enabled or data == null:
		return

	_pressing = false
	_ignore_next_release = true
	_hold_generation += 1
	_bounce_cancel()

	if _sticker_export_running or _is_global_sticker_render_active():
		_play_sfx("error")
		_animate_sticker_fill_back_to_white()
		return

	_export_sticker_png()


func _set_hold_fill_progress(value: float) -> void:
	_hold_fill_progress = clampf(value, 0.0, 1.0)
	if _hold_fill_progress <= 0.0001:
		_sticker_cancel_sfx_played = false
	_update_hold_fill_shader_parameters()
	if _hold_fill_progress > 0.0001 or _sticker_export_running:
		set_process(true)


func _animate_sticker_fill_back_to_white() -> void:
	if _hold_fill_tween != null and _hold_fill_tween.is_valid():
		_hold_fill_tween.kill()
	if _hold_fill_progress <= 0.0001:
		_set_hold_fill_progress(0.0)
		return

	_hold_fill_tween = create_tween()
	_hold_fill_tween.set_parallel(true)
	_hold_fill_tween.tween_method(
		Callable(self, "_set_hold_fill_progress"),
		_hold_fill_progress,
		0.0,
		STICKER_FILL_RETURN_SECONDS
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Match the restrained plus-button settle without growing a list item beyond 1.0.
	scale = Vector2(0.97, 0.97)
	_hold_fill_tween.tween_property(self, "scale", Vector2.ONE, STICKER_FILL_RETURN_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _export_sticker_png() -> void:
	if _sticker_export_running or data == null:
		return

	if not _acquire_global_sticker_render_lock(data.name):
		_play_sfx("error")
		_animate_sticker_fill_back_to_white()
		return

	_sticker_export_running = true
	_show_sticker_progress_toast(data.name)

	var logical_size := size
	if logical_size.x <= 0.0 or logical_size.y <= 0.0:
		logical_size = custom_minimum_size
	if logical_size.x <= 0.0 or logical_size.y <= 0.0:
		logical_size = Vector2(440.0, 540.0)

	var capture_scale := float(STICKER_CAPTURE_WIDTH) / logical_size.x
	var capture_size := Vector2i(
		STICKER_CAPTURE_WIDTH,
		maxi(1, roundi(logical_size.y * capture_scale))
	)
	var final_scale := float(STICKER_EXPORT_WIDTH) / logical_size.x

	# Keep the large render target disabled while the card scene is being built.
	# This prevents card construction, shader setup, and GPU allocation from all
	# landing in the same frame.
	var capture_viewport := SubViewport.new()
	capture_viewport.name = "PlanetCardStickerCapture"
	capture_viewport.size = Vector2i(64, 64)
	capture_viewport.transparent_bg = true
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	capture_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	capture_viewport.msaa_2d = Viewport.MSAA_2X
	get_tree().root.add_child(capture_viewport)
	await get_tree().process_frame

	var capture_card := PlanetCardPreview.new()
	capture_card.name = "StickerCard"
	capture_card.sticker_export_enabled = false
	capture_card.sticker_capture_mode = true
	capture_card.sticker_render_scale = capture_scale
	capture_card.position = Vector2.ZERO
	capture_card.custom_minimum_size = Vector2(capture_size)
	capture_card.size = Vector2(capture_size)
	capture_viewport.add_child(capture_card)
	await get_tree().process_frame

	# Building the full card is one of the expensive steps, so it gets its own
	# frame instead of sharing a frame with viewport allocation and rendering.
	capture_card.setup(data)
	await get_tree().process_frame

	# Grow the render target in two allocations rather than one large jump.
	var half_size := Vector2i(
		maxi(1, capture_size.x / 2),
		maxi(1, capture_size.y / 2)
	)
	capture_viewport.size = half_size
	await get_tree().process_frame
	capture_viewport.size = capture_size
	await get_tree().process_frame

	capture_card.size = Vector2(capture_size)
	capture_card.call("_layout_card")
	await get_tree().process_frame

	# Render only when every resource and layout is ready. UPDATE_ONCE avoids
	# paying for repeated full-resolution renders during setup.
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var image := capture_viewport.get_texture().get_image()
	capture_viewport.queue_free()

	if image == null or image.is_empty():
		_sticker_export_running = false
		_release_global_sticker_render_lock()
		_play_sfx("error")
		_show_sticker_error_toast()
		sticker_save_failed.emit(data, ERR_CANT_CREATE)
		_animate_sticker_fill_back_to_white()
		return

	var file_name := "%s_sticker.png" % _safe_sticker_file_name(data.name)
	_start_background_sticker_save(
		image,
		file_name,
		(CARD_RADIUS + BORDER_WIDTH) * final_scale,
		STICKER_EXPORT_WIDTH
	)


func _render_scale() -> float:
	return max(sticker_render_scale, 0.01) if sticker_capture_mode else 1.0


func _start_background_sticker_save(image: Image, file_name: String, corner_radius_px: float, output_width: int) -> void:
	if _sticker_save_thread != null:
		if _sticker_save_thread.is_alive():
			_sticker_save_thread.wait_to_finish()
		_sticker_save_thread = null

	_sticker_save_thread = Thread.new()
	var start_error := _sticker_save_thread.start(Callable(self, "_thread_save_sticker_image").bind(image, file_name, corner_radius_px, output_width))
	if start_error != OK:
		_sticker_save_thread = null
		_sticker_export_running = false
		_release_global_sticker_render_lock()
		_play_sfx("error")
		_show_sticker_error_toast()
		sticker_save_failed.emit(data, start_error)
		_animate_sticker_fill_back_to_white()
		return

	_start_sticker_thread_poll_timer()
	set_process(true)


func _thread_save_sticker_image(image: Image, file_name: String, corner_radius_px: float, output_width: int) -> Dictionary:
	var result := {
		"error": ERR_CANT_CREATE,
		"path": ""
	}

	if image == null or image.is_empty():
		return result

	var thread_image: Image = image
	if output_width > 0 and thread_image.get_width() != output_width:
		var output_height := maxi(
			1,
			roundi(float(thread_image.get_height()) * float(output_width) / float(thread_image.get_width()))
		)
		thread_image.resize(output_width, output_height, Image.INTERPOLATE_LANCZOS)

	_apply_exact_card_alpha_mask(thread_image, corner_radius_px)

	var saved_path := ""
	var write_error := ERR_CANT_CREATE
	var downloads_path := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)

	if not downloads_path.is_empty():
		var sticker_folder := downloads_path.path_join(STICKER_FOLDER_NAME)
		var directory_result := DirAccess.make_dir_recursive_absolute(sticker_folder)
		if directory_result == OK or DirAccess.dir_exists_absolute(sticker_folder):
			saved_path = _unique_sticker_path(sticker_folder, file_name)
			write_error = thread_image.save_png(saved_path)
			
	if write_error != OK:
		var fallback_folder := "user://stickers"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fallback_folder))
		saved_path = _unique_sticker_path(fallback_folder, file_name)
		write_error = thread_image.save_png(saved_path)
		
	result["error"] = write_error
	result["path"] = ProjectSettings.globalize_path(saved_path) if write_error == OK else ""
	return result


func _on_sticker_save_thread_finished(thread_result: Dictionary) -> void:
	_sticker_export_running = false
	_release_global_sticker_render_lock()
	var error_code := int(thread_result.get("error", ERR_CANT_CREATE))
	var saved_path := str(thread_result.get("path", ""))

	if error_code == OK and not saved_path.is_empty():
		_play_sfx("success")
		_show_sticker_complete_toast(_sticker_toast_planet_name)
		sticker_saved.emit(data, saved_path)
	else:
		_play_sfx("error")
		_show_sticker_error_toast()
		sticker_save_failed.emit(data, error_code)

	_animate_sticker_fill_back_to_white()


func _show_sticker_progress_toast(planet_name: String) -> void:
	# Match the prominent confirmation used when a multiplayer request is sent.
	_play_sfx("success")
	_sticker_toast_generation += 1
	_sticker_toast_planet_name = planet_name.to_upper()
	_sticker_toast_rendering_active = true
	_sticker_toast_render_dots = 1
	_sticker_toast_render_accum = 0.0
	_setup_sticker_toast()
	_ensure_sticker_toast_timers()
	_update_sticker_toast_text("CREATING STICKER", _sticker_toast_planet_name, "RENDERING.")
	_show_sticker_toast_now()
	_start_sticker_dots_timer()
	set_process(true)


func _show_sticker_complete_toast(planet_name: String) -> void:
	_sticker_toast_rendering_active = false
	_stop_sticker_dots_timer()
	_stop_sticker_thread_poll_timer()
	_disconnect_sticker_toast_timers()
	_update_sticker_toast_text("DOWNLOAD COMPLETED", planet_name.to_upper(), "RENDERING COMPLETED!")
	_hold_then_hide_sticker_toast(_sticker_toast_generation)
	set_process(true)


func _show_sticker_error_toast() -> void:
	_sticker_toast_rendering_active = false
	_stop_sticker_dots_timer()
	_stop_sticker_thread_poll_timer()
	_disconnect_sticker_toast_timers()
	var toast_name := _sticker_toast_planet_name if not _sticker_toast_planet_name.is_empty() else "PLANET CARD"
	_update_sticker_toast_text("DOWNLOAD FAILED", toast_name, "PLEASE TRY AGAIN")
	_hold_then_hide_sticker_toast(_sticker_toast_generation)
	set_process(true)


func _setup_sticker_toast() -> void:
	if is_instance_valid(_sticker_toast_panel):
		return
	var tree := get_tree()
	if tree == null or tree.root == null:
		return

	var existing := tree.root.get_node_or_null("UniversalStickerDownloadToastLayer")
	if existing is CanvasLayer:
		_sticker_toast_layer = existing as CanvasLayer
		_sticker_toast_layer.layer = STICKER_TOAST_LAYER
		var old_panel := _sticker_toast_layer.get_node_or_null("StickerDownloadToast")
		if old_panel is PanelContainer:
			old_panel.queue_free()
	else:
		_sticker_toast_layer = CanvasLayer.new()
		_sticker_toast_layer.name = "UniversalStickerDownloadToastLayer"
		_sticker_toast_layer.layer = STICKER_TOAST_LAYER
		_sticker_toast_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child(_sticker_toast_layer)

	_sticker_toast_panel = PanelContainer.new()
	_sticker_toast_panel.name = "StickerDownloadToast"
	_sticker_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sticker_toast_panel.custom_minimum_size = Vector2(STICKER_TOAST_WIDTH, STICKER_TOAST_HEIGHT)
	_sticker_toast_panel.size = _sticker_toast_panel.custom_minimum_size
	_sticker_toast_panel.z_index = 1000
	_sticker_toast_panel.visible = false
	_sticker_toast_panel.modulate.a = 0.0
	_sticker_toast_panel.add_theme_stylebox_override("panel", _sticker_toast_panel_style())
	_sticker_toast_layer.add_child(_sticker_toast_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_sticker_toast_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	margin.add_child(row)

	_sticker_toast_icon_shell = PanelContainer.new()
	_sticker_toast_icon_shell.custom_minimum_size = Vector2(STICKER_TOAST_ICON_SIZE, STICKER_TOAST_ICON_SIZE)
	_sticker_toast_icon_shell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sticker_toast_icon_shell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_sticker_toast_icon_shell)

	var icon_margin := MarginContainer.new()
	icon_margin.add_theme_constant_override("margin_left", 27)
	icon_margin.add_theme_constant_override("margin_right", 27)
	icon_margin.add_theme_constant_override("margin_top", 27)
	icon_margin.add_theme_constant_override("margin_bottom", 27)
	_sticker_toast_icon_shell.add_child(icon_margin)

	_sticker_toast_icon_texture = TextureRect.new()
	_sticker_toast_icon_texture.texture = load(PLANET_CARDS_ICON_PATH) as Texture2D
	_sticker_toast_icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sticker_toast_icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_margin.add_child(_sticker_toast_icon_texture)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)

	_sticker_toast_title = _make_toast_label(31, Color(1, 1, 1, 0.80))
	_sticker_toast_name = _make_toast_label(52, Color.WHITE)
	_sticker_toast_status = _make_toast_label(27, Color(1, 1, 1, 0.62))
	text_box.add_child(_sticker_toast_title)
	text_box.add_child(_sticker_toast_name)
	text_box.add_child(_sticker_toast_status)
	_ensure_sticker_toast_timers()
	_refresh_sticker_toast_theme()
	_layout_sticker_toast(true)


func _ensure_sticker_toast_timers() -> void:
	if not is_instance_valid(_sticker_toast_layer):
		return

	if not is_instance_valid(_sticker_dots_timer):
		var existing_dots := _sticker_toast_layer.get_node_or_null("StickerToastDotsTimer")
		if existing_dots is Timer:
			_sticker_dots_timer = existing_dots as Timer
		else:
			_sticker_dots_timer = Timer.new()
			_sticker_dots_timer.name = "StickerToastDotsTimer"
			_sticker_dots_timer.one_shot = false
			_sticker_dots_timer.wait_time = STICKER_RENDER_DOTS_INTERVAL
			_sticker_dots_timer.process_mode = Node.PROCESS_MODE_ALWAYS
			_sticker_toast_layer.add_child(_sticker_dots_timer)
		if not _sticker_dots_timer.timeout.is_connected(_on_sticker_dots_timer_timeout):
			_sticker_dots_timer.timeout.connect(_on_sticker_dots_timer_timeout)

	if not is_instance_valid(_sticker_thread_poll_timer):
		var existing_poll := _sticker_toast_layer.get_node_or_null("StickerToastThreadPollTimer")
		if existing_poll is Timer:
			_sticker_thread_poll_timer = existing_poll as Timer
		else:
			_sticker_thread_poll_timer = Timer.new()
			_sticker_thread_poll_timer.name = "StickerToastThreadPollTimer"
			_sticker_thread_poll_timer.one_shot = false
			_sticker_thread_poll_timer.wait_time = STICKER_THREAD_POLL_INTERVAL
			_sticker_thread_poll_timer.process_mode = Node.PROCESS_MODE_ALWAYS
			_sticker_toast_layer.add_child(_sticker_thread_poll_timer)
		if not _sticker_thread_poll_timer.timeout.is_connected(_on_sticker_thread_poll_timer_timeout):
			_sticker_thread_poll_timer.timeout.connect(_on_sticker_thread_poll_timer_timeout)


func _disconnect_sticker_toast_timers() -> void:
	if is_instance_valid(_sticker_dots_timer):
		var dots_callable := Callable(self, "_on_sticker_dots_timer_timeout")
		if _sticker_dots_timer.timeout.is_connected(dots_callable):
			_sticker_dots_timer.timeout.disconnect(dots_callable)

	if is_instance_valid(_sticker_thread_poll_timer):
		var poll_callable := Callable(self, "_on_sticker_thread_poll_timer_timeout")
		if _sticker_thread_poll_timer.timeout.is_connected(poll_callable):
			_sticker_thread_poll_timer.timeout.disconnect(poll_callable)


func _start_sticker_dots_timer() -> void:
	_ensure_sticker_toast_timers()
	if is_instance_valid(_sticker_dots_timer):
		_sticker_dots_timer.wait_time = STICKER_RENDER_DOTS_INTERVAL
		if _sticker_dots_timer.is_stopped():
			_sticker_dots_timer.start()


func _stop_sticker_dots_timer() -> void:
	if is_instance_valid(_sticker_dots_timer):
		_sticker_dots_timer.stop()


func _start_sticker_thread_poll_timer() -> void:
	_ensure_sticker_toast_timers()
	if is_instance_valid(_sticker_thread_poll_timer):
		_sticker_thread_poll_timer.wait_time = STICKER_THREAD_POLL_INTERVAL
		if _sticker_thread_poll_timer.is_stopped():
			_sticker_thread_poll_timer.start()


func _stop_sticker_thread_poll_timer() -> void:
	if is_instance_valid(_sticker_thread_poll_timer):
		_sticker_thread_poll_timer.stop()


func _on_sticker_dots_timer_timeout() -> void:
	if not _sticker_toast_rendering_active:
		_stop_sticker_dots_timer()
		return
	_sticker_toast_render_dots = (_sticker_toast_render_dots % 3) + 1
	if is_instance_valid(_sticker_toast_status):
		_sticker_toast_status.text = "RENDERING" + ".".repeat(_sticker_toast_render_dots)


func _on_sticker_thread_poll_timer_timeout() -> void:
	if _sticker_save_thread == null:
		_stop_sticker_thread_poll_timer()
		return
	if _sticker_save_thread.is_alive():
		return
	var thread_result: Variant = _sticker_save_thread.wait_to_finish()
	_sticker_save_thread = null
	_stop_sticker_thread_poll_timer()
	if thread_result is Dictionary:
		_on_sticker_save_thread_finished(thread_result)
	else:
		_on_sticker_save_thread_finished({"error": ERR_CANT_CREATE, "path": ""})


func _make_toast_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_apply_app_font(label)
	return label


func _sticker_toast_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	style.border_color = Color(1, 1, 1, 0.92)
	style.set_border_width_all(5)
	style.set_corner_radius_all(28)
	return style


func _get_theme_highlight_color() -> Color:
	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")

	if _settings_node != null:
		if _settings_node.has_method("get_accent_color"):
			var accent_value: Variant = _settings_node.call("get_accent_color")
			if accent_value is Color:
				return accent_value

		if _settings_node.has_method("get_text_highlighted_color"):
			var text_value: Variant = _settings_node.call("get_text_highlighted_color")
			if text_value is Color:
				return text_value

		for property_name in ["text_highlighted_color", "textHighlightedColor", "highlighted_text_color", "highlightedTextColor", "text_highlight_color", "textHighlightColor", "highlight_color", "highlightColor", "accent_color", "accentColor"]:
			var value: Variant = _settings_node.get(property_name)
			if value is Color:
				return value

	return Color(1.0, 0.82, 0.34, 0.98)


func _sticker_safe_icon_color() -> Color:
	var color := _get_theme_highlight_color()
	if color.a < 0.72:
		color.a = 1.0
	var luminance := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	if luminance < 0.12:
		return Color.WHITE
	return color


func _sticker_toast_icon_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.set_border_width_all(5)
	style.set_corner_radius_all(int(STICKER_TOAST_ICON_SIZE * 0.5))
	return style


func _refresh_sticker_toast_theme() -> void:
	var icon_color := _sticker_safe_icon_color()
	if is_instance_valid(_sticker_toast_icon_shell):
		_sticker_toast_icon_shell.add_theme_stylebox_override("panel", _sticker_toast_icon_style(icon_color))
	if is_instance_valid(_sticker_toast_icon_texture):
		_sticker_toast_icon_texture.modulate = icon_color


func _update_sticker_toast_text(title: String, main: String, status: String) -> void:
	_setup_sticker_toast()
	if is_instance_valid(_sticker_toast_title):
		_sticker_toast_title.text = title
	if is_instance_valid(_sticker_toast_name):
		_sticker_toast_name.text = main
	if is_instance_valid(_sticker_toast_status):
		_sticker_toast_status.text = status
	_refresh_sticker_toast_theme()


func _layout_sticker_toast(offscreen: bool) -> void:
	if not is_instance_valid(_sticker_toast_panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var in_position := Vector2(
		max(19.0, viewport_size.x - STICKER_TOAST_WIDTH - STICKER_TOAST_RIGHT_MARGIN),
		STICKER_TOAST_TOP_MARGIN
	)
	_sticker_toast_panel.size = Vector2(STICKER_TOAST_WIDTH, STICKER_TOAST_HEIGHT)
	_sticker_toast_panel.pivot_offset = _sticker_toast_panel.size * 0.5
	_sticker_toast_panel.position = Vector2(viewport_size.x + 26.0, in_position.y) if offscreen else in_position


func _show_sticker_toast_now() -> void:
	if not is_instance_valid(_sticker_toast_panel):
		return
	if _sticker_toast_tween != null and _sticker_toast_tween.is_valid():
		_sticker_toast_tween.kill()
	_layout_sticker_toast(true)
	var viewport_size := get_viewport().get_visible_rect().size
	var in_position := Vector2(max(19.0, viewport_size.x - STICKER_TOAST_WIDTH - STICKER_TOAST_RIGHT_MARGIN), STICKER_TOAST_TOP_MARGIN)
	_sticker_toast_panel.visible = true
	_sticker_toast_panel.modulate.a = 0.0
	_sticker_toast_panel.scale = Vector2(0.982, 0.982)
	_sticker_toast_tween = _sticker_toast_layer.create_tween()
	_sticker_toast_tween.set_trans(Tween.TRANS_CUBIC)
	_sticker_toast_tween.set_ease(Tween.EASE_OUT)
	_sticker_toast_tween.tween_property(_sticker_toast_panel, "position", in_position, STICKER_TOAST_IN_TIME)
	_sticker_toast_tween.parallel().tween_property(_sticker_toast_panel, "scale", Vector2.ONE, STICKER_TOAST_IN_TIME)
	_sticker_toast_tween.parallel().tween_property(_sticker_toast_panel, "modulate:a", 1.0, 0.30)


func _hold_then_hide_sticker_toast(generation: int) -> void:
	if not is_instance_valid(_sticker_toast_panel):
		_cleanup_detached_sticker_driver()
		return
	if _sticker_toast_tween != null and _sticker_toast_tween.is_valid():
		_sticker_toast_tween.kill()
	_sticker_toast_panel.visible = true
	_sticker_toast_panel.modulate.a = 1.0
	_sticker_toast_panel.scale = Vector2.ONE
	var viewport_size := get_viewport().get_visible_rect().size
	var out_position := Vector2(viewport_size.x + 26.0, STICKER_TOAST_TOP_MARGIN)
	_sticker_toast_tween = _sticker_toast_layer.create_tween()
	_sticker_toast_tween.tween_interval(STICKER_TOAST_COMPLETE_HOLD)
	_sticker_toast_tween.set_trans(Tween.TRANS_CUBIC)
	_sticker_toast_tween.set_ease(Tween.EASE_IN)
	_sticker_toast_tween.tween_property(_sticker_toast_panel, "position", out_position, STICKER_TOAST_OUT_TIME)
	_sticker_toast_tween.parallel().tween_property(_sticker_toast_panel, "modulate:a", 0.0, STICKER_TOAST_OUT_TIME)
	_sticker_toast_tween.finished.connect(func() -> void:
		if generation != _sticker_toast_generation:
			return
		if is_instance_valid(_sticker_toast_panel):
			_sticker_toast_panel.visible = false
			_sticker_toast_panel.scale = Vector2.ONE
		_cleanup_detached_sticker_driver()
	)


func _cleanup_detached_sticker_driver() -> void:
	if not _sticker_detached_for_background or _sticker_export_running:
		return
	_sticker_detached_for_background = false
	call_deferred("queue_free")


func _apply_exact_card_alpha_mask(image: Image, radius_px: float) -> void:
	if image == null or image.is_empty():
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	var width := image.get_width()
	var height := image.get_height()
	var radius := clamp(radius_px, 1.0, float(mini(width, height)) * 0.5)
	var feather := max(2.0, radius * 0.006)
	var corner_extent := mini(ceili(radius + feather + 2.0), mini(width, height))

	_mask_exact_corner(image, Rect2i(0, 0, corner_extent, corner_extent), Vector2(radius, radius), radius, feather)
	_mask_exact_corner(image, Rect2i(width - corner_extent, 0, corner_extent, corner_extent), Vector2(float(width) - radius, radius), radius, feather)
	_mask_exact_corner(image, Rect2i(0, height - corner_extent, corner_extent, corner_extent), Vector2(radius, float(height) - radius), radius, feather)
	_mask_exact_corner(image, Rect2i(width - corner_extent, height - corner_extent, corner_extent, corner_extent), Vector2(float(width) - radius, float(height) - radius), radius, feather)


func _mask_exact_corner(
	image: Image,
	region: Rect2i,
	center: Vector2,
	radius: float,
	feather: float
) -> void:
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var sample := Vector2(float(x) + 0.5, float(y) + 0.5)
			var distance := sample.distance_to(center)
			if distance <= radius - feather:
				continue
			var mask_alpha := 1.0 - smoothstep(radius - feather, radius + feather, distance)
			var pixel := image.get_pixel(x, y)
			pixel.a = min(pixel.a, clamp(mask_alpha, 0.0, 1.0))
			image.set_pixel(x, y, pixel)


func _safe_sticker_file_name(value: String) -> String:
	var source := value.strip_edges().to_lower()
	var builder := ""
	var previous_was_underscore := false

	for i in range(source.length()):
		var code := source.unicode_at(i)
		var is_lower := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57

		if is_lower or is_digit:
			builder += char(code)
			previous_was_underscore = false
		else:
			if not previous_was_underscore:
				builder += "_"
				previous_was_underscore = true

	var result := builder
	while result.begins_with("_"):
		result = result.substr(1)
	while result.ends_with("_"):
		result = result.substr(0, result.length() - 1)
	while result.contains("__"):
		result = result.replace("__", "_")

	return result if not result.is_empty() else "planet"


func _unique_sticker_path(folder: String, file_name: String) -> String:
	var base_name := file_name.get_basename()
	var extension := file_name.get_extension()
	var candidate := folder.path_join(file_name)
	var suffix := 2

	while FileAccess.file_exists(candidate):
		candidate = folder.path_join("%s_%d.%s" % [base_name, suffix, extension])
		suffix += 1

	return candidate


func _stamp_preview_animation_time() -> void:
	if data == null:
		return

	data.set_meta("preview_animation_time", _get_preview_animation_time())
	data.set_meta("preview_animation_stamp_msec", Time.get_ticks_msec())


func _get_preview_animation_time() -> float:
	if not is_instance_valid(_planet_node):
		return 1000.0

	if _planet_node.has_method("get_animation_time"):
		return float(_planet_node.call("get_animation_time"))

	var current_time = _planet_node.get("_animation_time")
	if current_time == null:
		return 1000.0

	return float(current_time)


func _bounce_down() -> void:
	if _bounce_tween != null and _bounce_tween.is_valid():
		_bounce_tween.kill()

	pivot_offset = size * 0.5

	_bounce_tween = create_tween()
	_bounce_tween.set_trans(Tween.TRANS_SINE)
	_bounce_tween.set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(self, "scale", Vector2.ONE * TAP_SCALE_DOWN, TAP_DOWN_TIME)


func _bounce_tap() -> void:
	if _bounce_tween != null and _bounce_tween.is_valid():
		_bounce_tween.kill()

	pivot_offset = size * 0.5

	_bounce_tween = create_tween()
	_bounce_tween.set_trans(Tween.TRANS_SINE)
	_bounce_tween.set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(self, "scale", Vector2.ONE * TAP_SCALE_UP, TAP_UP_TIME)
	_bounce_tween.tween_property(self, "scale", Vector2.ONE, TAP_SETTLE_TIME)


func _bounce_cancel() -> void:
	if _bounce_tween != null and _bounce_tween.is_valid():
		_bounce_tween.kill()

	pivot_offset = size * 0.5

	_bounce_tween = create_tween()
	_bounce_tween.set_trans(Tween.TRANS_SINE)
	_bounce_tween.set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(self, "scale", Vector2.ONE, TAP_SETTLE_TIME)



func _singularity_preview_diameter_multiplier(planet_data: PlanetData) -> float:
	return SINGULARITY_PREVIEW_VISUAL_DIAMETER_MULTIPLIER if _singularity_has_disk(planet_data) else SINGULARITY_PREVIEW_NO_DISK_VISUAL_DIAMETER_MULTIPLIER


func _singularity_has_disk(planet_data: PlanetData) -> bool:
	if planet_data == null:
		return true

	var preset := planet_data.planet_preset.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	var category := planet_data.object_category.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	var archetype := planet_data.archetype_id.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	if not (preset == "black_hole" or preset == "white_hole" or category == "singularity" or archetype == "black_hole" or archetype == "white_hole"):
		return true

	if preset == "white_hole" or archetype == "white_hole" or category == "white_hole":
		return true

	if planet_data.singularity_has_disk == false:
		return false

	var text := planet_data.ring_system.strip_edges().to_lower()
	for card in planet_data.data_cards:
		if card is Dictionary and str(card.get("title", "")).strip_edges().to_lower() == "disk":
			text = str(card.get("value", "")).strip_edges().to_lower()
			break

	if text.is_empty():
		return planet_data.singularity_has_disk

	return not (text == "none" or text.contains("no disk") or text.contains("no confirmed") or text.contains("absent") or text.contains("without disk") or text.contains("not confirmed"))


func _on_mouse_entered() -> void:
	if _hovered:
		return

	_hovered = true
	add_theme_stylebox_override("panel", _hover_card_style)

	if is_instance_valid(_border_overlay):
		_border_overlay.queue_redraw()


func _on_mouse_exited() -> void:
	if not _hovered:
		return

	_hovered = false
	add_theme_stylebox_override("panel", _normal_card_style)

	if is_instance_valid(_border_overlay):
		_border_overlay.queue_redraw()


func _apply_planet_data(planet: Node2D, planet_data: PlanetData, radius: int) -> void:
	planet.set("preset", planet_data.planet_preset)
	planet.set("radius_px", radius)
	planet.set("render_pixels", planet_data.planet_pixels)
	planet.set("seed_value", planet_data.planet_seed)
	planet.set("turning_speed", planet_data.planet_turning_speed)
	planet.set("axial_tilt_deg", planet_data.planet_axial_tilt_deg)
	planet.set("debug_border_enabled", false)
	planet.set("debug_border_width", 2.0)
	planet.set("debug_border_color", Color(0.2, 1.0, 1.0, 0.9))
	planet.set("draggable", false)
	planet.set("use_custom_colors", planet_data.use_custom_colors)
	planet.set("custom_colors", planet_data.custom_colors)
	
	planet.set("backing_disk_enabled", true)
	planet.set("backing_disk_color", Color.WHITE if planet_data.planet_preset.strip_edges().to_lower().replace(" ", "_").replace("-", "_") == "white_hole" else Color.BLACK)
	planet.set("backing_disk_padding_px", 0.0)
	planet.set("accretion_disk_enabled", _singularity_has_disk(planet_data))

	if planet.has_method("rebuild"):
		planet.call("rebuild")


func _preview_visual_offset(id: String) -> Vector2:
	match id.strip_edges().to_lower():
		"saturn":
			return Vector2(0, -4)

		_:
			return Vector2.ZERO


func _make_card_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = bg

	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)

	var radius := roundi(CARD_RADIUS * _render_scale())
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius

	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0

	if sticker_capture_mode:
		style.shadow_color = Color.TRANSPARENT
		style.shadow_size = 0
		style.shadow_offset = Vector2.ZERO
	else:
		style.shadow_color = Color(0, 0, 0, 0.46)
		style.shadow_size = 16
		style.shadow_offset = Vector2(0, 6)

	return style


func _make_planet_background_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = COLOR_PLANET_BACK
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)

	var radius := roundi(CARD_RADIUS * _render_scale())
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0

	return style


func _make_text_background_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = COLOR_TEXT_AREA
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)

	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	var radius := roundi(CARD_RADIUS * _render_scale())
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius

	return style


func _apply_app_font(control: Control) -> void:
	if _app_font != null:
		control.add_theme_font_override("font", _app_font)


func _play_sfx(id: String) -> void:
	if has_node("/root/UnilearnSFX"):
		get_node("/root/UnilearnSFX").play(id)


func _clear_children() -> void:
	_hold_generation += 1
	_pressing = false
	_ignore_next_release = false
	_hold_fill_progress = 0.0
	_hold_fill_color_cache = Color.TRANSPARENT

	if _hold_fill_tween != null and _hold_fill_tween.is_valid():
		_hold_fill_tween.kill()
	_hold_fill_tween = null

	if _bounce_tween != null and _bounce_tween.is_valid():
		_bounce_tween.kill()

	scale = Vector2.ONE
	if _sticker_save_thread != null:
		if _sticker_save_thread.is_alive():
			_sticker_save_thread.wait_to_finish()
		_sticker_save_thread = null
	if _sticker_export_running:
		_release_global_sticker_render_lock()
		_sticker_export_running = false
	_disconnect_sticker_toast_timers()
	_stop_sticker_dots_timer()
	_stop_sticker_thread_poll_timer()
	_sticker_toast_rendering_active = false
	_sticker_toast_render_accum = 0.0
	_stars_clip = null
	_stars_layer = null
	_stars_multimesh = null
	_planet_node = null
	_border_overlay = null
	_last_layout_size = Vector2(-1.0, -1.0)
	_last_name_width = -1.0

	for child in get_children():
		child.queue_free()

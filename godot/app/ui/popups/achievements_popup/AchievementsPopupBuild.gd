extends "res://app/ui/popups/achievements_popup/AchievementsPopupBase.gd"

var _achievement_cards_by_id: Dictionary = {}
var _category_cards_by_key: Dictionary = {}
var _achievement_search_serial := 0

const ACHIEVEMENT_BUILD_FRAME_BUDGET_MSEC := 3
const ACHIEVEMENT_RUNTIME_VIEWPORT_MARGIN := 720.0
const ACHIEVEMENT_LAYOUT_REFRESH_EVERY := 6
const ACHIEVEMENT_RUNTIME_VISIBILITY_MIN_INTERVAL_MSEC := 90

var _achievement_all_results_cache: Array = []
var _achievement_category_summary_cache: Array = []
var _achievement_search_haystack_cache: Dictionary = {}
var _achievement_category_haystack_cache: Dictionary = {}
var _achievement_runtime_visibility_update_pending := false
var _achievement_last_runtime_visibility_msec := -1000000
var _achievement_scroll_visibility_connected := false
var _achievement_cache_dirty := true
var _main_content: VBoxContainer = null
var _deferred_main_sections_built := false


const AI_CATEGORY_AFTER_READY_PAUSE := 0.24
const AI_CATEGORY_BEFORE_BACK_PAUSE := 0.16
const AI_CATEGORY_BACK_PAUSE := 0.26
const AI_CATEGORY_AFTER_BACK_PAUSE := 0.28
const AI_CATEGORY_BEFORE_SCROLL_PAUSE := 0.18
const AI_CATEGORY_SCROLL_TIME := 0.62
const AI_CATEGORY_AFTER_SCROLL_PAUSE := 0.22
const AI_CATEGORY_BEFORE_TAP_PAUSE := 0.16
const AI_CATEGORY_TAP_DOWN_TIME := 0.11
const AI_CATEGORY_TAP_RELEASE_PAUSE := 0.18
const AI_CATEGORY_AFTER_TAP_PAUSE := 0.16
const AI_CATEGORY_READY_FRAMES := 90


func simulate_ai_open_category(category: String) -> void:
	var clean_category := category.strip_edges()

	if clean_category.is_empty():
		return

	await _wait_for_ai_achievements_ready()
	await _ai_category_pause(AI_CATEGORY_AFTER_READY_PAUSE)

	_refresh_service_if_needed(false)
	_refresh_cached_achievement_results(false)

	var available_categories := {}

	for summary in _achievement_category_summary_cache:
		if summary is Dictionary:
			available_categories[str(summary.get("category", "")).strip_edges()] = true

	if not available_categories.has(clean_category):
		clean_category = _find_category_by_display_text(clean_category)

	if clean_category.is_empty():
		return

	# Do not teleport into the requested category. Apollo should visibly behave like
	# a user: leave the previous category, scroll the categories list, then tap it.
	if not _selected_category.strip_edges().is_empty():
		await _simulate_ai_back_to_categories()

	await _wait_for_ai_category_card(clean_category)
	await _ai_category_pause(AI_CATEGORY_BEFORE_SCROLL_PAUSE)

	var card = _category_cards_by_key.get(clean_category, null)
	if card == null or not is_instance_valid(card):
		# Safety fallback only. The normal path above should always be the visible tap.
		_open_category(clean_category)
		await get_tree().process_frame
		return

	await _simulate_ai_scroll_category_card_into_view(card)
	await _ai_category_pause(AI_CATEGORY_AFTER_SCROLL_PAUSE)
	await _simulate_ai_tap_category_card(card, clean_category)

	await get_tree().process_frame


func _wait_for_ai_achievements_ready() -> void:
	for _i in range(AI_CATEGORY_READY_FRAMES):
		if _closing:
			return
		if _intro_finished and is_instance_valid(_category_scroll) and is_instance_valid(_category_list):
			return
		await get_tree().process_frame


func _wait_for_ai_category_card(category: String) -> void:
	if _selected_category.strip_edges().is_empty():
		_update_active_achievement_view()

	for _i in range(AI_CATEGORY_READY_FRAMES):
		var card = _category_cards_by_key.get(category, null)
		if card != null and is_instance_valid(card):
			return
		await get_tree().process_frame


func _simulate_ai_back_to_categories() -> void:
	if _selected_category.strip_edges().is_empty():
		return

	await _ai_category_pause(AI_CATEGORY_BEFORE_BACK_PAUSE)

	if is_instance_valid(_back_button):
		var center := _back_button.get_global_rect().get_center()
		_start_back_button_press(-777)
		if AI_CATEGORY_BACK_PAUSE > 0.0:
			await get_tree().create_timer(AI_CATEGORY_BACK_PAUSE).timeout
		_finish_back_button_press(center)
	else:
		_back_to_categories()

	await get_tree().process_frame
	await get_tree().process_frame
	await _ai_category_pause(AI_CATEGORY_AFTER_BACK_PAUSE)


func _simulate_ai_scroll_category_card_into_view(card: Control) -> void:
	if not is_instance_valid(_category_scroll) or not is_instance_valid(card):
		return

	await get_tree().process_frame

	_scroll_velocity = 0.0
	_scroll_dragging = false

	var start_value := float(_category_scroll.scroll_vertical)
	var visible_height: float = max(_category_scroll.size.y, 1.0)
	var card_mid: float = card.position.y + card.size.y * 0.5
	var target_value: float = card_mid - visible_height * 0.5

	var bar := _category_scroll.get_v_scroll_bar()
	if bar != null:
		target_value = clamp(target_value, 0.0, max(0.0, bar.max_value - bar.page))
	else:
		target_value = max(0.0, target_value)

	if abs(start_value - target_value) <= 8.0:
		return

	var duration := AI_CATEGORY_SCROLL_TIME
	if reduce_motion_enabled:
		duration = 0.01

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(value: float) -> void:
		if is_instance_valid(_category_scroll):
			_category_scroll.scroll_vertical = int(round(value))
	, start_value, target_value, duration)
	await tween.finished


func _simulate_ai_tap_category_card(card: Control, category: String) -> void:
	if not is_instance_valid(card):
		_open_category(category)
		return

	await _ai_category_pause(AI_CATEGORY_BEFORE_TAP_PAUSE)

	var press_state := {"down": true, "tween": null}
	_bounce_card_down(card, press_state)

	if AI_CATEGORY_TAP_DOWN_TIME > 0.0:
		await get_tree().create_timer(AI_CATEGORY_TAP_DOWN_TIME).timeout

	_bounce_card_release(card, press_state)

	if AI_CATEGORY_TAP_RELEASE_PAUSE > 0.0:
		await get_tree().create_timer(AI_CATEGORY_TAP_RELEASE_PAUSE).timeout

	_open_category(category)
	await _ai_category_pause(AI_CATEGORY_AFTER_TAP_PAUSE)


func _ai_category_pause(seconds: float) -> void:
	if seconds <= 0.0 or reduce_motion_enabled:
		return
	await get_tree().create_timer(seconds).timeout


func _find_category_by_display_text(value: String) -> String:
	var wanted := value.strip_edges().to_lower().replace("_", " ").replace("-", " ")

	if wanted.is_empty():
		return ""

	_refresh_cached_achievement_results(false)

	for summary in _achievement_category_summary_cache:
		if not (summary is Dictionary):
			continue

		var category := str(summary.get("category", "")).strip_edges()

		if category.is_empty():
			continue

		var candidates := [
			category,
			category.replace("_", " "),
			_category_display_name(category)
		]

		for candidate in candidates:
			var clean := str(candidate).strip_edges().to_lower().replace("_", " ").replace("-", " ")

			if clean == wanted:
				return category

			if clean.contains(wanted) or wanted.contains(clean):
				return category

	return ""


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "AchievementsPopupRoot"
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
			close_popup()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			close_popup()
			get_viewport().set_input_as_handled()
	)

	_slide_root = Control.new()
	_slide_root.name = "AchievementsSlideRoot"
	_slide_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide_root.modulate.a = 0.0
	_root.add_child(_slide_root)

	_panel = PanelContainer.new()
	_panel.name = "AchievementsPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_slide_root.add_child(_panel)

	_body_root = Control.new()
	_body_root.name = "AchievementsBodyRoot"
	_body_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(_body_root)

	_build_main_view()


func _build_main_view(build_deferred_sections: bool = false) -> void:
	if is_instance_valid(_main_view):
		_main_view.queue_free()

	_deferred_main_sections_built = false
	_main_content = null

	_main_view = Control.new()
	_main_view.name = "AchievementsMainView"
	_main_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body_root.add_child(_main_view)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", panel_padding_x)
	margin.add_theme_constant_override("margin_right", panel_padding_x)
	margin.add_theme_constant_override("margin_top", panel_padding_y)
	margin.add_theme_constant_override("margin_bottom", panel_padding_y)
	_main_view.add_child(margin)

	_main_content = VBoxContainer.new()
	_main_content.name = "AchievementsContent"
	_main_content.add_theme_constant_override("separation", 34)
	margin.add_child(_main_content)

	_build_header_and_search(_main_content)

	if build_deferred_sections:
		_build_deferred_main_view()


func _build_header_and_search(content: VBoxContainer) -> void:
	var title_box := VBoxContainer.new()
	title_box.custom_minimum_size = Vector2(0, 230)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 6)
	content.add_child(title_box)

	var title := Label.new()
	title.text = "ACHIEVEMENTS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 118)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.clip_text = false
	_apply_app_font(title)
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Discover configurations of your universe!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 52)
	subtitle.add_theme_color_override("font_color", COLOR_SUBTITLE)
	_apply_app_font(subtitle)
	title_box.add_child(subtitle)

	_build_search_row(content)


func _build_deferred_main_view() -> void:
	if _deferred_main_sections_built:
		return
	if not is_instance_valid(_main_content):
		return

	_deferred_main_sections_built = true
	_build_stats_section(_main_content)
	_build_scroll_list(_main_content)
	call_deferred("_style_scroll_bar")


func _build_search_row(content: VBoxContainer) -> void:
	var search_row_height := 150.0
	var search_gap := 22.0

	_search_row = Control.new()
	_search_row.name = "AchievementsSearchRow"
	_search_row.custom_minimum_size = Vector2(0, search_row_height)
	_search_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(_search_row)

	_search_shell = PanelContainer.new()
	_search_shell.name = "SearchShell"
	_search_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	_search_shell.add_theme_stylebox_override("panel", _search_style())
	_search_row.add_child(_search_shell)

	_back_button = Control.new()
	_back_button.name = "BackToCategoriesButton"
	_back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_back_button.visible = true
	_back_button.modulate.a = 1.0
	_back_button.scale = Vector2.ONE
	_search_row.add_child(_back_button)

	_back_button.draw.connect(func() -> void:
		if not is_instance_valid(_back_button):
			return
		_back_button.draw_style_box(_square_button_style(), Rect2(Vector2.ZERO, _back_button.size))
	)

	_build_back_button_icon()

	_back_button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			if event.pressed:
				_start_back_button_press(event.index)
				get_viewport().set_input_as_handled()
			elif _back_button_pointer_id == event.index:
				_finish_back_button_press(event.position)
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_back_button_press(-2)
				get_viewport().set_input_as_handled()
			elif _back_button_pointer_id == -2:
				_finish_back_button_press(event.position)
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion and _back_button_pointer_id == -2:
			_update_back_button_pressed_visual(event.position)
		elif event is InputEventScreenDrag and _back_button_pointer_id == event.index:
			_update_back_button_pressed_visual(event.position)
	)

	var layout_search_row := func() -> void:
		_layout_search_row()

	_search_row.resized.connect(func() -> void:
		layout_search_row.call()
	)

	var search_margin := MarginContainer.new()
	search_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	search_margin.add_theme_constant_override("margin_left", 34)
	search_margin.add_theme_constant_override("margin_right", 20)
	search_margin.add_theme_constant_override("margin_top", 0)
	search_margin.add_theme_constant_override("margin_bottom", 0)
	_search_shell.add_child(search_margin)

	var search_inner := HBoxContainer.new()
	search_inner.alignment = BoxContainer.ALIGNMENT_CENTER
	search_inner.add_theme_constant_override("separation", 20)
	search_margin.add_child(search_inner)

	var left_icon := _create_search_icon()
	search_inner.add_child(left_icon)

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
	_search_box.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_search_box.add_theme_stylebox_override("read_only", _transparent_line_edit_style())
	_apply_app_font(_search_box)
	search_inner.add_child(_search_box)

	_search_clear_button = _create_search_clear_button()
	search_inner.add_child(_search_clear_button)

	_search_box.text_changed.connect(func(text: String) -> void:
		_filter_query = text.strip_edges()
		_update_search_clear_button()
		_request_rebuild()
	)

	_search_box.text_submitted.connect(func(_text: String) -> void:
		_apply_search_button()
	)

	layout_search_row.call()
	_update_search_clear_button()
	_update_back_button()




func _prewarm_achievement_icon_textures() -> void:
	var categories := [
		"achievement_total",
		"bronze",
		"silver",
		"gold",
		"add_body",
		"planet_collision",
		"sun_collision",
		"black_hole",
		"stat_mastery",
		"ai_assistant",
		"instability",
		"type_amount",
		"fictional_system",
		"franchise_system"
	]

	for category in categories:
		_load_achievement_icon_texture(str(category))


func _build_back_button_icon() -> void:
	if not is_instance_valid(_back_button):
		return

	_back_button_arrow_texture = load(BACK_ARROW_TEXTURE_PATH) as Texture2D

	if _back_button_arrow_texture != null:
		_back_button_icon = TextureRect.new()
		_back_button_icon.name = "BackArrowIcon"
		_back_button_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_back_button_icon.texture = _back_button_arrow_texture
		_back_button_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_back_button_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_back_button_icon.material = _make_icon_tint_material(_get_back_button_icon_color()).duplicate(true)
		_back_button_icon.rotation = -PI * 0.5
		_back_button.add_child(_back_button_icon)
	else:
		_back_button_fallback_arrow = Label.new()
		_back_button_fallback_arrow.name = "BackArrowFallback"
		_back_button_fallback_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_back_button_fallback_arrow.text = "←"
		_back_button_fallback_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_back_button_fallback_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_back_button_fallback_arrow.add_theme_font_size_override("font_size", 74)
		_apply_app_font(_back_button_fallback_arrow)
		_back_button.add_child(_back_button_fallback_arrow)

	_update_back_button_icon_visual()


func _get_back_button_icon_color() -> Color:
	var highlight := _get_theme_highlight_color()
	return highlight.lerp(Color.WHITE, clamp(_back_button_active_blend, 0.0, 1.0))


func _update_back_button_icon_visual() -> void:
	var color := _get_back_button_icon_color()

	if is_instance_valid(_back_button_icon):
		var material := _back_button_icon.material as ShaderMaterial
		if material != null:
			material.set_shader_parameter("tint_color", color)
		_back_button_icon.modulate = Color.WHITE

	if is_instance_valid(_back_button_fallback_arrow):
		_back_button_fallback_arrow.add_theme_color_override("font_color", color)

	if is_instance_valid(_back_button):
		_back_button.queue_redraw()


func _animate_back_button_active_state() -> void:
	var target := 1.0 if not _selected_category.strip_edges().is_empty() else 0.0

	if is_equal_approx(_back_button_active_blend, target):
		_update_back_button_icon_visual()
		return

	if _back_button_color_tween != null and _back_button_color_tween.is_valid():
		_back_button_color_tween.kill()

	if reduce_motion_enabled:
		_back_button_active_blend = target
		_update_back_button_icon_visual()
		return

	_back_button_color_tween = create_tween()
	_back_button_color_tween.set_trans(Tween.TRANS_SINE)
	_back_button_color_tween.set_ease(Tween.EASE_OUT)
	_back_button_color_tween.tween_method(
		func(value: float) -> void:
			_back_button_active_blend = value
			_update_back_button_icon_visual(),
		_back_button_active_blend,
		target,
		BACK_BUTTON_COLOR_TWEEN_TIME
	)


func _make_icon_tint_material(color: Color) -> ShaderMaterial:
	var key := color.to_html(true)
	if _tint_material_cache.has(key):
		return _tint_material_cache[key]

	if _icon_tint_shader == null:
		_icon_tint_shader = Shader.new()
		_icon_tint_shader.code = "shader_type canvas_item;\nuniform vec4 tint_color : source_color = vec4(1.0);\nvoid fragment() {\n\tvec4 tex = texture(TEXTURE, UV);\n\tCOLOR = vec4(tint_color.rgb, tint_color.a * tex.a);\n}"

	var material := ShaderMaterial.new()
	material.shader = _icon_tint_shader
	material.set_shader_parameter("tint_color", color)
	_tint_material_cache[key] = material
	return material

func _layout_search_row() -> void:
	if not is_instance_valid(_search_row) or not is_instance_valid(_search_shell):
		return

	var search_row_height := 150.0
	var search_gap := 22.0
	var row_width := _search_row.size.x
	var row_height := _search_row.size.y

	if row_height <= 0.0:
		row_height = search_row_height

	var button_size := row_height
	var search_width: float = max(0.0, row_width - button_size - search_gap)

	_search_shell.position = Vector2.ZERO
	_search_shell.size = Vector2(search_width, row_height)
	_search_shell.custom_minimum_size = _search_shell.size

	if is_instance_valid(_back_button):
		_back_button.position = Vector2(search_width + search_gap, 0.0)
		_back_button.size = Vector2(button_size, row_height)
		_back_button.custom_minimum_size = _back_button.size
		_back_button.pivot_offset = _back_button.size * 0.5

		var icon_size := Vector2(button_size * 0.56, button_size * 0.56)

		if is_instance_valid(_back_button_icon):
			_back_button_icon.size = icon_size
			_back_button_icon.custom_minimum_size = icon_size
			_back_button_icon.pivot_offset = icon_size * 0.5
			_back_button_icon.position = (_back_button.size - icon_size) * 0.5

		if is_instance_valid(_back_button_fallback_arrow):
			_back_button_fallback_arrow.position = Vector2.ZERO
			_back_button_fallback_arrow.size = _back_button.size

		_update_back_button_icon_visual()
		_back_button.queue_redraw()



func _build_stats_section(content: VBoxContainer) -> void:
	var section := HBoxContainer.new()
	section.name = "AchievementsStatsSection"
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 18)
	content.add_child(section)

	var unlocked_panel := PanelContainer.new()
	unlocked_panel.name = "UnlockedAchievementCard"
	unlocked_panel.custom_minimum_size = Vector2(0, 150)
	unlocked_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlocked_panel.add_theme_stylebox_override("panel", _unlocked_box_style())
	section.add_child(unlocked_panel)

	var unlocked_margin := MarginContainer.new()
	unlocked_margin.add_theme_constant_override("margin_left", 22)
	unlocked_margin.add_theme_constant_override("margin_right", 22)
	unlocked_margin.add_theme_constant_override("margin_top", 12)
	unlocked_margin.add_theme_constant_override("margin_bottom", 12)
	unlocked_panel.add_child(unlocked_margin)

	var unlocked_row := HBoxContainer.new()
	unlocked_row.alignment = BoxContainer.ALIGNMENT_CENTER
	unlocked_row.add_theme_constant_override("separation", 18)
	unlocked_margin.add_child(unlocked_row)

	unlocked_row.add_child(_create_category_icon("achievement_total", 3, COLOR_TEXT, Vector2(78, 78)))

	var unlocked_text := VBoxContainer.new()
	unlocked_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlocked_text.add_theme_constant_override("separation", 0)
	unlocked_row.add_child(unlocked_text)

	_unlocked_value_label = Label.new()
	_unlocked_value_label.text = "0/0"
	_unlocked_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_unlocked_value_label.add_theme_font_size_override("font_size", 68)
	_unlocked_value_label.add_theme_color_override("font_color", COLOR_TEXT)
	_apply_app_font(_unlocked_value_label)
	unlocked_text.add_child(_unlocked_value_label)

	_unlocked_caption_label = Label.new()
	_unlocked_caption_label.text = "ACHIEVEMENTS UNLOCKED"
	_unlocked_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_unlocked_caption_label.add_theme_font_size_override("font_size", 28)
	_unlocked_caption_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.86))
	_apply_app_font(_unlocked_caption_label)
	unlocked_text.add_child(_unlocked_caption_label)

	var tier_panel := PanelContainer.new()
	tier_panel.name = "TierSummaryCard"
	tier_panel.custom_minimum_size = Vector2(0, 150)
	tier_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tier_panel.add_theme_stylebox_override("panel", _tier_summary_style())
	section.add_child(tier_panel)

	var tier_margin := MarginContainer.new()
	tier_margin.add_theme_constant_override("margin_left", 18)
	tier_margin.add_theme_constant_override("margin_right", 18)
	tier_margin.add_theme_constant_override("margin_top", 12)
	tier_margin.add_theme_constant_override("margin_bottom", 12)
	tier_panel.add_child(tier_margin)

	var tier_row := HBoxContainer.new()
	tier_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tier_row.add_theme_constant_override("separation", 14)
	tier_margin.add_child(tier_row)

	_tier_value_labels.clear()
	_tier_progress_bars.clear()
	_add_tier_summary(tier_row, "BRONZE", "bronze", _tier_color(1))
	_add_tier_summary(tier_row, "SILVER", "silver", _tier_color(2))
	_add_tier_summary(tier_row, "GOLD", "gold", _tier_color(3))


func _add_tier_summary(parent: HBoxContainer, label_text: String, key: String, color: Color) -> void:
	var item := VBoxContainer.new()
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_constant_override("separation", 3)
	parent.add_child(item)

	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 6)
	item.add_child(top)

	top.add_child(_create_category_icon(key, 3, color, Vector2(44, 44)))

	var value := Label.new()
	value.text = "0"
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.add_theme_font_size_override("font_size", 46)
	value.add_theme_color_override("font_color", color)
	_apply_app_font(value)
	top.add_child(value)
	_tier_value_labels[key] = value

	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.88))
	_apply_app_font(label)
	item.add_child(label)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(1, 12)
	bar.add_theme_stylebox_override("background", _progress_back_style())
	bar.add_theme_stylebox_override("fill", _progress_fill_style(color))
	item.add_child(bar)
	_tier_progress_bars[key] = bar


func _build_scroll_list(content: VBoxContainer) -> void:
	var stack := Control.new()
	stack.name = "AchievementsScrollStack"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(stack)

	_category_scroll = _make_achievement_scroll("AchievementsCategoryScroll")
	_category_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_category_scroll)
	_category_list = _make_scroll_inner_list(_category_scroll, "AchievementCategoryList")
	_category_empty_label = _make_empty_label()
	_category_empty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_category_empty_label)

	_details_scroll = _make_achievement_scroll("AchievementsDetailScroll")
	_details_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_details_scroll.visible = false
	stack.add_child(_details_scroll)
	_details_list = _make_scroll_inner_list(_details_scroll, "AchievementDetailList")
	_details_empty_label = _make_empty_label()
	_details_empty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_details_empty_label)

	_scroll = _category_scroll
	_list = _category_list
	_empty_label = _category_empty_label
	_scroll_margin = _category_scroll.get_child(0) as MarginContainer
	_scroll_content = _category_list.get_parent() as VBoxContainer
	if has_method("_reset_scroll_motion"):
		_reset_scroll_motion()


func _make_achievement_scroll(scroll_name: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = scroll_name
	scroll.follow_focus = true
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.add_theme_constant_override("scrollbar_margin_left", 30)

	var margin := MarginContainer.new()
	margin.name = "ScrollContentMargin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_right", 44)
	scroll.add_child(margin)

	return scroll


func _make_scroll_inner_list(scroll: ScrollContainer, list_name: String) -> VBoxContainer:
	var margin := scroll.get_child(0) as MarginContainer
	var scroll_content := VBoxContainer.new()
	scroll_content.name = "ScrollContent"
	scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll_content.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll_content.add_theme_constant_override("separation", 0)
	margin.add_child(scroll_content)

	var list := VBoxContainer.new()
	list.name = list_name
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	list.add_theme_constant_override("separation", 26)
	scroll_content.add_child(list)
	return list


func _make_empty_label() -> Label:
	var label := Label.new()
	label.name = "CenteredEmptyAchievementsLabel"
	label.visible = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", COLOR_SUBTITLE)
	_apply_app_font(label)
	return label


func _request_rebuild() -> void:
	if _closing or not _deferred_main_sections_built:
		return
	_achievement_search_serial += 1
	var local_serial := _achievement_search_serial
	await get_tree().create_timer(0.12).timeout
	if local_serial != _achievement_search_serial or _closing or not _intro_finished:
		return
	_rebuild()


func _run_deferred_rebuild() -> void:
	if _closing or not _intro_finished or not _deferred_main_sections_built:
		return
	_rebuild()


func _rebuild() -> void:
	if _closing or not _deferred_main_sections_built:
		return

	_animate_current_rebuild = not _first_list_rebuild_done
	_first_list_rebuild_done = true
	_view_generation += 1
	var local_generation := _view_generation

	_update_active_achievement_view()
	_update_back_button()
	_hide_active_empty()
	_connect_achievement_scroll_runtime_visibility_signal()

	if _service == null:
		_update_summary_labels(0, 0, 0, 0, 0)
		_show_empty("ADD UNILEARNACHIEVEMENTS AUTOLOAD")
		return

	var all_results := _get_filtered_results()
	var summary := _get_global_summary_fast()
	_update_summary_labels(
		int(summary.get("unlocked", 0)),
		int(summary.get("total", _achievement_all_results_cache.size())),
		int(summary.get("bronze", 0)),
		int(summary.get("silver", 0)),
		int(summary.get("gold", 0))
	)

	await get_tree().process_frame

	if local_generation != _view_generation or _closing:
		return

	if _selected_category.strip_edges().is_empty():
		await _build_categories_progressively(_get_category_summaries(all_results), local_generation)
	else:
		var category_results := _filter_results_by_category(all_results, _selected_category)
		await _build_achievements_progressively(category_results, local_generation)

	call_deferred("_style_scroll_bar")
	_request_achievement_runtime_visibility_update()


func _hide_active_empty() -> void:
	if is_instance_valid(_category_empty_label):
		_category_empty_label.visible = false
		_category_empty_label.text = ""
	if is_instance_valid(_details_empty_label):
		_details_empty_label.visible = false
		_details_empty_label.text = ""
	var in_category := not _selected_category.strip_edges().is_empty()
	if is_instance_valid(_category_scroll):
		_category_scroll.visible = not in_category
	if is_instance_valid(_details_scroll):
		_details_scroll.visible = in_category


func _refresh_category_cards(categories: Array, local_generation: int) -> void:
	if local_generation != _view_generation or _closing or not is_instance_valid(_category_list):
		return

	if categories.is_empty():
		for old in _category_cards_by_key.values():
			if old != null and is_instance_valid(old):
				old.visible = false
		_show_empty("NO CATEGORY")
		return

	var visible_keys := {}
	for i in range(categories.size()):
		var summary: Dictionary = categories[i]
		var key := str(summary.get("category", "type_amount"))
		visible_keys[key] = true
		var card = _category_cards_by_key.get(key, null)
		if card == null or not is_instance_valid(card):
			card = _make_category_card(summary, i)
			card.modulate.a = 0.0 if _animate_current_rebuild and i < CARD_ANIMATION_LIMIT else 1.0
			card.scale = Vector2.ONE
			_category_cards_by_key[key] = card
			_category_list.add_child(card)
			if _animate_current_rebuild and i < CARD_ANIMATION_LIMIT:
				_animate_card_in(card, i)
		else:
			if card.get_parent() != _category_list:
				_category_list.add_child(card)
		card.visible = true
		if not (_animate_current_rebuild and i < CARD_ANIMATION_LIMIT and card.modulate.a < 1.0):
			card.modulate.a = 1.0
		card.scale = Vector2.ONE
		_category_list.move_child(card, i)

	for key in _category_cards_by_key.keys():
		if visible_keys.has(key):
			continue
		var card = _category_cards_by_key.get(key, null)
		if card != null and is_instance_valid(card):
			card.visible = false

	_hide_active_empty()


func _refresh_achievement_cards(results: Array, local_generation: int) -> void:
	if local_generation != _view_generation or _closing or not is_instance_valid(_details_list):
		return

	if results.is_empty():
		for old in _achievement_cards_by_id.values():
			if old != null and is_instance_valid(old):
				old.visible = false
		_show_empty("NO ACHIEVEMENTS")
		return

	var max_count: int = min(MAX_VISIBLE_RESULTS, results.size())
	var visible_ids := {}
	for i in range(max_count):
		var item: Dictionary = results[i]
		var id := str(item.get("id", "")).strip_edges()
		if id.is_empty():
			id = str(item.get("key", "achievement_%d" % i))
		visible_ids[id] = true
		var card = _achievement_cards_by_id.get(id, null)
		if card == null or not is_instance_valid(card):
			card = _make_achievement_card(item, i + 1)
			card.modulate.a = 0.0 if _animate_current_rebuild and i < CARD_ANIMATION_LIMIT else 1.0
			card.scale = Vector2.ONE
			_achievement_cards_by_id[id] = card
			_details_list.add_child(card)
			if _animate_current_rebuild and i < CARD_ANIMATION_LIMIT:
				_animate_card_in(card, i)
		else:
			if card.get_parent() != _details_list:
				_details_list.add_child(card)
		card.visible = true
		if not (_animate_current_rebuild and i < CARD_ANIMATION_LIMIT and card.modulate.a < 1.0):
			card.modulate.a = 1.0
		card.scale = Vector2.ONE
		_details_list.move_child(card, i)

	for id in _achievement_cards_by_id.keys():
		if visible_ids.has(id):
			continue
		var card = _achievement_cards_by_id.get(id, null)
		if card != null and is_instance_valid(card):
			card.visible = false

	_hide_active_empty()


func _update_active_achievement_view() -> void:
	var previous_scroll := _scroll
	var in_category := not _selected_category.strip_edges().is_empty()
	if is_instance_valid(_category_scroll):
		_category_scroll.visible = not in_category
	if is_instance_valid(_details_scroll):
		_details_scroll.visible = in_category
	_scroll = _details_scroll if in_category else _category_scroll
	_list = _details_list if in_category else _category_list
	_empty_label = _details_empty_label if in_category else _category_empty_label
	if previous_scroll != _scroll:
		_cached_max_scroll_bar = null
		_scroll_velocity = 0.0
		_scroll_pointer_id = -999
		_scroll_dragging = false
	if is_instance_valid(_scroll) and is_instance_valid(_list):
		_scroll_margin = _scroll.get_child(0) as MarginContainer
		_scroll_content = _list.get_parent() as VBoxContainer


func _clear_active_list() -> void:
	_achievement_cards_by_id.clear()
	if is_instance_valid(_list):
		for child in _list.get_children():
			child.queue_free()
	if is_instance_valid(_empty_label):
		_empty_label.visible = false
		_empty_label.text = ""


func _clear_list() -> void:
	_clear_active_list()


func _refresh_service_if_needed(force: bool = false) -> void:
	if _service == null or not _service.has_method("refresh"):
		return

	var now := Time.get_ticks_msec()
	if not force and _refresh_has_run and now - _last_refresh_msec < SERVICE_REFRESH_INTERVAL_MSEC:
		return

	_refresh_has_run = true
	_last_refresh_msec = now
	_service.call("refresh")


func _refresh_cached_achievement_results(force: bool = false) -> void:
	if _service == null:
		_achievement_all_results_cache = []
		_achievement_category_summary_cache = []
		return

	if not force and not _achievement_cache_dirty and not _achievement_all_results_cache.is_empty():
		return

	var raw_results: Variant = []
	if _service.has_method("get_results"):
		raw_results = _service.call("get_results")
	elif _service.has_method("filter_results"):
		raw_results = _service.call("filter_results", "")

	if raw_results is Array:
		_achievement_all_results_cache = raw_results.duplicate()
	else:
		_achievement_all_results_cache = []

	_achievement_search_haystack_cache.clear()
	_achievement_category_haystack_cache.clear()
	_achievement_category_summary_cache = _build_category_summaries_from_results(_achievement_all_results_cache)
	_achievement_cache_dirty = false


func _get_filtered_results() -> Array:
	_refresh_cached_achievement_results(false)
	var query := _filter_query.strip_edges()
	if query.is_empty():
		return _achievement_all_results_cache
	return _filter_results_by_search_text(_achievement_all_results_cache, query, true)


func _filter_results_by_search_text(results: Array, query: String, include_category_fields: bool = false) -> Array:
	var normalized_query := _normalize_achievement_search_text(query)
	if normalized_query.is_empty():
		return results

	var output: Array = []
	for result in results:
		if not (result is Dictionary):
			continue
		var haystack := _achievement_search_haystack(result, include_category_fields)
		if haystack.contains(normalized_query):
			output.append(result)
	return output


func _achievement_search_haystack(result: Dictionary, include_category_fields: bool = false) -> String:
	var id := str(result.get("id", result.get("key", result.get("title", result.get("name", ""))))).strip_edges()
	if id.is_empty():
		id = str(result.hash())
	var cache_key := "%s|%s" % [id, "cat" if include_category_fields else "base"]
	if _achievement_search_haystack_cache.has(cache_key):
		return str(_achievement_search_haystack_cache[cache_key])

	var parts: Array[String] = [
		str(result.get("id", "")),
		str(result.get("key", "")),
		str(result.get("title", "")),
		str(result.get("name", "")),
		str(result.get("description", "")),
		str(result.get("next_description", "")),
		str(result.get("rarity", "")),
		str(result.get("tier_label", ""))
	]

	if include_category_fields:
		var category := str(result.get("category", ""))
		parts.append(category)
		parts.append(str(result.get("category_label", "")))
		parts.append(_category_display_name(category))
		parts.append(_category_description(category, 0, 0))

	var haystack := _normalize_achievement_search_text(" ".join(parts))
	_achievement_search_haystack_cache[cache_key] = haystack
	return haystack



func _normalize_achievement_search_text(value: String) -> String:
	return value.strip_edges().to_lower().replace("_", " ").replace("-", " ")

func _get_global_summary_fast() -> Dictionary:
	_refresh_cached_achievement_results(false)
	return _summarize_results_array(_achievement_all_results_cache)


func _get_global_summary() -> Dictionary:
	return _get_global_summary_fast()


func _get_category_summaries(results: Array) -> Array:
	_refresh_cached_achievement_results(false)
	var query := _filter_query.strip_edges()

	if query.is_empty() and results.size() == _achievement_all_results_cache.size():
		return _achievement_category_summary_cache

	return _build_category_summaries_from_results(results)


func _build_category_summaries_from_results(results: Array) -> Array:
	var by_category: Dictionary = {}
	for result in results:
		if not (result is Dictionary):
			continue
		var category := str(result.get("category", "type_amount"))
		if not by_category.has(category):
			by_category[category] = {"category": category, "label": str(result.get("category_label", category.capitalize())), "total": 0, "unlocked": 0, "bronze": 0, "silver": 0, "gold": 0, "points": 0, "first_number": 999999}
		var item: Dictionary = by_category[category]
		var achievement_number := int(result.get("number", result.get("achievementNumber", result.get("achievement_number", 999999))))

		if achievement_number > 0:
			item["first_number"] = min(int(item.get("first_number", 999999)), achievement_number)

		item["total"] = int(item.get("total", 0)) + 1
		var tier := int(result.get("tier", 0))
		if tier > 0:
			item["unlocked"] = int(item.get("unlocked", 0)) + 1
			item["points"] = int(item.get("points", 0)) + int(result.get("points", 0))
		match tier:
			1:
				item["bronze"] = int(item.get("bronze", 0)) + 1
			2:
				item["silver"] = int(item.get("silver", 0)) + 1
			3:
				item["gold"] = int(item.get("gold", 0)) + 1
		by_category[category] = item

	var output: Array = []
	for value in by_category.values():
		output.append(value)
	output.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_number := int(a.get("first_number", 999999))
		var b_number := int(b.get("first_number", 999999))

		if a_number != b_number:
			return a_number < b_number

		return _category_display_name(str(a.get("category", ""))) < _category_display_name(str(b.get("category", "")))
	)
	return output


func _filter_results_by_category(results: Array, category: String) -> Array:
	var filtered: Array = []
	for result in results:
		if str(result.get("category", "")) == category:
			filtered.append(result)
	return filtered


func _build_categories_progressively(categories: Array, local_generation: int) -> void:
	if local_generation != _view_generation or _closing or not is_instance_valid(_category_list):
		return

	var visible_keys := {}
	for summary in categories:
		if summary is Dictionary:
			visible_keys[str(summary.get("category", "type_amount"))] = true

	for key in _category_cards_by_key.keys():
		var old = _category_cards_by_key.get(key, null)
		if old != null and is_instance_valid(old):
			old.visible = visible_keys.has(key)

	if categories.is_empty():
		_show_empty("NO CATEGORY")
		return

	var built_count := 0
	var index := 0
	while index < categories.size():
		if local_generation != _view_generation or _closing or not is_instance_valid(_category_list):
			return

		var batch_count := 0
		var frame_start := Time.get_ticks_msec()
		while index < categories.size() and batch_count < CATEGORY_CARD_BATCH_SIZE:
			if Time.get_ticks_msec() - frame_start >= ACHIEVEMENT_BUILD_FRAME_BUDGET_MSEC:
				break
			var summary: Dictionary = categories[index]
			var key := str(summary.get("category", "type_amount"))
			var card = _category_cards_by_key.get(key, null)
			var is_new := false
			if card == null or not is_instance_valid(card):
				card = _make_category_card(summary, index)
				is_new = true
				card.modulate.a = 0.0 if _animate_current_rebuild and built_count < CARD_ANIMATION_LIMIT else 1.0
				card.scale = CARD_ENTER_SCALE if _animate_current_rebuild and built_count < CARD_ANIMATION_LIMIT else Vector2.ONE
				_category_cards_by_key[key] = card
				_category_list.add_child(card)
			else:
				if card.get_parent() != _category_list:
					_category_list.add_child(card)
			card.visible = true
			_category_list.move_child(card, index)
			if is_new and _animate_current_rebuild and built_count < CARD_ANIMATION_LIMIT:
				_animate_card_in(card, built_count)
			else:
				card.modulate.a = 1.0
				card.scale = Vector2.ONE
			index += 1
			built_count += 1
			batch_count += 1

		if built_count % ACHIEVEMENT_LAYOUT_REFRESH_EVERY == 0:
			_request_achievement_runtime_visibility_update()

		await get_tree().process_frame

	_hide_active_empty()
	call_deferred("_style_scroll_bar")
	_request_achievement_runtime_visibility_update()


func _build_category_batch(categories: Array, local_generation: int, start_index: int) -> void:
	await _build_categories_progressively(categories.slice(start_index), local_generation)


func _build_achievements_progressively(results: Array, local_generation: int) -> void:
	if local_generation != _view_generation or _closing or not is_instance_valid(_details_list):
		return

	var max_count: int = min(MAX_VISIBLE_RESULTS, results.size())
	var visible_ids := {}
	for i in range(max_count):
		var item: Dictionary = results[i]
		var id := _achievement_card_id(item, i)
		visible_ids[id] = true

	for id in _achievement_cards_by_id.keys():
		var card = _achievement_cards_by_id.get(id, null)
		if card != null and is_instance_valid(card):
			card.visible = visible_ids.has(id)

	if max_count <= 0:
		_show_empty("NO ACHIEVEMENTS")
		return

	var built_count := 0
	var index := 0
	while index < max_count:
		if local_generation != _view_generation or _closing or not is_instance_valid(_details_list):
			return

		var batch_count := 0
		var frame_start := Time.get_ticks_msec()
		while index < max_count and batch_count < ACHIEVEMENT_CARD_BATCH_SIZE:
			if Time.get_ticks_msec() - frame_start >= ACHIEVEMENT_BUILD_FRAME_BUDGET_MSEC:
				break
			var item: Dictionary = results[index]
			var id := _achievement_card_id(item, index)
			var card = _achievement_cards_by_id.get(id, null)
			var is_new := false
			if card == null or not is_instance_valid(card):
				card = _make_achievement_card(item, index + 1)
				is_new = true
				card.modulate.a = 0.0 if _animate_current_rebuild and built_count < CARD_ANIMATION_LIMIT else 1.0
				card.scale = CARD_ENTER_SCALE if _animate_current_rebuild and built_count < CARD_ANIMATION_LIMIT else Vector2.ONE
				_achievement_cards_by_id[id] = card
				_details_list.add_child(card)
			else:
				if card.get_parent() != _details_list:
					_details_list.add_child(card)
			card.visible = true
			_details_list.move_child(card, index)
			if is_new and _animate_current_rebuild and built_count < CARD_ANIMATION_LIMIT:
				_animate_card_in(card, built_count)
			else:
				card.modulate.a = 1.0
				card.scale = Vector2.ONE
			index += 1
			built_count += 1
			batch_count += 1

		if built_count % ACHIEVEMENT_LAYOUT_REFRESH_EVERY == 0:
			_request_achievement_runtime_visibility_update()

		await get_tree().process_frame

	_hide_active_empty()
	call_deferred("_style_scroll_bar")
	_request_achievement_runtime_visibility_update()


func _achievement_card_id(item: Dictionary, index: int) -> String:
	var id := str(item.get("id", "")).strip_edges()
	if id.is_empty():
		id = str(item.get("key", "achievement_%d" % index))
	return id


func _build_achievement_batch(results: Array, local_generation: int, start_index: int) -> void:
	await _build_achievements_progressively(results.slice(start_index), local_generation)


func _connect_achievement_scroll_runtime_visibility_signal() -> void:
	var cb := Callable(self, "_on_achievement_scroll_changed_for_runtime")
	for scroll_node in [_category_scroll, _details_scroll]:
		if not is_instance_valid(scroll_node):
			continue
		var bar = scroll_node.get_v_scroll_bar()
		if bar == null:
			continue
		if not bar.value_changed.is_connected(cb):
			bar.value_changed.connect(cb)
	_achievement_scroll_visibility_connected = true


func _on_achievement_scroll_changed_for_runtime(_value: float) -> void:
	_request_achievement_runtime_visibility_update()


func _request_achievement_runtime_visibility_update() -> void:
	if _achievement_runtime_visibility_update_pending:
		return
	var now := Time.get_ticks_msec()
	if now - _achievement_last_runtime_visibility_msec < ACHIEVEMENT_RUNTIME_VISIBILITY_MIN_INTERVAL_MSEC:
		_achievement_runtime_visibility_update_pending = true
		var wait_sec := float(ACHIEVEMENT_RUNTIME_VISIBILITY_MIN_INTERVAL_MSEC - (now - _achievement_last_runtime_visibility_msec)) / 1000.0
		get_tree().create_timer(max(wait_sec, 0.01), false).timeout.connect(func() -> void:
			_update_achievement_runtime_visibility()
		)
		return
	_achievement_runtime_visibility_update_pending = true
	call_deferred("_update_achievement_runtime_visibility")


func _update_achievement_runtime_visibility() -> void:
	_achievement_runtime_visibility_update_pending = false
	_achievement_last_runtime_visibility_msec = Time.get_ticks_msec()
	if not is_instance_valid(_scroll) or not is_instance_valid(_list):
		return
	var scroll_rect := _scroll.get_global_rect()
	var active_rect := Rect2(
		scroll_rect.position - Vector2(0.0, ACHIEVEMENT_RUNTIME_VIEWPORT_MARGIN),
		scroll_rect.size + Vector2(0.0, ACHIEVEMENT_RUNTIME_VIEWPORT_MARGIN * 2.0)
	)
	for child in _list.get_children():
		if child is Control:
			var card := child as Control
			_set_achievement_runtime_enabled(card, _rects_intersect(active_rect, card.get_global_rect()))


func _set_achievement_runtime_enabled(node: Node, enabled: bool) -> void:
	if node == null:
		return
	var desired_mode := Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	if node.process_mode != desired_mode:
		node.process_mode = desired_mode

	# Do not recurse through every Label, ProgressBar, MarginContainer and TextureRect.
	# Achievement cards do not run active per-child logic; the old recursive walk was
	# pure open/scroll cost and got nasty once many achievement cards existed.


func _rects_intersect(a: Rect2, b: Rect2) -> bool:
	return (
		a.position.x < b.position.x + b.size.x
		and a.position.x + a.size.x > b.position.x
		and a.position.y < b.position.y + b.size.y
		and a.position.y + a.size.y > b.position.y
	)


func _show_empty(text: String) -> void:
	var in_category := not _selected_category.strip_edges().is_empty()
	if is_instance_valid(_category_scroll):
		_category_scroll.visible = false
	if is_instance_valid(_details_scroll):
		_details_scroll.visible = false
	if is_instance_valid(_category_empty_label):
		_category_empty_label.visible = not in_category
		_category_empty_label.text = text if not in_category else ""
	if is_instance_valid(_details_empty_label):
		_details_empty_label.visible = in_category
		_details_empty_label.text = text if in_category else ""


func _update_summary_labels(unlocked: int, total: int, bronze: int, silver: int, gold: int) -> void:
	if is_instance_valid(_unlocked_value_label):
		_unlocked_value_label.text = "%d/%d" % [unlocked, total]
	_update_tier_value("bronze", bronze, total)
	_update_tier_value("silver", silver, total)
	_update_tier_value("gold", gold, total)


func _update_tier_value(key: String, value_count: int, total: int) -> void:
	if _tier_value_labels.has(key):
		var label = _tier_value_labels[key]
		if label is Label:
			label.text = str(value_count)
	if _tier_progress_bars.has(key):
		var bar = _tier_progress_bars[key]
		if bar is ProgressBar:
			bar.value = 0.0 if total <= 0 else clamp(float(value_count) / float(total), 0.0, 1.0)



func _apply_achievement_results_delta(results: Array) -> bool:
	if results is Array:
		_achievement_all_results_cache = results.duplicate()
		_achievement_search_haystack_cache.clear()
		_achievement_category_haystack_cache.clear()
		_achievement_category_summary_cache = _build_category_summaries_from_results(_achievement_all_results_cache)
		_achievement_cache_dirty = false
	if not is_instance_valid(_list) or _closing:
		return false
	var saved_scroll := _scroll.scroll_vertical if is_instance_valid(_scroll) else 0
	var summary := _summarize_results_array(results)
	_update_summary_labels(
		int(summary.get("unlocked", 0)),
		int(summary.get("total", results.size())),
		int(summary.get("bronze", 0)),
		int(summary.get("silver", 0)),
		int(summary.get("gold", 0))
	)

	# The category overview has aggregate cards, so a full rebuild is still needed there.
	# Keep the scroll position so the popup no longer jumps back to top.
	if _selected_category.strip_edges().is_empty():
		_rebuild_preserving_scroll(saved_scroll)
		return true

	var visible_results := []
	for item in results:
		if item is Dictionary and str(item.get("category", "")).strip_edges() == _selected_category:
			visible_results.append(item)

	var touched := false
	var visible_ids := {}
	for item in visible_results:
		var id := str(item.get("id", "")).strip_edges()
		if id.is_empty():
			continue
		visible_ids[id] = true
		var old_card = _achievement_cards_by_id.get(id, null)
		if old_card == null or not is_instance_valid(old_card):
			continue
		var index: int = old_card.get_index()
		var new_card := _make_achievement_card(item, index)
		new_card.modulate.a = 1.0
		new_card.scale = Vector2.ONE
		_list.add_child(new_card)
		_list.move_child(new_card, index)
		old_card.queue_free()
		touched = true

	for id in _achievement_cards_by_id.keys().duplicate():
		if visible_ids.has(id):
			continue
		var stale = _achievement_cards_by_id.get(id, null)
		_achievement_cards_by_id.erase(id)
		if stale != null and is_instance_valid(stale):
			stale.queue_free()
			touched = true

	if touched:
		call_deferred("_style_scroll_bar")
		call_deferred("_restore_achievement_scroll", saved_scroll)
		return true

	_rebuild_preserving_scroll(saved_scroll)
	return true


func _rebuild_preserving_scroll(scroll_value: int) -> void:
	_view_generation += 1
	var local_generation := _view_generation
	_update_active_achievement_view()
	_update_back_button()
	var all_results := _get_filtered_results()
	if _selected_category.strip_edges().is_empty():
		_build_categories_progressively(_get_category_summaries(all_results), local_generation)
	else:
		_build_achievements_progressively(_filter_results_by_category(all_results, _selected_category), local_generation)
	call_deferred("_restore_achievement_scroll", scroll_value)


func _restore_achievement_scroll(value: int) -> void:
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(clamp(float(value), 0.0, _get_achievement_max_scroll()))


func _get_achievement_max_scroll() -> float:
	if not is_instance_valid(_scroll):
		return 0.0

	var bar := _scroll.get_v_scroll_bar()
	if bar == null:
		return 0.0

	return max(0.0, bar.max_value - bar.page)


func _summarize_results_array(results: Array) -> Dictionary:
	var summary := {"total": 0, "unlocked": 0, "bronze": 0, "silver": 0, "gold": 0}
	for item in results:
		if not (item is Dictionary):
			continue
		summary["total"] = int(summary.get("total", 0)) + 1
		if bool(item.get("unlocked", false)):
			summary["unlocked"] = int(summary.get("unlocked", 0)) + 1
		match int(item.get("tier", 0)):
			1:
				summary["bronze"] = int(summary.get("bronze", 0)) + 1
			2:
				summary["silver"] = int(summary.get("silver", 0)) + 1
			3:
				summary["gold"] = int(summary.get("gold", 0)) + 1
	return summary

func _category_completion_progress(total: int, bronze: int, silver: int, gold: int) -> float:
	if total <= 0:
		return 0.0
	var weighted_score := float(bronze) + (float(silver) * 2.0) + (float(gold) * 3.0)
	return clamp(weighted_score / (float(total) * 3.0), 0.0, 1.0)


func _make_category_card(summary: Dictionary, index: int) -> Control:
	var category := str(summary.get("category", "type_amount"))
	var total := int(summary.get("total", 0))
	var unlocked := int(summary.get("unlocked", 0))
	var gold := int(summary.get("gold", 0))
	var silver := int(summary.get("silver", 0))
	var bronze := int(summary.get("bronze", 0))
	var tier := 3 if gold > 0 else (2 if silver > 0 else (1 if bronze > 0 else 0))
	var tier_color := _tier_color(tier)

	var panel := PanelContainer.new()
	panel.name = "AchievementCategoryCard"
	panel.set_meta("achievement_tier", tier)
	panel.set_meta("achievement_rare_unlocked", false)
	panel.set_meta("achievement_tier_color", tier_color)
	panel.custom_minimum_size = Vector2(0, 214)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.modulate.a = 0.0
	panel.scale = CARD_ENTER_SCALE
	panel.add_theme_stylebox_override("panel", _achievement_card_style(tier_color, tier, false))

	var press_state := {"down": false, "tween": null}
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			if event.pressed:
				press_state["down"] = true
				_bounce_card_down(panel, press_state)
			else:
				var should_open := bool(press_state.get("down", false)) and not _scroll_dragging
				press_state["down"] = false
				if should_open:
					_bounce_card_release(panel, press_state)
					_open_category(category)
				else:
					_bounce_card_cancel(panel, press_state)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				press_state["down"] = true
				_bounce_card_down(panel, press_state)
			else:
				var should_open := bool(press_state.get("down", false)) and not _scroll_dragging
				press_state["down"] = false
				if should_open:
					_bounce_card_release(panel, press_state)
					_open_category(category)
				else:
					_bounce_card_cancel(panel, press_state)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)

	row.add_child(_create_category_icon(category, tier, Color.WHITE if tier > 0 else COLOR_SUBTITLE, Vector2(126, 126)))

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 6)
	row.add_child(text_box)

	var title := Label.new()
	title.text = _category_display_name(category).to_upper()
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", COLOR_TEXT if tier > 0 else COLOR_SUBTITLE)
	_apply_app_font(title)
	text_box.add_child(title)

	var desc := Label.new()
	desc.text = _category_description(category, unlocked, total)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 31)
	desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.58 if tier > 0 else 0.42))
	desc.add_theme_constant_override("line_spacing", 0)
	_apply_app_font(desc)
	text_box.add_child(desc)

	var desc_progress_gap := Control.new()
	desc_progress_gap.custom_minimum_size = Vector2(0, 4)
	text_box.add_child(desc_progress_gap)

	var progress := ProgressBar.new()
	progress.min_value = 0.0
	progress.max_value = 1.0
	progress.value = _category_completion_progress(total, bronze, silver, gold)
	progress.custom_minimum_size = Vector2(1, 18)
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background", _progress_back_style())
	progress.add_theme_stylebox_override("fill", _progress_fill_style(Color.WHITE))
	text_box.add_child(progress)

	var meta := Label.new()
	meta.text = "%d/%d unlocked · %d bronze · %d silver · %d gold" % [unlocked, total, bronze, silver, gold]
	meta.add_theme_font_size_override("font_size", 28)
	meta.add_theme_color_override("font_color", COLOR_TEXT if tier > 0 else Color(1, 1, 1, 0.78))
	_apply_app_font(meta)
	text_box.add_child(meta)

	row.add_child(_create_forward_arrow_icon())

	return panel


func _make_back_card() -> Control:
	var panel := PanelContainer.new()
	panel.name = "AchievementsBackCard"
	panel.custom_minimum_size = Vector2(0, 112)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.modulate.a = 0.0
	panel.scale = CARD_ENTER_SCALE
	panel.add_theme_stylebox_override("panel", _unlocked_box_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	row.add_child(_create_back_arrow_inline_icon())

	var label := Label.new()
	label.text = "BACK TO CATEGORIES"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	_apply_app_font(label)
	row.add_child(label)

	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and not event.pressed and not _scroll_dragging:
			_back_to_categories()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and not _scroll_dragging:
			_back_to_categories()
	)

	return panel


func _create_forward_arrow_icon() -> Control:
	return _create_direction_arrow_icon(PI * 0.5, Vector2(64, 96), COLOR_TEXT, "→")


func _create_back_arrow_inline_icon() -> Control:
	return _create_direction_arrow_icon(-PI * 0.5, Vector2(64, 96), COLOR_TEXT, "←")


func _create_direction_arrow_icon(rotation_value: float, min_size: Vector2, color: Color, fallback_text: String) -> Control:
	var wrapper_control := Control.new()
	wrapper_control.custom_minimum_size = min_size
	wrapper_control.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _back_button_arrow_texture == null and ResourceLoader.exists(BACK_ARROW_TEXTURE_PATH):
		_back_button_arrow_texture = load(BACK_ARROW_TEXTURE_PATH) as Texture2D

	if _back_button_arrow_texture != null:
		wrapper_control.draw.connect(func() -> void:
			var draw_size: float = min(wrapper_control.size.x, wrapper_control.size.y) * 0.62
			var center := wrapper_control.size * 0.5
			var rect := Rect2(Vector2(-draw_size * 0.5, -draw_size * 0.5), Vector2(draw_size, draw_size))
			wrapper_control.draw_set_transform(center, rotation_value, Vector2.ONE)
			wrapper_control.draw_texture_rect(_back_button_arrow_texture, rect, false, color)
			wrapper_control.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		)
	else:
		var fallback := Label.new()
		fallback.text = fallback_text
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.custom_minimum_size = min_size
		fallback.add_theme_font_size_override("font_size", 70)
		fallback.add_theme_color_override("font_color", color)
		_apply_app_font(fallback)
		wrapper_control.add_child(fallback)

	return wrapper_control


func _open_category(category: String) -> void:
	_play_sfx("click")
	_category_scroll_value = _category_scroll.scroll_vertical if is_instance_valid(_category_scroll) else 0
	_selected_category = category
	_cached_max_scroll_bar = null
	_scroll_velocity = 0.0
	if is_instance_valid(_details_scroll):
		_details_scroll.scroll_vertical = 0
	_update_back_button()
	_request_rebuild()


func _back_to_categories() -> void:
	_play_sfx("click")
	_selected_category = ""
	_cached_max_scroll_bar = null
	_scroll_velocity = 0.0
	_update_active_achievement_view()
	_update_back_button()
	if is_instance_valid(_category_scroll):
		_category_scroll.scroll_vertical = int(_category_scroll_value)
	call_deferred("_style_scroll_bar")


func _category_display_name(category: String) -> String:
	match category:
		"add_body":
			return "Added Bodies"
		"planet_collision":
			return "Planet Collisions"
		"sun_collision":
			return "Star Collisions"
		"black_hole":
			return "Black Holes"
		"stat_mastery":
			return "Stat Mastery"
		"ai_assistant":
			return "AI Assistant"
		"instability":
			return "Unstable Systems"
		"type_amount":
			return "Cards"
		"fictional_system":
			return "Custom Systems"
		"franchise_system":
			return "Real Systems"
		_:
			return category.replace("_", " ").capitalize()


func _category_description(category: String, unlocked: int, total: int) -> String:
	match category:
		"add_body":
			return "Add more cosmic bodies to the simulator and grow your active universe."
		"planet_collision":
			return "Create controlled planet impacts and study how collisions change your system."
		"sun_collision":
			return "Push stars into dangerous encounters and observe the chaos they create."
		"black_hole":
			return "Trigger extreme stellar events and discover collapsed black-hole systems."
		"stat_mastery":
			return "Upgrade planet cards until their six science stats reach perfect scores."
		"ai_assistant":
			return "Use Apollo to navigate, create, tune settings, and control the galaxy by voice."
		"instability":
			return "Build chaotic systems that become unstable through crowding or collisions."
		"type_amount":
			return "Collect and upgrade different card types across your universe."
		"fictional_system":
			return "Create original custom systems using your own generated stars and planets."
		"franchise_system":
			return "Recreate known systems, from our Solar System to famous sci-fi galaxies."
		_:
			return "Unlock %d of %d achievements in this category by experimenting with your universe." % [unlocked, total]


func _rarity_color(rarity: String, tier: int = 0) -> Color:
	if rarity.strip_edges().to_lower() == "rare":
		return _get_theme_highlight_color()
	return Color.WHITE if tier > 0 else COLOR_SUBTITLE


func _achievement_text_color(unlocked: bool) -> Color:
	return Color.WHITE if unlocked else COLOR_SUBTITLE


func _achievement_accent_color(rarity: String, unlocked: bool) -> Color:
	if not unlocked:
		return COLOR_SUBTITLE
	if rarity.strip_edges().to_lower() == "rare":
		return _get_theme_highlight_color()
	return Color.WHITE


func _achievement_content_color(rarity: String, unlocked: bool) -> Color:
	return _achievement_text_color(unlocked)


func _achievement_subtitle_color(rarity: String, unlocked: bool) -> Color:
	if not unlocked:
		return COLOR_SUBTITLE
	var base := _achievement_text_color(true)
	base.a = 0.58
	return base


func _make_achievement_card(result: Dictionary, _index: int) -> Control:
	var tier := int(result.get("tier", 0))
	var hidden := bool(result.get("hidden", false)) or not bool(result.get("unlocked", tier > 0))
	var rarity := str(result.get("rarity", "normal")).strip_edges().to_lower()
	var unlocked := bool(result.get("unlocked", tier > 0)) and not hidden
	var tier_color := _rarity_color(rarity, tier)
	var text_color := _achievement_text_color(unlocked)
	var accent_color := _achievement_accent_color(rarity, unlocked)
	if rarity == "rare" and unlocked:
		text_color = accent_color
	var rare_unlocked := false
	var medal_text_color := _tier_color(tier) if tier > 0 else COLOR_SUBTITLE
	var category := str(result.get("category", "type_amount"))

	var panel := PanelContainer.new()
	panel.name = "AchievementCard"
	panel.set_meta("achievement_tier", tier)
	panel.set_meta("achievement_rare_unlocked", rare_unlocked)
	panel.set_meta("achievement_tier_color", tier_color)
	var achievement_id := str(result.get("id", "")).strip_edges()
	if not achievement_id.is_empty():
		panel.set_meta("achievement_id", achievement_id)
		_achievement_cards_by_id[achievement_id] = panel
	panel.custom_minimum_size = Vector2(0, 220)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.modulate.a = 0.0
	panel.scale = CARD_ENTER_SCALE
	panel.add_theme_stylebox_override("panel", _achievement_card_style(tier_color, tier, rare_unlocked))


	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)

	var icon := _create_category_icon(category, tier, accent_color, Vector2(126, 126))
	row.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 6)
	row.add_child(text_box)

	var top_line := HBoxContainer.new()
	top_line.add_theme_constant_override("separation", 14)
	text_box.add_child(top_line)

	var title := Label.new()
	title.text = "???" if hidden else str(result.get("title", "Achievement"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", text_color)
	title.clip_text = true
	_apply_app_font(title)
	top_line.add_child(title)

	var tag := Label.new()
	tag.text = "???" if hidden else str(result.get("rarity_label", "NORMAL")).to_upper()
	tag.add_theme_font_size_override("font_size", 29)
	tag.add_theme_color_override("font_color", accent_color)
	_apply_app_font(tag)
	top_line.add_child(tag)

	var desc := Label.new()
	desc.text = _achievement_display_description(result, hidden)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 31)
	desc.add_theme_color_override("font_color", _achievement_subtitle_color(rarity, unlocked))
	desc.add_theme_constant_override("line_spacing", 0)
	_apply_app_font(desc)
	text_box.add_child(desc)

	var desc_progress_gap := Control.new()
	desc_progress_gap.custom_minimum_size = Vector2(0, 4)
	text_box.add_child(desc_progress_gap)

	var progress := ProgressBar.new()
	progress.min_value = 0.0
	progress.max_value = 1.0
	progress.value = _achievement_display_progress(result, hidden)
	progress.custom_minimum_size = Vector2(1, 18)
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background", _progress_back_style())
	progress.add_theme_stylebox_override("fill", _progress_fill_style(Color.WHITE))
	text_box.add_child(progress)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	text_box.add_child(status_row)

	var extra := "%d/%d" % [int(result.get("current_count", 0)), int(result.get("required_count", 0))]
	if int(result.get("required_stars", 0)) > 0:
		extra += " · %d/%d stars" % [int(result.get("active_stars", 0)), int(result.get("required_stars", 0))]
	var stage_label := str(result.get("stage_label", "")).strip_edges()
	var stage_part := (" · " + stage_label) if not stage_label.is_empty() else ""

	var status_tier := Label.new()
	status_tier.text = "LOCKED" if hidden else str(result.get("tier_name", "LOCKED"))
	status_tier.add_theme_font_size_override("font_size", 28)
	status_tier.add_theme_color_override("font_color", medal_text_color if tier > 0 else COLOR_SUBTITLE)
	_apply_app_font(status_tier)
	status_row.add_child(status_tier)

	# Progress count text after BRONZE / SILVER / GOLD was redundant with the subtitle
	# and progress bar, so it stays gone for good.

	return panel




func _achievement_display_description(result: Dictionary, hidden: bool) -> String:
	if hidden:
		return "Hidden achievement. Unlock it to reveal the real challenge."
	if bool(result.get("unlocked", false)) and str(result.get("next_stage_description", "")).strip_edges() != "":
		return str(result.get("next_stage_description", ""))
	return str(result.get("description", "Complete this achievement by experimenting with your universe."))


func _achievement_display_progress(result: Dictionary, hidden: bool) -> float:
	if hidden:
		return 0.0
	if int(result.get("tier", 0)) >= 3:
		return 1.0
	var required: float = max(float(result.get("required_count", 0)), 1.0)
	var current: float = clamp(float(result.get("current_count", 0)), 0.0, required)
	if required > 0.0:
		return clamp(current / required, 0.0, 1.0)
	return clamp(float(result.get("progress", 0.0)), 0.0, 1.0)


func _bounce_card_down(card: Control, state: Dictionary) -> void:
	if reduce_motion_enabled or not is_instance_valid(card):
		return
	_kill_card_state_tween(state)
	card.pivot_offset = card.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2(0.97, 0.97), BACK_BUTTON_DOWN_TIME)
	state["tween"] = tween


func _bounce_card_release(card: Control, state: Dictionary) -> void:
	if reduce_motion_enabled or not is_instance_valid(card):
		return
	_kill_card_state_tween(state)
	card.pivot_offset = card.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2(1.025, 1.025), BACK_BUTTON_UP_TIME)
	tween.tween_property(card, "scale", Vector2.ONE, BACK_BUTTON_SETTLE_TIME)
	state["tween"] = tween


func _bounce_card_cancel(card: Control, state: Dictionary) -> void:
	if reduce_motion_enabled or not is_instance_valid(card):
		return
	_kill_card_state_tween(state)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE, BACK_BUTTON_SETTLE_TIME)
	state["tween"] = tween


func _kill_card_state_tween(state: Dictionary) -> void:
	var old_tween = state.get("tween", null)
	if old_tween is Tween and old_tween.is_valid():
		old_tween.kill()


func _input(event: InputEvent) -> void:
	if _back_button_pointer_id == -999:
		return

	if event is InputEventScreenDrag:
		if event.index == _back_button_pointer_id:
			_update_back_button_pressed_visual(event.position)
	elif event is InputEventScreenTouch:
		if not event.pressed and event.index == _back_button_pointer_id:
			_finish_back_button_press(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _back_button_pointer_id == -2:
			_update_back_button_pressed_visual(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _back_button_pointer_id == -2:
			_finish_back_button_press(event.position)
			get_viewport().set_input_as_handled()


func _start_back_button_press(pointer_id: int) -> void:
	if not is_instance_valid(_back_button):
		return

	if _selected_category.strip_edges().is_empty():
		return

	_back_button_pointer_id = pointer_id
	_back_button_pressed = true
	_back_button.queue_redraw()

	if not reduce_motion_enabled:
		_bounce_back_button_down()


func _update_back_button_pressed_visual(screen_position: Vector2) -> void:
	if not is_instance_valid(_back_button):
		return

	var inside := _back_button.get_global_rect().has_point(screen_position)

	if _back_button_pressed != inside:
		_back_button_pressed = inside
		_back_button.queue_redraw()


func _finish_back_button_press(screen_position: Vector2) -> void:
	if not is_instance_valid(_back_button):
		_back_button_pointer_id = -999
		_back_button_pressed = false
		return

	var released_inside := _back_button.get_global_rect().has_point(screen_position)

	_back_button_pointer_id = -999
	_back_button_pressed = false
	_back_button.queue_redraw()

	if released_inside:
		if not reduce_motion_enabled:
			_bounce_back_button_release()
		_play_sfx("click")

		if not _selected_category.strip_edges().is_empty():
			_back_to_categories()
	else:
		if not reduce_motion_enabled:
			_bounce_back_button_cancel()


func _bounce_back_button_down() -> void:
	if not is_instance_valid(_back_button):
		return

	if _back_button_bounce_tween != null and _back_button_bounce_tween.is_valid():
		_back_button_bounce_tween.kill()

	_back_button.pivot_offset = _back_button.size * 0.5
	_back_button_bounce_tween = create_tween()
	_back_button_bounce_tween.set_trans(Tween.TRANS_BACK)
	_back_button_bounce_tween.set_ease(Tween.EASE_OUT)
	_back_button_bounce_tween.tween_property(_back_button, "scale", BACK_BUTTON_PRESS_SCALE, BACK_BUTTON_DOWN_TIME)


func _bounce_back_button_release() -> void:
	if not is_instance_valid(_back_button):
		return

	if _back_button_bounce_tween != null and _back_button_bounce_tween.is_valid():
		_back_button_bounce_tween.kill()

	_back_button.pivot_offset = _back_button.size * 0.5
	_back_button_bounce_tween = create_tween()
	_back_button_bounce_tween.set_trans(Tween.TRANS_BACK)
	_back_button_bounce_tween.set_ease(Tween.EASE_OUT)
	_back_button_bounce_tween.tween_property(_back_button, "scale", BACK_BUTTON_RELEASE_SCALE, BACK_BUTTON_UP_TIME)
	_back_button_bounce_tween.tween_property(_back_button, "scale", Vector2.ONE, BACK_BUTTON_SETTLE_TIME)


func _bounce_back_button_cancel() -> void:
	if not is_instance_valid(_back_button):
		return

	if _back_button_bounce_tween != null and _back_button_bounce_tween.is_valid():
		_back_button_bounce_tween.kill()

	_back_button.pivot_offset = _back_button.size * 0.5
	_back_button_bounce_tween = create_tween()
	_back_button_bounce_tween.set_trans(Tween.TRANS_BACK)
	_back_button_bounce_tween.set_ease(Tween.EASE_OUT)
	_back_button_bounce_tween.tween_property(_back_button, "scale", Vector2.ONE, BACK_BUTTON_SETTLE_TIME)


func _update_back_button() -> void:
	if not is_instance_valid(_back_button):
		return

	_back_button.visible = true
	_back_button.modulate.a = 1.0
	_animate_back_button_active_state()
	_layout_search_row()
	_back_button.queue_redraw()


func _apply_search_button() -> void:
	_play_sfx("click")
	if is_instance_valid(_search_box):
		_filter_query = _search_box.text.strip_edges()
		_search_box.release_focus()
	_request_rebuild()


func _create_search_icon() -> Control:
	var center_wrap := CenterContainer.new()
	center_wrap.custom_minimum_size = Vector2(92, 120)
	center_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon := Control.new()
	icon.custom_minimum_size = Vector2(76, 76)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		_draw_search_icon(icon, COLOR_TEXT, 7.0)
	)

	center_wrap.add_child(icon)
	return center_wrap


func _draw_search_icon(canvas: Control, color: Color, width: float = 7.0) -> void:
	var center := canvas.size * 0.5 + Vector2(-5, -5)
	var radius: float = min(canvas.size.x, canvas.size.y) * 0.27
	canvas.draw_arc(center, radius, 0.0, TAU, 64, color, width, true)
	canvas.draw_line(center + Vector2(radius * 0.70, radius * 0.70), center + Vector2(radius * 1.70, radius * 1.70), color, width, true)


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
		button.draw_line(center + Vector2(-half_size, -half_size), center + Vector2(half_size, half_size), COLOR_TEXT, width, true)
		button.draw_line(center + Vector2(half_size, -half_size), center + Vector2(-half_size, half_size), COLOR_TEXT, width, true)
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


func _clear_search() -> void:
	_play_sfx("click")
	_filter_query = ""
	if is_instance_valid(_search_box):
		_search_box.text = ""
	_update_search_clear_button()
	_request_rebuild()


func _update_search_clear_button() -> void:
	if not is_instance_valid(_search_clear_button) or not is_instance_valid(_search_box):
		return
	_search_clear_button.visible = not _search_box.text.strip_edges().is_empty()
	_search_clear_button.queue_redraw()


func _create_category_icon(category: String, tier: int, tier_color: Color, min_size: Vector2) -> Control:
	var holder := Control.new()
	holder.name = "CategoryIcon"
	holder.custom_minimum_size = min_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_texture := _load_achievement_icon_texture(category)
	var active := tier > 0 or category == "achievement_total" or category in ["bronze", "silver", "gold"]
	var highlight := _get_theme_highlight_color()
	var is_medal := category in ["bronze", "silver", "gold"]
	var symbol_color := tier_color if active else COLOR_SUBTITLE
	var ring_color := tier_color if active else COLOR_SUBTITLE

	holder.draw.connect(func() -> void:
		var side: float = min(holder.size.x, holder.size.y)
		var center := holder.size * 0.5
		var radius := side * 0.43
		holder.draw_arc(center, radius, 0.0, TAU, 112, ring_color, 4.6, true)
	)

	if icon_texture != null:
		var texture_rect := TextureRect.new()
		texture_rect.name = "IconTexture"
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_rect.texture = icon_texture
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.material = _make_icon_tint_material(symbol_color)
		holder.add_child(texture_rect)

		holder.resized.connect(func() -> void:
			var side: float = min(holder.size.x, holder.size.y)
			var texture_scale := _icon_texture_scale_for_category(category)
			var icon_size := Vector2(side * 0.56 * texture_scale, side * 0.56 * texture_scale)
			texture_rect.size = icon_size
			texture_rect.custom_minimum_size = icon_size
			texture_rect.position = (holder.size - icon_size) * 0.5
		)

		call_deferred("_layout_icon_texture", texture_rect, holder, category)
	else:
		holder.draw.connect(func() -> void:
			_draw_category_icon_symbol(holder, category, tier, tier_color)
		)

	return holder


func _layout_icon_texture(texture_rect: TextureRect, holder: Control, category: String = "") -> void:
	if not is_instance_valid(texture_rect) or not is_instance_valid(holder):
		return
	var side: float = min(holder.size.x, holder.size.y)
	if side <= 0.0:
		side = min(holder.custom_minimum_size.x, holder.custom_minimum_size.y)
	var texture_scale := _icon_texture_scale_for_category(category)
	var icon_size := Vector2(side * 0.56 * texture_scale, side * 0.56 * texture_scale)
	texture_rect.size = icon_size
	texture_rect.custom_minimum_size = icon_size
	texture_rect.position = (holder.size - icon_size) * 0.5


func _icon_texture_scale_for_category(category: String) -> float:
	match category:
		"ai_assistant", "instability":
			return 1.1
		_:
			return 1.0


func _load_achievement_icon_texture(category: String) -> Texture2D:
	var path := _achievement_icon_path(category)
	if path.is_empty():
		return null
	if _icon_texture_cache.has(path):
		return _icon_texture_cache[path]
	if not ResourceLoader.exists(path):
		_icon_texture_cache[path] = null
		return null
	var texture := load(path) as Texture2D
	_icon_texture_cache[path] = texture
	return texture


func _achievement_icon_path(category: String) -> String:
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
			return ""


func _draw_category_icon_symbol(icon: Control, category: String, tier: int, tier_color: Color) -> void:
	var side: float = min(icon.size.x, icon.size.y)
	var center := icon.size * 0.5
	var radius := side * 0.43
	var active := tier > 0 or category == "achievement_total" or category in ["bronze", "silver", "gold"]
	var highlight := _get_theme_highlight_color()
	var color := tier_color if active else COLOR_SUBTITLE
	var ring_color := tier_color if active else COLOR_SUBTITLE
	var fill_color := Color(1, 1, 1, 0.055 if active else 0.0)

	icon.draw_circle(center, radius, fill_color)
	icon.draw_arc(center, radius, 0.0, TAU, 112, ring_color, 4.6, true)

	match category:
		"achievement_total":
			_draw_trophy_icon(icon, center, radius, color)
		"bronze", "silver", "gold":
			_draw_medal_icon(icon, center, radius, color)
		"add_body":
			_draw_orbit_body_icon(icon, center, radius, color)
		"planet_collision":
			_draw_collision_icon(icon, center, radius, color, false)
		"sun_collision":
			_draw_collision_icon(icon, center, radius, color, true)
		"black_hole":
			_draw_black_hole_icon(icon, center, radius, color)
		"stat_mastery":
			_draw_stats_icon(icon, center, radius, color)
		"ai_assistant":
			_draw_trophy_icon(icon, center, radius, color)
		"instability":
			_draw_instability_icon(icon, center, radius, color)
		"fictional_system":
			_draw_fiction_icon(icon, center, radius, color)
		"franchise_system":
			_draw_franchise_icon(icon, center, radius, color)
		"type_amount":
			_draw_collection_icon(icon, center, radius, color)
		_:
			_draw_trophy_icon(icon, center, radius, color)


func _draw_orbit_body_icon(icon: Control, center: Vector2, radius: float, color: Color) -> void:
	icon.draw_arc(center, radius * 0.55, -0.28, TAU - 0.28, 96, color, 4.0, true)
	icon.draw_circle(center, radius * 0.20, color)
	icon.draw_circle(center + Vector2(radius * 0.55, 0), radius * 0.095, Color.WHITE)
	icon.draw_line(center + Vector2(radius * 0.12, -radius * 0.55), center + Vector2(radius * 0.12, -radius * 0.28), color, 4.0, true)
	icon.draw_line(center + Vector2(-radius * 0.02, -radius * 0.42), center + Vector2(radius * 0.26, -radius * 0.42), color, 4.0, true)


func _draw_collision_icon(icon: Control, center: Vector2, radius: float, color: Color, suns: bool) -> void:
	if suns:
		for i in range(10):
			var a := TAU * float(i) / 10.0
			icon.draw_line(center + Vector2(cos(a), sin(a)) * radius * 0.15, center + Vector2(cos(a), sin(a)) * radius * 0.38, color, 3.0, true)
	icon.draw_circle(center + Vector2(-radius * 0.23, 0), radius * 0.24, color)
	icon.draw_circle(center + Vector2(radius * 0.23, 0), radius * 0.24, Color.WHITE)
	var shard_color := color if not suns else Color.WHITE
	icon.draw_line(center + Vector2(-radius * 0.04, -radius * 0.45), center + Vector2(radius * 0.05, radius * 0.45), shard_color, 4.0, true)
	icon.draw_line(center + Vector2(-radius * 0.40, -radius * 0.14), center + Vector2(radius * 0.42, radius * 0.18), shard_color, 3.0, true)


func _draw_black_hole_icon(icon: Control, center: Vector2, radius: float, color: Color) -> void:
	icon.draw_arc(center, radius * 0.58, -0.45, PI + 0.35, 96, color, 5.0, true)
	icon.draw_arc(center, radius * 0.36, PI - 0.35, TAU + 0.45, 96, Color.WHITE, 4.0, true)
	icon.draw_circle(center, radius * 0.22, Color.BLACK)
	icon.draw_arc(center, radius * 0.23, 0.0, TAU, 64, color, 2.5, true)


func _draw_stats_icon(icon: Control, center: Vector2, radius: float, color: Color) -> void:
	for i in range(6):
		var h := radius * (0.24 + float((i * 2) % 5) * 0.065)
		var x := center.x - radius * 0.48 + float(i) * radius * 0.19
		icon.draw_line(Vector2(x, center.y + radius * 0.38), Vector2(x, center.y + radius * 0.38 - h), color if i % 2 == 0 else Color.WHITE, 5.0, true)
	icon.draw_line(center + Vector2(-radius * 0.56, radius * 0.40), center + Vector2(radius * 0.56, radius * 0.40), Color.WHITE, 3.0, true)


func _draw_stability_icon(icon: Control, center: Vector2, radius: float, color: Color) -> void:
	icon.draw_arc(center, radius * 0.60, 0.0, TAU, 96, color, 3.5, true)
	icon.draw_circle(center, radius * 0.15, color)
	icon.draw_circle(center + Vector2(radius * 0.60, 0), radius * 0.08, Color.WHITE)
	icon.draw_line(center + Vector2(-radius * 0.38, radius * 0.08), center + Vector2(-radius * 0.10, radius * 0.34), Color.WHITE, 4.0, true)
	icon.draw_line(center + Vector2(-radius * 0.10, radius * 0.34), center + Vector2(radius * 0.42, -radius * 0.32), Color.WHITE, 4.0, true)


func _draw_instability_icon(icon: Control, center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([center + Vector2(0, -radius * 0.58), center + Vector2(radius * 0.50, radius * 0.42), center + Vector2(-radius * 0.50, radius * 0.42)])
	icon.draw_colored_polygon(points, Color(color.r, color.g, color.b, 0.22))
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	icon.draw_polyline(outline, color, 4.2, true)
	icon.draw_line(center + Vector2(0, -radius * 0.25), center + Vector2(0, radius * 0.12), Color.WHITE, 4.0, true)
	icon.draw_circle(center + Vector2(0, radius * 0.32), 4.0, Color.WHITE)


func _draw_fiction_icon(icon: Control, center: Vector2, radius: float, color: Color) -> void:
	var p := PackedVector2Array()
	for i in range(10):
		var a := -PI * 0.5 + TAU * float(i) / 10.0
		var r := radius * (0.64 if i % 2 == 0 else 0.30)
		p.append(center + Vector2(cos(a), sin(a)) * r)
	icon.draw_colored_polygon(p, Color(color.r, color.g, color.b, 0.84))
	icon.draw_arc(center, radius * 0.24, 0.0, TAU, 64, Color.WHITE, 3.0, true)


func _draw_franchise_icon(icon: Control, center: Vector2, radius: float, color: Color) -> void:
	icon.draw_arc(center, radius * 0.55, -0.30, TAU - 0.30, 96, color, 4.0, true)
	icon.draw_line(center + Vector2(-radius * 0.42, -radius * 0.25), center + Vector2(radius * 0.42, radius * 0.28), Color.WHITE, 4.0, true)
	icon.draw_circle(center + Vector2(radius * 0.42, radius * 0.28), radius * 0.12, color)
	icon.draw_circle(center + Vector2(-radius * 0.42, -radius * 0.25), radius * 0.09, Color.WHITE)


func _draw_collection_icon(icon: Control, center: Vector2, radius: float, color: Color) -> void:
	for i in range(3):
		var a := -0.8 + float(i) * 0.8
		icon.draw_circle(center + Vector2(cos(a), sin(a)) * radius * 0.36, radius * (0.14 + float(i) * 0.025), color if i != 1 else Color.WHITE)
	icon.draw_arc(center, radius * 0.58, 0.10, PI - 0.10, 72, color, 3.5, true)


func _draw_trophy_icon(icon: Control, center: Vector2, radius: float, color: Color) -> void:
	var cup := Rect2(center + Vector2(-radius * 0.26, -radius * 0.35), Vector2(radius * 0.52, radius * 0.42))
	icon.draw_rect(cup, color, false, 5.0)
	icon.draw_arc(center + Vector2(-radius * 0.28, -radius * 0.12), radius * 0.20, PI * 0.5, PI * 1.5, 40, Color.WHITE, 3.2, true)
	icon.draw_arc(center + Vector2(radius * 0.28, -radius * 0.12), radius * 0.20, -PI * 0.5, PI * 0.5, 40, Color.WHITE, 3.2, true)
	icon.draw_line(center + Vector2(0, radius * 0.08), center + Vector2(0, radius * 0.36), color, 5.0, true)
	icon.draw_line(center + Vector2(-radius * 0.30, radius * 0.38), center + Vector2(radius * 0.30, radius * 0.38), Color.WHITE, 5.0, true)


func _draw_medal_icon(icon: Control, center: Vector2, radius: float, color: Color) -> void:
	icon.draw_line(center + Vector2(-radius * 0.22, -radius * 0.50), center + Vector2(-radius * 0.05, -radius * 0.12), Color.WHITE, 4.0, true)
	icon.draw_line(center + Vector2(radius * 0.22, -radius * 0.50), center + Vector2(radius * 0.05, -radius * 0.12), Color.WHITE, 4.0, true)
	icon.draw_circle(center + Vector2(0, radius * 0.08), radius * 0.28, color)
	icon.draw_arc(center + Vector2(0, radius * 0.08), radius * 0.17, 0.0, TAU, 64, Color.WHITE, 3.0, true)


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

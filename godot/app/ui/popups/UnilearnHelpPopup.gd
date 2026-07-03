extends CanvasLayer

signal closed

const FONT_PATH := "res://assets/fonts/JockeyOne-Regular.ttf"
const POPUP_SLIDE_DURATION := 0.42
const POPUP_FADE_DURATION := 0.22
const DIM_FADE_DURATION := 0.26
const POPUP_SIDE_PADDING := 80.0

const COLOR_PANEL := Color(0.0, 0.0, 0.0, 0.82)
const COLOR_BORDER := Color.WHITE
const COLOR_TEXT := Color.WHITE
const COLOR_SUBTITLE := Color(1.0, 1.0, 1.0, 0.58)
const COLOR_MUTED := Color(1.0, 1.0, 1.0, 0.36)
const COLOR_CARD := Color(1.0, 1.0, 1.0, 0.055)
const COLOR_CARD_BORDER := Color(1.0, 1.0, 1.0, 0.18)
const COLOR_HIGHLIGHT := Color(1.0, 0.82, 0.34, 0.98)

@export var panel_width_ratio: float = 0.96
@export var panel_height_ratio: float = 0.96
@export var panel_max_width: float = 1380.0
@export var panel_max_height: float = 1260.0
@export var panel_padding_x: int = 34
@export var panel_padding_y: int = 34

var reduce_motion_enabled := false
var _root: Control
var _dim: ColorRect
var _slide_root: Control
var _panel: PanelContainer
var _body: Control
var _title: Label
var _subtitle: Label
var _separator_line: ColorRect
var _page_holder: Control
var _page_row: HBoxContainer
var _dots: HBoxContainer
var _close_button: Button
var _page_tween: Tween
var _center_position := Vector2.ZERO
var _closing := false
var _popup_tween: Tween
var _app_font: Font = null
var _sfx_node: Node = null
var _settings_node: Node = null
var _style_cache: Dictionary = {}
var _current_page := 0
var _drag_start := Vector2.ZERO
var _drag_start_row_x := 0.0
var _dragging := false
var _drag_pointer_id := -999
var _card_gap := 34.0

var _pages := [
	{"step":"01", "title":"BUILD A UNIVERSE", "icon":"*", "summary":"Place bodies, throw them, or let stable orbit mode turn chaos into clean paths.", "bullets":["Add stars, planets, moons and singularities", "Drag bodies to test gravity", "Use collisions to evolve objects"], "chips":["STABLE", "BINARY", "CHAOS"]},
	{"step":"02", "title":"YOUR ROLE", "icon":"O", "summary":"You are the architect of a tiny learning universe.", "bullets":["Create experiments", "Observe what changes", "Turn strange systems into knowledge"], "chips":["ARCHITECT", "LEARNER"]},
	{"step":"03", "title":"PROGRESSION", "icon":"^", "summary":"Cards, XP, levels and achievements are the main progression loop.", "bullets":["Planet cards level up through use", "Achievements track discoveries", "Bronze, Silver and Gold mark mastery"], "chips":["XP", "LEVELS", "RARITY"]},
	{"step":"04", "title":"PLANET CARDS", "icon":"[]", "summary":"Cards are your collection, database and object launcher.", "bullets":["Tap cards for details", "Inspect stats, facts and prompts", "Add or remove bodies from the simulator"], "chips":["HERO", "STATS", "FACTS"]},
	{"step":"05", "title":"SMART SEARCH", "icon":">", "summary":"Use normal search or the >key:value filter method.", "bullets":[">type:star", ">type:moon", ">rings:yes", "Combine with text: >type:gas ringed"], "chips":["TYPE", "RINGS", "FEATURE"]},
	{"step":"06", "title":"ACHIEVEMENTS", "icon":"★", "summary":"Rewards come from experiments, weird systems and discoveries.", "bullets":["Browse category cards", "Open categories for full goals", "Search filters categories too"], "chips":["BRONZE", "SILVER", "GOLD"]},
	{"step":"07", "title":"GALAXY CONSOLE", "icon":"~", "summary":"The control room for data, physics, commands and results.", "bullets":["Data shows active bodies", "Behaviour tunes physics", "Reset Camera is second in Commands"], "chips":["DATA", "COMMANDS"]},
	{"step":"08", "title":"AI COMMANDS", "icon":"AI", "summary":"Apollo can navigate and trigger simple actions with natural commands.", "bullets":["Open planet cards, achievements or console", "Reset camera", "Turn music or SFX on/off"], "chips":["VOICE", "NAV", "HELP"]}
]

func setup(_reduce_motion_enabled: bool = false) -> void:
	reduce_motion_enabled = _reduce_motion_enabled

func _ready() -> void:
	layer = 1200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_app_font = load(FONT_PATH) as Font
	_sfx_node = get_node_or_null("/root/UnilearnSFX")
	_settings_node = get_node_or_null("/root/UnilearnUserSettings")
	_build_ui()
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or _closing:
		return
	_prepare_center_position()
	_layout_content()
	_snap_to_current_page(false)
	_update_page_dots()
	await _play_intro()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_dim = ColorRect.new()
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
	_slide_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide_root.modulate.a = 0.0
	_root.add_child(_slide_root)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_slide_root.add_child(_panel)

	_body = Control.new()
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.mouse_filter = Control.MOUSE_FILTER_STOP
	_body.clip_contents = true
	_panel.add_child(_body)
	_body.gui_input.connect(_on_body_input)

	_title = _make_label("HOW TO PLAY?", 118, COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_title.z_index = 10
	_body.add_child(_title)
	_subtitle = _make_label("Learn how to use multiple game functions!", 52, COLOR_SUBTITLE, HORIZONTAL_ALIGNMENT_CENTER)
	_subtitle.name = "HowToPlaySubtitle"
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.clip_text = false
	_subtitle.z_index = 10
	_subtitle.modulate = Color.WHITE
	_subtitle.add_theme_color_override("font_color", COLOR_SUBTITLE)
	_body.add_child(_subtitle)

	# The tutorial uses a drag-driven, scroll-wheel-like carousel.
	# No arrows: swipe/drag left-right, then it smoothly snaps to the closest card.
	_page_holder = Control.new()
	_page_holder.name = "TutorialCarouselViewport"
	_page_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	_page_holder.clip_contents = true
	_page_holder.z_index = 2
	_body.add_child(_page_holder)
	_page_holder.gui_input.connect(_on_page_input)

	_page_row = HBoxContainer.new()
	_page_row.name = "TutorialCarouselRow"
	_page_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_row.add_theme_constant_override("separation", int(_card_gap))
	_page_holder.add_child(_page_row)

	_build_tutorial_cards()

	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 12)
	_body.add_child(_dots)
	for i in range(_pages.size()):
		var dot := PanelContainer.new()
		dot.name = "TutorialPageDot%d" % i
		dot.custom_minimum_size = Vector2(22, 22)
		dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.set_meta("dot_color", Color.WHITE)
		dot.add_theme_stylebox_override("panel", _dot_style(false))
		_dots.add_child(dot)


func _layout_content() -> void:
	if not is_instance_valid(_panel):
		return
	var w := _panel.size.x
	var h := _panel.size.y
	if w <= 0.0 or h <= 0.0:
		return

	var x := float(panel_padding_x)
	var usable_w: float = max(320.0, w - float(panel_padding_x * 2))
	var y := float(panel_padding_y)

	# Same title/subtitle rhythm as the other popup menus, but the carousel
	# starts at the same visible gap below the subtitle as their search rows do.
	var title_subtitle_gap := 6.0
	var subtitle_content_gap := 34.0

	_title.position = Vector2(x, y)
	_title.size = Vector2(usable_w, ceil(_title.get_combined_minimum_size().y))

	_subtitle.text = "Learn how to use multiple game functions!"
	_subtitle.visible = true
	_subtitle.modulate.a = 1.0
	_subtitle.add_theme_font_size_override("font_size", 52)
	_subtitle.add_theme_color_override("font_color", COLOR_SUBTITLE)
	_subtitle.z_index = 10
	_subtitle.position = Vector2(x, _title.position.y + _title.size.y + title_subtitle_gap)
	_subtitle.size = Vector2(usable_w, ceil(_subtitle.get_combined_minimum_size().y))

	y = _subtitle.position.y + _subtitle.size.y + subtitle_content_gap

	# The separator line is intentionally removed; the cards themselves define the sections.
	var dots_h := 58.0
	var bottom_padding := float(panel_padding_y) + dots_h + 18.0
	var page_h: float = max(430.0, h - y - bottom_padding)
	var card_w: float = min(usable_w * 0.88, 980.0)
	var card_x: float = x + (usable_w - card_w) * 0.5

	_page_holder.position = Vector2(card_x, y)
	_page_holder.size = Vector2(card_w, page_h)
	_page_holder.custom_minimum_size = _page_holder.size

	_layout_tutorial_cards()
	_snap_to_current_page(false)

	y += page_h + 18
	_dots.position = Vector2(x, y)
	_dots.size = Vector2(usable_w, dots_h)

func _build_tutorial_cards() -> void:
	if not is_instance_valid(_page_row):
		return
	for child in _page_row.get_children():
		child.queue_free()
	for i in range(_pages.size()):
		var page: Dictionary = _pages[i]
		var card := PanelContainer.new()
		card.name = "TutorialCard%d" % i
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_theme_stylebox_override("panel", _page_style())
		card.add_child(_make_tutorial_card_content(page, i))
		_page_row.add_child(card)


func _make_tutorial_card_content(page: Dictionary, index: int) -> Control:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)

	var root_box := VBoxContainer.new()
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root_box.add_theme_constant_override("separation", 8)
	margin.add_child(root_box)

	var step_label := _make_label("STEP %s" % str(page.get("step", "%02d" % (index + 1))), 32, COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_child(step_label)

	var title_label := _make_label(str(page.get("title", "TUTORIAL")), 76, COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.clip_text = false
	root_box.add_child(title_label)

	return margin

func _make_tutorial_visual(index: int, page: Dictionary) -> Control:
	match index:
		0:
			return _make_orbit_demo_visual()
		1:
			return _make_role_demo_visual()
		2:
			return _make_progress_demo_visual()
		3:
			return _make_planet_card_demo_visual()
		4:
			return _make_search_demo_visual()
		5:
			return _make_achievement_demo_visual()
		6:
			return _make_console_demo_visual()
		7:
			return _make_ai_demo_visual()
		_:
			return _make_visual_panel(str(page.get("icon", "*")), page.get("chips", []))


func _make_demo_panel(min_height: float = 172.0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, min_height)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _visual_style())
	return panel


func _make_orbit_demo_visual() -> Control:
	var panel := _make_demo_panel(184.0)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var orbit_stack := VBoxContainer.new()
	orbit_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	orbit_stack.add_theme_constant_override("separation", 8)
	box.add_child(orbit_stack)

	for radius in [220, 170, 118]:
		var ring := PanelContainer.new()
		ring.custom_minimum_size = Vector2(radius, 20)
		ring.add_theme_stylebox_override("panel", _thin_orbit_style())
		orbit_stack.add_child(ring)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for size in [42, 22, 30, 18]:
		row.add_child(_make_demo_dot(size, _theme_accent_color() if size == 42 else Color.WHITE))
	return panel


func _make_role_demo_visual() -> Control:
	var panel := _make_demo_panel(172.0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	row.add_child(_make_mini_card("CREATE", "add bodies"))
	row.add_child(_make_mini_arrow())
	row.add_child(_make_mini_card("TEST", "drag + throw"))
	row.add_child(_make_mini_arrow())
	row.add_child(_make_mini_card("LEARN", "unlock data"))
	return panel


func _make_progress_demo_visual() -> Control:
	var panel := _make_demo_panel(178.0)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(_make_progress_row("PLANET CARD", 0.74, "LVL 7"))
	box.add_child(_make_progress_row("ACHIEVEMENT", 0.42, "SILVER"))
	box.add_child(_make_progress_row("DISCOVERY", 0.18, "NEW"))
	return panel


func _make_planet_card_demo_visual() -> Control:
	var panel := _make_demo_panel(184.0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	for i in range(3):
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(150, 130)
		card.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_theme_constant_override("separation", 8)
		card.add_child(_make_demo_dot(48 - i * 6, _theme_accent_color().lerp(Color.WHITE, float(i) * 0.20)))
		card.add_child(_make_label(["TERRA", "NYX", "SOL"][i], 24, COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(_wrap_demo_card(card))
	return panel


func _make_search_demo_visual() -> Control:
	var panel := _make_demo_panel(172.0)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	box.add_child(_make_fake_search_bar(">type:star  ringed"))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for txt in ["STAR", "RINGED", "MATCH"]:
		row.add_child(_make_chip(txt))
	return panel


func _make_achievement_demo_visual() -> Control:
	var panel := _make_demo_panel(184.0)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(_make_achievement_row("BRONZE", 0.33))
	box.add_child(_make_achievement_row("SILVER", 0.66))
	box.add_child(_make_achievement_row("GOLD", 1.0))
	return panel


func _make_console_demo_visual() -> Control:
	var panel := _make_demo_panel(178.0)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	box.add_child(tabs)
	for txt in ["DATA", "BEHAVIOUR", "COMMANDS"]:
		tabs.add_child(_make_chip(txt))
	box.add_child(_make_progress_row("TIME MULTIPLIER", 0.62, "12.5x"))
	box.add_child(_make_progress_row("ORBIT SPEED", 0.62, "12.5x"))
	return panel


func _make_ai_demo_visual() -> Control:
	var panel := _make_demo_panel(178.0)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var dots := HBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 10)
	box.add_child(dots)
	for size in [22, 32, 22]:
		dots.add_child(_make_demo_dot(size, _theme_accent_color()))
	box.add_child(_make_fake_search_bar("Apollo, open achievements"))
	var chip_row := HBoxContainer.new()
	chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chip_row.add_theme_constant_override("separation", 8)
	box.add_child(chip_row)
	for txt in ["VOICE", "ACTION", "NAV"]:
		chip_row.add_child(_make_chip(txt))
	return panel


func _make_demo_dot(size: int, color: Color) -> Control:
	var dot := PanelContainer.new()
	dot.custom_minimum_size = Vector2(size, size)
	dot.add_theme_stylebox_override("panel", _dot_style_with_color(color))
	return dot


func _make_mini_arrow() -> Label:
	return _make_label("→", 34, COLOR_SUBTITLE, HORIZONTAL_ALIGNMENT_CENTER)


func _make_mini_card(title: String, subtitle: String) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(150, 92)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 2)
	card.add_child(_make_label(title, 26, COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	card.add_child(_make_label(subtitle, 20, COLOR_SUBTITLE, HORIZONTAL_ALIGNMENT_CENTER))
	return _wrap_demo_card(card)


func _wrap_demo_card(content: Control) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _mini_card_style())
	panel.add_child(content)
	return panel


func _make_progress_row(label_text: String, progress: float, value_text: String) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var label := _make_label(label_text, 24, COLOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	label.custom_minimum_size = Vector2(230, 34)
	row.add_child(label)
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(260, 24)
	bar.add_theme_stylebox_override("panel", _progress_bg_style())
	var fill := ColorRect.new()
	fill.color = _theme_accent_color()
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(progress, 0.0, 1.0)
	bar.add_child(fill)
	row.add_child(bar)
	row.add_child(_make_label(value_text, 24, COLOR_SUBTITLE, HORIZONTAL_ALIGNMENT_LEFT))
	return row


func _make_achievement_row(rank: String, progress: float) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.add_child(_make_demo_dot(28, _theme_accent_color() if rank == "GOLD" else Color.WHITE))
	row.add_child(_make_progress_row(rank, progress, "%d%%" % int(round(progress * 100.0))))
	return row


func _make_fake_search_bar(text: String) -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 62)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("panel", _search_demo_style())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)
	row.add_child(_make_label("⌕", 30, COLOR_SUBTITLE, HORIZONTAL_ALIGNMENT_CENTER))
	var label := _make_label(text + " |", 30, COLOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(_make_label("×", 34, COLOR_SUBTITLE, HORIZONTAL_ALIGNMENT_CENTER))
	return bar


func _thin_orbit_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.0)
	style.border_color = Color(1, 1, 1, 0.22)
	style.set_border_width_all(2)
	style.set_corner_radius_all(100)
	return style


func _mini_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.38)
	style.border_color = Color(1, 1, 1, 0.24)
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _progress_bg_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.09)
	style.border_color = Color.WHITE
	style.set_border_width_all(2)
	style.set_corner_radius_all(100)
	return style


func _search_demo_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.34)
	style.border_color = Color(1, 1, 1, 0.28)
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _layout_tutorial_cards() -> void:
	if not is_instance_valid(_page_holder) or not is_instance_valid(_page_row):
		return
	_page_row.add_theme_constant_override("separation", int(_card_gap))
	var card_size := _page_holder.size
	for child in _page_row.get_children():
		if child is Control:
			var card := child as Control
			card.custom_minimum_size = card_size
			card.size = card_size
	_page_row.size = Vector2(card_size.x * float(_pages.size()) + _card_gap * float(max(0, _pages.size() - 1)), card_size.y)
	_update_card_scales()


func _on_body_input(event: InputEvent) -> void:
	if _closing:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and _is_scrollwheel_button(mb.button_index):
			_on_page_input(event)
			return
	elif event is InputEventPanGesture:
		_on_page_input(event)
		return


func _is_scrollwheel_button(button_index: int) -> bool:
	return button_index == MOUSE_BUTTON_WHEEL_UP \
		or button_index == MOUSE_BUTTON_WHEEL_DOWN \
		or button_index == MOUSE_BUTTON_WHEEL_LEFT \
		or button_index == MOUSE_BUTTON_WHEEL_RIGHT


func _is_point_inside_page_holder(global_position: Vector2) -> bool:
	if not is_instance_valid(_page_holder):
		return false
	return _page_holder.get_global_rect().has_point(global_position)


func _on_page_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_page_drag(touch.position, touch.index)
		elif _dragging and (_drag_pointer_id == touch.index or _drag_pointer_id == -999):
			_end_page_drag(touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _dragging and (_drag_pointer_id == drag.index or _drag_pointer_id == -999):
			_update_page_drag(drag.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed and _is_scrollwheel_button(mouse_button.button_index):
			if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP or mouse_button.button_index == MOUSE_BUTTON_WHEEL_LEFT:
				_go_page(-1)
			else:
				_go_page(1)
			get_viewport().set_input_as_handled()
		elif mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_begin_page_drag(mouse_button.position, -2)
			elif _dragging:
				_end_page_drag(mouse_button.position)
	elif event is InputEventMouseMotion and _dragging:
		_update_page_drag((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		var pan := event as InputEventPanGesture
		if abs(pan.delta.x) >= abs(pan.delta.y) and abs(pan.delta.x) > 0.5:
			_go_page(1 if pan.delta.x > 0.0 else -1)
			get_viewport().set_input_as_handled()
		elif abs(pan.delta.y) > 0.5:
			_go_page(1 if pan.delta.y > 0.0 else -1)
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if _closing or not is_instance_valid(_page_holder):
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and _is_scrollwheel_button(mb.button_index) and _panel.get_global_rect().has_point(mb.global_position):
			_on_page_input(event)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _is_point_inside_page_holder(mb.global_position):
				_begin_page_drag(mb.global_position, -2)
				get_viewport().set_input_as_handled()
			elif _dragging and _drag_pointer_id == -2:
				_end_page_drag(mb.global_position)
	elif event is InputEventMouseMotion and _dragging and _drag_pointer_id == -2:
		_update_page_drag((event as InputEventMouseMotion).global_position)
		get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		_on_page_input(event)


func _begin_page_drag(pointer_position: Vector2, pointer_id: int) -> void:
	_dragging = true
	_drag_pointer_id = pointer_id
	_drag_start = pointer_position
	_drag_start_row_x = _page_row.position.x if is_instance_valid(_page_row) else 0.0
	if _page_tween != null and _page_tween.is_valid():
		_page_tween.kill()


func _update_page_drag(pointer_position: Vector2) -> void:
	if not is_instance_valid(_page_holder) or not is_instance_valid(_page_row):
		return
	var delta_x := pointer_position.x - _drag_start.x
	var span := _page_span()
	if span <= 0.0:
		return
	# Flutter-like edge resistance: you can pull a little past the ends,
	# but it never loops to the opposite side anymore.
	var target_x := _drag_start_row_x + delta_x
	var min_x := -span * float(_pages.size() - 1)
	if target_x > 0.0:
		target_x *= 0.38
	elif target_x < min_x:
		target_x = min_x + (target_x - min_x) * 0.38
	_page_row.position.x = target_x
	_update_card_scales()


func _end_page_drag(pointer_position: Vector2) -> void:
	var delta_x := pointer_position.x - _drag_start.x
	_dragging = false
	_drag_pointer_id = -999
	var threshold = max(70.0, _page_holder.size.x * 0.16) if is_instance_valid(_page_holder) else 70.0
	if abs(delta_x) >= threshold:
		_go_page(-1 if delta_x > 0.0 else 1)
	else:
		_snap_to_current_page(true)
	get_viewport().set_input_as_handled()


func _go_page(delta: int) -> void:
	if _pages.is_empty():
		return
	var next_page: int = clampi(_current_page + delta, 0, _pages.size() - 1)
	if next_page == _current_page:
		_snap_to_current_page(true)
		return
	_current_page = next_page
	_play_sfx("click")
	_snap_to_current_page(true)
	_update_page_dots()


func _page_span() -> float:
	if not is_instance_valid(_page_holder):
		return 0.0
	return _page_holder.size.x + _card_gap


func _snap_to_current_page(animated: bool = true) -> void:
	if not is_instance_valid(_page_row):
		return
	var target_x := -_page_span() * float(_current_page)
	if _page_tween != null and _page_tween.is_valid():
		_page_tween.kill()
	if reduce_motion_enabled or not animated:
		_page_row.position = Vector2(target_x, 0.0)
		_update_card_scales()
		return
	var start_x := _page_row.position.x
	_page_tween = create_tween()
	_page_tween.tween_method(func(x_pos: float) -> void:
		_page_row.position.x = x_pos
		_update_card_scales()
	, start_x, target_x, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _update_card_scales() -> void:
	if not is_instance_valid(_page_row):
		return
	var span := _page_span()
	if span <= 0.0:
		return
	var virtual_page := -_page_row.position.x / span
	for i in range(_page_row.get_child_count()):
		var card := _page_row.get_child(i) as Control
		if card == null:
			continue
		var distance = min(abs(float(i) - virtual_page), 1.0)
		var scale_factor = lerpf(1.0, 0.78, distance)
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(scale_factor, scale_factor)
		card.modulate.a = lerpf(1.0, 0.62, distance)
		card.z_index = int(round((1.0 - distance) * 10.0))


func _update_page_dots() -> void:
	if not is_instance_valid(_dots):
		return
	var accent := _theme_accent_color()
	for i in range(_dots.get_child_count()):
		var dot := _dots.get_child(i) as Control
		if dot == null:
			continue
		var active := i == _current_page
		var target_size := Vector2(34, 34) if active else Vector2(24, 24)
		var target_color := accent if active else Color.WHITE
		if reduce_motion_enabled or not is_inside_tree():
			dot.custom_minimum_size = target_size
			dot.add_theme_stylebox_override("panel", _dot_style_with_color(target_color))
			dot.set_meta("dot_color", target_color)
			continue
		var from_color: Color = dot.get_meta("dot_color", Color.WHITE)
		dot.set_meta("dot_color", target_color)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(dot, "custom_minimum_size", target_size, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_method(func(c: Color) -> void:
			dot.add_theme_stylebox_override("panel", _dot_style_with_color(c))
		, from_color, target_color, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _render_page(_direction: int = 0) -> void:
	# Kept as a compatibility wrapper for older callers.
	_snap_to_current_page(true)
	_update_page_dots()


func _animate_page_card(_direction: int) -> void:
	pass

func _prepare_center_position() -> void:
	if get_viewport() == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width: float = min(viewport_size.x * panel_width_ratio, panel_max_width)
	var panel_height: float = min(viewport_size.y * panel_height_ratio, panel_max_height)
	_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	_panel.size = Vector2(panel_width, panel_height)
	_body.size = _panel.size
	_slide_root.custom_minimum_size = _panel.size
	_slide_root.size = _panel.size
	_center_position = Vector2((viewport_size.x - _slide_root.size.x) * 0.5, (viewport_size.y - _slide_root.size.y) * 0.5)
	_slide_root.position = _center_position
	_panel.position = Vector2.ZERO

func _play_intro() -> void:
	_play_sfx("open")
	_prepare_center_position()
	_layout_content()
	if reduce_motion_enabled:
		_slide_root.position = _center_position
		_slide_root.modulate.a = 1.0
		_dim.modulate.a = 1.0
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

func close_popup() -> void:
	if _closing:
		return
	_closing = true
	_play_sfx("close")
	if _popup_tween:
		_popup_tween.kill()
	if reduce_motion_enabled or not is_inside_tree():
		closed.emit()
		queue_free()
		return
	_popup_tween = create_tween()
	_popup_tween.set_parallel(true)
	_popup_tween.tween_property(_slide_root, "position", _get_right_offscreen_position(), POPUP_SLIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_popup_tween.tween_property(_slide_root, "modulate:a", 0.0, POPUP_FADE_DURATION).set_delay(max(0.0, POPUP_SLIDE_DURATION - POPUP_FADE_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_popup_tween.tween_property(_dim, "modulate:a", 0.0, DIM_FADE_DURATION).set_delay(max(0.0, POPUP_SLIDE_DURATION - DIM_FADE_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _popup_tween.finished
	closed.emit()
	queue_free()

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		call_deferred("_on_safe_resize")

func _on_safe_resize() -> void:
	if is_inside_tree() and not _closing:
		_prepare_center_position()
		_layout_content()

func _get_left_offscreen_position() -> Vector2:
	return Vector2(-_slide_root.size.x - POPUP_SIDE_PADDING, _center_position.y)

func _get_right_offscreen_position() -> Vector2:
	var viewport_width := _center_position.x + _slide_root.size.x + POPUP_SIDE_PADDING
	if get_viewport() != null:
		viewport_width = get_viewport().get_visible_rect().size.x
	return Vector2(viewport_width + POPUP_SIDE_PADDING, _center_position.y)

func _make_label(text: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_apply_app_font(label)
	return label

func _make_nav_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.add_theme_font_size_override("font_size", 48)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_color_override("font_hover_color", COLOR_TEXT)
	b.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	b.add_theme_stylebox_override("normal", _button_style(Color(0,0,0,0.30)))
	b.add_theme_stylebox_override("hover", _button_style(Color(1,1,1,0.06)))
	b.add_theme_stylebox_override("pressed", _button_style(Color(1,1,1,0.10)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_apply_app_font(b)
	return b

func _make_icon_badge(icon_text: String, step: String) -> Control:
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(116, 116)
	badge.add_theme_stylebox_override("panel", _badge_style())
	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	badge.add_child(center)
	center.add_child(_make_label(icon_text, 48, _theme_accent_color(), HORIZONTAL_ALIGNMENT_CENTER))
	center.add_child(_make_label(step, 22, COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	return badge

func _make_visual_panel(icon_text: String, chips: Array) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 150)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _visual_style())
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var orbit_row := HBoxContainer.new()
	orbit_row.alignment = BoxContainer.ALIGNMENT_CENTER
	orbit_row.add_theme_constant_override("separation", 14)
	box.add_child(orbit_row)
	for i in range(5):
		var orb := PanelContainer.new()
		var size := 26 + i * 10
		orb.custom_minimum_size = Vector2(size, size)
		orb.add_theme_stylebox_override("panel", _orb_style(i))
		orbit_row.add_child(orb)
	var chip_row := HBoxContainer.new()
	chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chip_row.add_theme_constant_override("separation", 8)
	box.add_child(chip_row)
	for chip in chips:
		chip_row.add_child(_make_chip(str(chip)))
	return panel

func _make_bullet(text: String) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	row.add_child(_make_label("•", 34, _theme_accent_color(), HORIZONTAL_ALIGNMENT_LEFT))
	var label := _make_label(text, 30, COLOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	return row

func _make_chip(text: String) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", _chip_style())
	chip.add_child(_make_label(text, 22, COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	return chip

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _theme_panel_color()
	style.border_color = COLOR_BORDER
	style.set_border_width_all(5)
	style.set_corner_radius_all(44)
	style.shadow_color = Color(0, 0, 0, 0.64)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 6)
	return style

func _page_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.84)
	style.border_color = COLOR_BORDER
	style.set_border_width_all(5)
	style.set_corner_radius_all(38)
	style.shadow_color = Color(0, 0, 0, 0.62)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 6)
	return style

func _badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.055)
	style.border_color = _theme_accent_color()
	style.set_border_width_all(4)
	style.set_corner_radius_all(42)
	return style

func _visual_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.22)
	style.border_color = Color(1, 1, 1, 0.10)
	style.set_border_width_all(2)
	style.set_corner_radius_all(26)
	return style

func _chip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.08)
	style.border_color = Color(1, 1, 1, 0.16)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _orb_style(index: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _theme_accent_color().lerp(Color.WHITE, float(index) * 0.12)
	style.border_color = Color.WHITE
	style.set_border_width_all(2)
	style.set_corner_radius_all(100)
	return style

func _dot_style(active: bool) -> StyleBoxFlat:
	return _dot_style_with_color(_theme_accent_color() if active else Color.WHITE)

func _dot_style_with_color(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color
	style.set_border_width_all(0)
	style.set_corner_radius_all(100)
	return style

func _button_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(1, 1, 1, 0.52)
	style.set_border_width_all(3)
	style.set_corner_radius_all(24)
	return style

func _theme_panel_color() -> Color:
	return COLOR_PANEL

func _theme_text_color() -> Color:
	return COLOR_TEXT

func _theme_accent_color() -> Color:
	if _settings_node != null and _settings_node.has_method("get_accent_color"):
		return _settings_node.call("get_accent_color")
	return COLOR_HIGHLIGHT

func _apply_app_font(control: Control) -> void:
	if _app_font != null:
		control.add_theme_font_override("font", _app_font)

func _play_sfx(name: String) -> void:
	if _sfx_node != null and _sfx_node.has_method("play"):
		_sfx_node.call("play", name)

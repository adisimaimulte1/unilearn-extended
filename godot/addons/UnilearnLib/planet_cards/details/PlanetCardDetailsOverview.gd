extends "res://addons/UnilearnLib/planet_cards/details/PlanetCardDetailsBase.gd"

func _add_learning_deck() -> void:
	var deck := PanelContainer.new()
	deck.name = "LearningDeck"
	deck.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck.mouse_filter = Control.MOUSE_FILTER_PASS
	deck.add_theme_stylebox_override("panel", _panel_style(42, _panel_color(), _line_color(), 3))
	_content.add_child(deck)

	var margin := _panel_margin(deck, 24, 24, 24, 30)

	var box := VBoxContainer.new()
	box.name = "LearningDeckContent"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 32)
	margin.add_child(box)

	_add_deck_intro(box)
	_add_tab_selector(box)

	_details_stack = VBoxContainer.new()
	_details_stack.name = "DetailsTabStack"
	_details_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	_details_stack.add_theme_constant_override("separation", 30)
	box.add_child(_details_stack)

	_set_details_tab(_selected_tab)

func _add_deck_intro(parent: VBoxContainer) -> void:
	var top := VBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_PASS
	top.add_theme_constant_override("separation", 14)
	parent.add_child(top)

	top.add_child(_make_label(_guide_label(), 38, _accent_color(), HORIZONTAL_ALIGNMENT_LEFT, false))

	var subtitle_holder := Control.new()
	subtitle_holder.name = "SubtitleHolder"
	subtitle_holder.custom_minimum_size = Vector2(0, 92)
	subtitle_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(subtitle_holder)

	var subtitle := _make_fit_label(
		data.subtitle,
		58,
		24,
		_text_color(),
		HORIZONTAL_ALIGNMENT_LEFT
	)
	subtitle_holder.add_child(subtitle)

	var underline := ColorRect.new()
	underline.name = "SubtitleUnderline"
	underline.custom_minimum_size = Vector2(0, 6)
	underline.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	underline.color = Color.WHITE
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(underline)

	subtitle_holder.resized.connect(func() -> void:
		_layout_subtitle_and_underline(subtitle_holder, subtitle, underline)
	)

	call_deferred("_layout_subtitle_and_underline", subtitle_holder, subtitle, underline)

	top.add_child(_make_label(_make_intro_hint(), 42, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true))


func _layout_subtitle_and_underline(holder: Control, label: Label, underline: ColorRect) -> void:
	if not is_instance_valid(holder) or not is_instance_valid(label) or not is_instance_valid(underline):
		return

	var target_width := max(holder.size.x * 0.90, 1.0)

	label.position = Vector2.ZERO
	label.size = Vector2(target_width, holder.size.y)
	label.custom_minimum_size = Vector2.ZERO

	var fitted_font_size := _fit_label_font_size(label, 58, 24)
	var text_width := min(_get_text_width(label.text, fitted_font_size), target_width)

	underline.custom_minimum_size = Vector2(text_width, 6)
	underline.size = Vector2(text_width, 6)


func _make_fit_label(
	value: String,
	max_font_size: int,
	min_font_size: int,
	color: Color,
	alignment: HorizontalAlignment
) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_FILL
	label.custom_minimum_size = Vector2.ZERO
	label.add_theme_color_override("font_color", color)
	_apply_app_font(label)

	label.resized.connect(func() -> void:
		_fit_label_font_size(label, max_font_size, min_font_size)
	)

	call_deferred("_fit_label_font_size", label, max_font_size, min_font_size)

	return label


func _layout_fit_label_percent(
	holder: Control,
	label: Label,
	width_percent: float,
	max_font_size: int,
	min_font_size: int
) -> void:
	if not is_instance_valid(holder) or not is_instance_valid(label):
		return

	var target_width := max(holder.size.x * width_percent, 1.0)

	label.position = Vector2.ZERO
	label.size = Vector2(target_width, holder.size.y)
	label.custom_minimum_size = Vector2.ZERO

	_fit_label_font_size(label, max_font_size, min_font_size)


func _fit_label_font_size(label: Label, max_font_size: int, min_font_size: int) -> int:
	if not is_instance_valid(label):
		return min_font_size

	var available_width := max(label.size.x, 1.0)
	var font_size := max_font_size

	while font_size > min_font_size:
		if _get_text_width(label.text, font_size) <= available_width:
			break

		font_size -= 1

	label.add_theme_font_size_override("font_size", font_size)
	return font_size


func _is_singularity_card() -> bool:
	if data == null:
		return false

	var category := _object_category()
	var preset := data.planet_preset.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	var archetype := data.archetype_id.strip_edges().to_lower().replace(" ", "_").replace("-", "_")

	return category == "singularity" or category == "black_hole" or category == "white_hole" or preset == "black_hole" or preset == "white_hole" or archetype == "black_hole" or archetype == "white_hole"


func _singularity_disk_value() -> String:
	if data == null:
		return "None"

	var preset := data.planet_preset.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	if preset == "white_hole":
		return "None"

	if data.singularity_has_disk == false:
		return "None"

	for card in data.data_cards:
		var title := str(card.get("title", "")).strip_edges().to_lower()
		if title == "disk":
			var value := str(card.get("value", "")).strip_edges().to_lower()
			if value == "none" or value == "no" or value == "no disk" or value == "unknown" or value == "not observed":
				return "None"
			return "Accretion disk"

	return "Accretion disk"


func _singularity_type_value() -> String:
	if data == null:
		return "Singularity"

	var preset := data.planet_preset.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	if preset == "white_hole":
		return "White hole"
	if preset == "black_hole":
		return "Black hole"

	if not data.subtitle.strip_edges().is_empty():
		return data.subtitle

	return data.archetype_id.replace("_", " ").capitalize()


func _normalized_singularity_data_items() -> Array[Dictionary]:
	var base := _singularity_data_items()

	if data == null or data.data_cards.is_empty():
		return base

	var by_title := {}
	for card in data.data_cards:
		var title := str(card.get("title", "")).strip_edges().to_lower()
		if not title.is_empty():
			by_title[title] = str(card.get("value", ""))

	for i in range(base.size()):
		var title := str(base[i].get("title", "")).strip_edges().to_lower()
		if title == "disk":
			base[i]["value"] = _singularity_disk_value()
		elif by_title.has(title):
			base[i]["value"] = by_title[title]

	return base


func _singularity_data_items() -> Array[Dictionary]:
	return [
		{"title": "Type", "value": _singularity_type_value()},
		{"title": "Horizon", "value": "White horizon" if data.planet_preset.strip_edges().to_lower().replace(" ", "_").replace("-", "_") == "white_hole" else "Event horizon"},
		{"title": "Mass", "value": data.mass},
		{"title": "Diameter", "value": data.diameter_km},
		{"title": "Gravity", "value": data.gravity},
		{"title": "Disk", "value": _singularity_disk_value()},
		{"title": "Radiation", "value": _value_or_unknown(data.magnetic_field)},
		{"title": "Status", "value": _value_or_unknown(data.habitability_note)},
	]


func _guide_label() -> String:
	var category := _object_category()

	if _is_singularity_card():
		return "SINGULARITY FIELD GUIDE"

	match category:
		"star":
			return "STELLAR FIELD GUIDE"

		"satellite", "moon":
			return "SATELLITE FIELD GUIDE"

		"dwarf_planet":
			return "DWARF WORLD FIELD GUIDE"

		_:
			return "PLANET FIELD GUIDE"


func _make_intro_hint() -> String:
	if _is_singularity_card():
		return "SINGULARITY DATA"

	match _object_category():
		"star":
			return "Study %s as a stellar engine: how it produces energy, shapes nearby orbits, and controls the environment around it." % data.name

		"satellite", "moon":
			return "Study %s as a natural satellite: its parent body, surface story, orbital behavior, and what it reveals about its local system." % data.name

		"dwarf_planet":
			return "Study %s as a small planetary world: its orbit, surface chemistry, formation clues, and why it matters beyond the major planets." % data.name

		_:
			if data.archetype_id.contains("gas") or data.archetype_id.contains("ice"):
				return "Study %s as a giant world: its atmosphere, deep interior, rings or moons, and the forces that shape its system." % data.name

			return "Study %s as a planetary world: its surface, atmosphere, rotation, environment, and the clues it gives about planet formation." % data.name


func _add_tab_selector(parent: VBoxContainer) -> void:
	_details_tab_buttons.clear()

	var rail := HBoxContainer.new()
	rail.name = "DetailsTabSelector"
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.mouse_filter = Control.MOUSE_FILTER_PASS
	rail.add_theme_constant_override("separation", 14)
	parent.add_child(rail)

	_add_tab_button(rail, TAB_OVERVIEW, "PREVIEW")
	_add_tab_button(rail, TAB_DATA, "DATA")
	_add_tab_button(rail, TAB_DISCOVERIES, "DISCOVER")
	_add_tab_button(rail, TAB_TRAINING, "GAME")

func _add_tab_button(parent: HBoxContainer, tab_id: String, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.custom_minimum_size = Vector2(0, 96)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 38)
	_apply_app_font(button)

	button.button_down.connect(func() -> void:
		_on_header_button_down(button)
	)

	button.button_up.connect(func() -> void:
		_tween_header_button_cancel(button)
	)

	button.pressed.connect(func() -> void:
		_on_header_button_up(button)
		_set_details_tab(tab_id)
	)

	parent.add_child(button)
	_details_tab_buttons[tab_id] = button


func _set_details_tab(tab_id: String) -> void:
	_selected_tab = tab_id
	_update_tab_button_styles()

	if not is_instance_valid(_details_stack):
		return

	for child in _details_stack.get_children():
		child.queue_free()

	if tab_id == TAB_DATA:
		_build_data_tab(_details_stack)
	elif tab_id == TAB_DISCOVERIES:
		_build_discoveries_tab(_details_stack)
	elif tab_id == TAB_TRAINING:
		_build_training_tab(_details_stack)
	else:
		_build_overview_tab(_details_stack)

	if is_instance_valid(_scroll):
		_scroll_velocity = 0.0

func _update_tab_button_styles() -> void:
	for tab_id in _details_tab_buttons.keys():
		var button: Button = _details_tab_buttons[tab_id]

		if not is_instance_valid(button):
			continue

		var selected: int = tab_id == _selected_tab
		var font_color := Color.BLACK if selected else Color.WHITE

		button.add_theme_color_override("font_color", font_color)
		button.add_theme_color_override("font_hover_color", button.get_theme_color("font_color"))
		button.add_theme_color_override("font_pressed_color", button.get_theme_color("font_color"))
		button.add_theme_stylebox_override("normal", _tab_button_style(selected, false))
		button.add_theme_stylebox_override("hover", button.get_theme_stylebox("normal"))
		button.add_theme_stylebox_override("pressed", button.get_theme_stylebox("normal"))


func _build_overview_tab(parent: VBoxContainer) -> void:
	_add_highlight_description(parent)
	_add_overview_points(parent)
	_add_fact()

func _build_data_tab(parent: VBoxContainer) -> void:
	_add_stats_grid()
	_add_environment_block(parent)

func _build_discoveries_tab(parent: VBoxContainer) -> void:
	_add_features()
	_add_missions_block(parent)

func _build_training_tab(parent: VBoxContainer) -> void:
	_add_game_stats_section(parent)


func _add_highlight_description(parent: VBoxContainer) -> void:
	var panel := _make_panel(_soft_panel_color(), _accent_color(), 0)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 24)
	_panel_margin(panel, 36, 34, 36, 38).add_child(box)

	box.add_child(_section_title("FIRST LOOK"))

	var rich := RichTextLabel.new()
	rich.name = "HighlightedDescription"
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.selection_enabled = false
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.add_theme_font_size_override("normal_font_size", 54)
	rich.add_theme_color_override("default_color", _text_color())
	_apply_app_font(rich)
	rich.text = _build_highlighted_description_bbcode()
	box.add_child(rich)

	var beam := ColorRect.new()
	beam.custom_minimum_size = Vector2(0, 6)
	beam.color = Color.WHITE
	beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(beam)

func _add_overview_points(parent: VBoxContainer) -> void:
	var points := data.overview_points

	if points.is_empty():
		points = _fallback_overview_points()

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	parent.add_child(grid)

	for point in points:
		_add_overview_card(grid, str(point.get("title", "")), str(point.get("text", "")))

func _add_overview_card(parent: GridContainer, title: String, text: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 190)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(
			30,
			Color.TRANSPARENT,
			Color.WHITE,
			3
		)
	)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 10)
	_panel_margin(panel, 24, 22, 24, 22).add_child(box)

	box.add_child(_make_label(title.to_upper(), 34, _accent_color(), HORIZONTAL_ALIGNMENT_LEFT, true))
	box.add_child(_make_label(text, 44, _text_color(), HORIZONTAL_ALIGNMENT_LEFT, true))

func _add_stats_grid() -> void:
	var parent := _details_stack if is_instance_valid(_details_stack) else _content

	var panel := _make_panel(Color.BLACK, Color.WHITE, 3)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 30)
	_panel_margin(panel, 30, 30, 30, 34).add_child(box)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_PASS
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 18)
	box.add_child(title_row)

	var title := _section_title(_data_section_title())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var tag := _make_label(_object_category().replace("_", " ").to_upper(), 34, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	tag.custom_minimum_size = Vector2(230, 72)

	var tag_panel := PanelContainer.new()
	tag_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	tag_panel.add_theme_stylebox_override("panel", _panel_style(22, Color.WHITE, Color.WHITE, 0))
	title_row.add_child(tag_panel)
	_panel_margin(tag_panel, 18, 8, 18, 8).add_child(tag)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	box.add_child(grid)

	var items := _data_items()

	for i in range(items.size()):
		var item: Dictionary = items[i]
		_add_stat_item(grid, str(item.get("title", "")), str(item.get("value", "")), i)
	

func _data_section_title() -> String:
	if _is_singularity_card():
		return "SINGULARITY DATA"

	match _object_category():
		"star":
			return "STELLAR DATA"

		"satellite", "moon":
			return "SATELLITE DATA"

		"dwarf_planet":
			return "DWARF WORLD DATA"

		_:
			return "PLANET DATA"

func _data_items() -> Array[Dictionary]:
	if _is_singularity_card():
		return _normalized_singularity_data_items()

	if not data.data_cards.is_empty():
		return data.data_cards

	match _object_category():
		"star":
			return [
				{"title": "Diameter", "value": data.diameter_km},
				{"title": "Mass", "value": data.mass},
				{"title": "Rotation", "value": data.rotation_period},
				{"title": "Temperature", "value": data.average_temperature},
				{"title": "Planets", "value": data.moons},
				{"title": "Galactic orbit", "value": data.orbital_period},
			]

		"satellite", "moon":
			return [
				{"title": "Parent", "value": _value_or_unknown(data.parent_object)},
				{"title": "Diameter", "value": data.diameter_km},
				{"title": "Mass", "value": data.mass},
				{"title": "Gravity", "value": data.gravity},
				{"title": "Orbit", "value": data.orbital_period},
				{"title": "Rotation", "value": data.rotation_period},
				{"title": "Avg temp", "value": data.average_temperature},
				{"title": "Surface", "value": _value_or_unknown(data.surface_geology)},
			]

		_:
			return [
				{"title": "Diameter", "value": data.diameter_km},
				{"title": "Mass", "value": data.mass},
				{"title": "Gravity", "value": data.gravity},
				{"title": "Rotation", "value": data.rotation_period},
				{"title": "Orbit", "value": data.orbital_period},
				{"title": _satellite_field_title(), "value": data.moons},
			]


func _add_environment_block(parent: VBoxContainer) -> void:
	var panel := _make_panel(Color.BLACK, Color.WHITE, 3)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 28)
	_panel_margin(panel, 34, 34, 34, 36).add_child(box)

	box.add_child(_section_title("ENVIRONMENT PROFILE"))

	var intro := _make_label(
		"Physical context, structure, and conditions that explain what this object is like beyond the raw numbers.",
		42,
		Color.WHITE,
		HORIZONTAL_ALIGNMENT_LEFT,
		true
	)
	box.add_child(intro)

	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 5)
	line.color = Color.WHITE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)

	var items := _environment_items()

	for item in items:
		_add_environment_item(box, str(item.get("title", "")), str(item.get("text", "")))

func _add_environment_item(parent: VBoxContainer, title: String, text: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", _panel_style(26, Color(0.0, 0.0, 0.0, 0.24), Color.WHITE, 2))
	parent.add_child(panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 22)
	_panel_margin(panel, 24, 22, 24, 24).add_child(row)

	var number_block := PanelContainer.new()
	number_block.custom_minimum_size = Vector2(96, 96)
	number_block.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	number_block.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	number_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number_block.add_theme_stylebox_override("panel", _panel_style(24, Color.WHITE, Color.WHITE, 0))
	row.add_child(number_block)

	var short := title.substr(0, 1).to_upper()
	var letter := _make_label(short, 52, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	_panel_margin(number_block, 0, 0, 0, 0).add_child(letter)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.mouse_filter = Control.MOUSE_FILTER_PASS
	text_box.add_theme_constant_override("separation", 8)
	row.add_child(text_box)

	text_box.add_child(_make_label(title.to_upper(), 36, _accent_color(), HORIZONTAL_ALIGNMENT_LEFT, true))
	text_box.add_child(_make_label(text, 46, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true))


func _environment_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if not data.composition.is_empty():
		result.append({"title": "Composition", "text": data.composition})

	if not data.atmosphere.is_empty():
		result.append({"title": "Atmosphere", "text": data.atmosphere})

	if not data.surface_geology.is_empty():
		result.append({"title": "Surface / Structure", "text": data.surface_geology})

	if not data.magnetic_field.is_empty():
		result.append({"title": "Magnetic Field", "text": data.magnetic_field})

	if not data.ring_system.is_empty():
		result.append({"title": "Ring System", "text": data.ring_system})

	if not data.habitability_note.is_empty():
		result.append({"title": "Habitability", "text": data.habitability_note})

	if result.is_empty():
		result.append({"title": "Profile", "text": "No extended environment profile is available yet."})

	return result

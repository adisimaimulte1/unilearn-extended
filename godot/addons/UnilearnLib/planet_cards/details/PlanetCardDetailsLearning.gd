extends "res://addons/UnilearnLib/planet_cards/details/PlanetCardDetailsOverview.gd"

func _add_features() -> void:
	var parent := _details_stack if is_instance_valid(_details_stack) else _content

	var panel := _make_panel(Color.BLACK, Color.WHITE, 3)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 30)
	_panel_margin(panel, 34, 34, 34, 38).add_child(box)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_PASS
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 18)
	box.add_child(title_row)

	var title := _section_title("DISCOVERY MAP")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var tag_panel := PanelContainer.new()
	tag_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	tag_panel.add_theme_stylebox_override("panel", _panel_style(22, Color.WHITE, Color.WHITE, 0))
	title_row.add_child(tag_panel)

	var tag := _make_label("SCIENCE", 34, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	tag.custom_minimum_size = Vector2(210, 72)
	_panel_margin(tag_panel, 18, 8, 18, 8).add_child(tag)

	var intro := _make_label(
		"Not just facts — these are the clues scientists use to understand how this object formed, changed, and interacts with its system.",
		44,
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

	var features := data.key_features

	for i in range(features.size()):
		var feature: Dictionary = features[i]
		_add_discovery_item(
			box,
			i + 1,
			str(feature.get("title", "")),
			str(feature.get("text", ""))
		)


func _add_discovery_item(parent: VBoxContainer, number: int, title: String, text: String) -> void:
	var row_panel := PanelContainer.new()
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	row_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(30, Color(0.0, 0.0, 0.0, 0.22), Color.WHITE, 3)
	)
	parent.add_child(row_panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 24)
	_panel_margin(row_panel, 24, 24, 24, 26).add_child(row)

	var number_column := VBoxContainer.new()
	number_column.custom_minimum_size = Vector2(120, 0)
	number_column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	number_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	number_column.alignment = BoxContainer.ALIGNMENT_CENTER
	number_column.mouse_filter = Control.MOUSE_FILTER_PASS
	number_column.add_theme_constant_override("separation", 12)
	row.add_child(number_column)

	var number_panel := PanelContainer.new()
	number_panel.custom_minimum_size = Vector2(100, 100)
	number_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number_panel.add_theme_stylebox_override("panel", _panel_style(999, Color.WHITE, Color.WHITE, 0))
	number_column.add_child(number_panel)

	var number_label := _make_label(str(number).pad_zeros(2), 42, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	_panel_margin(number_panel, 0, 0, 0, 0).add_child(number_label)

	var vertical_line := ColorRect.new()
	vertical_line.custom_minimum_size = Vector2(5, 72)
	vertical_line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vertical_line.color = Color.WHITE
	vertical_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number_column.add_child(vertical_line)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_theme_constant_override("separation", 12)
	row.add_child(content)

	content.add_child(_make_label(title.to_upper(), 46, _accent_color(), HORIZONTAL_ALIGNMENT_LEFT, true))

	var text_label := _make_label(text, 46, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(text_label)

	var bottom_row := HBoxContainer.new()
	bottom_row.mouse_filter = Control.MOUSE_FILTER_PASS
	bottom_row.add_theme_constant_override("separation", 12)
	content.add_child(bottom_row)

	var chip_1 := _discovery_chip("OBSERVE")
	var chip_2 := _discovery_chip("ANALYZE")
	var chip_3 := _discovery_chip("CONNECT")

	bottom_row.add_child(chip_1)
	bottom_row.add_child(chip_2)
	bottom_row.add_child(chip_3)

func _discovery_chip(text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", _panel_style(18, Color.TRANSPARENT, Color.WHITE, 2))

	var label := _make_label(text, 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false)
	label.custom_minimum_size = Vector2(130, 48)
	_panel_margin(chip, 10, 4, 10, 4).add_child(label)

	return chip


func _add_missions_block(parent: VBoxContainer) -> void:
	var panel := _make_panel(Color.BLACK, Color.WHITE, 3)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 28)
	_panel_margin(panel, 34, 34, 34, 38).add_child(box)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_PASS
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 18)
	box.add_child(title_row)

	var title := _section_title(data.missions_title.to_upper())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var orbit_tag_panel := PanelContainer.new()
	orbit_tag_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	orbit_tag_panel.add_theme_stylebox_override("panel", _panel_style(22, _accent_color(), _accent_color(), 0))
	title_row.add_child(orbit_tag_panel)

	var orbit_tag := _make_label("MISSIONS", 34, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	orbit_tag.custom_minimum_size = Vector2(230, 72)
	_panel_margin(orbit_tag_panel, 18, 8, 18, 8).add_child(orbit_tag)

	var timeline := HBoxContainer.new()
	timeline.mouse_filter = Control.MOUSE_FILTER_PASS
	timeline.add_theme_constant_override("separation", 18)
	box.add_child(timeline)

	_add_mission_step(timeline, "01", "Observe", "Capture light, motion, weather, or surface details.")
	_add_mission_step(timeline, "02", "Measure", "Convert observations into useful scientific data.")
	_add_mission_step(timeline, "03", "Explain", "Use the data to model origin, structure, and change.")

	var mission_text_panel := PanelContainer.new()
	mission_text_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mission_text_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	mission_text_panel.add_theme_stylebox_override("panel", _panel_style(28, Color(0.0, 0.0, 0.0, 0.26), Color.WHITE, 3))
	box.add_child(mission_text_panel)

	var mission_box := VBoxContainer.new()
	mission_box.mouse_filter = Control.MOUSE_FILTER_PASS
	mission_box.add_theme_constant_override("separation", 14)
	_panel_margin(mission_text_panel, 26, 24, 26, 26).add_child(mission_box)

	mission_box.add_child(_make_label("MISSION RECORD", 38, _accent_color(), HORIZONTAL_ALIGNMENT_LEFT, true))
	mission_box.add_child(_make_label(data.missions_text, 46, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true))

	if not data.discovery_note.is_empty():
		var context_line := ColorRect.new()
		context_line.custom_minimum_size = Vector2(0, 5)
		context_line.color = Color.WHITE
		context_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mission_box.add_child(context_line)

		mission_box.add_child(_make_label("DISCOVERY CONTEXT", 38, _accent_color(), HORIZONTAL_ALIGNMENT_LEFT, true))
		mission_box.add_child(_make_label(data.discovery_note, 44, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true))

func _add_mission_step(parent: HBoxContainer, number: String, title: String, text: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 210)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", _panel_style(28, Color.TRANSPARENT, Color.WHITE, 3))
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	_panel_margin(panel, 20, 18, 20, 20).add_child(box)

	box.add_child(_make_label(number, 48, _accent_color(), HORIZONTAL_ALIGNMENT_CENTER, false))

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 4)
	divider.color = Color.WHITE
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(divider)

	box.add_child(_make_label(title.to_upper(), 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	box.add_child(_make_label(text, 31, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))

func _add_fact() -> void:
	var parent := _details_stack if is_instance_valid(_details_stack) else _content

	var panel := _make_panel(_accent_color(), _transparent(), 0)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 24)
	_panel_margin(panel, 36, 34, 36, 38).add_child(box)

	box.add_child(_make_label(data.fun_fact_title.to_upper(), 58, Color.BLACK, HORIZONTAL_ALIGNMENT_LEFT, true))
	box.add_child(_make_label(data.fun_fact, 48, Color.BLACK, HORIZONTAL_ALIGNMENT_LEFT, true))

func _add_interactive_section() -> void:
	var parent := _details_stack if is_instance_valid(_details_stack) else _content

	var panel := _make_panel(Color.BLACK, Color.WHITE, 3)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 30)
	_panel_margin(panel, 34, 34, 34, 38).add_child(box)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_PASS
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 18)
	box.add_child(title_row)

	var title := _section_title("TRAINING DECK")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var tag_panel := PanelContainer.new()
	tag_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	tag_panel.add_theme_stylebox_override("panel", _panel_style(22, _accent_color(), _accent_color(), 0))
	title_row.add_child(tag_panel)

	var tag := _make_label("ACTIVE", 34, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	tag.custom_minimum_size = Vector2(190, 72)
	_panel_margin(tag_panel, 18, 8, 18, 8).add_child(tag)

	var intro := _make_label(
		"Turn this object into something you can actually remember: test, compare, then connect it to exploration.",
		44,
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

	var actions := HBoxContainer.new()
	actions.mouse_filter = Control.MOUSE_FILTER_PASS
	actions.add_theme_constant_override("separation", 18)
	box.add_child(actions)

	_add_training_action_card(actions, "01", data.quiz_title, data.quiz_text, "Start quiz")
	_add_training_action_card(actions, "02", data.compare_title, data.compare_text, "Compare now")
	_add_training_action_card(actions, "03", data.missions_title, data.missions_text, "View missions")

func _add_training_action_card(parent: HBoxContainer, number: String, title: String, text: String, button_text: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 310)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", _panel_style(30, Color.TRANSPARENT, Color.WHITE, 3))
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	_panel_margin(panel, 22, 22, 22, 24).add_child(box)

	var number_panel := PanelContainer.new()
	number_panel.custom_minimum_size = Vector2(96, 96)
	number_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number_panel.add_theme_stylebox_override("panel", _panel_style(999, Color.WHITE, Color.WHITE, 0))
	box.add_child(number_panel)

	var number_label := _make_label(number, 42, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	_panel_margin(number_panel, 0, 0, 0, 0).add_child(number_label)

	box.add_child(_make_label(title.to_upper(), 38, _accent_color(), HORIZONTAL_ALIGNMENT_CENTER, true))

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 4)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.color = Color.WHITE
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(divider)

	var text_label := _make_label(text, 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(text_label)

	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 82)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 34)
	button.add_theme_color_override("font_color", Color.BLACK)
	button.add_theme_color_override("font_hover_color", Color.BLACK)
	button.add_theme_color_override("font_pressed_color", Color.BLACK)
	button.add_theme_stylebox_override("normal", _training_button_style(false))
	button.add_theme_stylebox_override("hover", _training_button_style(true))
	button.add_theme_stylebox_override("pressed", _training_button_style(true))
	_apply_app_font(button)

	button.button_down.connect(func() -> void:
		_on_header_button_down(button)
	)

	button.button_up.connect(func() -> void:
		_on_header_button_up(button)
	)

	box.add_child(button)

func _training_button_style(_hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color.WHITE
	style.border_color = Color.WHITE
	style.set_border_width_all(3)
	style.set_corner_radius_all(22)

	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 12
	style.content_margin_bottom = 12

	return style


func _add_learning_prompts(parent: VBoxContainer) -> void:
	var prompts := data.learning_prompts

	if prompts.is_empty():
		prompts = _fallback_learning_prompts()

	var panel := _make_panel(Color.BLACK, Color.WHITE, 3)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 28)
	_panel_margin(panel, 34, 34, 34, 38).add_child(box)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_PASS
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 18)
	box.add_child(title_row)

	var title := _section_title("THINK LIKE A SCIENTIST")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var tag_panel := PanelContainer.new()
	tag_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	tag_panel.add_theme_stylebox_override("panel", _panel_style(22, Color.WHITE, Color.WHITE, 0))
	title_row.add_child(tag_panel)

	var tag := _make_label("PROMPTS", 34, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	tag.custom_minimum_size = Vector2(210, 72)
	_panel_margin(tag_panel, 18, 8, 18, 8).add_child(tag)

	var ladder := VBoxContainer.new()
	ladder.mouse_filter = Control.MOUSE_FILTER_PASS
	ladder.add_theme_constant_override("separation", 18)
	box.add_child(ladder)

	for i in range(prompts.size()):
		var prompt: Dictionary = prompts[i]
		_add_training_prompt_item(
			ladder,
			i + 1,
			str(prompt.get("title", "")),
			str(prompt.get("text", ""))
		)

func _add_training_prompt_item(parent: VBoxContainer, number: int, title: String, text: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", _panel_style(28, Color(0.0, 0.0, 0.0, 0.24), Color.WHITE, 3))
	parent.add_child(panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 22)
	_panel_margin(panel, 24, 22, 24, 24).add_child(row)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(110, 0)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.mouse_filter = Control.MOUSE_FILTER_PASS
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)

	var number_text := str(number).pad_zeros(2)
	var number_label := _make_label(number_text, 46, _accent_color(), HORIZONTAL_ALIGNMENT_CENTER, false)
	left.add_child(number_label)

	var pillar := ColorRect.new()
	pillar.custom_minimum_size = Vector2(5, 72)
	pillar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pillar.color = Color.WHITE
	pillar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(pillar)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_theme_constant_override("separation", 10)
	row.add_child(content)

	content.add_child(_make_label(title.to_upper(), 44, _accent_color(), HORIZONTAL_ALIGNMENT_LEFT, true))
	content.add_child(_make_label(text, 46, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true))

	var challenge_strip := HBoxContainer.new()
	challenge_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	challenge_strip.add_theme_constant_override("separation", 12)
	content.add_child(challenge_strip)

	challenge_strip.add_child(_training_chip("RECALL"))
	challenge_strip.add_child(_training_chip("REASON"))
	challenge_strip.add_child(_training_chip("APPLY"))

func _training_chip(text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", _panel_style(18, Color.TRANSPARENT, Color.WHITE, 2))

	var label := _make_label(text, 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false)
	label.custom_minimum_size = Vector2(120, 48)
	_panel_margin(chip, 10, 4, 10, 4).add_child(label)

	return chip


func _fallback_overview_points() -> Array[Dictionary]:
	return [
		{"title": "Role", "text": _value_or_unknown(data.system_role)},
		{"title": "Visual cue", "text": _value_or_unknown(data.visual_signature)},
		{"title": "Origin clue", "text": _value_or_unknown(data.formation_note)},
		{"title": "Extreme", "text": _value_or_unknown(data.notable_extreme)},
	]

func _fallback_learning_prompts() -> Array[Dictionary]:
	return [
		{"title": "Observe", "text": "Name one visible feature that helps identify " + data.name + "."},
		{"title": "Explain", "text": "Describe one force or process that shapes this object."},
		{"title": "Connect", "text": "Compare it with another object from the same category."},
	]


func _add_memory_item(parent: VBoxContainer, title: String, text: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", _panel_style(24, _card_color(), _transparent(), 0))
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 10)
	_panel_margin(panel, 26, 22, 26, 22).add_child(box)

	box.add_child(_make_label(title.to_upper(), 34, _accent_color(), HORIZONTAL_ALIGNMENT_LEFT, false))
	box.add_child(_make_label(text, 46, _text_color(), HORIZONTAL_ALIGNMENT_LEFT, true))

func _add_feature_item(parent: VBoxContainer, title: String, text: String) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 20)
	parent.add_child(row)

	var marker := PanelContainer.new()
	marker.custom_minimum_size = Vector2(18, 0)
	marker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_theme_stylebox_override("panel", _panel_style(999, _accent_color(), _accent_color(), 0))
	row.add_child(marker)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 10)
	row.add_child(box)

	box.add_child(_make_label(title, 50, _text_color(), HORIZONTAL_ALIGNMENT_LEFT, true))
	box.add_child(_make_label(text, 46, _muted_color(), HORIZONTAL_ALIGNMENT_LEFT, true))

func _add_stat_item(parent: GridContainer, title: String, value: String, index: int = 0) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 214)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var bg := Color(0.0, 0.0, 0.0, 0.34) if index % 2 == 0 else Color(0.0, 0.0, 0.0, 0.18)

	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(30, bg, Color.WHITE, 3)
	)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	_panel_margin(panel, 22, 20, 22, 22).add_child(box)

	var title_label := _make_label(title.to_upper(), 34, _accent_color(), HORIZONTAL_ALIGNMENT_CENTER, true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(title_label)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 4)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.color = Color.WHITE
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(divider)

	var value_label := _make_label(_value_or_unknown(value), 56, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(value_label)

func _add_action_card(parent: VBoxContainer, title: String, text: String, button_text: String) -> void:
	var panel := _make_panel(_card_color(), _transparent(), 0)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 24)
	_panel_margin(panel, 34, 32, 34, 34).add_child(box)

	box.add_child(_make_label(title, 50, _text_color(), HORIZONTAL_ALIGNMENT_LEFT, true))
	box.add_child(_make_label(text, 46, _muted_color(), HORIZONTAL_ALIGNMENT_LEFT, true))

	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 96)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 40)
	button.add_theme_color_override("font_color", Color.BLACK)
	button.add_theme_color_override("font_hover_color", Color.BLACK)
	button.add_theme_color_override("font_pressed_color", Color.BLACK)
	button.add_theme_stylebox_override("normal", _learning_button_style(false))
	button.add_theme_stylebox_override("hover", _learning_button_style(true))
	button.add_theme_stylebox_override("pressed", _learning_button_style(true))
	_apply_app_font(button)
	button.pressed.connect(func() -> void:
		_play_sfx("click")
	)
	box.add_child(button)


func _section_title(value: String) -> Label:
	return _make_label(value, 58, _text_color(), HORIZONTAL_ALIGNMENT_LEFT, true)

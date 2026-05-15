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

	bottom_row.add_child(_discovery_chip("OBSERVE"))
	bottom_row.add_child(_discovery_chip("ANALYZE"))
	bottom_row.add_child(_discovery_chip("CONNECT"))


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


func _add_game_progress_strip() -> void:
	if data == null or not is_instance_valid(_content):
		return

	var panel := _make_panel(Color(0.0, 0.0, 0.0, 0.22), Color.WHITE, 2)
	panel.name = "GameProgressStrip"
	_content.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 18)
	_panel_margin(panel, 28, 22, 28, 24).add_child(box)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_PASS
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 18)
	box.add_child(top)

	var level_label := _make_label("LVL %d" % max(data.game_level, 1), 56, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
	level_label.custom_minimum_size = Vector2(190, 70)
	top.add_child(level_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	var xp_text := _make_label("%d/%d XP" % [max(data.game_xp, 0), max(data.game_xp_to_next, 1)], 50, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, true)
	xp_text.custom_minimum_size = Vector2(290, 70)
	top.add_child(xp_text)

	_add_xp_bar(box)
	_add_attribute_badges(box)


func _add_xp_bar(parent: VBoxContainer) -> void:
	var ratio := clamp(
		float(max(data.game_xp, 0)) / float(max(data.game_xp_to_next, 1)),
		0.0,
		1.0
	)

	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 34)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.clip_contents = true
	parent.add_child(bar)

	var fill := Panel.new()
	fill.name = "XPFill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_theme_stylebox_override("panel", _xp_fill_style())
	bar.add_child(fill)

	var border := Panel.new()
	border.name = "XPBorder"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.add_theme_stylebox_override("panel", _xp_bar_border_style())
	bar.add_child(border)

	bar.resized.connect(func() -> void:
		_layout_xp_bar(fill, border, bar, ratio)
	)

	call_deferred("_layout_xp_bar", fill, border, bar, ratio)


func _layout_xp_bar(fill: Control, border: Control, bar: Control, ratio: float) -> void:
	if not is_instance_valid(fill) or not is_instance_valid(border) or not is_instance_valid(bar):
		return

	border.position = Vector2.ZERO
	border.size = bar.size

	fill.position = Vector2.ZERO
	fill.size = Vector2(bar.size.x * ratio, bar.size.y)
	fill.visible = ratio > 0.0

	fill.modulate = Color.WHITE
	fill.self_modulate = Color.WHITE

	fill.z_index = 0
	border.z_index = 1


func _xp_fill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color.WHITE
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(999)

	style.shadow_size = 0
	style.shadow_color = Color.TRANSPARENT
	style.shadow_offset = Vector2.ZERO

	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0

	return style


func _xp_bar_border_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.WHITE
	style.set_border_width_all(5)
	style.set_corner_radius_all(999)

	style.shadow_size = 0
	style.shadow_color = Color.TRANSPARENT
	style.shadow_offset = Vector2.ZERO

	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0

	return style


func _add_attribute_badges(parent: VBoxContainer) -> void:
	var badges := data.attribute_badges

	if badges.is_empty():
		badges = _fallback_attribute_badges()

	var filtered_badges: Array[Dictionary] = []

	for badge in badges:
		if not badge is Dictionary:
			continue

		var title := str(badge.get("title", "")).strip_edges()

		if title.to_lower() == "class":
			continue

		filtered_badges.append(badge)

		if filtered_badges.size() >= 3:
			break

	if filtered_badges.is_empty():
		filtered_badges = [
			{"title": "Role", "value": _default_role_text(), "color": "accent"},
			{"title": "Skill", "value": _default_orbit_skill(), "color": "blue"},
			{"title": "Reward", "value": "+%d XP" % _upgrade_quiz_xp_reward(), "color": "green"},
		]

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 0)
	parent.add_child(grid)

	for badge in filtered_badges:
		_add_badge(
			grid,
			str(badge.get("title", "Trait")),
			str(badge.get("value", "")),
			str(badge.get("color", "accent"))
		)


func _add_badge(parent: Control, title: String, value: String, color_key: String) -> void:
	var color := _badge_color(color_key)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 104)
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(24, Color(0.0, 0.0, 0.0, 0.28), color, 2)
	)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	_panel_margin(panel, 10, 8, 10, 10).add_child(box)

	var title_label := _make_label(
		"%s:" % title.to_upper(),
		31,
		color,
		HORIZONTAL_ALIGNMENT_CENTER,
		false
	)
	title_label.custom_minimum_size = Vector2(0, 36)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(title_label)

	var value_label := _make_label(
		value.to_upper(),
		39,
		Color.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER,
		true
	)
	value_label.custom_minimum_size = Vector2(0, 44)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(value_label)


func _add_game_stats_section(parent: VBoxContainer) -> void:
	_add_game_overview_panel(parent)
	_add_attribute_scores_panel(parent)
	_add_upgrade_button_panel(parent)


func _add_game_overview_panel(parent: VBoxContainer) -> void:
	var panel := _make_panel(Color.BLACK, Color.WHITE, 3)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 26)
	_panel_margin(panel, 34, 34, 34, 38).add_child(box)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)

	var title := _section_title("GAME PROFILE")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	var tag_panel := PanelContainer.new()
	tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_panel.add_theme_stylebox_override("panel", _panel_style(22, Color.WHITE, Color.WHITE, 0))
	row.add_child(tag_panel)

	var tag := _make_label(_object_category().replace("_", " ").to_upper(), 30, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	tag.custom_minimum_size = Vector2(230, 70)
	_panel_margin(tag_panel, 14, 8, 14, 8).add_child(tag)

	var intro := _make_label(
		_game_profile_text(),
		44,
		Color.WHITE,
		HORIZONTAL_ALIGNMENT_LEFT,
		true
	)
	box.add_child(intro)

	var lane := HBoxContainer.new()
	lane.mouse_filter = Control.MOUSE_FILTER_PASS
	lane.add_theme_constant_override("separation", 16)
	box.add_child(lane)

	_add_game_status_chip(lane, "ROLE", _default_role_text(), _accent_color())
	_add_game_status_chip(lane, "SKILL", _default_orbit_skill(), Color.WHITE)
	_add_game_status_chip(lane, "REWARD", "+%d XP" % _upgrade_quiz_xp_reward(), _badge_color("blue"))


func _add_game_status_chip(parent: HBoxContainer, title: String, value: String, color: Color) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style(24, Color(0.0, 0.0, 0.0, 0.22), color, 2))
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	_panel_margin(panel, 14, 14, 14, 16).add_child(box)

	box.add_child(_make_label(title, 30, color, HORIZONTAL_ALIGNMENT_CENTER, false))
	box.add_child(_make_label(value, 38, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))


func _add_attribute_scores_panel(parent: VBoxContainer) -> void:
	var panel := _make_panel(Color.BLACK, Color.WHITE, 3)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 26)
	_panel_margin(panel, 34, 34, 34, 38).add_child(box)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_PASS
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 18)
	box.add_child(title_row)

	var title := _section_title("CORE ATTRIBUTES")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var tag_panel := PanelContainer.new()
	tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_panel.add_theme_stylebox_override("panel", _panel_style(22, Color.WHITE, Color.WHITE, 0))
	title_row.add_child(tag_panel)

	var tag := _make_label("0-100", 32, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	tag.custom_minimum_size = Vector2(150, 70)
	_panel_margin(tag_panel, 14, 8, 14, 8).add_child(tag)

	var scores := _game_attribute_scores()

	for score in scores:
		if score is Dictionary:
			_add_attribute_score_item(box, str(score.get("title", "Score")), int(score.get("value", 0)))


func _add_attribute_score_item(parent: VBoxContainer, title: String, value: int) -> void:
	var clean_value: int = int(clamp(value, 0, 100))
	var color := _attribute_score_color(title)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)

	var label := _make_label(title.to_upper(), 40, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, false)
	label.custom_minimum_size = Vector2(340, 54)
	row.add_child(label)

	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 24)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override(
		"panel",
		_attribute_bar_style(999, Color(0.035, 0.038, 0.048, 1.0), Color.TRANSPARENT, 0)
	)
	row.add_child(bar)

	var fill := PanelContainer.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_theme_stylebox_override(
		"panel",
		_attribute_bar_style(999, color, Color.TRANSPARENT, 0)
	)
	bar.add_child(fill)

	bar.resized.connect(func() -> void:
		_layout_score_fill(fill, bar, clean_value)
	)

	call_deferred("_layout_score_fill", fill, bar, clean_value)

	var value_label := _make_label(str(clean_value), 40, color, HORIZONTAL_ALIGNMENT_RIGHT, false)
	value_label.custom_minimum_size = Vector2(82, 54)
	row.add_child(value_label)


func _attribute_score_color(title: String) -> Color:
	var key := title.strip_edges().to_lower()

	if key.contains("habit"):
		return Color("#7DFF8A")

	if key.contains("magnetic") or key.contains("magnet"):
		return Color("#B875FF")

	if key.contains("atmos"):
		return Color("#63D8FF")

	if key.contains("geolog") or key.contains("surface") or key.contains("volcan"):
		return Color("#FF9D42")

	if key.contains("grav"):
		return Color("#FF5F7E")

	if key.contains("radiation") or key.contains("safety"):
		return Color("#FFE45C")

	return _accent_color()


func _attribute_bar_style(radius: int, fill_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)

	style.shadow_size = 0
	style.shadow_color = Color.TRANSPARENT
	style.shadow_offset = Vector2.ZERO

	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0

	return style


func _layout_score_fill(fill: Control, bar_back: PanelContainer, value: int) -> void:
	if not is_instance_valid(fill) or not is_instance_valid(bar_back):
		return

	var inset := 3.0
	var ratio := clamp(float(value) / 100.0, 0.0, 1.0)
	var available_width := max(bar_back.size.x - inset * 2.0, 0.0)
	var available_height := max(bar_back.size.y - inset * 2.0, 0.0)

	fill.position = Vector2(inset, inset)
	fill.size = Vector2(available_width * ratio, available_height)


func _add_upgrade_button_panel(parent: VBoxContainer) -> void:
	var panel := _make_panel(_accent_soft_color(), _accent_color(), 3)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 24)
	_panel_margin(panel, 34, 34, 34, 38).add_child(box)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_PASS
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 18)
	box.add_child(top)

	var title := _section_title("UPGRADE QUIZ")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	var reward_panel := PanelContainer.new()
	reward_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_panel.add_theme_stylebox_override("panel", _panel_style(22, Color.WHITE, Color.WHITE, 0))
	top.add_child(reward_panel)

	var reward := _make_label("+%d XP" % _upgrade_quiz_xp_reward(), 34, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	reward.custom_minimum_size = Vector2(180, 72)
	_panel_margin(reward_panel, 16, 8, 16, 8).add_child(reward)

	box.add_child(_make_label(
		"Start a fresh AI-generated quiz for this object. Win XP, improve its score profile, and unlock future simulation bonuses.",
		46,
		Color.WHITE,
		HORIZONTAL_ALIGNMENT_LEFT,
		true
	))

	var button := Button.new()
	button.text = "START UPGRADE QUIZ"
	button.custom_minimum_size = Vector2(0, 94)
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

	button.button_down.connect(func() -> void:
		_on_header_button_down(button)
	)

	button.button_up.connect(func() -> void:
		_on_header_button_up(button)
	)

	button.pressed.connect(func() -> void:
		_request_upgrade_quiz()
	)

	box.add_child(button)


func _request_upgrade_quiz() -> void:
	if has_node("/root/UnilearnQuizController"):
		var quiz_controller := get_node("/root/UnilearnQuizController")

		if quiz_controller.has_method("open_upgrade_quiz"):
			quiz_controller.open_upgrade_quiz(data)


func _game_attribute_scores() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if data.game_attribute_scores.size() == 6:
		for item in data.game_attribute_scores:
			if not item is Dictionary:
				continue

			var title := str(item.get("title", "")).strip_edges()

			if title.is_empty():
				continue

			result.append({
				"title": title,
				"value": clampi(int(item.get("value", 0)), 0, 100),
			})

		if result.size() == 6:
			return result

	return _fallback_game_attribute_scores()


func _fallback_game_attribute_scores() -> Array[Dictionary]:
	match _object_category():
		"star":
			return [
				{"title": "Habitability", "value": 20},
				{"title": "Magnetic Field", "value": 90},
				{"title": "Atmosphere", "value": 95},
				{"title": "Geology", "value": 5},
				{"title": "Gravity", "value": 100},
				{"title": "Radiation Safety", "value": 5},
			]
		"satellite", "moon":
			return [
				{"title": "Habitability", "value": 25},
				{"title": "Magnetic Field", "value": 15},
				{"title": "Atmosphere", "value": 15},
				{"title": "Geology", "value": 65},
				{"title": "Gravity", "value": 25},
				{"title": "Radiation Safety", "value": 35},
			]
		_:
			return [
				{"title": "Habitability", "value": 50},
				{"title": "Magnetic Field", "value": 50},
				{"title": "Atmosphere", "value": 50},
				{"title": "Geology", "value": 50},
				{"title": "Gravity", "value": 50},
				{"title": "Radiation Safety", "value": 50},
			]


func _upgrade_quiz_xp_reward() -> int:
	return int(clamp(data.upgrade_quiz_xp_reward, 5, 250))


func _game_progress_label() -> String:
	var left := max(data.game_xp_to_next - data.game_xp, 0)
	return "%s needs %d XP to reach level %d." % [data.name, left, max(data.game_level, 1) + 1]


func _game_profile_text() -> String:
	match _object_category():
		"star":
			return "%s acts as a system anchor. Upgrade it to unlock stronger orbit tools, stellar zones, and challenge modifiers." % data.name
		"satellite", "moon":
			return "%s is a parent-bound body. Upgrade it to improve tidal, orbit, and surface-history challenges." % data.name
		_:
			return "%s can become a stronger simulation piece as you upgrade its orbit, environment, and scientific traits." % data.name


func _default_role_text() -> String:
	match _object_category():
		"star":
			return "Anchor"
		"satellite", "moon":
			return "Companion"
		"dwarf_planet":
			return "Outer body"
		_:
			return "World"


func _fallback_attribute_badges() -> Array[Dictionary]:
	var category := _object_category()
	var badges: Array[Dictionary] = []

	match category:
		"star":
			badges = [
				{"title": "Class", "value": "Stellar", "color": "yellow"},
				{"title": "Energy", "value": "Fusion", "color": "orange"},
				{"title": "Role", "value": "Anchor", "color": "purple"},
			]
		"satellite", "moon":
			badges = [
				{"title": "Class", "value": "Satellite", "color": "blue"},
				{"title": "Orbit", "value": "Parent-bound", "color": "purple"},
				{"title": "Surface", "value": "Ancient", "color": "gray"},
			]
		_:
			badges = [
				{"title": "Class", "value": "Planetary", "color": "green"},
				{"title": "Gravity", "value": "Active", "color": "blue"},
				{"title": "Study", "value": "World", "color": "purple"},
			]

	return badges


func _default_orbit_skill() -> String:
	match _object_category():
		"star":
			return "Anchor"
		"satellite", "moon":
			return "Parent lock"
		_:
			return "Tuning"


func _badge_color(key: String) -> Color:
	match key.strip_edges().to_lower():
		"red", "heat", "lava":
			return Color("#ff6b3d")
		"orange":
			return Color("#ffb347")
		"yellow", "star":
			return Color("#ffe066")
		"green", "life":
			return Color("#7dff9a")
		"blue", "ice", "water":
			return Color("#77d9ff")
		"gray", "rock":
			return Color("#c7c7c7")
		"purple", "gravity":
			return _accent_color()
		_:
			return _accent_color()

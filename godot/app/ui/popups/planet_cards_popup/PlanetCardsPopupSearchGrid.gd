extends "res://app/ui/popups/planet_cards_popup/PlanetCardsPopupGenerate.gd"

const PROGRESSIVE_CARD_INITIAL_BATCH_SIZE := 1
const PROGRESSIVE_CARD_BATCH_SIZE := 1
const PROGRESSIVE_CARD_FRAME_BUDGET_MSEC := 3

const CARD_ACTIVE_VIEWPORT_MARGIN := 620.0
const CARD_LAYOUT_REFRESH_EVERY := 10
const CARD_ANIMATION_LIMIT := 8

var _search_haystack_cache: Dictionary = {}
var _runtime_visibility_update_pending := false
var _scroll_visibility_signal_connected := false


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

	var should_show := not _search_box.text.strip_edges().is_empty()

	if _search_clear_button.visible != should_show:
		_search_clear_button.visible = should_show

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
	if not _intro_done:
		return

	if not is_instance_valid(_grid):
		return

	_rebuild_generation += 1
	var local_generation := _rebuild_generation

	if _grid_reveal_tween != null and _grid_reveal_tween.is_valid():
		_grid_reveal_tween.kill()

	_kill_existing_card_tweens()
	_clear_grid_children_deferred()

	var q := query.strip_edges().to_lower()
	var matches: Array[PlanetData] = _get_matching_cards(q)

	_connect_scroll_runtime_visibility_signal()

	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = 0
		_scroll_velocity = 0.0
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS

	if matches.is_empty():
		_grid.visible = false
		_grid.modulate.a = 0.0
		_grid.position = GRID_REVEAL_OFFSET

		if is_instance_valid(_no_results_label):
			_no_results_label.visible = true
			_no_results_label.text = "NO MATCH. NEW PLANET?" if not q.is_empty() else "NO PLANETS AVAILABLE"
			_no_results_label.add_theme_color_override("font_color", COLOR_SUBTITLE)
			_update_no_results_height()

		call_deferred("_style_scroll_bar")
		call_deferred("_update_no_results_height")
		return

	_grid.visible = true
	_grid.modulate.a = 1.0
	_grid.position = Vector2.ZERO

	if is_instance_valid(_no_results_label):
		_no_results_label.visible = true
		_no_results_label.text = ""
		_no_results_label.add_theme_color_override("font_color", COLOR_SUBTITLE)
		_update_no_results_height()

	await get_tree().process_frame

	if local_generation != _rebuild_generation or _closing or not is_instance_valid(_grid):
		return

	await _build_grid_cards_progressively(matches, local_generation)


func _get_matching_cards(q: String) -> Array[PlanetData]:
	var matches: Array[PlanetData] = []

	for planet_data in _all_planets:
		if planet_data == null:
			continue

		if _planet_matches_query(planet_data, q):
			matches.append(planet_data)

	matches.sort_custom(func(a: PlanetData, b: PlanetData) -> bool:
		return a.name.strip_edges().to_lower() < b.name.strip_edges().to_lower()
	)

	return matches


func _clear_grid_children_deferred() -> void:
	if not is_instance_valid(_grid):
		return

	for child in _grid.get_children():
		child.queue_free()


func _kill_existing_card_tweens() -> void:
	if not is_instance_valid(_grid):
		return

	for child in _grid.get_children():
		if child is Control:
			var control := child as Control
			control.modulate.a = 0.0


func _build_grid_cards_progressively(matches: Array[PlanetData], local_generation: int) -> void:
	var built_count := 0
	var index := 0

	while index < matches.size():
		if local_generation != _rebuild_generation or _closing or not is_instance_valid(_grid):
			return

		var batch_size := PROGRESSIVE_CARD_INITIAL_BATCH_SIZE if index == 0 else PROGRESSIVE_CARD_BATCH_SIZE
		var batch_count := 0
		var frame_start := Time.get_ticks_msec()

		while index < matches.size() and batch_count < batch_size:
			if Time.get_ticks_msec() - frame_start >= PROGRESSIVE_CARD_FRAME_BUDGET_MSEC:
				break

			var planet_data := matches[index]
			index += 1

			if planet_data == null:
				continue

			var card := PREVIEW_SCRIPT.new()
			card.mouse_filter = Control.MOUSE_FILTER_PASS
			card.focus_mode = Control.FOCUS_NONE
			card.modulate.a = 0.0
			card.scale = CARD_ENTER_SCALE

			card.setup(planet_data)

			card.selected.connect(_open_details)
			_force_card_scroll_compatibility(card)

			_grid.add_child(card)

			if built_count == 0 and is_instance_valid(_no_results_label):
				_no_results_label.visible = false

			if built_count < CARD_ANIMATION_LIMIT:
				_animate_card_in(card, built_count)
			else:
				card.modulate.a = 1.0
				card.scale = Vector2.ONE

			built_count += 1
			batch_count += 1

		if built_count % CARD_LAYOUT_REFRESH_EVERY == 0:
			call_deferred("_style_scroll_bar")
			call_deferred("_update_no_results_height")
			_request_runtime_visibility_update()

		await get_tree().process_frame

	if local_generation != _rebuild_generation or _closing or not is_instance_valid(_grid):
		return

	if built_count == 0:
		_grid.visible = false

		if is_instance_valid(_no_results_label):
			_no_results_label.visible = true
			_no_results_label.text = "NO CARDS FOUND"
			_no_results_label.add_theme_color_override("font_color", COLOR_SUBTITLE)
			_update_no_results_height()
	else:
		_grid.visible = true

		if is_instance_valid(_no_results_label):
			_no_results_label.visible = false

	call_deferred("_style_scroll_bar")
	call_deferred("_update_no_results_height")
	_request_runtime_visibility_update()


func _connect_scroll_runtime_visibility_signal() -> void:
	if _scroll_visibility_signal_connected:
		return

	if not is_instance_valid(_scroll):
		return

	var bar := _scroll.get_v_scroll_bar()

	if bar == null:
		return

	var callable := Callable(self, "_on_scroll_value_changed_for_card_runtime")

	if not bar.value_changed.is_connected(callable):
		bar.value_changed.connect(callable)

	_scroll_visibility_signal_connected = true


func _on_scroll_value_changed_for_card_runtime(_value: float) -> void:
	_request_runtime_visibility_update()


func _request_runtime_visibility_update() -> void:
	if _runtime_visibility_update_pending:
		return

	_runtime_visibility_update_pending = true
	call_deferred("_update_card_runtime_visibility")


func _update_card_runtime_visibility() -> void:
	_runtime_visibility_update_pending = false

	if not is_instance_valid(_scroll) or not is_instance_valid(_grid):
		return

	var scroll_rect := _scroll.get_global_rect()
	var active_rect := Rect2(
		scroll_rect.position - Vector2(0.0, CARD_ACTIVE_VIEWPORT_MARGIN),
		scroll_rect.size + Vector2(0.0, CARD_ACTIVE_VIEWPORT_MARGIN * 2.0)
	)

	for child in _grid.get_children():
		if not (child is Control):
			continue

		var card := child as Control
		var should_run := _rects_intersect(active_rect, card.get_global_rect())

		_set_card_runtime_enabled(card, should_run)


func _set_card_runtime_enabled(card: Control, enabled: bool) -> void:
	if not is_instance_valid(card):
		return

	var desired_mode := Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED

	if card.process_mode == desired_mode:
		return

	card.process_mode = desired_mode

	for child in card.get_children():
		_set_runtime_enabled_recursive(child, enabled)


func _set_runtime_enabled_recursive(node: Node, enabled: bool) -> void:
	if node == null:
		return

	var desired_mode := Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED

	if node.process_mode != desired_mode:
		node.process_mode = desired_mode

	for child in node.get_children():
		_set_runtime_enabled_recursive(child, enabled)


func _rects_intersect(a: Rect2, b: Rect2) -> bool:
	return (
		a.position.x < b.position.x + b.size.x
		and a.position.x + a.size.x > b.position.x
		and a.position.y < b.position.y + b.size.y
		and a.position.y + a.size.y > b.position.y
	)


func _reveal_grid() -> void:
	if not is_instance_valid(_grid):
		return

	_grid.modulate.a = 1.0
	_grid.position = Vector2.ZERO


func _animate_card_in(card: Control, index: int) -> void:
	if not is_instance_valid(card):
		return

	if _should_reduce_motion():
		card.modulate.a = 1.0
		card.scale = Vector2.ONE
		return

	card.pivot_offset = card.size * 0.5

	var delay: float = min(float(index % 2) * CARD_ENTER_STAGGER, 0.035)

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

	var next_height: float = max(available_height + 1.0, 420.0)

	if not is_equal_approx(_no_results_label.custom_minimum_size.y, next_height):
		_no_results_label.custom_minimum_size = Vector2(0, next_height)


func _planet_matches_query(planet_data: PlanetData, query: String) -> bool:
	if planet_data == null:
		return false

	if query.is_empty():
		return true

	var haystack := _get_cached_search_haystack(planet_data)
	return haystack.contains(query)


func _get_cached_search_haystack(planet_data: PlanetData) -> String:
	var key := _planet_search_cache_key(planet_data)

	if _search_haystack_cache.has(key):
		return str(_search_haystack_cache[key])

	var haystack := "%s %s %s %s %s %s %s" % [
		planet_data.name,
		planet_data.subtitle,
		planet_data.description,
		planet_data.planet_preset,
		planet_data.distance_from_sun,
		planet_data.object_category,
		planet_data.archetype_id
	]

	haystack = haystack.to_lower()
	_search_haystack_cache[key] = haystack

	return haystack


func _planet_search_cache_key(planet_data: PlanetData) -> String:
	if planet_data == null:
		return ""

	if not planet_data.instance_id.strip_edges().is_empty():
		return planet_data.instance_id

	return "%s_%s" % [planet_data.name, str(planet_data.planet_seed)]


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

	_request_runtime_visibility_update()

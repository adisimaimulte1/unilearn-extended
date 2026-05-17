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

	var parsed := _parse_search_query(query)

	if not _planet_matches_filters(planet_data, parsed["filters"]):
		return false

	var text_query := str(parsed["text"]).strip_edges().to_lower()

	if text_query.is_empty():
		return true

	var haystack := _get_cached_search_haystack(planet_data)
	return haystack.contains(text_query)


func _get_cached_search_haystack(planet_data: PlanetData) -> String:
	var key := _planet_search_cache_key(planet_data)

	if _search_haystack_cache.has(key):
		return str(_search_haystack_cache[key])

	var haystack := "%s %s %s %s %s %s %s %s %s %s %s %s" % [
		planet_data.name,
		planet_data.subtitle,
		planet_data.description,
		planet_data.planet_preset,
		planet_data.distance_from_sun,
		planet_data.object_category,
		planet_data.archetype_id,
		planet_data.parent_object,
		planet_data.system_role,
		planet_data.visual_signature,
		planet_data.composition,
		planet_data.atmosphere
	]

	haystack = haystack.to_lower()
	_search_haystack_cache[key] = haystack

	return haystack


func _parse_search_query(query: String) -> Dictionary:
	var filters: Array[Dictionary] = []
	var text_parts: Array[String] = []

	var parts := query.strip_edges().split(" ", false)

	for part in parts:
		var token := str(part).strip_edges()

		if token.begins_with(">") and token.contains(":"):
			var clean_token := token.substr(1)
			var separator_index := clean_token.find(":")
			var key := clean_token.substr(0, separator_index).strip_edges().to_lower()
			var value := clean_token.substr(separator_index + 1).strip_edges().to_lower()

			if not key.is_empty() and not value.is_empty():
				filters.append({
					"key": key,
					"value": value
				})
		else:
			text_parts.append(token)

	return {
		"filters": filters,
		"text": " ".join(text_parts)
	}


func _planet_matches_filters(planet_data: PlanetData, filters: Array[Dictionary]) -> bool:
	if filters.is_empty():
		return true

	for filter in filters:
		var key := str(filter.get("key", "")).strip_edges().to_lower()
		var value := str(filter.get("value", "")).strip_edges().to_lower()

		if key.is_empty() or value.is_empty():
			continue

		if not _planet_matches_single_filter(planet_data, key, value):
			return false

	return true

func _planet_matches_single_filter(planet_data: PlanetData, key: String, value: String) -> bool:
	match key:
		"type", "category", "cat":
			return _type_filter_matches(planet_data, value)

		"guide":
			return _filter_contains(_guide_type_for_card(planet_data), value)

		"preset", "visual":
			return _filter_contains(planet_data.planet_preset, value)

		"archetype", "arch":
			return _filter_contains(planet_data.archetype_id, value)

		"parent", "around", "orbits":
			return _filter_contains(planet_data.parent_object, value)

		"name", "id":
			return (
				_filter_contains(planet_data.name, value)
				or _filter_contains(planet_data.instance_id, value)
			)

		"moon", "moons":
			return _filter_contains(planet_data.moons, value)

		"temp", "temperature":
			return _filter_contains(planet_data.average_temperature, value)

		"gravity":
			return _filter_contains(planet_data.gravity, value)

		"mass":
			return _filter_contains(planet_data.mass, value)

		"distance":
			return _filter_contains(planet_data.distance_from_sun, value)

		"rings", "ring":
			return _filter_contains(planet_data.ring_system, value)

		"atmosphere", "atm":
			return _filter_contains(planet_data.atmosphere, value)

		"composition", "comp":
			return _filter_contains(planet_data.composition, value)

		"surface", "geo", "geology":
			return _filter_contains(planet_data.surface_geology, value)

		"feature", "features":
			return _filter_contains(_feature_text_for_card(planet_data), value)

		_:
			return _filter_contains(_get_cached_search_haystack(planet_data), value)


func _normalized_object_category(planet_data: PlanetData) -> String:
	var category := _normalize_filter_text(planet_data.object_category)
	var archetype := _normalize_filter_text(planet_data.archetype_id)
	var preset := _normalize_filter_text(planet_data.planet_preset)
	var name := _normalize_filter_text(planet_data.name)
	var parent := _normalize_filter_text(planet_data.parent_object)

	if category == "moon" or category == "satellite" or category == "natural satellite":
		return "satellite"

	if archetype == "moon" or preset == "moon":
		return "satellite"

	if category == "star" or archetype == "star" or preset == "star":
		return "star"

	if category == "dwarf planet" or category == "dwarf_planet" or archetype == "dwarf planet" or archetype == "dwarf_planet":
		return "dwarf_planet"

	if category == "small body" or category == "small_body":
		return "small_body"

	if category == "exoplanet":
		return "exoplanet"

	if category == "planet":
		return "planet"

	# Generated cards sometimes store the real type mostly in archetype/preset.
	if archetype in ["rocky", "gas giant", "ringed gas giant", "ice giant", "ice world", "lava world"]:
		return "exoplanet" if not parent.is_empty() and parent != "sun" else "planet"

	if preset in [
		"terran wet",
		"earth",
		"islands",
		"rivers",
		"dry terran",
		"no atmosphere",
		"lava world",
		"ice world",
		"gas planet",
		"gas giant 1",
		"gas giant 2",
		"ringed gas planet"
	]:
		return "exoplanet" if not parent.is_empty() and parent != "sun" else "planet"

	if not name.is_empty():
		return "planet"

	return "planet"


func _type_filter_matches(planet_data: PlanetData, value: String) -> bool:
	var wanted := _normalize_filter_text(value)
	var category := _normalized_object_category(planet_data)
	var archetype := _normalize_filter_text(planet_data.archetype_id)
	var preset := _normalize_filter_text(planet_data.planet_preset)

	if wanted == "moon" or wanted == "satellite" or wanted == "natural satellite":
		return category == "satellite" or archetype == "moon" or preset == "moon"

	if wanted == "planet":
		return category == "planet" or category == "exoplanet"

	if wanted == "exoplanet":
		return category == "exoplanet"

	if wanted == "star" or wanted == "stellar":
		return category == "star" or archetype == "star" or preset == "star"

	if wanted == "dwarf" or wanted == "dwarf planet":
		return category == "dwarf_planet"

	if wanted == "small body" or wanted == "asteroid" or wanted == "comet":
		return category == "small_body"

	if wanted == "lava" or wanted == "lava world" or wanted == "lava planet":
		return archetype == "lava world" or preset == "lava world"

	if wanted == "ice" or wanted == "ice world":
		return archetype == "ice world" or preset == "ice world"

	if wanted == "gas" or wanted == "gas giant":
		return (
			archetype == "gas giant"
			or archetype == "ringed gas giant"
			or preset == "gas planet"
			or preset == "gas giant 1"
			or preset == "gas giant 2"
			or preset == "ringed gas planet"
		)

	if wanted == "rocky":
		return (
			archetype == "rocky"
			or preset == "terran wet"
			or preset == "dry terran"
			or preset == "no atmosphere"
			or preset == "earth"
			or preset == "islands"
			or preset == "rivers"
		)

	return (
		_filter_contains(category, wanted)
		or _filter_contains(archetype, wanted)
		or _filter_contains(preset, wanted)
	)


func _filter_contains(source: String, value: String) -> bool:
	var normalized_source := _normalize_filter_text(source)
	var normalized_value := _normalize_filter_text(value)

	if normalized_value.is_empty():
		return true

	return normalized_source.contains(normalized_value)


func _normalize_filter_text(value: String) -> String:
	return value.strip_edges() \
		.to_lower() \
		.replace("_", " ") \
		.replace("-", " ")


func _guide_type_for_card(planet_data: PlanetData) -> String:
	var category := _normalized_object_category(planet_data)
	var archetype := planet_data.archetype_id.strip_edges().to_lower()
	var preset := planet_data.planet_preset.strip_edges().to_lower()

	if category == "star" or archetype == "star" or preset == "star":
		return "stellar"

	if category == "satellite" or archetype == "moon" or preset == "moon":
		return "satellite"

	return "planetary"


func _feature_text_for_card(planet_data: PlanetData) -> String:
	var parts: Array[String] = []

	for item in planet_data.key_features:
		if item is Dictionary:
			parts.append(str(item.get("title", "")))
			parts.append(str(item.get("text", "")))

	for item in planet_data.overview_points:
		if item is Dictionary:
			parts.append(str(item.get("title", "")))
			parts.append(str(item.get("text", "")))

	return " ".join(parts)


func _planet_search_cache_key(planet_data: PlanetData) -> String:
	if planet_data == null:
		return ""

	if not planet_data.instance_id.strip_edges().is_empty():
		return planet_data.instance_id

	return "%s_%s" % [planet_data.name, str(planet_data.planet_seed)]


func _open_details(planet_data: PlanetData) -> void:
	if planet_data == null:
		return

	_release_search_focus()
	_play_sfx("open")

	if is_instance_valid(_details_view):
		_details_view.queue_free()
		_details_view = null

	if is_instance_valid(_main_view):
		_main_view.visible = false

	_details_view = DETAILS_SCRIPT.new() as PlanetCardDetails

	if _details_view == null:
		push_error("PlanetCardsPopup: Could not create PlanetCardDetails from DETAILS_SCRIPT.")
		if is_instance_valid(_main_view):
			_main_view.visible = true
		return

	_details_view.name = "PlanetCardDetailsView"
	_details_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_details_view.setup(planet_data)

	var already_added := _query_planet_added_state(planet_data)

	if _details_view.has_method("set_planet_added"):
		_details_view.call("set_planet_added", already_added)

	_connect_details_signal_safe(
		_details_view,
		"add_planet_requested",
		Callable(self, "_on_details_add_planet_requested")
	)

	_connect_details_signal_safe(
		_details_view,
		"remove_planet_requested",
		Callable(self, "_on_details_remove_planet_requested")
	)

	_connect_details_signal_safe(
		_details_view,
		"back_requested",
		Callable(self, "_close_details")
	)

	if is_instance_valid(_body_root):
		_body_root.add_child(_details_view)
	else:
		add_child(_details_view)


func _query_planet_added_state(planet_data: PlanetData) -> bool:
	if planet_data == null:
		return false

	var scene := get_tree().current_scene

	if scene != null and scene.has_method("is_planet_card_in_scene"):
		return bool(scene.call("is_planet_card_in_scene", planet_data))

	var parent := get_parent()

	while parent != null:
		if parent.has_method("is_planet_card_in_scene"):
			return bool(parent.call("is_planet_card_in_scene", planet_data))

		parent = parent.get_parent()

	return false


func _close_details() -> void:
	_play_sfx("close")

	if is_instance_valid(_details_view):
		_details_view.queue_free()

	_details_view = null

	if is_instance_valid(_main_view):
		_main_view.visible = true

	_request_runtime_visibility_update()


func _connect_details_signal_safe(source: Object, signal_name: String, callable: Callable) -> void:
	if source == null:
		return

	if not source.has_signal(signal_name):
		push_warning("PlanetCardsPopup: Details view is missing signal: %s" % signal_name)
		return

	if source.is_connected(signal_name, callable):
		return

	source.connect(signal_name, callable)


func _on_details_add_planet_requested(data: PlanetData) -> void:
	if data == null:
		return

	planet_add_requested.emit(data)


func _on_details_remove_planet_requested(data: PlanetData) -> void:
	if data == null:
		return

	planet_remove_requested.emit(data)


func _on_planet_cards_cache_invalidated() -> void:
	_search_haystack_cache.clear()

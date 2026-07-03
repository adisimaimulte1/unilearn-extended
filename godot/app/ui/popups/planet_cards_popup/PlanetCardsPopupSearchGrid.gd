extends "res://app/ui/popups/planet_cards_popup/PlanetCardsPopupGenerate.gd"

const PROGRESSIVE_CARD_INITIAL_BATCH_SIZE := 1
const PROGRESSIVE_CARD_BATCH_SIZE := 1
const PROGRESSIVE_CARD_FRAME_BUDGET_MSEC := 3

const CARD_ACTIVE_VIEWPORT_MARGIN := 620.0
const CARD_LAYOUT_REFRESH_EVERY := 10
const CARD_ANIMATION_LIMIT := 4

var _search_haystack_cache: Dictionary = {}
var _runtime_visibility_update_pending := false
var _scroll_visibility_signal_connected := false
var _grid_cards_by_id: Dictionary = {}
var _grid_cards_pool_by_id: Dictionary = {}


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

	_request_search_rebuild(text)


func _request_search_rebuild(text: String) -> void:
	_search_rebuild_serial += 1
	var local_serial := _search_rebuild_serial
	await get_tree().create_timer(0.10).timeout
	if local_serial != _search_rebuild_serial or _closing or not _grid_ready:
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
	_play_sfx("click")
	if not is_instance_valid(_search_box):
		return

	_search_box.text = ""
	_update_search_clear_button()

	if _grid_ready:
		_request_search_rebuild("")


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

	var q := query.strip_edges().to_lower()
	var should_animate_cards := not _first_grid_rebuild_done
	_first_grid_rebuild_done = true

	_connect_scroll_runtime_visibility_signal()

	if is_instance_valid(_scroll) and not should_animate_cards:
		_scroll.scroll_vertical = 0
		_scroll_velocity = 0.0
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS

	await _refresh_grid_visibility(q, local_generation, should_animate_cards, false)


func _refresh_grid_visibility(q: String, local_generation: int, should_animate_new_cards: bool, preserve_scroll: bool = true) -> void:
	if local_generation != _rebuild_generation or _closing or not is_instance_valid(_grid):
		return

	var saved_scroll := _scroll.scroll_vertical if is_instance_valid(_scroll) else 0
	var existing_ids := {}
	var match_ids := {}
	var matches: Array[PlanetData] = []

	for planet_data in _all_planets:
		if planet_data == null:
			continue
		var id := _planet_card_runtime_id(planet_data)
		if id.is_empty():
			continue
		existing_ids[id] = true
		if _planet_matches_query(planet_data, q):
			match_ids[id] = true
			matches.append(planet_data)

	matches.sort_custom(func(a: PlanetData, b: PlanetData) -> bool:
		return _planet_card_sort_key(a) < _planet_card_sort_key(b)
	)

	# Remove only cards that no longer exist in the cache. Search filtering never
	# frees preview nodes, so animated planet previews do not reload per keystroke.
	for id in _grid_cards_pool_by_id.keys().duplicate():
		if existing_ids.has(id):
			continue
		var stale = _grid_cards_pool_by_id.get(id, null)
		_grid_cards_pool_by_id.erase(id)
		_grid_cards_by_id.erase(id)
		if stale != null and is_instance_valid(stale):
			stale.queue_free()

	for id in _grid_cards_pool_by_id.keys():
		var card = _grid_cards_pool_by_id.get(id, null)
		if card == null or not is_instance_valid(card):
			continue
		card.visible = match_ids.has(id)
		card.modulate.a = 1.0
		card.scale = Vector2.ONE

	if matches.is_empty():
		_grid.visible = false
		_grid.modulate.a = 1.0
		_grid.position = Vector2.ZERO

		if is_instance_valid(_no_results_label):
			_no_results_label.visible = true
			_no_results_label.text = _no_results_text(q)
			_no_results_label.add_theme_color_override("font_color", COLOR_SUBTITLE)
			_update_no_results_height()

		call_deferred("_style_scroll_bar")
		call_deferred("_update_no_results_height")
		if preserve_scroll:
			call_deferred("_restore_planet_cards_scroll", saved_scroll)
		return

	_grid.visible = true
	_grid.modulate.a = 1.0
	_grid.position = Vector2.ZERO

	if is_instance_valid(_no_results_label):
		_no_results_label.visible = false
		_no_results_label.text = ""
		_no_results_label.add_theme_color_override("font_color", COLOR_SUBTITLE)

	await _build_grid_cards_progressively(matches, local_generation, should_animate_new_cards)

	if preserve_scroll:
		call_deferred("_restore_planet_cards_scroll", saved_scroll)


func _no_results_text(q: String) -> String:
	if q.strip_edges().is_empty():
		return "NO PLANETS AVAILABLE"
	return "NO MATCH. MAX CARDS" if _is_planet_card_limit_reached() else "NO MATCH. NEW PLANET?"


func _get_matching_cards(q: String) -> Array[PlanetData]:
	var matches: Array[PlanetData] = []

	for planet_data in _all_planets:
		if planet_data == null:
			continue

		if _planet_matches_query(planet_data, q):
			matches.append(planet_data)

	matches.sort_custom(func(a: PlanetData, b: PlanetData) -> bool:
		return _planet_card_sort_key(a) < _planet_card_sort_key(b)
	)

	return matches


func _clear_grid_children_deferred() -> void:
	if not is_instance_valid(_grid):
		return
	for child in _grid.get_children():
		if child is Control:
			(child as Control).visible = false


func _kill_existing_card_tweens() -> void:
	if not is_instance_valid(_grid):
		return

	for child in _grid.get_children():
		if child is Control:
			var control := child as Control
			control.modulate.a = 1.0
			control.scale = Vector2.ONE


func _build_grid_cards_progressively(matches: Array[PlanetData], local_generation: int, should_animate_cards: bool) -> void:
	var built_count := 0
	var visible_index := 0
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

			var id := _planet_card_runtime_id(planet_data)
			if id.is_empty():
				continue

			var card = _grid_cards_pool_by_id.get(id, null)
			var is_new := false
			var signature := _planet_card_signature(planet_data)

			if card == null or not is_instance_valid(card):
				card = PREVIEW_SCRIPT.new()
				is_new = true
				card.mouse_filter = Control.MOUSE_FILTER_PASS
				card.focus_mode = Control.FOCUS_NONE
				card.modulate.a = 0.0 if should_animate_cards and built_count < CARD_ANIMATION_LIMIT else 1.0
				card.scale = CARD_ENTER_SCALE if should_animate_cards and built_count < CARD_ANIMATION_LIMIT else Vector2.ONE
				card.setup(planet_data)
				_grid_cards_pool_by_id[id] = card
				card.selected.connect(_open_details)
				_force_card_scroll_compatibility(card)
				_grid.add_child(card)
			else:
				if card.get_parent() != _grid:
					_grid.add_child(card)
				if str(card.get_meta("planet_card_signature", "")) != signature:
					if card.has_method("setup"):
						card.call("setup", planet_data)

			_register_grid_card(card, planet_data)
			card.visible = true
			_grid.move_child(card, visible_index)

			if is_new and should_animate_cards and built_count < CARD_ANIMATION_LIMIT:
				_animate_card_in(card, built_count)
			else:
				card.modulate.a = 1.0
				card.scale = Vector2.ONE

			visible_index += 1
			built_count += 1
			batch_count += 1

		if built_count % CARD_LAYOUT_REFRESH_EVERY == 0:
			call_deferred("_style_scroll_bar")
			call_deferred("_update_no_results_height")
			_request_runtime_visibility_update()

		await get_tree().process_frame

	if local_generation != _rebuild_generation or _closing or not is_instance_valid(_grid):
		return

	_grid.visible = visible_index > 0

	if is_instance_valid(_no_results_label):
		_no_results_label.visible = visible_index <= 0
		_no_results_label.text = "NO CARDS FOUND" if visible_index <= 0 else ""

	call_deferred("_style_scroll_bar")
	call_deferred("_update_no_results_height")
	_request_runtime_visibility_update()


func _register_grid_card(card: Control, planet_data: PlanetData) -> void:
	if card == null or planet_data == null:
		return
	var id := _planet_card_runtime_id(planet_data)
	if id.is_empty():
		return
	card.set_meta("planet_card_id", id)
	card.set_meta("planet_card_signature", _planet_card_signature(planet_data))
	_grid_cards_by_id[id] = card


func _planet_card_runtime_id(planet_data: PlanetData) -> String:
	if planet_data == null:
		return ""
	var id := str(planet_data.instance_id).strip_edges()
	if id.is_empty():
		id = planet_data.name.strip_edges()
	return id


func _apply_planet_cards_delta(cards: Array[PlanetData]) -> bool:
	if not _intro_done or not _grid_ready or not is_instance_valid(_grid):
		return false
	if not is_instance_valid(_search_box):
		return false

	_all_planets = cards.duplicate()
	_rebuild_generation += 1
	var local_generation := _rebuild_generation
	var q := _search_box.text.strip_edges().to_lower()
	_refresh_grid_visibility(q, local_generation, false, true)
	return true


func _planet_card_sort_key(planet_data: PlanetData) -> String:
	if planet_data == null:
		return ""
	var name_key := planet_data.name.strip_edges().to_lower()
	if name_key.is_empty():
		name_key = planet_data.instance_id.strip_edges().to_lower()
	return "%s|%s" % [name_key, _planet_card_runtime_id(planet_data).to_lower()]


func _planet_card_signature(planet_data: PlanetData) -> String:
	if planet_data == null:
		return ""
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		str(_planet_data_safe_get(planet_data, "instance_id", "")),
		str(_planet_data_safe_get(planet_data, "name", "")),
		str(_planet_data_safe_get(planet_data, "subtitle", "")),
		str(_planet_data_safe_get(planet_data, "planet_preset", "")),
		str(_planet_data_safe_get(planet_data, "planet_seed", 0)),
		str(_planet_data_safe_get(planet_data, "planet_radius_px", 0)),
		str(_planet_data_safe_get(planet_data, "game_level", 0)),
		str(_planet_data_safe_get(planet_data, "game_xp", 0)),
		str(_planet_data_safe_get(planet_data, "game_xp_to_next", 0)),
		str(_planet_data_safe_get(planet_data, "game_stats", [])),
	]


func _planet_data_safe_get(planet_data: PlanetData, property_name: String, fallback):
	if planet_data == null:
		return fallback
	for property_info in planet_data.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			return planet_data.get(property_name)
	return fallback


func _restore_planet_cards_scroll(value: int) -> void:
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(clamp(float(value), 0.0, _get_max_scroll()))

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

	card.scale = Vector2.ONE
	if _should_reduce_motion():
		card.modulate.a = 1.0
		return

	var delay: float = min(float(index % 2) * CARD_ENTER_STAGGER, 0.035)
	var tween := create_tween()
	tween.tween_property(card, "modulate:a", 1.0, CARD_ENTER_TIME) \
		.set_delay(delay) \
		.set_trans(Tween.TRANS_SINE) \
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


func _open_details(planet_data: PlanetData, play_transition_sfx: bool = false) -> void:
	if planet_data == null:
		return

	_release_search_focus()
	_details_opened_from_scene = play_transition_sfx
	_details_saved_scroll = _scroll.scroll_vertical if is_instance_valid(_scroll) else 0

	if play_transition_sfx:
		_play_sfx("open")

	# Important performance fix:
	# Do NOT hide _main_view. Hiding/showing the whole list forces Godot to wake,
	# relayout, and restart a lot of heavy preview controls when returning from
	# details. Instead, keep the list alive exactly as it is and place details as
	# a full-screen overlay above it. Closing the overlay simply reveals the
	# already-running list, so there is no massive "back to list" spike.
	if is_instance_valid(_details_view):
		_details_view.queue_free()
		_details_view = null

	if is_instance_valid(_details_overlay_backdrop):
		_details_overlay_backdrop.queue_free()
		_details_overlay_backdrop = null

	_details_overlay_backdrop = Panel.new()
	_details_overlay_backdrop.name = "PlanetCardDetailsBackdrop"
	_details_overlay_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_details_overlay_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	(_details_overlay_backdrop as Panel).add_theme_stylebox_override("panel", _details_overlay_panel_style())

	_details_view = DETAILS_SCRIPT.new() as PlanetCardDetails

	if _details_view == null:
		push_error("PlanetCardsPopup: Could not create PlanetCardDetails from DETAILS_SCRIPT.")
		if is_instance_valid(_details_overlay_backdrop):
			_details_overlay_backdrop.queue_free()
			_details_overlay_backdrop = null
		return

	_details_view.name = "PlanetCardDetailsView"
	_details_view.visible = false
	_details_view.modulate.a = 0.0
	_details_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_details_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_details_view.setup(planet_data)

	var already_added := _query_planet_added_state(planet_data)

	if _details_view.has_method("set_planet_added"):
		_details_view.call("set_planet_added", already_added)

	_update_details_scene_limit_state()

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

	var target_parent: Node = _body_root if is_instance_valid(_body_root) else self
	target_parent.add_child(_details_overlay_backdrop)
	target_parent.add_child(_details_view)

	# Keep the list nodes alive to avoid the back-navigation lag, but snap only
	# the list CONTENT invisible. The panel itself stays untouched, so its white
	# rounded border remains fully opaque and does not get shaved/faded.
	if is_instance_valid(_main_view):
		_main_view.visible = true
		_main_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_main_view.modulate.a = 0.0

	_details_overlay_backdrop.modulate.a = 1.0
	_details_view.position = Vector2.ZERO
	call_deferred("_settle_and_show_details_view")


func _settle_and_show_details_view() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_details_view):
		_details_view.visible = true
		_details_view.modulate.a = 1.0
		_details_view.scale = Vector2.ONE

func _query_scene_body_limit_reached() -> bool:
	var scene := get_tree().current_scene

	if scene != null and scene.has_method("is_simulation_body_limit_reached"):
		return bool(scene.call("is_simulation_body_limit_reached"))

	var parent := get_parent()

	while parent != null:
		if parent.has_method("is_simulation_body_limit_reached"):
			return bool(parent.call("is_simulation_body_limit_reached"))
		parent = parent.get_parent()

	return false


func _update_details_scene_limit_state() -> void:
	if not is_instance_valid(_details_view):
		return
	if _details_view.has_method("set_scene_body_limit_reached"):
		_details_view.call("set_scene_body_limit_reached", _query_scene_body_limit_reached())


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
	if _details_opened_from_scene:
		_play_sfx("close")

	_details_opened_from_scene = false

	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(clamp(float(_details_saved_scroll), 0.0, _get_max_scroll()))
		_scroll_velocity = 0.0

	var details := _details_view
	var backdrop := _details_overlay_backdrop
	_details_view = null
	_details_overlay_backdrop = null

	# No fade-out here. The details layer disappears immediately, then the
	# already-alive card list snaps back. This avoids the ugly moment where the
	# cards become visible through a fading details page.
	if is_instance_valid(details):
		details.modulate.a = 0.0
		details.queue_free()

	if is_instance_valid(backdrop):
		backdrop.modulate.a = 0.0
		backdrop.queue_free()

	if is_instance_valid(_main_view):
		_main_view.visible = true
		_main_view.mouse_filter = Control.MOUSE_FILTER_PASS
		_main_view.modulate.a = 1.0

	# No full-grid visibility rebuild here. The cards never left the tree, so
	# there is nothing expensive to wake back up.
	_request_runtime_visibility_update()


func _details_overlay_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.96)
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(44)
	return style

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

	if _query_scene_body_limit_reached() and not _query_planet_added_state(data):
		_update_details_scene_limit_state()
		return

	planet_add_requested.emit(data)
	call_deferred("_update_details_scene_limit_state_deferred")


func _on_details_remove_planet_requested(data: PlanetData) -> void:
	if data == null:
		return

	planet_remove_requested.emit(data)
	call_deferred("_update_details_scene_limit_state_deferred")


func _on_planet_cards_cache_invalidated() -> void:
	_search_haystack_cache.clear()


func _update_details_scene_limit_state_deferred() -> void:
	await get_tree().process_frame
	_update_details_scene_limit_state()

extends "res://app/ui/popups/planet_cards_popup/PlanetCardsPopupView.gd"


func _show_low_bar(_message: String, _is_error: bool = false, _sticky: bool = false) -> void:
	pass


func _hide_low_bar() -> void:
	if not is_instance_valid(_low_bar):
		return

	_low_bar_serial += 1

	if _low_bar_tween != null and _low_bar_tween.is_valid():
		_low_bar_tween.kill()

	_low_bar.visible = false
	_low_bar.modulate.a = 0.0
	_layout_low_bar()


func _start_add_button_press(pointer_id: int) -> void:
	if not is_instance_valid(_add_button) or _is_add_button_locked():
		return

	_add_button_pointer_id = pointer_id
	_add_button_pressed = true
	_add_button.queue_redraw()

	if not reduce_motion_enabled:
		_bounce_add_button_down()


func _update_add_button_pressed_visual(screen_position: Vector2) -> void:
	if not is_instance_valid(_add_button) or _is_add_button_locked():
		return

	var inside := _add_button.get_global_rect().has_point(screen_position)

	if _add_button_pressed != inside:
		_add_button_pressed = inside
		_add_button.queue_redraw()


func _finish_add_button_press(screen_position: Vector2) -> void:
	if not is_instance_valid(_add_button):
		_add_button_pointer_id = -999
		return

	if _is_add_button_locked():
		_add_button_pointer_id = -999
		_add_button_pressed = false
		_add_button.queue_redraw()
		return

	var released_inside := _add_button.get_global_rect().has_point(screen_position)

	_add_button_pointer_id = -999
	_add_button_pressed = false
	_add_button.queue_redraw()

	if released_inside:
		if not reduce_motion_enabled:
			_bounce_add_button_release()

		_press_create_planet_button(_add_button)
	else:
		if not reduce_motion_enabled:
			_bounce_add_button_cancel()


@warning_ignore("unused_parameter")
func _press_create_planet_button(button: Control) -> void:
	if _is_add_button_locked():
		_play_sfx("error")
		return

	if not is_instance_valid(_search_box):
		return

	var query := _search_box.text.strip_edges()

	if query.is_empty():
		_play_sfx("error")
		return

	var match_count := _get_search_match_count(query)

	if match_count > 0:
		_play_sfx("error")
		return

	_submit_generate_planet_request(query)


func _submit_generate_planet_request(query: String) -> void:
	query = query.strip_edges()

	if _is_add_button_locked():
		_play_sfx("error")
		return

	if query.length() < 2:
		_play_sfx("error")
		return

	if not has_node("/root/PlanetCardsCache"):
		_play_sfx("error")
		return

	if not PlanetCardsCache.has_method("generate_card_in_background"):
		_play_sfx("error")
		return

	var started: bool = PlanetCardsCache.generate_card_in_background(query)

	if not started:
		_play_sfx("error")
		return

	_play_sfx("success")

	_add_button_generating = true
	_add_button_generation_query = query

	if PlanetCardsCache.has_method("normalize_card_id"):
		_add_button_generation_id = str(PlanetCardsCache.normalize_card_id(query))
	else:
		_add_button_generation_id = _normalize_button_sync_id(query)

	_release_search_focus()
	_clear_search_after_generation_started()
	_sync_generate_button_ui(false)


func _clear_search_after_generation_started() -> void:
	if not is_instance_valid(_search_box):
		return

	_search_box.text = ""
	_search_box.placeholder_text = SEARCH_PLACEHOLDER

	_update_search_clear_button()

	if _grid_ready:
		_rebuild_grid("")


@warning_ignore("unused_parameter")
func _on_generate_planet_request_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	pass


func _add_generated_card_to_cache(planet_data: PlanetData) -> void:
	if planet_data == null:
		return

	if has_node("/root/PlanetCardsCache"):
		if PlanetCardsCache.has_method("add_or_update_card"):
			PlanetCardsCache.add_or_update_card(planet_data)
			return

	_all_planets = _upsert_planet_data(_all_planets, planet_data)

	if _grid_ready:
		_rebuild_grid("")


func _upsert_planet_data(cards: Array[PlanetData], planet_data: PlanetData) -> Array[PlanetData]:
	var result: Array[PlanetData] = []
	var inserted := false

	for existing in cards:
		if existing == null:
			continue

		if existing.instance_id == planet_data.instance_id:
			result.append(planet_data)
			inserted = true
		else:
			result.append(existing)

	if not inserted:
		result.append(planet_data)

	return result


func _set_generate_busy(value: bool) -> void:
	_generate_busy = value
	_sync_generate_button_ui(false)


func _sync_generate_button_ui(immediate: bool = false) -> void:
	if not is_instance_valid(_add_button):
		return

	var target_blend := 1.0 if _add_button_generating else 0.0
	var target_scale := ADD_BUTTON_GENERATING_SCALE if _add_button_generating else Vector2.ONE

	if _add_button_bounce_tween != null and _add_button_bounce_tween.is_valid():
		_add_button_bounce_tween.kill()

	if _add_button_color_tween != null and _add_button_color_tween.is_valid():
		_add_button_color_tween.kill()

	_add_button.mouse_filter = Control.MOUSE_FILTER_IGNORE if _add_button_generating else Control.MOUSE_FILTER_STOP

	if immediate or _should_reduce_motion():
		_set_add_button_highlight_blend(target_blend)
		_add_button.scale = target_scale
		_add_button.queue_redraw()
		return

	_add_button_color_tween = create_tween()
	_add_button_color_tween.set_parallel(true)

	_add_button_color_tween.tween_method(
		Callable(self, "_set_add_button_highlight_blend"),
		_add_button_highlight_blend,
		target_blend,
		ADD_BUTTON_COLOR_TWEEN_TIME
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_add_button_color_tween.tween_property(
		_add_button,
		"scale",
		target_scale,
		ADD_BUTTON_COLOR_TWEEN_TIME
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _is_add_button_locked() -> bool:
	return _add_button_generating


func _get_search_match_count(query: String) -> int:
	var q := query.strip_edges().to_lower()

	if q.is_empty():
		return 0

	if has_node("/root/PlanetCardsCache") and PlanetCardsCache.has_method("has_matching_card"):
		if PlanetCardsCache.has_matching_card(query):
			return 1

	var count := 0

	for planet_data in _all_planets:
		if planet_data == null:
			continue

		if _planet_matches_query(planet_data, q):
			count += 1

	return count


func _get_unilearn_id_token() -> String:
	if has_node("/root/UnilearnAuth"):
		var auth := get_node("/root/UnilearnAuth")

		if auth.has_method("get_fresh_id_token"):
			return str(await auth.get_fresh_id_token())

		if auth.has_method("get_id_token"):
			return str(auth.get_id_token())

		if "id_token" in auth:
			return str(auth.id_token)

	if has_node("/root/FirebaseAuth"):
		var firebase_auth := get_node("/root/FirebaseAuth")

		if firebase_auth.has_method("get_fresh_id_token"):
			return str(await firebase_auth.get_fresh_id_token())

		if firebase_auth.has_method("get_id_token"):
			return str(firebase_auth.get_id_token())

		if "id_token" in firebase_auth:
			return str(firebase_auth.id_token)

	if has_node("/root/UnilearnUser"):
		var user := get_node("/root/UnilearnUser")

		if user.has_method("get_fresh_id_token"):
			return str(await user.get_fresh_id_token())

		if user.has_method("get_id_token"):
			return str(user.get_id_token())

		if "id_token" in user:
			return str(user.id_token)

	return ""


func _bounce_add_button_down() -> void:
	if not is_instance_valid(_add_button) or _is_add_button_locked():
		return

	if _add_button_bounce_tween != null and _add_button_bounce_tween.is_valid():
		_add_button_bounce_tween.kill()

	_add_button.pivot_offset = _add_button.size * 0.5

	_add_button_bounce_tween = create_tween()
	_add_button_bounce_tween.set_trans(Tween.TRANS_BACK)
	_add_button_bounce_tween.set_ease(Tween.EASE_OUT)
	_add_button_bounce_tween.tween_property(_add_button, "scale", ADD_BUTTON_PRESS_SCALE, ADD_BUTTON_DOWN_TIME)


func _bounce_add_button_release() -> void:
	if not is_instance_valid(_add_button) or _is_add_button_locked():
		return

	if _add_button_bounce_tween != null and _add_button_bounce_tween.is_valid():
		_add_button_bounce_tween.kill()

	_add_button.pivot_offset = _add_button.size * 0.5

	_add_button_bounce_tween = create_tween()
	_add_button_bounce_tween.set_trans(Tween.TRANS_BACK)
	_add_button_bounce_tween.set_ease(Tween.EASE_OUT)
	_add_button_bounce_tween.tween_property(_add_button, "scale", ADD_BUTTON_RELEASE_SCALE, ADD_BUTTON_UP_TIME)
	_add_button_bounce_tween.tween_property(_add_button, "scale", Vector2.ONE, ADD_BUTTON_SETTLE_TIME)


func _bounce_add_button_cancel() -> void:
	if not is_instance_valid(_add_button) or _is_add_button_locked():
		return

	if _add_button_bounce_tween != null and _add_button_bounce_tween.is_valid():
		_add_button_bounce_tween.kill()

	_add_button.pivot_offset = _add_button.size * 0.5

	_add_button_bounce_tween = create_tween()
	_add_button_bounce_tween.set_trans(Tween.TRANS_BACK)
	_add_button_bounce_tween.set_ease(Tween.EASE_OUT)
	_add_button_bounce_tween.tween_property(_add_button, "scale", Vector2.ONE, ADD_BUTTON_SETTLE_TIME)


func _normalize_button_sync_id(value: String) -> String:
	var result := value.strip_edges().to_lower()
	result = result.replace("'", "")
	result = result.replace("\"", "")
	result = result.replace(" ", "_")
	result = result.replace("-", "_")
	result = result.replace(".", "_")
	result = result.replace(",", "_")
	result = result.replace(":", "_")
	result = result.replace(";", "_")
	result = result.replace("/", "_")
	result = result.replace("\\", "_")

	while result.contains("__"):
		result = result.replace("__", "_")

	return result.strip_edges()

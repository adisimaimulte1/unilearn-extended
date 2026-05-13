extends "res://addons/UnilearnLib/planet_cards/details/PlanetCardDetailsLearning.gd"

func _add_footer() -> void:
	var footer := _make_label(
		"AI can make mistakes. Verify important scientific information.",
		34,
		Color.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER,
		true
	)
	footer.custom_minimum_size = Vector2(0, 90)
	_content.add_child(footer)


func _build_highlighted_description_bbcode() -> String:
	var words := data.description.split(" ", false)
	var highlight_map := {}

	for index in data.description_highlight_indices:
		highlight_map[int(index)] = true

	var result := ""

	for i in range(words.size()):
		var word := _bbcode_escape(str(words[i]))

		if highlight_map.has(i):
			result += "[color=#%s]%s[/color]" % [_accent_color().to_html(false), word]
		else:
			result += word

		if i < words.size() - 1:
			result += " "

	return result


func _bbcode_escape(value: String) -> String:
	return value.replace("[", "[lb]").replace("]", "[rb]")


func _object_category() -> String:
	if data == null:
		return "planet"

	var clean := data.object_category.strip_edges().to_lower()
	var archetype := data.archetype_id.strip_edges().to_lower()
	var preset := data.planet_preset.strip_edges().to_lower()

	if clean == "moon" or clean == "satellite" or clean == "natural_satellite":
		return "satellite"

	if archetype == "moon" or archetype.contains("moon") or preset == "moon":
		return "satellite"

	if clean.is_empty():
		if archetype.contains("star") or preset.contains("star"):
			return "star"

		if archetype.contains("dwarf"):
			return "dwarf_planet"

		return "planet"

	return clean


func _satellite_field_title() -> String:
	match _object_category():
		"star":
			return "Planets"

		"satellite":
			return "Parent"

		"moon":
			return "Parent"

		_:
			return "Moons"


func _value_or_unknown(value: String) -> String:
	if value.strip_edges().is_empty():
		return "unknown"

	return value


func _toggle_add_planet() -> void:
	_planet_added = not _planet_added
	_update_add_planet_button_style()

	if _planet_added:
		add_planet_requested.emit(data)
	else:
		remove_planet_requested.emit(data)

func _update_add_planet_button_style() -> void:
	if not is_instance_valid(_add_planet_button):
		return

	if _planet_added:
		_add_planet_button.text = "REMOVE"
		_add_planet_button.add_theme_color_override("font_color", _accent_color())
		_add_planet_button.add_theme_color_override("font_hover_color", _accent_color())
		_add_planet_button.add_theme_color_override("font_pressed_color", _accent_color())
		_add_planet_button.add_theme_stylebox_override("normal", _add_button_style(false, true))
		_add_planet_button.add_theme_stylebox_override("hover", _add_button_style(true, true))
		_add_planet_button.add_theme_stylebox_override("pressed", _add_button_style(true, true))
	else:
		_add_planet_button.text = "ADD"
		_add_planet_button.add_theme_color_override("font_color", Color.BLACK)
		_add_planet_button.add_theme_color_override("font_hover_color", Color.BLACK)
		_add_planet_button.add_theme_color_override("font_pressed_color", Color.BLACK)
		_add_planet_button.add_theme_stylebox_override("normal", _add_button_style(false, false))
		_add_planet_button.add_theme_stylebox_override("hover", _add_button_style(true, false))
		_add_planet_button.add_theme_stylebox_override("pressed", _add_button_style(true, false))


func _on_header_button_down(button: Control) -> void:
	if not is_instance_valid(button):
		return

	_play_sfx("click")
	_tween_header_button_down(button)

func _on_header_button_up(button: Control) -> void:
	if not is_instance_valid(button):
		return

	_tween_header_button_release(button)


func _tween_header_button_down(button: Control) -> void:
	if not is_instance_valid(button):
		return

	button.pivot_offset = button.size * 0.5

	if _button_tweens.has(button):
		var old_tween: Tween = _button_tweens[button]
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", BUTTON_PRESS_SCALE, BUTTON_DOWN_TIME)

	_button_tweens[button] = tween

func _tween_header_button_release(button: Control) -> void:
	if not is_instance_valid(button):
		return

	button.pivot_offset = button.size * 0.5

	if _button_tweens.has(button):
		var old_tween: Tween = _button_tweens[button]
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", BUTTON_RELEASE_SCALE, BUTTON_UP_TIME)
	tween.tween_property(button, "scale", Vector2.ONE, BUTTON_SETTLE_TIME)

	_button_tweens[button] = tween

func _tween_header_button_cancel(button: Control) -> void:
	if not is_instance_valid(button):
		return

	button.pivot_offset = button.size * 0.5

	if _button_tweens.has(button):
		var old_tween: Tween = _button_tweens[button]
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, BUTTON_SETTLE_TIME)

	_button_tweens[button] = tween


func _draw_hero_stars() -> void:
	if not is_instance_valid(_hero_stars):
		return

	var area_size := _hero_stars.size

	if area_size.x <= 0.0 or area_size.y <= 0.0:
		return

	for i in range(HERO_STAR_COUNT):
		var x := _hash01(i, 11, HERO_STAR_SEED) * area_size.x
		var y := _hash01(i, 23, HERO_STAR_SEED) * area_size.y
		var r := lerp(1.2, 3.8, _hash01(i, 37, HERO_STAR_SEED))
		var a := lerp(0.35, 0.95, _hash01(i, 41, HERO_STAR_SEED))

		_hero_stars.draw_circle(
			Vector2(x, y),
			r,
			Color(1.0, 1.0, 1.0, a)
		)


func _hash01(a: int, b: int, seed: int) -> float:
	var n := seed
	n ^= a * 374761393
	n ^= b * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / 2147483647.0


func _handle_hero_input(event: InputEvent) -> bool:
	if not is_instance_valid(_hero_area):
		return false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _is_inside_interactive_header(event.position):
				return false

			if _is_inside_hero_area(event.position):
				_start_hero_drag(-2, event.position)
				return true
		else:
			if _hero_pointer_id == -2:
				_finish_hero_drag()
				return true

		return false

	if event is InputEventMouseMotion:
		if _hero_pointer_id == -2:
			_update_hero_drag(event.position)

			if _hero_dragging:
				get_viewport().set_input_as_handled()

			return true

		return false

	if event is InputEventScreenTouch:
		if event.pressed:
			if _is_inside_interactive_header(event.position):
				return false

			if _is_inside_hero_area(event.position):
				_start_hero_drag(event.index, event.position)
				return true
		else:
			if event.index == _hero_pointer_id:
				_finish_hero_drag()
				return true

		return false

	if event is InputEventScreenDrag:
		if event.index == _hero_pointer_id:
			_update_hero_drag(event.position)

			if _hero_dragging:
				get_viewport().set_input_as_handled()

			return _hero_pointer_id != -999

		return false

	return false

func _start_hero_drag(pointer_id: int, pos: Vector2) -> void:
	_hero_pointer_id = pointer_id
	_hero_dragging = false
	_hero_scroll_locked = false
	_hero_drag_start = pos
	_hero_manual_animation_time = _get_planet_animation_time()
	_hero_base_turning_speed = data.planet_turning_speed

	_scroll_pointer_id = -999
	_scroll_dragging = false
	_scroll_velocity = 0.0

func _update_hero_drag(pos: Vector2) -> void:
	if _hero_pointer_id == -999:
		return

	var total := pos - _hero_drag_start

	if not _hero_dragging:
		if max(abs(total.x), abs(total.y)) < HERO_DRAG_DEADZONE:
			return

		if abs(total.y) > abs(total.x):
			_hero_pointer_id = -999
			_hero_dragging = false
			_hero_scroll_locked = false
			_hero_drag_start = Vector2.ZERO
			_hero_manual_animation_time = 0.0
			_set_scroll_locked(false)
			_start_scroll_drag_from_position(pos)
			return

		_hero_dragging = true
		_hero_scroll_locked = true
		_set_scroll_locked(true)

		_scroll_pointer_id = -999
		_scroll_dragging = false
		_scroll_velocity = 0.0

	var delta_x := pos.x - _hero_drag_start.x

	if abs(delta_x) <= HERO_DRAG_MIN_DELTA:
		return

	_hero_manual_animation_time += delta_x * HERO_DRAG_TIME_SENSITIVITY
	_hero_drag_start = pos

	_set_planet_animation_time(_hero_manual_animation_time)

func _finish_hero_drag() -> void:
	if is_instance_valid(_planet_node):
		_set_planet_animation_time(_hero_manual_animation_time)
		_planet_node.set("turning_speed", _hero_base_turning_speed)

	data.planet_turning_speed = _hero_base_turning_speed

	_hero_pointer_id = -999
	_hero_dragging = false
	_hero_scroll_locked = false
	_hero_drag_start = Vector2.ZERO
	_hero_manual_animation_time = 0.0

	_set_scroll_locked(false)


func _set_scroll_locked(locked: bool) -> void:
	if not is_instance_valid(_scroll):
		return

	if locked:
		_scroll_velocity = 0.0
		_scroll_pointer_id = -999
		_scroll_dragging = false


func _get_planet_animation_time() -> float:
	if not is_instance_valid(_planet_node):
		return 0.0

	var current_time = _planet_node.get("_animation_time")

	if current_time == null:
		return 0.0

	return float(current_time)

func _set_planet_animation_time(value: float) -> void:
	if not is_instance_valid(_planet_node):
		return

	_planet_node.set("_animation_time", value)

	var inner_planet = _planet_node.get("_planet")

	if inner_planet != null and inner_planet.has_method("update_time"):
		inner_planet.call("update_time", value)


func _start_scroll_drag_from_position(screen_position: Vector2) -> void:
	_scroll_pointer_id = -2
	_scroll_dragging = false
	_scroll_start_y = screen_position.y
	_scroll_last_y = screen_position.y
	_scroll_last_time = Time.get_ticks_msec() / 1000.0
	_scroll_velocity = 0.0


func _center_hero_planet() -> void:
	if not is_instance_valid(_hero_clip) or not is_instance_valid(_planet_node):
		return

	var available_diameter: float = min(_hero_clip.size.x, _hero_clip.size.y) * HERO_BODY_MAX_FILL
	var planet_body_diameter: float = max(float(data.planet_radius_px) * 2.0, 1.0)
	var preview_scale: float = min(1.0, available_diameter / planet_body_diameter)

	_planet_node.scale = Vector2.ONE * preview_scale
	_planet_node.position = _hero_clip.size * 0.5


func _apply_planet_data(planet: Node2D, planet_data: PlanetData, radius: int) -> void:
	planet.set("preset", planet_data.planet_preset)
	planet.set("radius_px", radius)
	planet.set("render_pixels", planet_data.planet_pixels)
	planet.set("seed_value", planet_data.planet_seed)
	planet.set("turning_speed", planet_data.planet_turning_speed)
	planet.set("axial_tilt_deg", planet_data.planet_axial_tilt_deg)
	planet.set("ring_angle_deg", planet_data.planet_ring_angle_deg)
	planet.set("debug_border_enabled", false)
	planet.set("draggable", false)
	planet.set("use_custom_colors", planet_data.use_custom_colors)
	planet.set("custom_colors", planet_data.custom_colors)

	if planet.has_method("rebuild"):
		planet.call("rebuild")


func _handle_slippery_scroll_input(event: InputEvent) -> void:
	if not is_instance_valid(_scroll):
		return
	
	if _hero_scroll_locked:
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _scroll_pointer_id == -2:
				if _scroll_dragging:
					get_viewport().set_input_as_handled()

				_scroll_pointer_id = -999
				_scroll_dragging = false

			return

		if not _is_inside_scroll(event.position):
			return

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_scroll_velocity += _scroll_wheel_impulse
			_scroll_velocity = clamp(_scroll_velocity, -_scroll_max_velocity, _scroll_max_velocity)
			get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_scroll_velocity -= _scroll_wheel_impulse
			_scroll_velocity = clamp(_scroll_velocity, -_scroll_max_velocity, _scroll_max_velocity)
			get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _is_inside_interactive_header(event.position):
				return

			if _is_inside_scroll(event.position):
				_scroll_pointer_id = -2
				_scroll_dragging = false
				_scroll_start_y = event.position.y
				_scroll_last_y = event.position.y
				_scroll_last_time = Time.get_ticks_msec() / 1000.0
				_scroll_velocity = 0.0

	elif event is InputEventMouseMotion:
		if _scroll_pointer_id == -2:
			_apply_manual_scroll(event.position.y)

			if _scroll_dragging:
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenTouch:
		if event.pressed:
			if _is_inside_interactive_header(event.position):
				return

			if _is_inside_scroll(event.position):
				_scroll_pointer_id = event.index
				_scroll_dragging = false
				_scroll_start_y = event.position.y
				_scroll_last_y = event.position.y
				_scroll_last_time = Time.get_ticks_msec() / 1000.0
				_scroll_velocity = 0.0
		else:
			if event.index == _scroll_pointer_id:
				if _scroll_dragging:
					get_viewport().set_input_as_handled()

				_scroll_pointer_id = -999
				_scroll_dragging = false

	elif event is InputEventScreenDrag:
		if event.index == _scroll_pointer_id:
			_apply_manual_scroll(event.position.y)

			if _scroll_dragging:
				get_viewport().set_input_as_handled()

func _apply_manual_scroll(current_y: float) -> void:
	if not is_instance_valid(_scroll):
		return

	var total_delta := _scroll_start_y - current_y

	if abs(total_delta) >= _scroll_drag_deadzone:
		_scroll_dragging = true

	if not _scroll_dragging:
		return

	var now := Time.get_ticks_msec() / 1000.0
	var dt: float = max(0.001, now - _scroll_last_time)
	var frame_delta := _scroll_last_y - current_y

	_scroll_velocity = clamp(frame_delta / dt, -_scroll_max_velocity, _scroll_max_velocity)
	_scroll.scroll_vertical = int(clamp(float(_scroll.scroll_vertical) + frame_delta, 0.0, _get_max_scroll()))

	_scroll_last_y = current_y
	_scroll_last_time = now

func _apply_scroll_inertia(delta: float) -> void:
	if not is_instance_valid(_scroll):
		return

	if _scroll_pointer_id != -999:
		return

	if abs(_scroll_velocity) < 8.0:
		_scroll_velocity = 0.0
		return

	var max_scroll := _get_max_scroll()

	if max_scroll <= 0.0:
		_scroll_velocity = 0.0
		_scroll.scroll_vertical = 0
		return

	var next_scroll := float(_scroll.scroll_vertical) + (_scroll_velocity * delta)

	if next_scroll <= 0.0:
		next_scroll = 0.0
		_scroll_velocity = 0.0
	elif next_scroll >= max_scroll:
		next_scroll = max_scroll
		_scroll_velocity = 0.0
	else:
		_scroll_velocity = lerp(_scroll_velocity, 0.0, 1.0 - exp(-_scroll_friction * delta))

	_scroll.scroll_vertical = int(next_scroll)


func _get_max_scroll() -> float:
	if not is_instance_valid(_scroll):
		return 0.0

	var bar := _scroll.get_v_scroll_bar()

	if bar == null:
		return 0.0

	return max(0.0, bar.max_value - bar.page)


func _is_inside_scroll(screen_position: Vector2) -> bool:
	if not is_instance_valid(_scroll):
		return false

	return _scroll.get_global_rect().has_point(screen_position)

func _is_inside_hero_area(screen_position: Vector2) -> bool:
	if not is_instance_valid(_hero_area):
		return false

	return _hero_area.get_global_rect().has_point(screen_position)

func _is_inside_interactive_header(screen_position: Vector2) -> bool:
	if is_instance_valid(_back_button) and _back_button.get_global_rect().has_point(screen_position):
		return true

	if is_instance_valid(_add_planet_button) and _add_planet_button.get_global_rect().has_point(screen_position):
		return true

	return false


func _style_scroll_bar() -> void:
	if not is_instance_valid(_scroll):
		return

	var bar := _scroll.get_v_scroll_bar()

	if bar == null:
		return

	bar.visible = true
	bar.modulate.a = 1.0
	bar.custom_minimum_size = Vector2(18, 0)
	bar.add_theme_stylebox_override("scroll", _scroll_track_style())
	bar.add_theme_stylebox_override("grabber", _scroll_grabber_style(COLOR_SCROLL_GRAB))
	bar.add_theme_stylebox_override("grabber_highlight", _scroll_grabber_style(COLOR_SCROLL_GRAB_HOVER))
	bar.add_theme_stylebox_override("grabber_pressed", _scroll_grabber_style(COLOR_SCROLL_GRAB_HOVER))

func _scroll_track_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SCROLL_TRACK
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(999)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _scroll_grabber_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(999)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style

extends "res://app/ui/bottom_menu/BottomMenuLayoutMotion.gd"


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null

	if _texture_cache.has(path):
		return _texture_cache[path]

	if not ResourceLoader.exists(path):
		push_warning("Menu texture missing: " + path)
		_texture_cache[path] = null
		return null

	var texture := load(path) as Texture2D
	_texture_cache[path] = texture
	return texture


func _full_rect(node: Control) -> void:
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 1.0
	node.anchor_bottom = 1.0
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0


func _group_panel_style(color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var key := "group_%s_%s_%d" % [str(color), str(border_color), border_width]

	if _style_cache.has(key):
		return _style_cache[key]

	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(38)

	_style_cache[key] = style
	return style


func _circle_style(color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var key := "circle_%s_%s_%d" % [str(color), str(border_color), border_width]

	if _style_cache.has(key):
		return _style_cache[key]

	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(999)

	_style_cache[key] = style
	return style


func set_reduce_motion_enabled(enabled: bool) -> void:
	if reduce_motion_enabled == enabled:
		return

	reduce_motion_enabled = enabled

	if reduce_motion_enabled:
		if _snap_tween != null and _snap_tween.is_valid():
			_snap_tween.kill()

		for button in _button_tweens.keys():
			if is_instance_valid(button):
				button.scale = Vector2.ONE

		_button_tweens.clear()
		_apply_progress(1.0 if is_open else 0.0)


func _play_sfx(id: String) -> void:
	if _sfx_node != null and _sfx_node.has_method("play"):
		_sfx_node.call("play", id)

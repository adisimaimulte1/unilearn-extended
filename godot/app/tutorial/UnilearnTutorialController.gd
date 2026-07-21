extends CanvasLayer
class_name UnilearnTutorialController

const AUDIO_PATH := "res://assets/audio/ai/tutorial/1.mp3"
const FONT_PATH := "res://assets/fonts/JockeyOne-Regular.ttf"
# Match the standard Planet Cards / Settings / Galaxy popup footprint.
const PANEL_WIDTH_RATIO := 0.78
const PANEL_MAX_WIDTH := 820.0
const POPUP_SLIDE_DURATION := 0.42
const POPUP_FADE_DURATION := 0.22
const DIM_FADE_DURATION := 0.26
const POPUP_SIDE_PADDING := 80.0
const FALLBACK_TUTORIAL_DURATION := 38.0
const OFFER_MAX_HEIGHT := 415.0
const OFFER_MIN_HEIGHT := 365.0
const REMINDER_MAX_HEIGHT := 352.0
const REMINDER_MIN_HEIGHT := 322.0

var _app_screen: Node = null
var _bottom_menu: Node = null
var _ai_assistant: Node = null
var _settings: Node = null
var _screen_root: Control = null
var _input_blocker: Control = null
var _dim: ColorRect = null
var _slide_root: Control = null
var _panel: Panel = null
var _margin: MarginContainer = null
var _content: VBoxContainer = null
var _center_position := Vector2.ZERO
var _audio_player: AudioStreamPlayer = null
var _audio_finished := false
var _accepted := false
var _sequence_running := false
var _sequence_started_msec := 0
var _tutorial_mars_card: PlanetData = null
var _app_font: Font = null
var _music_duck_active := false
var _button_tweens: Dictionary = {}
var _reminder_visible := false
var _background_frozen_by_tutorial := false


func setup(app_screen: Node, bottom_menu: Node, ai_assistant: Node) -> void:
	_app_screen = app_screen
	_bottom_menu = bottom_menu
	_ai_assistant = ai_assistant
	_settings = get_node_or_null("/root/UnilearnUserSettings")
	call_deferred("_show_offer_after_scene_entry")


func setup_for_voice_command(app_screen: Node, bottom_menu: Node, ai_assistant: Node) -> void:
	_app_screen = app_screen
	_bottom_menu = bottom_menu
	_ai_assistant = ai_assistant
	_settings = get_node_or_null("/root/UnilearnUserSettings")
	call_deferred("start_from_voice_command")


func start_from_voice_command() -> void:
	if _sequence_running:
		return
	_accepted = true
	_sequence_running = true
	AIState.set_command("How to use the app", "actions/tutorial/start")
	AIState.set_state(AIState.State.THINKING)
	if is_instance_valid(_panel) and _panel.visible:
		await _hide_modal_animated()
	_set_tutorial_background_frozen(false)
	await get_tree().create_timer(0.18, true, false, true).timeout
	_start_tutorial_audio()
	_duck_music_for_tutorial()
	AIState.set_state(AIState.State.SPEAKING)
	_sequence_started_msec = Time.get_ticks_msec()
	await _run_guided_sequence()
	await _wait_for_audio_end()
	_release_music_duck()
	_complete_tutorial_setting()
	AIState.set_command("", "")
	AIState.set_state(AIState.State.IDLE)
	_sequence_running = false
	queue_free()


func _ready() -> void:
	# Stay above every app popup but below Apollo's dedicated layer, so the
	# thinking/speaking animation remains fully visible over the dimmed app.
	layer = 9900
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _settings == null:
		_settings = get_node_or_null("/root/UnilearnUserSettings")
	_app_font = load(FONT_PATH) as Font
	_build_modal()
	set_process_input(true)
	set_process_unhandled_input(true)
	set_process_unhandled_key_input(true)


func _show_offer_after_scene_entry() -> void:
	await get_tree().create_timer(0.85, true, false, true).timeout
	if not is_inside_tree():
		return
	AIState.set_command("Tutorial", "tutorial")
	AIState.set_state(AIState.State.THINKING)
	_set_tutorial_background_frozen(true)
	_show_modal_animated()


func _build_modal() -> void:
	_screen_root = Control.new()
	_screen_root.name = "TutorialScreenRoot"
	_screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_screen_root)

	_input_blocker = Control.new()
	_input_blocker.name = "TutorialInputBlocker"
	_input_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_input_blocker.gui_input.connect(func(_event: InputEvent) -> void:
		_input_blocker.accept_event()
		if get_viewport() != null:
			get_viewport().set_input_as_handled()
	)
	_screen_root.add_child(_input_blocker)

	_dim = ColorRect.new()
	_dim.name = "TutorialDim"
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.0, 0.0, 0.0, 0.88)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.modulate.a = 0.0
	_dim.visible = false
	_screen_root.add_child(_dim)

	_slide_root = Control.new()
	_slide_root.name = "TutorialSlideRoot"
	_slide_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_root.add_child(_slide_root)
	# Keep the blocker above the dim and below the popup, so only the popup's
	# buttons can receive input and every touch outside them is consumed.
	_screen_root.move_child(_input_blocker, _slide_root.get_index() - 1)

	# A plain Panel is intentional here. PanelContainer grows itself to the
	# combined minimum size of its labels/buttons, which made this popup taller
	# than the viewport on phones with a large UI scale.
	_panel = Panel.new()
	_panel.name = "TutorialConsentPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_slide_root.add_child(_panel)

	_margin = MarginContainer.new()
	_margin.add_theme_constant_override("margin_left", 46)
	_margin.add_theme_constant_override("margin_top", 18)
	_margin.add_theme_constant_override("margin_right", 46)
	_margin.add_theme_constant_override("margin_bottom", 38)
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(_margin)

	_content = VBoxContainer.new()
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 20)
	_margin.add_child(_content)

	var heading_block := VBoxContainer.new()
	heading_block.alignment = BoxContainer.ALIGNMENT_CENTER
	heading_block.add_theme_constant_override("separation", -8)
	_content.add_child(heading_block)

	var title := _label("WELCOME TO UNILEARN!", 76, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	heading_block.add_child(title)

	var subtitle_rows := VBoxContainer.new()
	subtitle_rows.alignment = BoxContainer.ALIGNMENT_CENTER
	subtitle_rows.add_theme_constant_override("separation", 0)
	heading_block.add_child(subtitle_rows)
	var duration_line := _label(
		"CHECK OUT THE TUTORIAL IN UNDER A MINUTE.",
		28,
		Color(1.0, 1.0, 1.0, 0.72),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	var volume_line := _label(
		"TURN UP YOUR VOLUME TO HEAR APOLLO.",
		28,
		Color(1.0, 1.0, 1.0, 0.72),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	duration_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	volume_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	duration_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	volume_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subtitle_rows.add_child(duration_line)
	subtitle_rows.add_child(volume_line)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 22)
	_content.add_child(buttons)

	var decline := _button("NO, THANKS", false)
	var accept := _button("START TUTORIAL", true)
	decline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(decline)
	buttons.add_child(accept)
	decline.pressed.connect(_on_declined)
	accept.pressed.connect(_on_accepted)
	_make_button_bouncy(decline)
	_make_button_bouncy(accept)

	get_viewport().size_changed.connect(_layout_modal)
	call_deferred("_layout_modal")


func _layout_modal() -> void:
	if not is_instance_valid(_panel) or not is_instance_valid(_slide_root):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(viewport_size.x * PANEL_WIDTH_RATIO, PANEL_MAX_WIDTH)
	var height := _popup_height(viewport_size, _reminder_visible)
	_panel.custom_minimum_size = Vector2.ZERO
	_panel.size = Vector2(width, height)
	_panel.position = Vector2.ZERO
	_slide_root.size = _panel.size
	_center_position = (viewport_size - _slide_root.size) * 0.5
	if _slide_root.modulate.a >= 0.99:
		_slide_root.position = _center_position


func _show_modal_animated() -> void:
	_layout_modal()
	_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = true
	_dim.visible = true
	_play_sfx("open")
	if _should_reduce_motion():
		_slide_root.position = _center_position
		_slide_root.modulate.a = 1.0
		_dim.modulate.a = 1.0
		return
	_slide_root.position = _get_left_offscreen_position()
	_slide_root.modulate.a = 0.0
	_dim.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_slide_root, "position", _center_position, POPUP_SLIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_slide_root, "modulate:a", 1.0, POPUP_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_dim, "modulate:a", 1.0, DIM_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _hide_modal_animated() -> void:
	if not is_instance_valid(_panel) or not is_instance_valid(_slide_root):
		return
	if _should_reduce_motion():
		_slide_root.position = _center_position
		_slide_root.modulate.a = 0.0
		_dim.modulate.a = 0.0
		_panel.visible = false
		_dim.visible = false
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_slide_root, "position", _get_right_offscreen_position(), POPUP_SLIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_slide_root, "modulate:a", 0.0, POPUP_FADE_DURATION).set_delay(maxf(0.0, POPUP_SLIDE_DURATION - POPUP_FADE_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_dim, "modulate:a", 0.0, DIM_FADE_DURATION).set_delay(maxf(0.0, POPUP_SLIDE_DURATION - DIM_FADE_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	if is_instance_valid(_panel):
		_panel.visible = false
	if is_instance_valid(_dim):
		_dim.visible = false


func _on_declined() -> void:
	if _sequence_running:
		return
	_play_sfx("click")
	_sequence_running = true
	await _show_tutorial_reminder()
	_sequence_running = false


func _show_tutorial_reminder() -> void:
	if not is_instance_valid(_panel) or not is_instance_valid(_content):
		return
	_play_sfx("whoosh")
	var old_content := _content
	var fade_out := create_tween()
	fade_out.tween_property(old_content, "modulate:a", 0.0, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade_out.finished
	if not is_instance_valid(_panel) or not is_instance_valid(_margin):
		return
	old_content.queue_free()
	_reminder_visible = true

	var viewport_size := get_viewport().get_visible_rect().size
	var target_size := Vector2(
		minf(viewport_size.x * PANEL_WIDTH_RATIO, PANEL_MAX_WIDTH),
		_popup_height(viewport_size, true)
	)
	var target_position := (viewport_size - target_size) * 0.5
	_panel.custom_minimum_size = Vector2.ZERO
	_panel.clip_contents = true
	var resize_tween := create_tween()
	resize_tween.set_parallel(true)
	resize_tween.tween_property(_panel, "size", target_size, 0.30).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	resize_tween.tween_property(_panel, "pivot_offset", target_size * 0.5, 0.30).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	resize_tween.tween_property(_slide_root, "size", target_size, 0.30).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	resize_tween.tween_property(_slide_root, "position", target_position, 0.30).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	await resize_tween.finished
	if not is_instance_valid(_panel):
		return
	_panel.size = target_size
	_panel.pivot_offset = target_size * 0.5
	_slide_root.size = target_size
	_slide_root.position = target_position
	_center_position = target_position
	_build_reminder_content()
	_animate_reminder_content_in()


func _build_reminder_content() -> void:
	_content = VBoxContainer.new()
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 20)
	_content.modulate.a = 0.0
	_margin.add_child(_content)

	var heading_block := VBoxContainer.new()
	heading_block.alignment = BoxContainer.ALIGNMENT_CENTER
	heading_block.add_theme_constant_override("separation", -8)
	_content.add_child(heading_block)
	heading_block.add_child(_label("NEED HELP LATER?", 72, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var guidance := _label(
		"WAKE APOLLO WITH ‘OK APOLLO’, THEN ASK ‘HOW TO PLAY THE GAME?’",
		27,
		Color(1.0, 1.0, 1.0, 0.72),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	guidance.autowrap_mode = TextServer.AUTOWRAP_OFF
	guidance.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading_block.add_child(guidance)

	var ok_button := _button("OK, I UNDERSTAND", false)
	ok_button.custom_minimum_size = Vector2(0, 98)
	ok_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok_button.pressed.connect(_on_reminder_ok)
	_make_button_bouncy(ok_button)
	_content.add_child(ok_button)


func _animate_reminder_content_in() -> void:
	if not is_instance_valid(_content):
		return
	_content.scale = Vector2(0.94, 0.94)
	_content.pivot_offset = _content.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_content, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_content, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_reminder_ok() -> void:
	if _sequence_running:
		return
	_play_sfx("click")
	_sequence_running = true
	await _hide_modal_animated()
	_set_tutorial_background_frozen(false)
	_complete_tutorial_setting()
	AIState.set_command("", "")
	AIState.set_state(AIState.State.IDLE)
	queue_free()


func _popup_height(viewport_size: Vector2, reminder: bool) -> float:
	if reminder:
		return maxf(minf(viewport_size.y * 0.29, REMINDER_MAX_HEIGHT), REMINDER_MIN_HEIGHT)
	return maxf(minf(viewport_size.y * 0.32, OFFER_MAX_HEIGHT), OFFER_MIN_HEIGHT)


func _on_accepted() -> void:
	if _sequence_running:
		return
	_play_sfx("click")
	_accepted = true
	_sequence_running = true
	await _hide_modal_animated()
	_set_tutorial_background_frozen(false)
	if not is_inside_tree():
		return
	AIState.set_state(AIState.State.THINKING)
	await get_tree().create_timer(0.18, true, false, true).timeout
	_start_tutorial_audio()
	_duck_music_for_tutorial()
	AIState.set_state(AIState.State.SPEAKING)
	_sequence_started_msec = Time.get_ticks_msec()
	await _run_guided_sequence()
	await _wait_for_audio_end()
	_release_music_duck()
	_complete_tutorial_setting()
	AIState.set_command("", "")
	AIState.set_state(AIState.State.IDLE)
	_sequence_running = false
	queue_free()


func _run_guided_sequence() -> void:
	await _wait_until(6.0)
	if _bottom_menu != null and _bottom_menu.has_method("simulate_tutorial_open_menu"):
		await _bottom_menu.call("simulate_tutorial_open_menu")

	await _wait_until(9.4)
	if _bottom_menu != null and _bottom_menu.has_method("simulate_ai_enter_planet_cards"):
		await _bottom_menu.call("simulate_ai_enter_planet_cards")
	var cards_popup := await _wait_for_menu_popup("get_tutorial_planet_cards_popup")
	if cards_popup != null and cards_popup.has_method("tutorial_prepare_mars_demo"):
		await cards_popup.call("tutorial_prepare_mars_demo")

	await _wait_until(12.2)
	if is_instance_valid(cards_popup) and cards_popup.has_method("tutorial_type_search"):
		await cards_popup.call("tutorial_type_search", ">type:star", true)

	await _wait_until(13.8)
	if is_instance_valid(cards_popup) and cards_popup.has_method("tutorial_clear_search"):
		cards_popup.call("tutorial_clear_search")

	await _wait_until(14.3)
	if is_instance_valid(cards_popup) and cards_popup.has_method("tutorial_type_search"):
		await cards_popup.call("tutorial_type_search", "Mars", true)

	await _wait_until(16.4)
	if is_instance_valid(cards_popup) and cards_popup.has_method("tutorial_press_plus_and_reveal_mars"):
		await cards_popup.call("tutorial_press_plus_and_reveal_mars")
	if is_instance_valid(cards_popup) and cards_popup.has_method("get_tutorial_mars_card"):
		_tutorial_mars_card = cards_popup.call("get_tutorial_mars_card") as PlanetData

	await get_tree().create_timer(0.35, true, false, true).timeout
	if is_instance_valid(cards_popup) and cards_popup.has_method("tutorial_open_mars_details"):
		cards_popup.call("tutorial_open_mars_details")

	await get_tree().create_timer(0.40, true, false, true).timeout
	if is_instance_valid(cards_popup) and cards_popup.has_method("tutorial_scroll_mars_details"):
		await cards_popup.call("tutorial_scroll_mars_details")

	if is_instance_valid(cards_popup) and cards_popup.has_method("tutorial_open_mars_game_tab"):
		await cards_popup.call("tutorial_open_mars_game_tab")

	if is_instance_valid(cards_popup) and cards_popup.has_method("tutorial_scroll_mars_game_tab_more"):
		await cards_popup.call("tutorial_scroll_mars_game_tab_more")

	await get_tree().create_timer(0.30, true, false, true).timeout
	if is_instance_valid(cards_popup) and cards_popup.has_method("tutorial_scroll_mars_details_to_top"):
		await cards_popup.call("tutorial_scroll_mars_details_to_top")

	if is_instance_valid(cards_popup) and cards_popup.has_method("tutorial_add_mars_to_simulation"):
		await cards_popup.call("tutorial_add_mars_to_simulation")

	await get_tree().create_timer(0.35, true, false, true).timeout
	if _bottom_menu != null and _bottom_menu.has_method("simulate_ai_exit_planet_cards"):
		await _bottom_menu.call("simulate_ai_exit_planet_cards")

	await get_tree().create_timer(0.25, true, false, true).timeout
	if _bottom_menu != null and _bottom_menu.has_method("simulate_ai_enter_galaxy"):
		await _bottom_menu.call("simulate_ai_enter_galaxy")
	var galaxy_popup := await _wait_for_menu_popup("get_tutorial_galaxy_popup")

	await _scroll_galaxy_console(galaxy_popup)

	await _demonstrate_galaxy_controls(galaxy_popup)

	if _bottom_menu != null and _bottom_menu.has_method("simulate_ai_enter_achievements"):
		await _bottom_menu.call("simulate_ai_enter_achievements", "")

	await get_tree().create_timer(1.0, true, false, true).timeout
	var achievements_popup: Node = null
	if _bottom_menu != null and _bottom_menu.has_method("get_tutorial_achievements_popup"):
		achievements_popup = _bottom_menu.call("get_tutorial_achievements_popup") as Node
	if is_instance_valid(achievements_popup) and achievements_popup.has_method("tutorial_visit_second_to_last_category"):
		await achievements_popup.call("tutorial_visit_second_to_last_category")
	if _bottom_menu != null and _bottom_menu.has_method("simulate_ai_exit_achievements"):
		await _bottom_menu.call("simulate_ai_exit_achievements")
	if _bottom_menu != null and _bottom_menu.has_method("simulate_ai_go_home"):
		await _bottom_menu.call("simulate_ai_go_home")


func _scroll_galaxy_console(galaxy_popup: Node) -> void:
	if galaxy_popup == null or not is_instance_valid(galaxy_popup):
		return
	var scroll_variant: Variant = galaxy_popup.get("_scroll")
	if not (scroll_variant is ScrollContainer) or not is_instance_valid(scroll_variant):
		return
	var scroll := scroll_variant as ScrollContainer
	var bar := scroll.get_v_scroll_bar()
	var max_scroll := maxi(0, int(bar.max_value - bar.page))
	var target := mini(scroll.scroll_vertical + 420, max_scroll)
	var tween := create_tween()
	tween.tween_property(scroll, "scroll_vertical", target, 0.72).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(0.36, true, false, true).timeout
	if _tutorial_mars_card != null and _app_screen != null and _app_screen.has_method("tutorial_remove_planet_from_scene"):
		_app_screen.call("tutorial_remove_planet_from_scene", _tutorial_mars_card)
	await tween.finished


func _demonstrate_galaxy_controls(galaxy_popup: Node) -> void:
	if galaxy_popup == null or not galaxy_popup.has_method("apply_ai_config_value_live"):
		return
	var config: Variant = galaxy_popup.get("config")
	if config == null:
		return
	var original_speed := float(config.get("simulation_speed"))
	var original_orbit := float(config.get("orbit_speed_multiplier"))
	var moved_speed := clampf(original_speed * 0.68, 0.05, 32.0)
	var moved_orbit := clampf(original_orbit * 1.28, 0.05, 32.0)
	galaxy_popup.call("apply_ai_config_value_live", "simulation_speed", moved_speed)
	galaxy_popup.call("apply_ai_config_value_live", "orbit_speed_multiplier", moved_orbit)
	await get_tree().create_timer(1.01, true, false, true).timeout
	if not is_instance_valid(galaxy_popup):
		return
	galaxy_popup.call("apply_ai_config_value_live", "simulation_speed", original_speed)
	galaxy_popup.call("apply_ai_config_value_live", "orbit_speed_multiplier", original_orbit)
	await get_tree().create_timer(1.02, true, false, true).timeout


func _wait_for_menu_popup(getter_name: String) -> Node:
	if _bottom_menu == null or not _bottom_menu.has_method(getter_name):
		return null
	for _attempt in range(180):
		var popup: Variant = _bottom_menu.call(getter_name)
		if popup is Node and is_instance_valid(popup):
			return popup as Node
		await get_tree().process_frame
	return null


func _wait_until(seconds_from_start: float) -> void:
	while is_inside_tree():
		var elapsed := float(Time.get_ticks_msec() - _sequence_started_msec) / 1000.0
		var remaining := seconds_from_start - elapsed
		if remaining <= 0.0:
			return
		await get_tree().create_timer(minf(remaining, 0.12), true, false, true).timeout


func _start_tutorial_audio() -> void:
	_audio_finished = false
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "ApolloTutorialAudio"
	_audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_audio_player.finished.connect(func() -> void:
		_audio_finished = true
		_release_music_duck()
	)
	add_child(_audio_player)
	var stream := load(AUDIO_PATH) as AudioStream
	if stream == null:
		push_warning("Tutorial audio was not found at %s" % AUDIO_PATH)
		return
	_audio_player.stream = stream
	_audio_player.play()


func _wait_for_audio_end() -> void:
	if is_instance_valid(_audio_player) and _audio_player.stream != null:
		while is_inside_tree() and _audio_player.playing and not _audio_finished:
			await get_tree().process_frame
		return
	var elapsed := float(Time.get_ticks_msec() - _sequence_started_msec) / 1000.0
	if elapsed < FALLBACK_TUTORIAL_DURATION:
		await get_tree().create_timer(FALLBACK_TUTORIAL_DURATION - elapsed, true, false, true).timeout


func _complete_tutorial_setting() -> void:
	if _settings != null and _settings.has_method("complete_tutorial_for_current_account"):
		_settings.call("complete_tutorial_for_current_account")


func _input(_event: InputEvent) -> void:
	if _accepted and _sequence_running and get_viewport() != null:
		get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	# GUI events consumed by the tutorial buttons never reach this callback.
	# Everything else is swallowed while either consent screen is visible.
	if is_instance_valid(_panel) and _panel.visible and get_viewport() != null:
		get_viewport().set_input_as_handled()


func _unhandled_key_input(_event: InputEvent) -> void:
	if is_instance_valid(_panel) and _panel.visible and get_viewport() != null:
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_set_tutorial_background_frozen(false)
	_release_music_duck()
	if is_instance_valid(_audio_player):
		_audio_player.stop()


func _set_tutorial_background_frozen(frozen: bool) -> void:
	if _background_frozen_by_tutorial == frozen:
		return
	_background_frozen_by_tutorial = frozen
	if _app_screen != null and _app_screen.has_method("_set_background_frozen"):
		_app_screen.call("_set_background_frozen", frozen)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.94)
	style.border_color = Color.WHITE
	style.set_border_width_all(5)
	style.set_corner_radius_all(42)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 22
	return style


func _button(text_value: String, highlighted: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(300, 98)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 38)
	if _app_font != null:
		button.add_theme_font_override("font", _app_font)
	var background := Color.WHITE if highlighted else Color.BLACK
	var foreground := Color.BLACK if highlighted else Color.WHITE
	var normal := StyleBoxFlat.new()
	normal.bg_color = background
	normal.border_color = Color.WHITE
	normal.set_border_width_all(4)
	normal.set_corner_radius_all(28)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", normal)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", foreground)
	button.add_theme_color_override("font_hover_color", foreground)
	button.add_theme_color_override("font_pressed_color", foreground)
	return button


func _make_button_bouncy(button: Button) -> void:
	button.button_down.connect(func() -> void:
		if _should_reduce_motion():
			return
		button.pivot_offset = button.size * 0.5
		_tween_button_scale(button, Vector2(0.88, 0.88), 0.055)
	)
	button.button_up.connect(func() -> void:
		if _should_reduce_motion():
			button.scale = Vector2.ONE
			return
		button.pivot_offset = button.size * 0.5
		_tween_button_scale(button, Vector2.ONE, 0.10)
	)
	# A drag outside cancels Button.pressed, leaving only the reset above.
	button.pressed.connect(func() -> void:
		if _should_reduce_motion():
			button.scale = Vector2.ONE
			return
		button.pivot_offset = button.size * 0.5
		_tween_button_scale(button, Vector2(1.10, 1.10), 0.11, true)
	)


func _tween_button_scale(button: Button, target: Vector2, duration: float, return_to_normal := false) -> void:
	if not is_instance_valid(button):
		return
	var existing: Variant = _button_tweens.get(button)
	if existing is Tween and existing.is_valid():
		existing.kill()
	var tween := create_tween()
	_button_tweens[button] = tween
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target, duration)
	if return_to_normal:
		tween.tween_property(button, "scale", Vector2.ONE, 0.10)


func _label(text_value: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if _app_font != null:
		label.add_theme_font_override("font", _app_font)
	return label


func _get_left_offscreen_position() -> Vector2:
	return Vector2(-_slide_root.size.x - POPUP_SIDE_PADDING, _center_position.y)


func _get_right_offscreen_position() -> Vector2:
	var viewport_width := _center_position.x + _slide_root.size.x + POPUP_SIDE_PADDING
	if get_viewport() != null:
		viewport_width = get_viewport().get_visible_rect().size.x
	return Vector2(viewport_width + POPUP_SIDE_PADDING, _center_position.y)


func _should_reduce_motion() -> bool:
	return _settings != null and bool(_settings.get("reduce_motion_enabled"))


func _duck_music_for_tutorial() -> void:
	if _music_duck_active:
		return
	var music := get_node_or_null("/root/UnilearnMusic")
	if music == null or not music.has_method("duck_for_tutorial"):
		return
	_music_duck_active = true
	music.call("duck_for_tutorial")


func _release_music_duck() -> void:
	if not _music_duck_active:
		return
	_music_duck_active = false
	var music := get_node_or_null("/root/UnilearnMusic")
	if music != null and music.has_method("release_tutorial_duck"):
		music.call("release_tutorial_duck")


func _accent_color() -> Color:
	if _settings != null and _settings.has_method("get_accent_color"):
		var value: Variant = _settings.call("get_accent_color")
		if value is Color:
			return value
	return Color("#9B6DFF")


func _play_sfx(id: String) -> void:
	var sfx := get_node_or_null("/root/UnilearnSFX")
	if sfx == null:
		return
	if sfx.has_method("play"):
		sfx.call("play", id)
	elif sfx.has_method("play_sfx"):
		sfx.call("play_sfx", id)

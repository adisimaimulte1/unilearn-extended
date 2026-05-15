extends CanvasLayer

signal quiz_completed(data: PlanetData, score: int, total: int, xp_won: int)

const FONT_PATH := "res://assets/fonts/JockeyOne-Regular.ttf"

const COLOR_DIM := Color(0.0, 0.0, 0.0, 0.88)
const COLOR_BLUR_FAKE := Color(1.0, 1.0, 1.0, 0.024)
const COLOR_PANEL := Color(0.0, 0.0, 0.0, 0.82)
const COLOR_SOFT := Color(1.0, 1.0, 1.0, 0.055)
const COLOR_MUTED := Color(1.0, 1.0, 1.0, 0.68)
const COLOR_WRONG := Color("#ff5f7e")

const PANEL_RADIUS := 44
const BUTTON_RADIUS := 38

const BUTTON_PRESS_SCALE := Vector2(0.88, 0.88)
const BUTTON_RELEASE_SCALE := Vector2(1.10, 1.10)
const BUTTON_DOWN_TIME := 0.055
const BUTTON_UP_TIME := 0.11
const BUTTON_SETTLE_TIME := 0.10

const PANEL_WIDTH_RATIO := 0.96
const PANEL_HEIGHT_RATIO := 0.96
const PANEL_MAX_WIDTH := 1380.0
const PANEL_MAX_HEIGHT := 1260.0

const TITLE_FONT_MAX := 82
const TITLE_FONT_MIN := 42
const QUESTION_FONT_MAX := 64
const QUESTION_FONT_MIN := 38
const ANSWER_FONT_MAX := 50
const ANSWER_FONT_MIN := 30

@export var backend_url: String = UnilearnBackendService.APOLLO_QUIZ_URL
@export var sfx_click_id: String = "click"
@export var sfx_success_id: String = "success"
@export var sfx_error_id: String = "error"

var _data: PlanetData = null
var _http: HTTPRequest = null
var _font: Font = null

var _last_accent_color := Color.WHITE

var _dim: ColorRect = null
var _blur_layer: ColorRect = null
var _panel: PanelContainer = null
var _root_box: VBoxContainer = null

var _quiz: Dictionary = {}
var _questions: Array = []
var _question_index := 0
var _score := 0
var _wrong_count := 0
var _answered := false

var _title_rich: RichTextLabel = null
var _question_label: Label = null
var _bottom_counter_label: Label = null
var _right_label: Label = null
var _wrong_label: Label = null
var _xp_label: Label = null
var _answer_buttons: Array[Button] = []
var _answer_rows: Array = []
var _next_button: Button = null

var _button_tweens: Dictionary = {}
var _ai_thinking_visual_active := false


func _ready() -> void:
	layer = 1201
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_font = load(FONT_PATH) as Font
	_last_accent_color = _accent_color()
	_connect_settings_signal()

	_http = HTTPRequest.new()
	_http.name = "ApolloQuizHTTPRequest"
	_http.timeout = UnilearnBackendService.QUIZ_GENERATION_TIMEOUT_SEC
	add_child(_http)
	_http.request_completed.connect(_on_quiz_request_completed)


func _connect_settings_signal() -> void:
	var settings := get_node_or_null("/root/UnilearnUserSettings")

	if settings == null:
		return

	if not settings.has_signal("settings_changed"):
		return

	var callable := Callable(self, "_on_settings_changed")

	if not settings.settings_changed.is_connected(callable):
		settings.settings_changed.connect(callable)


func _on_settings_changed() -> void:
	if not visible:
		_last_accent_color = _accent_color()
		return

	_refresh_live_theme()


func _refresh_live_theme() -> void:
	var old_accent := _last_accent_color
	var new_accent := _accent_color()

	if _colors_close(old_accent, new_accent):
		return

	_last_accent_color = new_accent

	_update_title_text()

	if is_instance_valid(_bottom_counter_label):
		_bottom_counter_label.add_theme_color_override("font_color", new_accent)

	if is_instance_valid(_next_button):
		_refresh_next_button_style(not _next_button.disabled)

	for i in range(_answer_rows.size()):
		if i < _answer_buttons.size():
			var button: Button = _answer_buttons[i]

			if not button.disabled:
				var row_data: Dictionary = _answer_rows[i]
				var letter_panel := row_data.get("letter_panel") as PanelContainer
				var letter_label := row_data.get("letter_label") as Label

				if is_instance_valid(letter_panel):
					letter_panel.add_theme_stylebox_override("panel", _letter_style(Color.BLACK, Color.WHITE))

				if is_instance_valid(letter_label):
					letter_label.add_theme_color_override("font_color", Color.WHITE)

				button.add_theme_stylebox_override("hover", _answer_text_style(_accent_soft_color(), new_accent, 3))

	_refresh_bubble_theme()


func _refresh_bubble_theme() -> void:
	if not is_instance_valid(_xp_label):
		return

	var xp_panel := _find_parent_panel(_xp_label)

	if xp_panel != null:
		xp_panel.add_theme_stylebox_override("panel", _panel_style(28, Color.BLACK, _accent_color(), 3))

	var current := _xp_label.get_parent()

	if current is HBoxContainer:
		for child in current.get_children():
			if child is Label and child != _xp_label:
				child.add_theme_color_override("font_color", _accent_color())


func _find_parent_panel(node: Node) -> PanelContainer:
	var current := node.get_parent()

	while current != null:
		if current is PanelContainer:
			return current

		current = current.get_parent()

	return null


func _colors_close(a: Color, b: Color, tolerance: float = 0.01) -> bool:
	return (
		abs(a.r - b.r) <= tolerance
		and abs(a.g - b.g) <= tolerance
		and abs(a.b - b.b) <= tolerance
		and abs(a.a - b.a) <= tolerance
	)


func open_upgrade_quiz(data: PlanetData) -> void:
	if data == null:
		return

	visible = true

	_data = data
	_quiz.clear()
	_questions.clear()
	_question_index = 0
	_score = 0
	_wrong_count = 0
	_answered = false

	_show_loading_ui()
	_enter_ai_thinking_visual()
	_request_quiz()


func _request_quiz() -> void:
	if _http == null:
		return

	if _data == null:
		_show_error("Missing planet data.")
		return

	var body := {
		"planetName": _data.name,
		"planet": _data.to_firebase_dict(),
		"xpReward": _data.upgrade_quiz_xp_reward,
	}

	var headers := ["Content-Type: application/json"]

	_http.timeout = UnilearnBackendService.QUIZ_GENERATION_TIMEOUT_SEC

	var err := _http.request(
		backend_url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)

	if err != OK:
		_release_ai_thinking_visual()
		_show_error("Could not start Apollo quiz.")


func _on_quiz_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_release_ai_thinking_visual()

	if result != HTTPRequest.RESULT_SUCCESS:
		_show_error("Network error while generating quiz.")
		return

	var text := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)

	if not parsed is Dictionary:
		_show_error("Invalid quiz response.")
		return

	var parsed_dict: Dictionary = parsed

	if response_code < 200 or response_code >= 300:
		_show_error(str(parsed_dict.get("message", "Apollo failed to generate quiz.")))
		return

	if not bool(parsed_dict.get("success", false)):
		_show_error(str(parsed_dict.get("message", "Apollo failed to generate quiz.")))
		return

	var quiz_variant: Variant = parsed_dict.get("quiz", {})

	if not quiz_variant is Dictionary:
		_show_error("Quiz data missing.")
		return

	var quiz: Dictionary = quiz_variant
	var questions_variant: Variant = quiz.get("questions", [])

	if not questions_variant is Array:
		_show_error("Quiz questions missing.")
		return

	var questions: Array = questions_variant

	if questions.size() != 4:
		_show_error("Apollo returned an incomplete quiz.")
		return

	_quiz = quiz
	_questions = questions
	_question_index = 0
	_score = 0
	_wrong_count = 0

	_build_question_ui()
	_show_question()


func _show_loading_ui() -> void:
	_clear_ui()
	_add_blur_dim()


func _build_question_ui() -> void:
	_clear_ui()
	_add_blur_dim()

	_panel = _make_panel(_popup_size())
	add_child(_panel)

	_root_box = VBoxContainer.new()
	_root_box.clip_contents = true
	_root_box.add_theme_constant_override("separation", 22)
	_panel_margin(_panel, 42, 38, 42, 42).add_child(_root_box)

	_add_title_row(_root_box)

	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 18)
	stat_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_box.add_child(stat_row)

	_right_label = _bubble(stat_row, "RIGHT", "0")
	_wrong_label = _bubble(stat_row, "WRONG", "0")
	_xp_label = _bubble(stat_row, "XP", "+0")

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 5)
	divider.color = Color.WHITE
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_box.add_child(divider)

	var question_card := PanelContainer.new()
	question_card.custom_minimum_size = Vector2(0, 250)
	question_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_card.add_theme_stylebox_override("panel", _panel_style(34, Color.BLACK, Color.WHITE, 3))
	_root_box.add_child(question_card)

	_question_label = _label("", QUESTION_FONT_MAX, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	_question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_question_label.clip_text = true
	_question_label.custom_minimum_size = Vector2(0, 190)
	_panel_margin(question_card, 34, 28, 34, 28).add_child(_question_label)

	var answers_box := VBoxContainer.new()
	answers_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	answers_box.add_theme_constant_override("separation", 14)
	_root_box.add_child(answers_box)

	_answer_buttons.clear()
	_answer_rows.clear()

	for i in range(4):
		var row_data := _make_answer_row()
		var row := row_data["row"] as HBoxContainer
		var button := row_data["button"] as Button
		var index := i

		button.button_down.connect(func() -> void:
			_play_sfx(sfx_click_id)
			_animate_button_down(button)
		)

		button.button_up.connect(func() -> void:
			_animate_button_up(button)
		)

		button.pressed.connect(func() -> void:
			_select_answer(index)
		)

		answers_box.add_child(row)
		_answer_buttons.append(button)
		_answer_rows.append(row_data)

	_next_button = _make_action_button("NEXT", Vector2(0, 104), 52, Color.BLACK, Color.WHITE)
	_next_button.disabled = true
	_next_button.add_theme_color_override("font_disabled_color", Color.WHITE)
	_next_button.add_theme_stylebox_override("disabled", _button_style(Color.BLACK, Color.WHITE, 3))
	_next_button.pressed.connect(_go_next)
	_root_box.add_child(_next_button)

	_bottom_counter_label = _label("1 / 4", 80, _accent_color(), HORIZONTAL_ALIGNMENT_CENTER, false)
	_root_box.add_child(_bottom_counter_label)

	_refresh_next_button_style(false)
	_pop_in(_panel)


func _add_title_row(parent: VBoxContainer) -> void:
	_title_rich = RichTextLabel.new()
	_title_rich.bbcode_enabled = true
	_title_rich.fit_content = true
	_title_rich.scroll_active = false
	_title_rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_rich.custom_minimum_size = Vector2(0, 96)
	_title_rich.add_theme_font_size_override("normal_font_size", TITLE_FONT_MAX)
	_title_rich.add_theme_color_override("default_color", Color.WHITE)

	if _font != null:
		_title_rich.add_theme_font_override("normal_font", _font)
		_title_rich.add_theme_font_override("bold_font", _font)

	parent.add_child(_title_rich)

	_update_title_text()
	call_deferred("_fit_title_text")


func _update_title_text() -> void:
	if not is_instance_valid(_title_rich):
		return

	var planet_name := _data.name.to_upper() if _data != null else "OBJECT"
	var accent_hex := _accent_color().to_html(false)

	_title_rich.text = "[center][color=#%s]%s[/color] [color=#ffffff]QUIZ[/color][/center]" % [
		accent_hex,
		_bbcode_escape(planet_name),
	]


func _show_question() -> void:
	if _question_index < 0 or _question_index >= _questions.size():
		_show_results()
		return

	_answered = false

	if not _questions[_question_index] is Dictionary:
		_show_error("Invalid question data.")
		return

	var question: Dictionary = _questions[_question_index]
	var answers_variant: Variant = question.get("answers", [])
	var answers: Array = answers_variant if answers_variant is Array else []

	_bottom_counter_label.text = "%d / 4" % (_question_index + 1)
	_update_bubbles()

	_question_label.text = str(question.get("question", ""))
	call_deferred("_fit_question_text")

	for i in range(_answer_buttons.size()):
		var button: Button = _answer_buttons[i]
		var answer: Dictionary = {}

		if i < answers.size() and answers[i] is Dictionary:
			answer = answers[i]

		var answer_id := str(answer.get("id", ["A", "B", "C", "D"][i]))
		var answer_text := str(answer.get("text", "Missing answer"))

		button.text = answer_text
		button.disabled = false
		_reset_answer_row(i, answer_id)
		call_deferred("_fit_answer_text", button)

	_next_button.disabled = true
	_next_button.text = "NEXT" if _question_index < _questions.size() - 1 else "FINISH"
	_refresh_next_button_style(false)


func _select_answer(index: int) -> void:
	if _answered:
		return

	if index < 0 or index >= _answer_buttons.size():
		return

	if _question_index < 0 or _question_index >= _questions.size():
		return

	if not _questions[_question_index] is Dictionary:
		return

	var question: Dictionary = _questions[_question_index]
	var answers_variant: Variant = question.get("answers", [])
	var answers: Array = answers_variant if answers_variant is Array else []

	if index >= answers.size() or not answers[index] is Dictionary:
		return

	_answered = true

	var selected: Dictionary = answers[index]
	var selected_id := str(selected.get("id", ""))
	var correct_id := str(question.get("correct_answer_id", "A"))

	var is_correct := selected_id == correct_id

	if is_correct:
		_score += 1
		_play_sfx(sfx_success_id)
	else:
		_wrong_count += 1
		_play_sfx(sfx_error_id)

	for i in range(_answer_buttons.size()):
		var button: Button = _answer_buttons[i]
		button.disabled = true

		var answer: Dictionary = {}

		if i < answers.size() and answers[i] is Dictionary:
			answer = answers[i]

		var answer_id := str(answer.get("id", ""))

		if answer_id == selected_id:
			_animate_answer_selection(i, is_correct)
		else:
			_dim_answer_row(i)

	_update_bubbles()
	_next_button.disabled = false
	_refresh_next_button_style(true)


func _go_next() -> void:
	if not _answered:
		return

	_question_index += 1

	if _question_index >= _questions.size():
		_show_results()
	else:
		_show_question()


func _show_results() -> void:
	var total := max(_questions.size(), 1)
	var xp_total := int(_quiz.get("xp_reward", _data.upgrade_quiz_xp_reward))
	var xp_won := int(round(float(xp_total) * (float(_score) / float(total))))

	_clear_ui()
	_add_blur_dim()

	_panel = _make_panel(_popup_size())
	add_child(_panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 28)
	_panel_margin(_panel, 42, 38, 42, 42).add_child(box)

	box.add_child(_label("QUIZ COMPLETE", 82, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false))
	box.add_child(_label(_data.name.to_upper(), 54, _accent_color(), HORIZONTAL_ALIGNMENT_CENTER, true))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)

	_bubble(row, "RIGHT", str(_score))
	_bubble(row, "WRONG", str(total - _score))
	_bubble(row, "XP", "+%d" % xp_won)

	var done := _make_action_button("DONE", Vector2(0, 104), 52, _accent_color(), Color.BLACK)
	done.pressed.connect(func() -> void:
		_finish_quiz(total, xp_won)
	)
	box.add_child(done)

	_pop_in(_panel)


func _finish_quiz(total: int, xp_won: int) -> void:
	if _data == null:
		close_quiz()
		return

	if has_node("/root/FirebaseDatabase") and FirebaseDatabase.has_method("add_planet_xp_optimistic"):
		FirebaseDatabase.add_planet_xp_optimistic(_data, xp_won)
	else:
		_apply_xp_locally(_data, xp_won)

	quiz_completed.emit(_data, _score, total, xp_won)
	close_quiz()


func _apply_xp_locally(card: PlanetData, xp_to_add: int) -> void:
	card.game_level = max(card.game_level, 1)
	card.game_xp = max(card.game_xp, 0)
	card.game_xp_to_next = max(card.game_xp_to_next, 10)

	card.game_xp += max(xp_to_add, 0)

	while card.game_xp >= card.game_xp_to_next:
		card.game_xp -= card.game_xp_to_next
		card.game_level += 1
		card.game_xp_to_next = max(10, int(round(float(card.game_xp_to_next) * 1.18)))


func _show_error(message: String) -> void:
	_release_ai_thinking_visual()
	_clear_ui()
	_add_blur_dim()

	_panel = _make_panel(Vector2(820, 440))
	add_child(_panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	_panel_margin(_panel, 36, 34, 36, 36).add_child(box)

	box.add_child(_label("QUIZ FAILED", 60, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false))
	box.add_child(_label(message, 38, COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

	var close := _make_action_button("CLOSE", Vector2(0, 88), 44, Color.WHITE, Color.BLACK)
	close.pressed.connect(close_quiz)
	box.add_child(close)

	_pop_in(_panel)


func close_quiz() -> void:
	_release_ai_thinking_visual()
	_clear_ui()
	visible = false

	_data = null
	_quiz.clear()
	_questions.clear()
	_question_index = 0
	_score = 0
	_wrong_count = 0


func _clear_ui() -> void:
	for child in get_children():
		if child == _http:
			continue

		child.queue_free()

	_dim = null
	_blur_layer = null
	_panel = null
	_root_box = null
	_answer_buttons.clear()
	_answer_rows.clear()
	_question_label = null
	_bottom_counter_label = null
	_right_label = null
	_wrong_label = null
	_xp_label = null
	_next_button = null
	_title_rich = null


func _add_blur_dim() -> void:
	_dim = ColorRect.new()
	_dim.color = COLOR_DIM
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(_event: InputEvent) -> void:
		get_viewport().set_input_as_handled()
	)
	add_child(_dim)

	_blur_layer = ColorRect.new()
	_blur_layer.color = COLOR_BLUR_FAKE
	_blur_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blur_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_blur_layer)


func _popup_size() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	return Vector2(
		min(viewport_size.x * PANEL_WIDTH_RATIO, PANEL_MAX_WIDTH),
		min(viewport_size.y * PANEL_HEIGHT_RATIO, PANEL_MAX_HEIGHT)
	)


func _make_panel(size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.z_index = 10
	panel.custom_minimum_size = size
	panel.size = size
	panel.position = _center_position_for_size(size)
	panel.pivot_offset = size * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.clip_contents = true
	panel.scale = Vector2(0.96, 0.96)
	panel.modulate = Color(1, 1, 1, 0.0)
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL_RADIUS, COLOR_PANEL, Color.WHITE, 5))
	return panel


func _center_position_for_size(size: Vector2) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	return (viewport_size - size) * 0.5


func _pop_in(control: Control) -> void:
	if not is_instance_valid(control):
		return

	control.pivot_offset = control.size * 0.5

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, 0.14)
	tween.tween_property(control, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _make_answer_row() -> Dictionary:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 118)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 18)

	var letter_panel := PanelContainer.new()
	letter_panel.custom_minimum_size = Vector2(118, 118)
	letter_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	letter_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	letter_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letter_panel.add_theme_stylebox_override("panel", _letter_style(Color.BLACK, Color.WHITE))
	row.add_child(letter_panel)

	var letter_label := _label("A", 64, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false)
	letter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter_label.custom_minimum_size = Vector2(0, 92)
	_panel_margin(letter_panel, 0, 0, 0, 0).add_child(letter_label)

	var button := _make_answer_button()
	row.add_child(button)

	return {
		"row": row,
		"button": button,
		"letter_panel": letter_panel,
		"letter_label": letter_label,
	}


func _make_answer_button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 118)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", ANSWER_FONT_MAX)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _answer_text_style(Color.BLACK, Color.WHITE, 3))
	button.add_theme_stylebox_override("hover", _answer_text_style(_accent_soft_color(), _accent_color(), 3))
	button.add_theme_stylebox_override("pressed", _answer_text_style(Color(1, 1, 1, 0.10), Color.WHITE, 3))
	_apply_font(button)
	return button


func _make_action_button(text: String, size: Vector2, font_size: int, bg: Color, text_color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_stylebox_override("normal", _button_style(bg, bg if bg != Color.BLACK else Color.WHITE, 3 if bg == Color.BLACK else 0))
	button.add_theme_stylebox_override("hover", _button_style(bg.lightened(0.04), bg.lightened(0.04), 0))
	button.add_theme_stylebox_override("pressed", _button_style(bg.darkened(0.06), bg.darkened(0.06), 0))
	_apply_font(button)

	button.button_down.connect(func() -> void:
		_play_sfx(sfx_click_id)
		_animate_button_down(button)
	)

	button.button_up.connect(func() -> void:
		_animate_button_up(button)
	)

	return button


func _refresh_next_button_style(active: bool) -> void:
	if not is_instance_valid(_next_button):
		return

	if active:
		_next_button.add_theme_color_override("font_color", Color.BLACK)
		_next_button.add_theme_color_override("font_hover_color", Color.BLACK)
		_next_button.add_theme_color_override("font_pressed_color", Color.BLACK)
		_next_button.add_theme_stylebox_override("normal", _button_style(_accent_color(), _accent_color(), 0))
		_next_button.add_theme_stylebox_override("hover", _button_style(_accent_color().lightened(0.05), _accent_color().lightened(0.05), 0))
		_next_button.add_theme_stylebox_override("pressed", _button_style(_accent_color().darkened(0.08), _accent_color().darkened(0.08), 0))

		var tween := create_tween()
		tween.tween_property(_next_button, "scale", Vector2(1.035, 1.035), 0.08)
		tween.tween_property(_next_button, "scale", Vector2.ONE, 0.11)
	else:
		_next_button.add_theme_color_override("font_color", Color.WHITE)
		_next_button.add_theme_color_override("font_hover_color", Color.WHITE)
		_next_button.add_theme_color_override("font_pressed_color", Color.WHITE)
		_next_button.add_theme_stylebox_override("normal", _button_style(Color.BLACK, Color.WHITE, 3))
		_next_button.add_theme_stylebox_override("hover", _button_style(Color(1, 1, 1, 0.06), Color.WHITE, 3))
		_next_button.add_theme_stylebox_override("pressed", _button_style(Color(1, 1, 1, 0.10), Color.WHITE, 3))
		_next_button.scale = Vector2.ONE


func _bubble(parent: HBoxContainer, title: String, value: String) -> Label:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 116)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var is_xp := title.strip_edges().to_lower() == "xp"
	var border := _accent_color() if is_xp else Color.WHITE
	panel.add_theme_stylebox_override("panel", _panel_style(28, Color.BLACK, border, 3))
	parent.add_child(panel)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_margin(panel, 10, 10, 10, 10).add_child(center)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	center.add_child(row)

	var title_color := _accent_color() if is_xp else Color.WHITE
	var title_label := _label("%s:" % title.to_upper(), 52, title_color, HORIZONTAL_ALIGNMENT_CENTER, false)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(title_label)

	var value_label := _label(value.to_upper(), 58, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(value_label)

	return value_label


func _update_bubbles() -> void:
	if is_instance_valid(_right_label):
		_right_label.text = str(_score)

	if is_instance_valid(_wrong_label):
		_wrong_label.text = str(_wrong_count)

	if is_instance_valid(_xp_label):
		var total := max(_questions.size(), 1)
		var xp_total := int(_quiz.get("xp_reward", _data.upgrade_quiz_xp_reward))
		var xp_won := int(round(float(xp_total) * (float(_score) / float(total))))
		_xp_label.text = "+%d" % xp_won


func _reset_answer_row(index: int, answer_id: String) -> void:
	if index < 0 or index >= _answer_rows.size():
		return

	var row_data: Dictionary = _answer_rows[index]
	var row := row_data.get("row") as Control
	var button := row_data.get("button") as Button
	var letter_panel := row_data.get("letter_panel") as PanelContainer
	var letter_label := row_data.get("letter_label") as Label

	if is_instance_valid(row):
		row.scale = Vector2.ONE
		row.modulate = Color.WHITE
		row.pivot_offset = row.size * 0.5

	if is_instance_valid(letter_panel):
		letter_panel.add_theme_stylebox_override("panel", _letter_style(Color.BLACK, Color.WHITE))

	if is_instance_valid(letter_label):
		letter_label.text = answer_id.to_upper()
		letter_label.add_theme_color_override("font_color", Color.WHITE)

	if is_instance_valid(button):
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.add_theme_color_override("font_disabled_color", Color.WHITE)

		var normal_style := _answer_text_style(Color.BLACK, Color.WHITE, 3)

		button.add_theme_stylebox_override("normal", normal_style)
		button.add_theme_stylebox_override("hover", _answer_text_style(_accent_soft_color(), _accent_color(), 3))
		button.add_theme_stylebox_override("pressed", _answer_text_style(Color(1, 1, 1, 0.10), Color.WHITE, 3))
		button.add_theme_stylebox_override("disabled", normal_style)
	

func _animate_answer_selection(index: int, is_correct: bool) -> void:
	if index < 0 or index >= _answer_rows.size():
		return

	var row_data: Dictionary = _answer_rows[index]
	var row := row_data.get("row") as Control
	var button := row_data.get("button") as Button
	var letter_panel := row_data.get("letter_panel") as PanelContainer
	var letter_label := row_data.get("letter_label") as Label

	var highlight := _accent_color() if is_correct else COLOR_WRONG

	if is_instance_valid(letter_panel):
		letter_panel.add_theme_stylebox_override("panel", _letter_style(Color.BLACK, highlight))

	if is_instance_valid(letter_label):
		letter_label.add_theme_color_override("font_color", highlight)

	if is_instance_valid(button):
		button.add_theme_color_override("font_color", highlight)
		button.add_theme_color_override("font_hover_color", highlight)
		button.add_theme_color_override("font_pressed_color", highlight)
		button.add_theme_color_override("font_disabled_color", highlight)

		var selected_style := _answer_text_style(Color.BLACK, highlight, 3)

		button.add_theme_stylebox_override("normal", selected_style)
		button.add_theme_stylebox_override("hover", selected_style)
		button.add_theme_stylebox_override("pressed", selected_style)
		button.add_theme_stylebox_override("disabled", selected_style)

	if is_instance_valid(row):
		row.pivot_offset = row.size * 0.5

		var tween := create_tween()
		tween.tween_property(row, "scale", Vector2(1.025, 1.025), 0.08)
		tween.tween_property(row, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _dim_answer_row(index: int) -> void:
	if index < 0 or index >= _answer_rows.size():
		return

	var row_data: Dictionary = _answer_rows[index]
	var row := row_data.get("row") as Control
	var button := row_data.get("button") as Button
	var letter_panel := row_data.get("letter_panel") as PanelContainer
	var letter_label := row_data.get("letter_label") as Label

	var dim_color := Color(1, 1, 1, 0.42)
	var dim_border := Color(1, 1, 1, 0.28)

	if is_instance_valid(row):
		row.modulate = Color.WHITE

	if is_instance_valid(letter_panel):
		letter_panel.add_theme_stylebox_override("panel", _letter_style(Color.BLACK, dim_border))

	if is_instance_valid(letter_label):
		letter_label.add_theme_color_override("font_color", dim_color)

	if is_instance_valid(button):
		button.add_theme_color_override("font_color", dim_color)
		button.add_theme_color_override("font_hover_color", dim_color)
		button.add_theme_color_override("font_pressed_color", dim_color)
		button.add_theme_color_override("font_disabled_color", dim_color)

		var dim_style := _answer_text_style(Color.BLACK, dim_border, 2)

		button.add_theme_stylebox_override("normal", dim_style)
		button.add_theme_stylebox_override("hover", dim_style)
		button.add_theme_stylebox_override("pressed", dim_style)
		button.add_theme_stylebox_override("disabled", dim_style)


func _fit_title_text() -> void:
	if not is_instance_valid(_title_rich):
		return

	var planet_name := _data.name.to_upper() if _data != null else "OBJECT"
	var plain_text := "%s QUIZ" % planet_name
	var available_width := max(_title_rich.size.x - 10.0, 1.0)
	var font_size := TITLE_FONT_MAX

	while font_size > TITLE_FONT_MIN:
		if _get_text_width(plain_text, font_size) <= available_width:
			break

		font_size -= 1

	_title_rich.add_theme_font_size_override("normal_font_size", font_size)
	_update_title_text()


func _fit_question_text() -> void:
	if not is_instance_valid(_question_label):
		return

	var available_width := max(_question_label.size.x - 10.0, 1.0)
	var max_two_line_width: float = available_width * 1.9
	var font_size := QUESTION_FONT_MAX

	while font_size > QUESTION_FONT_MIN:
		if _get_text_width(_question_label.text, font_size) <= max_two_line_width:
			break

		font_size -= 1

	_question_label.add_theme_font_size_override("font_size", font_size)


func _fit_answer_text(button: Button) -> void:
	if not is_instance_valid(button):
		return

	var available_width := max(button.size.x - 70.0, 1.0)
	var font_size := ANSWER_FONT_MAX

	while font_size > ANSWER_FONT_MIN:
		if _get_text_width(button.text, font_size) <= available_width:
			break

		font_size -= 1

	button.add_theme_font_size_override("font_size", font_size)


func _get_text_width(text: String, font_size: int) -> float:
	if _font != null:
		return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	return float(text.length() * font_size) * 0.58


func _animate_button_down(button: Control) -> void:
	if not is_instance_valid(button):
		return

	_kill_button_tween(button)
	button.pivot_offset = button.size * 0.5

	var tween := create_tween()
	_button_tweens[button] = tween
	tween.tween_property(button, "scale", BUTTON_PRESS_SCALE, BUTTON_DOWN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _animate_button_up(button: Control) -> void:
	if not is_instance_valid(button):
		return

	_kill_button_tween(button)
	button.pivot_offset = button.size * 0.5

	var tween := create_tween()
	_button_tweens[button] = tween
	tween.tween_property(button, "scale", BUTTON_RELEASE_SCALE, BUTTON_UP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, BUTTON_SETTLE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _kill_button_tween(button: Control) -> void:
	if _button_tweens.has(button):
		var tween: Tween = _button_tweens[button]

		if is_instance_valid(tween):
			tween.kill()

		_button_tweens.erase(button)


func _label(text: String, font_size: int, color: Color, alignment: HorizontalAlignment, wrap: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(label)
	return label


func _panel_style(radius: int, bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
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


func _button_style(color: Color, border: Color, border_width: int) -> StyleBoxFlat:
	return _panel_style(BUTTON_RADIUS, color, border, border_width)


func _answer_text_style(bg: Color, border: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var style := _panel_style(BUTTON_RADIUS, bg, border, border_width)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


func _letter_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := _panel_style(BUTTON_RADIUS, bg, border, 3)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _panel_margin(parent: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)

	if parent != null:
		parent.add_child(margin)

	return margin


func _apply_font(control: Control) -> void:
	if _font == null:
		return

	control.add_theme_font_override("font", _font)


func _bbcode_escape(value: String) -> String:
	return value.replace("[", "[lb]").replace("]", "[rb]")


func _play_sfx(id: String) -> void:
	id = id.strip_edges()

	if id.is_empty():
		return

	var sfx := get_node_or_null("/root/UnilearnSFX")

	if sfx != null:
		if "enabled" in sfx and not bool(sfx.enabled):
			return

		if sfx.has_method("play"):
			sfx.call("play", id)
			return

		if sfx.has_method("play_sfx"):
			sfx.call("play_sfx", id)
			return

	var fallbacks := [
		get_node_or_null("/root/UnilearnSfx"),
		get_node_or_null("/root/SFX"),
		get_node_or_null("/root/Sfx"),
		get_node_or_null("/root/SfxService"),
		get_node_or_null("/root/AudioService"),
		get_node_or_null("/root/SoundManager"),
		get_node_or_null("/root/AudioManager"),
	]

	for node in fallbacks:
		if node == null:
			continue

		if node.has_method("play_sfx"):
			node.call("play_sfx", id)
			return

		if node.has_method("play_ui"):
			node.call("play_ui", id)
			return

		if node.has_method("play"):
			node.call("play", id)
			return

		if node.has_method("play_sound"):
			node.call("play_sound", id)
			return

		if node.has_method("play_click") and id == sfx_click_id:
			node.call("play_click")
			return


func _enter_ai_thinking_visual() -> void:
	if _ai_thinking_visual_active:
		return

	if not has_node("/root/AIState"):
		return

	_ai_thinking_visual_active = true
	AIState.set_command(_data.name if _data != null else "", "quiz_generation")
	AIState.set_state(AIState.State.THINKING)


func _release_ai_thinking_visual() -> void:
	if not _ai_thinking_visual_active:
		return

	_ai_thinking_visual_active = false

	if not has_node("/root/AIState"):
		return

	AIState.set_command("", "")
	AIState.set_state(AIState.State.IDLE)


func _accent_color() -> Color:
	var settings := get_node_or_null("/root/UnilearnUserSettings")

	if settings != null and settings.has_method("get_accent_color"):
		return settings.get_accent_color()

	return Color("#B56CFF")


func _accent_soft_color() -> Color:
	var accent := _accent_color()
	return Color(accent.r, accent.g, accent.b, 0.16)

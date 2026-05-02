extends Control

const LOGIN_SCENE := "res://app/auth/LoginScreen.tscn"
const GLOBAL_UP_SHIFT := 80.0
const UNDERLINE_WIDTH_MULTIPLIER := 1.25

const WHITE := Color("#FFFFFF")
const BLACK := Color("#000000")
const TRANSPARENT := Color(1, 1, 1, 0)

@onready var panel: PanelContainer = $AuthPanel
@onready var margin: MarginContainer = $AuthPanel/MarginContainer
@onready var box: VBoxContainer = $AuthPanel/MarginContainer/VBoxContainer

@onready var title_label: Label = $AuthPanel/MarginContainer/VBoxContainer/Title
@onready var underline: ColorRect = $AuthPanel/MarginContainer/VBoxContainer/Underline
@onready var email_label: Label = $AuthPanel/MarginContainer/VBoxContainer/Email
@onready var logout_button: Button = $AuthPanel/MarginContainer/VBoxContainer/Logout

@onready var ai_assistant: AIAssistant = $AIAssistant

var button_tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)

	RenderingServer.set_default_clear_color(Color("#050712"))

	SpaceBackground.set_space_reveal(1.0)
	SpaceBackground.set_nebula_reveal(0.7)
	SpaceBackground.star_reveal = 1.0
	SpaceBackground.travel_speed_multiplier = 0.0

	_setup_layout()
	_setup_style()
	_setup_logic()
	_setup_ai_assistant()

	call_deferred("_fix_pivots")
	call_deferred("_fix_underline")

	await get_tree().process_frame
	_animate_in()


func _setup_ai_assistant() -> void:
	ai_assistant.process_mode = Node.PROCESS_MODE_ALWAYS
	ai_assistant.z_index = 999


func _setup_layout() -> void:
	var screen := get_viewport_rect().size
	var padding := 54.0

	panel.set_anchors_preset(Control.PRESET_CENTER, false)
	panel.size = Vector2(screen.x - padding * 2.0, min(screen.y * 0.82, 960.0))
	panel.position = (screen - panel.size) * 0.5 - Vector2(0, GLOBAL_UP_SHIFT)

	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 0)

	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 30)

	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	title_label.custom_minimum_size = Vector2(0, 140)
	email_label.custom_minimum_size = Vector2(0, 80)
	logout_button.custom_minimum_size = Vector2(0, 124)

	logout_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	email_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _setup_style() -> void:
	panel.add_theme_stylebox_override("panel", _style_box(TRANSPARENT, 0, 0))

	title_label.text = "Unilearn"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	title_label.add_theme_font_size_override("font_size", 170)
	title_label.add_theme_color_override("font_color", WHITE)

	underline.color = WHITE
	underline.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	if FirebaseAuth.email != "":
		email_label.text = FirebaseAuth.email
	else:
		email_label.text = "Logged in"

	email_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	email_label.add_theme_font_size_override("font_size", 34)
	email_label.add_theme_color_override("font_color", Color(1,1,1,0.75))

	logout_button.text = "Logout"
	_style_primary_button(logout_button)


func _style_primary_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 42)

	button.add_theme_color_override("font_color", BLACK)
	button.add_theme_color_override("font_hover_color", BLACK)
	button.add_theme_color_override("font_pressed_color", BLACK)

	button.add_theme_stylebox_override("normal", _style_box(WHITE, 0, 34))
	button.add_theme_stylebox_override("hover", _style_box(WHITE, 0, 34))
	button.add_theme_stylebox_override("pressed", _style_box(WHITE, 0, 34))


func _style_box(bg: Color, border_width: int, radius: int, border_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.border_width_left = border_width
	s.border_width_right = border_width
	s.border_width_top = border_width
	s.border_width_bottom = border_width
	s.border_color = border_color
	s.content_margin_left = 38
	s.content_margin_right = 38
	s.content_margin_top = 24
	s.content_margin_bottom = 24
	return s


func _setup_logic() -> void:
	logout_button.pressed.connect(_logout)

	logout_button.button_down.connect(func():
		_fix_pivots()
		_scale_button(Vector2(0.94, 0.94), 0.08)
	)

	logout_button.button_up.connect(func():
		_fix_pivots()
		_scale_button(Vector2(1.04, 1.04), 0.1, true)
	)


func _logout() -> void:
	FirebaseAuth.logout()
	call_deferred("_go_login")


func _go_login() -> void:
	get_tree().change_scene_to_file(LOGIN_SCENE)


func _animate_in() -> void:
	panel.modulate.a = 0.0
	panel.position.y += 90
	panel.scale = Vector2(0.96, 0.96)
	panel.pivot_offset = panel.size * 0.5

	underline.scale.x = 0.0

	for c in box.get_children():
		if c is Control:
			c.modulate.a = 0
			c.position.y += 28

	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_OUT)

	t.tween_property(panel, "modulate:a", 1, 0.45)
	t.parallel().tween_property(panel, "position:y", panel.position.y - 90, 0.55)
	t.parallel().tween_property(panel, "scale", Vector2.ONE, 0.55)

	for i in box.get_child_count():
		var c := box.get_child(i)
		if c is Control:
			t.parallel().tween_interval(0.08 + i * 0.05).finished.connect(func():
				var local := create_tween()
				local.tween_property(c, "modulate:a", 1, 0.3)
				local.parallel().tween_property(c, "position:y", c.position.y - 28, 0.3)

				if c == underline:
					_fix_underline()
					underline.scale.x = 0
					local.parallel().tween_property(underline, "scale:x", 1, 0.4)
			)


# ---------------- HELPERS ----------------
func _fix_underline() -> void:
	var font := title_label.get_theme_font("font")
	var font_size := title_label.get_theme_font_size("font_size")
	var text_size := font.get_string_size(title_label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)

	var w := text_size.x * UNDERLINE_WIDTH_MULTIPLIER
	underline.custom_minimum_size = Vector2(w, 6)
	underline.size = Vector2(w, 6)
	underline.pivot_offset = underline.size * 0.5


func _fix_pivots() -> void:
	logout_button.pivot_offset = logout_button.size * 0.5


func _scale_button(button_scale: Vector2, duration: float, back := false) -> void:
	if button_tween:
		button_tween.kill()

	button_tween = create_tween()
	button_tween.set_trans(Tween.TRANS_BACK)
	button_tween.set_ease(Tween.EASE_OUT)
	button_tween.tween_property(logout_button, "scale", button_scale, duration)

	if back:
		button_tween.tween_property(logout_button, "scale", Vector2.ONE, 0.1)

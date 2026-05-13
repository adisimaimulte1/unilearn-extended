extends Control

const GOOGLE_WEB_CLIENT_ID := "302625054209-3lbcj4hra1c9vqepg0cn5vpj704389dg.apps.googleusercontent.com"

const APP_SCENE := "res://app/content/AppContentScreen.tscn"
const GLOBAL_UP_SHIFT := 80.0
const UNDERLINE_WIDTH_MULTIPLIER := 1.25

const WHITE := Color("#FFFFFF")
const BLACK := Color("#000000")
const TRANSPARENT := Color(1, 1, 1, 0)

@onready var panel: PanelContainer = $AuthPanel
@onready var margin: MarginContainer = $AuthPanel/MarginContainer
@onready var box: VBoxContainer = $AuthPanel/MarginContainer/VBoxContainer

@onready var title_label: Label = $AuthPanel/MarginContainer/VBoxContainer/Title
@onready var title_underline: ColorRect = $AuthPanel/MarginContainer/VBoxContainer/TitleUnderline

@onready var email_input: LineEdit = $AuthPanel/MarginContainer/VBoxContainer/Email
@onready var password_input: LineEdit = $AuthPanel/MarginContainer/VBoxContainer/Password
@onready var error_label: Label = $AuthPanel/MarginContainer/VBoxContainer/ErrorLabel
@onready var login_button: Button = $AuthPanel/MarginContainer/VBoxContainer/LoginButton
@onready var google_button: Button = $AuthPanel/MarginContainer/VBoxContainer/GoogleButton
@onready var forgot_button: Button = $AuthPanel/MarginContainer/VBoxContainer/ForgotPasswordButton
@onready var create_button: Button = $AuthPanel/MarginContainer/VBoxContainer/CreateAccountButton

var title_gap_spacer: Control
var button_tweens: Dictionary = {}
var is_register_mode := false
var google_sign_in = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)

	RenderingServer.set_default_clear_color(Color("#050712"))

	_create_title_gap_spacer()
	_setup_layout()
	_setup_style()
	_setup_logic()
	_setup_google_sign_in()
	_setup_settings_listener()

	call_deferred("_fix_button_pivots")
	call_deferred("_fix_underline_size")

	await get_tree().process_frame
	_animate_in()


func _create_title_gap_spacer() -> void:
	title_gap_spacer = Control.new()
	title_gap_spacer.name = "TitleGapSpacer"
	title_gap_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title_gap_spacer)
	box.move_child(title_gap_spacer, title_underline.get_index() + 1)


func _setup_layout() -> void:
	var screen_size := get_viewport_rect().size
	var side_padding := 54.0

	panel.set_anchors_preset(Control.PRESET_CENTER, false)
	panel.size = Vector2(screen_size.x - side_padding * 2.0, min(screen_size.y * 0.82, 960.0))
	panel.position = (screen_size - panel.size) * 0.5 - Vector2(0.0, GLOBAL_UP_SHIFT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 0)

	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 30)

	title_label.custom_minimum_size = Vector2(0, 140)
	title_underline.custom_minimum_size = Vector2(360, 6)
	title_gap_spacer.custom_minimum_size = Vector2(0, 40)

	email_input.custom_minimum_size = Vector2(0, 124)
	password_input.custom_minimum_size = Vector2(0, 124)
	login_button.custom_minimum_size = Vector2(0, 124)
	google_button.custom_minimum_size = Vector2(0, 124)

	forgot_button.custom_minimum_size = Vector2(0, 64)
	create_button.custom_minimum_size = Vector2(0, 64)
	error_label.custom_minimum_size = Vector2(0, 44)

func _setup_style() -> void:
	panel.add_theme_stylebox_override("panel", _style_box(TRANSPARENT, 0, 0))

	title_label.text = "Unilearn"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	title_label.add_theme_font_size_override("font_size", 170)
	title_label.add_theme_color_override("font_color", WHITE)

	title_underline.color = WHITE
	title_underline.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	email_input.placeholder_text = "Email"
	password_input.placeholder_text = "Password"
	password_input.secret = true

	_style_input(email_input)
	_style_input(password_input)

	login_button.text = "Login"
	google_button.text = "Sign in with Google"
	forgot_button.text = "Forgot password?"
	create_button.text = "Don’t have an account? Register"

	_style_primary_button(login_button)
	_style_primary_button(google_button)
	_style_text_button(forgot_button)
	_style_text_button(create_button)

	_set_message("", false)


# -----------------------------------------------------------------------------
# Split-script virtual method declarations for inherited login layers.
# -----------------------------------------------------------------------------
func _setup_logic() -> void:
	pass

func _animate_in() -> void:
	pass

func _fix_underline_size() -> void:
	pass

func _fix_button_pivots() -> void:
	pass

func _style_input(_input: LineEdit) -> void:
	pass

func _style_primary_button(_button: Button) -> void:
	pass

func _style_text_button(_button: Button) -> void:
	pass


func _get_highlight_color() -> Color:
	var settings := get_node_or_null("/root/UnilearnUserSettings")
	if settings != null and settings.has_method("get_accent_color"):
		return settings.call("get_accent_color")
	return Color.WHITE


func _set_loading(_value: bool) -> void:
	pass

func _set_message(_message: String, _status_message: bool) -> void:
	pass

func _submit_auth() -> void:
	pass

func _forgot_password() -> void:
	pass

func _enter_app() -> void:
	pass

func _google_login() -> void:
	pass

func _on_google_sign_in_success(_arg1 = "", _arg2 = "", _arg3 = "") -> void:
	pass

func _on_google_sign_in_failed(_error: String) -> void:
	pass

func _play_sfx(_id: String) -> void:
	pass

func _setup_settings_listener() -> void:
	pass

func _setup_google_sign_in() -> void:
	pass


func _style_box(_bg: Color, _border_width: int, _radius: int, _border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	return StyleBoxFlat.new()

func _clean_error(error: String) -> String:
	return error

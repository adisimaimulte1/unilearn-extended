extends CanvasLayer

signal closed

const FONT_PATH := "res://assets/fonts/JockeyOne-Regular.ttf"
const MULTIPLAYER_ICON_PATH := "res://assets/app/buttons/button_multiplayer.png"

const POPUP_SLIDE_DURATION := 0.42
const POPUP_FADE_DURATION := 0.22
const DIM_FADE_DURATION := 0.26
const POPUP_SIDE_PADDING := 80.0

const COLOR_PANEL := Color(0.0, 0.0, 0.0, 0.82)
const COLOR_BORDER := Color.WHITE
const COLOR_TEXT := Color.WHITE
const COLOR_SUBTITLE := Color(1.0, 1.0, 1.0, 0.58)
const COLOR_PLACEHOLDER := Color(1.0, 1.0, 1.0, 0.42)
const COLOR_SCROLL_TRACK := Color(1.0, 1.0, 1.0, 0.06)
const COLOR_SCROLL_GRAB := Color(1.0, 1.0, 1.0, 0.34)
const COLOR_SCROLL_GRAB_HOVER := Color(1.0, 1.0, 1.0, 0.52)
const COLOR_STATUS := Color(1.0, 0.82, 0.34, 0.98)

const BUTTON_PRESS_SCALE := Vector2(0.88, 0.88)
const BUTTON_RELEASE_SCALE := Vector2(1.10, 1.10)
const BUTTON_DOWN_TIME := 0.055
const BUTTON_UP_TIME := 0.11
const BUTTON_SETTLE_TIME := 0.10
const BUTTON_COLOR_TWEEN_TIME := 0.34

@export var panel_width_ratio: float = 0.96
@export var panel_height_ratio: float = 0.96
@export var panel_max_width: float = 1380.0
@export var panel_max_height: float = 1260.0
@export var panel_padding_x: int = 34
@export var panel_padding_y: int = 34

var reduce_motion_enabled := false

var _root: Control
var _dim: ColorRect
var _slide_root: Control
var _panel: PanelContainer
var _body_root: Control
var _main_view: Control
var _username_box: LineEdit
var _username_clear_button: Control
var _connect_button: Control
var _nearby_scroll: ScrollContainer
var _nearby_scroll_margin: MarginContainer
var _nearby_content: VBoxContainer
var _nearby_list: VBoxContainer
var _nearby_empty_label: Label
var _nearby_refresh_timer: Timer
var _center_position := Vector2.ZERO
var _closing := false
var _popup_tween: Tween
var _button_bounce_tween: Tween
var _button_color_tween: Tween
var _button_highlight_blend := 0.0
var _button_pressed := false
var _button_hovered := false
var _button_toggled := false
var _location_permission_flow_running := false
var _last_saved_display_name := ""
var _nearby_players: Array[Dictionary] = []
var _nearby_load_generation := 0
var _app_font: Font = null
var _multiplayer_icon: Texture2D = null
var _sfx_node: Node = null
var _settings_node: Node = null



func setup(_reduce_motion_enabled: bool = false) -> void:
	reduce_motion_enabled = _reduce_motion_enabled

func _build_ui() -> void:
	pass


func _prepare_center_position() -> void:
	pass


func _play_intro() -> void:
	pass


func close_popup() -> void:
	pass


func _panel_style() -> StyleBoxFlat:
	return StyleBoxFlat.new()


func _search_style() -> StyleBoxFlat:
	return StyleBoxFlat.new()


func _square_button_style(_pressed: bool = false) -> StyleBoxFlat:
	return StyleBoxFlat.new()

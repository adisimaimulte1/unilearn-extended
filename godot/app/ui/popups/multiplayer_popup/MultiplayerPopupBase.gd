extends CanvasLayer

signal closed

const FONT_PATH := "res://assets/fonts/JockeyOne-Regular.ttf"
const MULTIPLAYER_ICON_PATH := "res://assets/app/buttons/button_multiplayer.png"
const PLANET_CARDS_ICON_PATH := "res://assets/app/buttons/button_card.png"
const GALAXY_CONSOLE_ICON_PATH := "res://assets/app/buttons/button_galaxy.png"

const USE_DUMMY_NEARBY_PLAYERS := false
const SWIPE_DEADZONE := 12.0
const SWIPE_TRIGGER_RATIO := 0.20
const SWIPE_COMMIT_RATIO := 0.85
const SWIPE_MAX_DISTANCE := 270.0
const SWIPE_RELEASE_TIME := 0.20
const SWIPE_ACTION_TIME := 0.20
const NEARBY_PLAYER_CARD_BATCH_SIZE := 1
const NEARBY_BUILD_FRAME_BUDGET_MSEC := 3
const NEARBY_CARD_ENTER_SCALE := Vector2(0.92, 0.92)
const NEARBY_CARD_ENTER_TIME := 0.28
const NEARBY_CARD_ENTER_STAGGER := 0.035
const NEARBY_CARD_ANIMATION_LIMIT := 5
const NEARBY_RUNTIME_VIEWPORT_MARGIN := 720.0
const NEARBY_RUNTIME_VISIBILITY_MIN_INTERVAL_MSEC := 90
const NEARBY_PLAYER_UI_LOST_GRACE_MSEC := 2500
const NEARBY_SYNC_HEARTBEAT_INTERVAL_SEC := 0.12
const NEARBY_SYNC_MIN_REVEAL_DELAY_MSEC := 20
const USERNAME_MAX_CHARS := 16

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

const MULTIPLAYER_TOAST_WIDTH := 553.0
const MULTIPLAYER_TOAST_HEIGHT := 188.0
const MULTIPLAYER_TOAST_TOP_MARGIN := 320.0
const MULTIPLAYER_TOAST_RIGHT_MARGIN := 34.0
const MULTIPLAYER_TOAST_LAYER := 10049
const MULTIPLAYER_TOAST_LEFT_MARGIN := 34.0
const MULTIPLAYER_TOAST_PAIR_GAP := 34.0
const MULTIPLAYER_TOAST_IN_TIME := 0.58
const MULTIPLAYER_TOAST_OUT_TIME := 0.46
const MULTIPLAYER_TOAST_ICON_SIZE := 132.0
const MULTIPLAYER_TOAST_PENDING_HOLD_TIME := 1.6
const MULTIPLAYER_TOAST_RESOLVED_HOLD_TIME := 1.45
const MULTIPLAYER_TOAST_PENDING_EXPIRE_TIME := 50.0
const MULTIPLAYER_WAITING_DOTS_INTERVAL := 1.0
const MULTIPLAYER_TEST_MIRROR_INCOMING_ON_SENT := false
const MULTIPLAYER_INCOMING_CARD_WIDTH := 553.0
const MULTIPLAYER_INCOMING_CARD_HEIGHT := 188.0

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
var _ble_plugin: Object = null
var _ble_last_players_json := ""
var _ble_discovery_running := false
var _ble_name_cache: Dictionary = {}
var _ble_name_requests: Dictionary = {}
var _ble_latest_players_by_uid: Dictionary = {}
var _ble_known_players_by_uid: Dictionary = {}
var _ble_stable_players_by_uid: Dictionary = {}
var _ble_pending_players_by_uid: Dictionary = {}
var _ble_sync_request_in_flight: Dictionary = {}
var _ble_sync_reveal_generation: Dictionary = {}
var _ble_sync_reveal_at_by_uid: Dictionary = {}
var _ble_peer_explicit_leave_at_by_uid: Dictionary = {}
var _ble_sync_heartbeat_timer: Timer = null
var _ble_player_removal_generation: Dictionary = {}
var _center_position := Vector2.ZERO
var _closing := false
var _closed_signal_sent := false
var _kept_alive_for_universal_toasts := false
var _popup_tween: Tween
var _button_bounce_tween: Tween
var _button_color_tween: Tween
var _button_highlight_blend := 0.0
var _button_pressed := false
var _button_hovered := false
var _button_toggled := false
var _sync_mode_active := false
var _sync_player: Dictionary = {}
var _location_permission_flow_running := false
var _ble_permission_flow_running := false
var _last_saved_display_name := ""
var _nearby_players: Array[Dictionary] = []
var _nearby_load_generation := 0
var _nearby_card_swipe_lock := false
var _nearby_build_generation := 0
var _nearby_cards_by_uid: Dictionary = {}
var _nearby_scroll_visibility_connected := false
var _nearby_runtime_visibility_update_pending := false
var _nearby_last_runtime_visibility_msec := -1000000
var _nearby_animate_next_build := false
var _nearby_theme_color_last := Color(-1.0, -1.0, -1.0, -1.0)
var _app_font: Font = null
var _multiplayer_icon: Texture2D = null
var _planet_cards_icon: Texture2D = null
var _galaxy_console_icon: Texture2D = null
var _sfx_node: Node = null
var _settings_node: Node = null

var _request_toast_layer: CanvasLayer = null
var _request_toast_panel: PanelContainer = null
var _request_toast_title_label: Label = null
var _request_toast_name_label: Label = null
var _request_toast_status_label: Label = null
var _request_toast_icon: Control = null
var _request_toast_tween: Tween = null
var _request_toast_universal_expire_timer: Timer = null
var _request_toast_generation := 0
var _request_toast_expire_generation := 0
var _request_toast_waiting_dots_generation := 0
var _request_toast_waiting_base_status := ""
var _request_toast_waiting_dots_timer: Timer = null
var _request_toast_waiting_dots_step := 0
var _multiplayer_request_expire_generation: int = 0
var _multiplayer_request_navigate_home_after_toast := false
var _multiplayer_request_start_at_ms := 0
var _multiplayer_request_resolved_action: String = ""
var _multiplayer_request_resolved_id: String = ""
var _multiplayer_request_pending := false
var _multiplayer_request_pending_id := ""
var _multiplayer_request_pending_action := ""
var _multiplayer_request_pending_player_uid := ""
var _multiplayer_request_pending_player_name := ""
var _multiplayer_request_pinned_player: Dictionary = {}
var _multiplayer_request_signal_owner_id := 0

var _incoming_request_panel: PanelContainer = null
var _incoming_request_title_label: Label = null
var _incoming_request_name_label: Label = null
var _incoming_request_status_label: Label = null
var _incoming_request_icon: Control = null
var _incoming_request_action_background: Control = null
var _incoming_request_input_surface: Control = null
var _incoming_request_press_tween: Tween = null
var _incoming_request_accept_button: Control = null
var _incoming_request_deny_button: Control = null
var _incoming_request_tween: Tween = null
var _incoming_request_generation := 0
var _incoming_request_universal_expire_timer: Timer = null
var _incoming_request_expire_generation := 0
var _incoming_request_active := false
var _incoming_request_id := ""
var _incoming_request_action := ""
var _incoming_request_sender_uid := ""
var _incoming_request_sender_name := ""
var _incoming_request_payload: Dictionary = {}
var _incoming_request_dragging := false
var _incoming_request_drag_start := Vector2.ZERO
var _incoming_request_drag_offset := 0.0
var _incoming_request_drag_pointer_id := -999
var _incoming_request_drag_started := false
var _incoming_request_pressing := false

var _scroll: ScrollContainer
var _scroll_pointer_id := -999
var _scroll_dragging := false
var _scroll_start_y := 0.0
var _scroll_last_y := 0.0
var _scroll_start_value := 0
var _scroll_last_time := 0.0
var _scroll_velocity := 0.0
var _scroll_drag_deadzone := 8.0
var _scroll_wheel_impulse := 1350.0
var _scroll_friction := 7.5
var _scroll_max_velocity := 3600.0
var _cached_max_scroll_bar: VScrollBar = null



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


func _reset_scroll_motion() -> void:
	_scroll_pointer_id = -999
	_scroll_dragging = false
	_scroll_velocity = 0.0
	_cached_max_scroll_bar = null

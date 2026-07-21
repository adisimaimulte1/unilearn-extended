extends Node

const DISPLAY_NAME_MAX_CHARS := 16

signal settings_changed
signal connectivity_changed(internet_available: bool, online_mode_available: bool)

const SAVE_PATH := "user://unilearn_settings.cfg"
const SECTION := "settings"
const MICROPHONE_PERMISSION := "android.permission.RECORD_AUDIO"
const ANDROID_NEARBY_PERMISSIONS := [
	"android.permission.BLUETOOTH_SCAN",
	"android.permission.BLUETOOTH_ADVERTISE",
	"android.permission.BLUETOOTH_CONNECT"
]
const CONNECTIVITY_NATIVE_POLL_SECONDS := 0.75

const ACCENT_PURPLE := Color("#B56CFF")
const ACCENT_ORANGE := Color("#c89f39ff")

var music_enabled: bool = true
var sfx_enabled: bool = true
var apollo_enabled: bool = false
var location_enabled: bool = false
var reduce_motion_enabled: bool = false
var display_name: String = ""
var play_login_success_intro_sfx: bool = false

var theme_dark_mode: bool = true
var theme_accent_name: String = "purple"
var internet_available: bool = false
var online_mode_available: bool = false
var _connectivity_timer: Timer = null
var tutorial_pending_account_id: String = ""
var tutorial_completed_account_ids: Array[String] = []


func _ready() -> void:
	load_settings()
	_setup_connectivity_monitor()


func _setup_connectivity_monitor() -> void:
	_connectivity_timer = Timer.new()
	_connectivity_timer.name = "UnilearnConnectivityTimer"
	_connectivity_timer.wait_time = CONNECTIVITY_NATIVE_POLL_SECONDS
	_connectivity_timer.one_shot = true
	_connectivity_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_connectivity_timer.timeout.connect(_poll_connectivity)
	add_child(_connectivity_timer)
	_poll_connectivity()


func _poll_connectivity() -> void:
	var native_state: Variant = _get_android_connectivity_state()
	var reachable := bool(native_state) if native_state is bool else _has_local_network_route()
	_set_connectivity_state(reachable)
	_schedule_connectivity_poll()


func _schedule_connectivity_poll() -> void:
	if not is_instance_valid(_connectivity_timer):
		return
	_connectivity_timer.start(CONNECTIVITY_NATIVE_POLL_SECONDS)


func _get_android_connectivity_state() -> Variant:
	# Query Android's connected network directly. This performs no DNS lookup and
	# opens no socket. Do not require NET_CAPABILITY_VALIDATED: several Android/OEM
	# combinations report it late or never, which incorrectly locks the app offline.
	if not OS.has_feature("android") or not Engine.has_singleton("AndroidRuntime"):
		return null
	var android_runtime: Variant = Engine.get_singleton("AndroidRuntime")
	if android_runtime == null:
		return null
	var context: Variant = android_runtime.getApplicationContext()
	if context == null:
		return null
	var connectivity_manager: Variant = context.getSystemService("connectivity")
	if connectivity_manager == null:
		return null
	var network_info: Variant = connectivity_manager.getActiveNetworkInfo()
	if network_info == null:
		return false
	return bool(network_info.isConnected())


func _has_local_network_route() -> bool:
	# Non-Android/editor fallback. Ignore loopback and link-local addresses; any
	# remaining assigned address means the OS currently has an active network route.
	for address_variant in IP.get_local_addresses():
		var address := str(address_variant).strip_edges().to_lower()
		if address.is_empty() or address == "127.0.0.1" or address == "::1":
			continue
		if address.begins_with("169.254.") or address.begins_with("fe80:"):
			continue
		return true
	return false


func _set_connectivity_state(reachable: bool) -> void:
	var next_online := reachable and is_user_logged_in()
	if internet_available == reachable and online_mode_available == next_online:
		return
	internet_available = reachable
	online_mode_available = next_online
	if not online_mode_available and location_enabled:
		location_enabled = false
		save_settings()
	connectivity_changed.emit(internet_available, online_mode_available)
	settings_changed.emit()


func is_internet_available() -> bool:
	return internet_available


func is_online_mode_available() -> bool:
	return internet_available and is_user_logged_in()


func is_user_logged_in() -> bool:
	var auth := get_node_or_null("/root/FirebaseAuth")
	if auth == null:
		return false
	for property_name in ["uid", "local_id", "user_id"]:
		if property_name in auth and not str(auth.get(property_name)).strip_edges().is_empty():
			return true
	return false


func refresh_connectivity_now() -> void:
	if is_instance_valid(_connectivity_timer):
		_connectivity_timer.stop()
	_poll_connectivity()


func _notification(what: int) -> void:
	# Network toggles often happen while Android's system shade/settings screen is
	# covering the app. Probe immediately on return instead of waiting for the next tick.
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		refresh_connectivity_now()


func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)

	if err != OK:
		_sync_accent_from_dark_mode()
		save_settings()
		return

	var had_music_key := config.has_section_key(SECTION, "music_enabled")
	music_enabled = bool(config.get_value(SECTION, "music_enabled", true))
	sfx_enabled = bool(config.get_value(SECTION, "sfx_enabled", true))
	apollo_enabled = bool(config.get_value(SECTION, "apollo_enabled", false))
	location_enabled = bool(config.get_value(SECTION, "location_enabled", false))
	reduce_motion_enabled = bool(config.get_value(SECTION, "reduce_motion_enabled", false))
	display_name = str(config.get_value(SECTION, "display_name", "")).substr(0, DISPLAY_NAME_MAX_CHARS)
	tutorial_pending_account_id = str(config.get_value(SECTION, "tutorial_pending_account_id", "")).strip_edges()
	tutorial_completed_account_ids.clear()
	var completed_tutorials: Variant = config.get_value(SECTION, "tutorial_completed_account_ids", [])
	if completed_tutorials is Array:
		for account_variant in completed_tutorials:
			var account_id := str(account_variant).strip_edges()
			if not account_id.is_empty() and not tutorial_completed_account_ids.has(account_id):
				tutorial_completed_account_ids.append(account_id)

	theme_dark_mode = bool(config.get_value(SECTION, "theme_dark_mode", true))
	theme_accent_name = str(config.get_value(SECTION, "theme_accent_name", "")).strip_edges().to_lower()

	if theme_accent_name != "purple" and theme_accent_name != "orange":
		_sync_accent_from_dark_mode()
	else:
		_sync_dark_mode_from_accent()

	if not had_music_key:
		save_settings()


func save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value(SECTION, "music_enabled", music_enabled)
	config.set_value(SECTION, "sfx_enabled", sfx_enabled)
	config.set_value(SECTION, "apollo_enabled", apollo_enabled)
	config.set_value(SECTION, "location_enabled", location_enabled)
	config.set_value(SECTION, "reduce_motion_enabled", reduce_motion_enabled)
	config.set_value(SECTION, "display_name", display_name)
	config.set_value(SECTION, "tutorial_pending_account_id", tutorial_pending_account_id)
	config.set_value(SECTION, "tutorial_completed_account_ids", tutorial_completed_account_ids)

	config.set_value(SECTION, "theme_dark_mode", theme_dark_mode)
	config.set_value(SECTION, "theme_accent_name", theme_accent_name)

	config.save(SAVE_PATH)


func mark_tutorial_pending_for_current_account() -> void:
	var account_id := _current_account_id()
	if account_id.is_empty():
		return
	tutorial_pending_account_id = account_id
	tutorial_completed_account_ids.erase(account_id)
	save_settings()


func should_offer_tutorial_for_current_account() -> bool:
	var account_id := _current_account_id()
	return not account_id.is_empty() \
		and tutorial_pending_account_id == account_id \
		and not tutorial_completed_account_ids.has(account_id)


func complete_tutorial_for_current_account() -> void:
	var account_id := _current_account_id()
	if account_id.is_empty():
		return
	if not tutorial_completed_account_ids.has(account_id):
		tutorial_completed_account_ids.append(account_id)
	if tutorial_pending_account_id == account_id:
		tutorial_pending_account_id = ""
	save_settings()


func _current_account_id() -> String:
	var auth := get_node_or_null("/root/FirebaseAuth")
	if auth == null:
		return ""
	for property_name in ["uid", "local_id", "user_id"]:
		if property_name in auth:
			var value := str(auth.get(property_name)).strip_edges()
			if not value.is_empty():
				return value
	return ""


func is_microphone_permission_granted() -> bool:
	if OS.get_name() != "Android":
		return true

	if not OS.has_method("get_granted_permissions"):
		return true

	var granted_permissions: PackedStringArray = OS.get_granted_permissions()
	return granted_permissions.has(MICROPHONE_PERMISSION)


func request_microphone_permission() -> void:
	if OS.get_name() != "Android":
		return

	if OS.has_method("request_permissions"):
		OS.request_permissions()


func is_location_permission_granted() -> bool:
	# Kept for compatibility with the existing multiplayer UI. It now means
	# "BLE nearby-device permission granted" rather than GPS permission granted.
	if OS.get_name() != "Android":
		return true
	if Engine.has_singleton("UnilearnBLE"):
		return bool(Engine.get_singleton("UnilearnBLE").call("hasPermissions"))
	return false


func request_location_permission() -> void:
	if OS.get_name() != "Android":
		return
	if Engine.has_singleton("UnilearnBLE"):
		var ble := Engine.get_singleton("UnilearnBLE")
		if not bool(ble.call("isBluetoothEnabled")):
			ble.call("requestEnableBluetooth")
		ble.call("requestPermissions")


func can_enable_apollo() -> bool:
	return is_microphone_permission_granted()


func can_enable_location() -> bool:
	return is_online_mode_available() and is_location_permission_granted()


func set_music_enabled(enabled: bool) -> void:
	if music_enabled == enabled:
		return

	music_enabled = enabled
	save_settings()
	settings_changed.emit()


func set_sfx_enabled(enabled: bool) -> void:
	if sfx_enabled == enabled:
		return

	sfx_enabled = enabled
	save_settings()
	settings_changed.emit()


func set_apollo_enabled(enabled: bool) -> void:
	if apollo_enabled == enabled:
		return

	apollo_enabled = enabled
	save_settings()
	settings_changed.emit()


func set_location_enabled(enabled: bool) -> void:
	enabled = enabled and is_online_mode_available() and is_location_permission_granted()

	if location_enabled == enabled:
		return

	location_enabled = enabled
	save_settings()
	settings_changed.emit()


func set_display_name(value: String) -> void:
	var clean_value := value.substr(0, DISPLAY_NAME_MAX_CHARS)

	if display_name == clean_value:
		return

	display_name = clean_value
	save_settings()
	settings_changed.emit()


func get_display_name() -> String:
	return display_name


func set_reduce_motion_enabled(enabled: bool) -> void:
	if reduce_motion_enabled == enabled:
		return

	reduce_motion_enabled = enabled
	save_settings()
	settings_changed.emit()


func set_theme_dark_mode(enabled: bool) -> void:
	var next_accent := "purple" if enabled else "orange"

	if theme_dark_mode == enabled and theme_accent_name == next_accent:
		return

	theme_dark_mode = enabled
	theme_accent_name = next_accent

	save_settings()
	settings_changed.emit()


func set_theme_accent_name(value: String) -> void:
	var clean_value := value.strip_edges().to_lower()

	if clean_value != "purple" and clean_value != "orange":
		clean_value = "purple"

	if theme_accent_name == clean_value:
		return

	theme_accent_name = clean_value
	_sync_dark_mode_from_accent()

	save_settings()
	settings_changed.emit()


func toggle_theme_accent() -> void:
	if theme_accent_name == "purple":
		set_theme_accent_name("orange")
	else:
		set_theme_accent_name("purple")


func _sync_accent_from_dark_mode() -> void:
	theme_accent_name = "purple" if theme_dark_mode else "orange"


func _sync_dark_mode_from_accent() -> void:
	theme_dark_mode = theme_accent_name == "purple"


func get_accent_color() -> Color:
	match theme_accent_name:
		"orange":
			return ACCENT_ORANGE
		_:
			return ACCENT_PURPLE


func get_panel_color() -> Color:
	return Color(0.0, 0.0, 0.0, 0.70)


func get_text_color() -> Color:
	return Color.WHITE


func get_muted_text_color() -> Color:
	return Color(0.72, 0.76, 0.84, 1.0)


func get_line_color() -> Color:
	return Color(1.0, 1.0, 1.0, 0.86)


func set_wake_word_detection_enabled(enabled: bool) -> void:
	set_apollo_enabled(enabled)


func is_wake_word_detection_enabled() -> bool:
	return apollo_enabled

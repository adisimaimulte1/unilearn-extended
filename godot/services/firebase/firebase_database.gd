extends Node

const DISPLAY_NAME_MAX_CHARS := 16

signal planet_card_xp_updated(card: PlanetData, xp_added: int)
signal multiplayer_request_received(payload: Dictionary)
signal multiplayer_request_accepted(payload: Dictionary)
signal multiplayer_request_denied(payload: Dictionary)
signal multiplayer_sync_closed(payload: Dictionary)
signal multiplayer_universe_event(payload: Dictionary)
signal multiplayer_trade_peer_card_selected(payload: Dictionary)
signal multiplayer_trade_start(payload: Dictionary)

const BACKEND_BASE_URL := UnilearnBackendService.BASE_URL

const USER_INIT_PATH := UnilearnBackendService.USER_INIT_PATH
const USER_PROFILE_PATH := UnilearnBackendService.USER_PROFILE_PATH
const NEARBY_MULTIPLAYER_PLAYERS_PATH := UnilearnBackendService.NEARBY_MULTIPLAYER_PLAYERS_PATH
const NEARBY_MULTIPLAYER_SYNC_REPORT_PATH := UnilearnBackendService.NEARBY_MULTIPLAYER_SYNC_REPORT_PATH
const NEARBY_MULTIPLAYER_SYNC_LEAVE_PATH := UnilearnBackendService.NEARBY_MULTIPLAYER_SYNC_LEAVE_PATH
const NEARBY_MULTIPLAYER_SYNC_LEAVE_ALL_PATH := UnilearnBackendService.NEARBY_MULTIPLAYER_SYNC_LEAVE_ALL_PATH
const MULTIPLAYER_REQUEST_SEND_PATH := UnilearnBackendService.MULTIPLAYER_REQUEST_SEND_PATH
const MULTIPLAYER_REQUEST_POLL_PATH := UnilearnBackendService.MULTIPLAYER_REQUEST_POLL_PATH
const MULTIPLAYER_REQUEST_RESPOND_PATH := UnilearnBackendService.MULTIPLAYER_REQUEST_RESPOND_PATH
const MULTIPLAYER_REQUEST_CANCEL_ACTIVE_PATH := UnilearnBackendService.MULTIPLAYER_REQUEST_CANCEL_ACTIVE_PATH
const MULTIPLAYER_SYNC_CLOSE_PATH := UnilearnBackendService.MULTIPLAYER_SYNC_CLOSE_PATH
const MULTIPLAYER_SYNC_EVENT_PATH := UnilearnBackendService.MULTIPLAYER_SYNC_EVENT_PATH
const MULTIPLAYER_TRADE_SELECT_PATH := UnilearnBackendService.MULTIPLAYER_TRADE_SELECT_PATH
const MULTIPLAYER_HOME_READY_PATH := UnilearnBackendService.MULTIPLAYER_HOME_READY_PATH
const MULTIPLAYER_TRADE_UI_READY_PATH := UnilearnBackendService.MULTIPLAYER_TRADE_UI_READY_PATH
const MULTIPLAYER_TRADE_CANCEL_PATH := UnilearnBackendService.MULTIPLAYER_TRADE_CANCEL_PATH
const MULTIPLAYER_REQUEST_POLL_INTERVAL_SEC := 0.10

var _multiplayer_request_poll_timer: Timer = null
var _multiplayer_request_poll_in_flight := false
var _multiplayer_request_seen_status: Dictionary = {}
var _multiplayer_trade_state_by_peer: Dictionary = {}
var _multiplayer_sync_seen_revision_by_request: Dictionary = {}
var _multiplayer_poll_token: String = ""
var _multiplayer_poll_token_cached_at_ms: int = 0
const MULTIPLAYER_POLL_TOKEN_CACHE_MS := 45000
const PLANET_CARDS_PATH := UnilearnBackendService.PLANET_CARDS_PATH
const GENERATE_PLANET_CARD_PATH := UnilearnBackendService.GENERATE_PLANET_CARD_PATH

const DEFAULT_TIMEOUT_SEC := UnilearnBackendService.DEFAULT_REQUEST_TIMEOUT_SEC
const PLANET_GENERATION_TIMEOUT_SEC := UnilearnBackendService.PLANET_GENERATION_TIMEOUT_SEC

const MAX_PLANET_QUERY_LENGTH := 120


func _ready() -> void:
	# This node is an autoload, so keep the multiplayer transport alive across
	# every screen. Universe-sync close events must still arrive while the
	# Multiplayer popup is closed or another popup/scene is open.
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_multiplayer_request_transport()


func initialize_user_account() -> Dictionary:
	var token := await _get_fresh_id_token()

	if token.strip_edges() == "":
		return {
			"success": false,
			"error": "MISSING_ID_TOKEN"
		}

	var default_cards: Array = []

	for planet: PlanetData in PlanetDataLibrary.get_all_planets():
		default_cards.append(planet.to_firebase_dict())

	return await _post_backend(USER_INIT_PATH, {
		"defaultCards": default_cards,
		# The app no longer stores galaxy data under the user document.
		# Backends that support this flag should skip creating /users/{uid}/galaxy.
		"createGalaxy": false,
		"skipGalaxy": true
	})


func get_user_profile() -> Dictionary:
	return await _get_backend(USER_PROFILE_PATH)


func save_user_display_name(display_name: String) -> Dictionary:
	return await _put_backend(USER_PROFILE_PATH, {
		"displayName": display_name.strip_edges().substr(0, DISPLAY_NAME_MAX_CHARS)
	})


func get_nearby_multiplayer_players() -> Dictionary:
	return await _get_backend(NEARBY_MULTIPLAYER_PLAYERS_PATH)


func report_nearby_multiplayer_detection(peer_uid: String, active: bool = true, trade_available: int = 0) -> Dictionary:
	peer_uid = peer_uid.strip_edges()
	if peer_uid.is_empty():
		return {
			"success": false,
			"error": "EMPTY_PEER_UID"
		}

	return await _post_backend(NEARBY_MULTIPLAYER_SYNC_REPORT_PATH, {
		"peerUid": peer_uid,
		"active": active,
		"tradeAvailable": 1 if trade_available == 1 else 0,
	})


func leave_nearby_multiplayer_detection(peer_uid: String) -> Dictionary:
	peer_uid = peer_uid.strip_edges()
	if peer_uid.is_empty():
		return {
			"success": false,
			"error": "EMPTY_PEER_UID"
		}

	return await _post_backend(NEARBY_MULTIPLAYER_SYNC_LEAVE_PATH, {
		"peerUid": peer_uid,
	})


func leave_all_nearby_multiplayer_detections(peer_uids: Array) -> Dictionary:
	var cleaned: Array[String] = []
	var seen: Dictionary = {}
	for value: Variant in peer_uids:
		var uid := str(value).strip_edges()
		if uid.is_empty() or seen.has(uid):
			continue
		seen[uid] = true
		cleaned.append(uid)

	if cleaned.is_empty():
		return {"success": true, "left": 0}

	return await _post_backend(NEARBY_MULTIPLAYER_SYNC_LEAVE_ALL_PATH, {
		"peerUids": cleaned,
	})


func get_multiplayer_player_by_uid(uid: String) -> Dictionary:
	uid = uid.strip_edges()
	if uid.is_empty():
		return {
			"success": false,
			"error": "EMPTY_UID"
		}

	# Resolve a BLE UID through the backend only once. The backend response shape
	# has changed a few times, so search it recursively instead of assuming that
	# the player array is always stored directly under a `players` key.
	var result: Dictionary = await get_nearby_multiplayer_players()
	if not bool(result.get("success", false)):
		return result

	var player := _find_player_by_uid_recursive(result, uid)
	if not player.is_empty():
		return {
			"success": true,
			"player": player
		}

	return {
		"success": false,
		"error": "PLAYER_NOT_FOUND",
		"uid": uid,
		"raw": result
	}


func _find_player_by_uid_recursive(value: Variant, wanted_uid: String) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		var candidate_uid := str(
			dictionary.get(
				"uid",
				dictionary.get(
					"userId",
					dictionary.get(
						"firebaseUid",
						dictionary.get("localId", dictionary.get("id", ""))
					)
				)
			)
		).strip_edges()

		if candidate_uid == wanted_uid:
			return dictionary.duplicate(true)

		for child: Variant in dictionary.values():
			var found := _find_player_by_uid_recursive(child, wanted_uid)
			if not found.is_empty():
				return found

	elif value is Array:
		for child: Variant in value:
			var found := _find_player_by_uid_recursive(child, wanted_uid)
			if not found.is_empty():
				return found

	return {}


func request_planet_card_trade(target_uid: String) -> Dictionary:
	return await _send_multiplayer_request(target_uid, "t")


func request_universe_sync(target_uid: String) -> Dictionary:
	return await _send_multiplayer_request(target_uid, "s")


func _send_multiplayer_request(target_uid: String, action_code: String) -> Dictionary:
	target_uid = target_uid.strip_edges()
	if target_uid.is_empty():
		return {"success": false, "error": "EMPTY_TARGET_UID"}
	start_multiplayer_request_transport()
	return await _post_backend(MULTIPLAYER_REQUEST_SEND_PATH, {"targetUid": target_uid, "action": action_code})


func respond_multiplayer_request(request_id: String, accepted: bool) -> Dictionary:
	request_id = request_id.strip_edges()
	if request_id.is_empty():
		return {"success": false, "error": "EMPTY_REQUEST_ID"}
	start_multiplayer_request_transport()
	return await _post_backend(MULTIPLAYER_REQUEST_RESPOND_PATH, {"requestId": request_id, "accepted": accepted})


func cancel_active_multiplayer_requests(reason: String = "location_disabled") -> Dictionary:
	start_multiplayer_request_transport()
	return await _post_backend(MULTIPLAYER_REQUEST_CANCEL_ACTIVE_PATH, {
		"reason": reason.strip_edges().to_lower(),
	})


func close_multiplayer_universe_sync(peer_uid: String) -> Dictionary:
	peer_uid = peer_uid.strip_edges()
	if peer_uid.is_empty():
		return {"success": false, "error": "EMPTY_PEER_UID"}
	start_multiplayer_request_transport()
	return await _post_backend(MULTIPLAYER_SYNC_CLOSE_PATH, {"peerUid": peer_uid})




func submit_multiplayer_universe_event(peer_uid: String, request_id: String, event_type: String, payload: Dictionary = {}) -> Dictionary:
	peer_uid = peer_uid.strip_edges()
	request_id = request_id.strip_edges()
	event_type = event_type.strip_edges().to_lower()
	if peer_uid.is_empty() or request_id.is_empty() or event_type.is_empty():
		return {"success": false, "error": "INVALID_SYNC_EVENT"}
	start_multiplayer_request_transport()
	return await _post_backend(MULTIPLAYER_SYNC_EVENT_PATH, {
		"peerUid": peer_uid,
		"requestId": request_id,
		"type": event_type,
		"payload": payload,
	})


func submit_multiplayer_trade_card(peer_uid: String, card: PlanetData, request_id: String = "") -> Dictionary:
	peer_uid = peer_uid.strip_edges()
	if peer_uid.is_empty() or card == null:
		return {"success": false, "error": "INVALID_TRADE_SELECTION"}
	start_multiplayer_request_transport()
	return await _post_backend(MULTIPLAYER_TRADE_SELECT_PATH, {
		"peerUid": peer_uid,
		"requestId": request_id.strip_edges(),
		"card": card.to_firebase_dict(),
	})


func mark_multiplayer_home_ready(request_id: String) -> Dictionary:
	return await _post_backend(MULTIPLAYER_HOME_READY_PATH, {"requestId": request_id.strip_edges()})

func mark_multiplayer_trade_ui_ready(request_id: String) -> Dictionary:
	return await _post_backend(MULTIPLAYER_TRADE_UI_READY_PATH, {"requestId": request_id.strip_edges()})

func cancel_multiplayer_trade(request_id: String) -> Dictionary:
	return await _post_backend(MULTIPLAYER_TRADE_CANCEL_PATH, {"requestId": request_id.strip_edges()})

func get_multiplayer_trade_state(peer_uid: String) -> Dictionary:
	return _multiplayer_trade_state_by_peer.get(peer_uid.strip_edges(), {}).duplicate(true)


func clear_multiplayer_trade_state(peer_uid: String) -> void:
	peer_uid = peer_uid.strip_edges()
	if peer_uid.is_empty():
		return
	_multiplayer_trade_state_by_peer.erase(peer_uid)


func start_multiplayer_request_transport() -> void:
	if is_instance_valid(_multiplayer_request_poll_timer):
		if _multiplayer_request_poll_timer.is_stopped():
			_multiplayer_request_poll_timer.start()
		return
	_multiplayer_request_poll_timer = Timer.new()
	_multiplayer_request_poll_timer.name = "MultiplayerRequestPollTimer"
	_multiplayer_request_poll_timer.wait_time = MULTIPLAYER_REQUEST_POLL_INTERVAL_SEC
	_multiplayer_request_poll_timer.one_shot = false
	_multiplayer_request_poll_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_multiplayer_request_poll_timer)
	_multiplayer_request_poll_timer.timeout.connect(_poll_multiplayer_requests)
	_multiplayer_request_poll_timer.start()
	_poll_multiplayer_requests()


func _poll_multiplayer_requests() -> void:
	if _multiplayer_request_poll_in_flight:
		return
	_multiplayer_request_poll_in_flight = true
	var result := await _get_backend_for_multiplayer_poll(MULTIPLAYER_REQUEST_POLL_PATH, 3.0)
	_multiplayer_request_poll_in_flight = false
	if not bool(result.get("success", false)):
		return
	var requests: Variant = result.get("requests", [])
	if not (requests is Array):
		return
	for item: Variant in requests:
		if not (item is Dictionary):
			continue
		var payload: Dictionary = (item as Dictionary).duplicate(true)
		var request_id := str(payload.get("requestId", "")).strip_edges()
		var status := str(payload.get("status", "pending")).strip_edges().to_lower()
		var peer_uid := str(payload.get("peerUid", "")).strip_edges()
		if not peer_uid.is_empty() and str(payload.get("action", "")) == "trade":
			if status in ["denied", "declined", "expired", "closed", "ended"]:
				_multiplayer_trade_state_by_peer.erase(peer_uid)
			elif int(payload.get("tradeStartAt", 0)) <= 0:
				# Cache only the pre-animation state needed when the trade popup is
				# still opening. A completed/start payload must not leak into the
				# next trade with the same player.
				_multiplayer_trade_state_by_peer[peer_uid] = payload.duplicate(true)
			else:
				_multiplayer_trade_state_by_peer.erase(peer_uid)
		if request_id.is_empty():
			continue
		var activity_revision := int(payload.get("activityRevision", 0))
		if status == "accepted" and activity_revision > 0:
			var activity_key := "%s:activity:%d" % [request_id, activity_revision]
			if not _multiplayer_request_seen_status.has(activity_key):
				_multiplayer_request_seen_status[activity_key] = true
				multiplayer_request_accepted.emit(payload)
		var trade_revision := int(payload.get("tradeRevision", 0))
		if str(payload.get("action", "")) == "trade" and trade_revision > 0:
			var trade_key := "%s:trade:%d" % [request_id, trade_revision]
			if not _multiplayer_request_seen_status.has(trade_key):
				_multiplayer_request_seen_status[trade_key] = true
				if bool(payload.get("peerCardChosen", false)):
					multiplayer_trade_peer_card_selected.emit(payload)
				if int(payload.get("tradeStartAt", 0)) > 0:
					multiplayer_trade_start.emit(payload)
		var sync_revision := int(payload.get("syncRevision", 0))
		var last_sync_revision := int(_multiplayer_sync_seen_revision_by_request.get(request_id, 0))
		var sync_events: Variant = payload.get("syncEvents", [])
		if sync_events is Array and sync_revision > last_sync_revision:
			for event_value: Variant in sync_events:
				if not (event_value is Dictionary):
					continue
				var sync_event: Dictionary = (event_value as Dictionary).duplicate(true)
				var event_revision := int(sync_event.get("revision", 0))
				if event_revision <= last_sync_revision:
					continue
				sync_event["requestId"] = request_id
				sync_event["peerUid"] = str(payload.get("peerUid", ""))
				multiplayer_universe_event.emit(sync_event)
			_multiplayer_sync_seen_revision_by_request[request_id] = sync_revision

		var status_key := "%s:%s" % [request_id, status]
		if _multiplayer_request_seen_status.has(status_key):
			continue
		_multiplayer_request_seen_status[status_key] = true
		if status in ["sync_closed", "closed", "ended"]:
			multiplayer_sync_closed.emit(payload)
		elif bool(payload.get("isSender", false)):
			if status == "accepted":
				multiplayer_request_accepted.emit(payload)
			elif status in ["denied", "declined", "expired"]:
				multiplayer_request_denied.emit(payload)
		elif status == "pending":
			multiplayer_request_received.emit(payload)
		elif status in ["denied", "declined", "expired"]:
			# The receiver must also be told when the requester cancels, most
			# importantly when the requester disables Nearby/location.
			multiplayer_request_denied.emit(payload)


func _get_backend_for_multiplayer_poll(path: String, timeout_sec: float) -> Dictionary:
	# Polling is already a single bulk endpoint for requests, trade state and sync-close
	# events. Reuse the current bearer token briefly instead of running the async token
	# freshness path on every 100 ms poll.
	var now_ms := Time.get_ticks_msec()
	if _multiplayer_poll_token.is_empty() or now_ms - _multiplayer_poll_token_cached_at_ms >= MULTIPLAYER_POLL_TOKEN_CACHE_MS:
		var current_token := ""
		if is_instance_valid(FirebaseAuth) and "id_token" in FirebaseAuth:
			current_token = str(FirebaseAuth.id_token).strip_edges()
		if current_token.is_empty() or _is_cached_token_missing_or_expiring_soon():
			current_token = await _get_fresh_id_token()
		_multiplayer_poll_token = current_token.strip_edges()
		_multiplayer_poll_token_cached_at_ms = now_ms
	if _multiplayer_poll_token.is_empty():
		return {"success": false, "error": "MISSING_ID_TOKEN"}
	var result := await _request_backend_with_token(path, HTTPClient.METHOD_GET, {}, timeout_sec, _multiplayer_poll_token)
	if str(result.get("error", "")) == "UNAUTHORIZED":
		_multiplayer_poll_token = ""
		_multiplayer_poll_token_cached_at_ms = 0
	return result


func _request_backend_with_token(
	path: String,
	method: HTTPClient.Method,
	body: Dictionary,
	timeout_sec: float,
	token: String
) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = timeout_sec
	add_child(request)
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]
	var request_body := ""
	if method != HTTPClient.METHOD_GET and method != HTTPClient.METHOD_DELETE:
		request_body = JSON.stringify(body)
	var err := request.request(UnilearnBackendService.url(path), headers, method, request_body)
	if err != OK:
		request.queue_free()
		return {"success": false, "error": "REQUEST_FAILED", "code": err}
	var response: Array = await request.request_completed
	request.queue_free()
	var result_code := int(response[0])
	var response_code := int(response[1])
	var response_body: PackedByteArray = response[3]
	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {"success": false, "error": _http_request_result_to_error(result_code), "status": response_code}
	if response_code == 401 or response_code == 403:
		return {"success": false, "error": "UNAUTHORIZED", "status": response_code}
	var parsed: Variant = JSON.parse_string(response_body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return {"success": false, "error": "INVALID_RESPONSE", "status": response_code}
	return parsed as Dictionary


func get_planet_cards() -> Dictionary:
	return await _get_backend(PLANET_CARDS_PATH)


func generate_planet_card(query: String) -> Dictionary:
	query = query.strip_edges()

	if query.length() < 2:
		return {
			"success": false,
			"error": "INVALID_QUERY"
		}

	if query.length() > MAX_PLANET_QUERY_LENGTH:
		query = query.substr(0, MAX_PLANET_QUERY_LENGTH).strip_edges()

	return await _post_backend(
		GENERATE_PLANET_CARD_PATH,
		{
			"query": query
		},
		PLANET_GENERATION_TIMEOUT_SEC
	)


func save_planet_card(card: PlanetData) -> Dictionary:
	if card == null:
		return {
			"success": false,
			"error": "NULL_CARD"
		}

	var card_id := card.instance_id.strip_edges()

	if card_id == "":
		card_id = "planet_%s" % str(Time.get_unix_time_from_system()).replace(".", "_")
		card.instance_id = card_id

	return await _put_backend("%s/%s" % [PLANET_CARDS_PATH, card_id.uri_encode()], {
		"card": card.to_firebase_dict()
	})


func add_planet_xp_optimistic(card: PlanetData, xp_to_add: int) -> Dictionary:
	if card == null:
		return {
			"success": false,
			"error": "NULL_CARD"
		}

	var card_id := card.instance_id.strip_edges()
	xp_to_add = max(xp_to_add, 0)

	if card_id == "":
		return {
			"success": false,
			"error": "EMPTY_CARD_ID"
		}

	if xp_to_add <= 0:
		return {
			"success": true,
			"status": "no_xp_added",
			"card": card.to_firebase_dict()
		}

	_apply_xp_locally(card, xp_to_add)
	planet_card_xp_updated.emit(card, xp_to_add)

	_sync_planet_xp_backend(card, card_id, xp_to_add)

	return {
		"success": true,
		"status": "optimistic_xp_added",
		"xp_added": xp_to_add,
		"card": card.to_firebase_dict()
	}


func _apply_xp_locally(card: PlanetData, xp_to_add: int) -> void:
	if card == null:
		return

	card.game_level = max(card.game_level, 1)
	card.game_xp = max(card.game_xp, 0)
	card.game_xp_to_next = max(card.game_xp_to_next, 10)

	card.game_xp += max(xp_to_add, 0)

	while card.game_xp >= card.game_xp_to_next:
		card.game_xp -= card.game_xp_to_next
		card.game_level += 1
		card.game_xp_to_next = max(10, int(round(float(card.game_xp_to_next) * 1.18)))


func _sync_planet_xp_backend(card: PlanetData, card_id: String, xp_to_add: int) -> void:
	var result := await _post_backend(
		UnilearnBackendService.ADD_PLANET_XP_PATH,
		{
			"cardId": card_id,
			"xp": xp_to_add
		}
	)

	if not bool(result.get("success", false)):
		push_warning("Failed to sync planet XP backend: %s" % str(result))
		return

	var card_dict: Dictionary = {}

	if result.get("card", {}) is Dictionary:
		card_dict = result.get("card", {})

	if card_dict.is_empty():
		return

	var updated_card := PlanetData.from_firebase_dict(card_dict)

	if updated_card == null:
		return

	card.game_level = updated_card.game_level
	card.game_xp = updated_card.game_xp
	card.game_xp_to_next = updated_card.game_xp_to_next

	planet_card_xp_updated.emit(card, 0)


func delete_planet_card(card_id: String) -> Dictionary:
	card_id = card_id.strip_edges()

	if card_id == "":
		return {
			"success": false,
			"error": "EMPTY_CARD_ID"
		}

	return await _delete_backend("%s/%s" % [PLANET_CARDS_PATH, card_id.uri_encode()])


func _post_backend(path: String, body: Dictionary, timeout_sec: float = DEFAULT_TIMEOUT_SEC) -> Dictionary:
	return await _request_backend(path, HTTPClient.METHOD_POST, body, timeout_sec)


func _get_backend(path: String, timeout_sec: float = DEFAULT_TIMEOUT_SEC) -> Dictionary:
	return await _request_backend(path, HTTPClient.METHOD_GET, {}, timeout_sec)


func _put_backend(path: String, body: Dictionary, timeout_sec: float = DEFAULT_TIMEOUT_SEC) -> Dictionary:
	return await _request_backend(path, HTTPClient.METHOD_PUT, body, timeout_sec)


func _delete_backend(path: String, timeout_sec: float = DEFAULT_TIMEOUT_SEC) -> Dictionary:
	return await _request_backend(path, HTTPClient.METHOD_DELETE, {}, timeout_sec)


func _request_backend(
	path: String,
	method: HTTPClient.Method,
	body: Dictionary = {},
	timeout_sec: float = DEFAULT_TIMEOUT_SEC
) -> Dictionary:
	return await _request_backend_internal(path, method, body, timeout_sec, false)


func _request_backend_internal(
	path: String,
	method: HTTPClient.Method,
	body: Dictionary = {},
	timeout_sec: float = DEFAULT_TIMEOUT_SEC,
	force_refresh_token: bool = false
) -> Dictionary:
	var token := await _get_fresh_id_token(force_refresh_token)

	if token.strip_edges() == "":
		return {
			"success": false,
			"error": "MISSING_ID_TOKEN"
		}

	var request := HTTPRequest.new()
	request.timeout = timeout_sec
	add_child(request)

	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]

	var final_url := UnilearnBackendService.url(path)
	var request_body := ""

	if method != HTTPClient.METHOD_GET and method != HTTPClient.METHOD_DELETE:
		request_body = JSON.stringify(body)

	var err := request.request(
		final_url,
		headers,
		method,
		request_body
	)

	if err != OK:
		request.queue_free()
		return {
			"success": false,
			"error": "REQUEST_FAILED",
			"code": err
		}

	var response: Array = await request.request_completed
	request.queue_free()

	var result_code: int = int(response[0])
	var response_code: int = int(response[1])
	var response_body: PackedByteArray = response[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"error": _http_request_result_to_error(result_code),
			"result_code": result_code,
			"status": response_code
		}

	var text := response_body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)

	if not (parsed is Dictionary):
		return {
			"success": false,
			"error": "INVALID_RESPONSE",
			"raw": text,
			"status": response_code
		}

	if response_code >= 200 and response_code < 300:
		return parsed

	var backend_error := str(parsed.get("error", "BACKEND_FAILED"))

	if (
		not force_refresh_token
		and response_code == 401
		and backend_error in ["INVALID_TOKEN", "TOKEN_EXPIRED", "ID_TOKEN_EXPIRED"]
	):
		return await _request_backend_internal(path, method, body, timeout_sec, true)

	return {
		"success": false,
		"error": backend_error,
		"message": str(parsed.get("message", "")),
		"status": response_code,
		"raw": parsed
	}


func _http_request_result_to_error(result_code: int) -> String:
	match result_code:
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			return "CHUNKED_BODY_SIZE_MISMATCH"
		HTTPRequest.RESULT_CANT_CONNECT:
			return "CANT_CONNECT"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "CANT_RESOLVE"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "CONNECTION_ERROR"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS_HANDSHAKE_ERROR"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "NO_RESPONSE"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "BODY_SIZE_LIMIT_EXCEEDED"
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
			return "BODY_DECOMPRESS_FAILED"
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "REQUEST_FAILED"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			return "DOWNLOAD_FILE_CANT_OPEN"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "DOWNLOAD_FILE_WRITE_ERROR"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "REDIRECT_LIMIT_REACHED"
		HTTPRequest.RESULT_TIMEOUT:
			return "REQUEST_TIMEOUT"
		_:
			return "HTTP_REQUEST_FAILED"


func _get_fresh_id_token(force_refresh: bool = false) -> String:
	if not is_instance_valid(FirebaseAuth):
		return ""

	if FirebaseAuth.has_method("get_fresh_id_token"):
		var token = await FirebaseAuth.get_fresh_id_token(force_refresh)
		return str(token)

	if FirebaseAuth.has_method("refresh_id_token"):
		if force_refresh:
			var refreshed_token = await FirebaseAuth.refresh_id_token()
			return str(refreshed_token)

		if _is_cached_token_missing_or_expiring_soon():
			var refreshed_expiring_token = await FirebaseAuth.refresh_id_token()
			return str(refreshed_expiring_token)

	if FirebaseAuth.has_method("get_id_token"):
		var existing_token = FirebaseAuth.get_id_token()
		return str(existing_token)

	if "id_token" in FirebaseAuth:
		return str(FirebaseAuth.id_token)

	return ""


func _is_cached_token_missing_or_expiring_soon() -> bool:
	if not is_instance_valid(FirebaseAuth):
		return true

	if not ("id_token" in FirebaseAuth):
		return true

	var token := str(FirebaseAuth.id_token).strip_edges()

	if token == "":
		return true

	if "id_token_expires_at" in FirebaseAuth:
		var expires_at := float(FirebaseAuth.id_token_expires_at)
		var now := Time.get_unix_time_from_system()

		return expires_at <= now + 120.0

	if "token_expires_at" in FirebaseAuth:
		var token_expires_at := float(FirebaseAuth.token_expires_at)
		var current_time := Time.get_unix_time_from_system()

		return token_expires_at <= current_time + 120.0

	return false

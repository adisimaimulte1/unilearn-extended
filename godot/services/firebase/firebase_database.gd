extends Node

signal planet_card_xp_updated(card: PlanetData, xp_added: int)

const BACKEND_BASE_URL := UnilearnBackendService.BASE_URL

const USER_INIT_PATH := UnilearnBackendService.USER_INIT_PATH
const PLANET_CARDS_PATH := UnilearnBackendService.PLANET_CARDS_PATH
const GENERATE_PLANET_CARD_PATH := UnilearnBackendService.GENERATE_PLANET_CARD_PATH

const DEFAULT_TIMEOUT_SEC := UnilearnBackendService.DEFAULT_REQUEST_TIMEOUT_SEC
const PLANET_GENERATION_TIMEOUT_SEC := UnilearnBackendService.PLANET_GENERATION_TIMEOUT_SEC

const MAX_PLANET_QUERY_LENGTH := 120


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
		"defaultCards": default_cards
	})


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

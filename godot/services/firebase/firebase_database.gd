extends Node

const BACKEND_BASE_URL := "https://optima-livekit-token-server.onrender.com"


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

	return await _post_backend("/unilearn/users/init", {
		"defaultCards": default_cards
	})


func get_planet_cards() -> Dictionary:
	return await _get_backend("/unilearn/users/planetCards")


func generate_planet_card(query: String) -> Dictionary:
	query = query.strip_edges()

	if query == "":
		return {
			"success": false,
			"error": "EMPTY_QUERY"
		}

	return await _post_backend("/unilearn/users/planetCards/generate", {
		"query": query
	})


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

	return await _put_backend("/unilearn/users/planetCards/%s" % card_id.uri_encode(), {
		"card": card.to_firebase_dict()
	})


func delete_planet_card(card_id: String) -> Dictionary:
	card_id = card_id.strip_edges()

	if card_id == "":
		return {
			"success": false,
			"error": "EMPTY_CARD_ID"
		}

	return await _delete_backend("/unilearn/users/planetCards/%s" % card_id.uri_encode())


func _post_backend(path: String, body: Dictionary) -> Dictionary:
	return await _request_backend(path, HTTPClient.METHOD_POST, body)


func _get_backend(path: String) -> Dictionary:
	return await _request_backend(path, HTTPClient.METHOD_GET, {})


func _put_backend(path: String, body: Dictionary) -> Dictionary:
	return await _request_backend(path, HTTPClient.METHOD_PUT, body)


func _delete_backend(path: String) -> Dictionary:
	return await _request_backend(path, HTTPClient.METHOD_DELETE, {})


func _request_backend(path: String, method: HTTPClient.Method, body: Dictionary = {}) -> Dictionary:
	return await _request_backend_internal(path, method, body, false)


func _request_backend_internal(
	path: String,
	method: HTTPClient.Method,
	body: Dictionary = {},
	force_refresh_token: bool = false
) -> Dictionary:
	var token := await _get_fresh_id_token(force_refresh_token)

	if token.strip_edges() == "":
		return {
			"success": false,
			"error": "MISSING_ID_TOKEN"
		}

	var request := HTTPRequest.new()
	add_child(request)

	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]

	var url := BACKEND_BASE_URL + path
	var request_body := ""

	if method != HTTPClient.METHOD_GET and method != HTTPClient.METHOD_DELETE:
		request_body = JSON.stringify(body)

	var err := request.request(
		url,
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

	var response = await request.request_completed
	request.queue_free()

	var response_code: int = response[1]
	var response_body: PackedByteArray = response[3]
	var text := response_body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)

	if parsed == null:
		return {
			"success": false,
			"error": "INVALID_RESPONSE",
			"raw": text,
			"status": response_code
		}

	if response_code >= 200 and response_code < 300:
		return parsed

	var backend_error := str(parsed.get("error", "BACKEND_FAILED"))

	if not force_refresh_token and response_code == 401 and backend_error in ["INVALID_TOKEN", "TOKEN_EXPIRED", "ID_TOKEN_EXPIRED"]:
		return await _request_backend_internal(path, method, body, true)

	return {
		"success": false,
		"error": backend_error,
		"message": str(parsed.get("message", "")),
		"status": response_code,
		"raw": parsed
	}


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

extends Node

const API_KEY := "AIzaSyCPndaWMATh7HNFuXIYmSBx14fzSMs4X-U"

const SIGN_UP_URL := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key="
const SIGN_IN_URL := "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key="
const RESET_URL := "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key="
const GOOGLE_SIGN_IN_URL := "https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key="
const REFRESH_TOKEN_URL := "https://securetoken.googleapis.com/v1/token?key="

const AUTH_FILE_PATH := "user://auth.cfg"
const AUTH_SECTION := "auth"

const TOKEN_REFRESH_MARGIN_SECONDS := 120.0

var id_token := ""
var refresh_token := ""
var uid := ""
var email := ""
var id_token_expires_at := 0.0

var _refresh_in_progress := false


func create_account(user_email: String, password: String) -> Dictionary:
	return await _post_auth(SIGN_UP_URL + API_KEY, {
		"email": user_email,
		"password": password,
		"returnSecureToken": true
	})


func login(user_email: String, password: String) -> Dictionary:
	return await _post_auth(SIGN_IN_URL + API_KEY, {
		"email": user_email,
		"password": password,
		"returnSecureToken": true
	})

func login_with_google_id_token(google_id_token: String) -> Dictionary:
	return await _post_auth(GOOGLE_SIGN_IN_URL + API_KEY, {
		"postBody": "id_token=%s&providerId=google.com" % google_id_token,
		"requestUri": "http://localhost",
		"returnIdpCredential": true,
		"returnSecureToken": true
	})


func send_password_reset(user_email: String) -> Dictionary:
	return await _post_raw(RESET_URL + API_KEY, {
		"requestType": "PASSWORD_RESET",
		"email": user_email
	})


func get_id_token() -> String:
	return id_token

func get_fresh_id_token(force_refresh: bool = false) -> String:
	if id_token.strip_edges() == "" and refresh_token.strip_edges() == "":
		return ""

	if force_refresh or _is_token_missing_or_expiring_soon():
		var refreshed := await refresh_id_token()

		if not refreshed.success:
			return ""

	return id_token

func refresh_id_token() -> Dictionary:
	if refresh_token.strip_edges() == "":
		return {
			"success": false,
			"error": "MISSING_REFRESH_TOKEN"
		}

	if _refresh_in_progress:
		while _refresh_in_progress:
			await get_tree().process_frame

		if id_token.strip_edges() != "":
			return {
				"success": true,
				"data": {
					"id_token": id_token,
					"refresh_token": refresh_token,
					"local_id": uid,
					"email": email,
					"expires_at": id_token_expires_at
				}
			}

		return {
			"success": false,
			"error": "REFRESH_FAILED"
		}

	_refresh_in_progress = true

	var result := await _post_refresh_token()

	_refresh_in_progress = false

	return result


func load_session() -> bool:
	var save := ConfigFile.new()

	if save.load(AUTH_FILE_PATH) != OK:
		return false

	id_token = str(save.get_value(AUTH_SECTION, "id_token", ""))
	refresh_token = str(save.get_value(AUTH_SECTION, "refresh_token", ""))
	uid = str(save.get_value(AUTH_SECTION, "uid", ""))
	email = str(save.get_value(AUTH_SECTION, "email", ""))
	id_token_expires_at = float(save.get_value(AUTH_SECTION, "id_token_expires_at", 0.0))

	return id_token.strip_edges() != "" and uid.strip_edges() != ""

func logout() -> void:
	id_token = ""
	refresh_token = ""
	uid = ""
	email = ""
	id_token_expires_at = 0.0
	_refresh_in_progress = false

	var dir := DirAccess.open("user://")

	if dir and dir.file_exists("auth.cfg"):
		dir.remove("auth.cfg")

func _is_token_missing_or_expiring_soon() -> bool:
	if id_token.strip_edges() == "":
		return true

	if id_token_expires_at <= 0.0:
		return true

	var now := Time.get_unix_time_from_system()
	return now >= id_token_expires_at - TOKEN_REFRESH_MARGIN_SECONDS


func _post_auth(url: String, body: Dictionary) -> Dictionary:
	var result := await _post_raw(url, body)

	if result.success:
		_save_auth_from_identity_toolkit(result.data)

	return result

func _post_refresh_token() -> Dictionary:
	var request := HTTPRequest.new()
	add_child(request)

	var headers := [
		"Content-Type: application/x-www-form-urlencoded"
	]

	var body := "grant_type=refresh_token&refresh_token=%s" % refresh_token.uri_encode()

	var err := request.request(
		REFRESH_TOKEN_URL + API_KEY,
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if err != OK:
		request.queue_free()
		return {
			"success": false,
			"error": "REFRESH_REQUEST_FAILED",
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
			"error": "INVALID_REFRESH_RESPONSE",
			"raw": text,
			"status": response_code
		}

	if response_code >= 200 and response_code < 300:
		_save_auth_from_refresh(parsed)

		return {
			"success": true,
			"data": parsed
		}

	var error_code := _extract_error_code(parsed)

	if error_code in ["TOKEN_EXPIRED", "USER_DISABLED", "USER_NOT_FOUND", "INVALID_REFRESH_TOKEN"]:
		logout()

	return {
		"success": false,
		"error": error_code,
		"status": response_code,
		"raw": parsed
	}

func _post_raw(url: String, body: Dictionary) -> Dictionary:
	var request := HTTPRequest.new()
	add_child(request)

	var headers := ["Content-Type: application/json"]
	var err := request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

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
		return {
			"success": true,
			"data": parsed
		}

	return {
		"success": false,
		"error": _extract_error_code(parsed),
		"status": response_code,
		"raw": parsed
	}


func _save_auth_from_identity_toolkit(data: Dictionary) -> void:
	id_token = str(data.get("idToken", ""))
	refresh_token = str(data.get("refreshToken", ""))
	uid = str(data.get("localId", ""))
	email = str(data.get("email", ""))

	var expires_in := float(str(data.get("expiresIn", "3600")))
	id_token_expires_at = Time.get_unix_time_from_system() + expires_in

	_save_session()

func _save_auth_from_refresh(data: Dictionary) -> void:
	id_token = str(data.get("id_token", id_token))
	refresh_token = str(data.get("refresh_token", refresh_token))
	uid = str(data.get("user_id", uid))

	var expires_in := float(str(data.get("expires_in", "3600")))
	id_token_expires_at = Time.get_unix_time_from_system() + expires_in

	_save_session()

func _save_session() -> void:
	var save := ConfigFile.new()

	save.set_value(AUTH_SECTION, "id_token", id_token)
	save.set_value(AUTH_SECTION, "refresh_token", refresh_token)
	save.set_value(AUTH_SECTION, "uid", uid)
	save.set_value(AUTH_SECTION, "email", email)
	save.set_value(AUTH_SECTION, "id_token_expires_at", id_token_expires_at)

	save.save(AUTH_FILE_PATH)


func _extract_error_code(parsed: Dictionary) -> String:
	if parsed.has("error"):
		var error = parsed["error"]

		if error is Dictionary and error.has("message"):
			return str(error["message"])

		if error is String:
			return str(error)

	return "AUTH_FAILED"

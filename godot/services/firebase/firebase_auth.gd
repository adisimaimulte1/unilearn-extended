extends Node

const API_KEY := "AIzaSyCPndaWMATh7HNFuXIYmSBx14fzSMs4X-U"

const SIGN_UP_URL := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key="
const SIGN_IN_URL := "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key="
const RESET_URL := "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key="
const GOOGLE_SIGN_IN_URL := "https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key="

const AUTH_FILE_PATH := "user://auth.cfg"
const AUTH_SECTION := "auth"

var id_token := ""
var refresh_token := ""
var uid := ""
var email := ""


func create_account(user_email: String, password: String) -> Dictionary:
	return await _post(SIGN_UP_URL + API_KEY, {
		"email": user_email,
		"password": password,
		"returnSecureToken": true
	})


func login(user_email: String, password: String) -> Dictionary:
	return await _post(SIGN_IN_URL + API_KEY, {
		"email": user_email,
		"password": password,
		"returnSecureToken": true
	})

func login_with_google_id_token(google_id_token: String) -> Dictionary:
	return await _post(GOOGLE_SIGN_IN_URL + API_KEY, {
		"postBody": "id_token=%s&providerId=google.com" % google_id_token,
		"requestUri": "http://localhost",
		"returnIdpCredential": true,
		"returnSecureToken": true
	})


func send_password_reset(user_email: String) -> Dictionary:
	return await _post(RESET_URL + API_KEY, {
		"requestType": "PASSWORD_RESET",
		"email": user_email
	})


func load_session() -> bool:
	var save := ConfigFile.new()

	if save.load(AUTH_FILE_PATH) != OK:
		return false

	id_token = str(save.get_value(AUTH_SECTION, "id_token", ""))
	refresh_token = str(save.get_value(AUTH_SECTION, "refresh_token", ""))
	uid = str(save.get_value(AUTH_SECTION, "uid", ""))
	email = str(save.get_value(AUTH_SECTION, "email", ""))

	return id_token != "" and uid != ""


func logout() -> void:
	id_token = ""
	refresh_token = ""
	uid = ""
	email = ""

	var dir := DirAccess.open("user://")

	if dir and dir.file_exists("auth.cfg"):
		dir.remove("auth.cfg")


func _post(url: String, body: Dictionary) -> Dictionary:
	var request := HTTPRequest.new()
	add_child(request)

	var headers := ["Content-Type: application/json"]
	var err := request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

	if err != OK:
		request.queue_free()
		return {
			"success": false,
			"error": "REQUEST_FAILED"
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
			"error": "INVALID_RESPONSE"
		}

	if response_code >= 200 and response_code < 300:
		_save_auth(parsed)
		return {
			"success": true,
			"data": parsed
		}

	return {
		"success": false,
		"error": _extract_error_code(parsed)
	}


func _save_auth(data: Dictionary) -> void:
	id_token = str(data.get("idToken", ""))
	refresh_token = str(data.get("refreshToken", ""))
	uid = str(data.get("localId", ""))
	email = str(data.get("email", ""))

	var save := ConfigFile.new()
	save.set_value(AUTH_SECTION, "id_token", id_token)
	save.set_value(AUTH_SECTION, "refresh_token", refresh_token)
	save.set_value(AUTH_SECTION, "uid", uid)
	save.set_value(AUTH_SECTION, "email", email)
	save.save(AUTH_FILE_PATH)


func _extract_error_code(parsed: Dictionary) -> String:
	if parsed.has("error") and parsed["error"].has("message"):
		return str(parsed["error"]["message"])

	return "AUTH_FAILED"

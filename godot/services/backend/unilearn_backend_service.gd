extends Node
class_name UnilearnBackendService

const BASE_URL := "https://optima-livekit-token-server.onrender.com"

const APOLLO_CHAT_PATH := "/apollo-chat"
const USER_INIT_PATH := "/unilearn/users/init"
const PLANET_CARDS_PATH := "/unilearn/users/planetCards"
const GENERATE_PLANET_CARD_PATH := "/unilearn/users/planetCards/generate"

const APOLLO_CHAT_URL := BASE_URL + APOLLO_CHAT_PATH
const USER_INIT_URL := BASE_URL + USER_INIT_PATH
const PLANET_CARDS_URL := BASE_URL + PLANET_CARDS_PATH
const GENERATE_PLANET_CARD_URL := BASE_URL + GENERATE_PLANET_CARD_PATH

const DEFAULT_REQUEST_TIMEOUT_SEC := 65.0
const PLANET_GENERATION_TIMEOUT_SEC := 95.0


static func url(path: String) -> String:
	path = path.strip_edges()

	if path.begins_with("http://") or path.begins_with("https://"):
		return path

	if not path.begins_with("/"):
		path = "/" + path

	return BASE_URL + path

extends Node
class_name UnilearnBackendService

const BASE_URL := "https://optima-livekit-token-server.onrender.com"

const APOLLO_CHAT_PATH := "/apollo-chat"
const APOLLO_QUIZ_PATH := "/apollo-quiz"

const USER_INIT_PATH := "/unilearn/users/init"
const USER_PROFILE_PATH := "/unilearn/users/profile"
const NEARBY_MULTIPLAYER_PLAYERS_PATH := "/unilearn/users/nearbyPlayers"
const NEARBY_MULTIPLAYER_SYNC_REPORT_PATH := "/unilearn/users/nearbySync/report"
const NEARBY_MULTIPLAYER_SYNC_LEAVE_PATH := "/unilearn/users/nearbySync/leave"
const NEARBY_MULTIPLAYER_SYNC_LEAVE_ALL_PATH := "/unilearn/users/nearbySync/leaveAll"
const MULTIPLAYER_REQUEST_SEND_PATH := "/unilearn/users/multiplayerRequests/send"
const MULTIPLAYER_REQUEST_POLL_PATH := "/unilearn/users/multiplayerRequests/poll"
const MULTIPLAYER_REQUEST_RESPOND_PATH := "/unilearn/users/multiplayerRequests/respond"
const MULTIPLAYER_REQUEST_CANCEL_ACTIVE_PATH := "/unilearn/users/multiplayerRequests/cancelActive"
const MULTIPLAYER_SYNC_CLOSE_PATH := "/unilearn/users/multiplayerRequests/closeSync"
const MULTIPLAYER_SYNC_EVENT_PATH := "/unilearn/users/multiplayerRequests/sync/event"
const MULTIPLAYER_TRADE_SELECT_PATH := "/unilearn/users/multiplayerRequests/trade/select"
const MULTIPLAYER_HOME_READY_PATH := "/unilearn/users/multiplayerRequests/homeReady"
const MULTIPLAYER_TRADE_UI_READY_PATH := "/unilearn/users/multiplayerRequests/trade/uiReady"
const MULTIPLAYER_TRADE_CANCEL_PATH := "/unilearn/users/multiplayerRequests/trade/cancel"
const PLANET_CARDS_PATH := "/unilearn/users/planetCards"
const GENERATE_PLANET_CARD_PATH := "/unilearn/users/planetCards/generate"
const ADD_PLANET_XP_PATH := "/unilearn/users/planetCards/xp"
const ACHIEVEMENTS_PATH := "/unilearn/users/achievements"
const UNLOCK_ACHIEVEMENT_PATH := "/unilearn/users/achievements/unlock"
const SYNC_ACHIEVEMENTS_PATH := "/unilearn/users/achievements/sync"

const APOLLO_CHAT_URL := BASE_URL + APOLLO_CHAT_PATH
const APOLLO_QUIZ_URL := BASE_URL + APOLLO_QUIZ_PATH

const USER_INIT_URL := BASE_URL + USER_INIT_PATH
const USER_PROFILE_URL := BASE_URL + USER_PROFILE_PATH
const NEARBY_MULTIPLAYER_PLAYERS_URL := BASE_URL + NEARBY_MULTIPLAYER_PLAYERS_PATH
const NEARBY_MULTIPLAYER_SYNC_REPORT_URL := BASE_URL + NEARBY_MULTIPLAYER_SYNC_REPORT_PATH
const NEARBY_MULTIPLAYER_SYNC_LEAVE_URL := BASE_URL + NEARBY_MULTIPLAYER_SYNC_LEAVE_PATH
const NEARBY_MULTIPLAYER_SYNC_LEAVE_ALL_URL := BASE_URL + NEARBY_MULTIPLAYER_SYNC_LEAVE_ALL_PATH
const PLANET_CARDS_URL := BASE_URL + PLANET_CARDS_PATH
const GENERATE_PLANET_CARD_URL := BASE_URL + GENERATE_PLANET_CARD_PATH
const ADD_PLANET_XP_URL := BASE_URL + ADD_PLANET_XP_PATH
const ACHIEVEMENTS_URL := BASE_URL + ACHIEVEMENTS_PATH
const UNLOCK_ACHIEVEMENT_URL := BASE_URL + UNLOCK_ACHIEVEMENT_PATH
const SYNC_ACHIEVEMENTS_URL := BASE_URL + SYNC_ACHIEVEMENTS_PATH

const DEFAULT_REQUEST_TIMEOUT_SEC := 65.0
const PLANET_GENERATION_TIMEOUT_SEC := 95.0
const QUIZ_GENERATION_TIMEOUT_SEC := 75.0

static func url(path: String) -> String:
	path = path.strip_edges()
	if path.begins_with("http://") or path.begins_with("https://"):
		return path
	if not path.begins_with("/"):
		path = "/" + path
	return BASE_URL + path

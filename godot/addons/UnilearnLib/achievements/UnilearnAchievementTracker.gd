extends Node

signal achievements_loaded
signal achievements_changed(results: Array)
signal achievement_unlocked(achievement: Dictionary)
signal achievement_progress_changed(achievement_id: String, progress: float)

const CATALOG := preload("res://addons/UnilearnLib/achievements/UnilearnAchievementCatalog.gd")

const BACKEND_BASE_URL := "https://optima-livekit-token-server.onrender.com"
const ACHIEVEMENTS_PATH := "/unilearn/users/achievements"
const UNLOCK_ACHIEVEMENT_PATH := "/unilearn/users/achievements/unlock"
const SYNC_ACHIEVEMENTS_PATH := "/unilearn/users/achievements/sync"
const PROGRESS_ACHIEVEMENTS_PATH := "/unilearn/users/achievements/progress"
const DEFAULT_REQUEST_TIMEOUT_SEC := 65.0

const TIER_NONE := 0
const TIER_BRONZE := 1
const TIER_SILVER := 2
const TIER_GOLD := 3

const RARE_ACHIEVEMENTS := {
	"diamonds": true,
	"the_pull_of_the_universe": true,
	"unknown_moon": true,
	"extremes_belong_together": true,
	"how_did_we_get_here": true,
	"e_mc2": true,
	"a_girl_s_fight": true,
	"unlocking_supernova": true,
	"all_inclusive": true,
	"white_magic": true,
	"cosmic_eraser": true,
	"the_end_of_the_universe": true,
	"better_than_home": true,
	"crowded_neighborhood": true,
	"omega_protocol": true,
	"triple_trouble_but_stable": true,
	"cosmic_clockwork": true,
	"eternal_system": true,
	"rogue_one": true,
	"this_feels_more_like_reality": true,
	"game_s_broken_now": true,
	"failed_star_club": true,
	"strange_new_worlds": true,
	"the_archivist": true,
}

const STAGED_ACHIEVEMENTS := {
	"a_fresh_start": {"event": "body_added_unique_count", "thresholds": [1, 30, 70], "label": "different bodies"},
	"life_beyond_earth": {"event": "life_beyond_earth_ids", "thresholds": [1, 5, 10], "label": "high-habitability exoplanets"},
	"the_chosen_one": {"event": "chosen_one_level", "thresholds": [1, 5, 10], "label": "card level"},
	"give_me_that_ring": {"event": "ringed_exoplanet_ids", "thresholds": [1, 3, 5], "label": "ringed exoplanets"},
	"gas_titan": {"event": "gas_titan_ids", "thresholds": [1, 3, 5], "label": "giant exoplanets"},
	"toxic_traits": {"event": "toxic_traits_ids", "thresholds": [1, 3, 5], "label": "toxic exoplanets"},
	"star_of_the_show": {"event": "outside_star_ids", "thresholds": [1, 5, 10], "label": "outside stars"},
	"diamonds": {"event": "diamonds_level", "thresholds": [1, 5, 10], "label": "card level"},
	"the_pull_of_the_universe": {"event": "pull_level", "thresholds": [1, 5, 10], "label": "card level"},
	"unknown_moon": {"event": "unknown_moon_level", "thresholds": [1, 5, 10], "label": "card level"},
	"big_bang": {"event": "planet_collision", "thresholds": [1, 30, 70], "label": "collisions"},
	"not_quite_a_planet": {"event": "moon_to_planet_count", "thresholds": [1, 10, 30], "label": "planet-sized moon merges"},
	"this_was_not_supposed_to_happen": {"event": "all_moons_into_planet", "thresholds": [1, 5, 10], "label": "moon-system collisions"},
	"magneto_s_helmet_origins": {"event": "magnetic_pairs", "thresholds": [1, 10, 30], "label": "magnetic planet pairs"},
	"breath_taking": {"event": "low_atmosphere_pairs", "thresholds": [1, 10, 30], "label": "low-atmosphere pairs"},
	"so_close": {"event": "planet_to_brown_dwarf", "thresholds": [1, 10, 30], "label": "brown dwarfs"},
	"no_hope_for_humanity": {"event": "earth_collisions", "thresholds": [21, 42, 84], "label": "Earth collisions"},
	"extremes_belong_together": {"event": "ice_lava_level", "thresholds": [1, 5, 10], "label": "planet level"},
	"how_did_we_get_here": {"event": "solar_planet_lineage_level", "thresholds": [1, 5, 10], "label": "solar planet level"},
	"e_mc2": {"event": "emcc_lineage_level", "thresholds": [1, 5, 10], "label": "planet level"},
	"needle_in_a_haystack": {"event": "moon_star_collisions", "thresholds": [1, 10, 25], "label": "moons into stars"},
	"death_star": {"event": "death_star_ids", "thresholds": [1, 5, 10], "label": "habitable exoplanets into stars"},
	"planet_thief": {"event": "planet_thief_count", "thresholds": [1, 10, 30], "label": "stolen planets"},
	"binary_breakup": {"event": "binary_breakup_count", "thresholds": [1, 5, 15], "label": "similar star pairs"},
	"triple_trouble": {"event": "rapid_star_collision_count", "thresholds": [3, 4, 5], "label": "rapid star collisions"},
	"start_end": {"event": "start_end_count", "thresholds": [1, 5, 15], "label": "white/brown dwarf pairs"},
	"life_s_not_fair": {"event": "life_not_fair_count", "thresholds": [1, 5, 10], "label": "small-big star collisions"},
	"a_girl_s_fight": {"event": "brown_dwarf_pair_level", "thresholds": [1, 5, 10], "label": "brown dwarf level"},
	"unlocking_supernova": {"event": "red_giant_pair_level", "thresholds": [1, 5, 10], "label": "red giant level"},
	"all_inclusive": {"event": "star_colors_level", "thresholds": [1, 5, 10], "label": "star level"},
	"black_magic": {"event": "black_holes_unlocked", "thresholds": [1, 5, 10], "label": "black holes"},
	"the_dark_side_of_the_moon": {"event": "black_hole_moons", "thresholds": [1, 10, 30], "label": "moons swallowed"},
	"the_formation_of_a_galaxy": {"event": "stars_orbiting_black_hole", "thresholds": [1, 5, 10], "label": "stars orbiting"},
	"forbidden_orbit": {"event": "moons_orbiting_black_hole", "thresholds": [1, 5, 10], "label": "moons orbiting"},
	"lights_out": {"event": "blue_stars_swallowed", "thresholds": [1, 5, 10], "label": "blue stars swallowed"},
	"star_soup": {"event": "black_hole_rapid_star_swallow", "thresholds": [1, 2, 3], "label": "rapid stars swallowed"},
	"gravity_bender": {"event": "supermassive_black_holes", "thresholds": [1, 5, 10], "label": "supermassive black holes"},
	"white_magic": {"event": "white_hole_level", "thresholds": [1, 5, 10], "label": "white hole level"},
	"cosmic_eraser": {"event": "cosmic_eraser_level", "thresholds": [1, 5, 10], "label": "system level"},
	"the_end_of_the_universe": {"event": "black_white_level", "thresholds": [1, 5, 10], "label": "singularity level"},
	"we_ain_t_going_there": {"event": "bad_score_level", "thresholds": [1, 2, 3], "label": "bad score"},
	"radiation_proof": {"event": "radiation_planets", "thresholds": [1, 5, 8], "label": "planets"},
	"rock_solid": {"event": "rock_solid_score", "thresholds": [1, 75, 85], "label": "score"},
	"i_ve_won_but_at_what_cost": {"event": "stat_cost_level", "thresholds": [1, 2, 3], "label": "stat extremity"},
	"moon_economy": {"event": "moon_economy_score", "thresholds": [75, 80, 85], "label": "score"},
	"one_star_review": {"event": "one_star_review_level", "thresholds": [1, 5, 10], "label": "planet level"},
	"overengineered": {"event": "overengineered_score", "thresholds": [85, 90, 95], "label": "score"},
	"better_than_home": {"event": "better_than_home_level", "thresholds": [1, 5, 10], "label": "planet level"},
	"crowded_neighborhood": {"event": "crowded_level", "thresholds": [1, 5, 10], "label": "planet level"},
	"omega_protocol": {"event": "omega_level", "thresholds": [1, 5, 10], "label": "planet level"},
	"first_orbit": {"event": "first_orbit_timer", "thresholds": [20, 45, 90], "label": "seconds"},
	"moon_guardian": {"event": "moon_guardian_timer", "thresholds": [30, 60, 120], "label": "seconds"},
	"solar_starter": {"event": "solar_starter_timer", "thresholds": [30, 45, 60], "label": "seconds"},
	"binary_ballet": {"event": "binary_ballet_timer", "thresholds": [30, 60, 120], "label": "seconds"},
	"family_system": {"event": "family_system_timer", "thresholds": [30, 45, 60], "label": "seconds"},
	"no_crash_zone": {"event": "no_crash_zone_timer", "thresholds": [60, 90, 120], "label": "seconds"},
	"perfect_spacing": {"event": "perfect_spacing_timer", "thresholds": [45, 60, 90], "label": "seconds"},
	"triple_trouble_but_stable": {"event": "triple_stable_timer", "thresholds": [30, 45, 60], "label": "seconds"},
	"cosmic_clockwork": {"event": "clockwork_timer", "thresholds": [60, 90, 120], "label": "seconds"},
	"eternal_system": {"event": "eternal_timer", "thresholds": [180, 180, 180], "label": "seconds"},
	"moon_master": {"event": "moon_master_count", "thresholds": [5, 10, 20], "label": "moons"},
	"frozen_wasteland": {"event": "frozen_wasteland_count", "thresholds": [8, 12, 16], "label": "planets"},
	"ra_s_empire": {"event": "ra_empire_count", "thresholds": [4, 7, 10], "label": "stars"},
	"on_the_edge_of_extinction": {"event": "extinction_count", "thresholds": [8, 12, 16], "label": "planets"},
	"center_of_the_universe": {"event": "earth_orbit_count", "thresholds": [5, 8, 10], "label": "planets"},
	"dual_what": {"event": "dual_what_count", "thresholds": [8, 12, 15], "label": "planets"},
	"whoops_wrong_button": {"event": "whoops_count", "thresholds": [5, 8, 10], "label": "planets"},
	"rogue_one": {"event": "rogue_one_level", "thresholds": [1, 5, 10], "label": "planet level"},
	"this_feels_more_like_reality": {"event": "reality_level", "thresholds": [1, 5, 10], "label": "planet level"},
	"game_s_broken_now": {"event": "broken_level", "thresholds": [1, 5, 10], "label": "planet level"},
	"planet_collector": {"event": "generated_cards", "thresholds": [1, 30, 70], "label": "generated cards"},
	"lvl_up": {"event": "card_level", "thresholds": [2, 5, 10], "label": "card level"},
	"moon_factory": {"event": "moon_cards", "thresholds": [10, 25, 50], "label": "moon cards"},
	"ice_age": {"event": "ice_cards", "thresholds": [5, 15, 30], "label": "ice worlds"},
	"gas_dealer": {"event": "gas_cards", "thresholds": [5, 15, 30], "label": "gas giants"},
	"terra_hunter": {"event": "habitable_cards", "thresholds": [5, 15, 30], "label": "habitable worlds"},
	"it_s_not_real": {"event": "fictional_cards", "thresholds": [1, 10, 25], "label": "fictional cards"},
	"failed_star_club": {"event": "brown_dwarf_cards", "thresholds": [3, 10, 25], "label": "brown dwarfs"},
	"strange_new_worlds": {"event": "planet_presets", "thresholds": [1, 3, 5], "label": "cards per preset"},
	"the_archivist": {"event": "generated_cards", "thresholds": [30, 70, 100], "label": "generated cards"},
}


const CATEGORY_ORDER := [
	"add_body",
	"planet_collision",
	"sun_collision",
	"black_hole",
	"stat_mastery",
	"stability",
	"instability",
	"type_amount"
]

const CATEGORY_LABELS := {
	"add_body": "Added Bodies",
	"planet_collision": "Planet Collisions",
	"sun_collision": "Star Collisions",
	"black_hole": "Black Holes",
	"stat_mastery": "Stat Mastery",
	"stability": "Stable Systems",
	"instability": "Unstable Systems",
	"type_amount": "Cards"
}

const CATEGORY_MAP := {
	"ADDED BODIES": "add_body",
	"PLANET COLLISIONS": "planet_collision",
	"STAR COLLISIONS": "sun_collision",
	"BLACK HOLES": "black_hole",
	"STAT MASTERY": "stat_mastery",
	"STABLE SYSTEMS": "stability",
	"UNSTABLE SYSTEMS": "instability",
	"CARDS": "type_amount"
}

const CATEGORY_SOURCE_LABELS := {
	"add_body": "ADDED BODIES",
	"planet_collision": "PLANET COLLISIONS",
	"sun_collision": "STAR COLLISIONS",
	"black_hole": "BLACK HOLES",
	"stat_mastery": "STAT MASTERY",
	"stability": "STABLE SYSTEMS",
	"instability": "UNSTABLE SYSTEMS",
	"type_amount": "CARDS"
}

const SOLAR_SYSTEM_NAMES := [
	"sun", "mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune",
	"moon", "io", "europa", "ganymede", "callisto", "titan", "enceladus", "triton", "charon", "pluto"
]

const PLANET_PRESET_TARGET := 14

var unlocked_ids: Dictionary = {}
var unlocked_payloads: Dictionary = {}
var shown_unlock_toasts: Dictionary = {}
var progress: Dictionary = {}
var timers: Dictionary = {}
var local_events: Dictionary = {
	"body_added": 0,
	"planet_collision": 0,
	"star_collision": 0,
	"black_hole_swallowed_moons": 0,
	"black_hole_swallowed_stars_window": 0,
	"earth_collisions": 0,
	"star_collision_window": 0
}

var backend_sync_enabled: bool = true
var _last_results: Array = []
var _last_signature := ""
var _is_loading := false
var _cards_cache: Array = []
var _active_generation_ids: Dictionary = {}
var _active_generation_count: int = 0
var _runtime_snapshot_accum: float = 0.0
var _last_runtime_snapshot_signature: String = ""
const RUNTIME_SNAPSHOT_INTERVAL := 0.85
const AUTH_ACCOUNT_POLL_INTERVAL := 0.65

var _current_account_key: String = ""
var _auth_poll_accum: float = 0.0
var _login_backend_reload_running: bool = false
var _backend_save_queued: bool = false
var _backend_save_running: bool = false


func _safe_int(value: Variant, fallback: int = 0) -> int:
	if value == null:
		return fallback
	if value is int:
		return value
	if value is bool:
		return 1 if value else 0
	if value is float:
		return roundi(value)
	if value is String or value is StringName:
		var text := str(value).strip_edges()
		if text.is_empty():
			return fallback
		if text.is_valid_int():
			return text.to_int()
		if text.is_valid_float():
			return roundi(text.to_float())
		return fallback
	if value is Dictionary:
		return value.size()
	if value is Array:
		return value.size()
	return fallback


func _unlock_toast_key(id: String, tier: int) -> String:
	id = CATALOG.normalize_id(id)
	return "%s:%d" % [id, clampi(_safe_int(tier, TIER_BRONZE), TIER_BRONZE, TIER_GOLD)]


func _has_shown_unlock_toast(id: String, tier: int) -> bool:
	return shown_unlock_toasts.has(_unlock_toast_key(id, tier))


func _mark_unlock_toast_shown(id: String, tier: int) -> void:
	var key := _unlock_toast_key(id, tier)
	if key.is_empty():
		return
	shown_unlock_toasts[key] = true


func _mark_loaded_unlocks_as_seen() -> void:
	for id in unlocked_payloads.keys():
		var raw_payload: Variant = unlocked_payloads.get(str(id), {})
		var payload: Dictionary = raw_payload if raw_payload is Dictionary else {}
		var tier := _normalize_display_tier(str(id), _safe_int(payload.get("tier", _default_tier_for_id(str(id)))))
		if tier <= TIER_NONE:
			tier = TIER_BRONZE
		for stage_tier in range(TIER_BRONZE, tier + 1):
			_mark_unlock_toast_shown(str(id), stage_tier)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_current_account_key = _get_account_key()
	_load_local()
	_connect_sources()
	_connect_auth_sources()
	refresh(true)
	call_deferred("_load_backend_then_refresh")


func _process(delta: float) -> void:
	_auth_poll_accum += delta
	if _auth_poll_accum < AUTH_ACCOUNT_POLL_INTERVAL:
		return
	_auth_poll_accum = 0.0
	_check_account_changed()


func force_reload_from_backend_after_login() -> Dictionary:
	if _login_backend_reload_running:
		return {"success": false, "error": "ALREADY_SYNCING"}

	_login_backend_reload_running = true
	backend_sync_enabled = true
	_current_account_key = _get_account_key()
	_load_local()
	var result := await load_from_backend()
	_purge_invalid_unlocks()
	refresh(true)
	_login_backend_reload_running = false
	return result


func _check_account_changed() -> void:
	var next_key := _get_account_key()
	if next_key == _current_account_key:
		return

	_current_account_key = next_key
	call_deferred("_reload_for_current_account")


func _reload_for_current_account() -> void:
	await force_reload_from_backend_after_login()

func _load_backend_then_refresh() -> void:
	await load_from_backend()
	_purge_invalid_unlocks()
	refresh(true)

func _connect_sources() -> void:
	var cache := get_node_or_null("/root/PlanetCardsCache")
	if cache != null and cache.has_signal("cards_changed"):
		var callable := Callable(self, "_on_cards_changed")
		if not cache.is_connected("cards_changed", callable):
			cache.connect("cards_changed", callable)

	if cache != null and cache.has_signal("card_generation_started"):
		var started_callable := Callable(self, "_on_card_generation_started")
		if not cache.is_connected("card_generation_started", started_callable):
			cache.connect("card_generation_started", started_callable)

	if cache != null and cache.has_signal("card_generation_finished"):
		var generated_callable := Callable(self, "_on_card_generation_finished")
		if not cache.is_connected("card_generation_finished", generated_callable):
			cache.connect("card_generation_finished", generated_callable)

	if cache != null and cache.has_signal("card_generation_failed"):
		var failed_callable := Callable(self, "_on_card_generation_failed")
		if not cache.is_connected("card_generation_failed", failed_callable):
			cache.connect("card_generation_failed", failed_callable)

func _connect_auth_sources() -> void:
	var auth := get_node_or_null("/root/FirebaseAuth")
	if auth == null:
		return

	for signal_name in [
		"logged_in",
		"signed_in",
		"login_success",
		"auth_state_changed",
		"session_loaded",
		"token_refreshed",
		"user_changed"
	]:
		if auth.has_signal(signal_name):
			var callable := Callable(self, "_on_auth_session_changed")
			if not auth.is_connected(signal_name, callable):
				auth.connect(signal_name, callable)


func _on_auth_session_changed(_a = null, _b = null, _c = null, _d = null) -> void:
	_check_account_changed()
	if _get_account_key() == _current_account_key:
		call_deferred("_reload_for_current_account")


func _on_cards_changed(_a = null, _b = null, _c = null) -> void:
	_cards_cache = _get_cards()

func _on_card_generation_started(_query: String, predicted_id: String) -> void:
	var clean_id := str(predicted_id).strip_edges()
	if clean_id.is_empty():
		clean_id = "generation_%s" % str(Time.get_ticks_usec())
	_active_generation_ids[clean_id] = true
	_active_generation_count += 1

func _on_card_generation_finished(card: PlanetData) -> void:
	if _active_generation_count <= 0:
		return
	_active_generation_count = max(_active_generation_count - 1, 0)
	_active_generation_ids.clear()
	register_generated_card(card)

func _on_card_generation_failed(_query: String, predicted_id: String) -> void:
	var clean_id := str(predicted_id).strip_edges()
	if not clean_id.is_empty() and _active_generation_ids.has(clean_id):
		_active_generation_ids.erase(clean_id)
	_active_generation_count = max(_active_generation_count - 1, 0)


func register_generated_card(card: PlanetData) -> void:
	if card == null:
		return

	var card_id := str(_read(card, "instance_id", "")).strip_edges()
	if card_id.is_empty():
		card_id = str(_read(card, "name", "")).strip_edges().to_lower().replace(" ", "_")

	var generated_ids: Dictionary = local_events.get("generated_card_ids", {}) if local_events.get("generated_card_ids", {}) is Dictionary else {}
	if not card_id.is_empty():
		generated_ids[card_id] = true
	local_events["generated_card_ids"] = generated_ids
	_set_counter_value("planet_collector", generated_ids.size(), {"card_id": card_id}, "generated_card")
	_set_counter_value("the_archivist", generated_ids.size(), {"card_id": card_id}, "generated_card")
	if _is_black_hole(card):
		_increment_counter("black_magic", 1, {"card_id": card_id, "body": _name(card)}, "generated_card")
	if _is_white_hole(card):
		_set_level_stage("white_magic", _level(card), {"card_id": card_id, "body": _name(card)}, "generated_card")
	register_cards(_get_cards(), false)
	_save_local()
	refresh(true)

func refresh(force_emit: bool = false) -> Array:
	_purge_invalid_unlocks()
	var cards := _get_cards()
	var signature := _build_signature(cards)
	if signature == _last_signature and not force_emit:
		return _last_results

	_last_signature = signature
	_last_results = _build_results()
	achievements_changed.emit(_last_results)
	return _last_results

func get_results() -> Array:
	if _last_results.is_empty():
		return refresh(true)
	return _last_results

func get_visible_achievements() -> Array:
	return get_results()

func filter_results(query: String) -> Array:
	var q := query.strip_edges().to_lower()
	var results := get_results()
	if q.is_empty():
		return results

	var filtered: Array = []
	for result in results:
		var hidden := bool(result.get("hidden", false))
		var blob := ""
		if hidden:
			blob = "locked hidden %s %s" % [str(result.get("category", "")), str(result.get("category_label", ""))]
		else:
			blob = "%s %s %s %s" % [
				str(result.get("title", "")),
				str(result.get("description", "")),
				str(result.get("category", "")),
				str(result.get("category_label", ""))
			]
		if blob.to_lower().contains(q):
			filtered.append(result)
	return filtered

func get_summary() -> Dictionary:
	var results := get_results()
	var unlocked := 0
	var bronze := 0
	var silver := 0
	var gold := 0
	var points := 0
	for result in results:
		var tier := _safe_int(result.get("tier", 0))
		if tier > 0:
			unlocked += 1
			match tier:
				1:
					bronze += 1
				2:
					silver += 1
				3:
					gold += 1
			points += _safe_int(result.get("points", 0))
	return {
		"total": results.size(),
		"unlocked": unlocked,
		"bronze": bronze,
		"silver": silver,
		"gold": gold,
		"points": points
	}

func get_category_summaries(query: String = "") -> Array:
	var results := filter_results(query)
	var by_category := {}

	for category in CATEGORY_ORDER:
		by_category[category] = {
			"category": category,
			"label": CATEGORY_LABELS.get(category, category.capitalize()),
			"total": 0,
			"unlocked": 0,
			"bronze": 0,
			"silver": 0,
			"gold": 0,
			"points": 0
		}

	for result in results:
		var category := str(result.get("category", "type_amount"))
		if not by_category.has(category):
			by_category[category] = {
				"category": category,
				"label": str(result.get("category_label", category.capitalize())),
				"total": 0,
				"unlocked": 0,
				"bronze": 0,
				"silver": 0,
				"gold": 0,
				"points": 0
			}

		var summary: Dictionary = by_category[category]
		summary["total"] = _safe_int(summary.get("total", 0)) + 1
		if _safe_int(result.get("tier", 0)) > 0:
			summary["unlocked"] = _safe_int(summary.get("unlocked", 0)) + 1
			match _safe_int(result.get("tier", 0)):
				1:
					summary["bronze"] = _safe_int(summary.get("bronze", 0)) + 1
				2:
					summary["silver"] = _safe_int(summary.get("silver", 0)) + 1
				3:
					summary["gold"] = _safe_int(summary.get("gold", 0)) + 1
			summary["points"] = _safe_int(summary.get("points", 0)) + _safe_int(result.get("points", 0))
		by_category[category] = summary

	var output: Array = []
	for category in CATEGORY_ORDER:
		if by_category.has(category):
			output.append(by_category[category])
	return output

func unlock(achievement_id: String, payload: Dictionary = {}, source: String = "client") -> bool:
	var id := CATALOG.normalize_id(achievement_id)
	if not _can_unlock_id(id, payload, source):
		return false
	if id == "":
		return false
	if unlocked_ids.has(id):
		return _upgrade_unlocked_tier(id, payload, source)

	var achievement := CATALOG.get_by_id(id)
	if achievement.is_empty():
		return false

	var unlocked_at_ms := _safe_int(Time.get_unix_time_from_system() * 1000.0)
	unlocked_ids[id] = true
	var final_payload := payload.duplicate(true)
	if ["life_beyond_earth", "the_chosen_one", "toxic_traits", "the_pull_of_the_universe", "star_of_the_show"].has(id) and not final_payload.has("is_exoplanet"):
		final_payload["is_exoplanet"] = false
	unlocked_payloads[id] = {
		"number": _safe_int(achievement.get("number", 0)),
		"unlocked": true,
		"tier": clampi(_safe_int(final_payload.get("tier", _tier_for_staged_count(id, _safe_int(final_payload.get("count", 1))) if _is_staged_achievement(id) else TIER_GOLD)), TIER_BRONZE, TIER_GOLD),
		"unlockedAtMs": unlocked_at_ms,
		"data": final_payload,
		"source": source
	}

	var unlocked_tier := _normalize_display_tier(id, _safe_int(unlocked_payloads[id].get("tier", _default_tier_for_id(id))))
	var should_show_toast := not _has_shown_unlock_toast(id, unlocked_tier)
	if should_show_toast:
		_mark_unlock_toast_shown(id, unlocked_tier)

	_save_local()

	if should_show_toast:
		var visible_result := _result_for(achievement)
		var unlocked_stage_description := CATALOG.stage_description(achievement, unlocked_tier)
		visible_result["description"] = unlocked_stage_description
		visible_result["current_stage_description"] = unlocked_stage_description
		visible_result["toast_description"] = unlocked_stage_description
		achievement_unlocked.emit(visible_result)
	refresh(true)

	if backend_sync_enabled:
		_sync_unlock_to_backend(id, final_payload, source)

	return true

func is_unlocked(achievement_id: String) -> bool:
	return unlocked_ids.has(CATALOG.normalize_id(achievement_id))

func load_from_backend() -> Dictionary:
	if _is_loading:
		return {"success": false, "error": "ALREADY_LOADING"}

	_is_loading = true
	var result := await _request_backend(ACHIEVEMENTS_PATH, HTTPClient.METHOD_GET, {})
	_is_loading = false

	if not bool(result.get("success", false)):
		return result

	# Keep local state as the base and merge backend data into it. The backend has
	# existed in a few shapes over time, so this loader intentionally accepts all
	# sane variants instead of assuming only `states: Array`.
	var merged_unlocked_ids := unlocked_ids.duplicate(true)
	var merged_unlocked_payloads := unlocked_payloads.duplicate(true)
	var backend_state_count := 0

	backend_state_count += _merge_backend_state_collection(result.get("states", null), merged_unlocked_ids, merged_unlocked_payloads)
	backend_state_count += _merge_backend_state_collection(result.get("achievementStates", null), merged_unlocked_ids, merged_unlocked_payloads)
	backend_state_count += _merge_backend_state_collection(result.get("achievement_states", null), merged_unlocked_ids, merged_unlocked_payloads)
	backend_state_count += _merge_backend_state_collection(result.get("achievements", null), merged_unlocked_ids, merged_unlocked_payloads)
	backend_state_count += _merge_backend_state_collection(result.get("unlockedAchievements", null), merged_unlocked_ids, merged_unlocked_payloads)
	backend_state_count += _merge_backend_state_collection(result.get("unlocked_achievements", null), merged_unlocked_ids, merged_unlocked_payloads)
	backend_state_count += _merge_backend_state_collection(result.get("unlocked", null), merged_unlocked_ids, merged_unlocked_payloads)
	backend_state_count += _merge_backend_state_collection(result.get("unlockedIds", null), merged_unlocked_ids, merged_unlocked_payloads)
	backend_state_count += _merge_backend_state_collection(result.get("unlocked_ids", null), merged_unlocked_ids, merged_unlocked_payloads)

	var progress_value: Variant = _first_dictionary_value(result, [
		"progress",
		"events",
		"local_events",
		"localEvents",
		"counters",
		"achievementProgress",
		"achievement_progress"
	])
	if progress_value is Dictionary:
		local_events = _merge_event_dictionaries(local_events, progress_value)

	unlocked_ids = merged_unlocked_ids
	unlocked_payloads = merged_unlocked_payloads

	# Critical: a staged achievement is unlocked when its saved counter reaches a
	# tier threshold. This makes restart/reinstall safe even if the backend only
	# stored progress and not a separate boolean.
	_apply_progress_state_to_unlocks("backend_or_local_state")

	_purge_invalid_unlocks()
	_mark_loaded_unlocks_as_seen()
	_save_local(false)
	# If this device had local progress/unlocks that were missing from the backend,
	# immediately push the merged state back so app reinstalls/account switches do not lose it.
	if backend_sync_enabled and (backend_state_count < unlocked_ids.size() or progress_value is Dictionary):
		_queue_backend_full_save()
	achievements_loaded.emit()
	return result

func sync_all_to_backend() -> Dictionary:
	var states: Array = []
	for id in unlocked_ids.keys():
		var achievement := CATALOG.get_by_id(str(id))
		if achievement.is_empty():
			continue
		var payload: Dictionary = {}
		var raw_payload: Variant = unlocked_payloads.get(str(id), {})
		if raw_payload is Dictionary:
			payload = raw_payload
		var saved_data: Dictionary = payload.get("data", payload.get("payload", {})) if payload.get("data", payload.get("payload", {})) is Dictionary else {}
		states.append({
			"id": str(id),
			"achievementId": str(id),
			"number": _safe_int(achievement.get("number", 0)),
			"achievementNumber": _safe_int(achievement.get("number", 0)),
			"unlocked": true,
			"tier": _normalize_display_tier(id, _safe_int(payload.get("tier", _default_tier_for_id(id)))),
			"unlockedAtMs": _safe_int(payload.get("unlockedAtMs", 0)),
			"count": _safe_int(saved_data.get("count", payload.get("count", 1))),
			"data": saved_data,
			"source": str(payload.get("source", "client_sync"))
		})
	return await _request_backend(SYNC_ACHIEVEMENTS_PATH, HTTPClient.METHOD_POST, {
		"states": states,
		"progress": local_events
	})

func _sync_unlock_to_backend(achievement_id: String, payload: Dictionary, source: String) -> void:
	var achievement := CATALOG.get_by_id(achievement_id)
	if achievement.is_empty():
		return
	var result := await _request_backend(UNLOCK_ACHIEVEMENT_PATH, HTTPClient.METHOD_POST, {
		"id": achievement_id,
		"achievementId": achievement_id,
		"achievementNumber": _safe_int(achievement.get("number", 0)),
		"number": _safe_int(achievement.get("number", 0)),
		"unlocked": true,
		"tier": _normalize_display_tier(achievement_id, _safe_int(payload.get("tier", _default_tier_for_id(achievement_id)))),
		"count": _safe_int(payload.get("count", 1)),
		"data": payload,
		"source": source
	})
	if not bool(result.get("success", false)) and str(result.get("error", "")) != "BACKEND_SYNC_DISABLED":
		if _safe_int(result.get("status", 0)) != 404:
			push_warning("Achievement backend sync failed: %s" % str(result))

func _can_unlock_id(id: String, payload: Dictionary = {}, source: String = "") -> bool:
	match id:
		"life_beyond_earth", "the_chosen_one", "toxic_traits", "the_pull_of_the_universe":
			if not bool(payload.get("is_exoplanet", false)):
				return false
			var body_name := str(payload.get("body", payload.get("source_name", "")))
			var instance_id := str(payload.get("instance_id", ""))
			if _is_solar_system_object(body_name) or _is_solar_system_object(instance_id):
				return false
		"star_of_the_show":
			var body_name := str(payload.get("body", payload.get("source_name", "")))
			var instance_id := str(payload.get("instance_id", ""))
			if _is_solar_system_object(body_name) or _is_solar_system_object(instance_id):
				return false
	return true

func _purge_invalid_unlocks() -> void:
	var changed := false
	for id in ["life_beyond_earth", "the_chosen_one", "toxic_traits", "the_pull_of_the_universe", "star_of_the_show"]:
		if not unlocked_ids.has(id):
			continue
		var payload: Dictionary = {}
		var raw_payload: Variant = unlocked_payloads.get(id, {})
		if raw_payload is Dictionary:
			payload = raw_payload.get("data", raw_payload) if raw_payload.has("data") else raw_payload
		if not _can_unlock_id(id, payload, "purge"):
			unlocked_ids.erase(id)
			unlocked_payloads.erase(id)
			changed = true
	if changed:
		_save_local()


func _is_rare_achievement(id: String) -> bool:
	return bool(RARE_ACHIEVEMENTS.get(CATALOG.normalize_id(id), false))

func _achievement_rarity(id: String) -> String:
	return "rare" if _is_rare_achievement(id) else "normal"

func _is_staged_achievement(id: String) -> bool:
	return not _achievement_rule(id).is_empty()

func _default_tier_for_id(id: String) -> int:
	return TIER_BRONZE

func _normalize_display_tier(id: String, tier: int) -> int:
	return clampi(_safe_int(tier), TIER_NONE, TIER_GOLD)

func _tier_for_staged_count(id: String, count: int) -> int:
	id = CATALOG.normalize_id(id)
	var rule := _achievement_rule(id)
	if rule.is_empty():
		return TIER_NONE
	var thresholds: Array = rule.get("thresholds", [1, 999999, 999999])
	if count >= _safe_int(thresholds[min(2, thresholds.size() - 1)]):
		return TIER_GOLD
	if count >= _safe_int(thresholds[min(1, thresholds.size() - 1)]):
		return TIER_SILVER
	if count >= _safe_int(thresholds[0]):
		return TIER_BRONZE
	return TIER_NONE

func _staged_progress_for(id: String, payload: Dictionary = {}) -> Dictionary:
	id = CATALOG.normalize_id(id)
	var stage: Dictionary = _achievement_rule(id)
	if stage.is_empty():
		return {}
	var event_key := str(stage.get("event", ""))
	var payload_data: Dictionary = payload.get("data", {}) if payload.get("data", {}) is Dictionary else {}
	# Progress must be live. The stored unlock payload is only a snapshot from the
	# moment a stage unlocked, so prefer the live saved counter from local_events.
	var raw_count: Variant = local_events.get(event_key, payload.get("count", payload_data.get("count", 0)))
	var count := 0
	if raw_count is Dictionary:
		count = raw_count.size()
	elif raw_count is Array:
		count = raw_count.size()
	else:
		count = _safe_int(raw_count)
	# Backward compatibility for old saves only until the unique counter exists.
	if id == "a_fresh_start" and not local_events.has(event_key):
		count = max(count, _safe_int(local_events.get("body_added", 0)))
	var thresholds: Array = stage.get("thresholds", [1, 999999, 999999])
	var tier := _tier_for_staged_count(id, count)
	var next_required := _safe_int(thresholds[min(max(tier, 0), thresholds.size() - 1)])
	if tier >= TIER_GOLD:
		next_required = _safe_int(thresholds[min(2, thresholds.size() - 1)])
	return {
		"tier": tier,
		"current_count": count,
		"required_count": max(next_required, 1),
		"progress": clamp(float(count) / float(max(next_required, 1)), 0.0, 1.0),
		"label": str(stage.get("label", ""))
	}

func _upgrade_unlocked_tier(id: String, payload: Dictionary = {}, source: String = "client") -> bool:
	id = CATALOG.normalize_id(id)
	var raw_current_payload: Variant = unlocked_payloads.get(id, {})
	if not (raw_current_payload is Dictionary):
		return false
	var current_payload: Dictionary = raw_current_payload
	var current_tier := clampi(_normalize_display_tier(id, _safe_int(current_payload.get("tier", _default_tier_for_id(id)))), TIER_BRONZE, TIER_GOLD)
	var current_data: Dictionary = current_payload.get("data", {}) if current_payload.get("data", {}) is Dictionary else {}
	var requested_tier := clampi(_safe_int(payload.get("tier", _tier_for_staged_count(id, _safe_int(payload.get("count", current_payload.get("count", current_data.get("count", 1))))) if _is_staged_achievement(id) else TIER_GOLD)), TIER_BRONZE, TIER_GOLD)
	if requested_tier <= current_tier:
		return false
	var data_payload: Dictionary = current_payload.get("data", {}) if current_payload.get("data", {}) is Dictionary else {}
	for key in payload.keys():
		data_payload[key] = payload[key]
	current_payload["tier"] = requested_tier
	current_payload["data"] = data_payload
	current_payload["source"] = source
	current_payload["count"] = _safe_int(payload.get("count", data_payload.get("count", 1)))
	unlocked_payloads[id] = current_payload
	var should_show_toast := not _has_shown_unlock_toast(id, requested_tier)
	if should_show_toast:
		_mark_unlock_toast_shown(id, requested_tier)
	_save_local()
	var achievement := CATALOG.get_by_id(id)
	if should_show_toast and not achievement.is_empty():
		var visible_result := _result_for(achievement)
		var unlocked_stage_description := CATALOG.stage_description(achievement, requested_tier)
		visible_result["description"] = unlocked_stage_description
		visible_result["current_stage_description"] = unlocked_stage_description
		visible_result["toast_description"] = unlocked_stage_description
		achievement_unlocked.emit(visible_result)
	refresh(true)
	if backend_sync_enabled:
		_sync_unlock_to_backend(id, data_payload, source)
	return true

func unlock_stage(achievement_id: String, count: int, payload: Dictionary = {}, source: String = "stage") -> bool:
	var id := CATALOG.normalize_id(achievement_id)
	var tier := _tier_for_staged_count(id, count)
	if tier <= TIER_NONE:
		return false
	var final_payload := payload.duplicate(true)
	final_payload["count"] = count
	final_payload["tier"] = tier
	return unlock(id, final_payload, source)

func _tier_name(tier: int) -> String:
	match _safe_int(tier):
		1:
			return "BRONZE"
		2:
			return "SILVER"
		3:
			return "GOLD"
		_:
			return "LOCKED"

func _build_results() -> Array:
	var result: Array = []
	for achievement in CATALOG.all():
		result.append(_result_for(achievement))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _safe_int(a.get("number", 0)) < _safe_int(b.get("number", 0))
	)
	return result

func _result_for(achievement: Dictionary) -> Dictionary:
	var id := str(achievement.get("id", ""))
	var unlocked := unlocked_ids.has(id)
	var source_category := str(achievement.get("category", "CARDS"))
	var category := str(CATEGORY_MAP.get(source_category, "type_amount"))
	var category_label := str(CATEGORY_LABELS.get(category, source_category.capitalize()))
	var payload: Dictionary = {}
	var raw_payload: Variant = unlocked_payloads.get(id, {})
	if raw_payload is Dictionary:
		payload = raw_payload
	var unlocked_at_ms := _safe_int(payload.get("unlockedAtMs", 0))
	var stored_tier := _normalize_display_tier(id, _safe_int(payload.get("tier", _default_tier_for_id(id))))
	var stage_info := _staged_progress_for(id, payload)
	if stage_info.has("tier"):
		stored_tier = max(stored_tier, _safe_int(stage_info.get("tier", stored_tier)))
	stored_tier = _normalize_display_tier(id, stored_tier)

	if unlocked:
		var display_tier := stored_tier
		var description_tier := min(stored_tier + 1, TIER_GOLD)
		var current_stage_description := CATALOG.stage_description(achievement, display_tier)
		var next_stage_description := CATALOG.stage_description(achievement, description_tier)
		var current_count := _safe_int(stage_info.get("current_count", 1))
		var required_count := max(_safe_int(stage_info.get("required_count", 1)), 1)
		var display_progress := clamp(float(current_count) / float(required_count), 0.0, 1.0)
		if stored_tier >= TIER_GOLD:
			display_progress = 1.0
			next_stage_description = current_stage_description
		return {
			"id": id,
			"number": _safe_int(achievement.get("number", 0)),
			"category": category,
			"category_label": category_label,
			"source_category": source_category,
			"title": str(achievement.get("title", "Achievement")),
			"base_title": str(achievement.get("title", "Achievement")),
			"description": next_stage_description,
			"current_stage_description": current_stage_description,
			"next_stage_description": next_stage_description,
			"tier": display_tier,
			"tier_name": _tier_name(display_tier),
			"next_tier": description_tier,
			"next_tier_name": _tier_name(description_tier),
			"rarity": _achievement_rarity(id),
			"rarity_label": _achievement_rarity(id).to_upper(),
			"points": 25 if _is_rare_achievement(id) else 10,
			"progress": display_progress,
			"current_count": current_count,
			"required_count": required_count,
			"stage_label": str(stage_info.get("label", "")),
			"avg_level": 1.0,
			"min_level": 1,
			"required_stars": 0,
			"active_stars": 0,
			"unlocked": true,
			"hidden": false,
			"unlockedAtMs": unlocked_at_ms
		}

	return {
		"id": id,
		"number": _safe_int(achievement.get("number", 0)),
		"category": category,
		"category_label": category_label,
		"source_category": source_category,
		"title": "???",
		"description": "Hidden achievement",
		"tier": TIER_NONE,
		"tier_name": "LOCKED",
		"rarity": _achievement_rarity(id),
		"rarity_label": "???",
		"points": 0,
		"progress": float(stage_info.get("progress", progress.get(id, 0.0))),
		"current_count": _safe_int(stage_info.get("current_count", 0)),
		"required_count": _safe_int(stage_info.get("required_count", 1)),
		"stage_label": str(stage_info.get("label", "")),
		"avg_level": 0.0,
		"min_level": 0,
		"required_stars": 0,
		"active_stars": 0,
		"unlocked": false,
		"hidden": true,
		"unlockedAtMs": 0
	}

func register_body_added(body) -> void:
	# This is intentionally called only from explicit add button / AI add body paths.
	# "Different cosmic bodies" must be tracked as unique bodies, not raw add taps.
	var d = _data(body)
	if d == null:
		return

	var scores := _scores(d)
	var uid := str(_read(_source(d), "instance_id", _read(d, "source_card_id", _read(d, "card_id", _name(d))))).strip_edges()
	if uid.is_empty():
		uid = _name(d)
	_mark_unique_counter("a_fresh_start", uid, {"body": _name(d), "instance_id": uid}, "body_added")

	if _is_exoplanet(d) and _score_value(scores, "habitability") >= 90:
		_mark_unique_counter("life_beyond_earth", uid, _body_payload(d), "body_added")
	if _is_exoplanet(d) and _stats_above_count(scores, 80) >= 4:
		_set_level_stage("the_chosen_one", _level(d), _body_payload(d), "body_added")
	if _is_ringed_exoplanet(d):
		_mark_unique_counter("give_me_that_ring", uid, _body_payload(d), "body_added")
	if _is_gas_giant_exoplanet(d) and _jupiter_diameter(d) >= 3.0:
		_mark_unique_counter("gas_titan", uid, _body_payload(d), "body_added")
	if _is_exoplanet(d) and not _is_star(d) and _score_value(scores, "radiation_safety", 100) < 5:
		_mark_unique_counter("toxic_traits", uid, _body_payload(d), "body_added")
	if _is_star(d) and not _is_solar_system_object(_name(d)):
		_mark_unique_counter("star_of_the_show", uid, _body_payload(d), "body_added")
	if _is_exoplanet(d) and _score_value(scores, "geology") >= 95:
		_set_level_stage("diamonds", _level(d), _body_payload(d), "body_added")
	if _is_exoplanet(d) and _score_value(scores, "gravity") >= 95:
		_set_level_stage("the_pull_of_the_universe", _level(d), _body_payload(d), "body_added")
	if _is_unknown_solar_moon(d):
		_set_level_stage("unknown_moon", _level(d), _body_payload(d), "body_added")
	if _is_black_hole(d):
		_increment_counter("black_magic", 1, _body_payload(d), "body_added")
	if _is_white_hole(d):
		_set_level_stage("white_magic", _level(d), _body_payload(d), "body_added")

	_save_local()
	refresh(true)

func record_body_added(data: Variant = null) -> void:
	register_body_added(data)

func register_collision(a, b, survivor = null) -> void:
	var ad = _data(a)
	var bd = _data(b)
	var sd = _data(survivor)
	if ad == null or bd == null:
		return

	_increment_counter("big_bang", 1, {"a": _name(ad), "b": _name(bd)}, "collision")

	var a_star := _is_star(ad)
	var b_star := _is_star(bd)
	var a_planet := _is_planet(ad)
	var b_planet := _is_planet(bd)
	var a_moon := _is_moon(ad)
	var b_moon := _is_moon(bd)
	var a_black := _is_black_hole(ad)
	var b_black := _is_black_hole(bd)
	var a_white_hole := _is_white_hole(ad)
	var b_white_hole := _is_white_hole(bd)

	# If any star is involved, star-collision checks run, but planet lineage checks still run too.
	if (a_star and b_planet and _is_exoplanet(bd) and _stat(bd, "habitability") >= 80):
		_mark_unique_counter("death_star", str(_read(_source(bd), "instance_id", _name(bd))), {"body": _name(bd)}, "collision")
	if (b_star and a_planet and _is_exoplanet(ad) and _stat(ad, "habitability") >= 80):
		_mark_unique_counter("death_star", str(_read(_source(ad), "instance_id", _name(ad))), {"body": _name(ad)}, "collision")
	if (b_star and a_planet and _planet_was_orbiting_another_star(ad, bd)):
		_increment_counter("planet_thief", 1, {"planet": _name(ad), "from": str(_read(ad, "orbit_parent_name", "another star")), "to": _name(bd)}, "collision")
	if (a_star and b_planet and _planet_was_orbiting_another_star(bd, ad)):
		_increment_counter("planet_thief", 1, {"planet": _name(bd), "from": str(_read(bd, "orbit_parent_name", "another star")), "to": _name(ad)}, "collision")
	if (a_moon and b_star) or (b_moon and a_star):
		_increment_counter("needle_in_a_haystack", 1, {"a": _name(ad), "b": _name(bd)}, "collision")

	if a_star or b_star:
		local_events["star_collision"] = _safe_int(local_events.get("star_collision", 0)) + 1

	if a_star and b_star:
		var star_window := _prune_time_window("rapid_star_collision_times", 10.0)
		var star_count_10 := star_window.size()
		var star_count_7 := 0
		var star_count_5 := 0
		var now := float(Time.get_ticks_msec()) / 1000.0
		for t in star_window:
			if now - float(t) <= 7.0: star_count_7 += 1
			if now - float(t) <= 5.0: star_count_5 += 1
		if star_count_5 >= 5:
			_set_counter_value("triple_trouble", 5, {"window": 5}, "collision_window")
		elif star_count_7 >= 4:
			_set_counter_value("triple_trouble", 4, {"window": 7}, "collision_window")
		elif star_count_10 >= 3:
			_set_counter_value("triple_trouble", 3, {"window": 10}, "collision_window")

		if _similar(float(_read(ad, "mass", 0.0)), float(_read(bd, "mass", 0.0)), 0.20) and _similar(float(_read(ad, "radius_world", 0.0)), float(_read(bd, "radius_world", 0.0)), 0.18):
			_increment_counter("binary_breakup", 1, {"a": _name(ad), "b": _name(bd)}, "collision")
		if _is_red_giant(ad) and _is_red_giant(bd):
			_set_level_stage("unlocking_supernova", _min_level(ad, bd), {"a": _name(ad), "b": _name(bd)}, "collision")
			_increment_counter("black_magic", 1, {"source": "supernova"}, "supernova")
		if _one_small_one_big(ad, bd):
			_increment_counter("life_s_not_fair", 1, {"a": _name(ad), "b": _name(bd)}, "collision")

	if _is_brown_dwarf(ad) and _is_brown_dwarf(bd):
		_set_level_stage("a_girl_s_fight", _min_level(ad, bd), {"a": _name(ad), "b": _name(bd)}, "collision")
	if (_is_white_dwarf(ad) and _is_brown_dwarf(bd)) or (_is_white_dwarf(bd) and _is_brown_dwarf(ad)):
		_increment_counter("start_end", 1, {"a": _name(ad), "b": _name(bd)}, "collision")
	if (a_planet and b_planet) and _score_value(_scores(ad), "magnetic_field") >= 90 and _score_value(_scores(bd), "magnetic_field") >= 90:
		_increment_counter("magneto_s_helmet_origins", 1, {"a": _name(ad), "b": _name(bd)}, "collision")
	if (a_planet and b_planet) and _score_value(_scores(ad), "atmosphere", 100) < 10 and _score_value(_scores(bd), "atmosphere", 100) < 10:
		_increment_counter("breath_taking", 1, {"a": _name(ad), "b": _name(bd)}, "collision")
	if (_is_ice(ad) and _is_lava(bd)) or (_is_ice(bd) and _is_lava(ad)):
		_set_level_stage("extremes_belong_together", _min_level(ad, bd), {"a": _name(ad), "b": _name(bd)}, "collision")
	if _name(ad).to_lower() == "earth" or _name(bd).to_lower() == "earth":
		_increment_counter("no_hope_for_humanity", 1, {"a": _name(ad), "b": _name(bd)}, "collision")
	if _is_brown_dwarf(sd) and (a_planet or b_planet):
		_increment_counter("so_close", 1, {"body": _name(sd)}, "collision")
	if _is_planet(sd) and _lineage_is_only_satellites(sd):
		_mark_unique_counter("not_quite_a_planet", _lineage_result_key(sd), {"body": _name(sd), "lineage": _lineage_names(sd)}, "collision")

	var all_moons_cleared_payload := _all_moons_cleared_payload(ad, bd, sd)
	if not all_moons_cleared_payload.is_empty():
		var unique_key := str(all_moons_cleared_payload.get("planet_id", all_moons_cleared_payload.get("planet_name", _name(sd))))
		unique_key += ":" + str(all_moons_cleared_payload.get("moon_id", all_moons_cleared_payload.get("moon_name", "last_moon")))
		_mark_unique_counter("this_was_not_supposed_to_happen", unique_key, all_moons_cleared_payload, "collision")

	_check_planet_lineage_achievements(sd)
	if a_star or b_star:
		_check_star_lineage_achievements(sd)

	if a_black or b_black:
		_register_black_hole_collision(ad, bd)
	if a_black and b_black:
		_increment_counter("gravity_bender", 1, {"a": _name(ad), "b": _name(bd)}, "collision")
	if (a_black and b_white_hole) or (b_black and a_white_hole):
		_set_level_stage("the_end_of_the_universe", _min_level(ad, bd), {"a": _name(ad), "b": _name(bd)}, "collision")

	_save_local()
	refresh(true)

func record_planet_collision(a: Variant = null, b: Variant = null) -> void:
	if a != null and b != null:
		register_collision(a, b)
	else:
		local_events["planet_collision"] = _safe_int(local_events.get("planet_collision", 0)) + 1
		unlock_stage("big_bang", _safe_int(local_events.get("planet_collision", 0)), {}, "collision")
		_save_local()
		refresh(true)

func record_sun_collision(a: Variant = null, b: Variant = null) -> void:
	local_events["star_collision"] = _safe_int(local_events.get("star_collision", 0)) + 1
	if a != null and b != null:
		register_collision(a, b)
	_save_local()
	refresh(true)

func record_black_hole_discovered_by_supernova(_data: Variant = null) -> void:
	_increment_counter("black_magic", 1, {"source": "supernova"}, "supernova")
	_save_local()
	refresh(true)

func register_system_score(feedback: Dictionary) -> void:
	# Called after add/exit-menu score refreshes; not from every physics tick.
	var stats: Dictionary = {}
	var raw_stats: Variant = feedback.get("stats", {})
	if raw_stats is Dictionary:
		stats = raw_stats
	var score := _safe_int(feedback.get("system_score", 0))
	var grade := str(feedback.get("grade", ""))
	var star_count := _safe_int(feedback.get("star_count", 0))
	var planet_count := _safe_int(feedback.get("planet_count", 0))
	var moon_count := _safe_int(feedback.get("moon_count", 0))
	var object_count := _safe_int(feedback.get("object_count", 0))
	var level5_planets := _safe_int(feedback.get("level5_planets", 0))
	var level10_planets := _safe_int(feedback.get("level10_planets", 0))

	# Empty galaxy feedback uses zeroed stats, which must not unlock stat achievements.
	# Also require at least one actual planet for the STAT MASTERY category.
	if object_count <= 0 or planet_count <= 0:
		return

	if score < 35:
		var bad_stage := 1
		if _max_stat(stats) < 10: bad_stage = 3
		elif _max_stat(stats) < 25: bad_stage = 2
		_set_counter_value("we_ain_t_going_there", bad_stage, {"score": score}, "stats")
	if _safe_int(stats.get("radiation_safety", 0)) >= 90 and star_count >= 1:
		_set_counter_value("radiation_proof", max(planet_count, 1), {"planets": planet_count}, "stats")
	if _safe_int(stats.get("geology", 0)) >= 90 and _safe_int(stats.get("magnetic_field", 0)) >= 90:
		_set_counter_value("rock_solid", 85 if _safe_int(stats.get("geology", 0)) >= 95 and _safe_int(stats.get("magnetic_field", 0)) >= 95 and score >= 85 else (75 if score >= 75 else 1), {"score": score}, "stats")
	if _max_stat(stats) >= 90 and _min_stat(stats) < 25:
		var cost_stage := 1
		if _max_stat(stats) >= 95 and _min_stat(stats) < 15: cost_stage = 3
		elif _max_stat(stats) >= 95 and _min_stat(stats) < 20: cost_stage = 2
		_set_counter_value("i_ve_won_but_at_what_cost", cost_stage, {"stats": stats}, "stats")
	if score >= 75 and moon_count > planet_count:
		_set_counter_value("moon_economy", score, {"score": score}, "stats")
	if star_count == 1 and planet_count >= 8 and _grade_at_least(grade, "S"):
		_set_level_stage("one_star_review", 10 if level10_planets >= 4 else (5 if level5_planets >= 4 else 1), {"grade": grade}, "stats")
	if score >= 85 and object_count >= 12:
		_set_counter_value("overengineered", score, {"score": score, "objects": object_count}, "stats")
	if _min_stat(stats) >= 80:
		_set_level_stage("better_than_home", 10 if level10_planets >= 3 and _min_stat(stats) >= 90 else (5 if level5_planets >= 3 and _min_stat(stats) >= 85 else 1), {"stats": stats}, "stats")
	if star_count == 1 and planet_count >= 10 and moon_count >= 5 and _grade_at_least(grade, "A"):
		_set_level_stage("crowded_neighborhood", 10 if level10_planets >= 5 else (5 if level5_planets >= 5 else 1), {"grade": grade}, "stats")
	if grade == "Ω" or grade.to_lower() == "omega":
		_set_level_stage("omega_protocol", 10 if level10_planets >= 5 else (5 if level5_planets >= 5 else 1), {"grade": grade}, "stats")
	_save_local()
	refresh(true)

func register_stability_snapshot(bodies: Array, config, delta: float) -> void:
	# Manual stability achievements only run when stable orbit mode is OFF.
	if config == null or bool(_read(config, "stable_orbit_mode", false)):
		timers.clear()
		return

	var planets := _count_kind(bodies, "planet")
	var stars := _count_kind(bodies, "star")
	var moons := _count_kind(bodies, "moon")
	var total := bodies.size()
	var lvl5_planets := _count_level_at_least(bodies, 5, func(d): return _is_planet(d))
	var lvl10_planets := _count_level_at_least(bodies, 10, func(d): return _is_planet(d))

	_update_timer("first_orbit", _has_planet_orbiting_star(bodies), 90.0, delta)
	_update_timer("moon_guardian", _has_moon_orbiting_planet(bodies), 120.0, delta)
	_update_timer("solar_starter", stars >= 1 and planets >= 8, 60.0, delta, planets)
	_update_timer("binary_ballet", _has_binary_stars(bodies), 120.0, delta)
	_update_timer("family_system", stars >= 1 and planets >= 8 and moons >= 5, 60.0, delta, planets)
	_update_timer("no_crash_zone", total >= 10, 120.0, delta, total)
	_update_timer("perfect_spacing", _planets_same_star(bodies) >= 10, 90.0, delta, _planets_same_star(bodies))
	_update_timer("triple_trouble_but_stable", stars >= 3 and (lvl5_planets >= 3 or lvl10_planets >= 3 or planets >= 0), 60.0, delta, 10 if lvl10_planets >= 3 else (5 if lvl5_planets >= 3 else 1))
	_update_timer("cosmic_clockwork", total >= 10 and (lvl5_planets >= 5 or lvl10_planets >= 5 or total >= 10), 120.0, delta, 10 if lvl10_planets >= 5 else (5 if lvl5_planets >= 5 else 1))
	_update_timer("eternal_system", total >= 2 and (lvl5_planets >= 5 or lvl10_planets >= 5 or total >= 2), 180.0, delta, 10 if lvl10_planets >= 5 else (5 if lvl5_planets >= 5 else 1))

func register_unstable_snapshot(bodies: Array, config = null) -> void:
	var planets := _count_kind(bodies, "planet")
	var stars := _count_kind(bodies, "star")
	var moons := _count_kind(bodies, "moon")
	var black_holes := _count_kind(bodies, "black_hole")
	var lvl5_planets := _count_level_at_least(bodies, 5, func(d): return _is_planet(d))
	var lvl10_planets := _count_level_at_least(bodies, 10, func(d): return _is_planet(d))

	# System-type achievements are checked only when those types actually exist in scene.
	if moons > 0 and _has_many_moons_same_planet(bodies, 5):
		_set_counter_value("moon_master", max(_max_moons_same_planet(bodies), 5), {}, "unstable_system")
	if planets > 0 and stars == 0:
		_set_counter_value("frozen_wasteland", planets, {}, "unstable_system")
	if stars > 0 and planets == 0 and moons == 0:
		_set_counter_value("ra_s_empire", stars, {}, "unstable_system")
	if planets > 0 and _has_red_supergiant(bodies):
		_set_counter_value("on_the_edge_of_extinction", planets, {}, "unstable_system")
	if _planets_orbiting_named_body(bodies, "earth") >= 5:
		_set_counter_value("center_of_the_universe", _planets_orbiting_named_body(bodies, "earth"), {}, "unstable_system")
	if planets >= 8 and _has_central_planet_binary(bodies):
		_set_counter_value("dual_what", planets, {}, "unstable_system")
	if bool(_read(config, "stable_orbit_mode", true)) == false and planets >= 5:
		_set_counter_value("whoops_wrong_button", planets, {}, "unstable_system")
	if _any_planet_far_from_origin(bodies, 100000.0):
		_set_level_stage("rogue_one", _max_far_planet_level(bodies, 100000.0), {}, "unstable_system")
	if config != null and bool(_read(config, "center_largest_body", true)) == false and _any_star_far_from_origin(bodies):
		_set_level_stage("this_feels_more_like_reality", 10 if lvl10_planets >= 8 else (5 if lvl5_planets >= 5 else 1), {}, "unstable_system")
	if _has_planet_orbiting_moon(bodies) or _has_star_orbiting_planet(bodies):
		_set_level_stage("game_s_broken_now", _broken_orbit_level(bodies), {}, "unstable_system")

	if black_holes > 0:
		_set_counter_value("the_formation_of_a_galaxy", _max_stars_orbiting_black_hole(bodies), {}, "black_hole_system")
		_set_counter_value("forbidden_orbit", _max_moons_orbiting_black_hole(bodies), {}, "black_hole_system")

func register_cards(cards: Array, emit_refresh: bool = true) -> void:
	_cards_cache = cards.duplicate()

	var generated := 0
	var ice := 0
	var habitable := 0
	var moons := 0
	var gas := 0
	var brown := 0
	var fictional := 0
	var presets := {}
	var max_card_level := 1
	var generated_ids: Dictionary = local_events.get("generated_card_ids", {}) if local_events.get("generated_card_ids", {}) is Dictionary else {}

	for card in cards:
		var category := _category(card)
		var preset := _preset(card)
		var archetype := _archetype(card)
		var level := _level(card)
		max_card_level = max(max_card_level, level)
		if _is_generated_card(card):
			generated += 1
			var gid := str(_read(card, "instance_id", _name(card))).strip_edges()
			if not gid.is_empty(): generated_ids[gid] = true
		if preset.contains("ice") or archetype.contains("ice"):
			ice += 1
		if _card_stat(card, "habitability") >= 80 or preset in ["earth", "terran_wet", "islands", "rivers"]:
			habitable += 1
		if category in ["moon", "satellite"] or archetype == "moon":
			moons += 1
		if preset.contains("gas") or archetype.contains("gas_giant"):
			gas += 1
		if archetype == "brown_dwarf" or _name(card).to_lower().contains("brown dwarf"):
			brown += 1
		if _is_white_hole(card):
			_set_level_stage("white_magic", level, {"card_id": str(_read(card, "instance_id", "")), "body": _name(card)}, "cards")
		if bool(_read(card, "is_fictional", false)):
			fictional += 1
		if preset != "":
			presets[preset] = _safe_int(presets.get(preset, 0)) + 1

	local_events["generated_card_ids"] = generated_ids
	_set_counter_value("planet_collector", generated, {"count": generated}, "cards")
	_set_counter_value("the_archivist", generated, {"count": generated}, "cards")
	_set_counter_value("ice_age", ice, {"count": ice}, "cards")
	_set_counter_value("terra_hunter", habitable, {"count": habitable}, "cards")
	_set_counter_value("moon_factory", moons, {"count": moons}, "cards")
	_set_counter_value("it_s_not_real", fictional, {"count": fictional}, "cards")
	_set_counter_value("gas_dealer", gas, {"count": gas}, "cards")
	_set_counter_value("failed_star_club", brown, {"count": brown}, "cards")
	_set_counter_value("lvl_up", max_card_level, {"level": max_card_level}, "cards")
	var min_preset_count := 999999
	for preset_key in presets.keys():
		min_preset_count = min(min_preset_count, _safe_int(presets[preset_key]))
	if presets.size() >= PLANET_PRESET_TARGET:
		_set_counter_value("strange_new_worlds", min_preset_count, {"preset_count": presets.size()}, "cards")

	if emit_refresh:
		_save_local()
		refresh(true)

func _update_timer(id: String, valid: bool, needed: float, delta: float, count_override: int = -1) -> void:
	if not valid:
		timers[id] = 0.0
		progress[id] = 0.0
		return
	timers[id] = float(timers.get(id, 0.0)) + max(delta, 0.0)
	var elapsed := _safe_int(floor(float(timers[id])))
	var rule := _achievement_rule(id)
	var thresholds: Array = rule.get("thresholds", [needed, needed, needed])
	var stage_count := elapsed if count_override < 0 else count_override
	if id in ["first_orbit", "moon_guardian", "binary_ballet"]:
		stage_count = elapsed
	elif id in ["solar_starter", "family_system", "no_crash_zone", "perfect_spacing"]:
		stage_count = count_override if count_override >= 0 else elapsed
	elif id in ["triple_trouble_but_stable", "cosmic_clockwork", "eternal_system"]:
		stage_count = count_override if count_override >= 0 else 1
	var next_required := _safe_int(thresholds[0])
	var current_tier := _tier_for_staged_count(id, _safe_int(local_events.get(_counter_key_for(id), 0)))
	if current_tier == TIER_BRONZE: next_required = _safe_int(thresholds[1])
	elif current_tier >= TIER_SILVER: next_required = _safe_int(thresholds[2])
	progress[id] = clamp(float(elapsed) / max(float(next_required), 0.001), 0.0, 1.0)
	achievement_progress_changed.emit(id, progress[id])
	if float(timers[id]) >= needed:
		_set_counter_value(id, stage_count, {"seconds": elapsed}, "manual_stability")

func _register_black_hole_collision(ad, bd) -> void:
	if (_is_black_hole(ad) and _is_moon(bd)) or (_is_black_hole(bd) and _is_moon(ad)):
		_increment_counter("the_dark_side_of_the_moon", 1, {"a": _name(ad), "b": _name(bd)}, "black_hole_collision")
	if _is_black_hole(ad) and _is_black_hole(bd):
		_increment_counter("gravity_bender", 1, {"a": _name(ad), "b": _name(bd)}, "black_hole_collision")
	if (_is_black_hole(ad) and _is_star(bd)) or (_is_black_hole(bd) and _is_star(ad)):
		var window := _prune_time_window("black_hole_star_swallow_times", 10.0)
		var now := float(Time.get_ticks_msec()) / 1000.0
		var count_10 := window.size()
		var count_7 := 0
		var count_4 := 0
		for t in window:
			if now - float(t) <= 7.0: count_7 += 1
			if now - float(t) <= 4.0: count_4 += 1
		if count_4 >= 3:
			_set_counter_value("star_soup", 3, {"window": 4}, "black_hole_collision")
		elif count_7 >= 3:
			_set_counter_value("star_soup", 2, {"window": 7}, "black_hole_collision")
		elif count_10 >= 3:
			_set_counter_value("star_soup", 1, {"window": 10}, "black_hole_collision")
	if (_is_black_hole(ad) and _is_blue_star(bd)) or (_is_black_hole(bd) and _is_blue_star(ad)):
		_increment_counter("lights_out", 1, {"a": _name(ad), "b": _name(bd)}, "black_hole_collision")
	if (_is_black_hole(ad) and _is_white_hole(bd)) or (_is_black_hole(bd) and _is_white_hole(ad)):
		_set_level_stage("the_end_of_the_universe", _min_level(ad, bd), {"a": _name(ad), "b": _name(bd)}, "black_hole_collision")

func _sync_progress_to_backend() -> void:
	var payload := local_events.duplicate(true)
	await _request_backend(PROGRESS_ACHIEVEMENTS_PATH, HTTPClient.METHOD_POST, {"progress": payload})

func _achievement_rule(id: String) -> Dictionary:
	id = CATALOG.normalize_id(id)
	if id.is_empty():
		return {}

	# Never index STAGED_ACHIEVEMENTS directly with [] here. In Godot, a
	# missing Dictionary key crashes with errors like:
	# "Invalid access to property or key 'a_fresh_start' on a base object of type 'Dictionary'."
	# Using get() keeps startup/load code safe even if an old save sends a
	# slightly different key type or a stale achievement id.
	var direct: Variant = STAGED_ACHIEVEMENTS.get(id, null)
	if direct is Dictionary:
		return direct

	for key in STAGED_ACHIEVEMENTS.keys():
		if CATALOG.normalize_id(str(key)) == id:
			var value: Variant = STAGED_ACHIEVEMENTS.get(key, {})
			return value if value is Dictionary else {}

	return {}

func _counter_key_for(id: String) -> String:
	var rule := _achievement_rule(id)
	return str(rule.get("event", id))

func _set_counter_value(id: String, value: int, payload: Dictionary = {}, source: String = "progress") -> bool:
	var key := _counter_key_for(id)
	var previous := _safe_int(local_events.get(key, 0))
	var next_value = max(previous, _safe_int(value))
	local_events[key] = next_value
	var changed: bool = next_value != previous
	var unlocked := unlock_stage(id, next_value, payload, source)
	if changed and not unlocked:
		_save_local()
		refresh(true)
	return unlocked or changed

func _increment_counter(id: String, amount: int = 1, payload: Dictionary = {}, source: String = "progress") -> bool:
	var key := _counter_key_for(id)
	return _set_counter_value(id, _safe_int(local_events.get(key, 0)) + max(amount, 1), payload, source)

func _mark_unique_counter(id: String, unique_id: String, payload: Dictionary = {}, source: String = "progress") -> bool:
	var key := _counter_key_for(id)
	var unique_key := "%s_unique" % key
	var values: Dictionary = local_events.get(unique_key, {}) if local_events.get(unique_key, {}) is Dictionary else {}
	var clean := str(unique_id).strip_edges().to_lower()
	if clean.is_empty():
		clean = "%s_%d" % [key, _safe_int(local_events.get(key, 0)) + 1]
	if values.has(clean):
		return false
	values[clean] = true
	local_events[unique_key] = values
	return _set_counter_value(id, values.size(), payload, source)

func _set_level_stage(id: String, level: int, payload: Dictionary = {}, source: String = "level") -> bool:
	return _set_counter_value(id, max(level, 1), payload, source)

func _level(d) -> int:
	var source = _source(d)
	return max(1, _safe_int(_read(source, "game_level", _read(d, "game_level", 1))))

func _min_level(a, b = null) -> int:
	if b == null:
		return _level(a)
	return min(_level(a), _level(b))

func _min_level_in_bodies(bodies: Array, predicate: Callable = Callable()) -> int:
	var best := 999999
	var found := false
	for body in bodies:
		var d = _data(body)
		if predicate.is_valid() and not bool(predicate.call(d)):
			continue
		found = true
		best = min(best, _level(d))
	return best if found else 0

func _count_level_at_least(bodies: Array, level: int, predicate: Callable = Callable()) -> int:
	var count := 0
	for body in bodies:
		var d = _data(body)
		if predicate.is_valid() and not bool(predicate.call(d)):
			continue
		if _level(d) >= level:
			count += 1
	return count

func _prune_time_window(key: String, seconds: float) -> Array:
	var now := float(Time.get_ticks_msec()) / 1000.0
	var arr: Array = local_events.get(key, []) if local_events.get(key, []) is Array else []
	var kept: Array = []
	for value in arr:
		if now - float(value) <= seconds:
			kept.append(float(value))
	kept.append(now)
	local_events[key] = kept
	return kept

func _canonical_lineage_name(value: String) -> String:
	var clean := str(value).strip_edges().to_lower().replace("_", " ").replace("-", " ")
	while clean.contains("  "):
		clean = clean.replace("  ", " ")
	var solar := ["mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune"]
	for planet_name in solar:
		if clean == planet_name or clean.contains(" " + planet_name + " ") or clean.begins_with(planet_name + " ") or clean.ends_with(" " + planet_name) or clean.contains(planet_name):
			return planet_name
	return clean.replace(" ", "_")


func _lineage_names(d) -> Array[String]:
	var names: Array[String] = []
	if d == null:
		return names
	var raw: Variant = _read(d, "lineage_names", [])
	if raw is Array:
		for value in raw:
			var n := _canonical_lineage_name(str(value))
			if not n.is_empty() and not names.has(n):
				names.append(n)
	var self_name := _canonical_lineage_name(_name(d))
	if not self_name.is_empty() and not names.has(self_name):
		names.append(self_name)
	return names


func _normalize_lineage_category(value: Variant) -> String:
	var category := str(value).strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	match category:
		"natural_satellite", "satellites", "moons":
			return "moon"
		"exoplanet", "dwarf_planet", "ringed_planet":
			return "planet"
	return category


func _lineage_categories(d) -> Array[String]:
	var categories: Array[String] = []
	if d == null:
		return categories
	var raw: Variant = _read(d, "lineage_categories", [])
	if raw is Array:
		for value in raw:
			var category := _normalize_lineage_category(value)
			if category.is_empty():
				continue
			categories.append(category)
	return categories


func _lineage_result_key(d) -> String:
	var id := str(_read(d, "instance_id", "")).strip_edges().to_lower()
	if not id.is_empty():
		return id
	var names := _lineage_names(d)
	if not names.is_empty():
		names.sort()
		return "moon_planet_%s" % "_".join(names)
	return "moon_planet_%s" % str(Time.get_ticks_usec())


func _lineage_source_categories(d) -> Array[String]:
	var categories := _lineage_categories(d)
	if categories.size() <= 1:
		return categories

	# Older collision snapshots accidentally appended the evolved result category
	# after the creator categories. A moon+moon merge that became a planet could
	# therefore look like [moon, moon, planet] and never unlock this achievement.
	# Strip only that final result category; original planet + moon remains
	# [planet, moon], so it still does NOT count.
	var final_category := _normalize_lineage_category(_category(d))
	var last_category := _normalize_lineage_category(categories[categories.size() - 1])
	if final_category == "planet" and last_category == "planet":
		categories.remove_at(categories.size() - 1)
	return categories


func _lineage_is_only_satellites(d) -> bool:
	if d == null:
		return false
	var categories := _lineage_source_categories(d)
	if categories.is_empty():
		# Old saves/snapshots may not have lineage_categories. In that case,
		# do not guess from the final body, because a moon + planet merge would
		# incorrectly look like a planet-sized moon merge.
		return false
	if categories.size() < 2:
		return false
	for category in categories:
		if not (category == "moon" or category == "satellite"):
			return false
	return true


func _lineage_level_for(levels: Dictionary, wanted_name: String) -> int:
	var wanted := _canonical_lineage_name(wanted_name)
	if levels.has(wanted):
		return _safe_int(levels.get(wanted, 1))
	for raw_key in levels.keys():
		var key := _canonical_lineage_name(str(raw_key))
		if key == wanted:
			return _safe_int(levels.get(raw_key, 1))
	return 0


func _lineage_min_level(d, wanted: Array) -> int:
	var levels: Dictionary = _read(d, "lineage_levels", {}) if _read(d, "lineage_levels", {}) is Dictionary else {}
	var best := 999999
	for name in wanted:
		var level := _lineage_level_for(levels, str(name))
		if level <= 0:
			return 0
		best = min(best, level)
	return best if best < 999999 else 0


func _all_moons_cleared_payload(ad, bd, sd) -> Dictionary:
	for source in [sd, ad, bd]:
		var direct: Variant = _read(source, "all_moons_cleared", null)
		if direct is Dictionary and not direct.is_empty():
			return direct
		direct = _read(source, "achievement_all_moons_cleared", null)
		if direct is Dictionary and not direct.is_empty():
			return direct
		var metadata: Variant = _read(source, "metadata", {})
		if metadata is Dictionary:
			direct = metadata.get("achievement_all_moons_cleared", null)
			if direct is Dictionary and not direct.is_empty():
				return direct
	return {}

func _check_planet_lineage_achievements(sd) -> void:
	if sd == null:
		return
	var names := _lineage_names(sd)
	var solar := ["mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune"]
	var has_all_solar := true
	for n in solar:
		if not names.has(n): has_all_solar = false
	if has_all_solar:
		_set_level_stage("how_did_we_get_here", max(_lineage_min_level(sd, solar), 1), {"lineage": names}, "collision_lineage")
	var initials := {"e": 0, "m": 0, "c": 0}
	var min_level := 999999
	for n in names:
		var initial := n.substr(0, 1).to_lower()
		if initials.has(initial):
			initials[initial] = _safe_int(initials[initial]) + 1
			var levels: Dictionary = _read(sd, "lineage_levels", {}) if _read(sd, "lineage_levels", {}) is Dictionary else {}
			var lineage_level := _lineage_level_for(levels, n)
			min_level = min(min_level, max(lineage_level, 1))
	if _safe_int(initials.get("e", 0)) >= 1 and _safe_int(initials.get("m", 0)) >= 1 and _safe_int(initials.get("c", 0)) >= 2:
		_set_level_stage("e_mc2", max(min_level if min_level < 999999 else 1, 1), {"lineage": names}, "collision_lineage")

func _check_star_lineage_achievements(sd) -> void:
	if sd == null:
		return
	var names := _lineage_names(sd)
	var required_colors := _all_inclusive_required_star_colors()
	var color_levels := _lineage_star_color_levels(sd)
	var found_colors := _lineage_star_colors(sd)
	var min_level := 999999
	for color in required_colors:
		if not found_colors.has(color):
			return
		min_level = min(min_level, max(_safe_int(color_levels.get(color, 1)), 1))
	_set_level_stage("all_inclusive", max(min_level if min_level < 999999 else 1, 1), {"lineage": names, "colors": found_colors}, "collision_lineage")


func _build_signature(cards: Array) -> String:
	var chunks: Array[String] = []
	for id in unlocked_ids.keys():
		chunks.append(str(id))
	chunks.sort()
	chunks.append("cards=%d" % cards.size())
	chunks.append("events=%s" % str(local_events))
	return "|".join(chunks)

func _get_cards() -> Array:
	var cache := get_node_or_null("/root/PlanetCardsCache")
	if cache != null:
		for method in ["get_all_cards", "get_cards", "cards"]:
			if cache.has_method(method):
				var cards: Variant = cache.call(method)
				if cards is Array:
					return cards
	if not _cards_cache.is_empty():
		return _cards_cache
	return []

func _request_backend(path: String, method: HTTPClient.Method, body: Dictionary) -> Dictionary:
	if not backend_sync_enabled:
		return {"success": false, "error": "BACKEND_SYNC_DISABLED"}
	var token := await _get_fresh_id_token()
	if token.strip_edges() == "":
		return {"success": false, "error": "MISSING_ID_TOKEN"}

	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = DEFAULT_REQUEST_TIMEOUT_SEC

	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]

	var payload := ""
	if method != HTTPClient.METHOD_GET and method != HTTPClient.METHOD_DELETE:
		payload = JSON.stringify(body)

	var err := req.request(_backend_url(path), headers, method, payload)
	if err != OK:
		req.queue_free()
		return {"success": false, "error": "REQUEST_FAILED", "code": err}

	var response: Array = await req.request_completed
	req.queue_free()

	var result_code := _safe_int(response[0])
	var status_code := _safe_int(response[1])
	var text := (response[3] as PackedByteArray).get_string_from_utf8()

	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {"success": false, "error": "HTTP_REQUEST_FAILED", "result_code": result_code, "status": status_code}

	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error != OK:
		if status_code == 404:
			backend_sync_enabled = false
		return {"success": false, "error": "INVALID_RESPONSE", "raw": text, "status": status_code}

	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		return {"success": false, "error": "INVALID_RESPONSE", "raw": text, "status": status_code}

	if status_code >= 200 and status_code < 300:
		return parsed

	if status_code == 404:
		backend_sync_enabled = false

	return {"success": false, "error": str(parsed.get("error", "BACKEND_FAILED")), "raw": parsed, "status": status_code}

func _backend_url(path: String) -> String:
	var clean := path.strip_edges()
	if clean.begins_with("http://") or clean.begins_with("https://"):
		return clean
	if not clean.begins_with("/"):
		clean = "/" + clean
	return BACKEND_BASE_URL + clean

func _get_fresh_id_token() -> String:
	if not is_instance_valid(FirebaseAuth):
		return ""
	if FirebaseAuth.has_method("get_fresh_id_token"):
		return str(await FirebaseAuth.get_fresh_id_token(false))
	if FirebaseAuth.has_method("get_id_token"):
		return str(FirebaseAuth.get_id_token())
	if "id_token" in FirebaseAuth:
		return str(FirebaseAuth.id_token)
	return ""

func _default_local_events() -> Dictionary:
	var events := {
		"body_added": 0,
		"planet_collision": 0,
		"star_collision": 0,
		"earth_collisions": 0,
		"star_collision_window": 0,
		"rapid_star_collision_times": [],
		"black_hole_star_swallow_times": [],
		"generated_card_ids": {},
	}
	for id in STAGED_ACHIEVEMENTS.keys():
		var event_key := str(_achievement_rule(str(id)).get("event", ""))
		if not event_key.is_empty() and not events.has(event_key):
			events[event_key] = 0
	return events

func _merge_event_dictionaries(base: Dictionary, incoming: Dictionary) -> Dictionary:
	# Progress is monotonic for achievements, so never let older backend data
	# decrease local counters/sets. This protects app restarts and late syncs.
	for key in incoming.keys():
		var clean_key := str(key)
		var incoming_value: Variant = incoming[key]
		var current_value: Variant = base.get(clean_key, null)
		if incoming_value is Dictionary:
			var merged_dict: Dictionary = current_value.duplicate(true) if current_value is Dictionary else {}
			for dict_key in incoming_value.keys():
				merged_dict[dict_key] = incoming_value[dict_key]
			base[clean_key] = merged_dict
		elif incoming_value is Array:
			var merged_array: Array = current_value.duplicate(true) if current_value is Array else []
			for item in incoming_value:
				if not merged_array.has(item):
					merged_array.append(item)
			base[clean_key] = merged_array
		elif incoming_value is int or incoming_value is float or incoming_value is bool or incoming_value is String or incoming_value is StringName:
			base[clean_key] = max(_safe_int(current_value), _safe_int(incoming_value))
		else:
			base[clean_key] = incoming_value
	return base



func _first_dictionary_value(source: Dictionary, keys: Array) -> Variant:
	for key in keys:
		if source.has(str(key)) and source[str(key)] is Dictionary:
			return source[str(key)]
	return {}


func _backend_id_from_key_or_item(fallback_key: String, item: Dictionary) -> String:
	var raw_id := str(item.get("id", item.get("achievementId", item.get("achievement_id", fallback_key)))).strip_edges()
	var id := CATALOG.normalize_id(raw_id)
	if not id.is_empty() and not CATALOG.get_by_id(id).is_empty():
		return id

	var raw_number: Variant = item.get("number", item.get("achievementNumber", item.get("achievement_number", fallback_key)))
	var number := _safe_int(raw_number, 0)
	if number > 0:
		var achievement := CATALOG.get_by_number(number)
		if not achievement.is_empty():
			return CATALOG.normalize_id(str(achievement.get("id", "")))

	if fallback_key.is_valid_int():
		var achievement_from_key := CATALOG.get_by_number(fallback_key.to_int())
		if not achievement_from_key.is_empty():
			return CATALOG.normalize_id(str(achievement_from_key.get("id", "")))

	return ""


func _merge_backend_state_collection(collection: Variant, target_ids: Dictionary, target_payloads: Dictionary) -> int:
	var merged_count := 0
	if collection == null:
		return 0

	if collection is Array:
		for raw_item in collection:
			var item: Dictionary = {}
			var fallback_key := ""
			if raw_item is Dictionary:
				item = raw_item
			else:
				fallback_key = str(raw_item)
				item = {"id": fallback_key, "unlocked": true}
			if _merge_single_backend_state_item(fallback_key, item, target_ids, target_payloads):
				merged_count += 1
		return merged_count

	if collection is Dictionary:
		for key in collection.keys():
			var fallback_key := str(key)
			var value: Variant = collection[key]
			var item: Dictionary = {}
			if value is Dictionary:
				item = value.duplicate(true)
				if not item.has("id") and not item.has("achievementId") and not item.has("achievement_id") and not item.has("number") and not item.has("achievementNumber") and not item.has("achievement_number"):
					item["id"] = fallback_key
			else:
				item = {"id": fallback_key, "unlocked": bool(value)}
			if _merge_single_backend_state_item(fallback_key, item, target_ids, target_payloads):
				merged_count += 1
	return merged_count


func _merge_single_backend_state_item(fallback_key: String, item: Dictionary, target_ids: Dictionary, target_payloads: Dictionary) -> bool:
	var id := _backend_id_from_key_or_item(fallback_key, item)
	if id.is_empty():
		return false

	var data_payload: Dictionary = item.get("data", item.get("payload", {})) if item.get("data", item.get("payload", {})) is Dictionary else {}
	if ["life_beyond_earth", "the_chosen_one", "toxic_traits", "the_pull_of_the_universe"].has(id) and not data_payload.has("is_exoplanet"):
		data_payload["is_exoplanet"] = true
	var tier := _normalize_display_tier(id, _safe_int(item.get("tier", item.get("stage", data_payload.get("tier", 0)))))
	var count := _safe_int(item.get("count", data_payload.get("count", 0)))
	if tier <= TIER_NONE and _is_staged_achievement(id) and count > 0:
		tier = _tier_for_staged_count(id, count)
	var unlocked_flag := bool(item.get("unlocked", item.get("isUnlocked", item.get("is_unlocked", false)))) or tier > TIER_NONE
	if not unlocked_flag:
		return false
	if tier <= TIER_NONE:
		tier = _default_tier_for_id(id)

	var achievement := CATALOG.get_by_id(id)
	_merge_backend_unlock(target_ids, target_payloads, id, {
		"number": _safe_int(achievement.get("number", item.get("number", item.get("achievementNumber", 0)))),
		"unlocked": true,
		"tier": tier,
		"unlockedAtMs": _safe_int(item.get("unlockedAtMs", item.get("unlocked_at_ms", item.get("updatedAtMs", 0)))),
		"count": max(count, 1),
		"data": data_payload,
		"source": str(item.get("source", "backend"))
	})
	return true


func _apply_progress_state_to_unlocks(source: String = "state") -> bool:
	var changed := false
	for id in STAGED_ACHIEVEMENTS.keys():
		var clean_id := CATALOG.normalize_id(str(id))
		var info := _staged_progress_for(clean_id, unlocked_payloads.get(clean_id, {}) if unlocked_payloads.get(clean_id, {}) is Dictionary else {})
		var tier := _normalize_display_tier(clean_id, _safe_int(info.get("tier", TIER_NONE)))
		if tier <= TIER_NONE:
			continue
		var achievement := CATALOG.get_by_id(clean_id)
		if achievement.is_empty():
			continue
		var current_payload: Dictionary = unlocked_payloads.get(clean_id, {}) if unlocked_payloads.get(clean_id, {}) is Dictionary else {}
		var current_tier := _normalize_display_tier(clean_id, _safe_int(current_payload.get("tier", TIER_NONE)))
		if unlocked_ids.has(clean_id) and current_tier >= tier:
			continue
		var existing_data: Dictionary = current_payload.get("data", {}) if current_payload.get("data", {}) is Dictionary else {}
		if ["life_beyond_earth", "the_chosen_one", "toxic_traits", "the_pull_of_the_universe"].has(clean_id) and not existing_data.has("is_exoplanet"):
			existing_data["is_exoplanet"] = true
		existing_data["count"] = _safe_int(info.get("current_count", existing_data.get("count", 1)))
		existing_data["tier"] = tier
		unlocked_ids[clean_id] = true
		unlocked_payloads[clean_id] = {
			"number": _safe_int(achievement.get("number", 0)),
			"unlocked": true,
			"tier": tier,
			"unlockedAtMs": _safe_int(current_payload.get("unlockedAtMs", Time.get_unix_time_from_system() * 1000.0)),
			"count": _safe_int(info.get("current_count", existing_data.get("count", 1))),
			"data": existing_data,
			"source": source
		}
		changed = true
	return changed


func _reset_runtime_state_for_account() -> void:
	unlocked_ids.clear()
	unlocked_payloads.clear()
	shown_unlock_toasts.clear()
	progress.clear()
	timers.clear()
	local_events = _default_local_events()
	_last_results.clear()
	_last_signature = ""
	_cards_cache.clear()
	_active_generation_ids.clear()
	_active_generation_count = 0
	_runtime_snapshot_accum = 0.0
	_last_runtime_snapshot_signature = ""
	_backend_save_queued = false
	_backend_save_running = false


func clear_runtime_for_logout() -> void:
	_login_backend_reload_running = false
	_is_loading = false
	_current_account_key = "anonymous"
	_reset_runtime_state_for_account()
	refresh(true)


func _get_account_key() -> String:
	var uid := ""
	if is_instance_valid(FirebaseAuth):
		if "uid" in FirebaseAuth:
			uid = str(FirebaseAuth.uid).strip_edges()
		if uid.is_empty() and "local_id" in FirebaseAuth:
			uid = str(FirebaseAuth.local_id).strip_edges()
		if uid.is_empty() and "user_id" in FirebaseAuth:
			uid = str(FirebaseAuth.user_id).strip_edges()
		if uid.is_empty() and "email" in FirebaseAuth:
			uid = str(FirebaseAuth.email).strip_edges().to_lower()

	if uid.is_empty():
		uid = "anonymous"

	uid = CATALOG.normalize_id(uid)
	if uid.is_empty():
		uid = "anonymous"

	return uid


func _local_save_path() -> String:
	return "user://unilearn_achievements_%s.cfg" % _get_account_key()

func _load_local() -> void:
	_reset_runtime_state_for_account()
	shown_unlock_toasts.clear()

	var config := ConfigFile.new()
	var err := config.load(_local_save_path())
	if err != OK:
		return

	var ids: Variant = config.get_value("achievements", "unlocked_ids", [])
	if ids is Array:
		for value in ids:
			var id := CATALOG.normalize_id(str(value))
			if id == "":
				continue
			unlocked_ids[id] = true
			var achievement := CATALOG.get_by_id(id)
			unlocked_payloads[id] = {
				"number": _safe_int(achievement.get("number", 0)),
				"unlocked": true,
				"tier": _safe_int(config.get_value("achievement_%s" % id, "tier", TIER_BRONZE)),
				"unlockedAtMs": _safe_int(config.get_value("achievement_%s" % id, "unlockedAtMs", 0)),
				"data": config.get_value("achievement_%s" % id, "data", {}),
				"source": str(config.get_value("achievement_%s" % id, "source", "local"))
			}

	var shown_values: Variant = config.get_value("toasts", "shown_unlock_keys", [])
	if shown_values is Array:
		for value in shown_values:
			var key := str(value).strip_edges()
			if not key.is_empty():
				shown_unlock_toasts[key] = true

	var events: Variant = config.get_value("events", "values", {})
	if events is Dictionary:
		for key in events.keys():
			var event_value: Variant = events[key]
			if event_value is Dictionary:
				local_events[str(key)] = event_value
			else:
				local_events[str(key)] = _safe_int(event_value)

	var rebuilt_from_progress := _apply_progress_state_to_unlocks("local_state")
	_mark_loaded_unlocks_as_seen()
	if rebuilt_from_progress:
		_save_local(false)

func _save_local(sync_progress: bool = true) -> void:
	var config := ConfigFile.new()
	config.set_value("achievements", "unlocked_ids", unlocked_ids.keys())
	config.set_value("events", "values", local_events)
	config.set_value("toasts", "shown_unlock_keys", shown_unlock_toasts.keys())
	for id in unlocked_payloads.keys():
		var raw_payload: Variant = unlocked_payloads.get(str(id), {})
		if not (raw_payload is Dictionary):
			continue
		var payload: Dictionary = raw_payload
		config.set_value("achievement_%s" % id, "unlockedAtMs", _safe_int(payload.get("unlockedAtMs", 0)))
		config.set_value("achievement_%s" % id, "tier", _safe_int(payload.get("tier", TIER_BRONZE)))
		config.set_value("achievement_%s" % id, "data", payload.get("data", payload.get("payload", {})))
		config.set_value("achievement_%s" % id, "source", str(payload.get("source", "local")))
	var err := config.save(_local_save_path())
	if err != OK:
		push_warning("Could not save achievements locally. Error: %s" % str(err))
	if sync_progress and backend_sync_enabled:
		_queue_backend_full_save()

func _queue_backend_full_save() -> void:
	if not backend_sync_enabled:
		return
	_backend_save_queued = true
	if _backend_save_running:
		return
	call_deferred("_flush_backend_full_save")


func _flush_backend_full_save() -> void:
	if _backend_save_running:
		return
	_backend_save_running = true
	while _backend_save_queued and backend_sync_enabled:
		_backend_save_queued = false
		var result := await sync_all_to_backend()
		if not bool(result.get("success", false)) and str(result.get("error", "")) != "BACKEND_SYNC_DISABLED":
			if _safe_int(result.get("status", 0)) != 404:
				push_warning("Achievement full backend save failed: %s" % str(result))
	_backend_save_running = false


func _merge_backend_unlock(target_ids: Dictionary, target_payloads: Dictionary, id: String, incoming_payload: Dictionary) -> void:
	id = CATALOG.normalize_id(id)
	if id.is_empty():
		return
	var achievement := CATALOG.get_by_id(id)
	if achievement.is_empty():
		return
	var incoming := incoming_payload.duplicate(true)
	incoming["number"] = _safe_int(incoming.get("number", achievement.get("number", 0)))
	incoming["unlocked"] = true
	incoming["tier"] = _normalize_display_tier(id, _safe_int(incoming.get("tier", _default_tier_for_id(id))))
	incoming["unlockedAtMs"] = _safe_int(incoming.get("unlockedAtMs", 0))
	if not incoming.has("data"):
		incoming["data"] = incoming.get("payload", {})
	if not incoming.has("source"):
		incoming["source"] = "backend"

	var raw_target_payload: Variant = target_payloads.get(id, {})
	if raw_target_payload is Dictionary:
		var current: Dictionary = raw_target_payload
		var current_tier := _normalize_display_tier(id, _safe_int(current.get("tier", _default_tier_for_id(id))))
		var incoming_tier := _normalize_display_tier(id, _safe_int(incoming.get("tier", _default_tier_for_id(id))))
		var current_time := _safe_int(current.get("unlockedAtMs", 0))
		var incoming_time := _safe_int(incoming.get("unlockedAtMs", 0))
		# Prefer the highest tier. If equal, keep the newest payload.
		if current_tier > incoming_tier or (current_tier == incoming_tier and current_time >= incoming_time):
			target_ids[id] = true
			return

	target_ids[id] = true
	target_payloads[id] = incoming


func _data(value):
	if value == null:
		return null
	if value is Dictionary:
		if value.has("data"):
			return value.get("data")
		return value
	if value is Object:
		var data_value = _read(value, "data", null)
		if data_value != null:
			return data_value
	return value

func _source(value):
	var d = _data(value)
	var source = _read(d, "source_planet_data", null)
	if source != null:
		return source
	return d

func _read(source, key: String, fallback = null):
	if source == null:
		return fallback
	if source is Dictionary:
		return source.get(key, fallback)
	if source is Object:
		var value = source.get(key)
		return fallback if value == null else value
	return fallback

func _body_payload(d) -> Dictionary:
	var source = _source(d)
	return {
		"body": _name(d),
		"source_name": str(_read(source, "name", "")),
		"instance_id": str(_read(source, "instance_id", _read(d, "instance_id", ""))),
		"category": _category(d),
		"preset": _preset(d),
		"archetype": _archetype(d),
		"is_exoplanet": _is_exoplanet(d)
	}

func _name(d) -> String:
	var display := str(_read(d, "display_name", "")).strip_edges()
	if not display.is_empty() and display.to_lower() != "unknown body":
		return display
	var source_name := str(_read(_source(d), "name", "")).strip_edges()
	if not source_name.is_empty():
		return source_name
	return "Unknown"

func _category(d) -> String:
	return str(_read(_source(d), "object_category", _read(d, "object_category", ""))).strip_edges().to_lower().replace(" ", "_")

func _preset(d) -> String:
	return str(_read(_source(d), "planet_preset", _read(d, "planet_preset", ""))).strip_edges().to_lower().replace(" ", "_")

func _archetype(d) -> String:
	return str(_read(_source(d), "archetype_id", _read(d, "archetype_id", ""))).strip_edges().to_lower().replace(" ", "_")

func _scores(d) -> Dictionary:
	var result := {}
	var arr = _read(_source(d), "game_attribute_scores", [])
	if arr is Array:
		for item in arr:
			if not item is Dictionary:
				continue
			var key := _normalize_stat_key(str(item.get("title", item.get("name", item.get("id", "")))))
			result[key] = _safe_int(item.get("value", item.get("score", item.get("amount", 0))))
	return result

func _score_value(scores: Dictionary, key: String, fallback: int = 0) -> int:
	key = _normalize_stat_key(key)
	return _safe_int(scores.get(key, fallback))

func _stats_above_count(scores: Dictionary, threshold: int) -> int:
	var count := 0
	for stat_key in ["habitability", "magnetic_field", "atmosphere", "geology", "gravity", "radiation_safety"]:
		if _score_value(scores, stat_key) > threshold:
			count += 1
	return count

func _stat(d, key: String) -> int:
	return _score_value(_scores(d), key)

func _normalize_stat_key(value: String) -> String:
	var text := value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	if text.contains("habit"): return "habitability"
	if text.contains("magnet") or text.contains("field"): return "magnetic_field"
	if text.contains("atmos"): return "atmosphere"
	if text.contains("geolog") or text.contains("surface") or text.contains("volcan"): return "geology"
	if text.contains("grav"): return "gravity"
	if text.contains("radiation") or text.contains("safety"): return "radiation_safety"
	return text

func _is_planet(d) -> bool:
	var category := _category(d)
	var kind := _safe_int(_read(d, "body_kind", -1))
	return category in ["planet", "exoplanet", "dwarf_planet", "ringed_planet"] or kind in [1, 7, 14]

func _is_moon(d) -> bool:
	var category := _category(d)
	var kind := _safe_int(_read(d, "body_kind", -1))
	return category in ["moon", "satellite"] or kind in [2, 6]

func _is_star(d) -> bool:
	var category := _category(d)
	var kind := _safe_int(_read(d, "body_kind", -1))
	return category == "star" or kind == 3

func _is_black_hole(d) -> bool:
	return _category(d) == "black_hole" or (_category(d) == "singularity" and _preset(d) == "black_hole") or _preset(d) == "black_hole" or _archetype(d) == "black_hole" or _safe_int(_read(d, "body_kind", -1)) == 4

func _is_white_hole(d) -> bool:
	return _category(d) == "white_hole" or (_category(d) == "singularity" and _preset(d) == "white_hole") or _preset(d) == "white_hole" or _archetype(d) == "white_hole" or _safe_int(_read(d, "body_kind", -1)) == 8

func _is_brown_dwarf(d) -> bool:
	return _archetype(d) == "brown_dwarf" or _name(d).to_lower().contains("brown dwarf")

func _is_white_dwarf(d) -> bool:
	return _archetype(d) == "white_dwarf" or _name(d).to_lower().contains("white dwarf")

func _is_red_giant(d) -> bool:
	var text := "%s %s %s" % [_name(d), _archetype(d), _preset(d)]
	text = text.to_lower()
	return text.contains("red giant") or text.contains("red_supergiant") or text.contains("supergiant")

func _is_blue_star(d) -> bool:
	var text := "%s %s %s" % [_name(d), _archetype(d), _preset(d)]
	return text.to_lower().contains("blue") and _is_star(d)

func _is_exoplanet(d) -> bool:
	if d == null:
		return false
	if not _is_planet(d):
		return false
	if _is_star(d) or _is_moon(d):
		return false
	if _is_solar_system_body(d):
		return false
	var category := _category(d)
	if category == "exoplanet":
		return true
	var source = _source(d)
	if bool(_read(source, "is_exoplanet", false)):
		return true
	if bool(_read(source, "is_generated", false)):
		return true
	var id := str(_read(source, "instance_id", _read(d, "source_card_id", ""))).strip_edges().to_lower()
	return not id.is_empty() and not _is_solar_system_object(id) and not _is_solar_system_object(_name(d))

func _is_ringed_exoplanet(d) -> bool:
	return _is_exoplanet(d) and (_preset(d).contains("ringed") or _archetype(d).contains("ringed"))

func _is_gas_giant_exoplanet(d) -> bool:
	return _is_exoplanet(d) and (_preset(d).contains("gas") or _archetype(d).contains("gas_giant"))

func _is_ice(d) -> bool:
	return _preset(d).contains("ice") or _archetype(d).contains("ice")

func _is_lava(d) -> bool:
	return _preset(d).contains("lava") or _archetype(d).contains("lava")

func _is_solar_system_object(object_name: String) -> bool:
	var clean := object_name.strip_edges().to_lower().replace(" ", "_")
	return SOLAR_SYSTEM_NAMES.has(clean) or SOLAR_SYSTEM_NAMES.has(clean.replace("_", " "))

func _is_solar_system_body(d) -> bool:
	var source = _source(d)
	var names: Array[String] = [
		_name(d),
		str(_read(source, "name", "")),
		str(_read(source, "instance_id", "")),
		str(_read(d, "source_card_id", "")),
		str(_read(source, "parent_object", ""))
	]
	for value in names:
		if _is_solar_system_object(value):
			return true
	return false

func _is_unknown_solar_moon(d) -> bool:
	var object_name := _name(d).to_lower()
	return _is_moon(d) and object_name == "mimas"

func _jupiter_diameter(d) -> float:
	var source = _source(d)
	var best := 0.0

	best = max(best, _parse_jupiter_size_ratio(str(_read(source, "diameter_km", "")), false))
	best = max(best, _parse_jupiter_size_ratio(str(_read(source, "diameter", "")), false))
	best = max(best, _parse_jupiter_size_ratio(str(_read(source, "diameter_text", "")), false))
	best = max(best, _parse_jupiter_size_ratio(str(_read(source, "radius", "")), true))
	best = max(best, _parse_jupiter_size_ratio(str(_read(source, "radius_text", "")), true))

	# Fallback for cards that only keep the displayed measurement inside data_cards.
	best = max(best, _parse_jupiter_size_ratio(_data_card_measurement(source, ["diameter"]), false))
	best = max(best, _parse_jupiter_size_ratio(_data_card_measurement(source, ["radius"]), true))

	return best

func _data_card_measurement(source, keywords: Array) -> String:
	var cards = _read(source, "data_cards", [])
	if not cards is Array:
		return ""

	for card in cards:
		var title := str(_read(card, "title", _read(card, "label", ""))).strip_edges().to_lower()
		if title.is_empty():
			continue

		for keyword in keywords:
			if title.contains(keyword):
				return str(_read(card, "value", ""))

	return ""

func _parse_jupiter_size_ratio(text: String, value_is_radius: bool = false) -> float:
	text = _normalize_numeric_text(text)
	if text.is_empty():
		return 0.0

	var value := _parse_first_number(text)
	if value <= 0.0:
		return 0.0

	# A ratio expressed in Jupiter radii/diameters has the same multiplier either way.
	# Example: 3 Jupiter radii also means 3 Jupiter diameters compared as a size ratio.
	if _mentions_jupiter_size_unit(text):
		return value

	# Fallback for kilometer values. If the source field/card says radius, double it first.
	# Jupiter's mean diameter is about 139,820 km.
	if text.contains("km") or text.contains("kilometer") or text.contains("kilometre"):
		var diameter_km := value * 2.0 if value_is_radius or _looks_like_radius_measurement(text) else value
		return diameter_km / 139820.0

	return 0.0

func _mentions_jupiter_size_unit(text: String) -> bool:
	return text.contains("jupiter") or text.contains("jovian") or text.contains("rj") or text.contains("r_j") or text.contains("r-j")

func _looks_like_radius_measurement(text: String) -> bool:
	return (text.contains("radius") or text.contains("radii")) and not text.contains("diameter")

func _normalize_numeric_text(value: String) -> String:
	var text := value.strip_edges().to_lower()
	if text.is_empty():
		return ""

	text = text.replace("approximately", "~")
	text = text.replace("approx.", "~")
	text = text.replace("approx", "~")
	text = text.replace("around", "~")
	text = text.replace("roughly", "~")
	text = text.replace("about", "~")
	text = text.replace("estimated", "~")
	text = text.replace("est.", "~")
	text = text.replace("est", "~")

	text = text.replace("×", "x")
	text = text.replace("⁻", "-")
	text = text.replace("⁰", "0")
	text = text.replace("¹", "1")
	text = text.replace("²", "2")
	text = text.replace("³", "3")
	text = text.replace("⁴", "4")
	text = text.replace("⁵", "5")
	text = text.replace("⁶", "6")
	text = text.replace("⁷", "7")
	text = text.replace("⁸", "8")
	text = text.replace("⁹", "9")

	text = text.replace("jupiter's", "jupiter")
	text = text.replace("jupiters", "jupiter")
	text = text.replace("jupiter-radii", "jupiter radii")
	text = text.replace("jupiter-radius", "jupiter radius")
	text = text.replace("jupiter-diameter", "jupiter diameter")
	text = text.replace("r j", "rj")
	text = text.replace("r_jup", "rj")
	text = text.replace("r_jupiter", "rj")
	text = text.replace("jupiter radii", "jupiter radius")
	text = text.replace("jupiter diameters", "jupiter diameter")
	text = text.replace("jovian radii", "jovian radius")
	text = text.replace("jovian diameters", "jovian diameter")

	return text.strip_edges()

func _parse_first_number(text: String) -> float:
	var scientific := _parse_scientific_number(text)
	if scientific > 0.0:
		return scientific

	var regex := RegEx.new()
	regex.compile("[-+]?[0-9][0-9,. ]*")
	var m := regex.search(text)
	if m == null:
		return 0.0

	return _number_token_to_float(m.get_string())

func _parse_scientific_number(text: String) -> float:
	var sci := RegEx.new()
	sci.compile("([-+]?[0-9][0-9,. ]*)\\s*(?:x|\\*)\\s*10\\s*\\^?\\s*([-+]?\\d+)")
	var m := sci.search(text)
	if m != null:
		var mantissa := _number_token_to_float(m.get_string(1))
		var exponent := int(m.get_string(2))
		if mantissa != 0.0:
			return mantissa * pow(10.0, float(exponent))

	var e_sci := RegEx.new()
	e_sci.compile("([-+]?[0-9][0-9,. ]*)\\s*e\\s*([-+]?\\d+)")
	m = e_sci.search(text)
	if m != null:
		var mantissa := _number_token_to_float(m.get_string(1))
		var exponent := int(m.get_string(2))
		if mantissa != 0.0:
			return mantissa * pow(10.0, float(exponent))

	return 0.0

func _number_token_to_float(token: String) -> float:
	var text := token.strip_edges().replace(" ", "")
	if text.is_empty():
		return 0.0

	var comma_count := text.split(",").size() - 1
	var dot_count := text.split(".").size() - 1

	if comma_count > 1 and dot_count == 0:
		text = text.replace(",", "")
	elif dot_count > 1 and comma_count == 0:
		text = text.replace(".", "")
	elif comma_count > 0 and dot_count == 1 and text.find(",") < text.find("."):
		# 1,234.56
		text = text.replace(",", "")
	elif dot_count > 0 and comma_count == 1 and text.rfind(".") < text.find(","):
		# 1.234,56
		text = text.replace(".", "").replace(",", ".")
	elif comma_count == 1 and dot_count == 0:
		var comma_parts := text.split(",")
		if comma_parts.size() == 2 and comma_parts[1].length() == 3 and comma_parts[0].length() <= 3:
			text = text.replace(",", "")
		else:
			text = text.replace(",", ".")
	elif dot_count == 1 and comma_count == 0:
		var dot_parts := text.split(".")
		if dot_parts.size() == 2 and dot_parts[1].length() == 3 and dot_parts[0].length() <= 3:
			text = text.replace(".", "")

	return float(text)


func _planet_was_orbiting_another_star(planet, collided_star) -> bool:
	if planet == null or collided_star == null:
		return false
	var parent_id := str(_read(planet, "orbit_parent_id", "")).strip_edges()
	var collided_id := str(_read(collided_star, "instance_id", "")).strip_edges()
	if parent_id.is_empty() or collided_id.is_empty() or parent_id == collided_id:
		return false
	var parent_kind := int(_read(planet, "orbit_parent_body_kind", -1))
	# SimulationPlanetData.BodyKind.STAR is 3 in this project. Keep black/white/galaxy
	# out of Planet Thief: the achievement wording says another star, not any anchor.
	return parent_kind == 3

func _similar(a: float, b: float, tolerance: float) -> bool:
	return abs(a - b) <= max(abs(a), abs(b)) * tolerance

func _one_small_one_big(a, b) -> bool:
	# This achievement is about the collision pair, not the final evolved body.
	# Generated stars often arrive with nice text fields but weak runtime mass values,
	# so use several signals: explicit dwarf/giant names, parsed stellar sizes,
	# runtime radius, and runtime mass.
	var class_a := _stellar_size_class(a)
	var class_b := _stellar_size_class(b)
	if (class_a == "small" and class_b == "big") or (class_a == "big" and class_b == "small"):
		return true

	var ra := _stellar_radius_score(a)
	var rb := _stellar_radius_score(b)
	if ra > 0.0 and rb > 0.0 and max(ra, rb) / max(min(ra, rb), 0.001) >= 6.0:
		return true

	var ma := _stellar_mass_score(a)
	var mb := _stellar_mass_score(b)
	if ma > 0.0 and mb > 0.0 and max(ma, mb) / max(min(ma, mb), 0.001) >= 8.0:
		return true

	return false

func _all_inclusive_required_star_colors() -> Array[String]:
	# Game-side star colors. "Blue-white" stars count as blue; brown dwarfs count as brown
	# because the simulator treats them as star-category failed stars.
	return ["red", "orange", "yellow", "white", "blue", "brown"]

func _lineage_star_colors(d) -> Array[String]:
	var result: Array[String] = []
	var raw: Variant = _read(d, "lineage_star_colors", [])
	if raw is Array:
		for value in raw:
			var color := _normalize_star_color_tag(str(value))
			if not color.is_empty() and not result.has(color):
				result.append(color)
	# Older snapshots did not store star colors. Fallback to names and current body text.
	for n in _lineage_names(d):
		for color in _star_color_tags_from_text(n):
			if not result.has(color):
				result.append(color)
	for color in _star_color_tags_from_body(d):
		if not result.has(color):
			result.append(color)
	return result

func _lineage_star_color_levels(d) -> Dictionary:
	var result := {}
	var raw: Variant = _read(d, "lineage_star_color_levels", {})
	if raw is Dictionary:
		for key in raw.keys():
			var color := _normalize_star_color_tag(str(key))
			if color.is_empty():
				continue
			result[color] = max(_safe_int(result.get(color, 1)), _safe_int(raw[key]))
	# Fallback for old snapshots: infer from lineage names and their stored levels.
	var levels: Dictionary = _read(d, "lineage_levels", {}) if _read(d, "lineage_levels", {}) is Dictionary else {}
	for n in _lineage_names(d):
		var level := max(_lineage_level_for(levels, n), 1)
		for color in _star_color_tags_from_text(n):
			result[color] = max(_safe_int(result.get(color, 1)), level)
	for color in _star_color_tags_from_body(d):
		result[color] = max(_safe_int(result.get(color, 1)), _level(d))
	return result

func _normalize_star_color_tag(value: String) -> String:
	var color := value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	match color:
		"blue_white", "bluewhite", "blueish", "bluish":
			return "blue"
		"yellow_white", "yellowish":
			return "yellow"
		"reddish":
			return "red"
		"orangish":
			return "orange"
		"whitish":
			return "white"
		"brownish":
			return "brown"
	return color if color in ["red", "orange", "yellow", "white", "blue", "brown"] else ""

func _star_color_tags_from_body(d) -> Array[String]:
	var source = _source(d)
	var text := "%s %s %s %s %s %s" % [
		_name(d),
		str(_read(source, "name", "")),
		str(_read(source, "subtitle", _read(d, "subtitle", ""))),
		str(_read(source, "archetype_id", _read(d, "archetype_id", ""))),
		str(_read(source, "planet_preset", _read(d, "planet_preset", ""))),
		str(_read(source, "visual_signature", _read(d, "visual_signature", "")))
	]
	var result := _star_color_tags_from_text(text)
	if result.is_empty():
		var custom: Variant = _read(source, "custom_colors", _read(d, "custom_colors", []))
		var inferred := _star_color_from_custom_colors(custom)
		if not inferred.is_empty():
			result.append(inferred)
	if result.is_empty() and _is_star(d):
		result.append("yellow")
	return result

func _star_color_tags_from_text(value: String) -> Array[String]:
	var result: Array[String] = []
	var text := value.strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	if text.contains("brown_dwarf") or text.contains("brown"):
		result.append("brown")
	if text.contains("red_supergiant") or text.contains("red_giant") or text.contains("red_dwarf") or text.contains("red"):
		result.append("red")
	if text.contains("orange"):
		result.append("orange")
	if text.contains("yellow") or text.contains("solar") or text.contains("sun"):
		result.append("yellow")
	if text.contains("blue_white") or text.contains("blue"):
		result.append("blue")
	if text.contains("white_dwarf") or text.contains("white"):
		result.append("white")
	return result

func _star_color_from_custom_colors(raw: Variant) -> String:
	if not raw is Array or raw.is_empty():
		return ""
	var best := Color.TRANSPARENT
	var best_score := -INF
	for item in raw:
		var color := Color.TRANSPARENT
		if item is Color:
			color = item
		else:
			var text := str(item).strip_edges()
			if text.is_empty():
				continue
			if not text.begins_with("#"):
				text = "#" + text
			color = Color(text)
		var score := color.s * 1.9 + color.v * 0.45
		if color.v < 0.08:
			score -= 1.2
		if score > best_score:
			best_score = score
			best = color
	if best_score == -INF:
		return ""
	if best.v < 0.22:
		return "brown"
	if best.s < 0.14 and best.v > 0.72:
		return "white"
	if best.h < 0.035 or best.h >= 0.92:
		return "red"
	if best.h < 0.105:
		return "orange"
	if best.h < 0.19:
		return "yellow"
	if best.h >= 0.50 and best.h <= 0.72:
		return "blue"
	if best.v > 0.80:
		return "white"
	return "yellow"

func _stellar_size_class(d) -> String:
	var source = _source(d)
	var text := "%s %s %s %s %s %s" % [
		_name(d),
		str(_read(source, "name", "")),
		str(_read(source, "subtitle", _read(d, "subtitle", ""))),
		str(_read(source, "archetype_id", _read(d, "archetype_id", ""))),
		str(_read(source, "planet_preset", _read(d, "planet_preset", ""))),
		str(_read(source, "visual_signature", _read(d, "visual_signature", "")))
	]
	text = text.to_lower().replace("-", "_").replace(" ", "_")
	if text.contains("supergiant") or text.contains("hypergiant") or text.contains("red_giant") or text.contains("giant_star"):
		return "big"
	if text.contains("white_dwarf") or text.contains("brown_dwarf") or text.contains("red_dwarf") or text.contains("dwarf"):
		return "small"
	return "normal"

func _stellar_radius_score(d) -> float:
	var source = _source(d)
	var best := 0.0
	best = max(best, float(_read(d, "radius_world", 0.0)))
	best = max(best, _parse_solar_size_ratio(str(_read(source, "diameter_km", _read(d, "diameter_km", ""))), false))
	best = max(best, _parse_solar_size_ratio(str(_read(source, "diameter", _read(d, "diameter", ""))), false))
	best = max(best, _parse_solar_size_ratio(str(_read(source, "diameter_text", _read(d, "diameter_text", ""))), false))
	best = max(best, _parse_solar_size_ratio(str(_read(source, "radius", _read(d, "radius", ""))), true))
	best = max(best, _parse_solar_size_ratio(str(_read(source, "radius_text", _read(d, "radius_text", ""))), true))
	best = max(best, _parse_solar_size_ratio(_data_card_measurement(source, ["radius"]), true))
	best = max(best, _parse_solar_size_ratio(_data_card_measurement(source, ["diameter"]), false))
	return best

func _stellar_mass_score(d) -> float:
	var source = _source(d)
	var runtime_mass := float(_read(d, "mass", 0.0))
	var parsed := _parse_solar_mass_ratio(str(_read(source, "mass", _read(d, "mass_text", ""))))
	parsed = max(parsed, _parse_solar_mass_ratio(_data_card_measurement(source, ["mass"])))
	return max(runtime_mass, parsed)

func _parse_solar_size_ratio(text: String, value_is_radius: bool = false) -> float:
	text = _normalize_numeric_text(text)
	if text.is_empty():
		return 0.0
	var value := _parse_first_number(text)
	if value <= 0.0:
		return 0.0
	if text.contains("solar") or text.contains("sun") or text.contains("r☉") or text.contains("rsun") or text.contains("r_sun") or text.contains("rsol") or text.contains("r_solar"):
		return value
	if text.contains("jupiter") or text.contains("jovian") or text.contains("rj") or text.contains("r_j") or text.contains("r-j"):
		return value * 0.10045
	if text.contains("km") or text.contains("kilometer") or text.contains("kilometre"):
		var diameter_km := value * 2.0 if value_is_radius or _looks_like_radius_measurement(text) else value
		return diameter_km / 1392700.0
	return 0.0

func _parse_solar_mass_ratio(text: String) -> float:
	text = _normalize_numeric_text(text)
	if text.is_empty():
		return 0.0
	var value := _parse_first_number(text)
	if value <= 0.0:
		return 0.0
	if text.contains("solar") or text.contains("sun") or text.contains("m☉") or text.contains("msun") or text.contains("m_sun") or text.contains("msol") or text.contains("m_solar"):
		return value
	if text.contains("jupiter") or text.contains("jovian") or text.contains("mj") or text.contains("m_j") or text.contains("m-j"):
		return value * 0.0009543
	return 0.0

func _max_stat(stats: Dictionary) -> int:
	var result := 0
	for key in stats.keys():
		result = max(result, _safe_int(stats[key]))
	return result

func _min_stat(stats: Dictionary) -> int:
	var result := 100
	for key in stats.keys():
		result = min(result, _safe_int(stats[key]))
	return result

func _grade_at_least(grade: String, target: String) -> bool:
	var order := ["E", "D", "C", "B", "A", "S", "S+", "SS", "SSS", "Ω"]
	var gi := order.find(grade)
	var ti := order.find(target)
	if gi < 0 or ti < 0:
		return false
	return gi >= ti

func _count_kind(bodies: Array, kind: String) -> int:
	var count := 0
	for body in bodies:
		var d = _data(body)
		if kind == "planet" and _is_planet(d): count += 1
		elif kind == "moon" and _is_moon(d): count += 1
		elif kind == "star" and _is_star(d): count += 1
		elif kind == "black_hole" and _is_black_hole(d): count += 1
		elif kind == "white_hole" and _is_white_hole(d): count += 1
	return count

func _has_planet_orbiting_star(bodies: Array) -> bool:
	for planet in bodies:
		var pd = _data(planet)
		if not _is_planet(pd):
			continue
		for star in bodies:
			var sd = _data(star)
			if _is_star(sd) and str(_read(pd, "orbit_parent_id", "")) == str(_read(sd, "instance_id", "")):
				return true
	return false

func _has_moon_orbiting_planet(bodies: Array) -> bool:
	for moon in bodies:
		var md = _data(moon)
		if not _is_moon(md):
			continue
		for planet in bodies:
			var pd = _data(planet)
			if _is_planet(pd) and str(_read(md, "orbit_parent_id", "")) == str(_read(pd, "instance_id", "")):
				return true
	return false

func _has_binary_stars(bodies: Array) -> bool:
	for body in bodies:
		var d = _data(body)
		if not _is_star(d):
			continue
		var metadata = _read(d, "metadata", {})
		if metadata is Dictionary and str(metadata.get("binary_partner_id", "")) != "":
			return true
	return false

func _planets_same_star(bodies: Array) -> int:
	var counts := {}
	for body in bodies:
		var d = _data(body)
		if _is_planet(d):
			var parent := str(_read(d, "orbit_parent_id", ""))
			if parent != "":
				counts[parent] = _safe_int(counts.get(parent, 0)) + 1
	var best := 0
	for key in counts.keys():
		best = max(best, _safe_int(counts[key]))
	return best

func _has_many_moons_same_planet(bodies: Array, needed: int) -> bool:
	var counts := {}
	for body in bodies:
		var d = _data(body)
		if _is_moon(d):
			var parent := str(_read(d, "orbit_parent_id", ""))
			if parent != "":
				counts[parent] = _safe_int(counts.get(parent, 0)) + 1
	for value in counts.values():
		if _safe_int(value) >= needed:
			return true
	return false


func _has_central_planet_binary(bodies: Array) -> bool:
	# Dual What? should mean the CENTER of the system is a two-planet binary,
	# not merely one random planet orbiting another planet somewhere in the scene.
	for body in bodies:
		var a = _data(body)
		if not _is_planet(a):
			continue
		var metadata = _read(a, "metadata", {})
		if not (metadata is Dictionary):
			continue
		var partner_id := str(metadata.get("binary_partner_id", ""))
		if partner_id == "":
			continue
		for other in bodies:
			var b = _data(other)
			if not _is_planet(b):
				continue
			if str(_read(b, "instance_id", "")) != partner_id:
				continue
			var b_meta = _read(b, "metadata", {})
			if not (b_meta is Dictionary):
				continue
			if str(b_meta.get("binary_partner_id", "")) != str(_read(a, "instance_id", "")):
				continue

			var a_center_locked := bool(metadata.get("binary_center_locked", false))
			var b_center_locked := bool(b_meta.get("binary_center_locked", false))
			var a_anchor := bool(_read(a, "is_static_anchor", false))
			var b_anchor := bool(_read(b, "is_static_anchor", false))

			# A freshly created central binary stores binary_center_locked=true. After
			# interactions, one or both members can also carry static-anchor state.
			# Either case is accepted, but random planet-planet satellites are not.
			if a_center_locked or b_center_locked or a_anchor or b_anchor:
				return true
	return false

func _has_planet_orbiting_planet(bodies: Array) -> bool:
	for body in bodies:
		var d = _data(body)
		if not _is_planet(d):
			continue
		var parent_id := str(_read(d, "orbit_parent_id", ""))
		for other in bodies:
			var od = _data(other)
			if _is_planet(od) and str(_read(od, "instance_id", "")) == parent_id:
				return true
	return false

func _planets_orbiting_named_body(bodies: Array, target_name: String) -> int:
	var target_id := ""
	for body in bodies:
		var d = _data(body)
		if _name(d).to_lower() == target_name.to_lower():
			target_id = str(_read(d, "instance_id", ""))
			break
	if target_id == "":
		return 0
	var count := 0
	for body in bodies:
		var d = _data(body)
		if _is_planet(d) and str(_read(d, "orbit_parent_id", "")) == target_id:
			count += 1
	return count

func _has_red_supergiant(bodies: Array) -> bool:
	for body in bodies:
		if _is_red_giant(_data(body)):
			return true
	return false

func _any_star_far_from_origin(bodies: Array) -> bool:
	for body in bodies:
		var d = _data(body)
		if _is_star(d):
			var pos: Vector2 = _read(d, "position", Vector2.ZERO)
			if pos.length() >= 100000.0:
				return true
	return false

func _any_planet_far_from_origin(bodies: Array, distance: float) -> bool:
	for body in bodies:
		var d = _data(body)
		if _is_planet(d):
			var pos: Vector2 = _read(d, "position", Vector2.ZERO)
			if pos.length() >= distance:
				return true
	return false

func _has_planet_orbiting_moon(bodies: Array) -> bool:
	for body in bodies:
		var d = _data(body)
		if not _is_planet(d):
			continue
		var parent_id := str(_read(d, "orbit_parent_id", ""))
		for other in bodies:
			var od = _data(other)
			if _is_moon(od) and str(_read(od, "instance_id", "")) == parent_id:
				return true
	return false

func _has_star_orbiting_planet(bodies: Array) -> bool:
	for body in bodies:
		var d = _data(body)
		if not _is_star(d):
			continue
		var parent_id := str(_read(d, "orbit_parent_id", ""))
		for other in bodies:
			var od = _data(other)
			if _is_planet(od) and str(_read(od, "instance_id", "")) == parent_id:
				return true
	return false


func _max_moons_same_planet(bodies: Array) -> int:
	var counts := {}
	for body in bodies:
		var d = _data(body)
		if _is_moon(d):
			var parent := str(_read(d, "orbit_parent_id", ""))
			if parent != "": counts[parent] = _safe_int(counts.get(parent, 0)) + 1
	var best := 0
	for value in counts.values(): best = max(best, _safe_int(value))
	return best

func _max_far_planet_level(bodies: Array, distance: float) -> int:
	var best := 0
	for body in bodies:
		var d = _data(body)
		if _is_planet(d):
			var pos: Vector2 = _read(d, "position", Vector2.ZERO)
			if pos.length() >= distance: best = max(best, _level(d))
	return max(best, 1)

func _broken_orbit_level(bodies: Array) -> int:
	var best := 1
	for body in bodies:
		var d = _data(body)
		if _is_planet(d) or _is_star(d):
			best = max(best, _level(d))
	return best

func _max_stars_orbiting_black_hole(bodies: Array) -> int:
	var black_ids: Array[String] = []
	for body in bodies:
		var d = _data(body)
		if _is_black_hole(d): black_ids.append(str(_read(d, "instance_id", "")))
	var counts := {}
	for body in bodies:
		var d = _data(body)
		if _is_star(d):
			var parent := str(_read(d, "orbit_parent_id", ""))
			if black_ids.has(parent): counts[parent] = _safe_int(counts.get(parent, 0)) + 1
	var best := 0
	for value in counts.values(): best = max(best, _safe_int(value))
	return best

func _max_moons_orbiting_black_hole(bodies: Array) -> int:
	var black_ids: Array[String] = []
	for body in bodies:
		var d = _data(body)
		if _is_black_hole(d): black_ids.append(str(_read(d, "instance_id", "")))
	var counts := {}
	for body in bodies:
		var d = _data(body)
		if _is_moon(d):
			var parent := str(_read(d, "orbit_parent_id", ""))
			if black_ids.has(parent): counts[parent] = _safe_int(counts.get(parent, 0)) + 1
	var best := 0
	for value in counts.values(): best = max(best, _safe_int(value))
	return best

func _card_stat(card, title: String) -> int:
	return _stat(card, title)

func _is_generated_card(card) -> bool:
	var source_text := str(_read(card, "source", "")).to_lower()
	if source_text.contains("generated") or source_text.contains("ai"):
		return true

	var id := str(_read(card, "instance_id", "")).strip_edges().to_lower()
	var generated_ids: Dictionary = local_events.get("generated_card_ids", {}) if local_events.get("generated_card_ids", {}) is Dictionary else {}
	if not id.is_empty() and generated_ids.has(id):
		return true

	return id.begins_with("generated") or id.contains("_generated") or bool(_read(card, "is_generated", false))

func _load_uid() -> String:
	return ""

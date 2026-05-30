extends Node
class_name UnilearnAchievementsService

signal achievements_changed(results: Array)

const TIER_NONE := 0
const TIER_BRONZE := 1
const TIER_SILVER := 2
const TIER_GOLD := 3

const BRONZE_LEVEL := 1
const SILVER_LEVEL := 30
const GOLD_LEVEL := 100
const REFRESH_INTERVAL := 0.65
const SAVE_PATH := "user://unilearn_achievement_events.cfg"
const TARGET_DEFINITION_COUNT := 100


const CATEGORY_ORDER := [
	"add_body",
	"planet_collision",
	"sun_collision",
	"black_hole",
	"stat_mastery",
	"stability",
	"instability",
	"type_amount",
	"fictional_system",
	"franchise_system"
]

const CATEGORY_LABELS := {
	"add_body": "Scene Bodies",
	"planet_collision": "Planet Collisions",
	"sun_collision": "Sun Collisions",
	"black_hole": "Black Holes",
	"stat_mastery": "Stat Mastery",
	"stability": "Stability",
	"instability": "Instability",
	"type_amount": "Collections",
	"fictional_system": "Fictional Systems",
	"franchise_system": "Universe Systems"
}

const TYPE_TARGETS := [
	{"target": "planet", "name": "planets"},
	{"target": "star", "name": "stars"},
	{"target": "moon", "name": "moons"},
	{"target": "gas", "name": "gas giants"},
	{"target": "ice", "name": "ice worlds"},
	{"target": "lava", "name": "lava worlds"},
	{"target": "rocky", "name": "rocky worlds"},
	{"target": "ringed", "name": "ringed worlds"},
	{"target": "ocean", "name": "ocean worlds"},
	{"target": "desert", "name": "desert worlds"},
	{"target": "terran", "name": "terran worlds"},
	{"target": "dwarf", "name": "dwarf planets"},
	{"target": "asteroid", "name": "asteroids"},
	{"target": "comet", "name": "comets"},
	{"target": "crystal", "name": "crystal worlds"},
	{"target": "toxic", "name": "toxic worlds"},
	{"target": "jungle", "name": "jungle worlds"},
	{"target": "city", "name": "city planets"},
	{"target": "binary", "name": "binary stars"},
	{"target": "black_hole", "name": "black holes"}
]

const STAT_TARGETS := ["habitability", "magnetic", "gravity", "atmosphere", "resources", "mystery"]

const FRANCHISES := {
	"star_wars": {"title": "Star Wars", "hints": ["star wars", "jedi", "sith", "tatooine", "hoth", "coruscant", "dagobah", "endor", "naboo", "mustafar", "kamino", "bespin", "alderaan", "geonosis", "kashyyyk", "jakku", "scarif", "yavin", "mandalore", "dathomir", "kessel"]},
	"dune": {"title": "Dune", "hints": ["dune", "arrakis", "caladan", "giedi prime", "salusa secundus", "kaitain"]},
	"avatar": {"title": "Avatar", "hints": ["avatar", "pandora", "polyphemus", "na'vi", "navi"]},
	"star_trek": {"title": "Star Trek", "hints": ["star trek", "vulcan", "romulus", "qonos", "kronos", "bajor", "cardassia", "ferenginar"]},
	"dragon_ball": {"title": "Dragon Ball", "hints": ["dragon ball", "namek", "vegeta", "planet plant", "yardrat"]},
	"transformers": {"title": "Transformers", "hints": ["transformers", "cybertron", "velocitron", "junkion"]},
	"halo": {"title": "Halo", "hints": ["halo", "reach", "sanghelios", "installation", "forerunner"]},
	"marvel": {"title": "Marvel", "hints": ["marvel", "asgard", "sakaar", "xandar", "knowhere", "vormir", "ego"]},
	"dc": {"title": "DC", "hints": ["dc", "krypton", "apokolips", "oa", "thanagar", "rann"]},
	"mass_effect": {"title": "Mass Effect", "hints": ["mass effect", "palaven", "thessia", "sur'kesh", "tuchanka", "illium"]}
}

var _last_results: Array = []
var _last_signature := ""
var _refresh_accum := 0.0
var _definition_cache: Array = []
var _events := {
	"body_added": 0,
	"planet_collision": 0,
	"sun_collision": 0,
	"black_hole_supernova": 0
}


func _ready() -> void:
	_load_events()
	_connect_sources()
	set_process(true)
	refresh(true)


func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum < REFRESH_INTERVAL:
		return
	_refresh_accum = 0.0
	refresh(false)


func _connect_sources() -> void:
	var cache := get_node_or_null("/root/PlanetCardsCache")
	if cache != null and cache.has_signal("cards_changed"):
		var callable := Callable(self, "_on_source_changed")
		if not cache.is_connected("cards_changed", callable):
			cache.connect("cards_changed", callable)

	var state := get_node_or_null("/root/GalaxyState")
	if state != null:
		for signal_name in ["galaxy_bodies_changed", "bodies_changed", "galaxy_config_changed"]:
			if state.has_signal(signal_name):
				var callable := Callable(self, "_on_source_changed")
				if not state.is_connected(signal_name, callable):
					state.connect(signal_name, callable)


func _on_source_changed(_a = null, _b = null, _c = null) -> void:
	refresh(false)


func record_body_added(_data: Variant = null) -> void:
	_events["body_added"] = int(_events.get("body_added", 0)) + 1
	_save_events()
	refresh(true)


func record_planet_collision(_a: Variant = null, _b: Variant = null) -> void:
	_events["planet_collision"] = int(_events.get("planet_collision", 0)) + 1
	_save_events()
	refresh(true)


func record_sun_collision(_a: Variant = null, _b: Variant = null) -> void:
	_events["sun_collision"] = int(_events.get("sun_collision", 0)) + 1
	_save_events()
	refresh(true)


func record_black_hole_discovered_by_supernova(_data: Variant = null) -> void:
	_events["black_hole_supernova"] = int(_events.get("black_hole_supernova", 0)) + 1
	_save_events()
	refresh(true)


func refresh(force_emit: bool = false) -> Array:
	var cards := _get_cards()
	var bodies := _get_scene_bodies()
	var signature := _build_signature(cards, bodies)
	if signature == _last_signature and not force_emit:
		return _last_results
	_last_signature = signature
	_last_results = evaluate(cards, bodies)
	achievements_changed.emit(_last_results)
	return _last_results


func get_results() -> Array:
	if _last_results.is_empty():
		return refresh(true)
	return _last_results


func get_summary() -> Dictionary:
	var results := get_results()
	var unlocked := 0
	var bronze := 0
	var silver := 0
	var gold := 0
	var points := 0
	for result in results:
		var tier := int(result.get("tier", 0))
		if tier > 0:
			unlocked += 1
			points += int(result.get("points", 0))
		match tier:
			TIER_BRONZE:
				bronze += 1
			TIER_SILVER:
				silver += 1
			TIER_GOLD:
				gold += 1
	return {"total": results.size(), "unlocked": unlocked, "bronze": bronze, "silver": silver, "gold": gold, "points": points}


func get_category_summaries(query: String = "") -> Array:
	var results := filter_results(query)
	var by_category: Dictionary = {}

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

		var item: Dictionary = by_category[category]
		item["total"] = int(item.get("total", 0)) + 1
		var tier := int(result.get("tier", 0))
		if tier > 0:
			item["unlocked"] = int(item.get("unlocked", 0)) + 1
			item["points"] = int(item.get("points", 0)) + int(result.get("points", 0))

		match tier:
			TIER_BRONZE:
				item["bronze"] = int(item.get("bronze", 0)) + 1
			TIER_SILVER:
				item["silver"] = int(item.get("silver", 0)) + 1
			TIER_GOLD:
				item["gold"] = int(item.get("gold", 0)) + 1

		by_category[category] = item

	var summaries: Array = []
	for category in CATEGORY_ORDER:
		if by_category.has(category):
			var summary: Dictionary = by_category[category]
			if int(summary.get("total", 0)) > 0 or query.strip_edges().is_empty():
				summaries.append(summary)

	for category in by_category.keys():
		if not CATEGORY_ORDER.has(str(category)):
			summaries.append(by_category[category])

	return summaries


func evaluate(cards: Array, bodies: Array = []) -> Array:
	var context := _build_context(cards, bodies)
	var results: Array = []
	for definition in _build_definitions():
		results.append(_evaluate_definition(definition, context))
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var at := int(a.get("tier", 0))
		var bt := int(b.get("tier", 0))
		if at != bt:
			return at > bt
		var ap := float(a.get("progress", 0.0))
		var bp := float(b.get("progress", 0.0))
		if not is_equal_approx(ap, bp):
			return ap > bp
		return str(a.get("title", "")) < str(b.get("title", ""))
	)
	return results


func filter_results(query: String) -> Array:
	var q := query.strip_edges().to_lower()
	var results := get_results()
	if q.is_empty():
		return results
	var filtered: Array = []
	for result in results:
		var blob := "%s %s %s %s %s" % [str(result.get("title", "")), str(result.get("description", "")), str(result.get("category", "")), str(result.get("category_label", "")), str(result.get("tier_name", ""))]
		if blob.to_lower().contains(q):
			filtered.append(result)
	return filtered


func _build_definitions() -> Array:
	if not _definition_cache.is_empty():
		return _definition_cache

	var defs: Array = []

	for count in range(1, 13):
		defs.append(_def("scene_bodies_%03d" % count, "Scene Builder %03d" % count, "Add at least %d cosmic bodies to the simulator scene and keep them active long enough to be counted." % count, "add_body", "scene_body", "all", count, "level"))

	defs.append(_def("scene_binary_eight", "Binary Architect", "Build a simulator scene with at least 2 stars and 8 planets in the same active system.", "add_body", "binary_system", "binary", 8, "level", 2))

	for count in range(1, 9):
		defs.append(_def("planet_collision_%03d" % count, "Impact Chain %03d" % count, "Trigger at least %d planet collision events in the simulator." % count, "planet_collision", "counter", "planet_collision", count, "counter"))

	for count in range(1, 7):
		defs.append(_def("sun_collision_%03d" % count, "Solar Clash %03d" % count, "Trigger at least %d star collision events in the simulator." % count, "sun_collision", "counter", "sun_collision", count, "counter"))

	for count in range(1, 7):
		defs.append(_def("black_hole_%03d" % count, "Event Horizon %03d" % count, "Discover or create at least %d black holes, including black holes formed from supernova events." % count, "black_hole", "black_hole", "supernova", count, "counter_or_object"))

	for count in range(3, 13):
		defs.append(_def("stable_system_%03d" % count, "Stable Orbit %03d" % count, "Keep a simulator system with at least %d bodies stable, readable, and free from recent destructive collisions." % count, "stability", "stability", "stable", count, "system"))

	for count in range(1, 9):
		defs.append(_def("unstable_system_%03d" % count, "Beautiful Disaster %03d" % count, "Create at least %d instability events through collisions, crowded systems, or chaotic simulator behavior." % count, "instability", "instability", "unstable", count, "counter"))

	for stat_name in STAT_TARGETS:
		for count in range(1, 4):
			var pretty: Variant = stat_name.capitalize()
			defs.append(_def("stat_%s_%02d" % [stat_name, count], "%s Mastery %02d" % [pretty, count], "Max the %s stat on at least %d different cards in your collection." % [pretty.to_lower(), count], "stat_mastery", "stat", stat_name, count, "stat"))

	for item in TYPE_TARGETS:
		var target := str(item.get("target", "planet"))
		var label := str(item.get("name", target))
		defs.append(_def("type_%s_01" % target, "%s Collector" % label.capitalize(), "Collect or place at least 1 %s in the current simulator scene or card collection." % label, "type_amount", "type", target, 1, "level"))

	for count in range(2, 7):
		defs.append(_def("fictional_system_%03d" % count, "Fictional Universe %03d" % count, "Build a system of at least %d bodies where every star and planet belongs to a fictional or custom universe." % count, "fictional_system", "fictional_scene", "fictional", count, "level"))

	var franchise_keys := ["star_wars", "dune", "avatar", "star_trek", "dragon_ball", "transformers"]
	for key in franchise_keys:
		var data: Dictionary = FRANCHISES.get(key, {})
		var title := str(data.get("title", key.capitalize()))
		defs.append(_def("franchise_%s_03" % key, "%s System" % title, "Build a system with at least 3 bodies from the %s universe." % title, "franchise_system", "franchise", str(key), 3, "level"))

	while defs.size() > TARGET_DEFINITION_COUNT:
		defs.pop_back()

	_definition_cache = defs
	return _definition_cache

func _def(id: String, title: String, description: String, category: String, kind: String, target: String, count: int, tier_mode: String, required_stars: int = 0) -> Dictionary:
	return {"id": id, "title": title, "description": description, "category": category, "category_label": CATEGORY_LABELS.get(category, category.capitalize()), "kind": kind, "target": target, "required_count": count, "required_stars": required_stars, "tier_mode": tier_mode}


func _evaluate_definition(definition: Dictionary, context: Dictionary) -> Dictionary:
	var matching_items := _matching_items_for(definition, context)
	var count := matching_items.size()
	var required_count: int = max(1, int(definition.get("required_count", 1)))
	var required_stars := int(definition.get("required_stars", 0))
	var star_count := int(context.get("active_star_count", 0))
	var counter_value := _counter_value(definition, context)
	var tier_mode := str(definition.get("tier_mode", "level"))
	var progress_count := count
	if tier_mode == "counter" or tier_mode == "counter_or_object":
		progress_count = max(count, counter_value)
	var structure_ok: bool = progress_count >= required_count
	if required_stars > 0:
		structure_ok = structure_ok and star_count >= required_stars
	var tier := _tier_for(definition, matching_items, progress_count, context, structure_ok)
	var progress := float(progress_count) / float(required_count)
	if required_stars > 0:
		progress = min(progress, float(star_count) / float(required_stars))
	progress = clamp(progress, 0.0, 1.0)
	return {"id": definition.get("id", ""), "title": definition.get("title", "Achievement"), "description": definition.get("description", "Complete the listed requirement to unlock this achievement."), "category": definition.get("category", "type_amount"), "category_label": definition.get("category_label", "Achievement"), "tier": tier, "tier_name": tier_name(tier), "points": points_for_tier(tier), "progress": progress, "current_count": progress_count, "required_count": required_count, "min_level": _min_level(matching_items), "avg_level": _avg_level(matching_items), "required_stars": required_stars, "active_stars": star_count}


func _tier_for(definition: Dictionary, items: Array, count: int, context: Dictionary, structure_ok: bool) -> int:
	if not structure_ok:
		return TIER_NONE
	var mode := str(definition.get("tier_mode", "level"))
	match mode:
		"counter", "counter_or_object":
			var required: int = max(1, int(definition.get("required_count", 1)))
			if count >= required * 10:
				return TIER_GOLD
			if count >= required * 3:
				return TIER_SILVER
			return TIER_BRONZE
		"stat":
			var required: int = max(1, int(definition.get("required_count", 1)))
			if count >= required * 2 or count >= 6:
				return TIER_GOLD
			if count >= required + 1:
				return TIER_SILVER
			return TIER_BRONZE
		"system":
			var collisions := int(_events.get("planet_collision", 0)) + int(_events.get("sun_collision", 0))
			if collisions <= 0 and int(context.get("active_body_count", 0)) >= int(definition.get("required_count", 1)) * 2:
				return TIER_GOLD
			if collisions <= 1:
				return TIER_SILVER
			return TIER_BRONZE
		_:
			var min_level := _min_level(items)
			var avg_level := _avg_level(items)
			if min_level >= GOLD_LEVEL or (avg_level >= GOLD_LEVEL and min_level >= SILVER_LEVEL):
				return TIER_GOLD
			if min_level >= SILVER_LEVEL:
				return TIER_SILVER
			return TIER_BRONZE


func _matching_items_for(definition: Dictionary, context: Dictionary) -> Array:
	var kind := str(definition.get("kind", ""))
	var target := str(definition.get("target", ""))
	var cards: Array = context.get("cards", [])
	var bodies: Array = context.get("bodies", [])
	var scene_items := bodies if not bodies.is_empty() else cards
	var result: Array = []
	match kind:
		"scene_body":
			result = scene_items.duplicate()
		"binary_system":
			for item in scene_items:
				if _matches_category(item, "planet"):
					result.append(item)
		"counter":
			return []
		"black_hole":
			for item in scene_items:
				if _matches_category(item, "black_hole"):
					result.append(item)
		"stability":
			result = scene_items.duplicate()
		"instability":
			var unstable_score: int = int(_events.get("planet_collision", 0)) + int(_events.get("sun_collision", 0)) + max(0, int(context.get("active_body_count", 0)) - 10)
			for _i in range(unstable_score):
				result.append({"name": "instability", "game_level": 1})
		"stat":
			result = _maxed_stats(cards, target)
		"fictional_scene":
			if scene_items.size() >= int(definition.get("required_count", 1)) and _all_items_match(scene_items, Callable(self, "_is_fictional")):
				result = scene_items.duplicate()
		"type":
			for item in scene_items:
				if _matches_category(item, target):
					result.append(item)
		"franchise":
			for item in scene_items:
				if _matches_franchise(item, target):
					result.append(item)
		_:
			result = []
	return result


func _counter_value(definition: Dictionary, _context: Dictionary) -> int:
	var kind := str(definition.get("kind", ""))
	var category := str(definition.get("category", ""))
	if kind == "counter":
		return int(_events.get(str(definition.get("target", "")), 0))
	if category == "black_hole":
		return int(_events.get("black_hole_supernova", 0))
	if category == "add_body":
		return int(_events.get("body_added", 0))
	if category == "instability":
		return int(_events.get("planet_collision", 0)) + int(_events.get("sun_collision", 0))
	return 0


func _build_context(cards: Array, bodies: Array) -> Dictionary:
	var active_items := bodies if not bodies.is_empty() else cards
	return {"cards": cards, "bodies": bodies, "active_body_count": active_items.size(), "active_star_count": _count_matching(active_items, "star"), "active_planet_count": _count_matching(active_items, "planet")}


func _count_matching(items: Array, category: String) -> int:
	var count := 0
	for item in items:
		if _matches_category(item, category):
			count += 1
	return count


func _get_cards() -> Array:
	var cache := get_node_or_null("/root/PlanetCardsCache")
	if cache != null and cache.has_method("get_all_cards"):
		var cards: Variant = cache.call("get_all_cards")
		if cards is Array:
			return cards
	return []


func _get_scene_bodies() -> Array:
	var state := get_node_or_null("/root/GalaxyState")
	if state != null and state.has_method("get_bodies"):
		var bodies: Variant = state.call("get_bodies")
		if bodies is Array and not bodies.is_empty():
			return bodies
	var scene := get_tree().current_scene
	var playground := _find_node_named(scene, "UniversePlayground")
	if playground != null and playground.has_method("get_added_planets_snapshot"):
		var snapshot: Variant = playground.call("get_added_planets_snapshot")
		if snapshot is Array:
			return snapshot
	return []


func _find_node_named(node: Node, wanted: String) -> Node:
	if node == null:
		return null
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find_node_named(child, wanted)
		if found != null:
			return found
	return null


func _build_signature(cards: Array, bodies: Array) -> String:
	var chunks: Array[String] = []
	for card in cards:
		chunks.append("%s:%d" % [_item_text(card), _card_level(card)])
	chunks.sort()
	var body_chunks: Array[String] = []
	for body in bodies:
		body_chunks.append("%s:%d" % [_item_text(body), _card_level(body)])
	body_chunks.sort()
	chunks.append("bodies=" + "|".join(body_chunks))
	chunks.append("events=%s" % str(_events))
	return "#".join(chunks)


func _matches_category(item: Variant, category: String) -> bool:
	var text := _item_text(item)
	category = category.to_lower()
	match category:
		"planet":
			return (text.contains("planet") or text.contains("world") or text.contains("terran") or text.contains("earth") or text.contains("mars") or text.contains("jupiter") or text.contains("saturn")) and not _matches_category(item, "star") and not _matches_category(item, "moon") and not _matches_category(item, "black_hole")
		"star":
			return text.contains("star") or text.contains("sun") or text.contains("stellar")
		"moon":
			return text.contains("moon") or text.contains("satellite")
		"black_hole":
			return text.contains("black hole") or text.contains("singularity") or text.contains("event horizon")
		"gas":
			return text.contains("gas") or text.contains("jupiter") or text.contains("saturn")
		"ice":
			return text.contains("ice") or text.contains("frozen") or text.contains("cryo") or text.contains("neptune") or text.contains("uranus") or text.contains("hoth")
		"lava":
			return text.contains("lava") or text.contains("volcan") or text.contains("magma") or text.contains("mustafar")
		"rocky":
			return text.contains("rock") or text.contains("terran") or text.contains("earth") or text.contains("mars") or text.contains("venus") or text.contains("mercury")
		"ringed":
			return text.contains("ring") or text.contains("saturn")
		"ocean":
			return text.contains("ocean") or text.contains("water") or text.contains("sea") or text.contains("rivers") or text.contains("kamino")
		"desert":
			return text.contains("desert") or text.contains("dry") or text.contains("tatooine") or text.contains("arrakis")
		"terran":
			return text.contains("terran") or text.contains("earth") or text.contains("habitable")
		"dwarf":
			return text.contains("dwarf") or text.contains("pluto")
		"asteroid":
			return text.contains("asteroid")
		"comet":
			return text.contains("comet")
		"crystal":
			return text.contains("crystal")
		"toxic":
			return text.contains("toxic") or text.contains("acid") or text.contains("poison")
		"jungle":
			return text.contains("jungle") or text.contains("forest") or text.contains("endor") or text.contains("kashyyyk")
		"city":
			return text.contains("city") or text.contains("coruscant") or text.contains("urban")
		"binary":
			return text.contains("binary") or text.contains("twin star")
		_:
			return text.contains(category)


func _is_fictional(item: Variant) -> bool:
	var text := _item_text(item)
	for key in FRANCHISES.keys():
		if _matches_franchise(item, str(key)):
			return true
	for hint in ["fictional", "imaginary", "fan made", "custom", "made up", "myth", "krypton", "cybertron", "namek", "arrakis", "pandora"]:
		if text.contains(str(hint)):
			return true
	return false


func _matches_franchise(item: Variant, key: String) -> bool:
	var data: Dictionary = FRANCHISES.get(key, {})
	var hints: Array = data.get("hints", [])
	var text := _item_text(item)
	for hint in hints:
		if text.contains(str(hint)):
			return true
	return false


func _all_items_match(items: Array, callable: Callable) -> bool:
	if items.is_empty():
		return false
	for item in items:
		if not bool(callable.call(item)):
			return false
	return true


func _maxed_stats(cards: Array, target_stat: String = "any") -> Array:
	var found: Dictionary = {}
	for card in cards:
		var scores: Variant = _safe_get(card, "game_attribute_scores")
		if not (scores is Array):
			continue
		for entry in scores:
			if not (entry is Dictionary):
				continue
			var name := str(entry.get("title", entry.get("name", entry.get("id", "stat")))).strip_edges().to_lower()
			var value := float(entry.get("score", entry.get("value", entry.get("amount", 0.0))))
			if value < 100.0:
				continue
			if target_stat != "any" and not name.contains(target_stat):
				continue
			found[name + str(found.size())] = {"name": name, "game_level": _card_level(card)}
	var result: Array = []
	for value in found.values():
		result.append(value)
	return result


func _item_text(item: Variant) -> String:
	var parts: Array[String] = []
	if item is Dictionary:
		for key in item.keys():
			var value = item.get(key)
			if value is String or value is int or value is float:
				parts.append(str(value))
			elif key == "source_planet_data" or key == "data" or key == "planet_data":
				parts.append(_item_text(value))
	elif item is Node:
		parts.append(str(item.name))
		for key in ["data", "planet_data", "source_planet_data"]:
			var value = item.get(key)
			if value != null:
				parts.append(_item_text(value))
	else:
		for key in ["name", "subtitle", "description", "object_category", "planet_preset", "archetype_id", "system_role", "composition", "atmosphere", "surface_geology", "ring_system", "habitability_note", "formation_note", "discovery_note", "notable_extreme", "exploration_status"]:
			var value: Variant = _safe_get(item, key)
			if value != null:
				parts.append(str(value))
	return " ".join(parts).to_lower()


func _safe_get(source: Variant, property_name: String) -> Variant:
	if source == null:
		return null
	if source is Dictionary:
		return source.get(property_name, null)
	if source is Object:
		return source.get(property_name)
	return null


func _card_level(card: Variant) -> int:
	var value: Variant = _safe_get(card, "game_level")
	if value == null:
		return 1
	return max(1, int(value))


func _min_level(items: Array) -> int:
	if items.is_empty():
		return 0
	var result := 999999
	for item in items:
		result = min(result, _card_level(item))
	return result


func _avg_level(items: Array) -> float:
	if items.is_empty():
		return 0.0
	var total := 0.0
	for item in items:
		total += float(_card_level(item))
	return total / float(items.size())


func tier_name(tier: int) -> String:
	match tier:
		TIER_BRONZE:
			return "BRONZE"
		TIER_SILVER:
			return "SILVER"
		TIER_GOLD:
			return "GOLD"
		_:
			return "LOCKED"


func points_for_tier(tier: int) -> int:
	match tier:
		TIER_BRONZE:
			return 10
		TIER_SILVER:
			return 30
		TIER_GOLD:
			return 75
		_:
			return 0


func color_for_tier(tier: int) -> Color:
	match tier:
		TIER_BRONZE:
			return Color("#CD7F32")
		TIER_SILVER:
			return Color("#C0C7D4")
		TIER_GOLD:
			return Color("#FFC62D")
		_:
			return Color(1, 1, 1, 0.35)


func _load_events() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err != OK:
		return
	for key in _events.keys():
		_events[key] = int(config.get_value("events", str(key), int(_events[key])))


func _save_events() -> void:
	var config := ConfigFile.new()
	for key in _events.keys():
		config.set_value("events", str(key), int(_events[key]))
	config.save(SAVE_PATH)

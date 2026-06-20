extends Resource
class_name PlanetData

@export var instance_id: String = ""
@export var archetype_id: String = ""
@export var name: String = ""
@export var subtitle: String = ""
@export_multiline var description: String = ""
@export var description_highlight_indices: PackedInt32Array = PackedInt32Array()
@export var object_category: String = "planet"
@export var parent_object: String = ""
@export var system_role: String = ""
@export var visual_signature: String = ""
@export var composition: String = ""
@export var atmosphere: String = ""
@export var surface_geology: String = ""
@export var magnetic_field: String = ""
@export var ring_system: String = ""
@export var singularity_has_disk: bool = true
@export var habitability_note: String = ""
@export var formation_note: String = ""
@export var discovery_note: String = ""
@export var notable_extreme: String = ""
@export var exploration_status: String = ""
@export var is_fictional: bool = false
@export var overview_points: Array[Dictionary] = []
@export var data_cards: Array[Dictionary] = []
@export var learning_prompts: Array[Dictionary] = []
@export var game_level: int = 1
@export var game_xp: int = 0
@export var game_xp_to_next: int = 100
@export var attribute_badges: Array[Dictionary] = []
@export var game_attribute_scores: Array[Dictionary] = []
@export var upgrade_quiz_xp_reward: int = 25
@export var planet_preset: String = "terran_wet"
@export var planet_seed: int = 2880143960
@export var planet_radius_px: int = 120
@export var planet_pixels: int = 480
@export var planet_turning_speed: float = 1.0
@export var planet_axial_tilt_deg: float = 0.0
@export var planet_ring_angle_deg: float = 0.0
@export var use_custom_colors: bool = false
@export var custom_colors: PackedColorArray = PackedColorArray()
@export var diameter_km: String = ""
@export var mass: String = ""
@export var orbital_period: String = ""
@export var rotation_period: String = ""
@export var average_temperature: String = ""
@export var gravity: String = ""
@export var moons: String = ""
@export var distance_from_sun: String = ""
@export var key_features: Array[Dictionary] = []
@export var fun_fact_title: String = ""
@export_multiline var fun_fact: String = ""
@export var quiz_title: String = "Quick quiz"
@export var quiz_text: String = ""
@export var compare_title: String = "Compare"
@export var compare_text: String = ""
@export var missions_title: String = "Space missions"
@export var missions_text: String = ""

func get_hero_main_color() -> Color:
	if custom_colors.size() > 0:
		return _pick_main_palette_color(custom_colors, planet_preset)
	return _fallback_main_color_for_preset(planet_preset, object_category, name)

static func _pick_main_palette_color(colors: PackedColorArray, preset_value: String = "") -> Color:
	if colors.is_empty():
		return _fallback_main_color_for_preset(preset_value, "", "")
	var preset := preset_value.strip_edges().to_lower()
	var best := colors[0]
	var best_score := -INF
	for color in colors:
		var brightness := (color.r + color.g + color.b) / 3.0
		var saturation: float = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b))
		var score := saturation * 1.9 + brightness * 0.45
		if brightness < 0.08: score -= 1.2
		if brightness > 0.88 and saturation < 0.16: score -= 0.9
		if preset == "star" and color.r >= color.g and color.g >= color.b: score += 0.28
		if preset.contains("black_hole"): score += (1.0 - brightness) * 0.6 + saturation * 0.4
		if preset.contains("white_hole"): score += brightness * 0.8
		if preset.contains("ice") and color.b >= color.r: score += 0.18
		if preset.contains("lava") and color.r >= color.g: score += 0.22
		if preset.contains("gas") and color.r >= color.b: score += 0.10
		if score > best_score:
			best_score = score
			best = color
	best.a = 1.0
	return best

static func _fallback_main_color_for_preset(preset_value: String, category_value: String = "", name_value: String = "") -> Color:
	var preset := preset_value.strip_edges().to_lower().replace(" ", "_")
	var category := category_value.strip_edges().to_lower().replace(" ", "_")
	var name_text := name_value.strip_edges().to_lower()
	if category.contains("singularity") and preset == "black_hole": return Color("#ffb029")
	if category.contains("singularity") and preset == "white_hole": return Color("#f7fbff")
	if category.contains("black_hole") or preset == "black_hole": return Color("#ffb029")
	if category.contains("white_hole") or preset == "white_hole": return Color("#f7fbff")
	if category.contains("star") or preset == "star" or name_text == "sun": return Color("#ffb73d")
	if category.contains("moon") or category.contains("satellite") or preset == "moon" or preset == "no_atmosphere": return Color("#a9a9a1")
	if preset.contains("lava"): return Color("#ff6a28")
	if preset.contains("ice"): return Color("#6ed9ee")
	if preset.contains("gas") or preset.contains("ringed"): return Color("#d4a765")
	if preset.contains("terran") or preset == "earth" or preset == "islands" or preset == "rivers": return Color("#4fa4b8")
	if preset.contains("dry"): return Color("#c4864f")
	return Color.WHITE

func to_firebase_dict() -> Dictionary:
	return {
		"instance_id": instance_id, "archetype_id": archetype_id, "name": name, "subtitle": subtitle,
		"description": description, "description_highlight_indices": _int_array_to_array(description_highlight_indices),
		"object_category": object_category, "parent_object": parent_object, "system_role": system_role,
		"visual_signature": visual_signature, "composition": composition, "atmosphere": atmosphere,
		"surface_geology": surface_geology, "magnetic_field": magnetic_field, "ring_system": ring_system, "singularity_has_disk": singularity_has_disk,
		"habitability_note": habitability_note, "formation_note": formation_note, "discovery_note": discovery_note,
		"notable_extreme": notable_extreme, "exploration_status": exploration_status, "is_fictional": is_fictional,
		"overview_points": overview_points, "data_cards": data_cards, "learning_prompts": learning_prompts,
		"game_level": game_level, "game_xp": game_xp, "game_xp_to_next": game_xp_to_next,
		"attribute_badges": attribute_badges, "game_attribute_scores": game_attribute_scores,
		"upgrade_quiz_xp_reward": upgrade_quiz_xp_reward, "planet_preset": planet_preset, "planet_seed": planet_seed,
		"planet_radius_px": planet_radius_px, "planet_pixels": planet_pixels, "planet_turning_speed": planet_turning_speed,
		"planet_axial_tilt_deg": planet_axial_tilt_deg, "planet_ring_angle_deg": planet_ring_angle_deg,
		"use_custom_colors": use_custom_colors, "custom_colors": _colors_to_strings(custom_colors),
		"diameter_km": diameter_km, "mass": mass, "orbital_period": orbital_period, "rotation_period": rotation_period,
		"average_temperature": average_temperature, "gravity": gravity, "moons": moons, "distance_from_sun": distance_from_sun,
		"key_features": key_features, "fun_fact_title": fun_fact_title, "fun_fact": fun_fact,
		"quiz_title": quiz_title, "quiz_text": quiz_text, "compare_title": compare_title, "compare_text": compare_text,
		"missions_title": missions_title, "missions_text": missions_text,
	}

static func from_firebase_dict(dict: Dictionary) -> PlanetData:
	var p := PlanetData.new()
	for property in p.get_property_list():
		var key := str(property.get("name", ""))
		if key.begins_with("resource_") or key == "script": continue
		if dict.has(key): p.set(key, dict[key])
	p.description_highlight_indices = _variant_to_int_array(dict.get("description_highlight_indices", []))
	p.overview_points = _variant_to_dictionary_array(dict.get("overview_points", []))
	p.data_cards = _variant_to_dictionary_array(dict.get("data_cards", []))
	p.learning_prompts = _variant_to_dictionary_array(dict.get("learning_prompts", []))
	p.attribute_badges = _variant_to_dictionary_array(dict.get("attribute_badges", []))
	p.game_attribute_scores = _variant_to_dictionary_array(dict.get("game_attribute_scores", []))
	p.key_features = _variant_to_dictionary_array(dict.get("key_features", []))
	p.custom_colors = _strings_to_colors(dict.get("custom_colors", []))
	p.game_level = clampi(int(p.game_level), 1, 10)
	if p.game_level >= 10:
		p.game_xp = max(int(p.game_xp), int(p.game_xp_to_next))
	return p

static func _colors_to_strings(colors: PackedColorArray) -> Array[String]:
	var result: Array[String] = []
	for color in colors: result.append(color.to_html(true))
	return result
static func _strings_to_colors(values: Variant) -> PackedColorArray:
	var result := PackedColorArray()
	if values is Array:
		for value in values: result.append(Color(str(value)))
	return result
static func _int_array_to_array(values: PackedInt32Array) -> Array[int]:
	var result: Array[int] = []
	for value in values: result.append(value)
	return result
static func _variant_to_int_array(values: Variant) -> PackedInt32Array:
	var result := PackedInt32Array()
	if values is Array:
		for value in values: result.append(int(value))
	return result
static func _variant_to_dictionary_array(values: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if values is Array:
		for value in values:
			if value is Dictionary: result.append(value)
	return result
static func _variant_to_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

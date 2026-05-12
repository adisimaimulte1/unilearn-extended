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
@export var habitability_note: String = ""
@export var formation_note: String = ""
@export var discovery_note: String = ""
@export var notable_extreme: String = ""
@export var exploration_status: String = ""

@export var overview_points: Array[Dictionary] = []
@export var data_cards: Array[Dictionary] = []
@export var learning_prompts: Array[Dictionary] = []

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


func to_firebase_dict() -> Dictionary:
	return {
		"instance_id": instance_id,
		"archetype_id": archetype_id,
		"name": name,
		"subtitle": subtitle,
		"description": description,
		"description_highlight_indices": _int_array_to_array(description_highlight_indices),

		"object_category": object_category,
		"parent_object": parent_object,
		"system_role": system_role,
		"visual_signature": visual_signature,
		"composition": composition,
		"atmosphere": atmosphere,
		"surface_geology": surface_geology,
		"magnetic_field": magnetic_field,
		"ring_system": ring_system,
		"habitability_note": habitability_note,
		"formation_note": formation_note,
		"discovery_note": discovery_note,
		"notable_extreme": notable_extreme,
		"exploration_status": exploration_status,
		"overview_points": overview_points,
		"data_cards": data_cards,
		"learning_prompts": learning_prompts,

		"planet_preset": planet_preset,
		"planet_seed": planet_seed,
		"planet_radius_px": planet_radius_px,
		"planet_pixels": planet_pixels,
		"planet_turning_speed": planet_turning_speed,
		"planet_axial_tilt_deg": planet_axial_tilt_deg,
		"planet_ring_angle_deg": planet_ring_angle_deg,
		"use_custom_colors": use_custom_colors,
		"custom_colors": _colors_to_strings(custom_colors),

		"diameter_km": diameter_km,
		"mass": mass,
		"orbital_period": orbital_period,
		"rotation_period": rotation_period,
		"average_temperature": average_temperature,
		"gravity": gravity,
		"moons": moons,
		"distance_from_sun": distance_from_sun,

		"key_features": key_features,
		"fun_fact_title": fun_fact_title,
		"fun_fact": fun_fact,
		"quiz_title": quiz_title,
		"quiz_text": quiz_text,
		"compare_title": compare_title,
		"compare_text": compare_text,
		"missions_title": missions_title,
		"missions_text": missions_text,
	}


static func from_firebase_dict(dict: Dictionary) -> PlanetData:
	var p := PlanetData.new()

	p.instance_id = str(dict.get("instance_id", ""))
	p.archetype_id = str(dict.get("archetype_id", ""))

	p.name = str(dict.get("name", "Unnamed Object"))
	p.subtitle = str(dict.get("subtitle", ""))
	p.description = str(dict.get("description", ""))
	p.description_highlight_indices = _variant_to_int_array(dict.get("description_highlight_indices", []))

	p.object_category = str(dict.get("object_category", "planet"))
	p.parent_object = str(dict.get("parent_object", ""))
	p.system_role = str(dict.get("system_role", ""))
	p.visual_signature = str(dict.get("visual_signature", ""))
	p.composition = str(dict.get("composition", ""))
	p.atmosphere = str(dict.get("atmosphere", ""))
	p.surface_geology = str(dict.get("surface_geology", ""))
	p.magnetic_field = str(dict.get("magnetic_field", ""))
	p.ring_system = str(dict.get("ring_system", ""))
	p.habitability_note = str(dict.get("habitability_note", ""))
	p.formation_note = str(dict.get("formation_note", ""))
	p.discovery_note = str(dict.get("discovery_note", ""))
	p.notable_extreme = str(dict.get("notable_extreme", ""))
	p.exploration_status = str(dict.get("exploration_status", ""))
	p.overview_points = _variant_to_dictionary_array(dict.get("overview_points", []))
	p.data_cards = _variant_to_dictionary_array(dict.get("data_cards", []))
	p.learning_prompts = _variant_to_dictionary_array(dict.get("learning_prompts", []))

	p.planet_preset = str(dict.get("planet_preset", "terran_wet"))
	p.planet_seed = int(dict.get("planet_seed", 2880143960))
	p.planet_radius_px = int(dict.get("planet_radius_px", 120))
	p.planet_pixels = int(dict.get("planet_pixels", 480))
	p.planet_turning_speed = float(dict.get("planet_turning_speed", 1.0))
	p.planet_axial_tilt_deg = float(dict.get("planet_axial_tilt_deg", 0.0))
	p.planet_ring_angle_deg = float(dict.get("planet_ring_angle_deg", 0.0))
	p.use_custom_colors = bool(dict.get("use_custom_colors", false))
	p.custom_colors = _strings_to_colors(dict.get("custom_colors", []))

	p.diameter_km = str(dict.get("diameter_km", ""))
	p.mass = str(dict.get("mass", ""))
	p.orbital_period = str(dict.get("orbital_period", ""))
	p.rotation_period = str(dict.get("rotation_period", ""))
	p.average_temperature = str(dict.get("average_temperature", ""))
	p.gravity = str(dict.get("gravity", ""))
	p.moons = str(dict.get("moons", ""))
	p.distance_from_sun = str(dict.get("distance_from_sun", ""))

	p.key_features = _variant_to_dictionary_array(dict.get("key_features", []))
	p.fun_fact_title = str(dict.get("fun_fact_title", ""))
	p.fun_fact = str(dict.get("fun_fact", ""))
	p.quiz_title = str(dict.get("quiz_title", "Quick quiz"))
	p.quiz_text = str(dict.get("quiz_text", ""))
	p.compare_title = str(dict.get("compare_title", "Compare"))
	p.compare_text = str(dict.get("compare_text", ""))
	p.missions_title = str(dict.get("missions_title", "Space missions"))
	p.missions_text = str(dict.get("missions_text", ""))

	return p


static func _colors_to_strings(colors: PackedColorArray) -> Array[String]:
	var result: Array[String] = []

	for color in colors:
		result.append(color.to_html(true))

	return result


static func _strings_to_colors(values: Variant) -> PackedColorArray:
	var result := PackedColorArray()

	if not (values is Array):
		return result

	for value in values:
		result.append(Color(str(value)))

	return result


static func _int_array_to_array(values: PackedInt32Array) -> Array[int]:
	var result: Array[int] = []

	for value in values:
		result.append(value)

	return result


static func _variant_to_int_array(values: Variant) -> PackedInt32Array:
	var result := PackedInt32Array()

	if not (values is Array):
		return result

	for value in values:
		result.append(int(value))

	return result


static func _variant_to_dictionary_array(values: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if not (values is Array):
		return result

	for value in values:
		if value is Dictionary:
			result.append(value)

	return result

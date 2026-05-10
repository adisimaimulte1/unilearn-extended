extends Resource
class_name PlanetData

@export var instance_id: String = ""
@export var archetype_id: String = ""

@export var name: String = ""
@export var subtitle: String = ""
@export_multiline var description: String = ""

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

	p.name = str(dict.get("name", "Unnamed Planet"))
	p.subtitle = str(dict.get("subtitle", ""))
	p.description = str(dict.get("description", ""))

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

	p.key_features = dict.get("key_features", [])
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

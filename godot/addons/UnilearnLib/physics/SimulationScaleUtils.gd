extends RefCounted
class_name SimulationScaleUtils

const EARTH_DIAMETER_KM := 12742.0
const EARTH_SCENE_RADIUS := 144.0

const PLANET_SCALE_POWER := 0.58

const MIN_SCENE_RADIUS := 30.0
const MAX_SCENE_RADIUS := 520.0

const SUN_DIAMETER_KM := 1392700.0
const SUN_SCENE_RADIUS := 780.0

const STAR_SCALE_POWER := 0.42

const MIN_STAR_RADIUS := 560.0
const MAX_STAR_RADIUS := 1900.0

const FALLBACK_MOON_RATIO := 0.27
const FALLBACK_DWARF_RATIO := 0.22
const FALLBACK_TERRESTRIAL_RATIO := 1.0
const FALLBACK_ICE_RATIO := 3.9
const FALLBACK_GAS_RATIO := 10.8
const FALLBACK_STAR_RATIO := 1.0
const FALLBACK_BLACK_HOLE_RATIO := 38.0


static func calculate_scene_radius(planet_data: PlanetData) -> float:
	if planet_data == null:
		return EARTH_SCENE_RADIUS

	if _is_star(planet_data):
		return _calculate_star_scene_radius(planet_data)

	var ratio := _diameter_ratio_from_card_data(planet_data, EARTH_DIAMETER_KM)

	if ratio <= 0.0:
		ratio = _fallback_planet_ratio_from_card_identity(planet_data)

	var raw_radius := EARTH_SCENE_RADIUS * pow(max(ratio, 0.02), PLANET_SCALE_POWER)
	return clamp(raw_radius, MIN_SCENE_RADIUS, _max_planet_radius_from_data(planet_data, ratio))


static func calculate_hit_radius(planet_data: PlanetData, scene_radius: float) -> float:
	if planet_data == null:
		return max(scene_radius + 26.0, 52.0)

	var preset := _normalized(planet_data.planet_preset)

	if _is_star(planet_data):
		return scene_radius * 1.12

	if preset == "ringed_gas_planet":
		return scene_radius * 1.46

	if preset == "black_hole":
		return scene_radius * 1.28

	return scene_radius + max(24.0, scene_radius * 0.10)


static func _calculate_star_scene_radius(planet_data: PlanetData) -> float:
	var sun_ratio := _diameter_ratio_from_card_data(planet_data, SUN_DIAMETER_KM)

	if sun_ratio <= 0.0:
		sun_ratio = _fallback_star_ratio_from_card_identity(planet_data)

	var raw_radius := SUN_SCENE_RADIUS * pow(max(sun_ratio, 0.05), STAR_SCALE_POWER)
	return clamp(raw_radius, MIN_STAR_RADIUS, _max_star_radius_from_data(planet_data, sun_ratio))


static func _diameter_ratio_from_card_data(planet_data: PlanetData, reference_diameter_km: float) -> float:
	if planet_data == null:
		return 0.0

	var ratio := _diameter_ratio_from_text(planet_data.diameter_km, reference_diameter_km)

	if ratio > 0.0:
		return ratio

	ratio = _diameter_ratio_from_text(planet_data.radius_km, reference_diameter_km)

	if ratio > 0.0:
		return ratio * 2.0

	return 0.0


static func _diameter_ratio_from_text(text: String, reference_diameter_km: float) -> float:
	var lower := text.strip_edges().to_lower()

	if lower.is_empty() or lower == "unknown":
		return 0.0

	var value := _parse_strict_number_value(lower)

	if value <= 0.0:
		return 0.0

	if lower.contains("earth"):
		if is_equal_approx(reference_diameter_km, EARTH_DIAMETER_KM):
			return value

		return (value * EARTH_DIAMETER_KM) / reference_diameter_km

	if lower.contains("sun") or lower.contains("solar"):
		if is_equal_approx(reference_diameter_km, SUN_DIAMETER_KM):
			return value

		return (value * SUN_DIAMETER_KM) / reference_diameter_km

	return value / reference_diameter_km


static func _parse_strict_number_value(text: String) -> float:
	var clean := text.strip_edges().to_lower()

	clean = clean.replace("≈", "")
	clean = clean.replace("~", "")
	clean = clean.replace("km", "")
	clean = clean.replace("kilometers", "")
	clean = clean.replace("kilometres", "")
	clean = clean.replace("diameter", "")
	clean = clean.replace("diameters", "")
	clean = clean.replace("radius", "")
	clean = clean.replace("radii", "")
	clean = clean.replace("earths", "")
	clean = clean.replace("earth", "")
	clean = clean.replace("suns", "")
	clean = clean.replace("sun", "")
	clean = clean.replace("solar", "")
	clean = clean.strip_edges()

	var sci := _parse_scientific_notation(clean)

	if sci > 0.0:
		return sci

	clean = _normalize_strict_plain_number(clean)

	var regex := RegEx.new()
	var err := regex.compile("[-+]?[0-9]*\\.?[0-9]+")

	if err != OK:
		return 0.0

	var match := regex.search(clean)

	if match == null:
		return 0.0

	return float(match.get_string())


static func _parse_scientific_notation(text: String) -> float:
	var clean := _normalize_scientific_text(text)

	if not _looks_like_scientific_notation(clean):
		return 0.0

	var e_regex := RegEx.new()
	var e_err := e_regex.compile("([-+]?[0-9]*\\.?[0-9]+)\\s*e\\s*([-+]?[0-9]+)")

	if e_err == OK:
		var e_match := e_regex.search(clean)

		if e_match != null:
			var base := float(e_match.get_string(1))
			var exponent := int(e_match.get_string(2))
			return base * pow(10.0, exponent)

	var x_regex := RegEx.new()
	var x_err := x_regex.compile("([-+]?[0-9]*\\.?[0-9]+)?\\s*x\\s*10\\s*\\^?\\s*([-+]?[0-9]+)")

	if x_err == OK:
		var x_match := x_regex.search(clean)

		if x_match != null:
			var base_text := x_match.get_string(1)
			var base := 1.0

			if not base_text.strip_edges().is_empty():
				base = float(base_text)

			var exponent := int(x_match.get_string(2))
			return base * pow(10.0, exponent)

	var caret_regex := RegEx.new()
	var caret_err := caret_regex.compile("([-+]?[0-9]*\\.?[0-9]+)?\\s*10\\s*\\^\\s*([-+]?[0-9]+)")

	if caret_err == OK:
		var caret_match := caret_regex.search(clean)

		if caret_match != null:
			var caret_base_text := caret_match.get_string(1)
			var caret_base := 1.0

			if not caret_base_text.strip_edges().is_empty():
				caret_base = float(caret_base_text)

			var caret_exponent := int(caret_match.get_string(2))
			return caret_base * pow(10.0, caret_exponent)

	return 0.0


static func _looks_like_scientific_notation(text: String) -> bool:
	var clean := text.strip_edges().to_lower()

	return (
		clean.contains("e")
		or clean.contains("x10")
		or clean.contains("*10")
		or clean.contains("×10")
		or clean.contains("10^")
	)


static func _normalize_scientific_text(text: String) -> String:
	var clean := text.strip_edges().to_lower()

	clean = clean.replace("×", "x")
	clean = clean.replace("·", "x")
	clean = clean.replace("*", "x")
	clean = clean.replace("−", "-")
	clean = clean.replace(",", "")

	clean = clean.replace("⁰", "0")
	clean = clean.replace("¹", "1")
	clean = clean.replace("²", "2")
	clean = clean.replace("³", "3")
	clean = clean.replace("⁴", "4")
	clean = clean.replace("⁵", "5")
	clean = clean.replace("⁶", "6")
	clean = clean.replace("⁷", "7")
	clean = clean.replace("⁸", "8")
	clean = clean.replace("⁹", "9")
	clean = clean.replace("⁻", "-")

	clean = clean.replace("x 10 ^", "x10^")
	clean = clean.replace("x10 ^", "x10^")
	clean = clean.replace("x 10^", "x10^")
	clean = clean.replace(" x ", "x")
	clean = clean.replace(" e ", "e")

	return clean


static func _normalize_strict_plain_number(text: String) -> String:
	var clean := text.strip_edges()

	var comma_thousands := RegEx.new()

	if comma_thousands.compile("\\b\\d{1,3}(?:,\\d{3})+\\b") == OK:
		var match := comma_thousands.search(clean)

		if match != null:
			return match.get_string().replace(",", "")

	return clean.replace(",", "")


static func _fallback_planet_ratio_from_card_identity(planet_data: PlanetData) -> float:
	if planet_data == null:
		return FALLBACK_TERRESTRIAL_RATIO

	var category := _normalized(planet_data.object_category)
	var preset := _normalized(planet_data.planet_preset)
	var archetype := _normalized(planet_data.archetype_id)

	if category == "black_hole" or preset == "black_hole" or archetype == "black_hole":
		return FALLBACK_BLACK_HOLE_RATIO

	if category == "moon" or category == "satellite" or preset == "moon" or archetype.contains("moon"):
		return FALLBACK_MOON_RATIO

	if category == "dwarf_planet" or archetype.contains("dwarf"):
		return FALLBACK_DWARF_RATIO

	if preset == "gas_planet" or preset == "gas_giant_1" or preset == "gas_giant_2" or archetype.contains("gas"):
		return FALLBACK_GAS_RATIO

	if preset == "ringed_gas_planet":
		return FALLBACK_GAS_RATIO * 1.05

	if preset == "ice_world" or archetype.contains("ice"):
		return FALLBACK_ICE_RATIO

	return FALLBACK_TERRESTRIAL_RATIO


static func _fallback_star_ratio_from_card_identity(planet_data: PlanetData) -> float:
	if planet_data == null:
		return FALLBACK_STAR_RATIO

	var name := _normalized(planet_data.name)
	var description := _normalized(planet_data.description)
	var subtitle := _normalized(planet_data.subtitle)

	var text := "%s %s %s" % [name, subtitle, description]

	if text.contains("uy_scuti") or text.contains("largest"):
		return 1700.0

	if text.contains("hypergiant"):
		return 1000.0

	if text.contains("supergiant"):
		return 500.0

	if text.contains("giant"):
		return 120.0

	if text.contains("dwarf"):
		return 0.25

	if text.contains("sun"):
		return 1.0

	return FALLBACK_STAR_RATIO


static func _max_planet_radius_from_data(planet_data: PlanetData, ratio: float) -> float:
	if planet_data == null:
		return MAX_SCENE_RADIUS

	var category := _normalized(planet_data.object_category)
	var preset := _normalized(planet_data.planet_preset)
	var archetype := _normalized(planet_data.archetype_id)

	if category == "black_hole" or preset == "black_hole" or archetype == "black_hole":
		return 560.0

	if ratio >= 8.0:
		return 360.0

	if ratio >= 3.0:
		return 310.0

	if ratio <= 0.35:
		return 118.0

	return 260.0


static func _max_star_radius_from_data(planet_data: PlanetData, sun_ratio: float) -> float:
	if planet_data == null:
		return MAX_STAR_RADIUS

	if sun_ratio >= 1000.0:
		return 1900.0

	if sun_ratio >= 300.0:
		return 1600.0

	if sun_ratio >= 80.0:
		return 1350.0

	if sun_ratio >= 10.0:
		return 1050.0

	if sun_ratio <= 0.5:
		return 620.0

	return 900.0


static func _is_star(planet_data: PlanetData) -> bool:
	if planet_data == null:
		return false

	var category := _normalized(planet_data.object_category)
	var preset := _normalized(planet_data.planet_preset)
	var archetype := _normalized(planet_data.archetype_id)

	return category == "star" or preset == "star" or archetype == "star"


static func _normalized(value: String) -> String:
	return value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")

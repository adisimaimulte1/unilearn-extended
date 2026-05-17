extends RefCounted
class_name SimulationPlanetFactory

const SIMULATION_PLANET_DATA_SCRIPT := preload("res://addons/UnilearnLib/physics/SimulationPlanetData.gd")
const SIMULATION_PLANET_BODY_SCRIPT := preload("res://addons/UnilearnLib/physics/SimulationPlanetBody.gd")
const SCALE_UTILS := preload("res://addons/UnilearnLib/physics/SimulationScaleUtils.gd")


static func create_body_from_planet_data(planet_data: PlanetData, space_position: Vector2) -> SimulationPlanetBody:
	if planet_data == null:
		return null

	var simulation_data: SimulationPlanetData = create_data_from_planet_data(planet_data, space_position)

	var body: SimulationPlanetBody = SIMULATION_PLANET_BODY_SCRIPT.new()
	body.setup(simulation_data)

	return body


static func create_data_from_planet_data(planet_data: PlanetData, space_position: Vector2) -> SimulationPlanetData:
	var data: SimulationPlanetData = SIMULATION_PLANET_DATA_SCRIPT.new()

	data.source_planet_data = planet_data
	data.source_card_id = _card_key(planet_data)
	data.instance_id = _make_instance_id(planet_data)

	data.position = space_position
	data.previous_position = space_position
	data.velocity = Vector2.ZERO
	data.acceleration = Vector2.ZERO

	var scene_radius := SCALE_UTILS.calculate_scene_radius(planet_data)
	data.radius_world = scene_radius
	data.visual_radius_px = scene_radius

	data.mass = _estimate_mass_from_planet_data(planet_data)

	data.orbit_parent_id = ""
	data.orbit_radius = 0.0
	data.orbit_clockwise = true

	data.is_static_anchor = false
	data.is_dragging = false

	if data.has_method("reset_trail"):
		data.reset_trail()

	return data


static func _card_key(planet_data: PlanetData) -> String:
	if planet_data == null:
		return ""

	var id := str(planet_data.instance_id).strip_edges()

	if id.is_empty():
		id = str(planet_data.archetype_id).strip_edges()

	if id.is_empty():
		id = str(planet_data.name).strip_edges().to_lower().replace(" ", "_")

	return id


static func _make_instance_id(planet_data: PlanetData) -> String:
	var base := _card_key(planet_data)

	if base.is_empty():
		base = "planet"

	return "sim_%s_%s" % [base, str(Time.get_ticks_usec())]


static func _estimate_mass_from_planet_data(planet_data: PlanetData) -> float:
	if planet_data == null:
		return 1.0

	var category := str(planet_data.object_category).strip_edges().to_lower().replace(" ", "_")
	var preset := str(planet_data.planet_preset).strip_edges().to_lower().replace(" ", "_")
	var archetype := str(planet_data.archetype_id).strip_edges().to_lower().replace(" ", "_")
	var name := str(planet_data.name).strip_edges().to_lower()

	if category == "black_hole" or preset == "black_hole" or archetype == "black_hole":
		return 6500.0

	if category == "star" or preset == "star" or archetype == "star":
		if name.contains("sun"):
			return 1800.0

		return 2200.0

	if category == "moon" or category == "satellite" or preset == "moon" or archetype.contains("moon"):
		return 1.0

	if preset == "gas_planet" or preset == "gas_giant_1" or preset == "gas_giant_2" or preset == "ringed_gas_planet" or archetype.contains("gas"):
		return 90.0

	if preset == "ice_world" or archetype.contains("ice"):
		return 45.0

	if category == "dwarf_planet" or archetype.contains("dwarf"):
		return 2.5

	return 15.0

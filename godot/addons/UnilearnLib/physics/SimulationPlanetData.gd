extends Resource
class_name SimulationPlanetData

# ============================================================
# Live simulation data for one placed planet/star/moon/etc.
# ------------------------------------------------------------
# PlanetData remains the reusable card/encyclopedia definition.
# This resource is the live instance placed in the simulation.
# ============================================================

enum BodyKind {
	UNKNOWN,
	PLANET,
	MOON,
	STAR,
	BLACK_HOLE,
	GALAXY,
	SATELLITE,
	RINGED_PLANET
}

enum CollisionMode {
	OFF,
	MERGE,
	BOUNCE
}

var source_planet_data: PlanetData = null

@export var instance_id: String = ""
@export var source_card_id: String = ""
@export var display_name: String = "Unknown Body"
@export var body_kind: BodyKind = BodyKind.UNKNOWN

@export var position: Vector2 = Vector2.ZERO
@export var previous_position: Vector2 = Vector2.ZERO
@export var velocity: Vector2 = Vector2.ZERO
@export var acceleration: Vector2 = Vector2.ZERO
@export var previous_acceleration: Vector2 = Vector2.ZERO

@export var mass: float = 1.0
@export var density: float = 1.0
@export var radius_world: float = 80.0
@export var visual_radius_px: int = 120
@export var gravitational_influence: float = 1.0

@export var is_static_anchor: bool = false
@export var is_dragging: bool = false
@export var is_selected: bool = false
@export var collision_mode: CollisionMode = CollisionMode.MERGE

@export var orbit_parent_id: String = ""
@export var orbit_radius: float = 0.0
@export var orbit_clockwise: bool = true
@export var orbit_eccentricity: float = 0.0
@export var orbit_phase: float = 0.0
@export var orbit_locked: bool = false

@export var trail_points: PackedVector2Array = PackedVector2Array()
@export var last_trail_position: Vector2 = Vector2.INF

@export var age_seconds: float = 0.0
@export var metadata: Dictionary = {}


static func from_planet_data(planet_data: PlanetData, spawn_position: Vector2 = Vector2.ZERO) -> SimulationPlanetData:
	var body := SimulationPlanetData.new()
	body.source_planet_data = planet_data
	body.position = spawn_position
	body.previous_position = spawn_position
	body.velocity = Vector2.ZERO
	body.acceleration = Vector2.ZERO
	body.previous_acceleration = Vector2.ZERO

	if planet_data == null:
		body.instance_id = SimulationPlanetData.make_instance_id("unknown")
		return body

	body.source_card_id = _first_non_empty([planet_data.instance_id, planet_data.archetype_id, planet_data.name])
	body.instance_id = SimulationPlanetData.make_instance_id(body.source_card_id)
	body.display_name = planet_data.name
	body.body_kind = SimulationPlanetData.kind_from_planet_data(planet_data)
	body.visual_radius_px = planet_data.planet_radius_px
	body.radius_world = max(float(planet_data.planet_radius_px), 8.0)
	body.mass = SimulationPlanetData.estimate_mass_from_planet_data(planet_data)
	body.density = SimulationPlanetData.estimate_density_from_kind(body.body_kind)
	body.gravitational_influence = SimulationPlanetData.estimate_gravity_influence(body.body_kind)
	body.collision_mode = CollisionMode.MERGE

	body.metadata = {
		"object_category": planet_data.object_category,
		"planet_preset": planet_data.planet_preset,
		"planet_seed": planet_data.planet_seed,
		"parent_object": planet_data.parent_object,
		"mass_text": planet_data.mass,
		"gravity_text": planet_data.gravity,
		"diameter_text": planet_data.diameter_km,
		"orbital_period_text": planet_data.orbital_period,
		"distance_text": planet_data.distance_from_sun
	}

	return body


static func make_instance_id(base: String) -> String:
	var safe := String(base).strip_edges().to_lower().replace(" ", "_").replace("/", "_").replace("\\", "_")
	if safe == "":
		safe = "body"
	return "%s_%s_%s" % [safe, str(Time.get_ticks_usec()), str(randi() % 100000)]


static func kind_from_planet_data(planet_data: PlanetData) -> BodyKind:
	if planet_data == null:
		return BodyKind.UNKNOWN

	var category := planet_data.object_category.to_lower()
	var preset := planet_data.planet_preset.to_lower()
	var name_text := planet_data.name.to_lower()

	if category.find("black") >= 0 or preset.find("black_hole") >= 0:
		return BodyKind.BLACK_HOLE
	if category.find("star") >= 0 or preset == "star":
		return BodyKind.STAR
	if category.find("galaxy") >= 0 or preset == "galaxy":
		return BodyKind.GALAXY
	if category.find("moon") >= 0 or name_text.find("moon") >= 0:
		return BodyKind.MOON
	if category.find("satellite") >= 0:
		return BodyKind.SATELLITE
	if preset.find("ringed") >= 0:
		return BodyKind.RINGED_PLANET
	if category.find("planet") >= 0:
		return BodyKind.PLANET

	return BodyKind.UNKNOWN


static func estimate_mass_from_planet_data(planet_data: PlanetData) -> float:
	if planet_data == null:
		return 1.0

	var parsed := parse_mass_text_to_game_mass(planet_data.mass)
	if parsed > 0.0:
		return parsed

	var kind := kind_from_planet_data(planet_data)
	match kind:
		BodyKind.BLACK_HOLE:
			return 12000.0
		BodyKind.STAR:
			return 1400.0
		BodyKind.GALAXY:
			return 50000.0
		BodyKind.RINGED_PLANET:
			return 70.0
		BodyKind.PLANET:
			if planet_data.planet_preset.to_lower().find("gas") >= 0:
				return 85.0
			return 12.0
		BodyKind.MOON:
			return 1.2
		BodyKind.SATELLITE:
			return 0.03
		_:
			return 1.0


static func parse_mass_text_to_game_mass(text: String) -> float:
	var t := text.strip_edges().to_lower()
	if t == "":
		return -1.0

	var number := _extract_first_float(t)
	if number <= 0.0:
		return -1.0

	# Game-scale conversion. Earth mass roughly maps to 12.
	if t.find("earth") >= 0:
		return max(number * 12.0, 0.01)
	if t.find("jupiter") >= 0:
		return max(number * 3800.0, 0.01)
	if t.find("solar") >= 0 or t.find("sun") >= 0:
		return max(number * 1400.0, 0.01)
	if t.find("moon") >= 0:
		return max(number * 1.2, 0.01)
	if t.find("kg") >= 0:
		# Supports strings like 5.97×10^24 kg or 5.97e24 kg.
		var kg := _parse_scientificish_number(t)
		if kg > 0.0:
			return clamp((kg / 5.972e24) * 12.0, 0.001, 100000.0)

	return -1.0


static func _parse_scientificish_number(t: String) -> float:
	var cleaned := t.replace("×", "e").replace("x10^", "e").replace("*10^", "e")
	cleaned = cleaned.replace(" ", "")
	var regex := RegEx.new()
	regex.compile("[-+]?[0-9]*\\.?[0-9]+(?:e[-+]?[0-9]+)?")
	var result := regex.search(cleaned)
	if result == null:
		return -1.0
	return float(result.get_string())


static func _extract_first_float(text: String) -> float:
	var regex := RegEx.new()
	regex.compile("[-+]?[0-9]*\\.?[0-9]+")
	var result := regex.search(text)
	if result == null:
		return -1.0
	return float(result.get_string())


static func estimate_density_from_kind(kind: BodyKind) -> float:
	match kind:
		BodyKind.BLACK_HOLE:
			return 1000.0
		BodyKind.STAR:
			return 0.6
		BodyKind.GALAXY:
			return 0.001
		BodyKind.RINGED_PLANET:
			return 0.35
		BodyKind.PLANET:
			return 1.0
		BodyKind.MOON:
			return 0.85
		BodyKind.SATELLITE:
			return 2.0
		_:
			return 1.0


static func estimate_gravity_influence(kind: BodyKind) -> float:
	match kind:
		BodyKind.BLACK_HOLE:
			return 4.5
		BodyKind.STAR:
			return 2.5
		BodyKind.GALAXY:
			return 8.0
		BodyKind.RINGED_PLANET:
			return 1.1
		BodyKind.PLANET:
			return 1.0
		BodyKind.MOON:
			return 0.4
		BodyKind.SATELLITE:
			return 0.05
		_:
			return 1.0


static func _first_non_empty(values: Array) -> String:
	for value in values:
		var text := String(value).strip_edges()
		if text != "":
			return text
	return "body"


func get_display_name() -> String:
	if display_name != "":
		return display_name
	if source_planet_data != null:
		return source_planet_data.name
	return "Unknown Body"


func get_planet_preset() -> String:
	if source_planet_data != null:
		return source_planet_data.planet_preset
	return "terran_wet"


func get_planet_seed() -> int:
	if source_planet_data != null:
		return source_planet_data.planet_seed
	return 0


func get_planet_pixels() -> int:
	if source_planet_data != null:
		return source_planet_data.planet_pixels
	return 480


func get_turning_speed() -> float:
	if source_planet_data != null:
		return source_planet_data.planet_turning_speed
	return 1.0


func get_axial_tilt_deg() -> float:
	if source_planet_data != null:
		return source_planet_data.planet_axial_tilt_deg
	return 0.0


func get_ring_angle_deg() -> float:
	if source_planet_data != null:
		return source_planet_data.planet_ring_angle_deg
	return 0.0


func clear_forces() -> void:
	previous_acceleration = acceleration
	acceleration = Vector2.ZERO


func add_acceleration(value: Vector2) -> void:
	acceleration += value


func apply_impulse(impulse: Vector2) -> void:
	if mass <= 0.0:
		return
	velocity += impulse / mass


func teleport(new_position: Vector2, clear_velocity: bool = false) -> void:
	position = new_position
	previous_position = new_position
	if clear_velocity:
		velocity = Vector2.ZERO
		acceleration = Vector2.ZERO
		previous_acceleration = Vector2.ZERO


func record_trail_point(max_points: int, min_distance: float) -> void:
	if max_points <= 0:
		trail_points.clear()
		return

	if last_trail_position != Vector2.INF and position.distance_to(last_trail_position) < min_distance:
		return

	trail_points.append(position)
	last_trail_position = position

	while trail_points.size() > max_points:
		trail_points.remove_at(0)


func reset_trail() -> void:
	trail_points.clear()
	last_trail_position = Vector2.INF


func get_collision_radius(config: SimulationPhysicsConfig = null) -> float:
	var scale := 0.72
	if config != null:
		scale = config.collision_radius_scale
	return max(radius_world * scale, 4.0)


func clone_runtime() -> SimulationPlanetData:
	var c := duplicate(true) as SimulationPlanetData
	c.source_planet_data = source_planet_data
	return c

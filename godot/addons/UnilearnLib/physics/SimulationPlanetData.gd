extends Resource
class_name SimulationPlanetData

enum BodyKind { UNKNOWN, PLANET, MOON, STAR, BLACK_HOLE, GALAXY, SATELLITE, RINGED_PLANET, WHITE_HOLE }
enum CollisionMode { OFF, MERGE, BOUNCE }

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
@export var max_orbit_speed: float = 900.0
@export var preferred_orbit_speed: float = 360.0
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
	if planet_data == null:
		body.instance_id = make_instance_id("unknown")
		return body
	body.source_card_id = _first_non_empty([planet_data.instance_id, planet_data.archetype_id, planet_data.name])
	body.instance_id = make_instance_id(body.source_card_id)
	body.display_name = planet_data.name
	body.body_kind = kind_from_planet_data(planet_data)
	body.visual_radius_px = planet_data.planet_radius_px
	body.radius_world = max(float(planet_data.planet_radius_px), 8.0)
	body.mass = estimate_mass_from_planet_data(planet_data)
	body.density = estimate_density_from_kind(body.body_kind)
	body.gravitational_influence = estimate_gravity_influence(body.body_kind)
	body.max_orbit_speed = estimate_max_orbit_speed_from_planet_data(planet_data, body)
	body.preferred_orbit_speed = body.max_orbit_speed * 0.42
	body.collision_mode = CollisionMode.MERGE
	var hero_main_color := Color.WHITE
	if planet_data.has_method("get_hero_main_color"):
		var resolved = planet_data.call("get_hero_main_color")
		if resolved is Color: hero_main_color = resolved
	body.metadata = {
		"object_category": planet_data.object_category,
		"planet_preset": planet_data.planet_preset,
		"planet_seed": planet_data.planet_seed,
		"parent_object": planet_data.parent_object,
		"mass_text": planet_data.mass,
		"gravity_text": planet_data.gravity,
		"diameter_text": planet_data.diameter_km,
		"orbital_period_text": planet_data.orbital_period,
		"rotation_period_text": planet_data.rotation_period,
		"distance_text": planet_data.distance_from_sun,
		"hero_main_color": hero_main_color,
		"hero_main_color_hex": hero_main_color.to_html(true),
		"gravity_polarity": "attractive",
		"is_fictional": planet_data.is_fictional,
	}
	return body

static func make_instance_id(base: String) -> String:
	var safe := String(base).strip_edges().to_lower().replace(" ", "_").replace("/", "_").replace("\\", "_")
	if safe == "": safe = "body"
	return "%s_%s_%s" % [safe, str(Time.get_ticks_usec()), str(randi() % 100000)]

static func kind_from_planet_data(planet_data: PlanetData) -> BodyKind:
	if planet_data == null: return BodyKind.UNKNOWN
	var category := planet_data.object_category.to_lower()
	var preset := planet_data.planet_preset.to_lower()
	var archetype := planet_data.archetype_id.to_lower()
	var name_text := planet_data.name.to_lower()
	if category.find("white_hole") >= 0 or preset.find("white_hole") >= 0 or archetype == "white_hole" or name_text.find("white hole") >= 0:
		return BodyKind.WHITE_HOLE
	if category.find("black") >= 0 or preset.find("black_hole") >= 0 or archetype == "black_hole" or name_text.find("black hole") >= 0:
		return BodyKind.BLACK_HOLE
	if category.find("star") >= 0 or preset == "star" or archetype == "star" or archetype.find("dwarf") >= 0:
		return BodyKind.STAR
	if category.find("galaxy") >= 0 or preset == "galaxy": return BodyKind.GALAXY
	if category.find("moon") >= 0 or category.find("satellite") >= 0 or name_text.find("moon") >= 0: return BodyKind.MOON
	if preset.find("ringed") >= 0: return BodyKind.RINGED_PLANET
	if category.find("planet") >= 0: return BodyKind.PLANET
	return BodyKind.UNKNOWN

static func estimate_mass_from_planet_data(planet_data: PlanetData) -> float:
	if planet_data == null: return 1.0
	var parsed := parse_mass_text_to_game_mass(planet_data.mass)
	if parsed > 0.0: return parsed
	match kind_from_planet_data(planet_data):
		BodyKind.WHITE_HOLE: return 9000.0
		BodyKind.BLACK_HOLE: return 12000.0
		BodyKind.STAR: return 1400.0
		BodyKind.GALAXY: return 50000.0
		BodyKind.RINGED_PLANET: return 70.0
		BodyKind.PLANET: return 85.0 if planet_data.planet_preset.to_lower().find("gas") >= 0 else 12.0
		BodyKind.MOON: return 1.2
		BodyKind.SATELLITE: return 0.03
		_: return 1.0

static func parse_mass_text_to_game_mass(text: String) -> float:
	var t := text.strip_edges().to_lower()
	if t == "": return -1.0
	var number := _extract_first_float(t)
	if number <= 0.0: return -1.0
	if t.find("earth") >= 0: return max(number * 12.0, 0.01)
	if t.find("jupiter") >= 0: return max(number * 3800.0, 0.01)
	if t.find("solar") >= 0 or t.find("sun") >= 0: return max(number * 1400.0, 0.01)
	if t.find("moon") >= 0: return max(number * 1.2, 0.01)
	if t.find("kg") >= 0:
		var kg := _parse_scientificish_number(t)
		if kg > 0.0: return clamp((kg / 5.972e24) * 12.0, 0.001, 100000.0)
	return -1.0

static func estimate_density_from_kind(kind: BodyKind) -> float:
	match kind:
		BodyKind.WHITE_HOLE: return 1000.0
		BodyKind.BLACK_HOLE: return 1000.0
		BodyKind.STAR: return 0.6
		BodyKind.GALAXY: return 0.001
		BodyKind.RINGED_PLANET: return 0.35
		BodyKind.PLANET: return 1.0
		BodyKind.MOON: return 0.85
		BodyKind.SATELLITE: return 2.0
		_: return 1.0

static func estimate_gravity_influence(kind: BodyKind) -> float:
	match kind:
		BodyKind.WHITE_HOLE: return 4.2
		BodyKind.BLACK_HOLE: return 4.5
		BodyKind.STAR: return 2.5
		BodyKind.GALAXY: return 8.0
		BodyKind.RINGED_PLANET: return 1.1
		BodyKind.PLANET: return 1.0
		BodyKind.MOON: return 0.4
		BodyKind.SATELLITE: return 0.05
		_: return 1.0

static func estimate_max_orbit_speed_from_planet_data(planet_data: PlanetData, body: SimulationPlanetData) -> float:
	var mass_factor := sqrt(max(body.mass, 0.05)) * 28.0
	var radius_factor := sqrt(max(body.radius_world, 8.0)) * 18.0
	var base_speed := 260.0 + mass_factor + radius_factor
	match body.body_kind:
		BodyKind.STAR: base_speed *= 0.72
		BodyKind.BLACK_HOLE, BodyKind.WHITE_HOLE: base_speed *= 0.55
		BodyKind.MOON: base_speed *= 1.34
		BodyKind.SATELLITE: base_speed *= 1.7
		BodyKind.RINGED_PLANET: base_speed *= 0.96
	return clamp(base_speed, 120.0, 3600.0)

static func _extract_first_float(text: String) -> float:
	var regex := RegEx.new(); regex.compile("[-+]?[0-9]*\\.?[0-9]+")
	var result := regex.search(text)
	return -1.0 if result == null else float(result.get_string())
static func _parse_scientificish_number(t: String) -> float:
	var cleaned := t.replace("×", "e").replace("x10^", "e").replace("*10^", "e").replace(" ", "")
	var regex := RegEx.new(); regex.compile("[-+]?[0-9]*\\.?[0-9]+(?:e[-+]?[0-9]+)?")
	var result := regex.search(cleaned)
	return -1.0 if result == null else float(result.get_string())
static func _first_non_empty(values: Array) -> String:
	for value in values:
		var text := String(value).strip_edges()
		if text != "": return text
	return "body"
func get_display_name() -> String: return display_name if display_name != "" else (source_planet_data.name if source_planet_data != null else "Unknown Body")
func get_hero_main_color() -> Color: return source_planet_data.get_hero_main_color() if source_planet_data != null and source_planet_data.has_method("get_hero_main_color") else Color(str(metadata.get("hero_main_color_hex", "#ffffff")))
func get_planet_preset() -> String: return source_planet_data.planet_preset if source_planet_data != null else "terran_wet"
func get_planet_seed() -> int: return source_planet_data.planet_seed if source_planet_data != null else 0
func get_planet_pixels() -> int: return source_planet_data.planet_pixels if source_planet_data != null else 480
func get_turning_speed() -> float: return source_planet_data.planet_turning_speed if source_planet_data != null else 1.0
func get_axial_tilt_deg() -> float: return source_planet_data.planet_axial_tilt_deg if source_planet_data != null else 0.0
func get_ring_angle_deg() -> float: return source_planet_data.planet_ring_angle_deg if source_planet_data != null else 0.0
func clear_forces() -> void: previous_acceleration = acceleration; acceleration = Vector2.ZERO
func add_acceleration(value: Vector2) -> void: acceleration += value
func apply_impulse(impulse: Vector2) -> void:
	if mass > 0.0: velocity += impulse / mass
func apply_human_drag_velocity(raw_velocity: Vector2, config: SimulationPhysicsConfig) -> void:
	if config == null: velocity = raw_velocity * 0.12; return
	if config.ignore_drag_throw_velocity: velocity *= config.drag_velocity_keep; return
	velocity = velocity * config.drag_velocity_keep + raw_velocity * clamp(config.human_drag_influence * config.drag_throw_strength, 0.0, 0.35)
func teleport(new_position: Vector2, clear_velocity: bool = false) -> void:
	position = new_position; previous_position = new_position
	if clear_velocity: velocity = Vector2.ZERO; acceleration = Vector2.ZERO; previous_acceleration = Vector2.ZERO
func record_trail_point(max_points: int, min_distance: float) -> void:
	if max_points < 0: trail_points.clear(); return
	var effective_min_distance: float = min_distance
	if last_trail_position != Vector2.INF and position.distance_to(last_trail_position) < effective_min_distance: return
	trail_points.append(position); last_trail_position = position
	while max_points > 0 and trail_points.size() > max_points: trail_points.remove_at(0)
func reset_trail() -> void: trail_points.clear(); last_trail_position = Vector2.INF
func get_collision_radius(config: SimulationPhysicsConfig = null) -> float: return max(radius_world * (config.collision_radius_scale if config != null else 0.72), 4.0)
func clone_runtime() -> SimulationPlanetData:
	var c := duplicate(true) as SimulationPlanetData; c.source_planet_data = source_planet_data; return c
func to_dictionary() -> Dictionary:
	return {"instance_id": instance_id, "source_card_id": source_card_id, "display_name": display_name, "body_kind": int(body_kind), "position": {"x": position.x, "y": position.y}, "previous_position": {"x": previous_position.x, "y": previous_position.y}, "velocity": {"x": velocity.x, "y": velocity.y}, "mass": mass, "density": density, "radius_world": radius_world, "visual_radius_px": visual_radius_px, "gravitational_influence": gravitational_influence, "max_orbit_speed": max_orbit_speed, "preferred_orbit_speed": preferred_orbit_speed, "is_static_anchor": is_static_anchor, "collision_mode": int(collision_mode), "orbit_parent_id": orbit_parent_id, "orbit_radius": orbit_radius, "orbit_clockwise": orbit_clockwise, "orbit_eccentricity": orbit_eccentricity, "orbit_phase": orbit_phase, "orbit_locked": orbit_locked, "age_seconds": age_seconds, "metadata": metadata}
func apply_dictionary(values: Dictionary) -> void:
	instance_id = str(values.get("instance_id", instance_id)); source_card_id = str(values.get("source_card_id", source_card_id)); display_name = str(values.get("display_name", display_name)); body_kind = int(values.get("body_kind", int(body_kind))); position = _dictionary_to_vector2(values.get("position", position), position); previous_position = _dictionary_to_vector2(values.get("previous_position", previous_position), previous_position); velocity = _dictionary_to_vector2(values.get("velocity", velocity), velocity); mass = float(values.get("mass", mass)); density = float(values.get("density", density)); radius_world = float(values.get("radius_world", radius_world)); visual_radius_px = int(values.get("visual_radius_px", visual_radius_px)); gravitational_influence = float(values.get("gravitational_influence", gravitational_influence)); max_orbit_speed = float(values.get("max_orbit_speed", max_orbit_speed)); preferred_orbit_speed = float(values.get("preferred_orbit_speed", preferred_orbit_speed)); is_static_anchor = bool(values.get("is_static_anchor", is_static_anchor)); collision_mode = int(values.get("collision_mode", int(collision_mode))); orbit_parent_id = str(values.get("orbit_parent_id", orbit_parent_id)); orbit_radius = float(values.get("orbit_radius", orbit_radius)); orbit_clockwise = bool(values.get("orbit_clockwise", orbit_clockwise)); orbit_eccentricity = float(values.get("orbit_eccentricity", orbit_eccentricity)); orbit_phase = float(values.get("orbit_phase", orbit_phase)); orbit_locked = bool(values.get("orbit_locked", orbit_locked)); age_seconds = float(values.get("age_seconds", age_seconds)); metadata = values.get("metadata", metadata) as Dictionary
static func from_dictionary(values: Dictionary) -> SimulationPlanetData:
	var body := SimulationPlanetData.new(); body.apply_dictionary(values); return body
static func _dictionary_to_vector2(value, fallback: Vector2) -> Vector2:
	if value is Vector2: return value
	if value is Dictionary: return Vector2(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)))
	return fallback

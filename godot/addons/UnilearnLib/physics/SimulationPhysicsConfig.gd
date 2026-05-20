extends Resource
class_name SimulationPhysicsConfig

const SAVE_KEYS := [
	"gravity_enabled",
	"collisions_enabled",
	"trails_enabled",
	"auto_orbit_enabled",
	"stable_orbit_mode",
	"hierarchical_orbits_enabled",
	"binary_orbits_enabled",
	"same_type_binary_enabled",
	"center_largest_body",
	"lock_planets_to_largest_body",
	"ignore_drag_throw_velocity",
	"gravitational_constant",
	"simulation_speed",
	"revolution_speed_multiplier",
	"center_anchor_strength",
	"orbit_lock_strength",
	"orbit_distance_padding",
	"orbit_spacing_multiplier",
	"moon_orbit_spacing_multiplier",
	"binary_orbit_spacing_multiplier",
	"binary_mass_similarity",
	"binary_max_distance_multiplier",
	"softening_radius",
	"max_acceleration",
	"damping_per_second",
	"min_substeps",
	"max_substeps",
	"target_substep_seconds",
	"collision_radius_scale",
	"bounce_restitution",
	"merge_velocity_loss",
	"default_collision_mode",
	"drag_velocity_keep",
	"drag_throw_strength",
	"max_drag_throw_speed",
	"human_drag_influence",
	"orbit_snap_distance",
	"max_trail_points",
	"trail_sample_distance",
	"min_visible_orbit_radius"
]

const BOOL_KEYS := [
	"gravity_enabled",
	"collisions_enabled",
	"trails_enabled",
	"auto_orbit_enabled",
	"stable_orbit_mode",
	"hierarchical_orbits_enabled",
	"binary_orbits_enabled",
	"same_type_binary_enabled",
	"center_largest_body",
	"lock_planets_to_largest_body",
	"ignore_drag_throw_velocity"
]

const INT_KEYS := [
	"min_substeps",
	"max_substeps",
	"default_collision_mode",
	"max_trail_points"
]

@export var gravity_enabled: bool = true
@export var collisions_enabled: bool = true
@export var trails_enabled: bool = true
@export var auto_orbit_enabled: bool = true

@export var stable_orbit_mode: bool = true
@export var hierarchical_orbits_enabled: bool = true
@export var binary_orbits_enabled: bool = true
@export var same_type_binary_enabled: bool = true
@export var center_largest_body: bool = true
@export var lock_planets_to_largest_body: bool = true
@export var ignore_drag_throw_velocity: bool = false

@export_range(0.0, 5000.0, 1.0) var gravitational_constant: float = 900.0
@export_range(0.05, 64.0, 0.01) var simulation_speed: float = 1.0
@export_range(0.05, 16.0, 0.01) var revolution_speed_multiplier: float = 1.0
@export_range(0.0, 1.0, 0.01) var center_anchor_strength: float = 0.45
@export_range(0.0, 1.0, 0.01) var orbit_lock_strength: float = 0.58
@export_range(0.0, 800.0, 2.0) var orbit_distance_padding: float = 140.0
@export_range(0.75, 3.0, 0.01) var orbit_spacing_multiplier: float = 1.12
@export_range(0.35, 2.0, 0.01) var moon_orbit_spacing_multiplier: float = 0.72
@export_range(0.8, 3.0, 0.01) var binary_orbit_spacing_multiplier: float = 1.28
@export_range(0.05, 1.0, 0.01) var binary_mass_similarity: float = 0.55
@export_range(2.0, 20.0, 0.1) var binary_max_distance_multiplier: float = 8.0
@export_range(1.0, 1000.0, 1.0) var softening_radius: float = 95.0
@export_range(1.0, 1000000.0, 10.0) var max_acceleration: float = 45000.0
@export_range(0.0, 0.2, 0.0001) var damping_per_second: float = 0.0012

@export_range(1, 16, 1) var min_substeps: int = 3
@export_range(1, 96, 1) var max_substeps: int = 24
@export_range(0.001, 0.05, 0.001) var target_substep_seconds: float = 0.010

@export_range(0.05, 5.0, 0.01) var collision_radius_scale: float = 0.68
@export_range(0.0, 1.0, 0.01) var bounce_restitution: float = 0.16
@export_range(0.0, 1.0, 0.01) var merge_velocity_loss: float = 0.10
@export var default_collision_mode: int = 1

@export_range(0.0, 1.0, 0.01) var drag_velocity_keep: float = 0.03
@export_range(0.0, 1.0, 0.005) var drag_throw_strength: float = 0.030
@export_range(0.0, 2500.0, 1.0) var max_drag_throw_speed: float = 300.0
@export_range(0.0, 1.0, 0.01) var human_drag_influence: float = 0.05
@export_range(8.0, 800.0, 1.0) var orbit_snap_distance: float = 260.0

@export_range(0, 20000, 1) var max_trail_points: int = 1200
@export_range(0.0, 80.0, 0.1) var trail_sample_distance: float = 12.0
@export_range(0.0, 300.0, 1.0) var min_visible_orbit_radius: float = 110.0


func get_substep_count(delta: float) -> int:
	_normalize_legacy_values()
	var scaled_delta: float = abs(delta * simulation_speed)
	if scaled_delta <= 0.0:
		return min_substeps

	var wanted: int = int(ceil(scaled_delta / max(target_substep_seconds, 0.001)))
	return clamp(wanted, min_substeps, max_substeps)


func duplicate_config() -> SimulationPhysicsConfig:
	_normalize_legacy_values()
	return duplicate(true) as SimulationPhysicsConfig


func has_config_property(property_name: String) -> bool:
	return SAVE_KEYS.has(property_name)


func to_save_dict() -> Dictionary:
	_normalize_legacy_values()
	var result := {}
	for key in SAVE_KEYS:
		if has_config_property(key):
			result[key] = get(key)
	return result


func apply_save_dict(values: Dictionary) -> void:
	for key in SAVE_KEYS:
		if values.has(key) and has_config_property(key):
			set(key, values[key])
	_normalize_legacy_values()


func apply_safe_value(property_name: String, value: Variant) -> bool:
	if not has_config_property(property_name):
		return false

	if INT_KEYS.has(property_name):
		set(property_name, int(round(float(value))))
	elif BOOL_KEYS.has(property_name):
		set(property_name, bool(value))
	else:
		set(property_name, float(value))

	_normalize_legacy_values()
	return true


func get_user_facing_name(property_name: String) -> String:
	match property_name:
		"simulation_speed":
			return "TIME SPEED"
		"revolution_speed_multiplier":
			return "ORBIT SPEED"
		"orbit_lock_strength":
			return "ORBIT STABILITY"
		"orbit_distance_padding":
			return "ORBIT SPACING"
		"center_anchor_strength":
			return "CENTER PULL"
		"gravitational_constant":
			return "GRAVITY POWER"
		"drag_throw_strength":
			return "THROW POWER"
		"max_drag_throw_speed":
			return "THROW CAP"
		"hierarchical_orbits_enabled":
			return "MOON SYSTEMS"
		"binary_orbits_enabled":
			return "BINARY ORBITS"
		_:
			return property_name.replace("_", " ").to_upper()


func get_user_facing_description(property_name: String) -> String:
	match property_name:
		"simulation_speed":
			return "How fast time passes for the whole simulation."
		"revolution_speed_multiplier":
			return "How fast bodies travel around their orbit parent."
		"orbit_lock_strength":
			return "How strongly bodies keep clean, readable orbits instead of drifting away."
		"orbit_distance_padding":
			return "Extra empty space between an object and what it orbits."
		"center_anchor_strength":
			return "How strongly the main star or heavy object is pulled back toward the center."
		"gravitational_constant":
			return "The raw strength of gravity. Higher values create stronger pulls."
		"drag_throw_strength":
			return "How much velocity a dragged body keeps when released."
		"max_drag_throw_speed":
			return "The maximum release speed after dragging, so throws do not become chaotic."
		"hierarchical_orbits_enabled":
			return "Moons prefer planets, planets prefer stars, and systems stay layered."
		"binary_orbits_enabled":
			return "Comparable bodies can orbit each other instead of only orbiting the biggest body."
		_:
			return "Simulation parameter."


func _normalize_legacy_values() -> void:
	if revolution_speed_multiplier > 32.0:
		revolution_speed_multiplier = clamp(revolution_speed_multiplier / 50.0, 0.05, 16.0)
	else:
		revolution_speed_multiplier = clamp(revolution_speed_multiplier, 0.05, 16.0)

	if orbit_lock_strength > 2.0:
		orbit_lock_strength = clamp(orbit_lock_strength / 60.0, 0.0, 1.0)
	else:
		orbit_lock_strength = clamp(orbit_lock_strength, 0.0, 1.0)

	if center_anchor_strength > 2.0:
		center_anchor_strength = clamp(center_anchor_strength / 40.0, 0.0, 1.0)
	else:
		center_anchor_strength = clamp(center_anchor_strength, 0.0, 1.0)

	gravity_enabled = bool(gravity_enabled)
	collisions_enabled = bool(collisions_enabled)
	trails_enabled = bool(trails_enabled)
	auto_orbit_enabled = bool(auto_orbit_enabled)
	stable_orbit_mode = bool(stable_orbit_mode)
	hierarchical_orbits_enabled = bool(hierarchical_orbits_enabled)
	binary_orbits_enabled = bool(binary_orbits_enabled)
	same_type_binary_enabled = bool(same_type_binary_enabled)
	center_largest_body = bool(center_largest_body)
	lock_planets_to_largest_body = bool(lock_planets_to_largest_body)
	ignore_drag_throw_velocity = bool(ignore_drag_throw_velocity)
	gravitational_constant = clamp(gravitational_constant, 0.0, 5000.0)
	simulation_speed = clamp(simulation_speed, 0.05, 64.0)
	orbit_distance_padding = clamp(orbit_distance_padding, 0.0, 800.0)
	orbit_spacing_multiplier = clamp(orbit_spacing_multiplier, 0.75, 3.0)
	moon_orbit_spacing_multiplier = clamp(moon_orbit_spacing_multiplier, 0.35, 2.0)
	binary_orbit_spacing_multiplier = clamp(binary_orbit_spacing_multiplier, 0.8, 3.0)
	binary_mass_similarity = clamp(binary_mass_similarity, 0.05, 1.0)
	binary_max_distance_multiplier = clamp(binary_max_distance_multiplier, 2.0, 20.0)
	softening_radius = clamp(softening_radius, 1.0, 1000.0)
	max_acceleration = clamp(max_acceleration, 1.0, 1000000.0)
	damping_per_second = clamp(damping_per_second, 0.0, 0.2)
	min_substeps = clamp(min_substeps, 1, 16)
	max_substeps = clamp(max_substeps, min_substeps, 96)
	target_substep_seconds = clamp(target_substep_seconds, 0.001, 0.05)
	collision_radius_scale = clamp(collision_radius_scale, 0.05, 5.0)
	bounce_restitution = clamp(bounce_restitution, 0.0, 1.0)
	merge_velocity_loss = clamp(merge_velocity_loss, 0.0, 1.0)
	default_collision_mode = clamp(default_collision_mode, 0, 2)
	drag_velocity_keep = clamp(drag_velocity_keep, 0.0, 1.0)
	drag_throw_strength = clamp(drag_throw_strength, 0.0, 1.0)
	max_drag_throw_speed = clamp(max_drag_throw_speed, 0.0, 2500.0)
	human_drag_influence = clamp(human_drag_influence, 0.0, 1.0)
	orbit_snap_distance = clamp(orbit_snap_distance, 8.0, 800.0)
	max_trail_points = clamp(max_trail_points, 0, 20000)
	trail_sample_distance = clamp(trail_sample_distance, 0.0, 80.0)
	min_visible_orbit_radius = clamp(min_visible_orbit_radius, 0.0, 300.0)

extends Resource
class_name SimulationPhysicsConfig

const SAVE_KEYS := [
	"gravity_enabled",
	"collisions_enabled",
	"trails_enabled",
	"auto_orbit_enabled",
	"stable_orbit_mode",
	"center_largest_body",
	"lock_planets_to_largest_body",
	"ignore_drag_throw_velocity",
	"gravitational_constant",
	"simulation_speed",
	"revolution_speed_multiplier",
	"center_anchor_strength",
	"orbit_lock_strength",
	"orbit_distance_padding",
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

@export var gravity_enabled: bool = true
@export var collisions_enabled: bool = true
@export var trails_enabled: bool = true
@export var auto_orbit_enabled: bool = true

@export var stable_orbit_mode: bool = true
@export var center_largest_body: bool = true
@export var lock_planets_to_largest_body: bool = true
@export var ignore_drag_throw_velocity: bool = false

@export_range(0.0, 10000.0, 1.0) var gravitational_constant: float = 1200.0
@export_range(0.001, 25.0, 0.001) var simulation_speed: float = 1.0
@export_range(0.1, 100.0, 0.1) var revolution_speed_multiplier: float = 50.05
@export_range(0.0, 40.0, 0.1) var center_anchor_strength: float = 20.0
@export_range(0.0, 60.0, 0.1) var orbit_lock_strength: float = 30.0
@export_range(0.0, 1000.0, 5.0) var orbit_distance_padding: float = 500.0
@export_range(1.0, 1000.0, 1.0) var softening_radius: float = 80.0
@export_range(1.0, 1000000.0, 10.0) var max_acceleration: float = 65000.0
@export_range(0.0001, 1.0, 0.0001) var damping_per_second: float = 0.0008

@export_range(1, 12, 1) var min_substeps: int = 2
@export_range(1, 24, 1) var max_substeps: int = 8
@export_range(0.001, 0.05, 0.001) var target_substep_seconds: float = 0.012

@export_range(0.05, 5.0, 0.01) var collision_radius_scale: float = 0.72
@export_range(0.0, 1.0, 0.01) var bounce_restitution: float = 0.18
@export_range(0.0, 1.0, 0.01) var merge_velocity_loss: float = 0.08
@export var default_collision_mode: int = 1

@export_range(0.0, 1.0, 0.01) var drag_velocity_keep: float = 0.04
@export_range(0.0, 1.0, 0.005) var drag_throw_strength: float = 0.045
@export_range(0.0, 2500.0, 1.0) var max_drag_throw_speed: float = 420.0
@export_range(0.0, 1.0, 0.01) var human_drag_influence: float = 0.08
@export_range(8.0, 400.0, 1.0) var orbit_snap_distance: float = 180.0

@export_range(0, 20000, 1) var max_trail_points: int = 0
@export_range(0.0, 60.0, 0.1) var trail_sample_distance: float = 10.0
@export_range(0.0, 200.0, 1.0) var min_visible_orbit_radius: float = 90.0


func get_substep_count(delta: float) -> int:
	var scaled_delta := abs(delta * simulation_speed)
	if scaled_delta <= 0.0:
		return min_substeps

	var wanted := int(ceil(scaled_delta / max(target_substep_seconds, 0.001)))
	return clamp(wanted, min_substeps, max_substeps)


func duplicate_config() -> SimulationPhysicsConfig:
	return duplicate(true) as SimulationPhysicsConfig


func has_config_property(property_name: String) -> bool:
	return SAVE_KEYS.has(property_name)


func to_save_dict() -> Dictionary:
	var result := {}
	for key in SAVE_KEYS:
		if has_config_property(key):
			result[key] = get(key)
	return result


func apply_save_dict(values: Dictionary) -> void:
	for key in SAVE_KEYS:
		if values.has(key) and has_config_property(key):
			set(key, values[key])


func apply_safe_value(property_name: String, value: Variant) -> bool:
	if not has_config_property(property_name):
		return false

	match property_name:
		"min_substeps", "max_substeps", "default_collision_mode", "max_trail_points":
			set(property_name, int(round(float(value))))
		"gravity_enabled", "collisions_enabled", "trails_enabled", "auto_orbit_enabled", "stable_orbit_mode", "center_largest_body", "lock_planets_to_largest_body", "ignore_drag_throw_velocity":
			set(property_name, bool(value))
		_:
			set(property_name, float(value))

	return true

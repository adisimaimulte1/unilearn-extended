extends Resource
class_name SimulationPhysicsConfig

# ============================================================
# Unilearn physics config
# ------------------------------------------------------------
# This is intentionally game-scaled, not SI-unit strict.
# The solver uses stable N-body math, but the values are tuned
# for an interactive 2D space sandbox.
# ============================================================

@export var gravity_enabled: bool = true
@export var collisions_enabled: bool = true
@export var trails_enabled: bool = true
@export var auto_orbit_enabled: bool = true

@export_range(0.0, 10000.0, 1.0) var gravitational_constant: float = 1200.0
@export_range(0.001, 25.0, 0.001) var simulation_speed: float = 1.0
@export_range(1.0, 1000.0, 1.0) var softening_radius: float = 80.0
@export_range(1.0, 1000000.0, 10.0) var max_acceleration: float = 65000.0
@export_range(0.0001, 1.0, 0.0001) var damping_per_second: float = 0.0008

# Substeps reduce orbit explosions when bodies pass close to each other.
@export_range(1, 12, 1) var min_substeps: int = 2
@export_range(1, 24, 1) var max_substeps: int = 8
@export_range(0.001, 0.05, 0.001) var target_substep_seconds: float = 0.012

# Collision / proximity behavior.
@export_range(0.05, 5.0, 0.01) var collision_radius_scale: float = 0.72
@export_range(0.0, 1.0, 0.01) var bounce_restitution: float = 0.18
@export_range(0.0, 1.0, 0.01) var merge_velocity_loss: float = 0.08
@export var default_collision_mode: int = 1 # 0 off, 1 merge, 2 bounce

# Drag interaction.
@export_range(0.0, 1.0, 0.01) var drag_velocity_keep: float = 0.0
@export_range(0.0, 5.0, 0.01) var drag_throw_strength: float = 1.0
@export_range(8.0, 400.0, 1.0) var orbit_snap_distance: float = 180.0

# Rendering helpers.
@export_range(0, 4096, 1) var max_trail_points: int = 420
@export_range(0.0, 60.0, 0.1) var trail_sample_distance: float = 8.0
@export_range(0.0, 200.0, 1.0) var min_visible_orbit_radius: float = 90.0


func get_substep_count(delta: float) -> int:
	var scaled_delta := abs(delta * simulation_speed)
	if scaled_delta <= 0.0:
		return min_substeps

	var wanted := int(ceil(scaled_delta / max(target_substep_seconds, 0.001)))
	return clamp(wanted, min_substeps, max_substeps)


func duplicate_config() -> SimulationPhysicsConfig:
	return duplicate(true) as SimulationPhysicsConfig

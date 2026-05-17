extends RefCounted
class_name SimulationTrajectoryPredictor

# Lightweight prediction copy. Useful for drawing future orbit paths
# without moving the actual simulation bodies.


static func predict_paths(
	bodies: Array,
	config: SimulationPhysicsConfig,
	seconds: float = 10.0,
	sample_count: int = 180
) -> Dictionary:
	var result: Dictionary = {}

	if bodies.is_empty() or config == null or seconds <= 0.0 or sample_count <= 0:
		return result

	var clones: Array[SimulationPlanetData] = []
	var clone_to_id: Dictionary = {}

	for body in bodies:
		if body == null or not is_instance_valid(body):
			continue

		if body.data == null:
			continue

		var c: SimulationPlanetData = body.data.clone_runtime()
		c.reset_trail()

		clones.append(c)
		clone_to_id[c] = body.data.instance_id
		result[body.data.instance_id] = PackedVector2Array()

	var local_config: SimulationPhysicsConfig = config.duplicate_config()
	local_config.trails_enabled = false
	local_config.collisions_enabled = false

	var dt: float = seconds / float(sample_count)

	for _i in range(sample_count):
		_step_data_only(clones, dt, local_config)

		for c: SimulationPlanetData in clones:
			var id: String = str(clone_to_id[c])

			if not result.has(id):
				result[id] = PackedVector2Array()

			var arr: PackedVector2Array = result[id] as PackedVector2Array
			arr.append(c.position)
			result[id] = arr

	return result


static func _step_data_only(
	clones: Array[SimulationPlanetData],
	delta: float,
	config: SimulationPhysicsConfig
) -> void:
	for c: SimulationPlanetData in clones:
		c.clear_forces()

	for i in range(clones.size()):
		var a: SimulationPlanetData = clones[i]

		if a == null or a.is_static_anchor:
			continue

		for j in range(clones.size()):
			if i == j:
				continue

			var b: SimulationPlanetData = clones[j]

			if b == null:
				continue

			a.add_acceleration(
				SimulationGravitySolver.acceleration_from_to(a, b, config)
			)

	for c: SimulationPlanetData in clones:
		if c == null or c.is_static_anchor:
			continue

		c.velocity += c.acceleration * delta
		c.position += c.velocity * delta

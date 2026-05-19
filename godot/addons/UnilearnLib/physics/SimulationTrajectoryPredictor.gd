extends RefCounted
class_name SimulationTrajectoryPredictor

class _PredictionBody:
	extends RefCounted
	var data: SimulationPlanetData = null

	func _init(next_data: SimulationPlanetData) -> void:
		data = next_data

	func sync_from_data() -> void:
		pass


static func predict_paths(
	bodies: Array,
	config: SimulationPhysicsConfig,
	seconds: float = 10.0,
	sample_count: int = 180
) -> Dictionary:
	var result: Dictionary = {}

	if bodies.is_empty() or config == null or seconds <= 0.0 or sample_count <= 0:
		return result

	var wrappers: Array = []
	var clone_to_id: Dictionary = {}

	for body in bodies:
		if body == null or not is_instance_valid(body):
			continue

		if body.data == null:
			continue

		var c: SimulationPlanetData = body.data.clone_runtime()
		c.reset_trail()
		c.is_dragging = false

		var wrapper := _PredictionBody.new(c)
		wrappers.append(wrapper)
		clone_to_id[wrapper] = body.data.instance_id
		result[body.data.instance_id] = PackedVector2Array()

	var local_config: SimulationPhysicsConfig = config.duplicate_config()
	local_config.trails_enabled = false
	local_config.collisions_enabled = false
	local_config.max_trail_points = 0

	var dt: float = seconds / float(sample_count)

	for _i in range(sample_count):
		SimulationGravitySolver.step(wrappers, dt, local_config)

		for wrapper in wrappers:
			if wrapper == null or wrapper.data == null:
				continue

			var id: String = str(clone_to_id.get(wrapper, ""))
			if id.is_empty():
				continue

			if not result.has(id):
				result[id] = PackedVector2Array()

			var arr: PackedVector2Array = result[id] as PackedVector2Array
			arr.append(wrapper.data.position)
			result[id] = arr

	return result

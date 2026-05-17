extends RefCounted
class_name SimulationGravitySolver

# ============================================================
# Stable N-body solver using velocity Verlet integration.
# ------------------------------------------------------------
# Supports arbitrary stars, planets, moons, satellites, and
# black holes. This is game-scaled but physically consistent:
# acceleration from each body is G * mass / distance^2.
# ============================================================

static func step(bodies: Array, delta: float, config: SimulationPhysicsConfig) -> void:
	if bodies.is_empty() or config == null:
		return

	var substeps := config.get_substep_count(delta)
	var h := (delta * config.simulation_speed) / float(substeps)

	for _s in range(substeps):
		_step_verlet(bodies, h, config)


static func compute_accelerations(bodies: Array, config: SimulationPhysicsConfig) -> void:
	for body in bodies:
		if _valid_body(body):
			body.data.clear_forces()

	for i in range(bodies.size()):
		var a = bodies[i]
		if not _valid_body(a):
			continue
		if a.data.is_static_anchor or a.data.is_dragging:
			continue

		for j in range(bodies.size()):
			if i == j:
				continue

			var b = bodies[j]
			if not _valid_body(b):
				continue

			var acc := acceleration_from_to(a.data, b.data, config)
			a.data.add_acceleration(acc)


static func acceleration_from_to(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> Vector2:
	if a == null or b == null or config == null:
		return Vector2.ZERO

	var dir := b.position - a.position
	var dist_sq := dir.length_squared()
	if dist_sq <= 0.0001:
		return Vector2.ZERO

	var softened := max(dist_sq, config.softening_radius * config.softening_radius)
	var mass_factor: float = max(b.mass, 0.0) * max(b.gravitational_influence, 0.0)
	var magnitude: float = config.gravitational_constant * mass_factor / softened
	magnitude = min(magnitude, config.max_acceleration)
	return dir.normalized() * magnitude


static func potential_energy_pair(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if a == null or b == null or config == null:
		return 0.0
	var r := max(a.position.distance_to(b.position), config.softening_radius)
	return -config.gravitational_constant * a.mass * b.mass / r


static func kinetic_energy(body: SimulationPlanetData) -> float:
	if body == null:
		return 0.0
	return 0.5 * body.mass * body.velocity.length_squared()


static func total_energy(bodies: Array, config: SimulationPhysicsConfig) -> float:
	var e := 0.0
	for body in bodies:
		if _valid_body(body):
			e += kinetic_energy(body.data)
	for i in range(bodies.size()):
		for j in range(i + 1, bodies.size()):
			if _valid_body(bodies[i]) and _valid_body(bodies[j]):
				e += potential_energy_pair(bodies[i].data, bodies[j].data, config)
	return e


static func _step_verlet(bodies: Array, h: float, config: SimulationPhysicsConfig) -> void:
	compute_accelerations(bodies, config)

	for body in bodies:
		if not _valid_body(body):
			continue
		var d: SimulationPlanetData = body.data
		if d.is_static_anchor or d.is_dragging:
			continue

		d.previous_position = d.position
		d.position += d.velocity * h + 0.5 * d.acceleration * h * h

	var old_accels := {}
	for body in bodies:
		if _valid_body(body):
			old_accels[body] = body.data.acceleration

	compute_accelerations(bodies, config)

	for body in bodies:
		if not _valid_body(body):
			continue
		var d: SimulationPlanetData = body.data
		if d.is_static_anchor or d.is_dragging:
			continue

		var old_a: Vector2 = old_accels.get(body, Vector2.ZERO)
		d.velocity += 0.5 * (old_a + d.acceleration) * h

		if config.damping_per_second > 0.0:
			var damping := pow(max(0.0, 1.0 - config.damping_per_second), abs(h))
			d.velocity *= damping

		d.age_seconds += abs(h)
		d.record_trail_point(config.max_trail_points if config.trails_enabled else 0, config.trail_sample_distance)
		body.sync_from_data()


static func _valid_body(body) -> bool:
	return body != null and is_instance_valid(body) and body.data != null

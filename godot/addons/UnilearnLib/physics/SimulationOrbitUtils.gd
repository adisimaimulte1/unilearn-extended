extends RefCounted
class_name SimulationOrbitUtils

# ============================================================
# Orbit tools.
# ------------------------------------------------------------
# These helpers set initial velocity for stable circular/elliptic
# orbits. The gravity solver then continues normally, so nearby
# bodies can still deviate the path.
# ============================================================

static func make_circular_orbit(body, parent, config: SimulationPhysicsConfig, clockwise: bool = true, radius_override: float = -1.0) -> bool:
	if not _valid_pair(body, parent, config):
		return false

	var offset: Vector2 = body.data.position - parent.data.position
	var radius := radius_override if radius_override > 0.0 else offset.length()
	radius = max(radius, config.min_visible_orbit_radius)

	if offset.length() < 0.001:
		offset = Vector2(radius, 0.0)
	else:
		offset = offset.normalized() * radius

	body.data.position = parent.data.position + offset
	var tangent := Vector2(-offset.y, offset.x).normalized()
	if clockwise:
		tangent *= -1.0

	var speed := circular_orbit_speed(parent.data.mass, radius, config)
	body.data.velocity = parent.data.velocity + tangent * speed
	body.data.orbit_parent_id = parent.data.instance_id
	body.data.orbit_radius = radius
	body.data.orbit_clockwise = clockwise
	body.data.orbit_eccentricity = 0.0
	body.data.orbit_locked = false
	body.data.reset_trail()
	body.sync_from_data()
	return true


static func make_elliptical_orbit(body, parent, config: SimulationPhysicsConfig, eccentricity: float = 0.25, clockwise: bool = true) -> bool:
	if not _valid_pair(body, parent, config):
		return false

	eccentricity = clamp(eccentricity, 0.0, 0.85)
	var offset: Vector2 = body.data.position - parent.data.position
	var radius := max(offset.length(), config.min_visible_orbit_radius)
	if offset.length() < 0.001:
		offset = Vector2(radius, 0.0)

	var semi_major: float = radius / max(1.0 - eccentricity, 0.01)
	var tangent := Vector2(-offset.y, offset.x).normalized()
	if clockwise:
		tangent *= -1.0

	var mu: float = config.gravitational_constant * max(parent.data.mass, 0.001)
	var speed := sqrt(max(mu * (2.0 / radius - 1.0 / semi_major), 0.0))

	body.data.velocity = parent.data.velocity + tangent * speed
	body.data.orbit_parent_id = parent.data.instance_id
	body.data.orbit_radius = radius
	body.data.orbit_clockwise = clockwise
	body.data.orbit_eccentricity = eccentricity
	body.data.orbit_locked = false
	body.data.reset_trail()
	return true


static func create_mutual_binary_orbit(a, b, config: SimulationPhysicsConfig, clockwise: bool = true, separation_override: float = -1.0) -> bool:
	if not _valid_pair(a, b, config):
		return false

	var total_mass := max(a.data.mass + b.data.mass, 0.001)
	var offset: Vector2 = b.data.position - a.data.position
	var separation := separation_override if separation_override > 0.0 else offset.length()
	separation = max(separation, config.min_visible_orbit_radius * 2.0)
	if offset.length() < 0.001:
		offset = Vector2(separation, 0.0)
	else:
		offset = offset.normalized() * separation

	var center: Vector2 = (a.data.position * a.data.mass + b.data.position * b.data.mass) / total_mass
	var ra: float = separation * (b.data.mass / total_mass)
	var rb: float = separation * (a.data.mass / total_mass)

	a.data.position = center - offset.normalized() * ra
	b.data.position = center + offset.normalized() * rb

	var tangent := Vector2(-offset.y, offset.x).normalized()
	if clockwise:
		tangent *= -1.0

	var omega := sqrt(config.gravitational_constant * total_mass / pow(separation, 3.0))
	a.data.velocity = -tangent * omega * ra
	b.data.velocity = tangent * omega * rb

	a.data.orbit_parent_id = b.data.instance_id
	b.data.orbit_parent_id = a.data.instance_id
	a.data.orbit_radius = ra
	b.data.orbit_radius = rb
	a.data.orbit_clockwise = clockwise
	b.data.orbit_clockwise = clockwise
	a.data.reset_trail()
	b.data.reset_trail()
	a.sync_from_data()
	b.sync_from_data()
	return true


static func create_triple_star_stable(inner_a, inner_b, outer_c, config: SimulationPhysicsConfig, clockwise: bool = true) -> bool:
	if not create_mutual_binary_orbit(inner_a, inner_b, config, clockwise):
		return false

	if outer_c == null or not is_instance_valid(outer_c) or outer_c.data == null:
		return false

	var center := get_center_of_mass([inner_a, inner_b])
	var offset: Vector2 = outer_c.data.position - center
	var radius := max(offset.length(), config.min_visible_orbit_radius * 4.0)
	if offset.length() < 0.001:
		offset = Vector2(radius, 0.0)
	outer_c.data.position = center + offset.normalized() * radius

	var virtual_parent := SimulationPlanetData.new()
	virtual_parent.instance_id = "virtual_binary_center"
	virtual_parent.position = center
	virtual_parent.velocity = get_center_of_mass_velocity([inner_a, inner_b])
	virtual_parent.mass = inner_a.data.mass + inner_b.data.mass

	var fake = {"data": virtual_parent}
	var tangent := Vector2(-offset.y, offset.x).normalized()
	if clockwise:
		tangent *= -1.0
	var speed := circular_orbit_speed(virtual_parent.mass, radius, config)
	outer_c.data.velocity = virtual_parent.velocity + tangent * speed
	outer_c.data.orbit_parent_id = virtual_parent.instance_id
	outer_c.data.orbit_radius = radius
	outer_c.data.orbit_clockwise = clockwise
	outer_c.data.reset_trail()
	outer_c.sync_from_data()
	return true


static func circular_orbit_speed(parent_mass: float, radius: float, config: SimulationPhysicsConfig) -> float:
	return sqrt(max(config.gravitational_constant * max(parent_mass, 0.001) / max(radius, 1.0), 0.0))


static func escape_velocity(parent_mass: float, radius: float, config: SimulationPhysicsConfig) -> float:
	return sqrt(max(2.0 * config.gravitational_constant * max(parent_mass, 0.001) / max(radius, 1.0), 0.0))


static func find_best_orbit_parent(body, candidates: Array, max_distance: float = 900.0):
	if body == null or not is_instance_valid(body) or body.data == null:
		return null

	var best = null
	var best_score := INF
	for candidate in candidates:
		if candidate == body or candidate == null or not is_instance_valid(candidate) or candidate.data == null:
			continue

		var dist: float = body.data.position.distance_to(candidate.data.position)
		if dist > max_distance:
			continue

		var mass_bias := max(candidate.data.mass, 0.001)
		var score := dist / sqrt(mass_bias)
		if score < best_score:
			best_score = score
			best = candidate

	return best


static func get_center_of_mass(bodies: Array) -> Vector2:
	var total_mass := 0.0
	var center := Vector2.ZERO
	for body in bodies:
		if body == null or not is_instance_valid(body) or body.data == null:
			continue
		center += body.data.position * body.data.mass
		total_mass += body.data.mass
	if total_mass <= 0.0:
		return Vector2.ZERO
	return center / total_mass


static func get_center_of_mass_velocity(bodies: Array) -> Vector2:
	var total_mass := 0.0
	var v := Vector2.ZERO
	for body in bodies:
		if body == null or not is_instance_valid(body) or body.data == null:
			continue
		v += body.data.velocity * body.data.mass
		total_mass += body.data.mass
	if total_mass <= 0.0:
		return Vector2.ZERO
	return v / total_mass


static func _valid_pair(a, b, config: SimulationPhysicsConfig) -> bool:
	return a != null and b != null and config != null and is_instance_valid(a) and is_instance_valid(b) and a.data != null and b.data != null and a != b

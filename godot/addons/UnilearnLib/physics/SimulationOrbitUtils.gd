extends RefCounted
class_name SimulationOrbitUtils

const ANCHOR_TARGET := Vector2.ZERO

static func make_circular_orbit(body, parent, config: SimulationPhysicsConfig, clockwise: bool = true, radius_override: float = -1.0, reset_trail: bool = false) -> bool:
	if not _valid_pair(body, parent, config):
		return false

	var offset: Vector2 = body.data.position - parent.data.position
	var radius: float = radius_override if radius_override > 0.0 else offset.length()
	radius = max(radius, minimum_orbit_radius(body.data, parent.data, config))

	if offset.length_squared() < 0.001:
		offset = _stable_direction(body.data.instance_id) * radius
	else:
		offset = offset.normalized() * radius

	body.data.position = parent.data.position + offset
	body.data.previous_position = body.data.position

	var tangent: Vector2 = Vector2(-offset.y, offset.x).normalized()
	if clockwise:
		tangent *= -1.0

	var speed: float = circular_orbit_speed(parent.data.mass * parent.data.gravitational_influence, radius, config)
	speed *= config.revolution_speed_multiplier
	speed = min(speed, _max_orbit_speed(body.data))

	body.data.velocity = parent.data.velocity + tangent * speed
	body.data.orbit_parent_id = parent.data.instance_id
	body.data.orbit_radius = radius
	body.data.orbit_clockwise = clockwise
	body.data.orbit_eccentricity = 0.0
	body.data.orbit_locked = config.stable_orbit_mode
	if reset_trail:
		body.data.reset_trail()
	body.sync_from_data()
	return true


static func prepare_soft_circular_orbit(body, parent, config: SimulationPhysicsConfig, clockwise: bool = true, radius_override: float = -1.0, blend_velocity: bool = true) -> bool:
	if not _valid_pair(body, parent, config):
		return false

	var offset: Vector2 = body.data.position - parent.data.position
	var radius: float = radius_override if radius_override > 0.0 else offset.length()
	radius = max(radius, minimum_orbit_radius(body.data, parent.data, config))

	var direction: Vector2 = offset.normalized() if offset.length_squared() >= 0.001 else _stable_direction(body.data.instance_id)
	var tangent: Vector2 = Vector2(-direction.y, direction.x).normalized()
	if clockwise:
		tangent *= -1.0

	var speed: float = circular_orbit_speed(parent.data.mass * parent.data.gravitational_influence, radius, config)
	speed *= config.revolution_speed_multiplier
	speed = min(speed, _max_orbit_speed(body.data))
	var desired_velocity: Vector2 = parent.data.velocity + tangent * speed

	body.data.orbit_parent_id = parent.data.instance_id
	body.data.orbit_radius = radius
	body.data.orbit_clockwise = clockwise
	body.data.orbit_eccentricity = 0.0
	body.data.orbit_locked = config.stable_orbit_mode
	body.data.metadata["orbit_architecture_dirty"] = false

	if blend_velocity:
		var blend: float = 0.34 if config.stable_orbit_mode else 0.16
		body.data.velocity = body.data.velocity.lerp(desired_velocity, blend)
	elif body.data.velocity.length_squared() < 1.0:
		body.data.velocity = desired_velocity * 0.42

	body.sync_from_data()
	return true


static func make_elliptical_orbit(body, parent, config: SimulationPhysicsConfig, eccentricity: float = 0.25, clockwise: bool = true, reset_trail: bool = false) -> bool:
	if not _valid_pair(body, parent, config):
		return false

	eccentricity = clamp(eccentricity, 0.0, 0.85)
	var offset: Vector2 = body.data.position - parent.data.position
	var radius: float = max(offset.length(), minimum_orbit_radius(body.data, parent.data, config))
	if offset.length_squared() < 0.001:
		offset = _stable_direction(body.data.instance_id) * radius

	var semi_major: float = radius / max(1.0 - eccentricity, 0.01)
	var tangent: Vector2 = Vector2(-offset.y, offset.x).normalized()
	if clockwise:
		tangent *= -1.0

	var mu: float = config.gravitational_constant * max(parent.data.mass * parent.data.gravitational_influence, 0.001)
	var speed: float = sqrt(max(mu * (2.0 / radius - 1.0 / semi_major), 0.0))
	speed *= config.revolution_speed_multiplier
	speed = min(speed, _max_orbit_speed(body.data))

	body.data.velocity = parent.data.velocity + tangent * speed
	body.data.orbit_parent_id = parent.data.instance_id
	body.data.orbit_radius = radius
	body.data.orbit_clockwise = clockwise
	body.data.orbit_eccentricity = eccentricity
	body.data.orbit_locked = config.stable_orbit_mode
	if reset_trail:
		body.data.reset_trail()
	body.sync_from_data()
	return true


static func create_mutual_binary_orbit(a, b, config: SimulationPhysicsConfig, clockwise: bool = true, separation_override: float = -1.0, reset_trail: bool = false, lock_center_to_screen: bool = false) -> bool:
	if not _valid_pair(a, b, config):
		return false

	var total_mass: float = max(a.data.mass + b.data.mass, 0.001)
	var offset: Vector2 = b.data.position - a.data.position
	var separation: float = separation_override if separation_override > 0.0 else offset.length()
	separation = max(separation, minimum_binary_separation(a.data, b.data, config))

	if offset.length_squared() < 0.001:
		offset = _stable_direction(a.data.instance_id + b.data.instance_id) * separation
	else:
		offset = offset.normalized() * separation

	var direction: Vector2 = offset.normalized()
	var center: Vector2 = (a.data.position * a.data.mass + b.data.position * b.data.mass) / total_mass
	var ra: float = separation * (b.data.mass / total_mass)
	var rb: float = separation * (a.data.mass / total_mass)

	a.data.position = center - direction * ra
	b.data.position = center + direction * rb
	a.data.previous_position = a.data.position
	b.data.previous_position = b.data.position

	var tangent: Vector2 = Vector2(-direction.y, direction.x)
	if clockwise:
		tangent *= -1.0

	var omega: float = sqrt(config.gravitational_constant * total_mass / pow(separation, 3.0))	
	omega *= config.revolution_speed_multiplier

	var center_velocity: Vector2 = get_center_of_mass_velocity([a, b])
	a.data.velocity = center_velocity - tangent * omega * ra
	b.data.velocity = center_velocity + tangent * omega * rb

	a.data.orbit_parent_id = b.data.instance_id
	b.data.orbit_parent_id = a.data.instance_id
	a.data.orbit_radius = separation
	b.data.orbit_radius = separation
	a.data.orbit_clockwise = clockwise
	b.data.orbit_clockwise = clockwise
	a.data.orbit_locked = config.stable_orbit_mode
	b.data.orbit_locked = config.stable_orbit_mode
	a.data.metadata["binary_partner_id"] = b.data.instance_id
	b.data.metadata["binary_partner_id"] = a.data.instance_id
	a.data.metadata["binary_center_locked"] = lock_center_to_screen
	b.data.metadata["binary_center_locked"] = lock_center_to_screen
	if reset_trail:
		a.data.reset_trail()
		b.data.reset_trail()
	a.sync_from_data()
	b.sync_from_data()
	return true


static func prepare_soft_mutual_binary_orbit(a, b, config: SimulationPhysicsConfig, clockwise: bool = true, separation_override: float = -1.0, lock_center_to_screen: bool = false) -> bool:
	if not _valid_pair(a, b, config):
		return false

	var total_mass: float = max(a.data.mass + b.data.mass, 0.001)
	var offset: Vector2 = b.data.position - a.data.position
	var current_separation: float = offset.length()
	var target_separation: float = separation_override if separation_override > 0.0 else current_separation
	target_separation = max(target_separation, minimum_binary_separation(a.data, b.data, config))

	var direction: Vector2 = offset.normalized() if offset.length_squared() >= 0.001 else _stable_direction(a.data.instance_id + b.data.instance_id)
	var tangent: Vector2 = Vector2(-direction.y, direction.x).normalized()
	if clockwise:
		tangent *= -1.0

	var ra: float = target_separation * (b.data.mass / total_mass)
	var rb: float = target_separation * (a.data.mass / total_mass)
	var omega: float = sqrt(config.gravitational_constant * total_mass / pow(max(target_separation, 1.0), 3.0))
	omega *= config.revolution_speed_multiplier

	var center_velocity: Vector2 = get_center_of_mass_velocity([a, b])	
	var desired_a_velocity: Vector2 = center_velocity - tangent * omega * ra
	var desired_b_velocity: Vector2 = center_velocity + tangent * omega * rb

	var blend: float = 0.10 if config.stable_orbit_mode else 0.04
	if a.data.velocity.length_squared() < 1.0 and b.data.velocity.length_squared() < 1.0:
		blend = 0.18 if config.stable_orbit_mode else 0.07

	a.data.velocity = a.data.velocity.lerp(desired_a_velocity, blend)
	b.data.velocity = b.data.velocity.lerp(desired_b_velocity, blend)

	a.data.orbit_parent_id = b.data.instance_id
	b.data.orbit_parent_id = a.data.instance_id
	a.data.orbit_radius = target_separation
	b.data.orbit_radius = target_separation
	a.data.orbit_clockwise = clockwise
	b.data.orbit_clockwise = clockwise
	a.data.orbit_locked = config.stable_orbit_mode
	b.data.orbit_locked = config.stable_orbit_mode
	a.data.metadata["binary_partner_id"] = b.data.instance_id
	b.data.metadata["binary_partner_id"] = a.data.instance_id
	a.data.metadata["binary_center_locked"] = lock_center_to_screen
	b.data.metadata["binary_center_locked"] = lock_center_to_screen
	a.data.metadata["orbit_architecture_dirty"] = false
	b.data.metadata["orbit_architecture_dirty"] = false
	return true


static func create_triple_star_stable(inner_a, inner_b, outer_c, config: SimulationPhysicsConfig, clockwise: bool = true, reset_trail: bool = false) -> bool:
	if not create_mutual_binary_orbit(inner_a, inner_b, config, clockwise, -1.0, reset_trail, true):
		return false

	if outer_c == null or not is_instance_valid(outer_c) or outer_c.data == null:
		return false

	var center: Vector2 = get_center_of_mass([inner_a, inner_b])
	var offset: Vector2 = outer_c.data.position - center
	var radius: float = max(offset.length(), config.min_visible_orbit_radius * 4.0)
	if offset.length_squared() < 0.001:
		offset = _stable_direction(outer_c.data.instance_id) * radius
	outer_c.data.position = center + offset.normalized() * radius
	outer_c.data.previous_position = outer_c.data.position

	var virtual_parent := SimulationPlanetData.new()
	virtual_parent.instance_id = "virtual_binary_center"
	virtual_parent.position = center
	virtual_parent.velocity = get_center_of_mass_velocity([inner_a, inner_b])
	virtual_parent.mass = inner_a.data.mass + inner_b.data.mass
	virtual_parent.gravitational_influence = 1.0

	var tangent: Vector2 = Vector2(-offset.y, offset.x).normalized()
	if clockwise:
		tangent *= -1.0
	var speed: float = circular_orbit_speed(virtual_parent.mass, radius, config) * config.revolution_speed_multiplier
	outer_c.data.velocity = virtual_parent.velocity + tangent * min(speed, _max_orbit_speed(outer_c.data))
	outer_c.data.orbit_parent_id = virtual_parent.instance_id
	outer_c.data.orbit_radius = radius
	outer_c.data.orbit_clockwise = clockwise
	outer_c.data.orbit_locked = config.stable_orbit_mode
	if reset_trail:
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
	var best_score: float = INF
	for candidate in candidates:
		if candidate == body or candidate == null or not is_instance_valid(candidate) or candidate.data == null:
			continue

		var dist: float = body.data.position.distance_to(candidate.data.position)
		if dist > max_distance:
			continue

		var mass_bias: float = max(candidate.data.mass, 0.001)
		var score: float = dist / sqrt(mass_bias)
		if score < best_score:
			best_score = score
			best = candidate

	return best


static func minimum_orbit_radius(body: SimulationPlanetData, parent: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if body == null or parent == null or config == null:
		return 120.0

	var spacing: float = max(config.orbit_spacing_multiplier, 0.01)
	var base_clearance: float = parent.radius_world + body.radius_world + config.orbit_distance_padding

	if _is_moon_like(body):
		spacing *= max(config.moon_orbit_spacing_multiplier, 0.01)
		base_clearance = parent.radius_world + body.radius_world + config.orbit_distance_padding * 0.44
	elif _is_star_like(body) and _is_star_like(parent):
		spacing *= max(config.binary_orbit_spacing_multiplier, 0.01)

	return max(
		config.min_visible_orbit_radius,
		base_clearance * spacing
	)


static func minimum_binary_separation(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if a == null or b == null or config == null:
		return 220.0

	var spacing: float = max(config.binary_orbit_spacing_multiplier, 0.01)
	var base_clearance: float = a.radius_world + b.radius_world + config.orbit_distance_padding * 0.62

	var center_pull: float = clamp(config.center_anchor_strength, 0.0, 1.0)
	var center_compression: float = lerp(1.0, 0.62, pow(center_pull, 0.72))
	var safe_clearance: float = a.radius_world + b.radius_world + max(config.min_visible_orbit_radius * 0.36, 28.0)
	var target: float = base_clearance * spacing * center_compression

	return max(
		safe_clearance,
		config.min_visible_orbit_radius * 1.18,
		target
	)


static func are_good_binary_partners(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> bool:
	if a == null or b == null or config == null:
		return false
	if not config.binary_orbits_enabled:
		return false
	if not config.same_type_binary_enabled:
		return false
	if _is_moon_like(a) or _is_moon_like(b):
		return false
	if not _same_orbit_family(a, b):
		return false

	var smaller: float = min(max(a.mass, 0.001), max(b.mass, 0.001))
	var larger: float = max(max(a.mass, 0.001), max(b.mass, 0.001))
	var required_similarity: float = clamp(config.binary_mass_similarity, 0.02, 1.0)

	var absorbed_a := int(a.metadata.get("absorbed_count", 0))
	var absorbed_b := int(b.metadata.get("absorbed_count", 0))
	if absorbed_a > 0 or absorbed_b > 0:
		required_similarity *= 0.38

	if _is_star_like(a) and _is_star_like(b):
		required_similarity *= 0.42

	required_similarity = clamp(required_similarity, 0.08, 1.0)

	if smaller / larger < required_similarity:
		return false

	var max_distance_multiplier: float = config.binary_max_distance_multiplier
	if absorbed_a > 0 or absorbed_b > 0:
		max_distance_multiplier = max(max_distance_multiplier, config.binary_max_distance_multiplier * 1.35)

	var max_distance: float = minimum_binary_separation(a, b, config) * max_distance_multiplier
	return a.position.distance_to(b.position) <= max_distance


static func get_center_of_mass(bodies: Array) -> Vector2:
	var total_mass: float = 0.0
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
	var total_mass: float = 0.0
	var v := Vector2.ZERO
	for body in bodies:
		if body == null or not is_instance_valid(body) or body.data == null:
			continue
		v += body.data.velocity * body.data.mass
		total_mass += body.data.mass
	if total_mass <= 0.0:
		return Vector2.ZERO
	return v / total_mass


static func _max_orbit_speed(d: SimulationPlanetData) -> float:
	if d == null:
		return 1800.0
	return max(d.max_orbit_speed * 4.0, 80.0)


static func _same_orbit_family(a: SimulationPlanetData, b: SimulationPlanetData) -> bool:
	if _is_star_like(a) and _is_star_like(b):
		return true
	if _is_planet_like(a) and _is_planet_like(b):
		return true
	return int(a.body_kind) == int(b.body_kind)


static func _is_star_like(d: SimulationPlanetData) -> bool:
	if d == null:
		return false
	return d.body_kind == SimulationPlanetData.BodyKind.STAR or d.body_kind == SimulationPlanetData.BodyKind.BLACK_HOLE or d.body_kind == SimulationPlanetData.BodyKind.GALAXY


static func _is_planet_like(d: SimulationPlanetData) -> bool:
	if d == null:
		return false
	return d.body_kind == SimulationPlanetData.BodyKind.PLANET or d.body_kind == SimulationPlanetData.BodyKind.RINGED_PLANET


static func _is_moon_like(d: SimulationPlanetData) -> bool:
	if d == null:
		return false
	return d.body_kind == SimulationPlanetData.BodyKind.MOON or d.body_kind == SimulationPlanetData.BodyKind.SATELLITE


static func _stable_direction(seed: String) -> Vector2:
	var angle: float = float(abs(hash(seed)) % 6283) / 1000.0
	return Vector2.RIGHT.rotated(angle).normalized()


static func _valid_pair(a, b, config: SimulationPhysicsConfig) -> bool:
	return a != null and b != null and config != null and is_instance_valid(a) and is_instance_valid(b) and a.data != null and b.data != null and a != b

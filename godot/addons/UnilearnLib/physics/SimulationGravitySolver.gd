extends RefCounted
class_name SimulationGravitySolver

const ANCHOR_TARGET := Vector2.ZERO
const MAX_ORBIT_SPEED_FALLBACK := 1800.0
const MIN_HOST_DISTANCE := 120.0
const BINARY_PARTNER_KEY := "binary_partner_id"
const ARCHITECTURE_DIRTY_KEY := "orbit_architecture_dirty"
const BINARY_CENTER_LOCKED_KEY := "binary_center_locked"


static func step(bodies: Array, delta: float, config: SimulationPhysicsConfig) -> void:
	if bodies.is_empty() or config == null:
		return

	prime_orbit_architecture(bodies, config, false)

	var substeps: int = config.get_substep_count(delta)
	var h: float = (delta * config.simulation_speed) / float(substeps)

	for _s in range(substeps):
		_step_verlet(bodies, h, config)


static func prime_orbit_architecture(bodies: Array, config: SimulationPhysicsConfig, force_reseed: bool = false) -> void:
	if bodies.is_empty() or config == null:
		return

	_clear_invalid_binary_links(bodies, config)
	_build_binary_links(bodies, config)
	_prepare_orbit_architecture(bodies, config, force_reseed)


static func mark_orbit_architecture_dirty(bodies: Array, clear_binary_links: bool = true) -> void:
	for body in bodies:
		if not _valid_body(body):
			continue

		var d: SimulationPlanetData = body.data
		d.metadata[ARCHITECTURE_DIRTY_KEY] = true

		if clear_binary_links:
			d.metadata.erase(BINARY_PARTNER_KEY)
			d.metadata.erase(BINARY_CENTER_LOCKED_KEY)

		d.is_static_anchor = false
		d.orbit_locked = false


static func compute_accelerations(bodies: Array, config: SimulationPhysicsConfig) -> void:
	for body in bodies:
		if _valid_body(body):
			body.data.clear_forces()

	for i in range(bodies.size()):
		var a = bodies[i]
		if not _valid_body(a):
			continue

		var ad: SimulationPlanetData = a.data
		if ad.is_dragging:
			continue

		if ad.is_static_anchor:
			if config.center_largest_body:
				_apply_center_anchor_force(ad, config)
			continue

		if config.gravity_enabled:
			for j in range(bodies.size()):
				if i == j:
					continue

				var b = bodies[j]
				if not _valid_body(b):
					continue

				ad.add_acceleration(acceleration_from_to(ad, b.data, config))

		if config.stable_orbit_mode:
			_apply_orbit_lock_force(ad, bodies, config)

	_apply_locked_binary_center_forces(bodies, config)


static func acceleration_from_to(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> Vector2:
	if a == null or b == null or config == null:
		return Vector2.ZERO

	var dir: Vector2 = b.position - a.position
	var dist_sq: float = dir.length_squared()
	if dist_sq <= 0.0001:
		return Vector2.ZERO

	var softened: float = max(dist_sq, config.softening_radius * config.softening_radius)
	var mass_factor: float = max(b.mass, 0.0) * max(b.gravitational_influence, 0.0)
	var magnitude: float = config.gravitational_constant * mass_factor / softened
	magnitude = min(magnitude, config.max_acceleration)
	return dir.normalized() * magnitude


static func potential_energy_pair(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if a == null or b == null or config == null:
		return 0.0
	var r: float = max(a.position.distance_to(b.position), config.softening_radius)
	return -config.gravitational_constant * a.mass * b.mass / r


static func kinetic_energy(body: SimulationPlanetData) -> float:
	if body == null:
		return 0.0
	return 0.5 * body.mass * body.velocity.length_squared()


static func total_energy(bodies: Array, config: SimulationPhysicsConfig) -> float:
	var e: float = 0.0
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
		if d.is_dragging:
			_continue_dragged_body(body, config)
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
		if d.is_dragging:
			_continue_dragged_body(body, config)
			continue

		var old_a: Vector2 = old_accels.get(body, Vector2.ZERO)
		d.velocity += 0.5 * (old_a + d.acceleration) * h
		_limit_velocity_for_orbit(d, config)

		if config.damping_per_second > 0.0:
			var damping: float = pow(max(0.0, 1.0 - config.damping_per_second), abs(h))
			d.velocity *= damping

		d.age_seconds += abs(h)
		d.record_trail_point(config.max_trail_points if config.trails_enabled else -1, config.trail_sample_distance)
		body.sync_from_data()


static func _prepare_orbit_architecture(bodies: Array, config: SimulationPhysicsConfig, force_reseed: bool = false) -> void:
	var anchor = _largest_anchor_body(bodies)
	var binary_members: Dictionary = _collect_binary_members(bodies)

	for body in bodies:
		if not _valid_body(body):
			continue

		var d: SimulationPlanetData = body.data
		d.is_static_anchor = false

		if config.center_largest_body and body == anchor and not binary_members.has(d.instance_id):
			d.is_static_anchor = true
			d.orbit_parent_id = ""
			d.orbit_locked = false
			continue

		if not config.hierarchical_orbits_enabled:
			continue

		var host = _choose_orbit_host(body, bodies, anchor, config)
		if host == null or not _valid_body(host):
			continue

		var host_data: SimulationPlanetData = host.data
		var previous_host_id: String = d.orbit_parent_id
		var previous_radius: float = d.orbit_radius
		var target_radius: float = _target_orbit_radius(d, host_data, config)

		d.orbit_parent_id = host_data.instance_id

		var needs_seed: bool = force_reseed or previous_host_id != host_data.instance_id or previous_radius <= 0.0 or bool(d.metadata.get(ARCHITECTURE_DIRTY_KEY, false))
		d.orbit_radius = target_radius

		if needs_seed and config.stable_orbit_mode and not _is_binary_member(d):
			_seed_orbit_velocity(d, host_data, target_radius, config)

		if needs_seed:
			d.metadata.erase(ARCHITECTURE_DIRTY_KEY)

		d.orbit_locked = config.stable_orbit_mode and (_is_moon_like(d) or _is_binary_member(d) or config.lock_planets_to_largest_body)


static func _build_binary_links(bodies: Array, config: SimulationPhysicsConfig) -> void:
	if config == null or not config.binary_orbits_enabled or not config.same_type_binary_enabled:
		return

	var used := {}

	for body in bodies:
		if not _valid_body(body):
			continue
		var d: SimulationPlanetData = body.data
		if _is_binary_member(d):
			used[d.instance_id] = true
			var partner = _find_body_by_id(bodies, str(d.metadata.get(BINARY_PARTNER_KEY, "")))
			if _valid_body(partner):
				var center_locked := _should_lock_binary_center_to_screen(body, partner, bodies, config)
				d.metadata[BINARY_CENTER_LOCKED_KEY] = center_locked
				partner.data.metadata[BINARY_CENTER_LOCKED_KEY] = center_locked

	for body in bodies:
		if not _valid_body(body):
			continue

		var a: SimulationPlanetData = body.data
		if used.has(a.instance_id) or _is_moon_like(a):
			continue

		var best = null
		var best_dist: float = INF

		for candidate in bodies:
			if candidate == body or not _valid_body(candidate):
				continue

			var b: SimulationPlanetData = candidate.data
			if used.has(b.instance_id) or _is_moon_like(b):
				continue

			if not SimulationOrbitUtils.are_good_binary_partners(a, b, config):
				continue

			var dist: float = a.position.distance_to(b.position)
			if dist < best_dist:
				best_dist = dist
				best = candidate

		if best != null and _valid_body(best):
			var bd: SimulationPlanetData = best.data
			a.metadata[BINARY_PARTNER_KEY] = bd.instance_id
			bd.metadata[BINARY_PARTNER_KEY] = a.instance_id
			a.metadata[ARCHITECTURE_DIRTY_KEY] = true
			bd.metadata[ARCHITECTURE_DIRTY_KEY] = true
			used[a.instance_id] = true
			used[bd.instance_id] = true
			var lock_center := _should_lock_binary_center_to_screen(body, best, bodies, config)
			a.is_static_anchor = false
			bd.is_static_anchor = false
			SimulationOrbitUtils.prepare_soft_mutual_binary_orbit(
				body,
				best,
				config,
				a.orbit_clockwise,
				max(best_dist, SimulationOrbitUtils.minimum_binary_separation(a, bd, config)),
				lock_center
			)


static func _clear_invalid_binary_links(bodies: Array, config: SimulationPhysicsConfig) -> void:
	var id_map := {}
	for body in bodies:
		if _valid_body(body):
			id_map[body.data.instance_id] = body

	for body in bodies:
		if not _valid_body(body):
			continue

		var d: SimulationPlanetData = body.data
		if not d.metadata.has(BINARY_PARTNER_KEY):
			continue

		var partner_id: String = str(d.metadata.get(BINARY_PARTNER_KEY, ""))
		if not id_map.has(partner_id):
			_clear_binary_link_for_body(d)
			continue

		var partner = id_map[partner_id]
		if not _valid_body(partner):
			_clear_binary_link_for_body(d)
			continue

		var partner_data: SimulationPlanetData = partner.data
		if str(partner_data.metadata.get(BINARY_PARTNER_KEY, "")) != d.instance_id:
			_clear_binary_link_for_body(d)
			_clear_binary_link_for_body(partner_data)
			continue

		if not SimulationOrbitUtils.are_good_binary_partners(d, partner_data, config):
			_clear_binary_link_for_body(d)
			_clear_binary_link_for_body(partner_data)


static func _clear_binary_link_for_body(d: SimulationPlanetData) -> void:
	if d == null:
		return

	d.metadata.erase(BINARY_PARTNER_KEY)
	d.metadata.erase(BINARY_CENTER_LOCKED_KEY)
	d.metadata[ARCHITECTURE_DIRTY_KEY] = true
	d.orbit_locked = false
	d.is_static_anchor = false


static func _collect_binary_members(bodies: Array) -> Dictionary:
	var result := {}
	for body in bodies:
		if _valid_body(body) and _is_binary_member(body.data):
			result[body.data.instance_id] = true
	return result


static func _should_lock_binary_center_to_screen(a_body, b_body, bodies: Array, config: SimulationPhysicsConfig) -> bool:
	if config == null or not config.center_largest_body:
		return false
	if not _valid_body(a_body) or not _valid_body(b_body):
		return false

	var a: SimulationPlanetData = a_body.data
	var b: SimulationPlanetData = b_body.data
	var pair_score: float = _anchor_score(a) + _anchor_score(b)
	var best_external_score: float = -INF

	for body in bodies:
		if body == a_body or body == b_body or not _valid_body(body):
			continue
		best_external_score = max(best_external_score, _anchor_score(body.data))

	return pair_score >= best_external_score


static func _apply_locked_binary_center_forces(bodies: Array, config: SimulationPhysicsConfig) -> void:
	if config == null or not config.center_largest_body:
		return

	var handled := {}
	var pull_strength: float = clamp(config.center_anchor_strength, 0.0, 1.0)
	if pull_strength <= 0.0:
		return

	for body in bodies:
		if not _valid_body(body):
			continue

		var a: SimulationPlanetData = body.data
		if handled.has(a.instance_id):
			continue
		if not bool(a.metadata.get(BINARY_CENTER_LOCKED_KEY, false)):
			continue

		var partner_id: String = str(a.metadata.get(BINARY_PARTNER_KEY, ""))
		var partner = _find_body_by_id(bodies, partner_id)
		if not _valid_body(partner):
			continue

		var b: SimulationPlanetData = partner.data
		if not bool(b.metadata.get(BINARY_CENTER_LOCKED_KEY, false)):
			continue

		var total_mass: float = max(a.mass + b.mass, 0.001)
		var center: Vector2 = (a.position * a.mass + b.position * b.mass) / total_mass
		var center_velocity: Vector2 = (a.velocity * a.mass + b.velocity * b.mass) / total_mass
		var to_center: Vector2 = ANCHOR_TARGET - center

		var spring: float = 0.22 + pull_strength * 0.86
		var damping: float = 0.12 + pull_strength * 0.24
		var center_accel: Vector2 = to_center * spring - center_velocity * damping
		var max_accel: float = 150.0 + pull_strength * 820.0
		if center_accel.length() > max_accel:
			center_accel = center_accel.normalized() * max_accel

		a.add_acceleration(center_accel)
		b.add_acceleration(center_accel)

		handled[a.instance_id] = true
		handled[b.instance_id] = true


static func _anchor_score(d: SimulationPlanetData) -> float:
	if d == null:
		return 0.0

	var role_bonus: float = 1.0
	if _is_star_like(d):
		role_bonus = 10.0
	elif _is_planet_like(d):
		role_bonus = 2.0
	elif _is_moon_like(d):
		role_bonus = 0.35

	return d.mass * max(d.gravitational_influence, 0.001) * role_bonus


static func _largest_anchor_body(bodies: Array):
	var best = null
	var best_mass: float = -INF

	for body in bodies:
		if not _valid_body(body):
			continue

		var d: SimulationPlanetData = body.data
		var weighted_mass: float = _anchor_score(d)

		if weighted_mass > best_mass:
			best_mass = weighted_mass
			best = body

	return best


static func _choose_orbit_host(body, bodies: Array, anchor, config: SimulationPhysicsConfig):
	if not _valid_body(body):
		return anchor

	var d: SimulationPlanetData = body.data
	var binary_partner_id: String = str(d.metadata.get(BINARY_PARTNER_KEY, ""))
	if not binary_partner_id.is_empty():
		var partner = _find_body_by_id(bodies, binary_partner_id)
		if _valid_body(partner):
			return partner

	if _is_moon_like(d):
		var planet_host = _best_host_by_role(body, bodies, [SimulationPlanetData.BodyKind.PLANET, SimulationPlanetData.BodyKind.RINGED_PLANET], false)
		if planet_host != null:
			return planet_host
		var moon_host = _best_host_by_role(body, bodies, [SimulationPlanetData.BodyKind.MOON], true)
		if moon_host != null:
			return moon_host
		return anchor

	if _is_planet_like(d):
		var star_host = _best_star_host(body, bodies)
		if star_host != null:
			return star_host
		return anchor

	if _is_star_like(d):
		if anchor != null and anchor != body:
			return anchor
		return null

	return anchor


static func _best_star_host(body, bodies: Array):
	var best = null
	var best_score: float = INF

	for candidate in bodies:
		if candidate == body or not _valid_body(candidate):
			continue

		var c: SimulationPlanetData = candidate.data
		if not _is_star_like(c):
			continue

		var dist: float = max(body.data.position.distance_to(c.position), MIN_HOST_DISTANCE)
		var score: float = dist / max(c.mass * c.gravitational_influence, 0.001)

		if score < best_score:
			best_score = score
			best = candidate

	return best


static func _best_host_by_role(body, bodies: Array, roles: Array, allow_lighter: bool):
	var best = null
	var best_score: float = INF

	for candidate in bodies:
		if candidate == body or not _valid_body(candidate):
			continue

		var c: SimulationPlanetData = candidate.data
		if not roles.has(c.body_kind):
			continue

		if not allow_lighter and c.mass <= body.data.mass:
			continue

		var dist: float = max(body.data.position.distance_to(c.position), MIN_HOST_DISTANCE)
		var score: float = dist / max(sqrt(max(c.mass, 0.001)), 0.001)

		if score < best_score:
			best_score = score
			best = candidate

	return best


static func _apply_center_anchor_force(d: SimulationPlanetData, config: SimulationPhysicsConfig) -> void:
	var to_center: Vector2 = ANCHOR_TARGET - d.position
	if to_center.length_squared() < 1.0:
		d.position = ANCHOR_TARGET
		d.velocity *= 0.72
		return

	var strength: float = clamp(config.center_anchor_strength, 0.0, 1.0)
	var pull: Vector2 = to_center * (strength * 0.48) - d.velocity * (strength * 0.46)
	var max_pull: float = 900.0 + strength * 2600.0
	if pull.length() > max_pull:
		pull = pull.normalized() * max_pull
	d.add_acceleration(pull)


static func _apply_orbit_lock_force(d: SimulationPlanetData, bodies: Array, config: SimulationPhysicsConfig) -> void:
	if not d.orbit_locked:
		return

	var host: Variant = _find_body_by_id(bodies, d.orbit_parent_id)
	if host == null or not _valid_body(host):
		return

	var h: SimulationPlanetData = host.data
	var radial: Vector2 = d.position - h.position
	var dist: float = max(radial.length(), 1.0)
	var target_radius: float = max(d.orbit_radius, _minimum_orbit_radius(d, h, config))
	var radius_error: float = dist - target_radius
	var radial_dir: Vector2 = radial / dist
	var tangent: Vector2 = Vector2(-radial_dir.y, radial_dir.x)
	if d.orbit_clockwise:
		tangent = -tangent

	var target_speed: float = _stable_orbit_speed(d, h, target_radius, config)
	var relative_velocity: Vector2 = d.velocity - h.velocity
	var radial_velocity: float = relative_velocity.dot(radial_dir)
	var tangential_velocity: float = relative_velocity.dot(tangent)
	var lock_strength: float = clamp(config.orbit_lock_strength, 0.0, 1.0)

	var spring_strength: float = lock_strength * 0.68
	var radial_damping_strength: float = lock_strength * 2.05
	var tangent_strength: float = lock_strength * 0.74

	if _is_binary_member(d):
		spring_strength = lock_strength * 0.24
		radial_damping_strength = lock_strength * 0.62
		tangent_strength = lock_strength * 0.24

	var radius_correction: Vector2 = -radial_dir * radius_error * spring_strength
	var radial_damping: Vector2 = -radial_dir * radial_velocity * radial_damping_strength
	var tangent_correction: Vector2 = tangent * (target_speed - tangential_velocity) * tangent_strength

	var total: Vector2 = radius_correction + radial_damping + tangent_correction
	var max_correction: float = 820.0 + lock_strength * 4200.0
	if _is_binary_member(d):
		max_correction *= 0.34
	if total.length() > max_correction:
		total = total.normalized() * max_correction
	d.add_acceleration(total)


static func _seed_orbit_velocity(d: SimulationPlanetData, host: SimulationPlanetData, radius: float, config: SimulationPhysicsConfig) -> void:
	var radial: Vector2 = d.position - host.position
	if radial.length_squared() < 0.001:
		radial = _stable_direction(d.instance_id) * radius

	var radial_dir: Vector2 = radial.normalized()
	var tangent: Vector2 = Vector2(-radial_dir.y, radial_dir.x)
	if d.orbit_clockwise:
		tangent = -tangent

	var target_speed: float = _stable_orbit_speed(d, host, radius, config)
	d.velocity = host.velocity + tangent * target_speed


static func _stable_orbit_speed(d: SimulationPlanetData, host: SimulationPlanetData, radius: float, config: SimulationPhysicsConfig) -> float:
	var host_force: float = max(host.mass, 0.001) * max(host.gravitational_influence, 0.001)
	var speed: float = sqrt(max(config.gravitational_constant * host_force / max(radius, 1.0), 0.0))
	speed *= clamp(config.revolution_speed_multiplier, 0.05, 4.0)
	return min(speed, _max_orbit_speed(d))


static func _limit_velocity_for_orbit(d: SimulationPlanetData, config: SimulationPhysicsConfig) -> void:
	if not config.stable_orbit_mode:
		return

	var max_speed: float = _max_orbit_speed(d)
	if d.velocity.length() > max_speed:
		d.velocity = d.velocity.normalized() * max_speed


static func _max_orbit_speed(d: SimulationPlanetData) -> float:
	if d == null:
		return MAX_ORBIT_SPEED_FALLBACK
	return max(d.max_orbit_speed, 80.0)


static func _target_orbit_radius(d: SimulationPlanetData, host: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if _is_binary_member(d):
		return SimulationOrbitUtils.minimum_binary_separation(d, host, config)
	return _minimum_orbit_radius(d, host, config)


static func _minimum_orbit_radius(d: SimulationPlanetData, host: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	return SimulationOrbitUtils.minimum_orbit_radius(d, host, config)


static func _find_body_by_id(bodies: Array, id: String):
	if id.is_empty():
		return null
	for body in bodies:
		if _valid_body(body) and body.data.instance_id == id:
			return body
	return null


static func _continue_dragged_body(body, config: SimulationPhysicsConfig) -> void:
	if not _valid_body(body):
		return
	var d: SimulationPlanetData = body.data
	if config.ignore_drag_throw_velocity:
		d.velocity = Vector2.ZERO
	else:
		d.velocity *= clamp(config.drag_velocity_keep, 0.0, 1.0)
	body.sync_from_data()


static func _is_binary_member(d: SimulationPlanetData) -> bool:
	return d != null and d.metadata.has(BINARY_PARTNER_KEY) and not str(d.metadata.get(BINARY_PARTNER_KEY, "")).is_empty()


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


static func _valid_body(body) -> bool:
	return body != null and is_instance_valid(body) and body.data != null

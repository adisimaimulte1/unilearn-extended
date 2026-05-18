extends RefCounted
class_name SimulationGravitySolver

const ANCHOR_TARGET := Vector2.ZERO
const MAX_ORBIT_SPEED_FALLBACK := 1800.0
const MIN_HOST_DISTANCE := 120.0
const ANCHOR_CENTER_READY_DISTANCE := 24.0
const ANCHOR_CENTER_READY_SPEED := 140.0
const ANCHOR_SWAP_GUARD_KEY := "anchor_swap_guard_host_id"
const ANCHOR_SWAP_FREE_HOST_KEY := "anchor_swap_free_host_id"


static func step(bodies: Array, delta: float, config: SimulationPhysicsConfig) -> void:
	if bodies.is_empty() or config == null:
		return

	_prepare_orbit_architecture(bodies, config)

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
		if a.data.is_dragging:
			continue

		if a.data.is_static_anchor:
			if config.center_largest_body:
				_apply_center_anchor_force(a.data, config)
			continue

		if config.gravity_enabled:
			for j in range(bodies.size()):
				if i == j:
					continue

				var b = bodies[j]
				if not _valid_body(b):
					continue

				a.data.add_acceleration(acceleration_from_to(a.data, b.data, config))

		if config.stable_orbit_mode:
			_apply_orbit_lock_force(a.data, bodies, config)

		_apply_anchor_swap_guard_force(a.data, bodies, config)


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
		_limit_velocity_for_orbit(d, bodies, config)

		if config.damping_per_second > 0.0:
			var damping := pow(max(0.0, 1.0 - config.damping_per_second), abs(h))
			d.velocity *= damping

		d.age_seconds += abs(h)
		d.record_trail_point(config.max_trail_points if config.trails_enabled else -1, config.trail_sample_distance)
		body.sync_from_data()


static func _prepare_orbit_architecture(bodies: Array, config: SimulationPhysicsConfig) -> void:
	var anchor = _largest_anchor_body(bodies)
	if anchor == null:
		return

	var old_anchor = _current_anchor_body(bodies)

	if old_anchor != null and old_anchor != anchor:
		_begin_anchor_swap_guard(old_anchor, anchor, config)

	for body in bodies:
		if not _valid_body(body):
			continue

		body.data.is_static_anchor = body == anchor and config.center_largest_body

	if config.center_largest_body:
		anchor.data.orbit_parent_id = ""
		anchor.data.orbit_locked = false
		_clear_anchor_swap_flags(anchor.data)

	for body in bodies:
		if not _valid_body(body) or body == anchor:
			continue

		var d: SimulationPlanetData = body.data
		var host = anchor if _has_anchor_swap_guard_for(d, anchor.data) else _choose_orbit_host(body, bodies, anchor)
		if host == null:
			continue

		var host_data: SimulationPlanetData = host.data
		var guard_active := _update_anchor_swap_guard_state(d, host_data, config)
		var released_from_guard := _is_anchor_swap_free_for(d, host_data)

		d.orbit_parent_id = host_data.instance_id

		if guard_active:
			d.orbit_radius = max(
				d.position.distance_to(host_data.position),
				_minimum_orbit_radius(d, host_data, config)
			)
			d.orbit_locked = true
			_seed_orbit_velocity_if_needed(d, host_data, config)
			continue

		if d.orbit_radius <= 0.0:
			d.orbit_radius = max(
				d.position.distance_to(host_data.position),
				_minimum_orbit_radius(d, host_data, config)
			)

		if released_from_guard:
			d.orbit_locked = false
			d.orbit_radius = max(d.position.distance_to(host_data.position), 1.0)
			continue

		d.orbit_locked = config.lock_planets_to_largest_body or _is_moon_like(d)

		if d.orbit_locked:
			_seed_orbit_velocity_if_needed(d, host_data, config)


static func _current_anchor_body(bodies: Array):
	for body in bodies:
		if not _valid_body(body):
			continue

		if body.data.is_static_anchor:
			return body

	return null


static func _begin_anchor_swap_guard(old_anchor, new_anchor, config: SimulationPhysicsConfig) -> void:
	if not _valid_body(old_anchor) or not _valid_body(new_anchor):
		return

	var old_data: SimulationPlanetData = old_anchor.data
	var new_data: SimulationPlanetData = new_anchor.data

	old_data.is_static_anchor = false
	old_data.orbit_parent_id = new_data.instance_id
	old_data.orbit_locked = true
	old_data.metadata[ANCHOR_SWAP_GUARD_KEY] = new_data.instance_id
	old_data.metadata.erase(ANCHOR_SWAP_FREE_HOST_KEY)

	var eject_dir := old_data.position - new_data.position

	if eject_dir.length_squared() < 1.0:
		eject_dir = old_data.position - ANCHOR_TARGET

	if eject_dir.length_squared() < 1.0:
		eject_dir = Vector2.RIGHT.rotated(float(Time.get_ticks_msec() % 6283) / 1000.0)

	eject_dir = eject_dir.normalized()

	var safe_radius := _minimum_orbit_radius(old_data, new_data, config)
	var current_dist := old_data.position.distance_to(new_data.position)

	if current_dist < safe_radius:
		old_data.position = new_data.position + eject_dir * safe_radius
		old_data.previous_position = old_data.position

	old_data.orbit_radius = safe_radius

	var tangent := Vector2(-eject_dir.y, eject_dir.x)
	if old_data.orbit_clockwise:
		tangent = -tangent

	var eject_speed := _stable_orbit_speed(old_data, new_data, safe_radius, config)
	eject_speed = clamp(eject_speed * 1.05, 100.0, _max_orbit_speed(old_data))

	old_data.velocity = new_data.velocity
	old_data.velocity += tangent * eject_speed
	old_data.velocity += eject_dir * min(eject_speed * 0.24, 240.0)

	if old_data.has_method("reset_trail"):
		old_data.reset_trail()

	if old_anchor.has_method("sync_from_data"):
		old_anchor.sync_from_data()


static func _update_anchor_swap_guard_state(d: SimulationPlanetData, host: SimulationPlanetData, config: SimulationPhysicsConfig) -> bool:
	if d == null or host == null:
		return false

	if not _has_anchor_swap_guard_for(d, host):
		return false

	if _anchor_is_centered(host):
		d.metadata.erase(ANCHOR_SWAP_GUARD_KEY)
		d.metadata[ANCHOR_SWAP_FREE_HOST_KEY] = host.instance_id
		d.orbit_locked = false
		d.orbit_radius = max(d.position.distance_to(host.position), 1.0)
		return false

	var safe_radius := _minimum_orbit_radius(d, host, config)
	var radial := d.position - host.position

	if radial.length_squared() < 1.0:
		radial = d.position - ANCHOR_TARGET

	if radial.length_squared() < 1.0:
		radial = Vector2.RIGHT.rotated(float(abs(hash(d.instance_id))) * 0.001)

	var dist := radial.length()
	var dir := radial.normalized()

	if dist < safe_radius:
		d.position = host.position + dir * safe_radius
		d.previous_position = d.position

		var tangent := Vector2(-dir.y, dir.x)
		if d.orbit_clockwise:
			tangent = -tangent

		var target_speed := _stable_orbit_speed(d, host, safe_radius, config)
		d.velocity = host.velocity + tangent * target_speed + dir * min(target_speed * 0.18, 190.0)

		if d.has_method("reset_trail"):
			d.reset_trail()

	d.orbit_parent_id = host.instance_id
	d.orbit_radius = safe_radius
	d.orbit_locked = true
	return true


static func _apply_anchor_swap_guard_force(d: SimulationPlanetData, bodies: Array, config: SimulationPhysicsConfig) -> void:
	if d == null or not d.metadata.has(ANCHOR_SWAP_GUARD_KEY):
		return

	var host_id := str(d.metadata.get(ANCHOR_SWAP_GUARD_KEY, ""))
	var host = _find_body_by_id(bodies, host_id)

	if host == null or not _valid_body(host):
		d.metadata.erase(ANCHOR_SWAP_GUARD_KEY)
		return

	var h: SimulationPlanetData = host.data

	if _anchor_is_centered(h):
		d.metadata.erase(ANCHOR_SWAP_GUARD_KEY)
		d.metadata[ANCHOR_SWAP_FREE_HOST_KEY] = h.instance_id
		d.orbit_locked = false
		d.orbit_radius = max(d.position.distance_to(h.position), 1.0)
		return

	var radial := d.position - h.position
	if radial.length_squared() < 1.0:
		radial = Vector2.RIGHT.rotated(float(abs(hash(d.instance_id))) * 0.001)

	var dist := max(radial.length(), 1.0)
	var dir: Vector2 = radial / dist
	var safe_radius := _minimum_orbit_radius(d, h, config)
	var guard_radius := safe_radius * 1.08

	if dist < guard_radius:
		var error: float = guard_radius - dist
		var strength: float = max(_time_safe_strength(config.orbit_lock_strength, config), 8.0) * 0.028
		var outward_velocity := d.velocity.dot(dir)
		var guard_force := dir * error * strength
		if guard_force.length() > 3200.0:
			guard_force = guard_force.normalized() * 3200.0
		d.add_acceleration(guard_force)
		if outward_velocity < 0.0:
			d.add_acceleration(-dir * outward_velocity * strength * 1.35)


static func _has_anchor_swap_guard_for(d: SimulationPlanetData, host: SimulationPlanetData) -> bool:
	if d == null or host == null:
		return false
	if not d.metadata.has(ANCHOR_SWAP_GUARD_KEY):
		return false
	return str(d.metadata.get(ANCHOR_SWAP_GUARD_KEY, "")) == host.instance_id


static func _is_anchor_swap_free_for(d: SimulationPlanetData, host: SimulationPlanetData) -> bool:
	if d == null or host == null:
		return false
	if not d.metadata.has(ANCHOR_SWAP_FREE_HOST_KEY):
		return false
	return str(d.metadata.get(ANCHOR_SWAP_FREE_HOST_KEY, "")) == host.instance_id


static func _clear_anchor_swap_flags(d: SimulationPlanetData) -> void:
	if d == null:
		return
	d.metadata.erase(ANCHOR_SWAP_GUARD_KEY)
	d.metadata.erase(ANCHOR_SWAP_FREE_HOST_KEY)


static func _anchor_is_centered(d: SimulationPlanetData) -> bool:
	if d == null:
		return true
	return d.position.distance_to(ANCHOR_TARGET) <= ANCHOR_CENTER_READY_DISTANCE and d.velocity.length() <= ANCHOR_CENTER_READY_SPEED


static func _largest_anchor_body(bodies: Array):
	var best = null
	var best_mass := -INF

	for body in bodies:
		if not _valid_body(body):
			continue

		var d: SimulationPlanetData = body.data
		var role_bonus := 1.0

		if _is_star_like(d):
			role_bonus = 8.0
		elif _is_planet_like(d):
			role_bonus = 2.0
		elif _is_moon_like(d):
			role_bonus = 0.55

		var weighted_mass := d.mass * role_bonus

		if weighted_mass > best_mass:
			best_mass = weighted_mass
			best = body

	return best


static func _choose_orbit_host(body, bodies: Array, anchor):
	if not _valid_body(body):
		return anchor

	var d: SimulationPlanetData = body.data
	var wants_planet_host := _is_moon_like(d)
	var best = null
	var best_score := INF

	for candidate in bodies:
		if candidate == body or not _valid_body(candidate):
			continue

		var c: SimulationPlanetData = candidate.data
		if wants_planet_host and not _is_planet_like(c) and not _is_moon_like(c):
			continue

		var dist := max(d.position.distance_to(c.position), MIN_HOST_DISTANCE)
		var score: float = dist / max(c.mass, 0.001)
		if _is_star_like(c):
			score *= 4.0 if wants_planet_host else 0.45
		if _is_planet_like(c):
			score *= 0.35 if wants_planet_host else 1.0

		if score < best_score:
			best_score = score
			best = candidate

	return best if best != null else anchor


static func _apply_center_anchor_force(d: SimulationPlanetData, config: SimulationPhysicsConfig) -> void:
	var to_center := ANCHOR_TARGET - d.position
	if to_center.length_squared() < 1.0:
		d.position = ANCHOR_TARGET
		d.velocity *= 0.82
		return

	var strength := _time_safe_strength(config.center_anchor_strength, config) * 0.12
	var pull := to_center * strength - d.velocity * strength * 0.20
	var max_pull := 2600.0 + config.center_anchor_strength * 120.0
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
	var radial := d.position - h.position
	var dist := max(radial.length(), 1.0)
	var target_radius := max(d.orbit_radius, _minimum_orbit_radius(d, h, config))
	var radius_error: float = dist - target_radius
	var radial_dir: Vector2 = radial / dist
	var tangent := Vector2(-radial_dir.y, radial_dir.x)
	if d.orbit_clockwise:
		tangent = -tangent

	var target_speed := _stable_orbit_speed(d, h, target_radius, config)
	var radial_velocity := d.velocity.dot(radial_dir)
	var tangential_velocity := d.velocity.dot(tangent)
	var lock_strength := _time_safe_strength(config.orbit_lock_strength, config) * 0.0045

	var radius_correction := -radial_dir * radius_error * lock_strength
	var radial_damping := -radial_dir * radial_velocity * lock_strength * 1.15
	var tangent_correction := tangent * (target_speed - tangential_velocity) * lock_strength * 0.85

	var max_correction := 2400.0 + config.orbit_lock_strength * 70.0
	var total := radius_correction + radial_damping + tangent_correction
	if total.length() > max_correction:
		total = total.normalized() * max_correction
	d.add_acceleration(total)


static func _seed_orbit_velocity_if_needed(d: SimulationPlanetData, host: SimulationPlanetData, config: SimulationPhysicsConfig) -> void:
	var radial := d.position - host.position
	var dist := max(radial.length(), 1.0)
	if dist <= 0.001:
		radial = Vector2.RIGHT
		dist = _minimum_orbit_radius(d, host, config)

	var radial_dir: Vector2 = radial / dist
	var tangent := Vector2(-radial_dir.y, radial_dir.x)
	if d.orbit_clockwise:
		tangent = -tangent

	var current_tangent_speed := d.velocity.dot(tangent)
	var target_speed := _stable_orbit_speed(d, host, max(d.orbit_radius, dist), config)
	if abs(current_tangent_speed) < target_speed * 0.18:
		d.velocity = tangent * target_speed + host.velocity


static func _stable_orbit_speed(d: SimulationPlanetData, host: SimulationPlanetData, radius: float, config: SimulationPhysicsConfig) -> float:
	var speed := sqrt(max(config.gravitational_constant * max(host.mass, 0.001) * max(host.gravitational_influence, 0.001) / max(radius, 1.0), 0.0))
	speed *= clamp(config.revolution_speed_multiplier / 50.0, 0.05, 4.0)
	return min(speed, _max_orbit_speed(d))


static func _limit_velocity_for_orbit(d: SimulationPlanetData, bodies: Array, config: SimulationPhysicsConfig) -> void:
	if not config.stable_orbit_mode:
		return

	var max_speed := _max_orbit_speed(d)
	if d.velocity.length() > max_speed:
		d.velocity = d.velocity.normalized() * max_speed


static func _max_orbit_speed(d: SimulationPlanetData) -> float:
	if d == null:
		return MAX_ORBIT_SPEED_FALLBACK
	if d.metadata.has("max_orbit_speed"):
		return max(float(d.metadata.get("max_orbit_speed", MAX_ORBIT_SPEED_FALLBACK)), 60.0)
	return clamp(420.0 + sqrt(max(d.mass, 0.0)) * 110.0 + max(d.radius_world, 1.0) * 3.0, 160.0, MAX_ORBIT_SPEED_FALLBACK)


static func _minimum_orbit_radius(d: SimulationPlanetData, host: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	return max(config.min_visible_orbit_radius, host.radius_world + d.radius_world + config.orbit_distance_padding)


static func _time_safe_strength(strength: float, config: SimulationPhysicsConfig) -> float:
	if config == null:
		return strength
	var speed_scale := sqrt(max(config.simulation_speed, 0.05))
	return strength / max(speed_scale, 1.0)


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


static func _valid_body(body) -> bool:
	return body != null and is_instance_valid(body) and body.data != null

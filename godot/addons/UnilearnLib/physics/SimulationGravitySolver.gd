extends RefCounted
class_name SimulationGravitySolver

const ANCHOR_TARGET := Vector2.ZERO
const MAX_ORBIT_SPEED_FALLBACK := 7200.0
const MIN_HOST_DISTANCE := 120.0
const BINARY_PARTNER_KEY := "binary_partner_id"
const ARCHITECTURE_DIRTY_KEY := "orbit_architecture_dirty"
const BINARY_CENTER_LOCKED_KEY := "binary_center_locked"
const COLLISION_PROTECTION_KEY := "collision_protected_until_ms"
const SYSTEM_ANCHOR_ID_KEY := "system_anchor_id"

static func step(bodies: Array, delta: float, config: SimulationPhysicsConfig) -> void:
	if bodies.is_empty() or config == null: return
	prime_orbit_architecture(bodies, config, false)
	var substeps: int = config.get_substep_count(delta)
	var h: float = (delta * config.simulation_speed) / float(substeps)
	for _s in range(substeps):
		_apply_black_hole_orbit_decay(bodies, abs(h), config)
		_step_verlet(bodies, h, config)

static func prime_orbit_architecture(bodies: Array, config: SimulationPhysicsConfig, force_reseed: bool = false) -> void:
	if bodies.is_empty() or config == null: return
	_clear_invalid_binary_links(bodies, config)
	_build_binary_links(bodies, config)
	_prepare_orbit_architecture(bodies, config, force_reseed)

static func mark_orbit_architecture_dirty(bodies: Array, clear_binary_links: bool = true) -> void:
	for body in bodies:
		if not _valid_body(body): continue
		var d: SimulationPlanetData = body.data
		d.metadata[ARCHITECTURE_DIRTY_KEY] = true
		if clear_binary_links:
			d.metadata.erase(BINARY_PARTNER_KEY); d.metadata.erase(BINARY_CENTER_LOCKED_KEY)
		d.is_static_anchor = false; d.orbit_locked = false

static func compute_accelerations(bodies: Array, config: SimulationPhysicsConfig) -> void:
	for body in bodies:
		if _valid_body(body): body.data.clear_forces()
	for i in range(bodies.size()):
		var a = bodies[i]
		if not _valid_body(a): continue
		var ad: SimulationPlanetData = a.data
		if ad.is_dragging: continue
		if ad.is_static_anchor:
			if config.center_largest_body: _apply_center_anchor_force(ad, config)
			continue
		if config.gravity_enabled:
			for j in range(bodies.size()):
				if i == j: continue
				var b = bodies[j]
				if _valid_body(b): ad.add_acceleration(acceleration_from_to(ad, b.data, config))
		if config.stable_orbit_mode: _apply_orbit_lock_force(ad, bodies, config)
	_apply_binary_barycenter_anchor_force(bodies, config)

static func acceleration_from_to(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> Vector2:
	if a == null or b == null or config == null: return Vector2.ZERO
	var dir: Vector2 = b.position - a.position
	var dist_sq: float = dir.length_squared()
	if dist_sq <= 0.0001: return Vector2.ZERO
	var softened: float = max(dist_sq, config.softening_radius * config.softening_radius)
	var polarity := -1.0 if str(b.metadata.get("gravity_polarity", "attractive")) == "repulsive" or b.body_kind == SimulationPlanetData.BodyKind.WHITE_HOLE else 1.0
	if _is_black_white_pair(a, b):
		polarity = 1.0
	var mass_factor: float = max(b.mass, 0.0) * abs(b.gravitational_influence)
	var magnitude: float = config.gravitational_constant * mass_factor / softened
	magnitude = min(magnitude, config.max_acceleration)
	return dir.normalized() * magnitude * polarity


static func _is_black_white_pair(a: SimulationPlanetData, b: SimulationPlanetData) -> bool:
	if a == null or b == null:
		return false
	return (a.body_kind == SimulationPlanetData.BodyKind.BLACK_HOLE and b.body_kind == SimulationPlanetData.BodyKind.WHITE_HOLE) or (a.body_kind == SimulationPlanetData.BodyKind.WHITE_HOLE and b.body_kind == SimulationPlanetData.BodyKind.BLACK_HOLE)

static func potential_energy_pair(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if a == null or b == null or config == null: return 0.0
	return -config.gravitational_constant * a.mass * b.mass / max(a.position.distance_to(b.position), config.softening_radius)
static func kinetic_energy(body: SimulationPlanetData) -> float: return 0.0 if body == null else 0.5 * body.mass * body.velocity.length_squared()
static func total_energy(bodies: Array, config: SimulationPhysicsConfig) -> float:
	var e := 0.0
	for body in bodies:
		if _valid_body(body): e += kinetic_energy(body.data)
	for i in range(bodies.size()):
		for j in range(i+1, bodies.size()):
			if _valid_body(bodies[i]) and _valid_body(bodies[j]): e += potential_energy_pair(bodies[i].data, bodies[j].data, config)
	return e

static func _step_verlet(bodies: Array, h: float, config: SimulationPhysicsConfig) -> void:
	compute_accelerations(bodies, config)
	var old_accels := {}
	for body in bodies:
		if not _valid_body(body): continue
		var d: SimulationPlanetData = body.data
		old_accels[body] = d.acceleration
		if d.is_dragging: _continue_dragged_body(body, config); continue
		d.previous_position = d.position
		d.position += d.velocity * h + 0.5 * d.acceleration * h * h
	compute_accelerations(bodies, config)
	for body in bodies:
		if not _valid_body(body): continue
		var d: SimulationPlanetData = body.data
		if d.is_dragging: _continue_dragged_body(body, config); continue
		d.velocity += 0.5 * (old_accels.get(body, Vector2.ZERO) + d.acceleration) * h
		_limit_velocity_for_orbit(d, config)
		if config.damping_per_second > 0.0: d.velocity *= pow(max(0.0, 1.0 - config.damping_per_second), abs(h))
		d.age_seconds += abs(h)
		d.record_trail_point(config.max_trail_points if config.trails_enabled else -1, config.trail_sample_distance)
		body.sync_from_data()


static func _stable_radius_multiplier(config: SimulationPhysicsConfig) -> float:
	if config == null:
		return 1.0
	if config.has_method("has_config_property") and config.has_config_property("stable_orbit_radius_multiplier"):
		return clamp(float(config.stable_orbit_radius_multiplier), 0.1, 1.0)
	return 1.0

static func _prepare_orbit_architecture(bodies: Array, config: SimulationPhysicsConfig, force_reseed: bool = false) -> void:
	var anchor = _largest_anchor_body(bodies)
	_protect_anchor_transition_family(bodies, anchor)
	var host_slots := {}
	var host_lanes := {}
	for body in bodies:
		if not _valid_body(body): continue
		var d: SimulationPlanetData = body.data
		d.is_static_anchor = false
		if config.center_largest_body and body == anchor and not _is_binary_member(d):
			d.is_static_anchor = true; d.orbit_parent_id = ""; d.orbit_locked = false; continue
		if not config.hierarchical_orbits_enabled: continue
		var host = _choose_orbit_host(body, bodies, anchor, config)
		if host == null or not _valid_body(host): continue
		var hd: SimulationPlanetData = host.data
		var previous_host := d.orbit_parent_id
		var previous_radius := d.orbit_radius
		var slot := int(host_slots.get(hd.instance_id, 0)); host_slots[hd.instance_id] = slot + 1
		d.metadata["stable_orbit_slot"] = slot
		var same_host := previous_host == hd.instance_id and previous_radius > 0.0
		var current_radius_multiplier := _stable_radius_multiplier(config)
		var lanes: Array = host_lanes.get(hd.instance_id, [])
		var radius_info := _target_orbit_radius_info(d, hd, config, lanes)
		var target_radius := float(radius_info.get("radius", _target_orbit_radius(d, hd, config, slot)))
		lanes.append(radius_info)
		host_lanes[hd.instance_id] = lanes
		# Only update the target orbit. Do not teleport/rebuild body position here.
		# The lock force moves the body toward this collision-safe target.
		var radius := target_radius
		d.orbit_parent_id = hd.instance_id; d.orbit_radius = radius
		d.metadata["stable_orbit_radius_multiplier_used"] = current_radius_multiplier
		d.metadata["stable_orbit_min_radius"] = float(radius_info.get("min_radius", radius))
		d.metadata["stable_orbit_max_radius"] = float(radius_info.get("max_radius", radius))
		var soft_recover := bool(d.metadata.get("stable_orbit_soft_recover", false))
		var needs_seed := (force_reseed and not same_host) or previous_host != hd.instance_id or previous_radius <= 0.0 or bool(d.metadata.get(ARCHITECTURE_DIRTY_KEY, false))
		if needs_seed and config.stable_orbit_mode and not soft_recover and not _is_binary_member(d) and not _is_white_hole(hd): _seed_orbit_velocity(d, hd, radius, config)
		if needs_seed: d.metadata.erase(ARCHITECTURE_DIRTY_KEY)
		if hd.body_kind == SimulationPlanetData.BodyKind.BLACK_HOLE:
			d.orbit_locked = false
			d.metadata["black_hole_unstable_orbit"] = true
		else:
			d.orbit_locked = config.stable_orbit_mode and not _is_white_hole(hd) and (_is_moon_like(d) or config.lock_planets_to_largest_body)

static func _build_binary_links(bodies: Array, config: SimulationPhysicsConfig) -> void:
	if config == null or not config.binary_orbits_enabled or not config.same_type_binary_enabled: return
	if _has_existing_anchor(bodies): return
	var used := {}
	for body in bodies:
		if not _valid_body(body): continue
		var a: SimulationPlanetData = body.data
		if used.has(a.instance_id) or _is_moon_like(a): continue
		for candidate in bodies:
			if candidate == body or not _valid_body(candidate): continue
			var b: SimulationPlanetData = candidate.data
			if used.has(b.instance_id) or _is_moon_like(b): continue
			if _is_black_white_pair(a, b):
				a.metadata[BINARY_PARTNER_KEY] = b.instance_id; b.metadata[BINARY_PARTNER_KEY] = a.instance_id
				a.metadata["death_dance_pair"] = b.instance_id; b.metadata["death_dance_pair"] = a.instance_id
				a.metadata["death_dance_ignore_binary_reseed"] = true; b.metadata["death_dance_ignore_binary_reseed"] = true
				a.metadata.erase(ARCHITECTURE_DIRTY_KEY); b.metadata.erase(ARCHITECTURE_DIRTY_KEY)
				var already_dancing := bool(a.metadata.get("death_dance_initialized", false)) or bool(b.metadata.get("death_dance_initialized", false))
				if not already_dancing:
					SimulationOrbitUtils.prepare_soft_mutual_binary_orbit(body, candidate, config, a.orbit_clockwise, -1.0, false)
				used[a.instance_id] = true; used[b.instance_id] = true
				break
			if not _are_good_binary_partners(a, b, config): continue
			a.metadata[BINARY_PARTNER_KEY] = b.instance_id; b.metadata[BINARY_PARTNER_KEY] = a.instance_id
			SimulationOrbitUtils.prepare_soft_mutual_binary_orbit(body, candidate, config, a.orbit_clockwise, -1.0, false)
			used[a.instance_id] = true; used[b.instance_id] = true
			break


static func _are_good_binary_partners(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> bool:
	if a == null or b == null or config == null:
		return false
	if not config.binary_orbits_enabled or not config.same_type_binary_enabled:
		return false
	if _is_moon_like(a) or _is_moon_like(b):
		return false
	if not _same_orbit_family(a, b):
		return false
	var smaller: float = min(max(a.mass, 0.001), max(b.mass, 0.001))
	var larger: float = max(max(a.mass, 0.001), max(b.mass, 0.001))
	var required: float = clamp(config.binary_mass_similarity * (0.42 if _is_star_like(a) and _is_star_like(b) else 1.0), 0.08, 1.0)
	if smaller / larger < required:
		return false
	return a.position.distance_to(b.position) <= _minimum_binary_separation(a, b, config) * config.binary_max_distance_multiplier

static func _minimum_binary_separation(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if a == null or b == null or config == null:
		return 220.0
	return max(a.radius_world + b.radius_world + max(config.min_visible_orbit_radius * 0.36, 28.0), config.min_visible_orbit_radius * 1.18)

static func _same_orbit_family(a: SimulationPlanetData, b: SimulationPlanetData) -> bool:
	if a == null or b == null:
		return false
	if _is_black_white_pair(a, b):
		return true
	if _is_star_like(a) and _is_star_like(b):
		return true
	if _is_planet_like(a) and _is_planet_like(b):
		return true
	return int(a.body_kind) == int(b.body_kind)

static func _clear_invalid_binary_links(bodies: Array, config: SimulationPhysicsConfig) -> void:
	var ids := {}
	for body in bodies:
		if _valid_body(body): ids[body.data.instance_id] = true
	for body in bodies:
		if _valid_body(body) and body.data.metadata.has(BINARY_PARTNER_KEY) and not ids.has(str(body.data.metadata.get(BINARY_PARTNER_KEY, ""))): _clear_binary_link_for_body(body.data)

static func _has_existing_anchor(bodies: Array) -> bool:
	for body in bodies:
		if _valid_body(body) and body.data.is_static_anchor:
			return true
	return false

static func _protect_anchor_transition_family(bodies: Array, anchor) -> void:
	var new_anchor_id := ""
	if _valid_body(anchor):
		new_anchor_id = str(anchor.data.instance_id)
	var old_anchor_id := ""
	for body in bodies:
		if _valid_body(body):
			old_anchor_id = str(body.data.metadata.get(SYSTEM_ANCHOR_ID_KEY, ""))
			if not old_anchor_id.is_empty():
				break

	if not old_anchor_id.is_empty() and not new_anchor_id.is_empty() and old_anchor_id != new_anchor_id:
		var protected_ids := {}
		protected_ids[old_anchor_id] = true
		protected_ids[new_anchor_id] = true
		for body in bodies:
			if not _valid_body(body):
				continue
			var d: SimulationPlanetData = body.data
			if str(d.orbit_parent_id) == old_anchor_id or str(d.orbit_parent_id) == new_anchor_id:
				protected_ids[d.instance_id] = true
			if str(d.metadata.get(BINARY_PARTNER_KEY, "")) == old_anchor_id or str(d.metadata.get(BINARY_PARTNER_KEY, "")) == new_anchor_id:
				protected_ids[d.instance_id] = true

		var protected_until := Time.get_ticks_msec() + 4200
		for body in bodies:
			if not _valid_body(body):
				continue
			var d: SimulationPlanetData = body.data
			if protected_ids.has(d.instance_id) or protected_ids.has(str(d.orbit_parent_id)):
				d.metadata[COLLISION_PROTECTION_KEY] = max(int(d.metadata.get(COLLISION_PROTECTION_KEY, 0)), protected_until)
				d.metadata["anchor_transition_protected"] = true
				d.metadata.erase(BINARY_PARTNER_KEY)
				d.metadata.erase(BINARY_CENTER_LOCKED_KEY)

	for body in bodies:
		if _valid_body(body):
			body.data.metadata[SYSTEM_ANCHOR_ID_KEY] = new_anchor_id
static func _clear_binary_link_for_body(d: SimulationPlanetData) -> void:
	if d == null: return
	d.metadata.erase(BINARY_PARTNER_KEY); d.metadata.erase(BINARY_CENTER_LOCKED_KEY); d.metadata[ARCHITECTURE_DIRTY_KEY] = true; d.orbit_locked = false; d.is_static_anchor = false
static func _is_binary_member(d: SimulationPlanetData) -> bool: return d != null and d.metadata.has(BINARY_PARTNER_KEY) and str(d.metadata.get(BINARY_PARTNER_KEY, "")) != ""
static func _anchor_score(d: SimulationPlanetData) -> float:
	if d == null: return 0.0
	var role_bonus := 1.0
	if _is_star_like(d): role_bonus = 10.0
	elif _is_planet_like(d): role_bonus = 2.0
	elif _is_moon_like(d): role_bonus = 0.35
	return d.mass * abs(d.gravitational_influence) * role_bonus
static func _largest_anchor_body(bodies: Array):
	var best = null; var score := -INF
	for body in bodies:
		if _valid_body(body) and _anchor_score(body.data) > score: score = _anchor_score(body.data); best = body
	return best
static func _choose_orbit_host(body, bodies: Array, anchor, config: SimulationPhysicsConfig):
	if not _valid_body(body): return anchor
	var d: SimulationPlanetData = body.data
	if _is_moon_like(d):
		var planet = _best_satellite_planet_host(body, bodies)
		return planet if planet != null else anchor
	if _is_planet_like(d):
		var star = _best_star_host(body, bodies)
		return star if star != null else anchor
	if _is_star_like(d): return anchor if anchor != null and anchor != body else null
	return anchor
static func _best_star_host(body, bodies: Array): return _best_host_by_role(body, bodies, [SimulationPlanetData.BodyKind.STAR, SimulationPlanetData.BodyKind.BLACK_HOLE, SimulationPlanetData.BodyKind.WHITE_HOLE], false)
static func _best_satellite_planet_host(body, bodies: Array):
	if not _valid_body(body):
		return null
	var moon: SimulationPlanetData = body.data
	var best = null
	var best_score := INF
	for candidate in bodies:
		if candidate == body or not _valid_body(candidate):
			continue
		var c: SimulationPlanetData = candidate.data
		if not [SimulationPlanetData.BodyKind.PLANET, SimulationPlanetData.BodyKind.RINGED_PLANET].has(c.body_kind):
			continue
		# Satellites should prefer actual planets, but not tiny rocks pretending to be hosts.
		# The planet must be clearly larger/heavier than the satellite.
		if c.radius_world <= moon.radius_world * 1.12 and c.mass <= moon.mass * 1.35:
			continue
		var distance := max(moon.position.distance_to(c.position), MIN_HOST_DISTANCE)
		var host_power := max(sqrt(max(c.mass, 0.001)) * max(c.radius_world, 1.0), 0.001)
		var score: float = distance / host_power
		if score < best_score:
			best_score = score
			best = candidate
	return best
static func _best_host_by_role(body, bodies: Array, roles: Array, allow_lighter: bool):
	var best = null; var best_score := INF
	for candidate in bodies:
		if candidate == body or not _valid_body(candidate): continue
		var c: SimulationPlanetData = candidate.data
		if not roles.has(c.body_kind): continue
		if not allow_lighter and c.mass <= body.data.mass: continue
		var score: float = max(body.data.position.distance_to(c.position), MIN_HOST_DISTANCE) / max(sqrt(max(c.mass, 0.001)), 0.001)
		if score < best_score: best_score = score; best = candidate
	return best
static func _apply_center_anchor_force(d: SimulationPlanetData, config: SimulationPhysicsConfig) -> void:
	var to_center := ANCHOR_TARGET - d.position
	var strength := clamp(config.center_anchor_strength, 0.0, 1.0)
	if strength <= 0.0:
		return

	# Gentle recentering: a soft spring with stronger velocity damping and a hard
	# acceleration cap. This keeps the anchor alive and elastic without the wild
	# yo-yo oscillation that made new anchors slingshot through the middle.
	var spring: float = 0.28 + strength * 0.82
	var damping: float = 1.05 + strength * 1.65
	var center_accel: Vector2 = (to_center * spring - d.velocity * damping) * strength
	d.add_acceleration(center_accel.limit_length(260.0 + strength * 820.0))

static func _apply_binary_barycenter_anchor_force(bodies: Array, config: SimulationPhysicsConfig) -> void:
	if config == null or not config.center_largest_body:
		return
	var pair := _best_anchor_binary_pair(bodies)
	if pair.size() != 2:
		return
	var a = pair[0]
	var b = pair[1]
	if not _valid_body(a) or not _valid_body(b):
		return
	if a.data.is_dragging or b.data.is_dragging:
		return
	var total_mass: float = max(a.data.mass + b.data.mass, 0.001)
	var barycenter: Vector2 = (a.data.position * a.data.mass + b.data.position * b.data.mass) / total_mass
	var bary_velocity: Vector2 = (a.data.velocity * a.data.mass + b.data.velocity * b.data.mass) / total_mass
	var strength := clamp(config.center_anchor_strength, 0.0, 1.0)
	if strength <= 0.0:
		return
	var spring: float = 0.28 + strength * 0.82
	var damping: float = 1.05 + strength * 1.65
	var center_accel: Vector2 = ((ANCHOR_TARGET - barycenter) * spring - bary_velocity * damping) * strength
	center_accel = center_accel.limit_length(260.0 + strength * 820.0)
	a.data.add_acceleration(center_accel)
	b.data.add_acceleration(center_accel)

static func _best_anchor_binary_pair(bodies: Array) -> Array:
	var best_pair: Array = []
	var best_pair_score := -INF
	var best_single_score := -INF
	var seen := {}
	for body in bodies:
		if not _valid_body(body):
			continue
		var d: SimulationPlanetData = body.data
		var score := _anchor_score(d)
		if not _is_binary_member(d):
			best_single_score = max(best_single_score, score)
		var partner_id := str(d.metadata.get(BINARY_PARTNER_KEY, ""))
		if partner_id.is_empty() or seen.has(d.instance_id):
			continue
		var partner = _find_body_by_id(bodies, partner_id)
		if not _valid_body(partner):
			continue
		seen[d.instance_id] = true
		seen[partner.data.instance_id] = true
		var pair_score := _anchor_score(d) + _anchor_score(partner.data)
		if pair_score > best_pair_score:
			best_pair_score = pair_score
			best_pair = [body, partner]
	if best_pair_score <= 0.0 or best_pair_score < best_single_score:
		return []
	return best_pair
static func _apply_orbit_lock_force(d: SimulationPlanetData, bodies: Array, config: SimulationPhysicsConfig) -> void:
	if not d.orbit_locked: return
	var host = _find_body_by_id(bodies, d.orbit_parent_id)
	if not _valid_body(host): return
	var h: SimulationPlanetData = host.data
	if _is_white_hole(h):
		d.orbit_locked = false
		return

	var radial := d.position - h.position
	var dist := max(radial.length(), 1.0)
	if h.body_kind == SimulationPlanetData.BodyKind.BLACK_HOLE:
		d.orbit_locked = false
		d.metadata["black_hole_unstable_orbit"] = true
		return

	var current_radius_multiplier := _stable_radius_multiplier(config)
	var slot := int(d.metadata.get("stable_orbit_slot", 0))
	if not _is_binary_member(d):
		if d.metadata.has("stable_orbit_min_radius") and d.metadata.has("stable_orbit_max_radius"):
			d.orbit_radius = SimulationOrbitUtils.orbit_radius_from_min_max(float(d.metadata.get("stable_orbit_min_radius", d.orbit_radius)), float(d.metadata.get("stable_orbit_max_radius", d.orbit_radius)), config)
		else:
			d.orbit_radius = _target_orbit_radius(d, h, config, slot)
		d.metadata["stable_orbit_radius_multiplier_used"] = current_radius_multiplier
	var target_radius := max(d.orbit_radius, 1.0)
	var radial_dir: Vector2 = radial / dist
	var tangent := Vector2(-radial_dir.y, radial_dir.x) * (-1.0 if d.orbit_clockwise else 1.0)
	var target_point: Vector2 = h.position + radial_dir * target_radius
	var to_orbit_path: Vector2 = target_point - d.position
	var relative := d.velocity - h.velocity
	var radial_speed: float = relative.dot(radial_dir)
	var tangential_speed: float = relative.dot(tangent)
	var target_speed := _stable_orbit_speed(d, h, target_radius, config)
	var delta_radius: float = dist - target_radius
	var distance_ratio: float = clamp(abs(delta_radius) / max(target_radius, 1.0), 0.0, 4.0)
	var soft_recover := bool(d.metadata.get("stable_orbit_soft_recover", false))

	# The radius slider is literal. If the target radius gets scaled down to 0.1,
	# the lock must actually pull the body inward instead of letting it float on
	# the old wide orbit for ages. This still updates only the target orbit; it does
	# not teleport/rebuild the position.
	var slider := _stable_radius_multiplier(config)
	var compact_boost := lerp(5.0, 1.0, slider)
	var normal_strength: float = config.orbit_lock_strength * lerp(0.34, 1.10, clamp(distance_ratio, 0.0, 1.0)) * compact_boost
	var normal_damping: float = config.orbit_lock_strength * lerp(0.36, 0.82, clamp(distance_ratio, 0.0, 1.0)) * compact_boost
	var revolving_strength: float = config.orbit_lock_strength * 0.92
	var acceleration_limit: float = (420.0 + config.orbit_lock_strength * 2400.0) * compact_boost

	if soft_recover:
		normal_strength *= 0.46
		normal_damping *= 0.62
		revolving_strength *= 0.42
		acceleration_limit *= 0.48

	var normal_vector: Vector2 = to_orbit_path * normal_strength - radial_dir * radial_speed * normal_damping
	var revolving_vector: Vector2 = tangent * (target_speed - tangential_speed) * revolving_strength
	var correction: Vector2 = normal_vector + revolving_vector
	d.add_acceleration(correction.limit_length(acceleration_limit))

	if soft_recover and abs(delta_radius) <= max(target_radius * 0.045, 18.0) and abs(radial_speed) <= 42.0:
		d.metadata.erase("stable_orbit_soft_recover")
static func _seed_orbit_velocity(d: SimulationPlanetData, host: SimulationPlanetData, radius: float, config: SimulationPhysicsConfig) -> void:
	var radial := d.position - host.position
	if radial.length_squared() < 0.001: radial = _stable_direction(d.instance_id) * radius
	var tangent := Vector2(-radial.normalized().y, radial.normalized().x)
	if d.orbit_clockwise: tangent = -tangent
	d.velocity = host.velocity + tangent * (_stable_orbit_speed(d, host, radius, config) * 1.04)
static func _stable_orbit_speed(d: SimulationPlanetData, host: SimulationPlanetData, radius: float, config: SimulationPhysicsConfig) -> float:
	var speed_multiplier := config.get_orbit_speed_multiplier() if config.has_method("get_orbit_speed_multiplier") else clamp(config.revolution_speed_multiplier, 0.05, 32.0)
	# Game-feel scaling requested: smaller stable-radius setting also lowers the
	# tangential target velocity, instead of letting the physics formula speed it up.
	var radius_slider := _stable_radius_multiplier(config)
	return min(sqrt(max(config.gravitational_constant * max(host.mass * abs(host.gravitational_influence), 0.001) / max(radius, 1.0), 0.0)) * speed_multiplier * radius_slider, _max_orbit_speed(d))
static func _limit_velocity_for_orbit(d: SimulationPlanetData, config: SimulationPhysicsConfig) -> void:
	if config.stable_orbit_mode and d.velocity.length() > _max_orbit_speed(d): d.velocity = d.velocity.normalized() * _max_orbit_speed(d)
static func _max_orbit_speed(d: SimulationPlanetData) -> float: return MAX_ORBIT_SPEED_FALLBACK if d == null else max(d.max_orbit_speed * 4.0, 80.0)
static func _minimum_orbit_radius_for_multiplier(d: SimulationPlanetData, host: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if d == null or host == null or config == null:
		return 120.0
	return SimulationOrbitUtils.minimum_orbit_radius(d, host, config)

static func _tight_orbit_radius_local(body: SimulationPlanetData, parent: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if body == null or parent == null or config == null:
		return 72.0
	return SimulationOrbitUtils.tight_orbit_radius(body, parent, config)

static func _target_orbit_radius_info(d: SimulationPlanetData, host: SimulationPlanetData, config: SimulationPhysicsConfig, inner_lanes: Array = []) -> Dictionary:
	var min_radius := SimulationOrbitUtils.stable_orbit_min_radius(d, host, config)
	var max_radius := SimulationOrbitUtils.stable_orbit_max_radius(d, host, config)
	for lane in inner_lanes:
		if not (lane is Dictionary):
			continue
		var existing = lane.get("body", null)
		var lane_min := float(lane.get("min_radius", 0.0))
		var lane_max := float(lane.get("max_radius", 0.0))
		var compact_gap := SimulationOrbitUtils.compact_orbit_lane_gap(d, host, config)
		var normal_gap := SimulationOrbitUtils.normal_orbit_lane_gap(d, host, config)
		if existing is SimulationPlanetData:
			compact_gap = SimulationOrbitUtils.compact_orbit_lane_gap(d, existing, config)
			normal_gap = SimulationOrbitUtils.normal_orbit_lane_gap(d, existing, config)
		normal_gap = max(compact_gap, normal_gap * SimulationOrbitUtils.orbit_spacing_multiplier(config))
		min_radius = max(min_radius, lane_min + compact_gap)
		max_radius = max(max_radius, lane_max + normal_gap)
	var radius := SimulationOrbitUtils.orbit_radius_from_min_max(min_radius, max_radius, config)
	return {"body": d, "min_radius": min_radius, "max_radius": max_radius, "radius": radius}

static func _target_orbit_radius(d: SimulationPlanetData, host: SimulationPlanetData, config: SimulationPhysicsConfig, orbit_slot: int = 0) -> float:
	return SimulationOrbitUtils.preferred_orbit_radius(d, host, config, orbit_slot)

static func _apply_black_hole_orbit_decay(bodies: Array, step_seconds: float, config: SimulationPhysicsConfig) -> void:
	if config == null or step_seconds <= 0.0:
		return
	for body in bodies:
		if not _valid_body(body):
			continue
		var d: SimulationPlanetData = body.data
		if d.is_dragging or d.orbit_parent_id.is_empty():
			continue
		if str(d.metadata.get("death_dance_pair", "")) != "":
			continue
		var host = _find_body_by_id(bodies, d.orbit_parent_id)
		if not _valid_body(host) or host.data.body_kind != SimulationPlanetData.BodyKind.BLACK_HOLE:
			continue
		var h: SimulationPlanetData = host.data
		var collision_radius := d.get_collision_radius(config) + h.get_collision_radius(config)
		var floor_radius: float = max(collision_radius * 0.58, 2.0)
		var physical_radius: float = max(d.position.distance_to(h.position), floor_radius)
		if d.orbit_radius <= 0.0:
			d.orbit_radius = physical_radius
		var current_radius: float = max(d.orbit_radius, floor_radius)
		var gravity_factor: float = clamp(pow(max(h.mass * abs(h.gravitational_influence), 1.0), 0.16) / 3.2, 0.55, 5.2)
		var body_factor: float = clamp(pow(max(d.mass, 0.01), 0.08), 0.72, 1.55)
		var decay_per_second: float = (28.0 + current_radius * 0.026) * gravity_factor / body_factor
		d.orbit_radius = max(floor_radius, current_radius - decay_per_second * step_seconds)
		var inward := h.position - d.position
		if inward.length_squared() > 0.001:
			var inward_dir := inward.normalized()
			var orbit_error: float = max(physical_radius - d.orbit_radius, 0.0)
			d.velocity += inward_dir * ((decay_per_second * 0.12) + orbit_error * 0.045) * step_seconds
			d.velocity = d.velocity.limit_length(max(_max_orbit_speed(d), 260.0))
static func _find_body_by_id(bodies: Array, id: String):
	if id.is_empty(): return null
	for body in bodies:
		if _valid_body(body) and body.data.instance_id == id: return body
	return null
static func _continue_dragged_body(body, config: SimulationPhysicsConfig) -> void:
	body.data.velocity = Vector2.ZERO if config.ignore_drag_throw_velocity else body.data.velocity * clamp(config.drag_velocity_keep, 0.0, 1.0)
	body.sync_from_data()
static func _is_star_like(d: SimulationPlanetData) -> bool: return d != null and d.body_kind in [SimulationPlanetData.BodyKind.STAR, SimulationPlanetData.BodyKind.BLACK_HOLE, SimulationPlanetData.BodyKind.WHITE_HOLE, SimulationPlanetData.BodyKind.GALAXY]
static func _is_planet_like(d: SimulationPlanetData) -> bool: return d != null and d.body_kind in [SimulationPlanetData.BodyKind.PLANET, SimulationPlanetData.BodyKind.RINGED_PLANET]
static func _is_moon_like(d: SimulationPlanetData) -> bool: return d != null and d.body_kind in [SimulationPlanetData.BodyKind.MOON, SimulationPlanetData.BodyKind.SATELLITE]
static func _stable_direction(seed: String) -> Vector2: return Vector2.RIGHT.rotated(float(abs(hash(seed)) % 6283) / 1000.0).normalized()
static func _valid_body(body) -> bool: return body != null and is_instance_valid(body) and body.data != null

static func _is_white_hole(d: SimulationPlanetData) -> bool: return d != null and d.body_kind == SimulationPlanetData.BodyKind.WHITE_HOLE

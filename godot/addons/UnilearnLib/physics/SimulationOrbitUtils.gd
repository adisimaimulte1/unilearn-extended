extends RefCounted
class_name SimulationOrbitUtils

const ANCHOR_TARGET := Vector2.ZERO

static func make_circular_orbit(body, parent, config: SimulationPhysicsConfig, clockwise: bool = true, radius_override: float = -1.0, reset_trail: bool = false) -> bool:
	if not _valid_pair(body, parent, config): return false
	var offset: Vector2 = body.data.position - parent.data.position
	var radius: float = radius_override if radius_override > 0.0 else offset.length()
	radius = max(radius, minimum_orbit_radius(body.data, parent.data, config))
	if offset.length_squared() < 0.001: offset = _stable_direction(body.data.instance_id) * radius
	else: offset = offset.normalized() * radius
	body.data.position = parent.data.position + offset
	body.data.previous_position = body.data.position
	var tangent := Vector2(-offset.y, offset.x).normalized()
	if clockwise: tangent *= -1.0
	var orbit_multiplier := config.get_orbit_speed_multiplier() if config.has_method("get_orbit_speed_multiplier") else clamp(config.revolution_speed_multiplier, 0.05, 32.0)
	var speed: float = circular_orbit_speed(parent.data.mass * abs(parent.data.gravitational_influence), radius, config) * orbit_multiplier * _stable_orbit_radius_value(config)
	body.data.velocity = parent.data.velocity + tangent * min(speed, _max_orbit_speed(body.data))
	body.data.orbit_parent_id = parent.data.instance_id
	body.data.orbit_radius = radius
	body.data.orbit_clockwise = clockwise
	body.data.orbit_eccentricity = 0.0
	body.data.orbit_locked = config.stable_orbit_mode
	if reset_trail: body.data.reset_trail()
	body.sync_from_data()
	return true

static func prepare_soft_circular_orbit(body, parent, config: SimulationPhysicsConfig, clockwise: bool = true, radius_override: float = -1.0, blend_velocity: bool = true) -> bool:
	if not _valid_pair(body, parent, config): return false
	var offset: Vector2 = body.data.position - parent.data.position
	var current_distance := offset.length()
	var radius: float = radius_override if radius_override > 0.0 else current_distance
	radius = max(radius, minimum_orbit_radius(body.data, parent.data, config))
	if current_distance < 0.001:
		offset = _stable_direction(body.data.instance_id) * radius
	var radial_dir := offset.normalized()
	if radial_dir.length_squared() < 0.001:
		radial_dir = _stable_direction(body.data.instance_id)
	var tangent := Vector2(-radial_dir.y, radial_dir.x).normalized()
	if clockwise: tangent *= -1.0
	var orbit_multiplier := config.get_orbit_speed_multiplier() if config.has_method("get_orbit_speed_multiplier") else clamp(config.revolution_speed_multiplier, 0.05, 32.0)
	var speed: float = circular_orbit_speed(parent.data.mass * abs(parent.data.gravitational_influence), radius, config) * orbit_multiplier * _stable_orbit_radius_value(config)
	var target_velocity: Vector2 = parent.data.velocity + tangent * min(speed, _max_orbit_speed(body.data))
	body.data.orbit_parent_id = parent.data.instance_id
	body.data.orbit_radius = radius
	body.data.orbit_clockwise = clockwise
	body.data.orbit_eccentricity = 0.0
	body.data.orbit_locked = config.stable_orbit_mode
	body.data.metadata["stable_orbit_soft_recover"] = true
	body.data.metadata.erase("orbit_architecture_dirty")
	if blend_velocity:
		body.data.velocity = body.data.velocity.lerp(target_velocity, 0.18)
	else:
		body.data.velocity = target_velocity
	body.sync_from_data()
	return true

static func make_elliptical_orbit(body, parent, config: SimulationPhysicsConfig, eccentricity: float = 0.25, clockwise: bool = true, reset_trail: bool = false) -> bool:
	if not make_circular_orbit(body, parent, config, clockwise, -1.0, reset_trail): return false
	body.data.orbit_eccentricity = clamp(eccentricity, 0.0, 0.85)
	return true

static func create_mutual_binary_orbit(a, b, config: SimulationPhysicsConfig, clockwise: bool = true, separation_override: float = -1.0, reset_trail: bool = false, lock_center_to_screen: bool = false) -> bool:
	if not _valid_pair(a, b, config): return false
	var total_mass := max(a.data.mass + b.data.mass, 0.001)
	var offset: Vector2 = b.data.position - a.data.position
	var separation := separation_override if separation_override > 0.0 else offset.length()
	var already_binary: bool = str(a.data.metadata.get("binary_partner_id", "")) == b.data.instance_id and str(b.data.metadata.get("binary_partner_id", "")) == a.data.instance_id
	var death_dance_pair := _is_black_white_pair(a.data, b.data)
	if separation_override > 0.0 or (not already_binary and not death_dance_pair):
		separation = max(separation, minimum_binary_separation(a.data, b.data, config))
	else:
		separation = max(separation, 1.0)
	if offset.length_squared() < 0.001:
		var zero_offset_minimum := 1.0 if death_dance_pair else minimum_binary_separation(a.data, b.data, config)
		offset = _stable_direction(a.data.instance_id + b.data.instance_id) * max(separation, zero_offset_minimum)
	else:
		offset = offset.normalized() * separation
	var direction := offset.normalized()
	var center: Vector2 = (a.data.position * a.data.mass + b.data.position * b.data.mass) / total_mass
	var ra: float = separation * (b.data.mass / total_mass)
	var rb: float = separation * (a.data.mass / total_mass)
	a.data.position = center - direction * ra
	b.data.position = center + direction * rb
	var tangent := Vector2(-direction.y, direction.x)
	if clockwise: tangent *= -1.0
	var orbit_multiplier := config.get_orbit_speed_multiplier() if config.has_method("get_orbit_speed_multiplier") else clamp(config.revolution_speed_multiplier, 0.05, 32.0)
	var omega: float = sqrt(config.gravitational_constant * total_mass / pow(separation, 3.0)) * orbit_multiplier
	var center_velocity := get_center_of_mass_velocity([a, b])
	a.data.velocity = center_velocity - tangent * omega * ra
	b.data.velocity = center_velocity + tangent * omega * rb
	a.data.orbit_parent_id = b.data.instance_id; b.data.orbit_parent_id = a.data.instance_id
	a.data.orbit_radius = separation; b.data.orbit_radius = separation
	if death_dance_pair:
		a.data.orbit_locked = false; b.data.orbit_locked = false
		a.data.metadata["death_dance_pair"] = b.data.instance_id; b.data.metadata["death_dance_pair"] = a.data.instance_id
		a.data.metadata["black_hole_unstable_orbit"] = true; b.data.metadata["black_hole_unstable_orbit"] = true
	else:
		a.data.orbit_locked = config.stable_orbit_mode; b.data.orbit_locked = config.stable_orbit_mode
	a.data.metadata["binary_partner_id"] = b.data.instance_id; b.data.metadata["binary_partner_id"] = a.data.instance_id
	a.data.metadata["binary_center_locked"] = false if death_dance_pair else lock_center_to_screen; b.data.metadata["binary_center_locked"] = false if death_dance_pair else lock_center_to_screen
	if reset_trail: a.data.reset_trail(); b.data.reset_trail()
	a.sync_from_data(); b.sync_from_data()
	return true

static func prepare_soft_mutual_binary_orbit(a, b, config: SimulationPhysicsConfig, clockwise: bool = true, separation_override: float = -1.0, lock_center_to_screen: bool = false) -> bool:
	return create_mutual_binary_orbit(a, b, config, clockwise, separation_override, false, lock_center_to_screen)
static func create_triple_star_stable(inner_a, inner_b, outer_c, config: SimulationPhysicsConfig, clockwise: bool = true, reset_trail: bool = false) -> bool:
	if not create_mutual_binary_orbit(inner_a, inner_b, config, clockwise, -1.0, reset_trail, true): return false
	return make_circular_orbit(outer_c, inner_a, config, clockwise, max(outer_c.data.position.distance_to(inner_a.data.position), config.min_visible_orbit_radius * 4.0), reset_trail)
static func circular_orbit_speed(parent_mass: float, radius: float, config: SimulationPhysicsConfig) -> float: return sqrt(max(config.gravitational_constant * max(parent_mass, 0.001) / max(radius, 1.0), 0.0))
static func escape_velocity(parent_mass: float, radius: float, config: SimulationPhysicsConfig) -> float: return sqrt(max(2.0 * config.gravitational_constant * max(parent_mass, 0.001) / max(radius, 1.0), 0.0))
static func find_best_orbit_parent(body, candidates: Array, max_distance: float = 900.0):
	var best = null; var best_score := INF
	for candidate in candidates:
		if candidate == body or not _valid_node(candidate): continue
		var dist: float = body.data.position.distance_to(candidate.data.position)
		if dist > max_distance: continue
		var score := dist / sqrt(max(candidate.data.mass, 0.001))
		if score < best_score: best_score = score; best = candidate
	return best
static func tight_orbit_radius(body: SimulationPlanetData, parent: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if body == null or parent == null or config == null:
		return 72.0

	# True compact lower bound. This is intentionally based on the visible/world
	# radii first, not only collision radii. The collision radius is scaled down
	# for nicer merging, so using it here can still visually drive a planet into
	# the sun at multiplier 0.1.
	var body_clearance: float = max(body.radius_world, body.get_collision_radius(config))
	var parent_clearance: float = max(parent.radius_world, parent.get_collision_radius(config))

	# If the host is part of a binary, the orbit must start outside the binary
	# envelope, otherwise the compact radius can aim through the partner path.
	if parent.metadata.has("binary_partner_id") and parent.orbit_radius > 0.0:
		parent_clearance = max(parent_clearance, parent.orbit_radius + parent.get_collision_radius(config))

	var padding: float = max(10.0, config.orbit_distance_padding * 0.09)
	if _is_moon_like(body):
		padding = max(7.0, config.orbit_distance_padding * 0.055)
	elif _is_star_like(body) and _is_star_like(parent):
		padding = max(18.0, config.orbit_distance_padding * 0.14)

	return max(12.0, parent_clearance + body_clearance + padding)

static func _normal_minimum_orbit_radius(body: SimulationPlanetData, parent: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if body == null or parent == null or config == null:
		return 120.0
	var clearance := parent.radius_world + body.radius_world + config.orbit_distance_padding
	if _is_moon_like(body):
		clearance = parent.radius_world + body.radius_world + config.orbit_distance_padding * 0.44
	elif _is_star_like(body) and _is_star_like(parent):
		clearance = parent.radius_world + body.radius_world + config.orbit_distance_padding * 1.35
	return max(config.min_visible_orbit_radius, clearance)

static func minimum_orbit_radius(body: SimulationPlanetData, parent: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if body == null or parent == null or config == null:
		return 120.0

	# Radius is now scaled only on the free orbit distance. The physical clearance
	# around the host/body is always added back, so 0.1 can get visually tight
	# without allowing the orbit center to enter the anchor.
	var slider := _stable_orbit_radius_value(config)
	var tight_clearance := tight_orbit_radius(body, parent, config)
	var normal_radius := max(tight_clearance, _normal_minimum_orbit_radius(body, parent, config))
	return _scaled_radius_with_clearance(tight_clearance, normal_radius, slider)

static func compact_orbit_lane_gap(body: SimulationPlanetData, existing: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if body == null or existing == null or config == null:
		return 48.0
	var a_collision := body.get_collision_radius(config)
	var b_collision := existing.get_collision_radius(config)
	var padding := max(10.0, config.orbit_distance_padding * 0.060)
	if _is_moon_like(body) or _is_moon_like(existing):
		padding = max(7.0, config.orbit_distance_padding * 0.035)
	return max(a_collision + b_collision + padding, body.radius_world + existing.radius_world + padding)

static func normal_orbit_lane_gap(body: SimulationPlanetData, existing: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if body == null or existing == null or config == null:
		return 120.0
	var compact := compact_orbit_lane_gap(body, existing, config)
	var wide := max(
		config.min_visible_orbit_radius * 1.42,
		body.get_collision_radius(config) * 2.70 + existing.get_collision_radius(config) * 0.38 + config.orbit_distance_padding * 1.04
	)
	if _is_moon_like(body) or _is_moon_like(existing):
		wide *= _moon_spacing_value(config)
	elif _is_star_like(body) and _is_star_like(existing):
		wide *= _binary_spacing_value(config)
	return max(compact, wide)

static func orbit_lane_gap(body: SimulationPlanetData, existing: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if body == null or existing == null or config == null:
		return 72.0
	var slider := _stable_orbit_radius_value(config)
	var spacing := _orbit_spacing_value(config)
	var compact := compact_orbit_lane_gap(body, existing, config)
	var normal := max(compact, normal_orbit_lane_gap(body, existing, config) * spacing)
	return _scaled_radius_with_clearance(compact, normal, slider)

static func stable_orbit_min_radius(body: SimulationPlanetData, parent: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	return tight_orbit_radius(body, parent, config)

static func stable_orbit_max_radius(body: SimulationPlanetData, parent: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if body == null or parent == null or config == null:
		return 120.0

	var min_radius := stable_orbit_min_radius(body, parent, config)
	var normal_minimum := max(min_radius, _normal_minimum_orbit_radius(body, parent, config))

	var body_radius_bonus := sqrt(max(body.radius_world, 8.0)) * 15.0
	var body_mass_bonus := pow(max(body.mass, 0.01), 0.34) * 34.0
	var parent_gravity_bonus := pow(max(parent.mass * abs(parent.gravitational_influence), 0.01), 0.18) * 18.0
	var kind_multiplier := 1.0
	if body.body_kind == SimulationPlanetData.BodyKind.SATELLITE:
		kind_multiplier = 0.34
	elif _is_moon_like(body):
		kind_multiplier = 0.48
	elif body.body_kind == SimulationPlanetData.BodyKind.RINGED_PLANET:
		kind_multiplier = 1.16
	elif body.body_kind == SimulationPlanetData.BodyKind.BLACK_HOLE or body.body_kind == SimulationPlanetData.BodyKind.WHITE_HOLE:
		kind_multiplier = 1.42
	elif _is_star_like(body) and _is_star_like(parent):
		kind_multiplier = 1.62

	return normal_minimum + (body_radius_bonus + body_mass_bonus + parent_gravity_bonus) * kind_multiplier

static func orbit_radius_from_min_max(min_radius: float, max_radius: float, config: SimulationPhysicsConfig) -> float:
	return _lerp_orbit_radius(min_radius, max_radius, _stable_orbit_radius_value(config))

static func preferred_orbit_radius(body: SimulationPlanetData, parent: SimulationPlanetData, config: SimulationPhysicsConfig, orbit_slot: int = 0) -> float:
	if body == null or parent == null or config == null:
		return 120.0

	var min_radius := stable_orbit_min_radius(body, parent, config)
	var max_radius := stable_orbit_max_radius(body, parent, config)

	# Fallback slot spacing for callers that do not have access to real inner lanes.
	# The main gravity solver uses actual previously assigned lanes instead.
	var slot := float(max(orbit_slot, 0))
	if slot > 0.0:
		var compact_gap := compact_orbit_lane_gap(body, parent, config)
		var normal_gap := max(compact_gap, normal_orbit_lane_gap(body, parent, config) * _orbit_spacing_value(config))
		min_radius += slot * compact_gap
		max_radius += slot * normal_gap

	return orbit_radius_from_min_max(min_radius, max_radius, config)

static func _lerp_orbit_radius(min_radius: float, max_radius: float, slider: float) -> float:
	var mn := max(min_radius, 1.0)
	var mx := max(max_radius, mn)
	var t := clamp((slider - 0.1) / 0.9, 0.0, 1.0)
	return lerp(mn, mx, t)

static func _scaled_radius_with_clearance(clearance_radius: float, normal_radius: float, slider: float) -> float:
	return _lerp_orbit_radius(clearance_radius, normal_radius, slider)

static func stable_radius_multiplier(config: SimulationPhysicsConfig) -> float:
	return _stable_orbit_radius_value(config)

static func orbit_spacing_multiplier(config: SimulationPhysicsConfig) -> float:
	return _orbit_spacing_value(config)

static func _lerp_from_slider(tight_value: float, wide_value: float, slider_value: float) -> float:
	var t := clamp((slider_value - 0.1) / 0.9, 0.0, 1.0)
	return lerp(tight_value, max(tight_value, wide_value), t)

static func _stable_orbit_radius_value(config: SimulationPhysicsConfig) -> float:
	if config == null:
		return 1.0
	if config.has_method("has_config_property") and config.has_config_property("stable_orbit_radius_multiplier"):
		return clamp(float(config.stable_orbit_radius_multiplier), 0.1, 1.0)
	return 1.0

static func _orbit_spacing_value(config: SimulationPhysicsConfig) -> float:
	if config == null:
		return 1.0
	if config.has_method("has_config_property") and config.has_config_property("orbit_spacing_multiplier"):
		return clamp(float(config.orbit_spacing_multiplier), 0.1, 1.0)
	return 1.0

static func _moon_spacing_value(config: SimulationPhysicsConfig) -> float:
	if config == null:
		return 1.0
	if config.has_method("has_config_property") and config.has_config_property("moon_orbit_spacing_multiplier"):
		return clamp(float(config.moon_orbit_spacing_multiplier), 0.1, 1.0)
	return 1.0

static func _binary_spacing_value(config: SimulationPhysicsConfig) -> float:
	if config == null:
		return 1.0
	if config.has_method("has_config_property") and config.has_config_property("binary_orbit_spacing_multiplier"):
		return clamp(float(config.binary_orbit_spacing_multiplier), 0.1, 1.0)
	return 1.0

static func minimum_binary_separation(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if a == null or b == null or config == null: return 220.0
	return max(a.radius_world + b.radius_world + max(config.min_visible_orbit_radius * 0.36, 28.0), config.min_visible_orbit_radius * 1.18)
static func are_good_binary_partners(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> bool:
	if a == null or b == null or config == null or not config.binary_orbits_enabled or not config.same_type_binary_enabled: return false
	if _is_moon_like(a) or _is_moon_like(b): return false
	if not _same_orbit_family(a, b): return false
	var smaller := min(max(a.mass, 0.001), max(b.mass, 0.001)); var larger := max(max(a.mass, 0.001), max(b.mass, 0.001))
	var required := clamp(config.binary_mass_similarity * (0.42 if _is_star_like(a) and _is_star_like(b) else 1.0), 0.08, 1.0)
	return smaller / larger >= required and a.position.distance_to(b.position) <= minimum_binary_separation(a, b, config) * config.binary_max_distance_multiplier
static func get_center_of_mass(bodies: Array) -> Vector2:
	var total := 0.0; var center := Vector2.ZERO
	for body in bodies:
		if _valid_node(body): center += body.data.position * body.data.mass; total += body.data.mass
	return Vector2.ZERO if total <= 0.0 else center / total
static func get_center_of_mass_velocity(bodies: Array) -> Vector2:
	var total := 0.0; var v := Vector2.ZERO
	for body in bodies:
		if _valid_node(body): v += body.data.velocity * body.data.mass; total += body.data.mass
	return Vector2.ZERO if total <= 0.0 else v / total
static func _max_orbit_speed(d: SimulationPlanetData) -> float: return 1800.0 if d == null else max(d.max_orbit_speed * 4.0, 80.0)
static func _same_orbit_family(a: SimulationPlanetData, b: SimulationPlanetData) -> bool:
	if _is_black_white_pair(a, b): return true
	if _is_star_like(a) and _is_star_like(b): return true
	if _is_planet_like(a) and _is_planet_like(b): return true
	return int(a.body_kind) == int(b.body_kind)
static func _is_black_white_pair(a: SimulationPlanetData, b: SimulationPlanetData) -> bool:
	if a == null or b == null: return false
	return (a.body_kind == SimulationPlanetData.BodyKind.BLACK_HOLE and b.body_kind == SimulationPlanetData.BodyKind.WHITE_HOLE) or (a.body_kind == SimulationPlanetData.BodyKind.WHITE_HOLE and b.body_kind == SimulationPlanetData.BodyKind.BLACK_HOLE)
static func _is_star_like(d: SimulationPlanetData) -> bool: return d != null and d.body_kind in [SimulationPlanetData.BodyKind.STAR, SimulationPlanetData.BodyKind.BLACK_HOLE, SimulationPlanetData.BodyKind.WHITE_HOLE, SimulationPlanetData.BodyKind.GALAXY]
static func _is_planet_like(d: SimulationPlanetData) -> bool: return d != null and d.body_kind in [SimulationPlanetData.BodyKind.PLANET, SimulationPlanetData.BodyKind.RINGED_PLANET]
static func _is_moon_like(d: SimulationPlanetData) -> bool: return d != null and d.body_kind in [SimulationPlanetData.BodyKind.MOON, SimulationPlanetData.BodyKind.SATELLITE]
static func _stable_direction(seed: String) -> Vector2: return Vector2.RIGHT.rotated(float(abs(hash(seed)) % 6283) / 1000.0).normalized()
static func _valid_pair(a, b, config: SimulationPhysicsConfig) -> bool: return a != null and b != null and config != null and is_instance_valid(a) and is_instance_valid(b) and a.data != null and b.data != null and a != b
static func _valid_node(body) -> bool: return body != null and is_instance_valid(body) and body.data != null

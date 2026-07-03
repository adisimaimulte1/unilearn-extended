extends Node2D
class_name SimulationSandboxController

signal body_added(body: SimulationPlanetBody)
signal body_removed(body: SimulationPlanetBody)
signal body_selected(body: SimulationPlanetBody)
signal collision_merged(survivor: SimulationPlanetBody, removed: SimulationPlanetBody)
signal universe_ended

@export var config: SimulationPhysicsConfig = SimulationPhysicsConfig.new()
@export var auto_select_added_body: bool = true
const UNIVERSE_END_FONT_PATH := "res://assets/fonts/JockeyOne-Regular.ttf"

var bodies: Array[SimulationPlanetBody] = []
var selected_body: SimulationPlanetBody = null
var paused: bool = false
var _universe_end_running: bool = false


func _physics_process(delta: float) -> void:
	if paused:
		return

	if config == null:
		return

	if config.gravity_enabled:
		SimulationGravitySolver.step(bodies, delta, config)

	_force_singularity_collapse(delta)

	var removed := SimulationCollisionSolver.solve(bodies, config)
	var should_end_universe := false
	for body in removed:
		var survivor := _find_collision_survivor(body)
		if survivor != null:
			collision_merged.emit(survivor, body)
			_notify_achievement_collision(survivor, body)

		if _has_universe_end_flag(body) or _has_universe_end_flag(survivor):
			should_end_universe = true

		_remove_body_internal(body)

	if should_end_universe:
		call_deferred("_trigger_universe_end")



func _initial_spawn_velocity_for(body: SimulationPlanetBody) -> Vector2:
	# Backwards-compatible wrapper. The real work is now done by
	# _assign_initial_orbit(), because the velocity must match the final reserved
	# orbit radius, not the random clicked/spawn distance.
	if not _assign_initial_orbit(body):
		return Vector2.ZERO
	return body.data.velocity if body != null and body.data != null else Vector2.ZERO


func _assign_initial_orbit(body: SimulationPlanetBody) -> bool:
	if body == null or body.data == null or bodies.is_empty() or config == null:
		return false

	var parent := _best_initial_orbit_host_for(body)
	if parent == null or parent.data == null:
		return false

	var d: SimulationPlanetData = body.data
	var h: SimulationPlanetData = parent.data
	if h.body_kind == SimulationPlanetData.BodyKind.WHITE_HOLE:
		return false

	var wanted_direction: Vector2 = d.position - h.position
	if wanted_direction.length_squared() < 4.0:
		wanted_direction = _stable_spawn_direction(d.instance_id)
	wanted_direction = wanted_direction.normalized()

	var slot := _next_orbit_slot_for_host(h.instance_id)
	var target_radius := SimulationOrbitUtils.preferred_orbit_radius(d, h, config, slot)
	target_radius = _find_clear_orbit_radius(d, h, target_radius)

	# Reserve the target lane, but keep the body at its spawn position. The
	# gravity solver will pull it into place instead of snapping it there.
	d.metadata["soft_orbit_radial_dir"] = wanted_direction
	d.metadata["stable_orbit_soft_recover"] = true
	d.orbit_parent_id = h.instance_id
	d.orbit_radius = target_radius
	d.orbit_clockwise = _stable_clockwise(d.instance_id)
	d.orbit_phase = atan2(wanted_direction.y, wanted_direction.x)
	d.orbit_locked = config.stable_orbit_mode and h.body_kind != SimulationPlanetData.BodyKind.BLACK_HOLE
	d.metadata["orbit_architecture_dirty"] = false
	d.metadata["spawn_orbit_seeded"] = true
	d.metadata["spawn_orbit_slot"] = slot
	d.metadata["collision_protected_until_ms"] = Time.get_ticks_msec() + 4200
	d.metadata["orbit_temperature_adjusted"] = true
	d.reset_trail()

	_apply_distance_environment(body, parent, target_radius)

	var radial_dir := wanted_direction
	var tangent := Vector2(-radial_dir.y, radial_dir.x)
	if d.orbit_clockwise:
		tangent = -tangent

	var orbit_speed := _safe_circular_orbit_speed(d, h, target_radius)
	# A tiny support margin avoids the first gravity step becoming a death dive,
	# especially when the anchor has strong gravity or the user spawned the body
	# very close before we moved it to its reserved lane.
	var support_multiplier := 1.04
	d.velocity = h.velocity + tangent * min(orbit_speed * support_multiplier, max(d.max_orbit_speed * 4.0, 80.0))
	return true


func _best_initial_orbit_host_for(body: SimulationPlanetBody) -> SimulationPlanetBody:
	if body == null or body.data == null:
		return null

	var d: SimulationPlanetData = body.data
	var anchor := _current_static_anchor_body(body)

	if d.body_kind in [SimulationPlanetData.BodyKind.MOON, SimulationPlanetData.BodyKind.SATELLITE]:
		# Moons prefer non-anchor planets first. If the anchor is a planet, they orbit
		# that planet. If the anchor is a star and only moons exist, the strongest moon
		# becomes the mini-planet and smaller moons orbit it.
		var non_anchor_planet := _best_initial_planet_host_for_moon(body, true)
		if non_anchor_planet != null:
			return non_anchor_planet
		if anchor != null and anchor.data != null and anchor.data.body_kind in [SimulationPlanetData.BodyKind.PLANET, SimulationPlanetData.BodyKind.RINGED_PLANET]:
			return anchor
		if anchor != null and anchor.data != null and _initial_is_star_like(anchor.data):
			var stronger_moon := _best_initial_stronger_moon_host(body)
			if stronger_moon != null:
				return stronger_moon
		var any_planet := _best_initial_planet_host_for_moon(body, false)
		if any_planet != null:
			return any_planet
		return anchor if anchor != null else _best_gravity_host_for(body)

	if d.body_kind in [SimulationPlanetData.BodyKind.PLANET, SimulationPlanetData.BodyKind.RINGED_PLANET]:
		if anchor != null and anchor.data != null:
			if _initial_is_star_like(anchor.data):
				return anchor
			if anchor.data.body_kind in [SimulationPlanetData.BodyKind.PLANET, SimulationPlanetData.BodyKind.RINGED_PLANET] and _initial_host_power(anchor.data) >= _initial_host_power(d) * 0.92:
				return anchor
		var star := _best_initial_host_by_roles(body, [SimulationPlanetData.BodyKind.STAR, SimulationPlanetData.BodyKind.BLACK_HOLE, SimulationPlanetData.BodyKind.GALAXY], false)
		return star if star != null else (anchor if anchor != null else _best_gravity_host_for(body))

	if d.body_kind in [SimulationPlanetData.BodyKind.STAR, SimulationPlanetData.BodyKind.BLACK_HOLE, SimulationPlanetData.BodyKind.WHITE_HOLE, SimulationPlanetData.BodyKind.GALAXY]:
		var star_host := _best_initial_host_by_roles(body, [SimulationPlanetData.BodyKind.STAR, SimulationPlanetData.BodyKind.BLACK_HOLE, SimulationPlanetData.BodyKind.GALAXY], false)
		return star_host if star_host != null else (anchor if anchor != null else null)

	return anchor if anchor != null else _best_gravity_host_for(body)


func _initial_is_star_like(d: SimulationPlanetData) -> bool:
	return d != null and d.body_kind in [SimulationPlanetData.BodyKind.STAR, SimulationPlanetData.BodyKind.BLACK_HOLE, SimulationPlanetData.BodyKind.WHITE_HOLE, SimulationPlanetData.BodyKind.GALAXY]


func _initial_host_power(d: SimulationPlanetData) -> float:
	if d == null:
		return 0.0
	return max(d.mass, 0.001) * max(abs(d.gravitational_influence), 0.001) * max(d.radius_world, 1.0)


func _best_initial_planet_host_for_moon(body: SimulationPlanetBody, exclude_static_anchor: bool) -> SimulationPlanetBody:
	if body == null or body.data == null:
		return null
	var best: SimulationPlanetBody = null
	var best_score := INF
	for candidate in bodies:
		if candidate == body or candidate == null or not is_instance_valid(candidate) or candidate.data == null:
			continue
		var c: SimulationPlanetData = candidate.data
		if exclude_static_anchor and c.is_static_anchor:
			continue
		if not (c.body_kind in [SimulationPlanetData.BodyKind.PLANET, SimulationPlanetData.BodyKind.RINGED_PLANET]):
			continue
		if c.radius_world <= body.data.radius_world * 1.08 and _initial_host_power(c) <= _initial_host_power(body.data) * 1.18:
			continue
		var distance := max(body.data.position.distance_to(c.position), 1.0)
		var score: float = distance / max(_initial_host_power(c), 0.001)
		if score < best_score:
			best_score = score
			best = candidate
	return best


func _best_initial_stronger_moon_host(body: SimulationPlanetBody) -> SimulationPlanetBody:
	if body == null or body.data == null:
		return null
	var best: SimulationPlanetBody = null
	var best_score := INF
	for candidate in bodies:
		if candidate == body or candidate == null or not is_instance_valid(candidate) or candidate.data == null:
			continue
		var c: SimulationPlanetData = candidate.data
		if not (c.body_kind in [SimulationPlanetData.BodyKind.MOON, SimulationPlanetData.BodyKind.SATELLITE]):
			continue
		if c.radius_world <= body.data.radius_world * 1.04 and _initial_host_power(c) <= _initial_host_power(body.data) * 1.16:
			continue
		var distance := max(body.data.position.distance_to(c.position), 1.0)
		var score: float = distance / max(_initial_host_power(c), 0.001)
		if score < best_score:
			best_score = score
			best = candidate
	return best


func _best_initial_host_by_roles(body: SimulationPlanetBody, roles: Array, allow_lighter: bool) -> SimulationPlanetBody:
	if body == null or body.data == null or roles.is_empty():
		return null
	var best: SimulationPlanetBody = null
	var best_score := INF
	for candidate in bodies:
		if candidate == body or candidate == null or not is_instance_valid(candidate) or candidate.data == null:
			continue
		var c: SimulationPlanetData = candidate.data
		if not roles.has(c.body_kind):
			continue
		if c.body_kind == SimulationPlanetData.BodyKind.WHITE_HOLE and body.data.body_kind != SimulationPlanetData.BodyKind.BLACK_HOLE:
			continue
		if not allow_lighter and c.mass <= body.data.mass and not c.is_static_anchor:
			continue
		var distance := max(body.data.position.distance_to(c.position), 1.0)
		var gravity := max(sqrt(max(c.mass, 0.001)) * abs(c.gravitational_influence), 0.001)
		var role_bonus := 1.0
		if c.is_static_anchor:
			role_bonus = 0.12
		elif c.body_kind == SimulationPlanetData.BodyKind.STAR:
			role_bonus = 0.2
		elif c.body_kind == SimulationPlanetData.BodyKind.BLACK_HOLE or c.body_kind == SimulationPlanetData.BodyKind.GALAXY:
			role_bonus = 0.28
		elif c.body_kind in [SimulationPlanetData.BodyKind.PLANET, SimulationPlanetData.BodyKind.RINGED_PLANET]:
			role_bonus = 0.7
		var score: float = distance / gravity * role_bonus
		if score < best_score:
			best_score = score
			best = candidate
	return best


func _current_static_anchor_body(ignored: SimulationPlanetBody = null) -> SimulationPlanetBody:
	var best: SimulationPlanetBody = null
	var best_score := -INF
	for candidate in bodies:
		if candidate == ignored or candidate == null or not is_instance_valid(candidate) or candidate.data == null:
			continue
		if not candidate.data.is_static_anchor:
			continue
		var score: float = candidate.data.mass * max(abs(candidate.data.gravitational_influence), 0.001)
		if score > best_score:
			best_score = score
			best = candidate
	return best


func _best_gravity_host_for(body: SimulationPlanetBody) -> SimulationPlanetBody:
	if body == null or body.data == null:
		return null
	var best: SimulationPlanetBody = null
	var best_score := INF
	for candidate in bodies:
		if candidate == body or candidate == null or not is_instance_valid(candidate) or candidate.data == null:
			continue
		var c: SimulationPlanetData = candidate.data
		if c.body_kind == SimulationPlanetData.BodyKind.WHITE_HOLE and body.data.body_kind != SimulationPlanetData.BodyKind.BLACK_HOLE:
			continue
		var distance := max(body.data.position.distance_to(c.position), 1.0)
		var gravity := max(sqrt(max(c.mass, 0.001)) * abs(c.gravitational_influence), 0.001)
		var role_bonus := 1.0
		if c.is_static_anchor:
			role_bonus = 0.12
		elif c.body_kind in [SimulationPlanetData.BodyKind.STAR, SimulationPlanetData.BodyKind.BLACK_HOLE, SimulationPlanetData.BodyKind.GALAXY]:
			role_bonus = 0.25
		elif c.body_kind in [SimulationPlanetData.BodyKind.PLANET, SimulationPlanetData.BodyKind.RINGED_PLANET]:
			role_bonus = 0.72
		var score: float = distance / gravity * role_bonus
		if score < best_score:
			best_score = score
			best = candidate
	return best


func _next_orbit_slot_for_host(host_id: String) -> int:
	var highest_slot := -1
	var count := 0
	for existing in bodies:
		if existing == null or not is_instance_valid(existing) or existing.data == null:
			continue
		var ed: SimulationPlanetData = existing.data
		if str(ed.orbit_parent_id) != host_id:
			continue
		count += 1
		if ed.metadata.has("spawn_orbit_slot"):
			highest_slot = max(highest_slot, int(ed.metadata.get("spawn_orbit_slot", -1)))
	return max(count, highest_slot + 1)


func _tight_orbit_radius_local(body_data: SimulationPlanetData, host_data: SimulationPlanetData) -> float:
	if body_data == null or host_data == null or config == null:
		return 72.0
	return SimulationOrbitUtils.tight_orbit_radius(body_data, host_data, config)

func _find_clear_orbit_radius(body_data: SimulationPlanetData, host_data: SimulationPlanetData, requested_radius: float) -> float:
	# Keep the scaled target, but add physical clearance after the scaling.
	# This means 0.1 is still close, while the orbit center cannot be inside the
	# anchor, a binary host envelope, or an inner body lane.
	var safe_radius := max(requested_radius, _tight_orbit_radius_local(body_data, host_data))
	if body_data == null or host_data == null:
		return safe_radius

	for existing in bodies:
		if existing == null or not is_instance_valid(existing) or existing.data == null:
			continue
		var ed: SimulationPlanetData = existing.data
		if str(ed.orbit_parent_id) != str(host_data.instance_id):
			continue
		if ed.orbit_radius <= 0.0:
			continue
		# Only bodies already closer to the same host are "in front" of this lane.
		# Add their current lane radius plus a collision-safe lane gap.
		if ed.orbit_radius <= safe_radius + 0.001:
			safe_radius = max(safe_radius, ed.orbit_radius + _minimum_orbit_lane_gap(body_data, ed))

	return safe_radius


func _minimum_orbit_lane_gap(a: SimulationPlanetData, b: SimulationPlanetData) -> float:
	if a != null and b != null and config != null:
		return SimulationOrbitUtils.orbit_lane_gap(a, b, config)
	var a_collision := a.get_collision_radius(config) if a != null and config != null else 30.0
	var b_collision := b.get_collision_radius(config) if b != null and config != null else 30.0
	return max(a_collision + b_collision + 18.0, 48.0)


func _safe_circular_orbit_speed(body_data: SimulationPlanetData, host_data: SimulationPlanetData, radius: float) -> float:
	if body_data == null or host_data == null or config == null:
		return 120.0
	var speed_multiplier := config.get_orbit_speed_multiplier() if config.has_method("get_orbit_speed_multiplier") else clamp(config.revolution_speed_multiplier, 0.05, 32.0)
	var host_gravity := max(host_data.mass * abs(host_data.gravitational_influence), 0.001)
	var radius_slider := SimulationOrbitUtils.stable_radius_multiplier(config)
	var support := lerp(0.96, 1.08, radius_slider)
	return sqrt(max(config.gravitational_constant * host_gravity / max(radius, 1.0), 0.0)) * speed_multiplier * support


func _stable_spawn_direction(seed: String) -> Vector2:
	var h := abs(hash(seed))
	return Vector2.RIGHT.rotated(float(h % 6283) / 1000.0).normalized()


func _stable_clockwise(seed: String) -> bool:
	return abs(hash(seed)) % 2 == 0


func _apply_distance_environment(body: SimulationPlanetBody, parent: SimulationPlanetBody, orbit_radius: float) -> void:
	if body == null or body.data == null or parent == null or parent.data == null or config == null:
		return
	var d: SimulationPlanetData = body.data
	var h: SimulationPlanetData = parent.data
	if not _is_star_heat_source(h) or not _is_environment_mutable_body(d):
		return
	var source := d.source_planet_data
	if source == null:
		return

	var minimum_radius := max(SimulationOrbitUtils.minimum_orbit_radius(d, h, config), 1.0)
	var distance_band: float = orbit_radius / minimum_radius
	var original_preset := source.planet_preset.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	var original_archetype := source.archetype_id.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	var adjusted: PlanetData = null

	if distance_band <= 1.38:
		adjusted = source.duplicate(true) as PlanetData
		if original_preset.contains("gas") or original_archetype.contains("gas") or d.body_kind == SimulationPlanetData.BodyKind.RINGED_PLANET:
			adjusted.planet_preset = "gas_giant_1"
			adjusted.archetype_id = "hot_gas_giant"
			adjusted.subtitle = "Close-orbit hot giant"
			adjusted.use_custom_colors = true
			adjusted.custom_colors = PackedColorArray([Color("#fff0a8"), Color("#ffb04a"), Color("#d85c24"), Color("#5b1d16")])
		else:
			adjusted.planet_preset = "lava_world"
			adjusted.archetype_id = "lava_world"
			adjusted.subtitle = "Close-orbit scorched world"
			adjusted.use_custom_colors = true
			adjusted.custom_colors = PackedColorArray([Color("#32100c"), Color("#8d2f16"), Color("#ff6a24"), Color("#ffd36a")])
		adjusted.average_temperature = "Extremely hot"
		adjusted.atmosphere = _replace_environment_text(adjusted.atmosphere, "Heat-stripped or superheated atmosphere")
		adjusted.surface_geology = _replace_environment_text(adjusted.surface_geology, "Scorched, molten, or dry surface; no stable water or ice")
		adjusted.habitability_note = "Too close to the star for liquid water or surface ice."
	elif distance_band >= 3.85:
		adjusted = source.duplicate(true) as PlanetData
		adjusted.planet_preset = "ice_world"
		if original_preset.contains("gas") or original_archetype.contains("gas") or d.mass >= 40.0 or d.body_kind == SimulationPlanetData.BodyKind.RINGED_PLANET:
			adjusted.archetype_id = "ice_giant"
			adjusted.subtitle = "Outer frozen giant"
			adjusted.composition = _replace_environment_text(adjusted.composition, "Hydrogen, helium, methane ice, ammonia ice, and frozen volatiles")
		else:
			adjusted.archetype_id = "frozen_dwarf_planet" if d.mass <= 4.0 else "ice_world"
			adjusted.subtitle = "Outer frozen world"
			adjusted.composition = _replace_environment_text(adjusted.composition, "Rock, water ice, nitrogen ice, methane ice, and frozen volatiles")
		adjusted.average_temperature = "Extremely cold"
		adjusted.atmosphere = _replace_environment_text(adjusted.atmosphere, "Thin, frozen, or methane-rich outer-system atmosphere")
		adjusted.surface_geology = _replace_environment_text(adjusted.surface_geology, "Frozen crust; no molten or desert surface conditions")
		adjusted.habitability_note = "Far from the star, so heat-based biomes are suppressed and volatiles freeze out."
		adjusted.use_custom_colors = true
		adjusted.custom_colors = PackedColorArray([Color("#dffbff"), Color("#9be7ff"), Color("#4e9ed9"), Color("#1d3f73")])
	else:
		# Temperate and middle lanes keep the AI/card biome. This prevents every body
		# from being overwritten while still blocking impossible close-water / far-lava cases.
		return

	if adjusted != null:
		body.force_apply_planet_data(adjusted)
		d.metadata["distance_environment_band"] = distance_band
		d.metadata["distance_environment_host"] = h.instance_id


func _replace_environment_text(current: String, fallback: String) -> String:
	var clean := current.strip_edges()
	return fallback if clean.is_empty() else fallback


func _is_star_heat_source(d: SimulationPlanetData) -> bool:
	if d == null:
		return false
	return d.body_kind == SimulationPlanetData.BodyKind.STAR


func _is_environment_mutable_body(d: SimulationPlanetData) -> bool:
	if d == null:
		return false
	if d.body_kind in [SimulationPlanetData.BodyKind.PLANET, SimulationPlanetData.BodyKind.RINGED_PLANET, SimulationPlanetData.BodyKind.MOON]:
		return true
	return false

func add_planet_data(planet_data: PlanetData, spawn_position: Vector2) -> SimulationPlanetBody:
	var body := SimulationPlanetFactory.create_body_from_planet_data(planet_data, spawn_position)
	add_body(body)
	return body


func add_body(body: SimulationPlanetBody) -> void:
	if body == null:
		return
	if body.data != null and body.data.velocity.length_squared() <= 0.001 and bodies.size() > 0:
		_assign_initial_orbit(body)
	add_child(body)
	bodies.append(body)
	body.pressed.connect(_on_body_pressed)
	body.drag_started.connect(_on_body_drag_started)
	body.drag_finished.connect(_on_body_drag_finished)
	body_added.emit(body)
	if auto_select_added_body:
		select_body(body)
	if config != null and config.auto_orbit_enabled:
		SimulationGravitySolver.prime_orbit_architecture(bodies, config, true)


func remove_body(body: SimulationPlanetBody) -> void:
	_remove_body_internal(body)


func clear_all() -> void:
	for body in bodies.duplicate():
		_remove_body_internal(body)
	bodies.clear()
	selected_body = null


func select_body(body: SimulationPlanetBody) -> void:
	for b in bodies:
		if b != null and is_instance_valid(b):
			b.set_selected(b == body)
	selected_body = body
	body_selected.emit(body)


func pause_simulation() -> void:
	paused = true


func resume_simulation() -> void:
	paused = false


func toggle_pause() -> void:
	paused = not paused


func make_selected_orbit_nearest(clockwise: bool = true, elliptical: bool = false) -> bool:
	if selected_body == null:
		return false
	var parent = SimulationOrbitUtils.find_best_orbit_parent(selected_body, bodies, config.orbit_snap_distance * 5.0)
	if parent == null:
		return false
	if elliptical:
		return SimulationOrbitUtils.make_elliptical_orbit(selected_body, parent, config, 0.25, clockwise, true)
	return SimulationOrbitUtils.make_circular_orbit(selected_body, parent, config, clockwise, -1.0, true)


func create_binary_from_selection(other: SimulationPlanetBody, clockwise: bool = true) -> bool:
	if selected_body == null or other == null:
		return false
	return SimulationOrbitUtils.create_mutual_binary_orbit(selected_body, other, config, clockwise, -1.0, true, false)


func reset_system_orbits() -> void:
	if config == null:
		return
	SimulationGravitySolver.prime_orbit_architecture(bodies, config, true)


func get_nearest_body_to(point: Vector2, max_distance: float = INF, ignored: SimulationPlanetBody = null) -> SimulationPlanetBody:
	var best: SimulationPlanetBody = null
	var best_dist: float = max_distance
	for body in bodies:
		if body == ignored or body == null or not is_instance_valid(body) or body.data == null:
			continue
		var d: float = body.data.position.distance_to(point)
		if d < best_dist:
			best_dist = d
			best = body
	return best


func predict_paths(seconds: float = 10.0, samples: int = 180) -> Dictionary:
	return SimulationTrajectoryPredictor.predict_paths(bodies, config, seconds, samples)


func _on_body_pressed(body: SimulationPlanetBody) -> void:
	select_body(body)


func _on_body_drag_started(body: SimulationPlanetBody) -> void:
	select_body(body)


func _on_body_drag_finished(body: SimulationPlanetBody, release_velocity: Vector2) -> void:
	if body == null or body.data == null:
		return

	var capped_release := release_velocity.limit_length(config.max_drag_throw_speed)
	if capped_release.length() < 65.0:
		capped_release = Vector2.ZERO
	body.data.velocity = Vector2.ZERO if config.ignore_drag_throw_velocity else capped_release * config.drag_throw_strength

	if config != null and config.stable_orbit_mode and not body.data.orbit_parent_id.is_empty() and body.data.orbit_radius > 0.0:
		body.data.orbit_locked = true
		body.data.metadata["stable_orbit_soft_recover"] = true
		body.data.metadata.erase("orbit_architecture_dirty")
		body.data.reset_trail()
		return

	if config.auto_orbit_enabled:
		SimulationGravitySolver.prime_orbit_architecture(bodies, config, true)


func _remove_body_internal(body: SimulationPlanetBody) -> void:
	if body == null:
		return
	bodies.erase(body)
	if selected_body == body:
		selected_body = null
	body_removed.emit(body)
	if is_instance_valid(body):
		body.queue_free()
	if config != null:
		SimulationGravitySolver.prime_orbit_architecture(bodies, config, true)


func _force_singularity_collapse(delta: float) -> void:
	if _universe_end_running or bodies.size() < 2 or delta <= 0.0:
		return

	var black_holes: Array = []
	var white_holes: Array = []
	for body in bodies:
		if body == null or not is_instance_valid(body) or body.data == null:
			continue
		if _is_black_hole_body(body):
			black_holes.append(body)
		elif _is_white_hole_body(body):
			white_holes.append(body)

	if black_holes.is_empty() or white_holes.is_empty():
		return

	for black in black_holes:
		for white in white_holes:
			if black == null or white == null or not is_instance_valid(black) or not is_instance_valid(white):
				continue
			if black.data == null or white.data == null:
				continue

			black.data.is_static_anchor = false
			white.data.is_static_anchor = false
			black.data.orbit_locked = false
			white.data.orbit_locked = false
			black.data.orbit_parent_id = white.data.instance_id
			white.data.orbit_parent_id = black.data.instance_id
			black.data.metadata["binary_partner_id"] = white.data.instance_id
			white.data.metadata["binary_partner_id"] = black.data.instance_id
			black.data.metadata["binary_center_locked"] = false
			white.data.metadata["binary_center_locked"] = false
			black.data.metadata["gravity_polarity"] = "attractive"
			white.data.metadata["gravity_polarity"] = "attractive"
			black.data.metadata["death_dance_pair"] = white.data.instance_id
			white.data.metadata["death_dance_pair"] = black.data.instance_id
			black.data.metadata["death_dance_ignore_binary_reseed"] = true
			white.data.metadata["death_dance_ignore_binary_reseed"] = true
			black.data.metadata["black_hole_unstable_orbit"] = true
			white.data.metadata["black_hole_unstable_orbit"] = true

			var offset: Vector2 = white.data.position - black.data.position
			var distance: float = offset.length()
			if distance < 1.0:
				offset = Vector2.RIGHT.rotated(float(abs(hash(black.data.instance_id + white.data.instance_id)) % 6283) / 1000.0)
				distance = 1.0
			var direction: Vector2 = offset / distance
			var combined_radius: float = black.data.get_collision_radius(config) + white.data.get_collision_radius(config)
			var end_distance: float = max(combined_radius * 0.62, 8.0)
			var protected_distance: float = max(combined_radius * 0.36, 6.0)
			var dance_duration: float = 18.5
			var dance_elapsed: float = float(black.data.metadata.get("death_dance_elapsed", 0.0)) + delta
			black.data.metadata["death_dance_elapsed"] = dance_elapsed
			white.data.metadata["death_dance_elapsed"] = dance_elapsed

			if not bool(black.data.metadata.get("death_dance_initialized", false)):
				black.data.metadata["death_dance_initialized"] = true
				white.data.metadata["death_dance_initialized"] = true
				black.data.metadata["death_dance_start_distance"] = distance
				white.data.metadata["death_dance_start_distance"] = distance
				black.data.metadata["death_dance_collision_ready"] = false
				white.data.metadata["death_dance_collision_ready"] = false

			var dance_start_distance: float = max(float(black.data.metadata.get("death_dance_start_distance", distance)), 1.0)
			var time_progress: float = clamp(dance_elapsed / dance_duration, 0.0, 1.0)
			var time_curve: float = time_progress * time_progress * (3.0 - 2.0 * time_progress)
			var collapse_curve: float = clamp((time_progress - 0.86) / 0.14, 0.0, 1.0)
			collapse_curve = collapse_curve * collapse_curve * (3.0 - 2.0 * collapse_curve)
			var curve: float = max(time_curve, clamp(1.0 - distance / max(combined_radius * 54.0, 42000.0), 0.0, 1.0))
			var total_mass: float = max(black.data.mass + white.data.mass, 0.001)
			var black_share: float = white.data.mass / total_mass
			var white_share: float = black.data.mass / total_mass
			var old_black_position: Vector2 = black.data.position
			var old_white_position: Vector2 = white.data.position
			var barycenter: Vector2 = (black.data.position * black.data.mass + white.data.position * white.data.mass) / total_mass
			var target_barycenter: Vector2 = barycenter.lerp(Vector2.ZERO, clamp(time_curve * 0.82, 0.0, 1.0))
			var swirl_sign := -1.0 if black.data.instance_id < white.data.instance_id else 1.0
			var angular_speed: float = lerp(1.05, 8.4, curve)
			var next_direction := direction.rotated(swirl_sign * angular_speed * delta).normalized()
			var natural_start_distance: float = max(dance_start_distance, combined_radius * 1.42)
			var pre_collapse_distance: float = lerp(natural_start_distance, protected_distance, time_curve)
			var final_distance: float = lerp(protected_distance, max(end_distance * 0.42, 2.0), collapse_curve)
			var target_distance: float = pre_collapse_distance
			if collapse_curve > 0.0:
				target_distance = min(target_distance, final_distance)
			target_distance = max(target_distance, 1.0)
			var black_target_position: Vector2 = target_barycenter - next_direction * target_distance * black_share
			var white_target_position: Vector2 = target_barycenter + next_direction * target_distance * white_share

			var position_blend: float = clamp(delta * lerp(0.85, 3.25, curve), 0.0, 0.14)
			var black_next_position: Vector2 = old_black_position.lerp(black_target_position, position_blend)
			var white_next_position: Vector2 = old_white_position.lerp(white_target_position, position_blend)
			var black_desired_velocity: Vector2 = (black_next_position - old_black_position) / max(delta, 0.0001)
			var white_desired_velocity: Vector2 = (white_next_position - old_white_position) / max(delta, 0.0001)
			var velocity_blend: float = clamp(delta * 2.2, 0.0, 0.22)

			black.data.previous_position = old_black_position
			white.data.previous_position = old_white_position
			black.data.position = black_next_position
			white.data.position = white_next_position
			black.data.velocity = black.data.velocity.lerp(black_desired_velocity, velocity_blend).limit_length(18000.0)
			white.data.velocity = white.data.velocity.lerp(white_desired_velocity, velocity_blend).limit_length(18000.0)
			var current_pair_distance: float = black_next_position.distance_to(white_next_position)
			var collision_ready: bool = dance_elapsed >= dance_duration * 0.94 and current_pair_distance <= combined_radius * 1.05
			black.data.metadata["death_dance_collision_ready"] = collision_ready
			white.data.metadata["death_dance_collision_ready"] = collision_ready
			black.sync_from_data()
			white.sync_from_data()

			if collision_ready:
				black.data.metadata["universe_end_collision"] = true
				white.data.metadata["universe_end_collision"] = true
				call_deferred("_trigger_universe_end")
				return



func _find_collision_survivor(removed_body: SimulationPlanetBody) -> SimulationPlanetBody:
	if removed_body == null or removed_body.data == null:
		return null
	var removed_name := removed_body.data.get_display_name()
	var best: SimulationPlanetBody = null
	var best_score := INF
	for body in bodies:
		if body == removed_body or body == null or not is_instance_valid(body) or body.data == null:
			continue
		var last_absorbed := str(body.data.metadata.get("last_absorbed", ""))
		if last_absorbed == removed_name:
			return body
		var d := body.data.position.distance_squared_to(removed_body.data.position)
		if d < best_score:
			best_score = d
			best = body
	return best


func _has_universe_end_flag(body: Variant) -> bool:
	if body == null:
		return false
	if body is SimulationPlanetBody:
		if body.data == null:
			return false
		return bool(body.data.metadata.get("universe_end_collision", false))
	if body is SimulationPlanetData:
		return bool(body.metadata.get("universe_end_collision", false))
	return false


func _trigger_universe_end() -> void:
	if _universe_end_running:
		return
	_universe_end_running = true
	paused = true
	universe_ended.emit()

	var layer := CanvasLayer.new()
	layer.layer = 4096
	var flash := ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)
	var label := Label.new()
	label.text = ""
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", Color.BLACK)
	var end_font := load(UNIVERSE_END_FONT_PATH) as Font
	if end_font != null:
		label.add_theme_font_override("font", end_font)
	label.add_theme_font_size_override("font_size", 220)
	layer.add_child(label)
	get_tree().root.add_child(layer)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(flash, "color", Color(1.0, 1.0, 1.0, 1.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	await _type_universe_end_label(label, "THE END", 0.23)
	await get_tree().create_timer(1.0, true, false, true).timeout
	label.text += "?"
	await get_tree().create_timer(0.5, true, false, true).timeout

	clear_all()

	var fade := create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(flash, "color", Color(1.0, 1.0, 1.0, 0.0), 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.parallel().tween_property(label, "modulate:a", 0.0, 0.85)
	await fade.finished

	if is_instance_valid(layer):
		layer.queue_free()
	_unlock_universe_end_achievement()
	paused = false
	_universe_end_running = false


func _type_universe_end_label(label: Label, text: String, delay: float) -> void:
	label.text = ""
	for i in range(text.length()):
		label.text += text.substr(i, 1)
		await get_tree().create_timer(delay, true, false, true).timeout


func _notify_achievement_collision(survivor: SimulationPlanetBody, removed: SimulationPlanetBody) -> void:
	var tracker := _get_achievement_tracker()
	if tracker == null:
		return
	var collision_a: Variant = null
	var collision_b: Variant = null
	var collision_survivor: Variant = null
	if removed != null and is_instance_valid(removed) and removed.data != null:
		collision_a = removed.data.metadata.get("achievement_collision_a", null)
		collision_b = removed.data.metadata.get("achievement_collision_b", null)
		collision_survivor = removed.data.metadata.get("achievement_collision_survivor", null)
	if collision_a != null and collision_b != null and tracker.has_method("register_collision"):
		tracker.call("register_collision", collision_a, collision_b, collision_survivor)
	elif tracker.has_method("register_collision"):
		tracker.call("register_collision", survivor, removed, survivor)
	elif tracker.has_method("record_planet_collision"):
		tracker.call("record_planet_collision", survivor, removed)


func _unlock_universe_end_achievement() -> void:
	var tracker := _get_achievement_tracker()
	if tracker == null:
		return
	if tracker.has_method("unlock"):
		tracker.call("unlock", "the_end_of_the_universe")
	elif tracker.has_method("record_planet_collision"):
		tracker.call("record_planet_collision")


func _get_achievement_tracker() -> Node:
	var root := get_tree().root
	var names := ["UnilearnAchievementTracker", "AchievementTracker", "Achievements"]
	for name in names:
		var node := root.get_node_or_null(NodePath(name))
		if node != null:
			return node
	return null


func _is_black_hole_body(body: SimulationPlanetBody) -> bool:
	return body != null and body.data != null and body.data.body_kind == SimulationPlanetData.BodyKind.BLACK_HOLE


func _is_white_hole_body(body: SimulationPlanetBody) -> bool:
	return body != null and body.data != null and body.data.body_kind == SimulationPlanetData.BodyKind.WHITE_HOLE


func _is_star_like_data(d: SimulationPlanetData) -> bool:
	return d != null and d.body_kind in [SimulationPlanetData.BodyKind.STAR, SimulationPlanetData.BodyKind.BLACK_HOLE, SimulationPlanetData.BodyKind.WHITE_HOLE, SimulationPlanetData.BodyKind.GALAXY]


func _is_moon_like_data(d: SimulationPlanetData) -> bool:
	return d != null and d.body_kind in [SimulationPlanetData.BodyKind.MOON, SimulationPlanetData.BodyKind.SATELLITE]

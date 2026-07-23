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
const FORCE_ANCHOR_UNTIL_KEY := "force_anchor_until_ms"
const SOFT_ORBIT_RADIAL_DIR_KEY := "soft_orbit_radial_dir"
const VERLET_ACCELERATION_VALID_KEY := "verlet_acceleration_valid"

static func step(bodies: Array, delta: float, config: SimulationPhysicsConfig) -> void:
	if bodies.is_empty() or config == null: return
	# Do not rebuild the whole parent/binary/orbit architecture every physics frame.
	# That was the real lag source with 8+ bodies, even when trails were disabled.
	# Explicit add/remove/collision/config paths still call prime_orbit_architecture(..., true).
	prime_orbit_architecture(bodies, config, false)
	var runtime_delta := min(delta, _runtime_delta_cap(bodies.size()))
	var substeps: int = _runtime_substep_count(bodies.size(), runtime_delta, config)
	var h: float = (runtime_delta * config.simulation_speed) / float(substeps)
	var id_lookup := _build_body_id_lookup(bodies)
	var sparse_gravity_pairs := _build_sparse_gravity_pairs(bodies, config)
	var moon_orbit_cache := _build_moon_orbit_frame_cache(bodies, config, id_lookup)
	var old_accels: Array[Vector2] = []
	old_accels.resize(bodies.size())
	var base_accels: Array[Vector2] = []
	base_accels.resize(bodies.size())

	# Carry the acceleration calculated at the end of the previous Verlet step.
	# Recalculating it at both ends of every step doubled gravity and constraint work.
	var acceleration_cache_valid := true
	for body in bodies:
		if not _valid_body(body):
			continue
		if body.data.is_dragging:
			body.data.metadata[VERLET_ACCELERATION_VALID_KEY] = false
		if not bool(body.data.metadata.get(VERLET_ACCELERATION_VALID_KEY, false)):
			acceleration_cache_valid = false
	if not acceleration_cache_valid:
		compute_accelerations(bodies, config, id_lookup, sparse_gravity_pairs, moon_orbit_cache, base_accels)
		_mark_verlet_acceleration_valid(bodies)

	# Keep simulation math substepped, but do NOT push Node2D transforms every
	# substep. Updating scene nodes multiple times before one frame is drawn creates
	# visible frame pacing spikes on mobile. Sync once after all substeps instead.
	for _s in range(substeps):
		_apply_black_hole_orbit_decay(bodies, abs(h), config)
		_step_verlet(bodies, h, config, id_lookup, sparse_gravity_pairs, moon_orbit_cache, old_accels, base_accels)

	_record_frame_trails(bodies, config)
	_sync_bodies_from_data(bodies)


static func _runtime_delta_cap(body_count: int) -> float:
	# Prevent a bad frame from creating a physics death spiral. Under heavy load,
	# sim time may slow slightly, but the app recovers instead of stacking 20-30
	# substeps and dropping to single-digit FPS.
	if body_count >= 14:
		return 1.0 / 26.0
	if body_count >= 8:
		return 1.0 / 22.0
	return 1.0 / 18.0


static func _runtime_substep_count(body_count: int, delta: float, config: SimulationPhysicsConfig) -> int:
	if config == null:
		return 1
	var scaled_delta: float = abs(delta * config.simulation_speed)
	if scaled_delta <= 0.0:
		return 1
	# 60 FPS is 1/60 s. A 1/120 target gives exactly two Verlet substeps;
	# the old 0.008 value unnecessarily rounded that same frame up to three.
	var target := max(config.target_substep_seconds, 1.0 / 120.0)
	if body_count >= 14:
		target = max(target, 0.018)
	elif body_count >= 8:
		target = max(target, 0.014)
	var wanted: int = int(ceil((scaled_delta / target) - 0.0001))
	var runtime_min := 1 if body_count >= 8 else min(config.min_substeps, 2)
	var runtime_max := config.max_substeps
	if body_count >= 18:
		runtime_max = min(runtime_max, 1)
	elif body_count >= 12:
		runtime_max = min(runtime_max, 2)
	elif body_count >= 8:
		runtime_max = min(runtime_max, 3)
	else:
		runtime_max = min(runtime_max, 6)
	return clamp(wanted, runtime_min, max(runtime_min, runtime_max))

static func prime_orbit_architecture(bodies: Array, config: SimulationPhysicsConfig, force_reseed: bool = false) -> void:
	if bodies.is_empty() or config == null: return

	# Expensive architecture work is only needed when structure/config changed.
	# Before this, every physics tick rebuilt binary links, anchor choices, host lanes,
	# orbit slots, and target radii. With normal min_substeps + collision checks, that
	# was enough to make 8 bodies stutter even with trails turned OFF.
	if not force_reseed and not _orbit_architecture_needs_refresh(bodies, config):
		return

	_clear_invalid_binary_links(bodies, config)
	_break_unstable_binary_pairs(bodies, config)
	_build_binary_links(bodies, config)
	_prepare_orbit_architecture(bodies, config, force_reseed)
	# Every structural change handled by this pass is now committed. Anchor bodies,
	# disabled-hierarchy bodies, and bodies without a host used to leave this flag
	# behind because their branches `continue` early. One leftover flag caused this
	# entire O(n²/n³) architecture pass to run again on every physics tick.
	for body in bodies:
		if _valid_body(body):
			body.data.metadata.erase(ARCHITECTURE_DIRTY_KEY)
			body.data.metadata[VERLET_ACCELERATION_VALID_KEY] = false
	_store_orbit_architecture_signature(bodies, config)

static func mark_orbit_architecture_dirty(bodies: Array, clear_binary_links: bool = true) -> void:
	for body in bodies:
		if not _valid_body(body): continue
		var d: SimulationPlanetData = body.data
		d.metadata[ARCHITECTURE_DIRTY_KEY] = true
		if clear_binary_links:
			d.metadata.erase(BINARY_PARTNER_KEY); d.metadata.erase(BINARY_CENTER_LOCKED_KEY)
		d.is_static_anchor = false; d.orbit_locked = false

static func _orbit_architecture_needs_refresh(bodies: Array, config: SimulationPhysicsConfig) -> bool:
	if config == null:
		return true
	var now := Time.get_ticks_msec()
	for body in bodies:
		if not _valid_body(body):
			continue
		if bool(body.data.metadata.get(ARCHITECTURE_DIRTY_KEY, false)):
			return true
		var forced_until := int(body.data.metadata.get(FORCE_ANCHOR_UNTIL_KEY, 0))
		if forced_until > 0 and forced_until <= now:
			return true
	if config._runtime_orbit_architecture_body_count != bodies.size():
		return true
	return config._runtime_orbit_architecture_config_hash != _orbit_architecture_config_hash(config)

static func _store_orbit_architecture_signature(bodies: Array, config: SimulationPhysicsConfig) -> void:
	if config == null:
		return
	config._runtime_orbit_architecture_body_count = bodies.size()
	config._runtime_orbit_architecture_config_hash = _orbit_architecture_config_hash(config)

static func _orbit_architecture_config_hash(config: SimulationPhysicsConfig) -> int:
	if config == null:
		return 0
	# Only settings that can change parent selection or orbit lanes belong here.
	# Body structural changes already set ARCHITECTURE_DIRTY_KEY at their source.
	# Fold values directly instead of allocating an Array every physics frame.
	var result := 17
	result = _fold_architecture_hash(result, config.stable_orbit_mode)
	result = _fold_architecture_hash(result, config.hierarchical_orbits_enabled)
	result = _fold_architecture_hash(result, config.binary_orbits_enabled)
	result = _fold_architecture_hash(result, config.same_type_binary_enabled)
	result = _fold_architecture_hash(result, config.center_largest_body)
	result = _fold_architecture_hash(result, config.lock_planets_to_largest_body)
	result = _fold_architecture_hash(result, snappedf(config.stable_orbit_radius_multiplier, 0.001))
	result = _fold_architecture_hash(result, snappedf(config.orbit_distance_padding, 0.1))
	result = _fold_architecture_hash(result, snappedf(config.orbit_spacing_multiplier, 0.001))
	result = _fold_architecture_hash(result, snappedf(config.moon_orbit_spacing_multiplier, 0.001))
	result = _fold_architecture_hash(result, snappedf(config.binary_orbit_spacing_multiplier, 0.001))
	result = _fold_architecture_hash(result, snappedf(config.binary_mass_similarity, 0.001))
	result = _fold_architecture_hash(result, snappedf(config.binary_max_distance_multiplier, 0.01))
	return result

static func _fold_architecture_hash(seed: int, value: Variant) -> int:
	return int((seed * 31 + (hash(value) & 0x7fffffff)) & 0x7fffffff)

static func compute_accelerations(bodies: Array, config: SimulationPhysicsConfig, id_lookup: Dictionary = {}, sparse_gravity_pairs: PackedInt32Array = PackedInt32Array(), moon_orbit_cache: Dictionary = {}, base_accels: Array[Vector2] = []) -> void:
	var body_count := bodies.size()
	for body in bodies:
		if _valid_body(body): body.data.clear_forces()
	var sparse_gravity := _use_sparse_mutual_gravity(body_count, config)
	if config.gravity_enabled:
		# Resolve pair geometry once, then apply each source's force in its own
		# direction. This preserves asymmetric masses/polarities while halving
		# distance, normalization, and softening work.
		if sparse_gravity:
			var pair_index := 0
			while pair_index + 1 < sparse_gravity_pairs.size():
				var i := sparse_gravity_pairs[pair_index]
				var j := sparse_gravity_pairs[pair_index + 1]
				pair_index += 2
				if i >= 0 and i < body_count and j >= 0 and j < body_count and _valid_body(bodies[i]) and _valid_body(bodies[j]):
					_apply_mutual_pair_gravity(bodies[i].data, bodies[j].data, true, config)
		else:
			for i in range(body_count):
				var a = bodies[i]
				if not _valid_body(a):
					continue
				var ad: SimulationPlanetData = a.data
				for j in range(i + 1, body_count):
					var b = bodies[j]
					if not _valid_body(b):
						continue
					_apply_mutual_pair_gravity(ad, b.data, false, config)
	# Save pure-gravity acceleration before stable-orbit constraints are applied.
	# A moon later receives only its parent's constraint acceleration—not the
	# parent's complete gravity again—so shared external gravity is not doubled.
	if base_accels.size() != body_count:
		base_accels.resize(body_count)
	for i in range(body_count):
		base_accels[i] = bodies[i].data.acceleration if _valid_body(bodies[i]) else Vector2.ZERO

	for i in range(body_count):
		var a = bodies[i]
		if not _valid_body(a): continue
		var ad: SimulationPlanetData = a.data
		if ad.is_dragging: continue
		if ad.is_static_anchor:
			if config.center_largest_body: _apply_center_anchor_force(ad, config)
			continue
		# Binary members are handled by _apply_binary_stable_lock_force() plus
		# _apply_binary_barycenter_anchor_force(). Do not also run the
		# normal one-body orbit lock, or the fresh pair inherits the old
		# anchor/satellite behaviour for the first frames.
		if config.stable_orbit_mode and not _is_binary_member(ad) and not _is_moon_like(ad):
			_apply_orbit_lock_force(ad, bodies, config, id_lookup, moon_orbit_cache)
	if config.stable_orbit_mode:
		_apply_binary_stable_lock_force(bodies, config, id_lookup)
	_apply_binary_barycenter_anchor_force(bodies, config, id_lookup)
	if config.stable_orbit_mode:
		for body in bodies:
			if not _valid_body(body):
				continue
			var moon: SimulationPlanetData = body.data
			if moon.is_dragging or moon.is_static_anchor or not _is_moon_like(moon) or _is_binary_member(moon):
				continue
			var cached: Dictionary = moon_orbit_cache.get(moon.instance_id, {})
			var host = cached.get("host", null) if not cached.is_empty() else _find_body_by_id(bodies, moon.orbit_parent_id, id_lookup)
			if _valid_body(host):
				var host_index := int(cached.get("host_index", -1))
				var host_base: Vector2 = base_accels[host_index] if host_index >= 0 and host_index < base_accels.size() else host.data.acceleration
				moon.add_acceleration(host.data.acceleration - host_base)
			_apply_orbit_lock_force(moon, bodies, config, id_lookup, moon_orbit_cache)

static func _apply_mutual_pair_gravity(a: SimulationPlanetData, b: SimulationPlanetData, sparse_gravity: bool, config: SimulationPhysicsConfig) -> void:
	if a == null or b == null:
		return
	var apply_to_a := not a.is_dragging and not a.is_static_anchor and (not sparse_gravity or _should_apply_crowded_pair_gravity(a, b))
	var apply_to_b := not b.is_dragging and not b.is_static_anchor and (not sparse_gravity or _should_apply_crowded_pair_gravity(b, a))
	if not apply_to_a and not apply_to_b:
		return
	var delta := b.position - a.position
	var dist_sq := delta.length_squared()
	if dist_sq <= 0.0001:
		return
	var softened := max(dist_sq, config.softening_radius * config.softening_radius)
	var unit := delta / sqrt(dist_sq)
	var black_white := _is_black_white_pair(a, b)
	if apply_to_a:
		var polarity_a := 1.0 if black_white else (-1.0 if str(b.metadata.get("gravity_polarity", "attractive")) == "repulsive" or b.body_kind == SimulationPlanetData.BodyKind.WHITE_HOLE else 1.0)
		var magnitude_a := min(config.gravitational_constant * max(b.mass, 0.0) * abs(b.gravitational_influence) / softened, config.max_acceleration)
		a.add_acceleration(unit * magnitude_a * polarity_a)
	if apply_to_b:
		var polarity_b := 1.0 if black_white else (-1.0 if str(a.metadata.get("gravity_polarity", "attractive")) == "repulsive" or a.body_kind == SimulationPlanetData.BodyKind.WHITE_HOLE else 1.0)
		var magnitude_b := min(config.gravitational_constant * max(a.mass, 0.0) * abs(a.gravitational_influence) / softened, config.max_acceleration)
		b.add_acceleration(-unit * magnitude_b * polarity_b)

static func _use_sparse_mutual_gravity(body_count: int, config: SimulationPhysicsConfig) -> bool:
	return config != null and config.stable_orbit_mode and body_count >= 8


static func _build_sparse_gravity_pairs(
	bodies: Array,
	config: SimulationPhysicsConfig
) -> PackedInt32Array:
	var pairs := PackedInt32Array()
	if not _use_sparse_mutual_gravity(bodies.size(), config):
		return pairs

	# The pair topology depends on the cached orbit hierarchy, so build it once
	# per rendered physics frame and reuse it for both Verlet force evaluations.
	for i in range(bodies.size()):
		if not _valid_body(bodies[i]):
			continue
		var body_a: SimulationPlanetData = bodies[i].data
		for j in range(i + 1, bodies.size()):
			if not _valid_body(bodies[j]):
				continue
			var body_b: SimulationPlanetData = bodies[j].data
			if (
				_should_apply_crowded_pair_gravity(body_a, body_b)
				or _should_apply_crowded_pair_gravity(body_b, body_a)
			):
				pairs.append(i)
				pairs.append(j)
	return pairs


static func _should_apply_crowded_pair_gravity(a: SimulationPlanetData, b: SimulationPlanetData) -> bool:
	if a == null or b == null:
		return false
	# In stable-orbit mode, host locks already create the readable system motion.
	# Full planet↔planet gravity is the expensive jitter source, especially when it
	# runs twice per substep. Keep only pairs that actually change gameplay feel.
	if b.is_static_anchor or a.orbit_parent_id == b.instance_id:
		return true
	if _is_binary_member(a) and str(a.metadata.get(BINARY_PARTNER_KEY, "")) == b.instance_id:
		return true
	if _is_black_white_pair(a, b):
		return true
	if b.body_kind == SimulationPlanetData.BodyKind.BLACK_HOLE or b.body_kind == SimulationPlanetData.BodyKind.WHITE_HOLE:
		return true
	if a.body_kind == SimulationPlanetData.BodyKind.BLACK_HOLE or a.body_kind == SimulationPlanetData.BodyKind.WHITE_HOLE:
		return true
	if not a.orbit_locked:
		return _host_power(b) >= _host_power(a) * 1.35
	return false


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

static func _step_verlet(bodies: Array, h: float, config: SimulationPhysicsConfig, id_lookup: Dictionary, sparse_gravity_pairs: PackedInt32Array, moon_orbit_cache: Dictionary, old_accels: Array[Vector2], base_accels: Array[Vector2]) -> void:
	# Array indexed by body position is much cheaper than a Dictionary keyed by
	# Node objects. This runs every substep, so avoiding hash lookups matters.
	var count := bodies.size()

	for i in range(count):
		var body = bodies[i]
		if not _valid_body(body):
			old_accels[i] = Vector2.ZERO
			continue
		var d: SimulationPlanetData = body.data
		old_accels[i] = d.acceleration
		if d.is_dragging: _continue_dragged_body(body, config); continue
		d.previous_position = d.position
		d.position += d.velocity * h + 0.5 * d.acceleration * h * h

	compute_accelerations(bodies, config, id_lookup, sparse_gravity_pairs, moon_orbit_cache, base_accels)
	_mark_verlet_acceleration_valid(bodies)

	var damping_factor := 1.0
	if config.damping_per_second > 0.0:
		damping_factor = pow(max(0.0, 1.0 - config.damping_per_second), abs(h))
	for i in range(count):
		var body = bodies[i]
		if not _valid_body(body): continue
		var d: SimulationPlanetData = body.data
		if d.is_dragging: _continue_dragged_body(body, config); continue
		d.velocity += 0.5 * (old_accels[i] + d.acceleration) * h
		_limit_velocity_for_orbit(d, config)
		if config.damping_per_second > 0.0: d.velocity *= damping_factor
		d.age_seconds += abs(h)


static func _mark_verlet_acceleration_valid(bodies: Array) -> void:
	for body in bodies:
		if _valid_body(body):
			body.data.metadata[VERLET_ACCELERATION_VALID_KEY] = not body.data.is_dragging


static func _record_frame_trails(bodies: Array, config: SimulationPhysicsConfig) -> void:
	if config == null:
		return
	var body_count := bodies.size()
	var point_budget := _runtime_trail_point_budget(body_count, config) if config.trails_enabled else -1
	var sample_distance := _runtime_trail_sample_distance(body_count, config)
	for body in bodies:
		if _valid_body(body):
			body.data.record_trail_point(point_budget, sample_distance)


static func _sync_bodies_from_data(bodies: Array) -> void:
	for body in bodies:
		if _valid_body(body):
			body.sync_from_data()



static func _runtime_trail_point_budget(body_count: int, config: SimulationPhysicsConfig) -> int:
	if config == null:
		return 0
	var requested := int(config.max_trail_points)
	if body_count >= 14:
		return min(requested, 100)
	if body_count >= 10:
		return min(requested, 150)
	if body_count >= 7:
		return min(requested, 220)
	return min(requested, 360)


static func _runtime_trail_sample_distance(body_count: int, config: SimulationPhysicsConfig) -> float:
	if config == null:
		return 12.0
	var distance := float(config.trail_sample_distance)
	# Keep the actual stored trail dense enough to describe tight curves. The renderer
	# now owns visual decimation, so over-aggressive physics-side sampling only makes
	# corners look like jittery straight segments.
	if body_count >= 14:
		return max(distance, 20.0)
	if body_count >= 10:
		return max(distance, 16.0)
	if body_count >= 7:
		return max(distance, 12.0)
	return max(distance, 8.0)


static func _config_float(config: SimulationPhysicsConfig, property_name: String, fallback: float) -> float:
	if config == null:
		return fallback
	if config.has_method("has_config_property") and not config.has_config_property(property_name):
		return fallback
	var value: Variant = config.get(property_name)
	if value == null:
		return fallback
	return float(value)

static func _stable_radius_multiplier(config: SimulationPhysicsConfig) -> float:
	if config == null:
		return 1.0
	if config.has_method("has_config_property") and config.has_config_property("stable_orbit_radius_multiplier"):
		return clamp(float(config.stable_orbit_radius_multiplier), 0.1, 1.0)
	return 1.0

static func _prepare_orbit_architecture(bodies: Array, config: SimulationPhysicsConfig, force_reseed: bool = false) -> void:
	var anchor = _preferred_anchor_body(bodies)
	_protect_anchor_transition_family(bodies, anchor)
	var host_slots := {}
	var host_lanes := {}
	for body in bodies:
		if not _valid_body(body): continue
		var d: SimulationPlanetData = body.data
		d.is_static_anchor = false
		if _is_moon_like(d):
			var current_host = _find_body_by_id(bodies, str(d.orbit_parent_id))
			if _valid_body(current_host):
				_clear_moon_host_search_protection(d)
			else:
				d.orbit_parent_id = ""
				_enable_moon_host_search_protection(d)
		if _is_binary_member(d):
			# Mutual binaries own their parent/radius. Do not let the hierarchical
			# host picker overwrite the pair into a normal one-body orbit.
			continue
		if config.center_largest_body and body == anchor:
			d.is_static_anchor = true; d.orbit_parent_id = ""; d.orbit_locked = false; continue
		if not config.hierarchical_orbits_enabled: continue
		var host = _choose_orbit_host(body, bodies, anchor, config)
		if host == null or not _valid_body(host):
			if _is_moon_like(d):
				d.orbit_parent_id = ""
				_enable_moon_host_search_protection(d)
			continue
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
		if _is_moon_like(d):
			_clear_moon_host_search_protection(d)
		d.metadata["stable_orbit_radius_multiplier_used"] = current_radius_multiplier
		d.metadata["stable_orbit_min_radius"] = float(radius_info.get("min_radius", radius))
		d.metadata["stable_orbit_max_radius"] = float(radius_info.get("max_radius", radius))
		var soft_recover := bool(d.metadata.get("stable_orbit_soft_recover", false))
		var needs_seed := (force_reseed and not same_host) or previous_host != hd.instance_id or previous_radius <= 0.0 or bool(d.metadata.get(ARCHITECTURE_DIRTY_KEY, false))
		if needs_seed and config.stable_orbit_mode and not soft_recover and not _is_binary_member(d) and not _is_white_hole(hd):
			_place_new_or_dirty_body_on_orbit_if_needed(d, hd, radius, config, slot)
			_seed_orbit_velocity(d, hd, radius, config)
		if needs_seed: d.metadata.erase(ARCHITECTURE_DIRTY_KEY)
		if hd.body_kind == SimulationPlanetData.BodyKind.BLACK_HOLE:
			d.orbit_locked = false
			d.metadata["black_hole_unstable_orbit"] = true
		else:
			d.orbit_locked = config.stable_orbit_mode and not _is_white_hole(hd) and (_is_moon_like(d) or config.lock_planets_to_largest_body)

static func _build_binary_links(bodies: Array, config: SimulationPhysicsConfig) -> void:
	if config == null or not config.binary_orbits_enabled or not config.same_type_binary_enabled:
		return

	# Star systems get one real stellar binary: the two strongest stars pair up,
	# while every extra star remains a normal orbiting body. Planets/moons are not
	# attached to the binary envelope; they still choose one concrete star as host.
	if _try_build_primary_star_binary(bodies, config):
		return

	# Binary rule for non-stellar bodies:
	# - if a main anchor exists, only the anchor itself may form a new binary;
	#   orbiting planets/moons do not randomly steal each other into binaries.
	# - if the old anchor was removed, the largest remaining body becomes the
	#   anchor candidate and can form a binary with a compatible remaining body.
	var anchor = _current_or_candidate_anchor_body(bodies, config)
	if _valid_body(anchor) and config.center_largest_body:
		_try_build_anchor_binary(anchor, bodies, config)
		return

	var used := {}
	for body in bodies:
		if not _valid_body(body):
			continue
		var a: SimulationPlanetData = body.data
		if used.has(a.instance_id) or _is_moon_like(a):
			continue
		for candidate in bodies:
			if candidate == body or not _valid_body(candidate):
				continue
			var b: SimulationPlanetData = candidate.data
			if used.has(b.instance_id) or _is_moon_like(b):
				continue
			if _try_make_binary_pair(body, candidate, config, false):
				used[a.instance_id] = true
				used[b.instance_id] = true
				break

static func _current_or_candidate_anchor_body(bodies: Array, config: SimulationPhysicsConfig):
	if config == null or not config.center_largest_body:
		return null
	for body in bodies:
		if _valid_body(body) and body.data.is_static_anchor:
			return body
	return _preferred_anchor_body(bodies)

static func _try_build_primary_star_binary(bodies: Array, config: SimulationPhysicsConfig) -> bool:
	if config == null or not config.binary_orbits_enabled or not config.same_type_binary_enabled:
		return false
	var best_a = null
	var best_b = null
	var best_a_score := -INF
	var best_b_score := -INF
	for body in bodies:
		if not _valid_body(body):
			continue
		var d: SimulationPlanetData = body.data
		if d.body_kind != SimulationPlanetData.BodyKind.STAR:
			continue
		if _is_binary_member(d):
			var partner = _find_body_by_id(bodies, str(d.metadata.get(BINARY_PARTNER_KEY, "")))
			if _valid_body(partner) and partner.data.body_kind == SimulationPlanetData.BodyKind.STAR:
				return true
		var score := _star_binary_candidate_score(d)
		if score > best_a_score:
			best_b = best_a
			best_b_score = best_a_score
			best_a = body
			best_a_score = score
		elif score > best_b_score:
			best_b = body
			best_b_score = score
	if not _valid_body(best_a) or not _valid_body(best_b):
		return false
	return _force_make_primary_star_binary_pair(best_a, best_b, config)

static func _force_make_primary_star_binary_pair(body, candidate, config: SimulationPhysicsConfig) -> bool:
	if not _valid_body(body) or not _valid_body(candidate) or config == null:
		return false
	var a: SimulationPlanetData = body.data
	var b: SimulationPlanetData = candidate.data
	if a.body_kind != SimulationPlanetData.BodyKind.STAR or b.body_kind != SimulationPlanetData.BodyKind.STAR:
		return false
	a.metadata[BINARY_PARTNER_KEY] = b.instance_id
	b.metadata[BINARY_PARTNER_KEY] = a.instance_id
	a.metadata.erase(ARCHITECTURE_DIRTY_KEY)
	b.metadata.erase(ARCHITECTURE_DIRTY_KEY)
	_prepare_soft_mutual_binary_orbit_local(body, candidate, config, a.orbit_clockwise, _preferred_binary_separation(a, b, config), true)
	return true

static func _star_binary_candidate_score(d: SimulationPlanetData) -> float:
	if d == null:
		return -INF
	return max(d.mass, 0.001) * 100000.0 + max(d.radius_world, 1.0) * 100.0 + max(abs(d.gravitational_influence), 0.001)

static func _try_build_anchor_binary(anchor, bodies: Array, config: SimulationPhysicsConfig) -> bool:
	if not _valid_body(anchor):
		return false
	var a: SimulationPlanetData = anchor.data
	if _is_moon_like(a):
		return false
	if _is_binary_member(a):
		return true
	var best = null
	var best_score := -INF
	for candidate in bodies:
		if candidate == anchor or not _valid_body(candidate):
			continue
		var b: SimulationPlanetData = candidate.data
		if _is_moon_like(b) or _is_binary_member(b):
			continue
		# Anchor binaries should form when the new/remaining body is compatible, even
		# if the add spawn is not already sitting at the exact binary separation.
		if not _are_good_binary_partners(a, b, config, true):
			continue
		var score := _binary_partner_score(a, b)
		if score > best_score:
			best_score = score
			best = candidate
	if _valid_body(best):
		return _try_make_binary_pair(anchor, best, config, true)
	return false

static func _binary_partner_score(a: SimulationPlanetData, b: SimulationPlanetData) -> float:
	if a == null or b == null:
		return -INF
	if _is_black_white_pair(a, b):
		return INF
	var smaller: float = min(max(a.mass, 0.001), max(b.mass, 0.001))
	var larger: float = max(max(a.mass, 0.001), max(b.mass, 0.001))
	var mass_similarity := smaller / larger
	var closeness = 1.0 / max(a.position.distance_to(b.position), MIN_HOST_DISTANCE)
	return mass_similarity * 1000.0 + closeness

static func _try_make_binary_pair(body, candidate, config: SimulationPhysicsConfig, ignore_distance: bool = false) -> bool:
	if not _valid_body(body) or not _valid_body(candidate):
		return false
	var a: SimulationPlanetData = body.data
	var b: SimulationPlanetData = candidate.data
	if _is_black_white_pair(a, b):
		a.metadata[BINARY_PARTNER_KEY] = b.instance_id
		b.metadata[BINARY_PARTNER_KEY] = a.instance_id
		a.metadata["death_dance_pair"] = b.instance_id
		b.metadata["death_dance_pair"] = a.instance_id
		a.metadata["death_dance_ignore_binary_reseed"] = true
		b.metadata["death_dance_ignore_binary_reseed"] = true
		a.metadata.erase(ARCHITECTURE_DIRTY_KEY)
		b.metadata.erase(ARCHITECTURE_DIRTY_KEY)
		var already_dancing := bool(a.metadata.get("death_dance_initialized", false)) or bool(b.metadata.get("death_dance_initialized", false))
		if not already_dancing:
			_prepare_soft_mutual_binary_orbit_local(body, candidate, config, a.orbit_clockwise, -1.0, false)
		return true
	if not _are_good_binary_partners(a, b, config, ignore_distance):
		return false
	a.metadata[BINARY_PARTNER_KEY] = b.instance_id
	b.metadata[BINARY_PARTNER_KEY] = a.instance_id
	a.metadata.erase(ARCHITECTURE_DIRTY_KEY)
	b.metadata.erase(ARCHITECTURE_DIRTY_KEY)
	_prepare_soft_mutual_binary_orbit_local(body, candidate, config, a.orbit_clockwise, _preferred_binary_separation(a, b, config), ignore_distance)
	return true

static func _are_good_binary_partners(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig, ignore_distance: bool = false) -> bool:
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
	if _is_star_like(a) and _is_star_like(b):
		# Visual similarity is only for the achievement. Binary physics should still
		# allow two stars to pair, otherwise big star systems never form binaries.
		# Non-star binaries keep the stricter same-family/mass checks above.
		pass
	if ignore_distance:
		return true
	return a.position.distance_to(b.position) <= _minimum_binary_separation(a, b, config) * config.binary_max_distance_multiplier

static func _minimum_binary_separation(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if a == null or b == null or config == null:
		return 120.0
	var ar: float = max(a.radius_world, a.get_collision_radius(config))
	var br: float = max(b.radius_world, b.get_collision_radius(config))
	var padding: float = max(36.0, config.orbit_distance_padding * 0.58)
	if _is_star_like(a) and _is_star_like(b):
		padding = max(64.0, config.orbit_distance_padding * 1.05)
	elif _is_planet_like(a) and _is_planet_like(b):
		padding = max(42.0, config.orbit_distance_padding * 0.72)
	return max(ar + br + padding, MIN_HOST_DISTANCE * 0.62)

static func _stable_binary_max_separation(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if a == null or b == null or config == null:
		return 220.0
	var min_sep := _minimum_binary_separation(a, b, config)
	var mass_term := pow(max(a.mass + b.mass, 0.01), 0.22) * 46.0
	var radius_term := sqrt(max(a.radius_world + b.radius_world, 8.0)) * 18.0
	var role_multiplier := 1.0
	if _is_star_like(a) and _is_star_like(b):
		role_multiplier = 1.72
	elif _is_planet_like(a) and _is_planet_like(b):
		role_multiplier = 1.08
	return max(min_sep, min_sep + (mass_term + radius_term + config.min_visible_orbit_radius * 0.42) * role_multiplier)

static func _preferred_binary_separation(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if a == null or b == null or config == null:
		return 160.0
	var min_sep := _minimum_binary_separation(a, b, config)
	var max_sep := _stable_binary_max_separation(a, b, config)
	var slider := _stable_radius_multiplier(config)
	var t := clamp((slider - 0.1) / 0.9, 0.0, 1.0)
	return lerp(min_sep, max_sep, t)

static func _prepare_soft_mutual_binary_orbit_local(a, b, config: SimulationPhysicsConfig, clockwise: bool = true, separation_override: float = -1.0, lock_center_to_screen: bool = false) -> bool:
	if not _valid_body(a) or not _valid_body(b) or config == null:
		return false
	var ad: SimulationPlanetData = a.data
	var bd: SimulationPlanetData = b.data
	var death_pair := _is_black_white_pair(ad, bd)
	var total_mass := max(ad.mass + bd.mass, 0.001)
	var offset: Vector2 = bd.position - ad.position
	var separation := separation_override if separation_override > 0.0 else offset.length()
	if death_pair:
		separation = max(separation, 1.0)
	else:
		separation = _preferred_binary_separation(ad, bd, config)
	if offset.length_squared() < 0.001:
		offset = _stable_direction(ad.instance_id + bd.instance_id) * separation
	var direction := offset.normalized()
	if direction.length_squared() < 0.001:
		direction = _stable_direction(ad.instance_id + bd.instance_id)
	var center: Vector2 = (ad.position * ad.mass + bd.position * bd.mass) / total_mass
	var ra: float = separation * (bd.mass / total_mass)
	var rb: float = separation * (ad.mass / total_mass)
	var tangent := Vector2(-direction.y, direction.x)
	if clockwise:
		tangent *= -1.0
	var orbit_multiplier := config.get_orbit_speed_multiplier() if config.has_method("get_orbit_speed_multiplier") else clamp(config.revolution_speed_multiplier, 0.05, 32.0)
	var omega = sqrt(config.gravitational_constant * total_mass / pow(max(separation, 1.0), 3.0)) * orbit_multiplier
	var center_velocity = (ad.velocity * ad.mass + bd.velocity * bd.mass) / total_mass
	if lock_center_to_screen and not death_pair:
		# Original binary barycenter behaviour assumed the pair center did not inherit
		# the old spawn/orbit drift. With smooth center-spawn enabled, both bodies can
		# carry the same outward velocity into the moment the binary is created, which
		# makes the theoretical barycenter run away before the anchor spring can catch
		# it. Keep the internal spin, but reset the shared barycenter velocity so the
		# invisible binary center behaves like a freshly anchored body again.
		center_velocity = Vector2.ZERO
	var target_va = center_velocity - tangent * omega * ra
	var target_vb = center_velocity + tangent * omega * rb

	# Black-hole / white-hole death dance still needs its special immediate setup.
	# Normal binaries, however, must not rewrite positions: the stable binary lock
	# below pulls them onto the mutual lane smoothly over the next frames.
	if death_pair:
		ad.position = center - direction * ra
		bd.position = center + direction * rb
		ad.previous_position = ad.position
		bd.previous_position = bd.position
		ad.velocity = target_va
		bd.velocity = target_vb
	else:
		ad.velocity = ad.velocity.lerp(target_va, 0.08)
		bd.velocity = bd.velocity.lerp(target_vb, 0.08)
		var transition_until := Time.get_ticks_msec() + 1800
		ad.metadata["binary_soft_transition_until_ms"] = transition_until
		bd.metadata["binary_soft_transition_until_ms"] = transition_until
		# Remove stale one-body soft orbit data from the moment this becomes a binary.
		ad.metadata.erase("stable_orbit_soft_recover")
		bd.metadata.erase("stable_orbit_soft_recover")
		ad.metadata.erase(SOFT_ORBIT_RADIAL_DIR_KEY)
		bd.metadata.erase(SOFT_ORBIT_RADIAL_DIR_KEY)
	ad.orbit_parent_id = bd.instance_id
	bd.orbit_parent_id = ad.instance_id
	ad.orbit_radius = separation
	bd.orbit_radius = separation
	ad.orbit_clockwise = clockwise
	bd.orbit_clockwise = not clockwise
	if death_pair:
		ad.orbit_locked = false
		bd.orbit_locked = false
		ad.metadata["death_dance_pair"] = bd.instance_id
		bd.metadata["death_dance_pair"] = ad.instance_id
		ad.metadata["black_hole_unstable_orbit"] = true
		bd.metadata["black_hole_unstable_orbit"] = true
	else:
		ad.orbit_locked = config.stable_orbit_mode
		bd.orbit_locked = config.stable_orbit_mode
	ad.metadata[BINARY_PARTNER_KEY] = bd.instance_id
	bd.metadata[BINARY_PARTNER_KEY] = ad.instance_id
	ad.metadata[BINARY_CENTER_LOCKED_KEY] = false if death_pair else lock_center_to_screen
	bd.metadata[BINARY_CENTER_LOCKED_KEY] = false if death_pair else lock_center_to_screen
	ad.metadata.erase(ARCHITECTURE_DIRTY_KEY)
	bd.metadata.erase(ARCHITECTURE_DIRTY_KEY)
	a.sync_from_data()
	b.sync_from_data()
	return true

static func _prepare_soft_circular_orbit_local(body, parent, config: SimulationPhysicsConfig, clockwise: bool = true, radius_override: float = -1.0, blend_velocity: bool = true) -> bool:
	if not _valid_body(body) or not _valid_body(parent) or config == null:
		return false
	var d: SimulationPlanetData = body.data
	var h: SimulationPlanetData = parent.data
	var offset: Vector2 = d.position - h.position
	var radius: float = radius_override if radius_override > 0.0 else offset.length()
	radius = max(radius, _minimum_orbit_radius_for_multiplier(d, h, config))
	if offset.length_squared() < 0.001:
		offset = _stable_direction(d.instance_id) * radius
	var radial_dir := offset.normalized()
	if radial_dir.length_squared() < 0.001:
		radial_dir = _stable_direction(d.instance_id)
	var tangent := Vector2(-radial_dir.y, radial_dir.x)
	if clockwise:
		tangent *= -1.0
	var target_velocity := h.velocity + tangent * _stable_orbit_speed(d, h, radius, config)
	d.orbit_parent_id = h.instance_id
	d.orbit_radius = radius
	d.orbit_clockwise = clockwise
	d.orbit_eccentricity = 0.0
	d.orbit_locked = config.stable_orbit_mode
	d.metadata["stable_orbit_soft_recover"] = true
	d.metadata[SOFT_ORBIT_RADIAL_DIR_KEY] = radial_dir
	d.metadata[COLLISION_PROTECTION_KEY] = Time.get_ticks_msec() + 4200
	if _is_moon_like(d):
		_clear_moon_host_search_protection(d)
	d.metadata.erase(ARCHITECTURE_DIRTY_KEY)
	d.velocity = d.velocity.lerp(target_velocity, 0.18) if blend_velocity else target_velocity
	body.sync_from_data()
	return true

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

static func _break_unstable_binary_pairs(bodies: Array, config: SimulationPhysicsConfig) -> void:
	if config == null:
		return
	var seen := {}
	for body in bodies:
		if not _valid_body(body):
			continue
		var a: SimulationPlanetData = body.data
		if seen.has(a.instance_id):
			continue
		var partner_id := str(a.metadata.get(BINARY_PARTNER_KEY, ""))
		if partner_id.is_empty():
			continue
		var partner = _find_body_by_id(bodies, partner_id)
		if not _valid_body(partner):
			_clear_binary_link_for_body(a)
			continue
		var b: SimulationPlanetData = partner.data
		seen[a.instance_id] = true
		seen[b.instance_id] = true
		if _is_black_white_pair(a, b):
			continue
		# When a collision/evolution makes one member too dominant, it is no longer
		# a proper binary planet/star pair. Break it and promote the bigger member.
		if not _are_good_binary_partners(a, b, config, true) or _binary_member_outgrew_standard(a, b, config):
			_break_binary_pair_and_promote_larger(body, partner, config)

static func _binary_member_outgrew_standard(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> bool:
	if a == null or b == null or config == null:
		return false
	var smaller_mass := min(max(a.mass, 0.001), max(b.mass, 0.001))
	var larger_mass := max(max(a.mass, 0.001), max(b.mass, 0.001))
	var required := clamp(config.binary_mass_similarity * (0.42 if _is_star_like(a) and _is_star_like(b) else 1.0), 0.08, 1.0)
	if smaller_mass / larger_mass < required:
		return true
	var smaller_radius := min(max(a.radius_world, 1.0), max(b.radius_world, 1.0))
	var larger_radius := max(max(a.radius_world, 1.0), max(b.radius_world, 1.0))
	# Radius catches the exact visual problem: one planet becomes visibly too big
	# for the old binary standard even if mass has not caught up yet.
	return smaller_radius / larger_radius < max(required * 0.72, 0.24)

static func _break_binary_pair_and_promote_larger(body_a, body_b, config: SimulationPhysicsConfig) -> void:
	if not _valid_body(body_a) or not _valid_body(body_b):
		return
	var a: SimulationPlanetData = body_a.data
	var b: SimulationPlanetData = body_b.data
	var promote = body_a
	var demote = body_b
	if _anchor_score(b) > _anchor_score(a) or b.radius_world > a.radius_world * 1.08:
		promote = body_b
		demote = body_a
	# Binary partners intentionally store opposite orbit_clockwise flags. After the
	# pair breaks, force the demoted body onto the promoted anchor's normal system
	# direction; otherwise one planet can inherit the binary's opposite spin.
	var demote_clockwise := bool(promote.data.orbit_clockwise)
	_clear_binary_link_for_body(a)
	_clear_binary_link_for_body(b)
	promote.data.is_static_anchor = true
	promote.data.orbit_parent_id = ""
	promote.data.orbit_locked = false
	promote.data.metadata[FORCE_ANCHOR_UNTIL_KEY] = Time.get_ticks_msec() + 6500
	demote.data.orbit_clockwise = demote_clockwise
	demote.data.metadata[ARCHITECTURE_DIRTY_KEY] = true
	if config != null and config.stable_orbit_mode:
		_prepare_soft_circular_orbit_local(demote, promote, config, demote_clockwise, -1.0, true)

static func _orbit_clockwise_from_relative_motion(child: SimulationPlanetData, parent: SimulationPlanetData, fallback: bool = true) -> bool:
	if child == null or parent == null:
		return fallback
	var radial: Vector2 = child.position - parent.position
	var relative_velocity: Vector2 = child.velocity - parent.velocity
	if radial.length_squared() < 0.001 or relative_velocity.length_squared() < 0.001:
		return fallback
	var spin := radial.cross(relative_velocity)
	if abs(spin) < 0.001:
		return fallback
	# In this project, clockwise=true uses the negative perpendicular tangent,
	# which gives a negative 2D cross product around the parent.
	return spin < 0.0

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
				if _valid_body(anchor) and body != anchor:
					# When an anchor swap dissolves a binary, both former members must
					# join the new anchor's system direction. Keeping the binary partner's
					# opposite flag is what made one planet orbit backwards.
					d.orbit_clockwise = bool(anchor.data.orbit_clockwise)
					d.orbit_parent_id = anchor.data.instance_id
					d.metadata["stable_orbit_soft_recover"] = true
					d.metadata[ARCHITECTURE_DIRTY_KEY] = true
				d.metadata.erase(BINARY_PARTNER_KEY)
				d.metadata.erase(BINARY_CENTER_LOCKED_KEY)
				d.metadata.erase("binary_soft_transition_until_ms")

	for body in bodies:
		if _valid_body(body):
			body.data.metadata[SYSTEM_ANCHOR_ID_KEY] = new_anchor_id
static func _clear_binary_link_for_body(d: SimulationPlanetData) -> void:
	if d == null: return
	d.metadata.erase(BINARY_PARTNER_KEY); d.metadata.erase(BINARY_CENTER_LOCKED_KEY); d.metadata.erase("binary_soft_transition_until_ms"); _clear_temporary_collision_protection(d); d.metadata[ARCHITECTURE_DIRTY_KEY] = true; d.orbit_locked = false; d.is_static_anchor = false

static func _clear_temporary_collision_protection(d: SimulationPlanetData) -> void:
	if d == null:
		return
	d.metadata.erase(COLLISION_PROTECTION_KEY)
	d.metadata.erase("anchor_transition_protected")

static func _enable_moon_host_search_protection(d: SimulationPlanetData) -> void:
	if d == null or not _is_moon_like(d):
		return
	d.metadata["collision_protected_until_stable_orbit"] = true
	d.metadata[COLLISION_PROTECTION_KEY] = max(
		int(d.metadata.get(COLLISION_PROTECTION_KEY, 0)),
		Time.get_ticks_msec() + 4200
	)

static func _clear_moon_host_search_protection(d: SimulationPlanetData) -> void:
	if d == null:
		return
	d.metadata.erase("collision_protected_until_stable_orbit")
	var anchor_transition := bool(d.metadata.get("anchor_transition_protected", false))
	var binary_transition := int(d.metadata.get("binary_soft_transition_until_ms", 0)) > Time.get_ticks_msec()
	if not anchor_transition and not binary_transition:
		d.metadata.erase(COLLISION_PROTECTION_KEY)

static func _is_binary_member(d: SimulationPlanetData) -> bool: return d != null and d.metadata.has(BINARY_PARTNER_KEY) and str(d.metadata.get(BINARY_PARTNER_KEY, "")) != ""
static func _anchor_score(d: SimulationPlanetData) -> float:
	if d == null: return 0.0
	var role_bonus := 1.0
	if _is_star_like(d): role_bonus = 10.0
	elif _is_planet_like(d): role_bonus = 2.0
	elif _is_moon_like(d): role_bonus = 0.35
	return d.mass * abs(d.gravitational_influence) * role_bonus
static func _preferred_anchor_body(bodies: Array):
	var now := Time.get_ticks_msec()
	var forced = null
	var forced_score := -INF
	for body in bodies:
		if not _valid_body(body):
			continue
		var until := int(body.data.metadata.get(FORCE_ANCHOR_UNTIL_KEY, 0))
		if until > now and _anchor_score(body.data) > forced_score:
			forced_score = _anchor_score(body.data)
			forced = body
		elif until > 0 and until <= now:
			body.data.metadata.erase(FORCE_ANCHOR_UNTIL_KEY)
	if _valid_body(forced):
		return forced
	return _largest_anchor_body(bodies)

static func _largest_anchor_body(bodies: Array):
	var best = null; var score := -INF
	for body in bodies:
		if _valid_body(body) and _anchor_score(body.data) > score: score = _anchor_score(body.data); best = body
	return best
static func _choose_orbit_host(body, bodies: Array, anchor, config: SimulationPhysicsConfig):
	if not _valid_body(body): return anchor
	var d: SimulationPlanetData = body.data
	if _is_moon_like(d):
		return _choose_satellite_host(body, bodies, anchor)
	if _is_planet_like(d):
		return _choose_planet_host(body, bodies, anchor)
	if _is_star_like(d): return anchor if anchor != null and anchor != body else null
	return anchor

static func _choose_satellite_host(body, bodies: Array, anchor):
	if not _valid_body(body):
		return anchor
	var d: SimulationPlanetData = body.data
	# Sticky host rule: once a moon has a real planet host, keep it until
	# that host disappears. A star/black-hole anchor is only a fallback lane.
	var existing = _find_body_by_id(bodies, str(d.orbit_parent_id))
	if _valid_body(existing) and _is_planet_like(existing.data) and not existing.data.is_static_anchor:
		return existing

	# Strong preference: satellites go to non-anchor planets first.
	var non_anchor_planet = _best_satellite_planet_host(body, bodies, true)
	if non_anchor_planet != null:
		return non_anchor_planet

	# Planet-anchor system: every moon uses the planet anchor, not other moons.
	if _valid_body(anchor) and _is_planet_like(anchor.data) and anchor != body:
		return anchor

	# Keep an existing moon host once chosen, unless the system has a planet host above.
	if _valid_body(existing) and _is_moon_like(existing.data):
		return existing

	if _valid_body(anchor) and _is_star_like(anchor.data):
		var stronger_moon = _best_stronger_satellite_host(body, bodies)
		if stronger_moon != null:
			return stronger_moon

	var any_planet = _best_satellite_planet_host(body, bodies, false)
	if any_planet != null:
		return any_planet

	return anchor if anchor != body else null

static func _choose_planet_host(body, bodies: Array, anchor):
	if not _valid_body(body):
		return anchor
	var d: SimulationPlanetData = body.data
	if _valid_body(anchor) and anchor != body:
		var ad: SimulationPlanetData = anchor.data
		if _is_star_like(ad):
			return anchor
		if _is_planet_like(ad) and _host_power(ad) >= _host_power(d) * 0.92:
			# Planet anchor system: weaker planets behave like moons of the anchor.
			return anchor
	var star = _best_star_host(body, bodies)
	return star if star != null else (anchor if anchor != body else null)

static func _best_star_host(body, bodies: Array): return _best_host_by_role(body, bodies, [SimulationPlanetData.BodyKind.STAR, SimulationPlanetData.BodyKind.BLACK_HOLE, SimulationPlanetData.BodyKind.WHITE_HOLE, SimulationPlanetData.BodyKind.GALAXY], false)

static func _best_satellite_planet_host(body, bodies: Array, exclude_static_anchor: bool = false):
	if not _valid_body(body):
		return null
	var moon: SimulationPlanetData = body.data
	var best = null
	var best_score := INF
	for candidate in bodies:
		if candidate == body or not _valid_body(candidate):
			continue
		var c: SimulationPlanetData = candidate.data
		if exclude_static_anchor and c.is_static_anchor:
			continue
		if not [SimulationPlanetData.BodyKind.PLANET, SimulationPlanetData.BodyKind.RINGED_PLANET].has(c.body_kind):
			continue
		# Satellites should orbit planets. Do not reject a valid planet just because
		# the generated moon has weird radius/mass values; gameplay hierarchy wins here.
		var distance := max(moon.position.distance_to(c.position), MIN_HOST_DISTANCE)
		var host_power := max(_host_power(c), 0.001)
		var score: float = distance / host_power
		if score < best_score:
			best_score = score
			best = candidate
	return best

static func _best_stronger_satellite_host(body, bodies: Array):
	if not _valid_body(body):
		return null
	var moon: SimulationPlanetData = body.data
	var best = null
	var best_score := INF
	for candidate in bodies:
		if candidate == body or not _valid_body(candidate):
			continue
		var c: SimulationPlanetData = candidate.data
		if not _is_moon_like(c):
			continue
		# A larger/heavier moon can act as a mini-planet when the real anchor is a star.
		if c.radius_world <= moon.radius_world * 1.04 and _host_power(c) <= _host_power(moon) * 1.16:
			continue
		var distance := max(moon.position.distance_to(c.position), MIN_HOST_DISTANCE)
		var score: float = distance / max(_host_power(c), 0.001)
		if score < best_score:
			best_score = score
			best = candidate
	return best

static func _host_power(d: SimulationPlanetData) -> float:
	if d == null:
		return 0.0
	return max(d.mass, 0.001) * max(abs(d.gravitational_influence), 0.001) * max(d.radius_world, 1.0)
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

static func _apply_binary_stable_lock_force(bodies: Array, config: SimulationPhysicsConfig, id_lookup: Dictionary = {}) -> void:
	if config == null:
		return
	var seen := {}
	var now := Time.get_ticks_msec()
	var slider := _stable_radius_multiplier(config)
	var compact_boost := lerp(3.4, 1.0, slider)
	var velocity_correction_strength := _config_float(config, "velocity_correction_strength", 1.0)
	var base_spring = config.orbit_lock_strength * 0.92 * compact_boost
	var base_damping := 0.72 + velocity_correction_strength * 0.22
	var orbit_multiplier := config.get_orbit_speed_multiplier() if config.has_method("get_orbit_speed_multiplier") else clamp(config.revolution_speed_multiplier, 0.05, 32.0)
	var base_vel_mix := clamp(velocity_correction_strength * 0.018, 0.0, 0.085)
	for body in bodies:
		if not _valid_body(body):
			continue
		var a: SimulationPlanetData = body.data
		if seen.has(a.instance_id):
			continue
		var partner_id := str(a.metadata.get(BINARY_PARTNER_KEY, ""))
		if partner_id.is_empty():
			continue
		var partner = _find_body_by_id(bodies, partner_id, id_lookup)
		if not _valid_body(partner):
			continue
		var b: SimulationPlanetData = partner.data
		seen[a.instance_id] = true
		seen[b.instance_id] = true
		if _is_black_white_pair(a, b):
			continue
		if a.is_dragging or b.is_dragging:
			_apply_held_binary_partner_lock(a, b, config)
			continue
		var radial := b.position - a.position
		var dist := max(radial.length(), 1.0)
		var radial_dir = radial / dist
		var target_sep := _preferred_binary_separation(a, b, config)
		var total_mass := max(a.mass + b.mass, 0.001)
		var ra = target_sep * (b.mass / total_mass)
		var rb = target_sep * (a.mass / total_mass)
		var center = (a.position * a.mass + b.position * b.mass) / total_mass
		var center_velocity = (a.velocity * a.mass + b.velocity * b.mass) / total_mass
		var separation_error = dist - target_sep
		var spring = base_spring
		var damping := base_damping
		var transition_until := max(int(a.metadata.get("binary_soft_transition_until_ms", 0)), int(b.metadata.get("binary_soft_transition_until_ms", 0)))
		var soft_transition = transition_until > now
		if soft_transition:
			# New binaries should slide into their mutual orbit instead of instantly
			# snapping onto the final barycentric lane. Keep the spring strong enough
			# to converge, but do not hard-correct position or velocity.
			spring *= 0.48
			damping *= 0.62
		elif transition_until > 0:
			a.metadata.erase("binary_soft_transition_until_ms")
			b.metadata.erase("binary_soft_transition_until_ms")
			a.metadata.erase("stable_orbit_soft_recover")
			b.metadata.erase("stable_orbit_soft_recover")
			a.metadata.erase(SOFT_ORBIT_RADIAL_DIR_KEY)
			b.metadata.erase(SOFT_ORBIT_RADIAL_DIR_KEY)
			_clear_temporary_collision_protection(a)
			_clear_temporary_collision_protection(b)
		if not soft_transition and dist >= max(target_sep * 0.65, 48.0):
			a.metadata.erase("stable_orbit_soft_recover")
			b.metadata.erase("stable_orbit_soft_recover")
			a.metadata.erase(SOFT_ORBIT_RADIAL_DIR_KEY)
			b.metadata.erase(SOFT_ORBIT_RADIAL_DIR_KEY)
			_clear_temporary_collision_protection(a)
			_clear_temporary_collision_protection(b)
		var relative_velocity := b.velocity - a.velocity
		var radial_speed := relative_velocity.dot(radial_dir)
		var correction = radial_dir * (separation_error * spring + radial_speed * damping)
		var correction_limit := config.max_acceleration * (0.38 if soft_transition else 0.65)
		correction = correction.limit_length(correction_limit)
		a.add_acceleration(correction * (b.mass / total_mass))
		b.add_acceleration(-correction * (a.mass / total_mass))
		var tangent := Vector2(-radial_dir.y, radial_dir.x)
		if a.orbit_clockwise:
			tangent *= -1.0
		var omega = sqrt(config.gravitational_constant * total_mass / pow(max(target_sep, 1.0), 3.0)) * orbit_multiplier
		var target_va = center_velocity - tangent * omega * ra
		var target_vb = center_velocity + tangent * omega * rb
		var vel_mix := base_vel_mix
		if soft_transition:
			vel_mix *= 0.34
		a.velocity = a.velocity.lerp(target_va, vel_mix)
		b.velocity = b.velocity.lerp(target_vb, vel_mix)
		a.orbit_radius = target_sep
		b.orbit_radius = target_sep
		a.metadata["stable_binary_radius_multiplier_used"] = slider
		b.metadata["stable_binary_radius_multiplier_used"] = slider

static func _apply_held_binary_partner_lock(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> void:
	if a == null or b == null or config == null:
		return
	if a.is_dragging and b.is_dragging:
		return
	var held := a if a.is_dragging else b
	var free := b if a.is_dragging else a
	if held == null or free == null or free.is_dragging:
		return

	var radial := free.position - held.position
	var dist := max(radial.length(), 1.0)
	var radial_dir = radial / dist
	if radial_dir.length_squared() < 0.001:
		radial_dir = _stable_direction("%s:%s:held" % [held.instance_id, free.instance_id])
	var target_sep := _preferred_binary_separation(held, free, config)
	var tangent := Vector2(-radial_dir.y, radial_dir.x)
	if held.orbit_clockwise:
		tangent *= -1.0

	var total_mass := max(held.mass + free.mass, 0.001)
	var orbit_multiplier := config.get_orbit_speed_multiplier() if config.has_method("get_orbit_speed_multiplier") else clamp(config.revolution_speed_multiplier, 0.05, 32.0)
	var omega = sqrt(config.gravitational_constant * total_mass / pow(max(target_sep, 1.0), 3.0)) * orbit_multiplier
	var target_speed = omega * target_sep
	var target_velocity = held.velocity + tangent * target_speed
	var relative_velocity := free.velocity - held.velocity
	var radial_speed := relative_velocity.dot(radial_dir)
	var separation_error = dist - target_sep
	var spring := max(config.orbit_lock_strength * 1.35, 0.45)
	var damping := 1.15 + config.orbit_lock_strength * 0.85
	var correction = radial_dir * (-separation_error * spring - radial_speed * damping)
	free.add_acceleration(correction.limit_length(config.max_acceleration * 0.72))
	free.velocity = free.velocity.lerp(target_velocity, clamp(config.orbit_lock_strength * 0.075, 0.025, 0.12))
	free.orbit_radius = target_sep
	held.orbit_radius = target_sep

static func _apply_binary_barycenter_anchor_force(bodies: Array, config: SimulationPhysicsConfig, id_lookup: Dictionary = {}) -> void:
	if config == null or not config.center_largest_body:
		return
	var pair := _best_anchor_binary_pair(bodies, id_lookup)
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
	var locked_center := bool(a.data.metadata.get(BINARY_CENTER_LOCKED_KEY, false)) or bool(b.data.metadata.get(BINARY_CENTER_LOCKED_KEY, false))
	var to_anchor := ANCHOR_TARGET - barycenter

	# Treat the binary barycenter exactly like a normal anchored body. The pair gets
	# the same shared acceleration that one static anchor body would receive, so the
	# center of mass elastically oscillates into the anchor instead of teleporting
	# or being velocity-forced into a snappy lerp. Both members receive identical
	# acceleration, preserving their internal binary spin while the invisible
	# barycenter behaves like the anchored body.
	var spring: float = 0.28 + strength * 0.82
	var damping: float = 1.05 + strength * 1.65
	var center_accel: Vector2 = (to_anchor * spring - bary_velocity * damping) * strength
	center_accel = center_accel.limit_length(260.0 + strength * 820.0)
	a.data.add_acceleration(center_accel)
	b.data.add_acceleration(center_accel)

static func _best_anchor_binary_pair(bodies: Array, id_lookup: Dictionary = {}) -> Array:
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
		var partner = _find_body_by_id(bodies, partner_id, id_lookup)
		if not _valid_body(partner):
			continue
		seen[d.instance_id] = true
		seen[partner.data.instance_id] = true
		var pair_score := _anchor_score(d) + _anchor_score(partner.data)
		if bool(d.metadata.get(BINARY_CENTER_LOCKED_KEY, false)) or bool(partner.data.metadata.get(BINARY_CENTER_LOCKED_KEY, false)):
			# This restores the original anchor-binary intent: once a pair is created as
			# the system center, its barycenter is the anchor candidate. Do not let an
			# extra star/planet steal the anchor comparison for a frame while the pair is
			# still sliding into its mutual orbit.
			pair_score += 1000000000.0
		if pair_score > best_pair_score:
			best_pair_score = pair_score
			best_pair = [body, partner]
	if best_pair_score <= 0.0:
		return []
	if best_pair_score < best_single_score:
		return []
	return best_pair
static func _apply_orbit_lock_force(d: SimulationPlanetData, bodies: Array, config: SimulationPhysicsConfig, id_lookup: Dictionary = {}, moon_orbit_cache: Dictionary = {}) -> void:
	if not d.orbit_locked: return
	var cached_moon: Dictionary = moon_orbit_cache.get(d.instance_id, {}) if _is_moon_like(d) else {}
	var host = cached_moon.get("host", null) if not cached_moon.is_empty() else _find_body_by_id(bodies, d.orbit_parent_id, id_lookup)
	if not _valid_body(host): return
	var h: SimulationPlanetData = host.data
	if _is_white_hole(h):
		d.orbit_locked = false
		return

	var radial := d.position - h.position
	var raw_dist := radial.length()
	var dist := max(raw_dist, 1.0)
	if h.body_kind == SimulationPlanetData.BodyKind.BLACK_HOLE:
		d.orbit_locked = false
		d.metadata["black_hole_unstable_orbit"] = true
		return

	var current_radius_multiplier := _stable_radius_multiplier(config)
	var slot := int(d.metadata.get("stable_orbit_slot", 0))
	if not cached_moon.is_empty():
		d.orbit_radius = float(cached_moon.get("target_radius", d.orbit_radius))
	elif not _is_binary_member(d):
		if d.metadata.has("stable_orbit_min_radius") and d.metadata.has("stable_orbit_max_radius"):
			d.orbit_radius = _orbit_radius_from_min_max_local(float(d.metadata.get("stable_orbit_min_radius", d.orbit_radius)), float(d.metadata.get("stable_orbit_max_radius", d.orbit_radius)), config)
		else:
			d.orbit_radius = _target_orbit_radius(d, h, config, slot)
		d.metadata["stable_orbit_radius_multiplier_used"] = current_radius_multiplier
	var target_radius := max(d.orbit_radius, 1.0)
	var radial_dir: Vector2 = radial / dist
	if raw_dist < 2.0 or radial_dir.length_squared() < 0.001:
		var stored_dir: Variant = d.metadata.get(SOFT_ORBIT_RADIAL_DIR_KEY, Vector2.ZERO)
		if stored_dir is Vector2 and stored_dir.length_squared() > 0.001:
			radial_dir = stored_dir.normalized()
		else:
			radial_dir = _stable_direction("%s:%s" % [h.instance_id, d.instance_id])
		d.metadata[SOFT_ORBIT_RADIAL_DIR_KEY] = radial_dir
	elif bool(d.metadata.get("stable_orbit_soft_recover", false)):
		d.metadata[SOFT_ORBIT_RADIAL_DIR_KEY] = radial_dir
	var tangent := Vector2(-radial_dir.y, radial_dir.x) * (-1.0 if d.orbit_clockwise else 1.0)
	var target_point: Vector2 = h.position + radial_dir * target_radius
	var to_orbit_path: Vector2 = target_point - d.position
	var relative := d.velocity - h.velocity
	var radial_speed: float = relative.dot(radial_dir)
	var tangential_speed: float = relative.dot(tangent)
	var target_speed := float(cached_moon.get("target_speed", 0.0)) if not cached_moon.is_empty() else _stable_orbit_speed(d, h, target_radius, config)
	var delta_radius: float = dist - target_radius
	var distance_ratio: float = clamp(abs(delta_radius) / max(target_radius, 1.0), 0.0, 4.0)
	var soft_recover := bool(d.metadata.get("stable_orbit_soft_recover", false))
	var protect_until_stable := bool(d.metadata.get("collision_protected_until_stable_orbit", false))
	if soft_recover and not protect_until_stable and raw_dist >= max(target_radius * 0.72, 48.0):
		# Once the body has actually left the shared spawn point and reached the
		# general orbit lane, collisions must become real again. Keep the visual
		# soft-recover movement, but remove the collision shield.
		_clear_temporary_collision_protection(d)

	# The radius slider is literal. If the target radius gets scaled down to 0.1,
	# the lock must actually pull the body inward instead of letting it float on
	# the old wide orbit for ages. This still updates only the target orbit; it does
	# not teleport/rebuild the position.
	var slider := _stable_radius_multiplier(config)
	var compact_boost := lerp(5.0, 1.0, slider)
	var normal_strength: float = config.orbit_lock_strength * lerp(0.34, 1.10, clamp(distance_ratio, 0.0, 1.0)) * compact_boost
	var normal_damping: float = config.orbit_lock_strength * lerp(0.36, 0.82, clamp(distance_ratio, 0.0, 1.0)) * compact_boost
	var revolving_strength: float = config.orbit_lock_strength * (1.24 if _is_moon_like(d) else 0.92)
	var acceleration_limit: float = (420.0 + config.orbit_lock_strength * 2400.0) * compact_boost

	if soft_recover:
		var spawn_push: bool = raw_dist < max(target_radius * 0.34, 120.0)
		if spawn_push:
			normal_strength *= 1.18
			normal_damping *= 0.72
			revolving_strength *= 0.92
			acceleration_limit *= 1.10
		else:
			normal_strength *= 0.46
			normal_damping *= 0.62
			revolving_strength *= 0.42
			acceleration_limit *= 0.48

	var normal_vector: Vector2 = to_orbit_path * normal_strength - radial_dir * radial_speed * normal_damping
	var revolving_vector: Vector2 = tangent * (target_speed - tangential_speed) * revolving_strength
	var correction: Vector2 = normal_vector + revolving_vector
	d.add_acceleration(correction.limit_length(acceleration_limit))
	_apply_minimum_tangential_support(d, h, tangent, tangential_speed, target_speed, config, acceleration_limit)

	if soft_recover and abs(delta_radius) <= max(target_radius * 0.045, 18.0) and abs(radial_speed) <= 42.0:
		d.metadata.erase("stable_orbit_soft_recover")
		d.metadata.erase(SOFT_ORBIT_RADIAL_DIR_KEY)
		d.metadata.erase("collision_protected_until_stable_orbit")
		_clear_temporary_collision_protection(d)
static func _apply_minimum_tangential_support(d: SimulationPlanetData, host: SimulationPlanetData, tangent: Vector2, current_tangential_speed: float, target_speed: float, config: SimulationPhysicsConfig, acceleration_limit: float) -> void:
	if d == null or host == null or config == null:
		return
	if d.is_dragging or target_speed <= 0.0 or tangent.length_squared() <= 0.001:
		return
	var minimum_speed := target_speed * 0.92
	if _is_moon_like(d):
		# A hierarchical moon must keep revolving in the accelerating reference
		# frame of its planet; falling below circular speed makes it appear pinned.
		minimum_speed = target_speed
	if bool(d.metadata.get("stable_orbit_soft_recover", false)):
		minimum_speed = target_speed * 1.02
	if current_tangential_speed >= minimum_speed:
		return
	var missing := minimum_speed - current_tangential_speed
	var support_strength := max(config.orbit_lock_strength * 1.85, 1.0)
	if _is_moon_like(d):
		support_strength = max(config.orbit_lock_strength * 2.35, 1.35)
	d.add_acceleration((tangent.normalized() * missing * support_strength).limit_length(max(acceleration_limit * 0.72, 360.0)))

static func _seed_orbit_velocity(d: SimulationPlanetData, host: SimulationPlanetData, radius: float, config: SimulationPhysicsConfig) -> void:
	var radial := d.position - host.position
	if radial.length_squared() < 0.001: radial = _stable_direction(d.instance_id) * radius
	var tangent := Vector2(-radial.normalized().y, radial.normalized().x)
	if d.orbit_clockwise: tangent = -tangent
	d.velocity = host.velocity + tangent * (_stable_orbit_speed(d, host, radius, config) * 1.12)

static func _place_new_or_dirty_body_on_orbit_if_needed(d: SimulationPlanetData, host: SimulationPlanetData, radius: float, config: SimulationPhysicsConfig, slot: int = 0) -> void:
	if d == null or host == null or config == null:
		return
	var offset := d.position - host.position
	var dir := offset.normalized() if offset.length_squared() > 0.001 else _stable_direction("%s:%s:%d" % [host.instance_id, d.instance_id, slot])
	# No teleporting here. New planets and moons may spawn at the screen center,
	# even on top of the anchor. Store the desired escape direction and let the
	# orbit-lock force pull them onto the reserved lane smoothly.
	d.metadata[SOFT_ORBIT_RADIAL_DIR_KEY] = dir
	d.metadata["stable_orbit_soft_recover"] = true
	d.metadata[COLLISION_PROTECTION_KEY] = Time.get_ticks_msec() + 4200
	if _is_moon_like(d):
		_clear_moon_host_search_protection(d)
static func _stable_orbit_speed(d: SimulationPlanetData, host: SimulationPlanetData, radius: float, config: SimulationPhysicsConfig) -> float:
	var speed_multiplier := config.get_orbit_speed_multiplier() if config.has_method("get_orbit_speed_multiplier") else clamp(config.revolution_speed_multiplier, 0.05, 32.0)
	# Game-feel scaling requested: smaller stable-radius setting also lowers the
	# tangential target velocity, instead of letting the physics formula speed it up.
	var radius_slider := _stable_radius_multiplier(config)
	var support := lerp(0.92, 1.0, radius_slider)
	return min(sqrt(max(config.gravitational_constant * max(host.mass * abs(host.gravitational_influence), 0.001) / max(radius, 1.0), 0.0)) * speed_multiplier * support, _max_orbit_speed(d))
static func _limit_velocity_for_orbit(d: SimulationPlanetData, config: SimulationPhysicsConfig) -> void:
	if config.stable_orbit_mode and d.velocity.length() > _max_orbit_speed(d): d.velocity = d.velocity.normalized() * _max_orbit_speed(d)
static func _max_orbit_speed(d: SimulationPlanetData) -> float: return MAX_ORBIT_SPEED_FALLBACK if d == null else max(d.max_orbit_speed * 4.0, 80.0)
static func _minimum_orbit_radius_for_multiplier(d: SimulationPlanetData, host: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if d == null or host == null or config == null:
		return 120.0
	var min_radius := _stable_orbit_min_radius_local(d, host, config)
	var max_radius := _stable_orbit_max_radius_local(d, host, config)
	return _orbit_radius_from_min_max_local(min_radius, max_radius, config)

static func _tight_orbit_radius_local(body: SimulationPlanetData, parent: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if body == null or parent == null or config == null:
		return 72.0
	var body_clearance: float = max(body.radius_world, body.get_collision_radius(config))
	var parent_clearance: float = max(parent.radius_world, parent.get_collision_radius(config))
	if parent.metadata.has(BINARY_PARTNER_KEY) and parent.orbit_radius > 0.0 and not _is_moon_like(body) and not _is_star_like(parent):
		parent_clearance = max(parent_clearance, parent.orbit_radius + parent.get_collision_radius(config))
	var padding: float = max(22.0, config.orbit_distance_padding * 0.18)
	if _is_moon_like(body):
		padding = max(18.0, config.orbit_distance_padding * 0.13 * _orbit_spacing_multiplier_local(config))
	elif _is_star_like(body) and _is_star_like(parent):
		padding = max(32.0, config.orbit_distance_padding * 0.22)
	return max(12.0, parent_clearance + body_clearance + padding)

static func _normal_orbit_radius_local(body: SimulationPlanetData, parent: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if body == null or parent == null or config == null:
		return 120.0
	var clearance := parent.radius_world + body.radius_world + config.orbit_distance_padding * 1.32
	if _is_moon_like(body):
		clearance = parent.radius_world + body.radius_world + config.orbit_distance_padding * 0.86 * _orbit_spacing_multiplier_local(config)
	elif _is_star_like(body) and _is_star_like(parent):
		clearance = parent.radius_world + body.radius_world + config.orbit_distance_padding * 1.64
	return max(config.min_visible_orbit_radius, clearance)

static func _orbit_radius_from_min_max_local(min_radius: float, max_radius: float, config: SimulationPhysicsConfig) -> float:
	var mn: float = max(min_radius, 1.0)
	var mx: float = max(max_radius, mn)
	var slider := _stable_radius_multiplier(config)
	var t := clamp((slider - 0.1) / 0.9, 0.0, 1.0)
	return lerp(mn, mx, t)

static func _stable_orbit_min_radius_local(body: SimulationPlanetData, parent: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if body == null or parent == null or config == null:
		return 120.0
	return _tight_orbit_radius_local(body, parent, config)

static func _stable_orbit_max_radius_local(body: SimulationPlanetData, parent: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if body == null or parent == null or config == null:
		return 120.0
	var min_radius := _stable_orbit_min_radius_local(body, parent, config)
	var normal_radius := max(min_radius, _normal_orbit_radius_local(body, parent, config))
	var radius_bonus := sqrt(max(body.radius_world, 8.0)) * 16.0
	var mass_bonus := pow(max(body.mass, 0.01), 0.30) * 30.0
	var parent_bonus := pow(max(parent.mass * abs(parent.gravitational_influence), 0.01), 0.16) * 18.0
	var kind_multiplier := 1.0
	if _is_moon_like(body):
		kind_multiplier = 0.48 * max(_orbit_spacing_multiplier_local(config), 0.1)
	elif _is_star_like(body) and _is_star_like(parent):
		kind_multiplier = 1.62
	elif _is_planet_like(body):
		kind_multiplier = 1.06
	return max(min_radius, normal_radius) + (radius_bonus + mass_bonus + parent_bonus) * kind_multiplier

static func _compact_orbit_lane_gap_local(body: SimulationPlanetData, existing: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if body == null or existing == null or config == null:
		return 120.0
	var body_clearance := max(body.radius_world, body.get_collision_radius(config))
	var existing_clearance := max(existing.radius_world, existing.get_collision_radius(config))
	var padding := _config_float(config, "orbit_distance_padding", 86.0)
	var spacing := max(_orbit_spacing_multiplier_local(config), 0.1)
	var gap = body_clearance + existing_clearance + max(56.0, padding * 0.82)
	# Same-host planets were sharing lanes that were mathematically safe but visually
	# way too tight. Planet lanes need a much larger floor than moon lanes.
	if _is_planet_like(body) and _is_planet_like(existing):
		gap = max(gap, body_clearance + existing_clearance + max(140.0, padding * 1.95))
	elif _is_moon_like(body) or _is_moon_like(existing):
		gap = max(gap, body_clearance + existing_clearance + max(72.0, padding * 0.92) * spacing)
	elif _is_star_like(body) or _is_star_like(existing):
		gap = max(gap, body_clearance + existing_clearance + max(180.0, padding * 2.25))
	return max(96.0, gap)

static func _normal_orbit_lane_gap_local(body: SimulationPlanetData, existing: SimulationPlanetData, config: SimulationPhysicsConfig) -> float:
	if body == null or existing == null or config == null:
		return 160.0
	var compact := _compact_orbit_lane_gap_local(body, existing, config)
	var min_visible := _config_float(config, "min_visible_orbit_radius", 120.0)
	var padding := _config_float(config, "orbit_distance_padding", 86.0)
	var spacing := max(_orbit_spacing_multiplier_local(config), 0.1)
	var wide = compact + max(max(min_visible * 1.08, padding * 1.32), 118.0)
	if _is_planet_like(body) and _is_planet_like(existing):
		wide = compact + max(max(min_visible * 1.42, padding * 2.10), 190.0)
	elif _is_moon_like(body) or _is_moon_like(existing):
		wide = compact + max(max(min_visible * 0.82, padding * 0.95), 86.0) * spacing
	elif _is_star_like(body) or _is_star_like(existing):
		wide = compact + max(max(min_visible * 1.65, padding * 2.60), 240.0)
	return max(compact, wide)

static func _orbit_spacing_multiplier_local(config: SimulationPhysicsConfig) -> float:
	if config == null:
		return 1.0
	if config.has_method("has_config_property") and config.has_config_property("orbit_spacing_multiplier"):
		return clamp(float(config.orbit_spacing_multiplier), 0.1, 1.0)
	return 1.0

static func _target_orbit_radius_info(d: SimulationPlanetData, host: SimulationPlanetData, config: SimulationPhysicsConfig, inner_lanes: Array = []) -> Dictionary:
	var min_radius := _stable_orbit_min_radius_local(d, host, config)
	var max_radius := _stable_orbit_max_radius_local(d, host, config)
	for lane in inner_lanes:
		if not (lane is Dictionary):
			continue
		var existing = lane.get("body", null)
		var lane_min := float(lane.get("min_radius", 0.0))
		var lane_max := float(lane.get("max_radius", 0.0))
		var compact_gap := _compact_orbit_lane_gap_local(d, host, config)
		var normal_gap := _normal_orbit_lane_gap_local(d, host, config)
		if existing is SimulationPlanetData:
			compact_gap = _compact_orbit_lane_gap_local(d, existing, config)
			normal_gap = _normal_orbit_lane_gap_local(d, existing, config)
		normal_gap = max(compact_gap, normal_gap * _orbit_spacing_multiplier_local(config))
		min_radius = max(min_radius, lane_min + compact_gap)
		max_radius = max(max_radius, lane_max + normal_gap)
	var radius := _orbit_radius_from_min_max_local(min_radius, max_radius, config)
	return {"body": d, "min_radius": min_radius, "max_radius": max_radius, "radius": radius}

static func _target_orbit_radius(d: SimulationPlanetData, host: SimulationPlanetData, config: SimulationPhysicsConfig, orbit_slot: int = 0) -> float:
	if d == null or host == null or config == null:
		return 120.0
	var min_radius := _stable_orbit_min_radius_local(d, host, config)
	var max_radius := _stable_orbit_max_radius_local(d, host, config)
	var radius := _orbit_radius_from_min_max_local(min_radius, max_radius, config)
	if orbit_slot > 0:
		radius += float(orbit_slot) * _normal_orbit_lane_gap_local(d, d, config)
	return radius

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
static func _build_body_id_lookup(bodies: Array) -> Dictionary:
	var lookup := {}
	for body in bodies:
		if _valid_body(body):
			lookup[body.data.instance_id] = body
	return lookup

static func _build_moon_orbit_frame_cache(bodies: Array, config: SimulationPhysicsConfig, id_lookup: Dictionary) -> Dictionary:
	var cache := {}
	if config == null or not config.stable_orbit_mode:
		return cache
	var radius_multiplier := _stable_radius_multiplier(config)
	for body in bodies:
		if not _valid_body(body):
			continue
		var moon: SimulationPlanetData = body.data
		if not _is_moon_like(moon) or not moon.orbit_locked or moon.orbit_parent_id.is_empty():
			continue
		var host = _find_body_by_id(bodies, moon.orbit_parent_id, id_lookup)
		if not _valid_body(host) or _is_white_hole(host.data):
			continue
		var target_radius := moon.orbit_radius
		if moon.metadata.has("stable_orbit_min_radius") and moon.metadata.has("stable_orbit_max_radius"):
			target_radius = _orbit_radius_from_min_max_local(
				float(moon.metadata.get("stable_orbit_min_radius", target_radius)),
				float(moon.metadata.get("stable_orbit_max_radius", target_radius)),
				config
			)
		else:
			target_radius = _target_orbit_radius(moon, host.data, config, int(moon.metadata.get("stable_orbit_slot", 0)))
		target_radius = max(target_radius, 1.0)
		moon.orbit_radius = target_radius
		moon.metadata["stable_orbit_radius_multiplier_used"] = radius_multiplier
		cache[moon.instance_id] = {
			"host": host,
			"host_index": bodies.find(host),
			"target_radius": target_radius,
			"target_speed": _stable_orbit_speed(moon, host.data, target_radius, config),
		}
	return cache

static func _find_body_by_id(bodies: Array, id: String, id_lookup: Dictionary = {}):
	if id.is_empty(): return null
	if not id_lookup.is_empty():
		return id_lookup.get(id, null)
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

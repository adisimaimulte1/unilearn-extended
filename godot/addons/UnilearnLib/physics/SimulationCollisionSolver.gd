extends RefCounted
class_name SimulationCollisionSolver

const COLLISION_STAGE_RADIUS_BOUNDS := {
	0: Vector2(30.0, 90.0),
	1: Vector2(92.0, 180.0),
	2: Vector2(185.0, 300.0),
	3: Vector2(300.0, 340.0),
	4: Vector2(345.0, 420.0),
	5: Vector2(430.0, 555.0),
	6: Vector2(560.0, 820.0),
	7: Vector2(830.0, 1100.0),
	8: Vector2(1110.0, 1400.0),
	9: Vector2(1410.0, 1650.0),
	10: Vector2(1660.0, 1900.0),
	# Match the normal generated black-hole visual band from SimulationScaleUtils.
	# A collapse is still much smaller than the red-supergiant stage before it.
	11: Vector2(360.0, 560.0),
}

const BLACK_HOLE_COLLAPSE_RADIUS := 360.0


static func solve(bodies: Array, config: SimulationPhysicsConfig) -> Array:
	var removed: Array = []
	if bodies.size() < 2 or config == null or not config.collisions_enabled: return removed
	for i in range(bodies.size()):
		var a = bodies[i]
		if not _valid(a) or removed.has(a): continue
		for j in range(i + 1, bodies.size()):
			var b = bodies[j]
			if not _valid(b) or removed.has(b): continue
			if not _are_colliding(a.data, b.data, config, bodies): continue
			var mode := _resolve_mode(a.data, b.data, config)
			if mode == SimulationPlanetData.CollisionMode.OFF: continue
			elif mode == SimulationPlanetData.CollisionMode.BOUNCE: _bounce(a.data, b.data, config)
			else:
				var dead = _merge(a, b, config, bodies)
				if dead != null: removed.append(dead)
	return removed
static func _are_colliding(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig, bodies: Array = []) -> bool:
	if _is_death_dance_pair(a, b) and not _death_dance_collision_ready(a, b):
		return false
	if _is_temporarily_collision_protected(a, bodies) or _is_temporarily_collision_protected(b, bodies):
		return false
	var r := a.get_collision_radius(config) + b.get_collision_radius(config)
	return a.position.distance_squared_to(b.position) <= r * r

static func _is_temporarily_collision_protected(d: SimulationPlanetData, bodies: Array = []) -> bool:
	if d == null:
		return false
	var until_ms := int(d.metadata.get("collision_protected_until_ms", 0))
	if until_ms <= 0:
		return false
	var still_emerging := bool(d.metadata.get("stable_orbit_soft_recover", false))
	var protected_until_stable := bool(d.metadata.get("collision_protected_until_stable_orbit", false))
	var anchor_transition := bool(d.metadata.get("anchor_transition_protected", false))
	var binary_transition_until := int(d.metadata.get("binary_soft_transition_until_ms", 0))
	var binary_transition := binary_transition_until > Time.get_ticks_msec()

	# Moon protection is a host-search shield only. The instant its parent ID
	# resolves to a live body, every collision—including with the system anchor—
	# becomes real again, even while the moon is still settling onto its lane.
	if protected_until_stable and _has_valid_orbit_host(d, bodies):
		d.metadata.erase("collision_protected_until_stable_orbit")
		protected_until_stable = false
		if not anchor_transition and not binary_transition:
			d.metadata.erase("collision_protected_until_ms")
			until_ms = 0
	elif protected_until_stable:
		return true
	if not still_emerging and not anchor_transition and not binary_transition:
		_clear_temporary_collision_protection(d)
		return false

	if Time.get_ticks_msec() <= until_ms:
		return true
	_clear_temporary_collision_protection(d)
	return false

static func _has_valid_orbit_host(d: SimulationPlanetData, bodies: Array) -> bool:
	if d == null:
		return false
	var host_id := str(d.orbit_parent_id).strip_edges()
	if host_id.is_empty() or host_id == str(d.instance_id):
		return false
	for body in bodies:
		if _valid(body) and str(body.data.instance_id) == host_id:
			return true
	return false

static func _clear_temporary_collision_protection(d: SimulationPlanetData) -> void:
	if d == null:
		return
	d.metadata.erase("collision_protected_until_ms")
	d.metadata.erase("anchor_transition_protected")

static func _is_death_dance_pair(a: SimulationPlanetData, b: SimulationPlanetData) -> bool:
	if a == null or b == null:
		return false
	var a_pair := str(a.metadata.get("death_dance_pair", ""))
	var b_pair := str(b.metadata.get("death_dance_pair", ""))
	return a_pair == str(b.instance_id) and b_pair == str(a.instance_id)

static func _death_dance_collision_ready(a: SimulationPlanetData, b: SimulationPlanetData) -> bool:
	return bool(a.metadata.get("death_dance_collision_ready", false)) and bool(b.metadata.get("death_dance_collision_ready", false))
static func _resolve_mode(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> int:
	if a.collision_mode == SimulationPlanetData.CollisionMode.OFF or b.collision_mode == SimulationPlanetData.CollisionMode.OFF: return SimulationPlanetData.CollisionMode.OFF
	if a.collision_mode == SimulationPlanetData.CollisionMode.BOUNCE or b.collision_mode == SimulationPlanetData.CollisionMode.BOUNCE: return SimulationPlanetData.CollisionMode.BOUNCE
	return config.default_collision_mode
static func _bounce(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> void:
	var normal := (b.position - a.position).normalized()
	if normal.length_squared() <= 0.001: normal = Vector2.RIGHT
	var relative_velocity := a.velocity - b.velocity
	var vel_along_normal := relative_velocity.dot(normal)
	if vel_along_normal > 0.0: return
	var inv_mass_a: float = 0.0 if a.is_static_anchor else 1.0 / max(a.mass, 0.001)
	var inv_mass_b: float = 0.0 if b.is_static_anchor else 1.0 / max(b.mass, 0.001)
	var impulse: Vector2 = normal * (-(1.0 + config.bounce_restitution) * vel_along_normal / max(inv_mass_a + inv_mass_b, 0.001))
	if not a.is_static_anchor: a.velocity += impulse * inv_mass_a
	if not b.is_static_anchor: b.velocity -= impulse * inv_mass_b
static func _merge(a, b, config: SimulationPhysicsConfig, bodies: Array = []):
	var universe_end := (_is_black_hole(a.data) and _is_white_hole(b.data)) or (_is_black_hole(b.data) and _is_white_hole(a.data))
	var black_hole_absorption := (_is_black_hole(a.data) or _is_black_hole(b.data)) and not universe_end
	var black_hole_merger := _is_black_hole(a.data) and _is_black_hole(b.data)
	var survivor = a if a.data.mass >= b.data.mass else b
	# Ordinary merges keep the held node so dragging remains continuous. A black-hole
	# merger is stricter: physical ownership always belongs to the greater mass.
	if not black_hole_merger:
		if a.data.is_dragging and not b.data.is_dragging:
			survivor = a
		elif b.data.is_dragging and not a.data.is_dragging:
			survivor = b
	if black_hole_absorption and not black_hole_merger and not survivor.data.is_dragging:
		survivor = a if _is_black_hole(a.data) else b
	var absorbed = b if survivor == a else a
	var preserved_black_hole_source: PlanetData = null
	var preserved_black_hole_radius: float = 0.0
	var preserve_black_hole_hero := black_hole_absorption and _is_black_hole(survivor.data)
	var all_moons_cleared_payload := _last_attached_moon_collision_payload(a.data, b.data, bodies)
	if preserve_black_hole_hero:
		# Identity always belongs to the actual survivor (the mass winner for a
		# black-hole merger). Only the radius floor may come from the larger visual.
		if survivor.data.source_planet_data != null:
			preserved_black_hole_source = survivor.data.source_planet_data.duplicate(true) as PlanetData
		preserved_black_hole_radius = max(float(a.data.radius_world), float(b.data.radius_world)) if black_hole_merger else survivor.data.radius_world
	var survivor_achievement_snapshot: Dictionary = _achievement_snapshot(survivor.data, bodies)
	var absorbed_achievement_snapshot: Dictionary = _achievement_snapshot(absorbed.data, bodies)
	if not all_moons_cleared_payload.is_empty():
		survivor_achievement_snapshot["all_moons_cleared"] = all_moons_cleared_payload
		absorbed_achievement_snapshot["all_moons_cleared"] = all_moons_cleared_payload
		survivor.data.metadata["achievement_all_moons_cleared"] = all_moons_cleared_payload
		absorbed.data.metadata["achievement_all_moons_cleared"] = all_moons_cleared_payload
	survivor.data.metadata["achievement_collision_a"] = survivor_achievement_snapshot
	survivor.data.metadata["achievement_collision_b"] = absorbed_achievement_snapshot
	survivor.data.metadata["achievement_collision_survivor"] = survivor_achievement_snapshot
	absorbed.data.metadata["achievement_collision_a"] = survivor_achievement_snapshot
	absorbed.data.metadata["achievement_collision_b"] = absorbed_achievement_snapshot
	absorbed.data.metadata["achievement_collision_survivor"] = survivor_achievement_snapshot
	if universe_end:
		a.data.metadata["universe_end_collision"] = true
		b.data.metadata["universe_end_collision"] = true
	var total_mass := max(survivor.data.mass + absorbed.data.mass, 0.001)
	if not survivor.data.is_dragging:
		survivor.data.position = (survivor.data.position * survivor.data.mass + absorbed.data.position * absorbed.data.mass) / total_mass
		survivor.data.velocity = ((survivor.data.velocity * survivor.data.mass + absorbed.data.velocity * absorbed.data.mass) / total_mass) * max(0.0, 1.0 - config.merge_velocity_loss)
	else:
		# Keep the dragged body pinned to the finger; only the visual/data evolves.
		survivor.data.previous_position = survivor.data.position
		survivor.data.velocity = Vector2.ZERO
	var old_radius: float = survivor.data.radius_world
	survivor.data.mass = total_mass
	var absorbed_radius: float = max(absorbed.data.radius_world, 1.0)
	var area_growth_radius: float = sqrt(survivor.data.radius_world * survivor.data.radius_world + absorbed_radius * absorbed_radius * 0.72)
	var minimum_visible_growth: float = survivor.data.radius_world + max(absorbed_radius * 0.075, 2.5)
	survivor.data.radius_world = max(area_growth_radius, minimum_visible_growth)
	survivor.data.visual_radius_px = int(max(float(survivor.data.visual_radius_px), survivor.data.radius_world))
	survivor.data.metadata["preserve_runtime_visual_radius"] = true
	if black_hole_merger:
		# A merger may grow, but can never produce an event horizon smaller than
		# either input black hole.
		preserved_black_hole_radius = clamp(
			max(preserved_black_hole_radius, area_growth_radius),
			_stage_radius_min(11),
			_stage_radius_max(11)
		)
	if _is_black_hole(survivor.data) or _is_black_hole(absorbed.data):
		survivor.data.body_kind = SimulationPlanetData.BodyKind.BLACK_HOLE
		survivor.data.metadata["black_hole_absorbed_count"] = int(survivor.data.metadata.get("black_hole_absorbed_count", 0)) + 1
		if preserve_black_hole_hero:
			# A normal body falling into an existing black hole should not redesign the
			# black hole hero/card/visual preset. Keep the black hole's original source
			# data and visible radius; only physics mass/velocity/lineage change.
			survivor.data.radius_world = max(preserved_black_hole_radius, 8.0)
			survivor.data.visual_radius_px = int(survivor.data.radius_world)
			if preserved_black_hole_source != null:
				survivor.data.source_planet_data = preserved_black_hole_source
			if black_hole_merger:
				# Every black-hole merger is an accretion event. Preserve the largest
				# hole's disk when present; otherwise create one on this first merger.
				_set_black_hole_accretion_disk(survivor.data, true, true)
			else:
				_refresh_black_hole_accretion_stage(survivor.data, absorbed.data)
		else:
			var black_hole_radius: float = BLACK_HOLE_COLLAPSE_RADIUS + min(float(survivor.data.metadata.get("black_hole_absorbed_count", 0)) * 10.0, 70.0)
			# Black holes are the explicit exception to the collision-growth visual rule:
			# collapse compresses the object, so it may become smaller than the red
			# supergiant or giant body that produced it.
			survivor.data.radius_world = clamp(black_hole_radius, _stage_radius_min(11), _stage_radius_max(11))
			survivor.data.visual_radius_px = int(survivor.data.radius_world)
			_ensure_black_hole_source_data(survivor.data, int(survivor.data.metadata.get("black_hole_absorbed_count", 0)) > 0)
	if _is_white_hole(survivor.data) or _is_white_hole(absorbed.data):
		survivor.data.metadata["white_hole_collision"] = true
	survivor.data.metadata["absorbed_count"] = int(survivor.data.metadata.get("absorbed_count", 0)) + 1
	survivor.data.metadata["last_absorbed"] = absorbed.data.get_display_name()
	survivor.data.metadata["last_collision_pair"] = [survivor.data.get_display_name(), absorbed.data.get_display_name()]
	if universe_end:
		survivor.data.metadata["universe_end_collision"] = true
		absorbed.data.metadata["universe_end_collision"] = true
	survivor.data.metadata["merge_visual_dirty"] = true
	survivor.data.metadata["merge_visual_old_radius"] = old_radius
	survivor.data.metadata["merge_visual_target_radius"] = survivor.data.radius_world
	survivor.data.metadata["orbit_architecture_dirty"] = true
	survivor.data.metadata.erase("binary_partner_id")
	survivor.data.metadata.erase("binary_center_locked")
	if not _is_black_hole(survivor.data):
		survivor.data.metadata["collision_min_radius_after_merge"] = max(max(old_radius, absorbed_radius), float(survivor.data.metadata.get("collision_min_radius_after_merge", 0.0)))
	else:
		survivor.data.metadata.erase("collision_min_radius_after_merge")
	_merge_achievement_lineage(survivor.data, absorbed.data)
	_apply_collision_evolution(survivor.data, absorbed.data)
	if preserve_black_hole_hero:
		survivor.data.body_kind = SimulationPlanetData.BodyKind.BLACK_HOLE
		survivor.data.radius_world = max(preserved_black_hole_radius, 8.0)
		survivor.data.visual_radius_px = int(survivor.data.radius_world)
		if preserved_black_hole_source != null:
			survivor.data.source_planet_data = preserved_black_hole_source
		if black_hole_merger:
			_set_black_hole_accretion_disk(survivor.data, true, true)
		else:
			_refresh_black_hole_accretion_stage(survivor.data, absorbed.data)
		survivor.data.metadata.erase("merge_visual_dirty")
	var evolved_survivor_achievement_snapshot: Dictionary = _achievement_snapshot(survivor.data, bodies)
	if not all_moons_cleared_payload.is_empty():
		evolved_survivor_achievement_snapshot["all_moons_cleared"] = all_moons_cleared_payload
	survivor.data.metadata["achievement_collision_survivor"] = evolved_survivor_achievement_snapshot
	absorbed.data.metadata["achievement_collision_survivor"] = evolved_survivor_achievement_snapshot
	survivor.sync_from_data()
	return absorbed


static func _last_attached_moon_collision_payload(a: SimulationPlanetData, b: SimulationPlanetData, bodies: Array) -> Dictionary:
	if a == null or b == null:
		return {}

	var colliding_planet: SimulationPlanetData = null
	var moon: SimulationPlanetData = null

	if _is_planet_kind(a) and _is_moon_kind(b):
		colliding_planet = a
		moon = b
	elif _is_planet_kind(b) and _is_moon_kind(a):
		colliding_planet = b
		moon = a
	else:
		return {}

	var colliding_planet_id := str(colliding_planet.instance_id).strip_edges()
	var moon_id := str(moon.instance_id).strip_edges()
	var owner_planet_id := str(moon.orbit_parent_id).strip_edges()
	if colliding_planet_id.is_empty() or moon_id.is_empty() or owner_planet_id.is_empty():
		return {}

	# "This Was Not Supposed to Happen" means a moon owned by one planet gets
	# slammed into a DIFFERENT planet. The old check accidentally counted the
	# moon falling back into its own owner, which made the achievement cheap/wrong.
	if colliding_planet_id == owner_planet_id:
		return {}

	var owner_planet: SimulationPlanetData = null
	for body in bodies:
		if body == null or not is_instance_valid(body) or body.data == null:
			continue
		var d: SimulationPlanetData = body.data
		if str(d.instance_id).strip_edges() == owner_planet_id and _is_planet_kind(d):
			owner_planet = d
			break
	if owner_planet == null:
		return {}

	var remaining_attached_moons := 0
	var previous_attached_moons := 1
	for body in bodies:
		if body == null or not is_instance_valid(body):
			continue
		var d: SimulationPlanetData = body.data
		if d == null:
			continue
		if str(d.instance_id).strip_edges() == moon_id:
			continue
		if str(d.orbit_parent_id).strip_edges() != owner_planet_id:
			continue
		if _is_moon_kind(d):
			remaining_attached_moons += 1
			previous_attached_moons += 1

	if remaining_attached_moons > 0:
		return {}

	return {
		"planet_id": owner_planet_id,
		"planet_name": owner_planet.get_display_name(),
		"target_planet_id": colliding_planet_id,
		"target_planet_name": colliding_planet.get_display_name(),
		"moon_id": moon_id,
		"moon_name": moon.get_display_name(),
		"previous_attached_moons": previous_attached_moons,
		"remaining_attached_moons": 0,
	}


static func _is_planet_kind(d: SimulationPlanetData) -> bool:
	if d == null:
		return false
	if int(d.body_kind) in [SimulationPlanetData.BodyKind.PLANET, SimulationPlanetData.BodyKind.RINGED_PLANET]:
		return true
	var category := ""
	if d.source_planet_data != null:
		category = str(d.source_planet_data.object_category).strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	if category.is_empty():
		category = str(d.metadata.get("object_category", "")).strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	return category in ["planet", "exoplanet", "dwarf_planet", "ringed_planet"]


static func _is_moon_kind(d: SimulationPlanetData) -> bool:
	if d == null:
		return false
	if int(d.body_kind) in [SimulationPlanetData.BodyKind.MOON, SimulationPlanetData.BodyKind.SATELLITE]:
		return true
	var category := ""
	if d.source_planet_data != null:
		category = str(d.source_planet_data.object_category).strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	if category.is_empty():
		category = str(d.metadata.get("object_category", "")).strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	return category in ["moon", "satellite", "natural_satellite"]

static func _ensure_black_hole_source_data(d: SimulationPlanetData, has_accretion_disk: bool = false) -> void:
	if d == null:
		return
	var p: PlanetData = null
	if d.source_planet_data != null:
		p = d.source_planet_data.duplicate(true) as PlanetData
	if p == null:
		return
	p.object_category = "singularity"
	p.archetype_id = "black_hole"
	p.planet_preset = "black_hole"
	p.subtitle = "Accreting black hole" if has_accretion_disk else "Freshly collapsed black hole"
	p.use_custom_colors = true
	p.custom_colors = PackedColorArray([Color("#050505"), Color("#111111"), Color("#000000"), Color("#1d1206"), Color("#2b1708"), Color("#090909")])
	p.planet_radius_px = int(max(d.radius_world, 8.0))
	d.source_planet_data = p
	d.metadata["runtime_visual_clone"] = true
	d.metadata["preserve_runtime_visual_radius"] = true
	_set_black_hole_accretion_disk(d, has_accretion_disk, true)
	d.metadata["force_rebuild_visual"] = true


static func _set_black_hole_accretion_disk(d: SimulationPlanetData, has_disk: bool, force_visual_rebuild: bool = false) -> void:
	if d == null:
		return
	if d.source_planet_data == null:
		return

	var p: PlanetData = d.source_planet_data.duplicate(true) as PlanetData
	if p == null:
		return

	var changed := p.singularity_has_disk != has_disk
	p.object_category = "singularity"
	p.archetype_id = "black_hole"
	p.planet_preset = "black_hole"
	p.singularity_has_disk = has_disk
	p.subtitle = "Accreting black hole" if has_disk else "Freshly collapsed black hole"
	p.ring_system = "Accretion disk" if has_disk else "None"
	p.planet_radius_px = int(max(d.radius_world, 8.0))
	_update_disk_data_card(p, has_disk)
	d.source_planet_data = p
	d.metadata["black_hole_has_accretion_disk"] = has_disk
	d.metadata["runtime_visual_clone"] = true
	d.metadata["preserve_runtime_visual_radius"] = true
	if changed or force_visual_rebuild:
		d.metadata["force_rebuild_visual"] = true


static func _update_disk_data_card(p: PlanetData, has_disk: bool) -> void:
	if p == null:
		return
	var value := "Accretion disk" if has_disk else "None"
	var updated := false
	for i in range(p.data_cards.size()):
		var card = p.data_cards[i]
		if card is Dictionary and str(card.get("title", "")).strip_edges().to_lower() == "disk":
			card["value"] = value
			p.data_cards[i] = card
			updated = true
			break
	if not updated:
		p.data_cards.append({"title": "Disk", "value": value})


static func _refresh_black_hole_accretion_stage(d: SimulationPlanetData, absorbed: SimulationPlanetData = null) -> void:
	if d == null:
		return
	if not _is_black_hole(d):
		return
	var absorbed_count := int(d.metadata.get("black_hole_absorbed_count", 0))
	var has_disk := absorbed_count > 0
	if absorbed != null and not _is_black_hole(absorbed):
		has_disk = true
	_set_black_hole_accretion_disk(d, has_disk, false)


static func _merge_achievement_lineage(survivor: SimulationPlanetData, absorbed: SimulationPlanetData) -> void:
	if survivor == null or absorbed == null:
		return
	var names: Array = []
	var levels := {}
	var categories: Array = []
	var star_colors: Array = []
	var star_color_levels := {}
	_collect_lineage_into(survivor, names, levels, categories, star_colors, star_color_levels)
	_collect_lineage_into(absorbed, names, levels, categories, star_colors, star_color_levels)
	survivor.metadata["lineage_names"] = names
	survivor.metadata["lineage_levels"] = levels
	survivor.metadata["lineage_categories"] = categories
	survivor.metadata["lineage_star_colors"] = star_colors
	survivor.metadata["lineage_star_color_levels"] = star_color_levels

static func _collect_lineage_into(d: SimulationPlanetData, names: Array, levels: Dictionary, categories: Array = [], star_colors: Array = [], star_color_levels: Dictionary = {}) -> void:
	if d == null:
		return
	var raw_names: Variant = d.metadata.get("lineage_names", [])
	var raw_levels: Variant = d.metadata.get("lineage_levels", {})
	var raw_categories: Variant = d.metadata.get("lineage_categories", [])
	var raw_star_colors: Variant = d.metadata.get("lineage_star_colors", [])
	var raw_star_color_levels: Variant = d.metadata.get("lineage_star_color_levels", {})
	if raw_names is Array:
		for value in raw_names:
			var n := str(value).strip_edges().to_lower()
			if n.is_empty(): continue
			if not names.has(n): names.append(n)
			if raw_levels is Dictionary and raw_levels.has(n): levels[n] = max(int(levels.get(n, 1)), int(raw_levels[n]))
	if raw_star_colors is Array:
		for value in raw_star_colors:
			var color := str(value).strip_edges().to_lower().replace(" ", "_").replace("-", "_")
			if color == "blue_white":
				color = "blue"
			if not color.is_empty() and not star_colors.has(color):
				star_colors.append(color)
	if raw_star_color_levels is Dictionary:
		for key in raw_star_color_levels.keys():
			var color_key := str(key).strip_edges().to_lower().replace(" ", "_").replace("-", "_")
			if color_key == "blue_white":
				color_key = "blue"
			if color_key.is_empty():
				continue
			star_color_levels[color_key] = max(int(star_color_levels.get(color_key, 1)), int(raw_star_color_levels[key]))

	var had_existing_lineage_categories := false
	if raw_categories is Array:
		for value in raw_categories:
			var c := str(value).strip_edges().to_lower().replace(" ", "_").replace("-", "_")
			if not c.is_empty():
				categories.append(c)
				had_existing_lineage_categories = true
	var self_name := d.get_display_name().strip_edges().to_lower()
	if d.source_planet_data != null and not str(d.source_planet_data.name).strip_edges().is_empty():
		self_name = str(d.source_planet_data.name).strip_edges().to_lower()
	var self_level := int(d.source_planet_data.game_level if d.source_planet_data != null else 1)
	if not self_name.is_empty():
		if not names.has(self_name): names.append(self_name)
		levels[self_name] = max(int(levels.get(self_name, 1)), self_level)
	var self_category := str(d.source_planet_data.object_category if d.source_planet_data != null else d.metadata.get("object_category", "")).strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	if self_category.is_empty():
		match int(d.body_kind):
			2, 6:
				self_category = "moon"
			1, 7:
				self_category = "planet"
			3:
				self_category = "star"
			4:
				self_category = "black_hole"
			8:
				self_category = "white_hole"
			_:
				self_category = "unknown"
	# When a body already has lineage_categories, those entries represent the
	# original source bodies that created it. Do not append the current evolved
	# category again, otherwise a moon+moon body that evolved into a planet becomes
	# [moon, moon, planet] and moon-lineage achievements can never pass.
	if _lineage_entry_is_star(d, self_category):
		for color in _star_color_tags_for_data(d):
			if not star_colors.has(color):
				star_colors.append(color)
			star_color_levels[color] = max(int(star_color_levels.get(color, 1)), self_level)
	if not had_existing_lineage_categories:
		categories.append(self_category)

static func _lineage_entry_is_star(d: SimulationPlanetData, category: String) -> bool:
	if d == null:
		return false
	if int(d.body_kind) == SimulationPlanetData.BodyKind.STAR:
		return true
	return category == "star"

static func _star_color_tags_for_data(d: SimulationPlanetData) -> Array:
	var result: Array = []
	if d == null:
		return result
	var source = d.source_planet_data
	var text := "%s %s %s %s %s" % [
		d.get_display_name(),
		str(source.name if source != null else ""),
		str(source.subtitle if source != null else ""),
		str(source.archetype_id if source != null else ""),
		str(source.planet_preset if source != null else "")
	]
	text = text.to_lower().replace("-", "_").replace(" ", "_")
	if text.contains("brown_dwarf") or text.contains("brown"):
		result.append("brown")
	if text.contains("red_supergiant") or text.contains("red_giant") or text.contains("red_dwarf") or text.contains("red"):
		result.append("red")
	if text.contains("orange"):
		result.append("orange")
	if text.contains("yellow") or text.contains("sun") or text.contains("solar"):
		result.append("yellow")
	if text.contains("blue_white") or text.contains("blue"):
		result.append("blue")
	if text.contains("white_dwarf") or text.contains("white"):
		result.append("white")
	if result.is_empty() and source != null:
		var color := _star_color_tag_from_color(_source_main_color(source))
		if not color.is_empty():
			result.append(color)
	if result.is_empty():
		result.append("yellow")
	var unique: Array = []
	for color in result:
		if not unique.has(color):
			unique.append(color)
	return unique

static func _star_color_tag_from_color(color: Color) -> String:
	var hue := color.h
	var sat := color.s
	var val := color.v
	if val < 0.22:
		return "brown"
	if sat < 0.14 and val > 0.72:
		return "white"
	if hue < 0.035 or hue >= 0.92:
		return "red"
	if hue < 0.105:
		return "orange"
	if hue < 0.19:
		return "yellow"
	if hue >= 0.50 and hue <= 0.72:
		return "blue"
	if val > 0.80:
		return "white"
	return "yellow"

static func _color_array_to_hex_strings(colors: PackedColorArray) -> Array:
	var result: Array = []
	for color in colors:
		result.append(color.to_html(false))
	return result

static func _achievement_snapshot(d: SimulationPlanetData, bodies: Array = []) -> Dictionary:
	if d == null:
		return {}
	var source = d.source_planet_data
	var names: Array = []
	var levels := {}
	var categories: Array = []
	var star_colors: Array = []
	var star_color_levels := {}
	_collect_lineage_into(d, names, levels, categories, star_colors, star_color_levels)
	var parent_kind := -1
	var parent_name := ""
	for body in bodies:
		if body == null or not is_instance_valid(body) or body.data == null:
			continue
		var pd: SimulationPlanetData = body.data
		if str(pd.instance_id) == str(d.orbit_parent_id):
			parent_kind = int(pd.body_kind)
			parent_name = pd.get_display_name()
			break
	return {
		"display_name": d.get_display_name(),
		"body_kind": int(d.body_kind),
		"mass": d.mass,
		"radius_world": d.radius_world,
		"position": d.position,
		"velocity": d.velocity,
		"orbit_parent_id": d.orbit_parent_id,
		"orbit_parent_body_kind": parent_kind,
		"orbit_parent_name": parent_name,
		"achievement_all_moons_cleared": d.metadata.get("achievement_all_moons_cleared", {}),
		"all_moons_cleared": d.metadata.get("achievement_all_moons_cleared", {}),
		"instance_id": d.instance_id,
		"game_level": int(source.game_level if source != null else 1),
		"object_category": str(source.object_category if source != null else ""),
		"planet_preset": str(source.planet_preset if source != null else ""),
		"archetype_id": str(source.archetype_id if source != null else ""),
		"name": str(source.name if source != null else d.display_name),
		"subtitle": str(source.subtitle if source != null else ""),
		"diameter_km": str(source.diameter_km if source != null else ""),
		"mass_text": str(source.mass if source != null else ""),
		"visual_signature": str(source.visual_signature if source != null else ""),
		"custom_colors": _color_array_to_hex_strings(source.custom_colors) if source != null else [],
		"lineage_names": names,
		"lineage_levels": levels,
		"lineage_categories": categories,
		"lineage_star_colors": star_colors,
		"lineage_star_color_levels": star_color_levels,
		"game_attribute_scores": source.game_attribute_scores if source != null else [],
	}


static func _source_main_color(p: PlanetData) -> Color:
	if p == null:
		return Color("#d4a765")
	if p.custom_colors.size() > 0:
		return p.get_hero_main_color()
	return PlanetData._fallback_main_color_for_preset(p.planet_preset, p.object_category, p.name)

static func _derived_gas_colors(base: Color) -> PackedColorArray:
	var warm := base.lerp(Color("#d9a15d"), 0.34)
	var pale := warm.lerp(Color.WHITE, 0.28)
	var deep := warm.darkened(0.38)
	var storm := warm.lerp(Color("#f0c483"), 0.52)
	return PackedColorArray([
		pale,
		warm.lightened(0.12),
		warm,
		deep,
		storm,
		warm.darkened(0.18),
	])

static func _derived_ice_colors(base: Color) -> PackedColorArray:
	var cold := base.lerp(Color("#6ed9ee"), 0.62)
	var frost := cold.lerp(Color.WHITE, 0.42)
	var blue := cold.lerp(Color("#2d8fe8"), 0.34)
	var deep := cold.darkened(0.34)
	return PackedColorArray([
		frost,
		cold.lightened(0.18),
		blue,
		deep,
		cold.lerp(Color("#dffbff"), 0.45),
		blue.darkened(0.18),
	])

static func _apply_collision_evolution(d: SimulationPlanetData, absorbed: SimulationPlanetData = null) -> void:
	if d == null or d.source_planet_data == null:
		return

	if d.body_kind == SimulationPlanetData.BodyKind.BLACK_HOLE or d.body_kind == SimulationPlanetData.BodyKind.WHITE_HOLE:
		return

	var p: PlanetData = d.source_planet_data.duplicate(true) as PlanetData
	if p == null:
		return
	var original_main_color: Color = _source_main_color(p)
	var impact_traits := _impact_traits(absorbed)
	d.source_planet_data = p
	d.metadata["runtime_visual_clone"] = true
	d.metadata["preserve_runtime_visual_radius"] = true

	var stage := _collision_evolution_stage(d)
	var previous_stage := int(d.metadata.get("collision_evolution_stage", -1))
	if stage < previous_stage:
		stage = previous_stage
	if stage == 2 and _source_evolution_stage(d) >= 2:
		stage = 3
	d.metadata["collision_evolution_stage"] = stage
	_apply_stage_radius_bounds(d, stage)

	match stage:
		0:
			d.body_kind = SimulationPlanetData.BodyKind.MOON
			d.gravitational_influence = max(d.gravitational_influence, 0.42)
			p.object_category = "moon"
			p.archetype_id = "moon"
			p.planet_preset = "moon"
			p.subtitle = "Collision-grown moon"
		1:
			d.body_kind = SimulationPlanetData.BodyKind.PLANET
			d.gravitational_influence = max(d.gravitational_influence, 1.0)
			p.object_category = "planet"
			_apply_rocky_collision_variant(p, impact_traits, original_main_color)
		2:
			d.body_kind = SimulationPlanetData.BodyKind.RINGED_PLANET
			d.gravitational_influence = max(d.gravitational_influence, 1.32)
			p.object_category = "planet"
			p.archetype_id = "ringed_gas_giant"
			p.planet_preset = "ringed_gas_planet"
			p.subtitle = "Collision-grown ringed gas giant"
			p.use_custom_colors = true
			p.custom_colors = _derived_gas_colors(original_main_color)
		3:
			d.body_kind = SimulationPlanetData.BodyKind.RINGED_PLANET
			d.gravitational_influence = max(d.gravitational_influence, 1.32)
			p.object_category = "planet"
			p.archetype_id = "ringed_gas_giant"
			p.planet_preset = "ringed_gas_planet"
			p.subtitle = "Collision-grown ringed gas giant"
			p.use_custom_colors = true
			p.custom_colors = _derived_gas_colors(original_main_color)
		4:
			# Stage 4 is now always a giant phase, never a direct brown-dwarf jump.
			# Cold/icy impact material produces an ice giant; otherwise the body becomes
			# a ringed gas giant first, so the evolution chain feels earned.
			if bool(impact_traits.get("cold", false)):
				d.body_kind = SimulationPlanetData.BodyKind.PLANET
				d.gravitational_influence = max(d.gravitational_influence, 1.45)
				p.object_category = "planet"
				p.archetype_id = "ice_giant"
				p.planet_preset = "ice_world"
				p.subtitle = "Collision-grown ice giant"
				p.use_custom_colors = true
				p.custom_colors = _derived_ice_colors(original_main_color)
			else:
				d.body_kind = SimulationPlanetData.BodyKind.RINGED_PLANET
				d.gravitational_influence = max(d.gravitational_influence, 1.46)
				p.object_category = "planet"
				p.archetype_id = "ringed_gas_giant"
				p.planet_preset = "ringed_gas_planet"
				p.subtitle = "Collision-grown mature ringed gas giant"
				p.use_custom_colors = true
				p.custom_colors = _derived_gas_colors(original_main_color)
		5:
			d.body_kind = SimulationPlanetData.BodyKind.STAR
			d.gravitational_influence = max(d.gravitational_influence, 1.85)
			p.object_category = "star"
			p.archetype_id = "brown_dwarf"
			p.planet_preset = "gas_giant_1"
			p.subtitle = "Collision-grown brown dwarf"
			p.use_custom_colors = true
			p.custom_colors = PackedColorArray([Color("#2a1208"), Color("#4a2410"), Color("#6b3516"), Color("#120805"), Color("#241009"), Color("#3a1a0c")])
		_:
			if stage >= 11:
				d.body_kind = SimulationPlanetData.BodyKind.BLACK_HOLE
				d.gravitational_influence = max(d.gravitational_influence, 4.6)
				d.density = max(d.density, 1000.0)
				p.object_category = "singularity"
				p.archetype_id = "black_hole"
				p.planet_preset = "black_hole"
				p.subtitle = "Freshly collapsed black hole"
				p.singularity_has_disk = false
				p.ring_system = "None"
				_update_disk_data_card(p, false)
				p.use_custom_colors = true
				p.custom_colors = PackedColorArray([Color("#050505"), Color("#111111"), Color("#000000"), Color("#1d1206"), Color("#2b1708"), Color("#090909")])
				d.metadata["black_hole_has_accretion_disk"] = false
				d.metadata["unlock_black_magic"] = true
				d.metadata["collapsed_from_red_supergiant"] = true
				d.radius_world = clamp(d.radius_world, _stage_radius_min(11), _stage_radius_max(11))
				d.visual_radius_px = int(d.radius_world)
			else:
				d.body_kind = SimulationPlanetData.BodyKind.STAR
				d.gravitational_influence = max(d.gravitational_influence, 2.5 + float(stage - 6) * 0.34)
				p.object_category = "star"
				p.archetype_id = "star"
				p.planet_preset = "star"
				p.subtitle = _star_stage_subtitle(stage)
				p.use_custom_colors = true
				p.custom_colors = _star_stage_colors(stage)

	var min_radius := 0.0 if d.body_kind == SimulationPlanetData.BodyKind.BLACK_HOLE else float(d.metadata.get("collision_min_radius_after_merge", 0.0))
	if min_radius > 0.0:
		d.radius_world = max(d.radius_world, min_radius)
		d.visual_radius_px = int(max(float(d.visual_radius_px), d.radius_world))
		d.metadata["merge_visual_target_radius"] = d.radius_world
	p.planet_radius_px = int(d.radius_world)
	d.metadata["force_rebuild_visual"] = true
	d.metadata["collision_evolved"] = true

static func _impact_traits(absorbed: SimulationPlanetData) -> Dictionary:
	var traits := {"cold": false, "hot": false, "bare": false, "watery": false, "gas": false}
	if absorbed == null:
		return traits
	var p: PlanetData = absorbed.source_planet_data
	var text := ""
	if p != null:
		text = "%s %s %s %s %s %s %s" % [p.name, p.subtitle, p.object_category, p.archetype_id, p.planet_preset, p.composition, p.surface_geology]
	text = text.strip_edges().to_lower().replace("-", "_")
	traits["cold"] = text.contains("ice") or text.contains("frost") or text.contains("snow") or text.contains("cold") or text.contains("frozen") or text.contains("neptune") or text.contains("uranus")
	traits["hot"] = text.contains("lava") or text.contains("magma") or text.contains("volcan") or text.contains("hot") or text.contains("scorch") or text.contains("venus") or text.contains("fire") or text.contains("molten")
	traits["bare"] = text.contains("bare") or text.contains("mercury") or text.contains("dry") or text.contains("desert") or text.contains("crater") or text.contains("no_atmosphere")
	traits["watery"] = text.contains("water") or text.contains("ocean") or text.contains("river") or text.contains("sea") or text.contains("ice")
	traits["gas"] = text.contains("gas") or text.contains("jupiter") or text.contains("saturn")
	return traits

static func _apply_rocky_collision_variant(p: PlanetData, impact_traits: Dictionary, base: Color) -> void:
	p.archetype_id = "rocky"
	if bool(impact_traits.get("hot", false)):
		p.planet_preset = "lava_world"
		p.subtitle = "Collision-heated lava world"
		p.use_custom_colors = true
		p.custom_colors = PackedColorArray([base.lerp(Color("#ff5d1f"), 0.68), Color("#ff8a2a"), Color("#3a0804"), Color("#ffcc7a"), Color("#8c1508"), Color("#1c0302")])
	elif bool(impact_traits.get("cold", false)) or bool(impact_traits.get("watery", false)):
		p.planet_preset = "rivers"
		p.subtitle = "Collision-seeded water world"
		p.use_custom_colors = true
		p.custom_colors = PackedColorArray([base.lerp(Color("#2f8fd7"), 0.62), Color("#5fd1ff"), Color("#1d5b36"), Color("#d7f8ff"), Color("#2f9a68"), Color("#0b2f55")])
	elif bool(impact_traits.get("bare", false)):
		p.planet_preset = "terran_dry"
		p.subtitle = "Collision-stripped desert world"
		p.use_custom_colors = true
		p.custom_colors = PackedColorArray([base.lerp(Color("#c4864f"), 0.66), Color("#e0b06a"), Color("#6d4528"), Color("#f2d39b"), Color("#9b6538"), Color("#322012")])
	else:
		p.planet_preset = "terran_dry"
		p.subtitle = "Collision-grown rocky planet"

static func _apply_stage_radius_bounds(d: SimulationPlanetData, stage: int) -> void:
	if d == null:
		return
	var old_radius: float = float(d.metadata.get("merge_visual_old_radius", d.radius_world))
	var min_radius: float = _stage_radius_min(stage)
	var max_radius: float = _stage_radius_max(stage)
	var target_radius: float = d.radius_world
	if stage >= 11:
		var compressed: float = BLACK_HOLE_COLLAPSE_RADIUS + min(float(d.metadata.get("black_hole_absorbed_count", 0)) * 10.0, 70.0)
		target_radius = clamp(compressed, min_radius, max_radius)
	else:
		if target_radius < min_radius:
			target_radius = min_radius
		if target_radius <= old_radius and old_radius < max_radius:
			target_radius = min(max_radius, old_radius + max(2.5, (max_radius - min_radius) * 0.055))
		target_radius = clamp(target_radius, min_radius, max_radius)
	d.radius_world = target_radius
	d.visual_radius_px = int(target_radius)
	d.metadata["merge_visual_target_radius"] = target_radius

static func _stage_radius_min(stage: int) -> float:
	var bounds: Vector2 = COLLISION_STAGE_RADIUS_BOUNDS.get(stage, COLLISION_STAGE_RADIUS_BOUNDS[10])
	return bounds.x

static func _stage_radius_max(stage: int) -> float:
	var bounds: Vector2 = COLLISION_STAGE_RADIUS_BOUNDS.get(stage, COLLISION_STAGE_RADIUS_BOUNDS[10])
	return bounds.y

static func _collision_evolution_stage(d: SimulationPlanetData) -> int:
	var m := max(d.mass, 0.0)
	var source_stage := _source_evolution_stage(d)
	var mass_stage := 0
	if m >= 11200.0:
		mass_stage = 11
	elif m >= 8200.0:
		mass_stage = 10
	elif m >= 5600.0:
		mass_stage = 9
	elif m >= 3400.0:
		mass_stage = 8
	elif m >= 1800.0:
		mass_stage = 7
	elif m >= 820.0:
		mass_stage = 6
	elif m >= 340.0:
		mass_stage = 4
	elif m >= 170.0:
		mass_stage = 3
	elif m >= 70.0:
		mass_stage = 2
	elif m >= 8.0:
		mass_stage = 1

	var stage: int = max(source_stage, mass_stage)
	var collision_count := int(d.metadata.get("absorbed_count", 0))
	if collision_count >= 2 and stage < 3:
		stage = 3
	if collision_count >= 4 and stage < 4:
		stage = 4
	if collision_count >= 8 and stage < 5:
		stage = 5

	# Keep collision evolution readable: a rocky world should not jump straight into a
	# brown dwarf just because several impacts happened quickly. It must visibly pass
	# through the gas/ice-giant phase first. Massive pre-existing stars/black holes are
	# still handled by source_stage/mass_stage above, but normal collision-grown bodies
	# advance at most one evolution stage per merge.
	var previous_stage := int(d.metadata.get("collision_evolution_stage", -1))
	if previous_stage >= 0 and stage > previous_stage + 1:
		stage = previous_stage + 1
	if stage >= 5 and previous_stage < 4 and source_stage < 5:
		stage = 4
	return stage

static func _source_evolution_stage(d: SimulationPlanetData) -> int:
	if d == null or d.source_planet_data == null:
		return 0
	var p: PlanetData = d.source_planet_data
	var preset := str(p.planet_preset).strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	var category := str(p.object_category).strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	var archetype := str(p.archetype_id).strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	if preset == "star" or category == "star" or archetype == "star":
		return 6
	if archetype == "brown_dwarf":
		return 5
	if preset == "ice_world" or archetype == "ice_giant":
		return 4
	if preset == "ringed_gas_planet" or preset == "gas_giant_2" or archetype == "ringed_gas_giant":
		return 3
	if preset == "gas_giant_1" or preset == "gas_planet" or archetype == "gas_giant" or archetype.contains("gas"):
		return 2
	if preset == "moon" or preset == "no_atmosphere" or category == "moon":
		return 0
	return 1

static func _star_stage_subtitle(stage: int) -> String:
	if stage <= 6:
		return "Collision-grown red dwarf"
	if stage == 7:
		return "Collision-grown yellow star"
	if stage == 8:
		return "Collision-grown blue-white star"
	if stage == 9:
		return "Collision-grown red giant"
	return "Collision-grown red supergiant"

static func _star_stage_colors(stage: int) -> PackedColorArray:
	if stage <= 6:
		return PackedColorArray([Color("#5a130b"), Color("#b43818"), Color("#ff7a2a"), Color("#260704"), Color("#7b1d0e"), Color("#ffb36a")])
	if stage == 7:
		return PackedColorArray([Color("#fff2a6"), Color("#ffd45a"), Color("#ff9f2e"), Color("#fffbe2"), Color("#ffcc47"), Color("#fff1a8")])
	if stage == 8:
		return PackedColorArray([Color("#e8fbff"), Color("#9fdcff"), Color("#4fa6ff"), Color("#ffffff"), Color("#bfeaff"), Color("#6cb8ff")])
	if stage == 9:
		return PackedColorArray([Color("#ff6a1f"), Color("#c32912"), Color("#7a0f08"), Color("#ffd09a"), Color("#ff8b3d"), Color("#4a0805")])
	return PackedColorArray([Color("#ff2e12"), Color("#991006"), Color("#3d0302"), Color("#ffb06a"), Color("#e43b14"), Color("#5c0703")])

static func _is_black_hole(d: SimulationPlanetData) -> bool: return d != null and d.body_kind == SimulationPlanetData.BodyKind.BLACK_HOLE
static func _is_white_hole(d: SimulationPlanetData) -> bool: return d != null and d.body_kind == SimulationPlanetData.BodyKind.WHITE_HOLE
static func _valid(body) -> bool: return body != null and is_instance_valid(body) and body.data != null

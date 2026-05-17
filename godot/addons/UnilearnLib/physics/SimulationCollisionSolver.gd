extends RefCounted
class_name SimulationCollisionSolver

# Collision modes:
# 0 OFF, 1 MERGE, 2 BOUNCE.
# Merge conserves momentum and keeps the larger visual/card source.

static func solve(bodies: Array, config: SimulationPhysicsConfig) -> Array:
	var removed: Array = []
	if bodies.size() < 2 or config == null or not config.collisions_enabled:
		return removed

	for i in range(bodies.size()):
		var a = bodies[i]
		if not _valid(a) or removed.has(a):
			continue
		for j in range(i + 1, bodies.size()):
			var b = bodies[j]
			if not _valid(b) or removed.has(b):
				continue

			if not _are_colliding(a.data, b.data, config):
				continue

			var mode := _resolve_mode(a.data, b.data, config)
			if mode == SimulationPlanetData.CollisionMode.OFF:
				continue
			elif mode == SimulationPlanetData.CollisionMode.BOUNCE:
				_bounce(a.data, b.data, config)
			else:
				var dead = _merge(a, b, config)
				if dead != null:
					removed.append(dead)

	return removed


static func _are_colliding(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> bool:
	var r := a.get_collision_radius(config) + b.get_collision_radius(config)
	return a.position.distance_squared_to(b.position) <= r * r


static func _resolve_mode(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> int:
	if a.collision_mode == SimulationPlanetData.CollisionMode.OFF or b.collision_mode == SimulationPlanetData.CollisionMode.OFF:
		return SimulationPlanetData.CollisionMode.OFF
	if a.collision_mode == SimulationPlanetData.CollisionMode.BOUNCE or b.collision_mode == SimulationPlanetData.CollisionMode.BOUNCE:
		return SimulationPlanetData.CollisionMode.BOUNCE
	return config.default_collision_mode


static func _bounce(a: SimulationPlanetData, b: SimulationPlanetData, config: SimulationPhysicsConfig) -> void:
	var normal := b.position - a.position
	if normal.length_squared() <= 0.001:
		normal = Vector2.RIGHT
	normal = normal.normalized()

	var relative_velocity := a.velocity - b.velocity
	var vel_along_normal := relative_velocity.dot(normal)
	if vel_along_normal > 0.0:
		return

	var inv_mass_a: float = 0.0 if a.is_static_anchor else 1.0 / max(a.mass, 0.001)
	var inv_mass_b: float = 0.0 if b.is_static_anchor else 1.0 / max(b.mass, 0.001)
	var j := -(1.0 + config.bounce_restitution) * vel_along_normal
	j /= max(inv_mass_a + inv_mass_b, 0.001)

	var impulse := normal * j
	if not a.is_static_anchor:
		a.velocity += impulse * inv_mass_a
	if not b.is_static_anchor:
		b.velocity -= impulse * inv_mass_b

	_separate(a, b, normal, config)


static func _separate(a: SimulationPlanetData, b: SimulationPlanetData, normal: Vector2, config: SimulationPhysicsConfig) -> void:
	var target := a.get_collision_radius(config) + b.get_collision_radius(config)
	var current := a.position.distance_to(b.position)
	var penetration := max(target - current, 0.0)
	if penetration <= 0.0:
		return

	if a.is_static_anchor and not b.is_static_anchor:
		b.position += normal * penetration
	elif b.is_static_anchor and not a.is_static_anchor:
		a.position -= normal * penetration
	else:
		a.position -= normal * penetration * 0.5
		b.position += normal * penetration * 0.5


static func _merge(a, b, config: SimulationPhysicsConfig):
	var survivor = a if a.data.mass >= b.data.mass else b
	var absorbed = b if survivor == a else a

	var total_mass := max(survivor.data.mass + absorbed.data.mass, 0.001)
	var new_position: Vector2 = (survivor.data.position * survivor.data.mass + absorbed.data.position * absorbed.data.mass) / total_mass
	var new_velocity: Vector2 = (survivor.data.velocity * survivor.data.mass + absorbed.data.velocity * absorbed.data.mass) / total_mass
	new_velocity *= max(0.0, 1.0 - config.merge_velocity_loss)

	survivor.data.mass = total_mass
	survivor.data.position = new_position
	survivor.data.velocity = new_velocity
	survivor.data.radius_world = sqrt(survivor.data.radius_world * survivor.data.radius_world + absorbed.data.radius_world * absorbed.data.radius_world * 0.28)
	survivor.data.visual_radius_px = int(max(survivor.data.visual_radius_px, survivor.data.radius_world))
	survivor.data.metadata["absorbed_count"] = int(survivor.data.metadata.get("absorbed_count", 0)) + 1
	survivor.data.metadata["last_absorbed"] = absorbed.data.get_display_name()
	survivor.data.reset_trail()
	survivor.sync_from_data()

	return absorbed


static func _valid(body) -> bool:
	return body != null and is_instance_valid(body) and body.data != null

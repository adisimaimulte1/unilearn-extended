extends Node2D
class_name SimulationSandboxController

signal body_added(body: SimulationPlanetBody)
signal body_removed(body: SimulationPlanetBody)
signal body_selected(body: SimulationPlanetBody)
signal collision_merged(survivor: SimulationPlanetBody, removed: SimulationPlanetBody)

@export var config: SimulationPhysicsConfig = SimulationPhysicsConfig.new()
@export var auto_select_added_body: bool = true

var bodies: Array[SimulationPlanetBody] = []
var selected_body: SimulationPlanetBody = null
var paused: bool = false


func _physics_process(delta: float) -> void:
	if paused:
		return

	if config == null:
		return

	if config.gravity_enabled:
		SimulationGravitySolver.step(bodies, delta, config)

	var removed := SimulationCollisionSolver.solve(bodies, config)
	for body in removed:
		_remove_body_internal(body)


func add_planet_data(planet_data: PlanetData, spawn_position: Vector2) -> SimulationPlanetBody:
	var body := SimulationPlanetFactory.create_body_from_planet_data(planet_data, spawn_position)
	add_body(body)
	return body


func add_body(body: SimulationPlanetBody) -> void:
	if body == null:
		return
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

	body.data.velocity = Vector2.ZERO if config.ignore_drag_throw_velocity else release_velocity.limit_length(config.max_drag_throw_speed) * config.drag_throw_strength

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

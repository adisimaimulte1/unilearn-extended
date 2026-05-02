extends Control

@export var star_count: int = 170
@export var travel_speed_multiplier: float = 0.0
@export var travel_direction: Vector2 = Vector2(0.0, -1.0)

@export var nebula_alpha: float = 0.16
@export var nebula_drift_strength: float = 4.0
@export var nebula_drift_speed: float = 0.08

@onready var space_gradient: ColorRect = $SpaceGradient
@onready var wave_nebula: ColorRect = $WaveNebula
@onready var star_layer: Control = $StarLayer

var stars: Array[ColorRect] = []
var star_data: Array[Dictionary] = []

var star_reveal: float = 0.0
var scroll_offset: float = 0.0
var nebula_base_position := Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)

	space_gradient.set_anchors_preset(Control.PRESET_FULL_RECT)
	space_gradient.set_offsets_preset(Control.PRESET_FULL_RECT)

	wave_nebula.set_anchors_preset(Control.PRESET_FULL_RECT)
	wave_nebula.set_offsets_preset(Control.PRESET_FULL_RECT)

	star_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	star_layer.set_offsets_preset(Control.PRESET_FULL_RECT)

	nebula_base_position = wave_nebula.position

	_setup_materials()
	_create_stars()
	_apply_scroll()


func _setup_materials() -> void:
	space_gradient.material.set_shader_parameter("reveal", 0.0)
	space_gradient.material.set_shader_parameter("wave_strength", 0.08)
	space_gradient.material.set_shader_parameter("color_a", Color(0.0, 0.0, 0.0, 1.0))
	space_gradient.material.set_shader_parameter("color_b", Color(0.008, 0.018, 0.055, 1.0))
	space_gradient.material.set_shader_parameter("color_c", Color(0.025, 0.045, 0.11, 1.0))

	wave_nebula.material.set_shader_parameter("reveal", 0.0)
	wave_nebula.material.set_shader_parameter("wave_strength", 0.12)
	wave_nebula.material.set_shader_parameter("color_a", Color(0.0, 0.0, 0.0, 0.0))
	wave_nebula.material.set_shader_parameter("color_b", Color(0.018, 0.035, 0.095, 0.75))
	wave_nebula.material.set_shader_parameter("color_c", Color(0.055, 0.065, 0.16, 0.65))
	wave_nebula.modulate.a = nebula_alpha


func _create_stars() -> void:
	var screen_size := get_viewport_rect().size

	for i in star_count:
		var star := ColorRect.new()
		var s := randf_range(1.5, 4.0)

		star.size = Vector2(s, s)
		star.position = Vector2(randf_range(0, screen_size.x), randf_range(0, screen_size.y))
		star.color = Color(1, 1, 1, 0)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE

		star_layer.add_child(star)
		stars.append(star)

		star_data.append({
			"speed": randf_range(4, 18),
			"drift": randf_range(-4, 4),
			"pulse": randf_range(1.3, 3.4),
			"base_alpha": randf_range(0.75, 1.25),
			"phase": randf_range(0, TAU)
		})


func intro_reveal(tween: Tween) -> void:
	tween.tween_method(set_space_reveal, 0.0, 1.0, 0.7)
	tween.parallel().tween_method(set_nebula_reveal, 0.0, 0.65, 1.0)
	tween.parallel().tween_property(self, "star_reveal", 1.0, 0.9)


func set_space_reveal(v: float) -> void:
	space_gradient.material.set_shader_parameter("reveal", v)


func set_nebula_reveal(v: float) -> void:
	wave_nebula.material.set_shader_parameter("reveal", v)


func set_scroll_offset(v: float) -> void:
	scroll_offset = v
	_apply_scroll()


func _process(delta: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0
	var screen_size := get_viewport_rect().size

	_apply_scroll()
	_update_nebula_drift(time)

	var direction := travel_direction.normalized()
	var travel_velocity := direction * travel_speed_multiplier

	for i in stars.size():
		var s := stars[i]
		var d := star_data[i]

		s.position.y += float(d["speed"]) * delta
		s.position.x += sin(time + float(d["phase"])) * float(d["drift"]) * delta

		s.position += travel_velocity * delta

		var pulse := sin(time * float(d["pulse"]) + float(d["phase"])) * 0.45 + 0.65
		s.color.a = min(1.0, float(d["base_alpha"]) * pulse * star_reveal)

		if s.position.y > screen_size.y + 20.0:
			s.position.y = -20.0
			s.position.x = randf_range(0, screen_size.x)

		if s.position.y < -20.0:
			s.position.y = screen_size.y + 20.0
			s.position.x = randf_range(0, screen_size.x)

		if s.position.x > screen_size.x + 20.0:
			s.position.x = -20.0
			s.position.y = randf_range(0, screen_size.y)

		if s.position.x < -20.0:
			s.position.x = screen_size.x + 20.0
			s.position.y = randf_range(0, screen_size.y)


func _update_nebula_drift(time: float) -> void:
	wave_nebula.position = nebula_base_position + Vector2(
		sin(time * nebula_drift_speed) * nebula_drift_strength,
		cos(time * nebula_drift_speed * 0.7) * nebula_drift_strength
	)


func _apply_scroll() -> void:
	star_layer.position = Vector2.ZERO
	space_gradient.position = Vector2.ZERO

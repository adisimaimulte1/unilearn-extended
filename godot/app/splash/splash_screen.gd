extends Control

@export var logo_fade_duration: float = 0.55
@export var splash_duration: float = 0.85

@export var logo_size: Vector2 = Vector2(1024, 1024)
@export var logo_vertical_ratio: float = 0.38
@export var global_down_shift: float = 90.0
@export var title_gap: float = 175.0

@export var planet_intro_duration: float = 1.85
@export var planet_intro_stagger: float = 0.025
@export var planet_start_scale: float = 2.4

@onready var logo_root: Control = $LogoRoot
@onready var sun: ColorRect = $LogoRoot/Sun
@onready var planet_1: ColorRect = $LogoRoot/Planet1
@onready var planet_2: ColorRect = $LogoRoot/Planet2
@onready var planet_3: ColorRect = $LogoRoot/Planet3
@onready var planet_4: ColorRect = $LogoRoot/Planet4
@onready var planet_5: ColorRect = $LogoRoot/Planet5
@onready var final_logo: TextureRect = $LogoRoot/FinalLogo

@onready var title: Label = $Title

var changing_scene := false

var planets: Array[ColorRect] = []
var logo_final_center: Vector2
var title_final_position: Vector2

var text_float_enabled := false
var logo_float_enabled := false

var _has_saved_session := false
var _startup_preload_started := false
var _startup_preload_done := false
var _startup_preload_success := false

var planet_targets := [
	Vector2(-255.55, 78.78),
	Vector2(80, 176),
	Vector2(269, -99),
	Vector2(-95, -191.5),
	Vector2(90.6, -125.127),
]

var planet_sizes := [
	Vector2(100.1558, 102.3096),
	Vector2(89.4692, 89.4692),
	Vector2(63.8686, 65.2421),
	Vector2(70.1407, 71.6491),
	Vector2(42.4319, 43.3445),
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)

	RenderingServer.set_default_clear_color(Color("#050712"))

	_has_saved_session = FirebaseAuth.load_session()

	if _has_saved_session:
		_start_preloading_app_data()

	SpaceBackground.set_navigation_enabled(false)
	SpaceBackground.travel_speed_multiplier = 0.0
	SpaceBackground.set_space_position(Vector2.ZERO)
	SpaceBackground.set_space_zoom(0.75, get_viewport_rect().size * 0.5)

	SpaceBackground.set_space_reveal(0.0)
	SpaceBackground.set_nebula_reveal(0.0)
	SpaceBackground.star_reveal = 0.0

	_setup_logo_and_title()
	_play_intro()


func _start_preloading_app_data() -> void:
	if _startup_preload_started:
		return

	_startup_preload_started = true
	_startup_preload_done = false
	_startup_preload_success = false

	_preload_app_data()

func _preload_app_data() -> void:
	if not has_node("/root/PlanetCardsCache"):
		print("PlanetCardsCache autoload missing.")
		_startup_preload_done = true
		_startup_preload_success = false
		return

	var cards: Array[PlanetData] = await PlanetCardsCache.ensure_loaded()

	if cards.is_empty():
		print("Startup preload finished, but no planet cards were found.")

	_startup_preload_done = true
	_startup_preload_success = true


func _reset_control(node: Control) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	node.set_offsets_preset(Control.PRESET_TOP_LEFT)
	node.position = Vector2.ZERO
	node.rotation = 0.0
	node.scale = Vector2.ONE


func _setup_logo_and_title() -> void:
	var screen_size := get_viewport_rect().size

	_reset_control(logo_root)
	logo_root.size = logo_size
	logo_root.pivot_offset = logo_root.size * 0.5
	logo_root.modulate.a = 1.0

	logo_final_center = Vector2(
		screen_size.x * 0.5,
		screen_size.y * logo_vertical_ratio + global_down_shift
	)

	logo_root.position = logo_final_center

	_reset_control(final_logo)
	final_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	final_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	final_logo.size = logo_size
	final_logo.position = -logo_size * 0.5
	final_logo.pivot_offset = logo_size * 0.5
	final_logo.modulate.a = 0.0
	final_logo.visible = true
	final_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_root.move_child(final_logo, 0)

	_reset_control(sun)
	sun.size = Vector2(204, 204)
	sun.pivot_offset = sun.size * 0.5
	sun.position = -sun.size * 0.5
	sun.scale = Vector2(0.65, 0.65)
	sun.modulate.a = 0.0
	sun.mouse_filter = Control.MOUSE_FILTER_IGNORE

	planets = [planet_1, planet_2, planet_3, planet_4, planet_5]

	for i in planets.size():
		var p := planets[i]
		_reset_control(p)
		p.size = planet_sizes[i]
		p.pivot_offset = p.size * 0.5
		p.position = -p.size * 0.5
		p.scale = Vector2.ONE * planet_start_scale
		p.modulate.a = 0.0
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_reset_control(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var font := title.get_theme_font("font")
	var fs := title.get_theme_font_size("font_size")
	var text_size := font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, fs)

	title.size = Vector2(screen_size.x, text_size.y + 10.0)
	title.pivot_offset = title.size * 0.5

	var visible_logo_height := logo_size.y * 0.2

	title_final_position = Vector2(
		0.0,
		logo_final_center.y + (visible_logo_height * 0.5) + title_gap
	)

	title.position = title_final_position + Vector2(0.0, 28.0)
	title.modulate = Color(1, 1, 1, 0)


func _play_intro() -> void:
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_OUT)

	SpaceBackground.intro_reveal(t)

	t.tween_interval(0.08)

	t.tween_property(sun, "modulate:a", 1.0, 0.35)
	t.parallel().tween_property(sun, "scale", Vector2(1.08, 1.08), 0.45)
	t.tween_property(sun, "scale", Vector2.ONE, 0.28)

	for i in planets.size():
		_animate_planet_orbit(t, planets[i], planet_targets[i], i * planet_intro_stagger)

	t.tween_interval(planet_intro_duration * 0.75)

	t.tween_property(final_logo, "modulate:a", 1.0, 0.55)
	t.parallel().tween_property(title, "modulate:a", 1.0, 0.55)
	t.parallel().tween_property(title, "position", title_final_position, 0.65)

	t.tween_interval((planet_intro_duration * 0.25) + 0.2)

	t.tween_callback(func():
		text_float_enabled = true
		logo_float_enabled = true
	)

	t.tween_interval(splash_duration * 0.3)

	t.tween_callback(func():
		text_float_enabled = false
		logo_float_enabled = false
		changing_scene = true
		logo_root.position = logo_final_center
		title.position = title_final_position
	)

	t.tween_property(logo_root, "modulate:a", 0.0, logo_fade_duration)
	t.parallel().tween_property(title, "modulate:a", 0.0, logo_fade_duration)

	t.tween_callback(_go_next)


func _animate_planet_orbit(tween: Tween, planet: Control, target_offset: Vector2, delay: float) -> void:
	var screen_size := get_viewport_rect().size

	var rotated := _rotate(target_offset, 72.0)

	var target_angle := atan2(rotated.y, rotated.x)
	var target_radius := rotated.length()

	var side := -1.0
	if target_offset.x >= 0.0:
		side = 1.0

	var start_angle := target_angle - side * TAU * 0.65
	var start_radius: float = max(screen_size.x, screen_size.y) * 0.75

	planet.position = Vector2(cos(start_angle), sin(start_angle)) * start_radius - planet.size * 0.5
	planet.scale = Vector2.ONE * planet_start_scale
	planet.modulate.a = 0.0
	planet.rotation = side * 0.45

	tween.parallel().tween_interval(delay).finished.connect(func():
		var local := create_tween()
		local.set_trans(Tween.TRANS_SINE)
		local.set_ease(Tween.EASE_OUT)

		local.tween_property(planet, "modulate:a", 1.0, 0.35)

		local.parallel().tween_method(
			func(v: float) -> void:
				var eased := _ease_out_cubic(v)

				var angle: float = lerp(start_angle, target_angle + side * TAU * 0.08, eased)
				var radius: float = lerp(start_radius, target_radius * 1.08, eased)
				var depth_push := sin(v * PI) * 45.0

				planet.position = Vector2(
					cos(angle) * radius,
					sin(angle) * radius + depth_push
				) - planet.size * 0.5

				planet.scale = Vector2.ONE * lerp(planet_start_scale, 0.92, eased)
				planet.rotation = lerp(side * 0.45, -side * 0.08, eased),
			0.0,
			1.0,
			planet_intro_duration * 0.75
		)

		local.tween_method(
			func(v: float) -> void:
				var eased := _ease_out_cubic(v)

				var angle: float = lerp(target_angle + side * TAU * 0.08, target_angle, eased)
				var radius: float = lerp(target_radius * 1.08, target_radius, eased)

				planet.position = Vector2(cos(angle), sin(angle)) * radius - planet.size * 0.5
				planet.scale = Vector2.ONE
				planet.rotation = lerp(-side * 0.08, 0.0, eased),
			0.0,
			1.0,
			planet_intro_duration * 0.25
		)
	)


func _ease_out_cubic(v: float) -> float:
	return 1.0 - pow(1.0 - v, 3.0)


func _process(_delta: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0

	if logo_float_enabled and not changing_scene:
		logo_root.position = logo_final_center + Vector2(
			sin(time * 0.5) * 1.0,
			cos(time * 0.4) * 1.2
		)

	if text_float_enabled and not changing_scene:
		title.position = title_final_position + Vector2(
			sin(time * 0.5) * 0.8,
			cos(time * 0.4) * 1.0
		)


func _go_next() -> void:
	if _has_saved_session:
		if _startup_preload_started and not _startup_preload_done:
			await _wait_for_startup_preload()

		get_tree().change_scene_to_file("res://app/content/AppContentScreen.tscn")
	else:
		get_tree().change_scene_to_file("res://app/auth/LoginScreen.tscn")


func _wait_for_startup_preload() -> void:
	while not _startup_preload_done:
		await get_tree().process_frame


func _rotate(v: Vector2, deg: float) -> Vector2:
	var r := deg_to_rad(deg)
	return Vector2(
		v.x * cos(r) - v.y * sin(r),
		v.x * sin(r) + v.y * cos(r)
	)

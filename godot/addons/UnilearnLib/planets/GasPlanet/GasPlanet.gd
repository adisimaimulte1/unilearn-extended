extends "res://addons/UnilearnLib/planets/Planet.gd"

func set_pixels(amount):
	$Cloud.material.set_shader_parameter("pixels", amount)
	$Cloud2.material.set_shader_parameter("pixels", amount)

	# Keep the shader circle centered on this planet node's origin.
	# Without this, the wrapper centers the ColorRect bounds, but the rendered gas
	# giant can appear shifted against the debug border on mobile.
	var body_size := Vector2(amount, amount)
	var body_offset := -body_size * 0.5

	size = body_size
	pivot_offset = Vector2.ZERO

	$Cloud.position = body_offset
	$Cloud2.position = body_offset
	$Cloud.size = body_size
	$Cloud2.size = body_size

func set_light(pos):
	$Cloud.material.set_shader_parameter("light_origin", pos)
	$Cloud2.material.set_shader_parameter("light_origin", pos)

func set_seed(sd):
	var converted_seed = sd%1000/100.0
	$Cloud.material.set_shader_parameter("seed", converted_seed)
	$Cloud2.material.set_shader_parameter("seed", converted_seed)
	$Cloud2.material.set_shader_parameter("cloud_cover", randf_range(0.28, 0.5))

func set_rotates(r):
	$Cloud.material.set_shader_parameter("rotation", r)
	$Cloud2.material.set_shader_parameter("rotation", r)
	
func update_time(t):
	$Cloud.material.set_shader_parameter("time", t * get_multiplier($Cloud.material) * 0.005)
	$Cloud2.material.set_shader_parameter("time", t * get_multiplier($Cloud2.material) * 0.005)
	
func set_custom_time(t):
	$Cloud.material.set_shader_parameter("time", t * get_multiplier($Cloud.material))
	$Cloud2.material.set_shader_parameter("time", t * get_multiplier($Cloud2.material))

func get_colors():
	return get_colors_from_shader($Cloud.material) + get_colors_from_shader($Cloud2.material)

func set_colors(colors):
	set_colors_on_shader($Cloud.material, colors.slice(0, 4))
	set_colors_on_shader($Cloud2.material, colors.slice(4, 8))

func randomize_colors():
	var seed_colors = _generate_new_colorscheme(8 + randi()%4, randf_range(0.3, 0.8), 1.0)
	var cols1= []
	var cols2= []
	for i in 4:
		var new_col = seed_colors[i].darkened(i/6.0).darkened(0.7)
#		new_col = new_col.lightened((1.0 - (i/4.0)) * 0.2)
		cols1.append(new_col)
	
	for i in 4:
		var new_col = seed_colors[i+4].darkened(i/4.0)
		new_col = new_col.lightened((1.0 - (i/4.0)) * 0.5)
		cols2.append(new_col)

	set_colors(cols1 + cols2)

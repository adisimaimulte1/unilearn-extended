extends "res://addons/UnilearnLib/planets/Planet.gd"

var accretion_disk_enabled := true

func set_accretion_disk_enabled(value: bool) -> void:
	accretion_disk_enabled = value
	if has_node("Disk"):
		$Disk.visible = value


func set_pixels(amount):
	amount = max(amount, 24)
	$BlackHole.material.set_shader_parameter("pixels", amount)
	$Disk.material.set_shader_parameter("pixels", amount * 3.0)

	$BlackHole.position = Vector2.ZERO
	$BlackHole.size = Vector2(amount, amount)
	$Disk.position = Vector2(-amount, -amount)
	$Disk.size = Vector2(amount, amount) * 3.0
	set_accretion_disk_enabled(accretion_disk_enabled)

func set_light(_pos):
	pass

func set_seed(sd):
	var converted_seed = sd%1000/100.0
	$Disk.material.set_shader_parameter("seed", converted_seed)

func set_rotates(r):
	$Disk.material.set_shader_parameter("rotation", r+0.7)

func update_time(t):
	$Disk.material.set_shader_parameter("time", t * 314.15 * 0.004 )

func set_custom_time(t):
	$Disk.material.set_shader_parameter("time", t * 314.15 * $Disk.material.get_shader_parameter("time_speed") * 0.5)

func set_dither(d):
	$Disk.material.set_shader_parameter("should_dither", d)

func get_dither():
	return $Disk.material.get_shader_parameter("should_dither")

func get_colors():
	return get_colors_from_shader($BlackHole.material) + get_colors_from_shader($Disk.material)

func set_colors(colors):
	var cols1 = colors.slice(0, 3)
	var cols2 = colors.slice(3, 8)
	set_colors_on_shader($BlackHole.material, cols1)
	set_colors_on_shader($Disk.material, cols2)

func randomize_colors():
	set_colors(PackedColorArray([
		Color("#000000"),
		Color("#f6f3e8"),
		Color("#ffffff"),
		Color("#050203"),
		Color("#5a1208"),
		Color("#c84d14"),
		Color("#ffb029"),
		Color("#fff0a6"),
	]))

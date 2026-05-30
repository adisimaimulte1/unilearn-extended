extends Control
class_name UnilearnAchievementIcon

var achievement_id := "achievement"
var tier := 0
var tier_color := Color(1, 1, 1, 0.35)

func setup(id: String, tier_value: int, color: Color) -> void:
	achievement_id = id
	tier = tier_value
	tier_color = color
	queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(104, 104)

func _draw() -> void:
	var side: float = min(size.x, size.y)
	var center := size * 0.5
	var radius := side * 0.42
	var active := tier > 0
	var main_color := tier_color if active else Color(1, 1, 1, 0.60)
	var white := Color.WHITE if active else Color(1, 1, 1, 0.55)

	var hash_value: int = abs(hash(achievement_id))
	var points := 5 + int(hash_value % 4)
	var inner := radius * (0.30 + float((hash_value >> 4) % 18) / 100.0)
	var outer := radius * 0.74
	var poly := PackedVector2Array()

	for i in range(points * 2):
		var angle := -PI * 0.5 + (TAU * float(i) / float(points * 2))
		var r := outer if i % 2 == 0 else inner
		poly.append(center + Vector2(cos(angle), sin(angle)) * r)

	draw_colored_polygon(poly, main_color)

	var inner_ring_radius := radius * 0.25
	draw_arc(center, inner_ring_radius, 0.0, TAU, 64, white, 3.0, true)

	if active:
		draw_line(center + Vector2(-radius * 0.42, radius * 0.46), center + Vector2(radius * 0.42, radius * 0.46), white, 3.0, true)

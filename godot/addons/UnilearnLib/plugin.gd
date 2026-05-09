@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_custom_type(
		"UnilearnPixelPlanet2D",
		"Node2D",
		preload("res://addons/UnilearnLib/nodes/UnilearnPixelPlanet2D.gd"),
		null
	)

func _exit_tree() -> void:
	remove_custom_type("UnilearnPixelPlanet2D")

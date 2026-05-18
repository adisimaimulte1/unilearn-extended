extends Node
class_name GalaxyPopupUsageBridge

const GALAXY_POPUP_SCENE_PATH := "res://app/ui/popups/galaxy_popup/GalaxyPopup.tscn"

static func open_popup(parent: Node, config: SimulationPhysicsConfig, system_objects: Array, reduce_motion_enabled: bool = false) -> CanvasLayer:
	if parent == null:
		return null

	var state_node := parent.get_node_or_null("/root/UnilearnGalaxyState")
	if state_node != null and state_node.has_method("apply_to_config"):
		state_node.apply_to_config(config)

	var popup_scene := load(GALAXY_POPUP_SCENE_PATH) as PackedScene
	if popup_scene == null:
		push_error("Missing galaxy popup scene: " + GALAXY_POPUP_SCENE_PATH)
		return null

	var popup := popup_scene.instantiate() as CanvasLayer
	parent.add_child(popup)

	if popup.has_method("setup"):
		popup.setup(config, reduce_motion_enabled, system_objects)

	if popup.has_signal("config_value_changed"):
		popup.config_value_changed.connect(func(property_name: String, value) -> void:
			if state_node != null and state_node.has_method("set_config_value"):
				state_node.set_config_value(property_name, value, true)
		)

	if popup.has_signal("closed"):
		popup.closed.connect(func() -> void:
			if state_node != null and state_node.has_method("capture_runtime"):
				state_node.capture_runtime(system_objects, config, true)
		)

	return popup

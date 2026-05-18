extends Node
class_name GalaxyPopupUsageBridge

const GALAXY_POPUP_SCRIPT := preload("res://app/ui/popups/UnilearnGalaxyPopup.gd")

static func open_popup(parent: Node, config: SimulationPhysicsConfig, system_objects: Array, reduce_motion_enabled: bool = false) -> CanvasLayer:
	if parent == null:
		return null

	var state_node := parent.get_node_or_null("/root/GalaxyState")
	if config == null:
		config = SimulationPhysicsConfig.new()

	if state_node != null:
		if state_node.has_method("load_into"):
			config = state_node.call("load_into", config)
		elif state_node.has_method("get_config"):
			config = state_node.call("get_config")

	var popup := GALAXY_POPUP_SCRIPT.new()
	popup.name = "UnilearnGalaxyPopup"

	if popup.has_method("setup"):
		popup.setup(config, reduce_motion_enabled, system_objects)

	parent.add_child(popup)

	if popup.has_signal("config_value_changed"):
		popup.config_value_changed.connect(func(property_name: String, value) -> void:
			if state_node != null and state_node.has_method("set_config_value"):
				state_node.set_config_value(property_name, value, true)
		)

	if popup.has_signal("closed"):
		popup.closed.connect(func() -> void:
			if state_node != null and state_node.has_method("replace_config"):
				state_node.replace_config(config, true)
		)

	return popup

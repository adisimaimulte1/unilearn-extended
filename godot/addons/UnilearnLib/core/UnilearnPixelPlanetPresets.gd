extends RefCounted
class_name UnilearnPixelPlanetPresets

const PRESETS := {
	"rivers": "res://addons/UnilearnLib/vendor/Planets/Rivers/Rivers.tscn",
	"dry_terran": "res://addons/UnilearnLib/vendor/Planets/DryTerran/DryTerran.tscn",
	"earth": "res://addons/UnilearnLib/vendor/Planets/LandMasses/LandMasses.tscn",
	"islands": "res://addons/UnilearnLib/vendor/Planets/LandMasses/LandMasses.tscn",
	"moon": "res://addons/UnilearnLib/vendor/Planets/NoAtmosphere/NoAtmosphere.tscn",
	"no_atmosphere": "res://addons/UnilearnLib/vendor/Planets/NoAtmosphere/NoAtmosphere.tscn",
	"gas_planet": "res://addons/UnilearnLib/vendor/Planets/GasPlanet/GasPlanet.tscn",
	"ringed_gas_planet": "res://addons/UnilearnLib/vendor/Planets/GasPlanetLayers/GasPlanetLayers.tscn",
	"gas_layers": "res://addons/UnilearnLib/vendor/Planets/GasPlanetLayers/GasPlanetLayers.tscn",
	"ice_world": "res://addons/UnilearnLib/vendor/Planets/IceWorld/IceWorld.tscn",
	"lava_world": "res://addons/UnilearnLib/vendor/Planets/LavaWorld/LavaWorld.tscn",
	"black_hole": "res://addons/UnilearnLib/vendor/Planets/BlackHole/BlackHole.tscn",
	"galaxy": "res://addons/UnilearnLib/vendor/Planets/Galaxy/Galaxy.tscn",
	"star": "res://addons/UnilearnLib/vendor/Planets/Star/Star.tscn",
}

static func normalize_name(value: String) -> String:
	var key := value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	match key:
		"islands", "island":
			return "islands"
		"earth", "terra", "land", "land_masses":
			return "earth"
		"river", "rivers", "terran_wet", "wet_terran", "earth_rivers":
			return "rivers"
		"mars", "dry", "dry_terran", "desert", "terran_dry":
			return "dry_terran"
		"ice", "ice_world", "uranus", "neptune":
			return "ice_world"
		"moon", "luna", "no_atmosphere", "mercury":
			return "moon"
		"lava", "lava_world":
			return "lava_world"
		"gas", "gas_planet", "jupiter", "gas_giant_1":
			return "gas_planet"
		"saturn", "ringed", "ringed_gas_planet", "gas_layers", "gas_giant_2":
			return "ringed_gas_planet"
		"sun", "star":
			return "star"
		"black_hole", "blackhole":
			return "black_hole"
		"galaxy":
			return "galaxy"
		_:
			return "earth"

static func get_scene_path(value: String) -> String:
	var key := normalize_name(value)
	return PRESETS.get(key, PRESETS["earth"])

static func get_names() -> PackedStringArray:
	return PackedStringArray(PRESETS.keys())

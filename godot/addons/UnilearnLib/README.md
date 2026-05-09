# UnilearnLib Pixel Planets

Self-contained Godot 4 addon wrapping Deep-Fold's Pixel Planet Generator source.

## Install

Copy `addons/UnilearnLib` into your Godot project and enable it from:
`Project > Project Settings > Plugins > UnilearnLib`.

## Important paths

- Main node: `res://addons/UnilearnLib/nodes/UnilearnPixelPlanet2D.gd`
- Preset registry: `res://addons/UnilearnLib/core/UnilearnPixelPlanetPresets.gd`
- Original source kept mostly intact: `res://addons/UnilearnLib/vendor/`
- Test scene: `res://addons/UnilearnLib/examples/PlanetTestScene.tscn`

## Removed

Asteroid preset and asteroid source folder were removed.

## Presets

`earth`, `rivers`, `dry_terran`, `moon`, `gas_planet`, `ringed_gas_planet`, `ice_world`, `lava_world`, `black_hole`, `galaxy`, `star`

## Wrapper API

The wrapper exposes common parameters directly: `preset`, `radius_px`, `render_pixels`, `seed`, `spin_speed`, `axial_tilt_deg`, `should_dither`, `light_angle_deg`, `light_distance`, `light_softness`, `light_intensity`.

For lower-level control, use:

- `get_planet_node()`
- `get_layers()`
- `toggle_layer(index)`
- `set_layer_visible(index, visible)`
- `get_colors()` / `set_colors(colors)`
- `randomize_colors()`
- `get_shader_parameter_dump()`
- `set_shader_parameter_on_layer(layer_name, parameter_name, value)`

`render_pixels` defaults higher than the original generator so planets look less chunky.

extends RefCounted
class_name PlanetDataLibrary


static func get_all_planets() -> Array[PlanetData]:
	return [
		_sun(),
		_mercury(),
		_venus(),
		_earth(),
		_mars(),
		_jupiter(),
		_saturn(),
		_uranus(),
		_neptune(),
	]


static func get_planet_by_id(instance_id: String) -> PlanetData:
	for planet in get_all_planets():
		if planet.instance_id == instance_id:
			return planet

	return get_all_planets()[0]


static func _base(
	instance_id: String,
	name: String,
	subtitle: String,
	description: String,
	archetype_id: String,
	preset: String,
	seed: int
) -> PlanetData:
	var p := PlanetData.new()

	p.instance_id = instance_id
	p.archetype_id = archetype_id
	p.name = name
	p.subtitle = subtitle
	p.description = description
	p.planet_preset = preset
	p.planet_seed = seed
	p.planet_pixels = 480
	p.planet_radius_px = 142
	p.planet_turning_speed = 1.0
	p.planet_axial_tilt_deg = 0.0
	p.planet_ring_angle_deg = 0.0

	return p


static func _apply_colors(p: PlanetData, colors: PackedColorArray) -> PlanetData:
	p.use_custom_colors = true
	p.custom_colors = colors
	return p


static func _sun() -> PlanetData:
	var p := _base(
		"sun",
		"Sun",
		"The star at the center",
		"The Sun is the star at the center of the Solar System. Its gravity holds the planets in orbit, and nuclear fusion in its core releases the light and heat that make Earth habitable.",
		"star",
		"star",
		694201337
	)

	p.diameter_km = "1,392,700 km"
	p.mass = "1.989 × 10³⁰ kg"
	p.orbital_period = "Around the Milky Way: ~230 million years"
	p.rotation_period = "Equator: ~25 days; poles: ~35 days"
	p.average_temperature = "Surface: ~5,500 °C"
	p.gravity = "274 m/s²"
	p.moons = "0"
	p.distance_from_sun = "0 km"

	p.key_features = [
		{"title": "Solar System anchor", "text": "The Sun contains more than 99% of the Solar System’s mass."},
		{"title": "Nuclear fusion", "text": "Hydrogen fuses into helium in the core, releasing enormous energy."},
		{"title": "Light travel time", "text": "Sunlight takes about 8 minutes and 20 seconds to reach Earth."},
		{"title": "Solar activity", "text": "Sunspots, flares, and solar wind can affect satellites and power grids."},
	]

	p.fun_fact_title = "Did you know?"
	p.fun_fact = "About 1.3 million Earths could fit inside the Sun by volume."
	p.quiz_text = "Test what you learned about the Sun."
	p.compare_text = "Compare the Sun with planets and other stars."
	p.missions_text = "Explore missions like SOHO, STEREO, Parker Solar Probe, and Solar Orbiter."

	p.planet_radius_px = 188
	p.planet_turning_speed = 0.34
	p.planet_axial_tilt_deg = 7.25

	return _apply_colors(p, PackedColorArray([
		Color("#fff8c6"),
		Color("#ffd45c"),
		Color("#ff9a1f"),
		Color("#ff5d00"),
		Color("#c92f00"),
		Color("#ffffff"),
		Color("#ffd45c"),
		Color("#fff8c6"),
		Color("#ff9a1f"),
		Color("#ffffff"),
	]))


static func _mercury() -> PlanetData:
	var p := _base(
		"mercury",
		"Mercury",
		"The scorched crater world",
		"Mercury is the closest planet to the Sun and the smallest planet in the Solar System. It has almost no atmosphere, so its surface heats up and cools down extremely fast.",
		"rocky",
		"no_atmosphere",
		37819421
	)

	p.diameter_km = "4,879 km"
	p.mass = "3.301 × 10²³ kg"
	p.orbital_period = "88.0 Earth days"
	p.rotation_period = "58.6 Earth days"
	p.average_temperature = "167 °C"
	p.gravity = "3.7 m/s²"
	p.moons = "0"
	p.distance_from_sun = "57.9 million km"

	p.key_features = [
		{"title": "Closest to the Sun", "text": "Mercury orbits the Sun faster than any other planet."},
		{"title": "Extreme temperatures", "text": "Its thin exosphere cannot trap heat."},
		{"title": "Cratered surface", "text": "Mercury is covered with impact craters and ancient lava plains."},
	]

	p.fun_fact_title = "Did you know?"
	p.fun_fact = "A year on Mercury lasts only 88 Earth days, but one solar day lasts about 176 Earth days."
	p.quiz_text = "Test what you learned about Mercury."
	p.compare_text = "Compare Mercury with Earth and the Moon."
	p.missions_text = "Explore missions like Mariner 10, MESSENGER, and BepiColombo."

	p.planet_radius_px = 116
	p.planet_turning_speed = 0.72
	p.planet_axial_tilt_deg = 0.03

	return _apply_colors(p, PackedColorArray([
		Color("#b9b2a8"),
		Color("#918b83"),
		Color("#6d6861"),
		Color("#d7cfc0"),
		Color("#3f3b36"),
	]))


static func _venus() -> PlanetData:
	var p := _base(
		"venus",
		"Venus",
		"Earth’s cloudy furnace",
		"Venus is similar in size to Earth, but its thick carbon dioxide atmosphere creates a runaway greenhouse effect, making it the hottest planet in the Solar System.",
		"rocky",
		"terran_dry",
		84726109
	)

	p.diameter_km = "12,104 km"
	p.mass = "4.867 × 10²⁴ kg"
	p.orbital_period = "224.7 Earth days"
	p.rotation_period = "243 Earth days, retrograde"
	p.average_temperature = "464 °C"
	p.gravity = "8.87 m/s²"
	p.moons = "0"
	p.distance_from_sun = "108.2 million km"

	p.key_features = [
		{"title": "Hottest planet", "text": "Venus is hotter than Mercury because its dense atmosphere traps heat."},
		{"title": "Sulfuric clouds", "text": "Its upper atmosphere is covered by bright sulfuric acid clouds."},
		{"title": "Retrograde rotation", "text": "Venus spins in the opposite direction to most planets."},
	]

	p.fun_fact_title = "Did you know?"
	p.fun_fact = "On Venus, the Sun would appear to rise in the west and set in the east."
	p.quiz_text = "Test what you learned about Venus."
	p.compare_text = "Compare Venus with Earth’s size, mass, and atmosphere."
	p.missions_text = "Explore missions like Venera, Magellan, Venus Express, and Akatsuki."

	p.planet_radius_px = 138
	p.planet_turning_speed = -0.22
	p.planet_axial_tilt_deg = 177.4

	return _apply_colors(p, PackedColorArray([
		Color("#fff2be"),
		Color("#f0cf82"),
		Color("#d8a75b"),
		Color("#b87b43"),
		Color("#8d552f"),
	]))


static func _earth() -> PlanetData:
	var p := _base(
		"earth",
		"Earth",
		"Our living ocean world",
		"Earth is the only planet known to support life. Its liquid water, protective atmosphere, magnetic field, and active climate systems make it unique in the Solar System.",
		"rocky",
		"terran_wet",
		2880143960
	)

	p.diameter_km = "12,742 km"
	p.mass = "5.972 × 10²⁴ kg"
	p.orbital_period = "365.25 days"
	p.rotation_period = "23h 56m"
	p.average_temperature = "15 °C"
	p.gravity = "9.81 m/s²"
	p.moons = "1"
	p.distance_from_sun = "149.6 million km"

	p.key_features = [
		{"title": "Liquid water", "text": "Most of Earth’s surface is covered by oceans."},
		{"title": "Protective atmosphere", "text": "The atmosphere blocks harmful radiation and supports life."},
		{"title": "Magnetic field", "text": "Earth’s magnetic field helps protect it from solar wind."},
	]

	p.fun_fact_title = "Did you know?"
	p.fun_fact = "Earth is not a perfect sphere. It is slightly wider at the equator because of its rotation."
	p.quiz_text = "Test what you learned about Earth."
	p.compare_text = "Compare Earth with rocky and gas planets."
	p.missions_text = "Explore Earth observation missions and satellites."

	p.planet_radius_px = 142
	p.planet_turning_speed = 1.0
	p.planet_axial_tilt_deg = 23.44

	return _apply_colors(p, PackedColorArray([
		Color("#2f77c8"),
		Color("#174c87"),
		Color("#1e7a4c"),
		Color("#78b957"),
		Color("#f2f1df"),
		Color("#082847"),
	]))


static func _mars() -> PlanetData:
	var p := _base(
		"mars",
		"Mars",
		"The rusty desert planet",
		"Mars is a cold desert world with iron-rich dust, polar ice caps, huge volcanoes, and signs that liquid water existed on its surface in the ancient past.",
		"rocky",
		"terran_dry",
		52938471
	)

	p.diameter_km = "6,779 km"
	p.mass = "6.417 × 10²³ kg"
	p.orbital_period = "687.0 Earth days"
	p.rotation_period = "24h 37m"
	p.average_temperature = "-63 °C"
	p.gravity = "3.71 m/s²"
	p.moons = "2"
	p.distance_from_sun = "227.9 million km"

	p.key_features = [
		{"title": "Red surface", "text": "Iron oxide dust gives Mars its reddish color."},
		{"title": "Olympus Mons", "text": "Mars has the tallest volcano known in the Solar System."},
		{"title": "Ancient water", "text": "Valleys and minerals show evidence of past water flow."},
	]

	p.fun_fact_title = "Did you know?"
	p.fun_fact = "Mars has seasons like Earth because its axis is tilted."
	p.quiz_text = "Test what you learned about Mars."
	p.compare_text = "Compare Mars with Earth and the Moon."
	p.missions_text = "Explore missions like Viking, Curiosity, Perseverance, and Ingenuity."

	p.planet_radius_px = 124
	p.planet_turning_speed = 0.97
	p.planet_axial_tilt_deg = 25.19

	return _apply_colors(p, PackedColorArray([
		Color("#d77745"),
		Color("#b24f32"),
		Color("#7b3429"),
		Color("#e49b67"),
		Color("#4f241d"),
	]))


static func _jupiter() -> PlanetData:
	var p := _base(
		"jupiter",
		"Jupiter",
		"The storm-striped giant",
		"Jupiter is the largest planet in the Solar System. It is a gas giant made mostly of hydrogen and helium, famous for its cloud bands and the Great Red Spot.",
		"gas_giant",
		"gas_giant_1",
		76219384
	)

	p.diameter_km = "139,820 km"
	p.mass = "1.898 × 10²⁷ kg"
	p.orbital_period = "11.86 Earth years"
	p.rotation_period = "9h 56m"
	p.average_temperature = "-108 °C"
	p.gravity = "24.79 m/s²"
	p.moons = "101"
	p.distance_from_sun = "778.5 million km"

	p.key_features = [
		{"title": "Largest planet", "text": "Jupiter is over 11 times wider than Earth."},
		{"title": "Great Red Spot", "text": "A giant storm that has lasted for hundreds of years."},
		{"title": "Strong magnetic field", "text": "Jupiter has the strongest planetary magnetic field in the Solar System."},
		{"title": "Many moons", "text": "Its moons include Ganymede, the largest moon in the Solar System."},
	]

	p.fun_fact_title = "Did you know?"
	p.fun_fact = "Jupiter spins so fast that its day is less than 10 hours long."
	p.quiz_text = "Test what you learned about Jupiter."
	p.compare_text = "Compare Jupiter with Earth and the other gas giants."
	p.missions_text = "Explore missions like Pioneer, Voyager, Galileo, Juno, Europa Clipper, and JUICE."

	p.planet_radius_px = 168
	p.planet_turning_speed = 1.45
	p.planet_axial_tilt_deg = 3.13

	return _apply_colors(p, PackedColorArray([
		Color("#f6e3c4"),
		Color("#d8aa72"),
		Color("#a8693f"),
		Color("#7c4a35"),
		Color("#fff3dd"),
	]))


static func _saturn() -> PlanetData:
	var p := _base(
		"saturn",
		"Saturn",
		"The golden ringed giant",
		"Saturn is a gas giant best known for its bright ring system. Its rings are made mostly of ice particles, rocky debris, and dust.",
		"ringed_gas_giant",
		"gas_giant_2",
		61390275
	)

	p.diameter_km = "116,460 km"
	p.mass = "5.683 × 10²⁶ kg"
	p.orbital_period = "29.45 Earth years"
	p.rotation_period = "10h 33m"
	p.average_temperature = "-139 °C"
	p.gravity = "10.44 m/s²"
	p.moons = "285+"
	p.distance_from_sun = "1.43 billion km"

	p.key_features = [
		{"title": "Iconic rings", "text": "Saturn’s rings stretch far from the planet but are very thin."},
		{"title": "Gas giant", "text": "It is made mostly of hydrogen and helium."},
		{"title": "Low density", "text": "Saturn is less dense than water."},
		{"title": "Titan", "text": "Titan is a large moon with a thick atmosphere."},
	]

	p.fun_fact_title = "Did you know?"
	p.fun_fact = "Saturn’s rings are not solid. They are countless separate particles orbiting the planet."
	p.quiz_text = "Test what you learned about Saturn."
	p.compare_text = "Compare Saturn with Jupiter."
	p.missions_text = "Explore missions like Pioneer 11, Voyager, and Cassini-Huygens."

	p.planet_radius_px = 158
	p.planet_turning_speed = 1.2
	p.planet_axial_tilt_deg = 26.73
	p.planet_ring_angle_deg = 26.73

	return _apply_colors(p, PackedColorArray([
		Color("#f2dfad"),
		Color("#d6b978"),
		Color("#b48f52"),
		Color("#8b6b3f"),
		Color("#fff0c2"),
		Color("#c9a264"),
	]))


static func _uranus() -> PlanetData:
	var p := _base(
		"uranus",
		"Uranus",
		"The sideways ice giant",
		"Uranus is an ice giant with a pale blue-green color caused by methane in its atmosphere. It rotates almost on its side, making it one of the strangest planets.",
		"ice_giant",
		"ice_world",
		90835162
	)

	p.diameter_km = "50,724 km"
	p.mass = "8.681 × 10²⁵ kg"
	p.orbital_period = "84.0 Earth years"
	p.rotation_period = "17h 14m, retrograde"
	p.average_temperature = "-197 °C"
	p.gravity = "8.69 m/s²"
	p.moons = "29"
	p.distance_from_sun = "2.87 billion km"

	p.key_features = [
		{"title": "Extreme tilt", "text": "Uranus rotates almost sideways compared with its orbit."},
		{"title": "Ice giant", "text": "It contains water, ammonia, and methane ices deep inside."},
		{"title": "Pale cyan color", "text": "Methane absorbs red light and gives Uranus its blue-green appearance."},
	]

	p.fun_fact_title = "Did you know?"
	p.fun_fact = "Because Uranus is tilted so much, its poles can face the Sun for decades."
	p.quiz_text = "Test what you learned about Uranus."
	p.compare_text = "Compare Uranus with Neptune."
	p.missions_text = "Voyager 2 is the only spacecraft to have visited Uranus. Webb discovered an additional small Uranian moon in 2025."

	p.planet_radius_px = 144
	p.planet_turning_speed = -0.62
	p.planet_axial_tilt_deg = 97.77
	p.planet_ring_angle_deg = 97.77

	return _apply_colors(p, PackedColorArray([
		Color("#dcffff"),
		Color("#b5f2f2"),
		Color("#83d7de"),
		Color("#5fb6c0"),
		Color("#347f8b"),
	]))


static func _neptune() -> PlanetData:
	var p := _base(
		"neptune",
		"Neptune",
		"The deep blue wind giant",
		"Neptune is the farthest known planet from the Sun. It is an ice giant with deep blue clouds and some of the fastest winds measured in the Solar System.",
		"ice_giant",
		"ice_world",
		43091827
	)

	p.diameter_km = "49,244 km"
	p.mass = "1.024 × 10²⁶ kg"
	p.orbital_period = "164.8 Earth years"
	p.rotation_period = "16h 6m"
	p.average_temperature = "-201 °C"
	p.gravity = "11.15 m/s²"
	p.moons = "16"
	p.distance_from_sun = "4.50 billion km"

	p.key_features = [
		{"title": "Fast winds", "text": "Neptune has winds that can exceed 2,000 km/h."},
		{"title": "Ice giant", "text": "Its interior contains icy materials under extreme pressure."},
		{"title": "Triton", "text": "Triton is Neptune’s largest moon and orbits backward."},
	]

	p.fun_fact_title = "Did you know?"
	p.fun_fact = "One Neptune year lasts almost 165 Earth years."
	p.quiz_text = "Test what you learned about Neptune."
	p.compare_text = "Compare Neptune with Uranus and Jupiter."
	p.missions_text = "Voyager 2 is the only spacecraft to have visited Neptune."

	p.planet_radius_px = 143
	p.planet_turning_speed = 0.85
	p.planet_axial_tilt_deg = 28.32

	return _apply_colors(p, PackedColorArray([
		Color("#2f57d8"),
		Color("#1f3fb3"),
		Color("#152b7a"),
		Color("#5c82ff"),
		Color("#0b1645"),
	]))

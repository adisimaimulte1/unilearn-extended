extends RefCounted
class_name PlanetDataLibrary


static func get_all_planets() -> Array[PlanetData]:
	return [
		_sun(),
		_mercury(),
		_venus(),
		_earth(),
		_moon(),
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
	seed: int,
	description_highlight_indices: PackedInt32Array = PackedInt32Array()
) -> PlanetData:
	var p := PlanetData.new()

	p.instance_id = instance_id
	p.archetype_id = archetype_id
	p.name = name
	p.subtitle = subtitle
	p.description = description
	p.description_highlight_indices = description_highlight_indices
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


static func _badge(title: String, value: String, color: String = "accent") -> Dictionary:
	return {
		"title": title,
		"value": value,
		"color": color,
	}


static func _score(title: String, value: int, color: String = "accent") -> Dictionary:
	return {
		"title": title,
		"value": clampi(value, 0, 100),
		"color": color,
	}


static func _apply_game_data(
	p: PlanetData,
	class_name_value: String,
	_stability: String,
	_orbit_skill: String,
	quiz_xp_reward: int,
	scores: Array,
	extra_badges: Array = []
) -> PlanetData:
	p.game_level = 1
	p.game_xp = 0
	p.game_xp_to_next = 100
	p.upgrade_quiz_xp_reward = clampi(quiz_xp_reward, 5, 250)


	p.attribute_badges = [
		_badge("Class", class_name_value, _class_color(class_name_value)),
	]

	for badge in extra_badges:
		if p.attribute_badges.size() >= 5:
			break

		if not badge is Dictionary:
			continue

		var title := String(badge.get("title", "")).strip_edges()

		if title.is_empty():
			continue

		if title.to_lower() == "class":
			continue

		p.attribute_badges.append({
			"title": title,
			"value": String(badge.get("value", "")).strip_edges(),
			"color": String(badge.get("color", "accent")).strip_edges(),
		})

	p.game_attribute_scores = _normalize_game_scores(scores)

	return p


static func _class_color(class_name_value: String) -> String:
	match class_name_value.to_lower():
		"stellar":
			return "yellow"
		"satellite":
			return "blue"
		_:
			return "accent"


static func _normalize_game_scores(scores: Array) -> Array:
	var fallback := [
		_score("Habitability", 50, "green"),
		_score("Magnetic Field", 50, "purple"),
		_score("Atmosphere", 50, "blue"),
		_score("Geology", 50, "orange"),
		_score("Gravity", 50, "accent"),
		_score("Radiation Safety", 50, "green"),
	]

	var by_title := {}

	for item in scores:
		if not item is Dictionary:
			continue

		var title := _normalize_score_title(String(item.get("title", "")))

		if title.is_empty():
			continue

		by_title[title] = _score(
			title,
			int(item.get("value", 50)),
			String(item.get("color", "accent"))
		)

	var result := []

	for fallback_item in fallback:
		var title := String(fallback_item["title"])

		if by_title.has(title):
			result.append(by_title[title])
		else:
			result.append(fallback_item)

	return result


static func _normalize_score_title(value: String) -> String:
	var raw := value.strip_edges().to_lower()

	if raw.contains("habit"):
		return "Habitability"
	if raw.contains("magnetic") or raw.contains("magnet"):
		return "Magnetic Field"
	if raw.contains("atmos"):
		return "Atmosphere"
	if raw.contains("geolog") or raw.contains("surface") or raw.contains("volcan"):
		return "Geology"
	if raw.contains("grav"):
		return "Gravity"
	if raw.contains("radiation") or raw.contains("safety"):
		return "Radiation Safety"

	return ""


static func _sun() -> PlanetData:
	var p := _base(
		"sun",
		"Sun",
		"The star that powers our system",
		"The Sun is a main-sequence star made mostly of hydrogen and helium. Its gravity organizes nearby worlds, while nuclear fusion in its core releases the energy that drives light, heat, climate, and space weather.",
		"star",
		"star",
		694201337,
		PackedInt32Array([1, 4, 8, 12, 13, 16, 20, 21, 28, 30])
	)

	p.object_category = "star"
	p.parent_object = "Milky Way"
	p.system_role = "Primary star and gravitational anchor of its planetary system."
	p.visual_signature = "Bright plasma surface, magnetic active regions, flares, prominences, and a glowing corona."
	p.composition = "Mostly hydrogen and helium plasma."
	p.atmosphere = "Layered stellar atmosphere: photosphere, chromosphere, transition region, and corona."
	p.surface_geology = "No solid surface; the visible layer is the photosphere."
	p.magnetic_field = "Powerful and constantly changing; it drives sunspots, solar flares, and coronal mass ejections."
	p.ring_system = "None."
	p.habitability_note = "Not habitable itself, but its stable energy output creates habitable-zone conditions around suitable planets."
	p.formation_note = "Formed about 4.6 billion years ago from a collapsing cloud of gas and dust."
	p.discovery_note = "Known since prehistory; studied with spectroscopy, helioseismology, eclipses, and space observatories."
	p.notable_extreme = "Contains more than 99% of the mass of its planetary system."
	p.exploration_status = "Observed by SOHO, STEREO, SDO, Parker Solar Probe, and Solar Orbiter."

	p.diameter_km = "1,392,700 km"
	p.mass = "1.989 × 10³⁰ kg"
	p.orbital_period = "Galactic orbit: ~230 million years"
	p.rotation_period = "Equator: ~25 days; poles: ~35 days"
	p.average_temperature = "Surface: ~5,500 °C"
	p.gravity = "274 m/s²"
	p.moons = "8 major planets"
	p.distance_from_sun = "System center"

	p.data_cards = [
		{"title": "Type", "value": "G-type main-sequence star"},
		{"title": "Diameter", "value": p.diameter_km},
		{"title": "Mass", "value": p.mass},
		{"title": "Surface temp", "value": "~5,500 °C"},
		{"title": "Core temp", "value": "~15 million °C"},
		{"title": "Rotation", "value": p.rotation_period},
		{"title": "Planets", "value": "8 major planets"},
		{"title": "Galaxy orbit", "value": "~230 million years"},
	]

	p.overview_points = [
		{"title": "Energy engine", "text": "Fusion in the core turns hydrogen into helium and releases enormous energy."},
		{"title": "Orbit controller", "text": "Its gravity organizes planets, dwarf planets, comets, asteroids, and dust."},
		{"title": "Space weather source", "text": "Solar storms can affect satellites, power systems, navigation, and radio signals."},
		{"title": "Life connection", "text": "Its light powers climate, weather, and photosynthesis on suitable worlds."},
	]

	p.key_features = [
		{"title": "Fusion core", "text": "The core is where pressure and temperature are high enough for nuclear fusion."},
		{"title": "Magnetic activity", "text": "Sunspots, flares, prominences, and coronal mass ejections are shaped by magnetic fields."},
		{"title": "Solar wind", "text": "A stream of charged particles flows outward and interacts with planets and magnetic fields."},
		{"title": "Stable main sequence", "text": "The Sun is in a long-lasting phase where fusion balances gravity."},
	]

	p.fun_fact_title = "Did you know?"
	p.fun_fact = "About 1.3 million Earths could fit inside the Sun by volume."
	p.quiz_text = "Test how the Sun creates energy, controls orbits, and shapes space weather."
	p.compare_text = "Compare the Sun with red dwarfs, giant stars, rocky planets, and gas giants."
	p.missions_text = "Explore missions like SOHO, STEREO, Solar Dynamics Observatory, Parker Solar Probe, and Solar Orbiter."

	p.learning_prompts = [
		{"title": "Explain", "text": "Why can a star support life indirectly without being habitable itself?"},
		{"title": "Observe", "text": "Name two visible signs that the Sun is magnetically active."},
		{"title": "Connect", "text": "How would nearby planets change if the Sun were much cooler or much hotter?"},
	]

	p.planet_radius_px = 188
	p.planet_turning_speed = 0.34
	p.planet_axial_tilt_deg = 7.25

	_apply_game_data(
		p,
		"Stellar",
		"Fusion-stable",
		"System anchor",
		50,
		[
			_score("Habitability", 0, "gray"),
			_score("Magnetic Field", 92, "purple"),
			_score("Atmosphere", 0, "gray"),
			_score("Geology", 8, "orange"),
			_score("Gravity", 100, "red"),
			_score("Radiation Safety", 3, "red"),
		],
		[
			_badge("Energy", "Fusion", "orange"),
			_badge("Gravity", "Anchor", "purple"),
			_badge("Risk", "Extreme", "red"),
		]
	)

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
		"Mercury is a small rocky planet with an oversized metallic core, a heavily cratered surface, and almost no atmosphere. Its short orbit and exposed terrain make it a harsh record of impacts, heat, and ancient volcanism.",
		"rocky",
		"no_atmosphere",
		37819421,
		PackedInt32Array([0, 4, 5, 8, 11, 12, 18, 25, 28, 31])
	)

	p.object_category = "planet"
	p.parent_object = "Sun"
	p.system_role = "Inner rocky planet and fast-moving laboratory for extreme solar heating."
	p.visual_signature = "Gray, cratered terrain with long cliffs, smooth plains, and bright impact rays."
	p.composition = "Large metallic core with a rocky silicate mantle and crust."
	p.atmosphere = "Almost no atmosphere; only a very thin exosphere."
	p.surface_geology = "Impact craters, ancient lava plains, scarps, basins, and fractured terrain."
	p.magnetic_field = "Weak global magnetic field, unusual for such a small rocky planet."
	p.ring_system = "None."
	p.habitability_note = "Surface conditions are extremely harsh because of radiation, temperature swings, and lack of air."
	p.formation_note = "Its oversized core may preserve evidence of early collisions or sorting of dense materials close to the young Sun."
	p.discovery_note = "Known since ancient times; mapped closely by Mariner 10 and MESSENGER."
	p.notable_extreme = "Shortest orbital year of any major planet."

	p.diameter_km = "4,879 km"
	p.mass = "3.301 × 10²³ kg"
	p.orbital_period = "88.0 Earth days"
	p.rotation_period = "58.6 Earth days"
	p.average_temperature = "167 °C"
	p.gravity = "3.7 m/s²"
	p.moons = "0"
	p.distance_from_sun = "57.9 million km"

	p.data_cards = [
		{"title": "Diameter", "value": p.diameter_km},
		{"title": "Mass", "value": p.mass},
		{"title": "Orbit", "value": p.orbital_period},
		{"title": "Solar day", "value": "~176 Earth days"},
		{"title": "Gravity", "value": p.gravity},
		{"title": "Atmosphere", "value": "Thin exosphere"},
		{"title": "Moons", "value": "0"},
		{"title": "Main terrain", "value": "Craters and scarps"},
	]

	p.overview_points = [
		{"title": "Fast orbit", "text": "Mercury completes a trip around the Sun faster than any other major planet."},
		{"title": "Exposed surface", "text": "With almost no atmosphere, impacts and solar radiation directly shape the ground."},
		{"title": "Metal-rich body", "text": "Its huge core makes it unusually dense for its size."},
		{"title": "Thermal shock", "text": "The surface swings between scorching daylight and freezing night."},
	]

	p.key_features = [
		{"title": "Caloris Basin", "text": "A giant impact basin that reshaped a large part of the planet."},
		{"title": "Lobate scarps", "text": "Long cliffs formed as Mercury cooled and contracted."},
		{"title": "Polar ice", "text": "Permanently shadowed polar craters can trap water ice despite the planet’s heat."},
		{"title": "Large core", "text": "Mercury’s metallic core takes up a surprisingly large fraction of the planet."},
	]

	p.fun_fact_title = "Did you know?"
	p.fun_fact = "A year on Mercury lasts only 88 Earth days, but one solar day lasts about 176 Earth days."
	p.quiz_text = "Test why Mercury can be both extremely hot and extremely cold."
	p.compare_text = "Compare Mercury with the Moon, Mars, and other airless rocky bodies."
	p.missions_text = "Explore missions like Mariner 10, MESSENGER, and BepiColombo."

	p.learning_prompts = [
		{"title": "Predict", "text": "Why does having almost no atmosphere create extreme temperature swings?"},
		{"title": "Compare", "text": "How is Mercury similar to and different from the Moon?"},
		{"title": "Infer", "text": "What might Mercury’s large core tell scientists about its early history?"},
	]

	p.planet_radius_px = 116
	p.planet_turning_speed = 0.72
	p.planet_axial_tilt_deg = 0.03

	_apply_game_data(
		p,
		"Planetary",
		"Airless",
		"Fast inner orbit",
		30,
		[
			_score("Habitability", 2, "red"),
			_score("Magnetic Field", 28, "purple"),
			_score("Atmosphere", 1, "gray"),
			_score("Geology", 42, "orange"),
			_score("Gravity", 32, "blue"),
			_score("Radiation Safety", 6, "red"),
		],
		[
			_badge("Surface", "Cratered", "gray"),
			_badge("Orbit", "Fast", "yellow"),
			_badge("Heat", "Extreme", "red"),
		]
	)

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
		"Venus is a rocky planet similar in size to Earth, but its dense carbon dioxide atmosphere and sulfuric acid clouds trap heat through a runaway greenhouse effect, making the surface hotter than Mercury.",
		"rocky",
		"dry_terran",
		84726109,
		PackedInt32Array([0, 4, 8, 10, 13, 14, 17, 20, 21, 29])
	)

	p.object_category = "planet"
	p.parent_object = "Sun"
	p.system_role = "Rocky planet showing how atmosphere can completely transform climate."
	p.visual_signature = "Bright cloud-covered disk hiding a hot volcanic surface."
	p.composition = "Rocky planet with metallic core, mantle, and crust."
	p.atmosphere = "Very dense carbon dioxide atmosphere with sulfuric acid clouds."
	p.surface_geology = "Volcanic plains, mountains, coronae, tesserae, and deformed crustal regions."
	p.magnetic_field = "No strong global magnetic field; solar wind interacts directly with the upper atmosphere."
	p.ring_system = "None."
	p.habitability_note = "The surface is extremely hostile, though the upper cloud layers remain scientifically interesting."
	p.formation_note = "Likely formed similarly to Earth, then evolved into a runaway greenhouse world."
	p.discovery_note = "Known since ancient times; explored by Venera landers, Magellan radar mapping, Venus Express, and Akatsuki."
	p.notable_extreme = "Hottest major planet despite not being the closest to the Sun."

	p.diameter_km = "12,104 km"
	p.mass = "4.867 × 10²⁴ kg"
	p.orbital_period = "224.7 Earth days"
	p.rotation_period = "243 Earth days, retrograde"
	p.average_temperature = "464 °C"
	p.gravity = "8.87 m/s²"
	p.moons = "0"
	p.distance_from_sun = "108.2 million km"

	p.data_cards = [
		{"title": "Diameter", "value": p.diameter_km},
		{"title": "Mass", "value": p.mass},
		{"title": "Orbit", "value": p.orbital_period},
		{"title": "Rotation", "value": "243 days retrograde"},
		{"title": "Surface temp", "value": p.average_temperature},
		{"title": "Pressure", "value": "~92× Earth"},
		{"title": "Atmosphere", "value": "CO₂ + sulfuric clouds"},
		{"title": "Moons", "value": "0"},
	]

	p.overview_points = [
		{"title": "Climate warning", "text": "Venus shows how powerful greenhouse heating can dominate an entire planet."},
		{"title": "Hidden ground", "text": "Thick clouds block normal cameras, so radar is used to map the surface."},
		{"title": "Backward spin", "text": "Venus rotates opposite most major planets."},
		{"title": "Volcanic world", "text": "Its surface is shaped by broad volcanic plains and large deformation features."},
	]

	p.key_features = [
		{"title": "Runaway greenhouse", "text": "Dense carbon dioxide traps heat until the surface becomes oven-like."},
		{"title": "Crushing pressure", "text": "The surface pressure is similar to being deep underwater on Earth."},
		{"title": "Sulfuric acid clouds", "text": "The bright clouds reflect sunlight but also hide the surface."},
		{"title": "Radar-mapped surface", "text": "Spacecraft use radar to see through Venus’s thick cloud cover."},
	]

	p.fun_fact_title = "Did you know?"
	p.fun_fact = "On Venus, the Sun would appear to rise in the west and set in the east."
	p.quiz_text = "Test how atmosphere, pressure, and greenhouse heating turned Venus into an extreme world."
	p.compare_text = "Compare Venus with Earth’s size, mass, atmosphere, and surface conditions."
	p.missions_text = "Explore missions like Venera, Magellan, Venus Express, Akatsuki, VERITAS, DAVINCI, and EnVision."

	p.learning_prompts = [
		{"title": "Explain", "text": "Why is Venus hotter than Mercury even though Mercury is closer to the Sun?"},
		{"title": "Compare", "text": "What makes Venus Earth-like in size but not Earth-like in environment?"},
		{"title": "Investigate", "text": "Why is radar useful for exploring Venus?"},
	]

	p.planet_radius_px = 138
	p.planet_turning_speed = -0.22
	p.planet_axial_tilt_deg = 177.4

	_apply_game_data(
		p,
		"Planetary",
		"Runaway greenhouse",
		"Retrograde orbit",
		45,
		[
			_score("Habitability", 1, "red"),
			_score("Magnetic Field", 12, "gray"),
			_score("Atmosphere", 100, "orange"),
			_score("Geology", 72, "red"),
			_score("Gravity", 82, "purple"),
			_score("Radiation Safety", 18, "red"),
		],
		[
			_badge("Heat", "Extreme", "red"),
			_badge("Atmosphere", "Crushing", "orange"),
			_badge("Rotation", "Retrograde", "purple"),
		]
	)

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
		"Earth is a rocky ocean planet with liquid water, active geology, a protective atmosphere, and a global magnetic field. These connected systems make it the only known world with confirmed life.",
		"rocky",
		"terran_wet",
		363978383,
		PackedInt32Array([0, 4, 5, 7, 8, 10, 11, 13, 14, 22, 23])
	)

	p.object_category = "planet"
	p.parent_object = "Sun"
	p.system_role = "Rocky ocean planet with active geology, climate, and confirmed life."
	p.visual_signature = "Blue oceans, white clouds, brown-green continents, and polar ice."
	p.composition = "Metallic core, rocky mantle, crust, oceans, atmosphere, and biosphere."
	p.atmosphere = "Nitrogen-oxygen atmosphere with water vapor, clouds, and trace gases."
	p.surface_geology = "Plate tectonics, oceans, continents, mountains, volcanoes, erosion, and sediment cycles."
	p.magnetic_field = "Strong global magnetic field generated by motion in the liquid outer core."
	p.ring_system = "None."
	p.habitability_note = "Only known world with stable surface liquid water and confirmed life."
	p.formation_note = "Formed from early rocky material, then evolved through impacts, differentiation, ocean formation, and biological change."
	p.discovery_note = "Human homeworld; observed from orbit by thousands of satellites."
	p.notable_extreme = "Only confirmed living planet known so far."

	p.diameter_km = "12,742 km"
	p.mass = "5.972 × 10²⁴ kg"
	p.orbital_period = "365.25 days"
	p.rotation_period = "23h 56m"
	p.average_temperature = "15 °C"
	p.gravity = "9.81 m/s²"
	p.moons = "1"
	p.distance_from_sun = "149.6 million km"

	p.data_cards = [
		{"title": "Diameter", "value": p.diameter_km},
		{"title": "Mass", "value": p.mass},
		{"title": "Orbit", "value": p.orbital_period},
		{"title": "Rotation", "value": p.rotation_period},
		{"title": "Avg temp", "value": p.average_temperature},
		{"title": "Surface water", "value": "~71%"},
		{"title": "Atmosphere", "value": "N₂ + O₂"},
		{"title": "Moon", "value": "1"},
	]

	p.overview_points = [
		{"title": "Living system", "text": "Earth connects geology, air, water, and life into one dynamic planet."},
		{"title": "Water world", "text": "Liquid oceans regulate climate and support ecosystems."},
		{"title": "Shielded planet", "text": "Atmosphere and magnetosphere reduce radiation and small impact threats."},
		{"title": "Active crust", "text": "Plate tectonics recycles rock and shapes continents over time."},
	]

	p.key_features = [
		{"title": "Biosphere", "text": "Life changes the atmosphere, oceans, rocks, and climate over time."},
		{"title": "Plate tectonics", "text": "Moving plates build mountains, recycle crust, and power many volcanoes and earthquakes."},
		{"title": "Water cycle", "text": "Evaporation, clouds, rain, rivers, ice, and oceans constantly move water around the planet."},
		{"title": "Magnetosphere", "text": "Earth’s magnetic field helps deflect charged particles from the solar wind."},
	]

	p.fun_fact_title = "Did you know?"
	p.fun_fact = "Earth is not a perfect sphere. It is slightly wider at the equator because of its rotation."
	p.quiz_text = "Test how water, air, rock, magnetism, and life interact on Earth."
	p.compare_text = "Compare Earth with Venus, Mars, ocean moons, and rocky exoplanets."
	p.missions_text = "Explore Earth observation missions, weather satellites, climate satellites, and crewed orbital stations."

	p.learning_prompts = [
		{"title": "Explain", "text": "Why do liquid water, atmosphere, and magnetic field matter together?"},
		{"title": "Compare", "text": "Which Earth feature is most different from Mars or Venus?"},
		{"title": "Apply", "text": "What would you search for first on an exoplanet that might be Earth-like?"},
	]

	p.planet_radius_px = 142
	p.planet_turning_speed = 1.0
	p.planet_axial_tilt_deg = 23.44

	_apply_game_data(
		p,
		"Planetary",
		"Life-stable",
		"Balanced orbit",
		40,
		[
			_score("Habitability", 100, "green"),
			_score("Magnetic Field", 86, "purple"),
			_score("Atmosphere", 91, "blue"),
			_score("Geology", 88, "orange"),
			_score("Gravity", 72, "accent"),
			_score("Radiation Safety", 84, "green"),
		],
		[
			_badge("Ocean", "Liquid water", "blue"),
			_badge("Life", "Confirmed", "green"),
			_badge("Shield", "Magnetic", "purple"),
		]
	)

	return _apply_colors(p, PackedColorArray([
		Color("#63AB3F"),
		Color("#3b7d4f"),
		Color("#2f5753"),
		Color("#283540"),
		Color("#4fa4b8"),
		Color("#404973"),
		Color("#f5ffe8"),
		Color("#dfe0e8"),
		Color("#686f99"),
		Color("#404973"),
	]))


static func _moon() -> PlanetData:
	var p := _base(
		"moon",
		"Moon",
		"Earth’s cratered companion",
		"The Moon is Earth’s only natural satellite, a rocky airless world shaped by impacts, ancient volcanism, tidal locking, and long-term interaction with Earth. Its surface preserves a record of early Solar System history.",
		"moon",
		"moon",
		194874231,
		PackedInt32Array([0, 2, 5, 7, 8, 10, 13, 17, 20, 24, 29])
	)

	p.object_category = "satellite"
	p.parent_object = "Earth"
	p.system_role = "Natural satellite that stabilizes Earth’s axial tilt, drives tides, and preserves ancient impact history."
	p.visual_signature = "Gray cratered highlands, darker basaltic maria, bright ray systems, and rugged impact basins."
	p.composition = "Rocky silicate body with a small metallic core, mantle, crust, basaltic maria, and impact-processed regolith."
	p.atmosphere = "Almost no atmosphere; only an extremely thin exosphere."
	p.surface_geology = "Impact craters, maria, highlands, mountains, rilles, basins, lava plains, and fine regolith."
	p.magnetic_field = "No active global magnetic field today; some crustal regions preserve ancient magnetism."
	p.ring_system = "None."
	p.habitability_note = "Not naturally habitable because it lacks air, liquid surface water, and strong radiation shielding."
	p.formation_note = "Likely formed after a giant impact between early Earth and a Mars-sized body, followed by debris accretion."
	p.discovery_note = "Known since prehistory; visited by Luna, Surveyor, Apollo, Chang’e, Chandrayaan, LRO, Artemis-related missions, and many orbiters."
	p.notable_extreme = "Only world beyond Earth where humans have walked."
	p.exploration_status = "Explored by orbiters, landers, rovers, sample-return missions, and Apollo astronauts."

	p.diameter_km = "3,474 km"
	p.mass = "7.342 × 10²² kg"
	p.orbital_period = "27.3 Earth days"
	p.rotation_period = "27.3 Earth days, synchronous"
	p.average_temperature = "-20 °C"
	p.gravity = "1.62 m/s²"
	p.moons = "Not applicable"
	p.distance_from_sun = "Orbits Earth; Earth averages 149.6 million km from Sun"

	p.data_cards = [
		{"title": "Diameter", "value": p.diameter_km},
		{"title": "Mass", "value": p.mass},
		{"title": "Parent", "value": "Earth"},
		{"title": "Orbit", "value": p.orbital_period},
		{"title": "Rotation", "value": p.rotation_period},
		{"title": "Avg temp", "value": p.average_temperature},
		{"title": "Gravity", "value": p.gravity},
		{"title": "Surface", "value": "Craters, maria, regolith"},
	]

	p.overview_points = [
		{"title": "Tidal partner", "text": "The Moon’s gravity raises tides on Earth and slowly changes both bodies’ rotation over time."},
		{"title": "Locked face", "text": "Because it is tidally locked, the Moon keeps nearly the same side facing Earth."},
		{"title": "Ancient surface", "text": "With almost no atmosphere or weather, many craters remain preserved for billions of years."},
		{"title": "Human frontier", "text": "The Moon is the first world beyond Earth visited by humans and remains a major exploration target."},
	]

	p.key_features = [
		{"title": "Impact craters", "text": "Craters of many sizes record collisions from early Solar System debris and later impacts."},
		{"title": "Lunar maria", "text": "The dark maria are ancient basaltic lava plains formed by volcanic flooding."},
		{"title": "Regolith", "text": "Fine broken rock and dust cover much of the surface after billions of years of impacts."},
		{"title": "Tidal locking", "text": "The Moon rotates once per orbit, keeping the same near side facing Earth."},
	]

	p.fun_fact_title = "Did you know?"
	p.fun_fact = "The Moon is slowly moving away from Earth by about 3.8 cm per year."
	p.quiz_text = "Test how impacts, tides, synchronous rotation, and ancient volcanism shaped the Moon."
	p.compare_text = "Compare the Moon with Mercury, Mars, Europa, Titan, and other rocky or icy satellites."
	p.missions_text = "Explore missions like Luna, Surveyor, Apollo, Clementine, Lunar Reconnaissance Orbiter, Chandrayaan, Chang’e, and Artemis."

	p.learning_prompts = [
		{"title": "Explain", "text": "Why does the Moon always show nearly the same face to Earth?"},
		{"title": "Compare", "text": "How is the Moon similar to Mercury, and how is it different?"},
		{"title": "Investigate", "text": "What can lunar craters tell scientists about early Solar System history?"},
	]

	p.planet_radius_px = 102
	p.planet_turning_speed = 0.72
	p.planet_axial_tilt_deg = 6.68

	_apply_game_data(
		p,
		"Satellite",
		"Parent-bound",
		"Synchronous orbit",
		30,
		[
			_score("Habitability", 7, "red"),
			_score("Magnetic Field", 6, "gray"),
			_score("Atmosphere", 1, "gray"),
			_score("Geology", 38, "orange"),
			_score("Gravity", 18, "blue"),
			_score("Radiation Safety", 16, "red"),
		],
		[
			_badge("Orbit", "Locked", "blue"),
			_badge("Surface", "Cratered", "gray"),
			_badge("History", "Ancient", "accent"),
		]
	)

	return _apply_colors(p, PackedColorArray([
		Color("#d8d8d0"),
		Color("#b9b9b0"),
		Color("#8f8f88"),
		Color("#666660"),
		Color("#3f3f3c"),
		Color("#eeeeea"),
		Color("#aaa9a2"),
		Color("#777770"),
	]))


static func _mars() -> PlanetData:
	var p := _base(
		"mars",
		"Mars",
		"The rusty desert planet",
		"Mars is a cold rocky desert with iron-rich dust, polar ice, giant volcanoes, deep canyons, and ancient water clues. Its surface preserves evidence that rivers, lakes, or groundwater once shaped parts of the planet.",
		"rocky",
		"dry_terran",
		734862,
		PackedInt32Array([0, 4, 5, 7, 8, 10, 12, 13, 16, 17, 22, 23])
	)

	p.object_category = "planet"
	p.parent_object = "Sun"
	p.system_role = "Cold rocky desert world preserving clues about past water and habitability."
	p.visual_signature = "Rust-red surface, dusty skies, polar caps, volcanoes, and canyon systems."
	p.composition = "Rocky body rich in iron-bearing minerals and basaltic crust."
	p.atmosphere = "Thin carbon dioxide atmosphere with dust, clouds, and seasonal pressure changes."
	p.surface_geology = "Volcanoes, impact basins, dried river valleys, dunes, and polar layered deposits."
	p.magnetic_field = "No strong global magnetic field today; crustal magnetism remains in some regions."
	p.ring_system = "None."
	p.habitability_note = "Not comfortable today, but ancient Mars may have had environments where microbes could survive."
	p.formation_note = "Formed as a rocky planet, then lost much of its atmosphere and surface water over billions of years."
	p.discovery_note = "Known since ancient times; explored by orbiters, landers, rovers, and helicopter scouting."
	p.notable_extreme = "Home to Olympus Mons and Valles Marineris, among the largest volcanic and canyon systems known."

	p.diameter_km = "6,779 km"
	p.mass = "6.417 × 10²³ kg"
	p.orbital_period = "687.0 Earth days"
	p.rotation_period = "24h 37m"
	p.average_temperature = "-63 °C"
	p.gravity = "3.71 m/s²"
	p.moons = "2"
	p.distance_from_sun = "227.9 million km"

	p.data_cards = [
		{"title": "Diameter", "value": p.diameter_km},
		{"title": "Mass", "value": p.mass},
		{"title": "Orbit", "value": p.orbital_period},
		{"title": "Rotation", "value": p.rotation_period},
		{"title": "Avg temp", "value": p.average_temperature},
		{"title": "Atmosphere", "value": "Thin CO₂"},
		{"title": "Moons", "value": "2"},
		{"title": "Main clue", "value": "Ancient water"},
	]

	p.overview_points = [
		{"title": "Water clues", "text": "Valleys, minerals, and lakebed deposits suggest liquid water once shaped the surface."},
		{"title": "Dust planet", "text": "Fine iron-rich dust gives Mars its red color and can fuel planet-wide storms."},
		{"title": "Human target", "text": "Mars is a major focus for future robotic and crewed exploration."},
		{"title": "Lost shield", "text": "Without a strong global magnetic field, its atmosphere became easier to strip away."},
	]

	p.key_features = [
		{"title": "Olympus Mons", "text": "A giant shield volcano that rises far higher than Mount Everest."},
		{"title": "Valles Marineris", "text": "A huge canyon system stretching thousands of kilometers across the planet."},
		{"title": "Polar ice caps", "text": "Seasonal and permanent ice deposits record climate changes."},
		{"title": "Ancient habitability", "text": "Rocks and sediments preserve clues about warmer, wetter environments in the past."},
	]

	p.fun_fact_title = "Did you know?"
	p.fun_fact = "Mars has seasons like Earth because its axis is tilted."
	p.quiz_text = "Test how ancient water, thin air, dust, and volcanoes shaped Mars."
	p.compare_text = "Compare Mars with Earth, Mercury, the Moon, and possible future human bases."
	p.missions_text = "Explore missions like Viking, Curiosity, Perseverance, Ingenuity, Mars Express, MAVEN, and ExoMars."

	p.learning_prompts = [
		{"title": "Explain", "text": "How can dry valleys prove that water once existed?"},
		{"title": "Compare", "text": "Why is Mars more inviting than Venus but still hostile?"},
		{"title": "Design", "text": "What would a rover need to search for ancient life on Mars?"},
	]

	p.planet_radius_px = 124
	p.planet_turning_speed = 0.97
	p.planet_axial_tilt_deg = 25.19

	_apply_game_data(
		p,
		"Planetary",
		"Cold desert",
		"Exploration target",
		40,
		[
			_score("Habitability", 28, "yellow"),
			_score("Magnetic Field", 14, "gray"),
			_score("Atmosphere", 24, "orange"),
			_score("Geology", 78, "red"),
			_score("Gravity", 38, "blue"),
			_score("Radiation Safety", 22, "red"),
		],
		[
			_badge("Dust", "Iron-rich", "orange"),
			_badge("Water", "Ancient", "blue"),
			_badge("Volcanoes", "Giant", "red"),
		]
	)

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
		"Jupiter is a massive gas giant made mostly of hydrogen and helium. Its fast rotation, deep atmosphere, huge magnetic field, and large moon system make it feel like a miniature planetary system.",
		"gas_giant",
		"gas_giant_1",
		76219384,
		PackedInt32Array([0, 4, 5, 9, 10, 13, 14, 17, 20, 22, 25, 26])
	)

	p.object_category = "planet"
	p.parent_object = "Sun"
	p.system_role = "Massive gas giant that shapes nearby small-body orbits and hosts a moon system like a mini solar system."
	p.visual_signature = "Striped cloud bands, bright zones, dark belts, and the Great Red Spot."
	p.composition = "Mostly hydrogen and helium, likely with a deep compressed interior and diluted heavy-element core."
	p.atmosphere = "Thick hydrogen-helium atmosphere with ammonia clouds, storms, and powerful jet streams."
	p.surface_geology = "No solid surface; visible features are atmospheric cloud layers."
	p.magnetic_field = "Strongest planetary magnetic field in the Solar System."
	p.ring_system = "Very faint ring system made mostly of dust."
	p.habitability_note = "Not habitable as a gas giant, but some moons may contain subsurface oceans."
	p.formation_note = "Likely formed early and grew massive enough to capture large amounts of gas."
	p.discovery_note = "Known since ancient times; studied by Pioneer, Voyager, Galileo, Juno, Europa Clipper, and JUICE."
	p.notable_extreme = "Largest major planet, with storms bigger than Earth."

	p.diameter_km = "139,820 km"
	p.mass = "1.898 × 10²⁷ kg"
	p.orbital_period = "11.86 Earth years"
	p.rotation_period = "9h 56m"
	p.average_temperature = "-108 °C"
	p.gravity = "24.79 m/s²"
	p.moons = "101"
	p.distance_from_sun = "778.5 million km"

	p.data_cards = [
		{"title": "Diameter", "value": p.diameter_km},
		{"title": "Mass", "value": p.mass},
		{"title": "Orbit", "value": p.orbital_period},
		{"title": "Rotation", "value": p.rotation_period},
		{"title": "Cloud temp", "value": p.average_temperature},
		{"title": "Main gases", "value": "H₂ + He"},
		{"title": "Moons", "value": p.moons},
		{"title": "Signature", "value": "Great Red Spot"},
	]

	p.overview_points = [
		{"title": "Giant gravity", "text": "Jupiter’s mass strongly affects asteroids, comets, and nearby moon orbits."},
		{"title": "Storm machine", "text": "Fast rotation and deep atmosphere create powerful belts, zones, and long-lived storms."},
		{"title": "Moon system", "text": "Its major moons include volcanic Io, icy Europa, huge Ganymede, and cratered Callisto."},
		{"title": "Magnetic power", "text": "Its magnetosphere is enormous and radiation-rich."},
	]

	p.key_features = [
		{"title": "Great Red Spot", "text": "A long-lived giant storm large enough to swallow Earth."},
		{"title": "Galilean moons", "text": "Io, Europa, Ganymede, and Callisto are diverse worlds with volcanoes, ice, oceans, and craters."},
		{"title": "Deep atmosphere", "text": "Bands and storms are only the visible top of a much deeper fluid planet."},
		{"title": "Radiation belts", "text": "Jupiter’s magnetic field traps intense radiation around the planet."},
	]

	p.fun_fact_title = "Did you know?"
	p.fun_fact = "Jupiter spins so fast that its day is less than 10 hours long."
	p.quiz_text = "Test how gas giants work, why storms last, and why Jupiter’s moons matter."
	p.compare_text = "Compare Jupiter with Saturn, Neptune, brown dwarfs, and large exoplanets."
	p.missions_text = "Explore missions like Pioneer, Voyager, Galileo, Juno, Europa Clipper, and JUICE."

	p.learning_prompts = [
		{"title": "Explain", "text": "Why does fast rotation matter for Jupiter’s atmosphere?"},
		{"title": "Compare", "text": "How is a gas giant different from a rocky planet?"},
		{"title": "Investigate", "text": "Why are Europa and Ganymede scientifically important?"},
	]

	p.planet_radius_px = 168
	p.planet_turning_speed = 1.45
	p.planet_axial_tilt_deg = 3.13

	_apply_game_data(
		p,
		"Planetary",
		"Massive",
		"Moon system",
		50,
		[
			_score("Habitability", 3, "red"),
			_score("Magnetic Field", 100, "purple"),
			_score("Atmosphere", 100, "orange"),
			_score("Geology", 14, "gray"),
			_score("Gravity", 96, "red"),
			_score("Radiation Safety", 5, "red"),
		],
		[
			_badge("Scale", "Giant", "orange"),
			_badge("Storm", "Great Red Spot", "red"),
			_badge("Magnetic", "Extreme", "purple"),
		]
	)

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
		"Saturn is a gas giant with a wide icy ring system, low density, fast winds, and a rich family of moons. Its rings and satellites make it one of the best natural laboratories for orbital physics.",
		"ringed_gas_giant",
		"gas_giant_2",
		61390275,
		PackedInt32Array([0, 4, 5, 8, 9, 11, 14, 17, 20, 24, 25, 26])
	)

	p.object_category = "planet"
	p.parent_object = "Sun"
	p.system_role = "Ringed gas giant with a complex satellite system and low-density structure."
	p.visual_signature = "Golden bands surrounded by a wide, bright ring system."
	p.composition = "Mostly hydrogen and helium with deeper layers of compressed material."
	p.atmosphere = "Hydrogen-helium atmosphere with clouds, storms, and fast winds."
	p.surface_geology = "No solid surface; visible structure is atmospheric."
	p.magnetic_field = "Large magnetic field, unusually aligned close to its rotation axis."
	p.ring_system = "Bright icy rings made of countless particles from dust grains to boulders."
	p.habitability_note = "Not habitable itself, but moons such as Titan and Enceladus are major astrobiology targets."
	p.formation_note = "Built from gas and solids in the early outer system; rings may be relatively young compared with the planet."
	p.discovery_note = "Known since ancient times; Cassini-Huygens transformed modern understanding of Saturn and its moons."
	p.notable_extreme = "Lowest average density of the major planets."

	p.diameter_km = "116,460 km"
	p.mass = "5.683 × 10²⁶ kg"
	p.orbital_period = "29.45 Earth years"
	p.rotation_period = "10h 33m"
	p.average_temperature = "-139 °C"
	p.gravity = "10.44 m/s²"
	p.moons = "285+"
	p.distance_from_sun = "1.43 billion km"

	p.data_cards = [
		{"title": "Diameter", "value": p.diameter_km},
		{"title": "Mass", "value": p.mass},
		{"title": "Orbit", "value": p.orbital_period},
		{"title": "Rotation", "value": p.rotation_period},
		{"title": "Cloud temp", "value": p.average_temperature},
		{"title": "Rings", "value": "Bright icy system"},
		{"title": "Moons", "value": p.moons},
		{"title": "Density", "value": "Less than water"},
	]

	p.overview_points = [
		{"title": "Ring laboratory", "text": "Saturn’s rings reveal orbital waves, gaps, moon interactions, and icy particle behavior."},
		{"title": "Titan", "text": "Titan has a thick atmosphere and methane-ethane lakes."},
		{"title": "Enceladus", "text": "Enceladus sprays icy plumes from a subsurface ocean."},
		{"title": "Soft giant", "text": "Despite its huge size, Saturn is much less dense than rocky worlds."},
	]

	p.key_features = [
		{"title": "Ring system", "text": "The rings are countless separate icy particles, not a solid disk."},
		{"title": "Titan", "text": "Titan is larger than Mercury and has a dense nitrogen-rich atmosphere."},
		{"title": "Enceladus plumes", "text": "Jets of icy material reveal a hidden ocean beneath the surface."},
		{"title": "Hexagon storm", "text": "A strange six-sided jet stream pattern exists around Saturn’s north pole."},
	]

	p.fun_fact_title = "Did you know?"
	p.fun_fact = "Saturn’s rings are incredibly wide but surprisingly thin compared with their diameter."
	p.quiz_text = "Test how rings, moons, density, and gas giant structure work."
	p.compare_text = "Compare Saturn with Jupiter, Uranus, Neptune, and ringed exoplanets."
	p.missions_text = "Explore missions like Pioneer 11, Voyager, Cassini-Huygens, and future Titan missions."

	p.learning_prompts = [
		{"title": "Explain", "text": "Why are Saturn’s rings not a solid disk?"},
		{"title": "Compare", "text": "Why might Titan feel more planet-like than many small moons?"},
		{"title": "Investigate", "text": "What makes Enceladus interesting for astrobiology?"},
	]

	p.planet_radius_px = 158
	p.planet_turning_speed = 1.2
	p.planet_axial_tilt_deg = 26.73
	p.planet_ring_angle_deg = 26.73

	_apply_game_data(
		p,
		"Planetary",
		"Ring-stable",
		"Ring physics",
		50,
		[
			_score("Habitability", 4, "red"),
			_score("Magnetic Field", 82, "purple"),
			_score("Atmosphere", 96, "orange"),
			_score("Geology", 16, "gray"),
			_score("Gravity", 78, "purple"),
			_score("Radiation Safety", 24, "yellow"),
		],
		[
			_badge("Rings", "Icy", "yellow"),
			_badge("Density", "Low", "blue"),
			_badge("Moons", "Rich", "accent"),
		]
	)

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
		"Uranus is an ice giant with a pale cyan atmosphere, dark narrow rings, unusual magnetism, and an extreme sideways tilt. Its strange orientation creates seasons unlike those of any ordinary spinning world.",
		"ice_giant",
		"ice_world",
		90835162,
		PackedInt32Array([0, 3, 4, 8, 9, 11, 14, 16, 19, 20, 24, 25])
	)

	p.object_category = "planet"
	p.parent_object = "Sun"
	p.system_role = "Ice giant with an extreme axial tilt and a cold, methane-colored atmosphere."
	p.visual_signature = "Smooth pale cyan disk, faint dark rings, and sideways rotation."
	p.composition = "Ice giant interior rich in water, ammonia, methane, rock, and hydrogen-helium gas."
	p.atmosphere = "Hydrogen-helium atmosphere with methane that absorbs red light."
	p.surface_geology = "No solid visible surface; cloud layers hide a deep ice-rich interior."
	p.magnetic_field = "Tilted and offset magnetic field, unlike a simple centered dipole."
	p.ring_system = "Dark, narrow ring system."
	p.habitability_note = "Not habitable, but its moons and interior structure are important for understanding ice giants."
	p.formation_note = "May have been knocked onto its side by a major early impact or series of impacts."
	p.discovery_note = "Discovered telescopically by William Herschel in 1781; visited only by Voyager 2."
	p.notable_extreme = "Rotates almost sideways compared with its orbit."

	p.diameter_km = "50,724 km"
	p.mass = "8.681 × 10²⁵ kg"
	p.orbital_period = "84.0 Earth years"
	p.rotation_period = "17h 14m, retrograde"
	p.average_temperature = "-197 °C"
	p.gravity = "8.69 m/s²"
	p.moons = "29"
	p.distance_from_sun = "2.87 billion km"

	p.data_cards = [
		{"title": "Diameter", "value": p.diameter_km},
		{"title": "Mass", "value": p.mass},
		{"title": "Orbit", "value": p.orbital_period},
		{"title": "Rotation", "value": p.rotation_period},
		{"title": "Avg temp", "value": p.average_temperature},
		{"title": "Axial tilt", "value": "97.77°"},
		{"title": "Moons", "value": p.moons},
		{"title": "Color source", "value": "Methane"},
	]

	p.overview_points = [
		{"title": "Sideways seasons", "text": "Its tilt gives each pole decades of sunlight or darkness."},
		{"title": "Ice giant mystery", "text": "Uranus helps explain a planet type common around other stars."},
		{"title": "Hidden structure", "text": "Its smooth appearance hides complex layers deep below."},
		{"title": "Underexplored", "text": "Only one spacecraft has flown past Uranus so far."},
	]

	p.key_features = [
		{"title": "Extreme tilt", "text": "Uranus spins almost on its side, likely because of ancient impacts."},
		{"title": "Methane color", "text": "Methane absorbs red light, giving the planet its blue-green appearance."},
		{"title": "Offset magnetism", "text": "Its magnetic field is tilted and shifted away from the planet’s center."},
		{"title": "Dark rings", "text": "Uranus has narrow, dark rings that are harder to see than Saturn’s."},
	]

	p.fun_fact_title = "Did you know?"
	p.fun_fact = "Because Uranus is tilted so much, one pole can face the Sun for decades."
	p.quiz_text = "Test how tilt, methane, rings, and magnetic fields make Uranus unusual."
	p.compare_text = "Compare Uranus with Neptune, Saturn, and ice-giant exoplanets."
	p.missions_text = "Voyager 2 is the only spacecraft to have visited Uranus. Future orbiter concepts could transform what we know."

	p.learning_prompts = [
		{"title": "Explain", "text": "How does a 98-degree tilt change seasons?"},
		{"title": "Compare", "text": "How are ice giants different from gas giants?"},
		{"title": "Investigate", "text": "Why would scientists want a dedicated Uranus orbiter?"},
	]

	p.planet_radius_px = 144
	p.planet_turning_speed = -0.62
	p.planet_axial_tilt_deg = 97.77
	p.planet_ring_angle_deg = 97.77

	_apply_game_data(
		p,
		"Planetary",
		"Sideways",
		"Tilted seasons",
		45,
		[
			_score("Habitability", 5, "red"),
			_score("Magnetic Field", 64, "purple"),
			_score("Atmosphere", 90, "blue"),
			_score("Geology", 20, "gray"),
			_score("Gravity", 66, "purple"),
			_score("Radiation Safety", 38, "yellow"),
		],
		[
			_badge("Tilt", "Sideways", "purple"),
			_badge("Type", "Ice giant", "blue"),
			_badge("Rings", "Dark", "gray"),
		]
	)

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
		"Neptune is a distant ice giant with deep blue clouds, faint rings, strong storms, and some of the fastest winds measured on any planet. Its largest moon, Triton, may be a captured Kuiper Belt object.",
		"ice_giant",
		"ice_world",
		43091827,
		PackedInt32Array([0, 4, 5, 8, 9, 11, 13, 18, 19, 25, 26, 31])
	)

	p.object_category = "planet"
	p.parent_object = "Sun"
	p.system_role = "Distant ice giant with powerful winds, dark storms, and a captured moon system."
	p.visual_signature = "Deep blue atmosphere with bright methane clouds and occasional dark storm systems."
	p.composition = "Ice giant interior rich in water, ammonia, methane, rock, and hydrogen-helium gas."
	p.atmosphere = "Hydrogen-helium atmosphere with methane and high-speed weather patterns."
	p.surface_geology = "No solid visible surface; cloud features sit above a deep ice-rich interior."
	p.magnetic_field = "Tilted and offset magnetic field, similar in weirdness to Uranus."
	p.ring_system = "Faint ring arcs and dusty rings."
	p.habitability_note = "Not habitable, but its moon Triton is geologically interesting and may contain internal activity."
	p.formation_note = "Likely migrated early in Solar System history, helping reshape distant small-body populations."
	p.discovery_note = "Predicted mathematically before direct observation in 1846; visited only by Voyager 2."
	p.notable_extreme = "Hosts some of the fastest winds measured on a planet."

	p.diameter_km = "49,244 km"
	p.mass = "1.024 × 10²⁶ kg"
	p.orbital_period = "164.8 Earth years"
	p.rotation_period = "16h 6m"
	p.average_temperature = "-201 °C"
	p.gravity = "11.15 m/s²"
	p.moons = "16"
	p.distance_from_sun = "4.50 billion km"

	p.data_cards = [
		{"title": "Diameter", "value": p.diameter_km},
		{"title": "Mass", "value": p.mass},
		{"title": "Orbit", "value": p.orbital_period},
		{"title": "Rotation", "value": p.rotation_period},
		{"title": "Avg temp", "value": p.average_temperature},
		{"title": "Wind speed", "value": "Over 2,000 km/h"},
		{"title": "Moons", "value": p.moons},
		{"title": "Largest moon", "value": "Triton"},
	]

	p.overview_points = [
		{"title": "Wind world", "text": "Neptune’s distant atmosphere still produces extremely fast winds."},
		{"title": "Triton clue", "text": "Triton orbits backward, suggesting it may have been captured."},
		{"title": "Dark storms", "text": "Large storm systems appear and change over time."},
		{"title": "Outer frontier", "text": "Neptune marks the last major planet before the Kuiper Belt region."},
	]

	p.key_features = [
		{"title": "Supersonic winds", "text": "Neptune’s winds can exceed 2,000 km/h."},
		{"title": "Dark storm systems", "text": "Large atmospheric storms can appear, shift, and fade over time."},
		{"title": "Triton", "text": "Triton orbits backward and may have been captured from the Kuiper Belt."},
		{"title": "Faint rings", "text": "Neptune has dusty rings and ring arcs that are difficult to observe."},
	]

	p.fun_fact_title = "Did you know?"
	p.fun_fact = "One Neptune year lasts almost 165 Earth years."
	p.quiz_text = "Test how winds, methane, storms, rings, and captured moons define Neptune."
	p.compare_text = "Compare Neptune with Uranus, gas giants, and icy exoplanets."
	p.missions_text = "Voyager 2 is the only spacecraft to have visited Neptune. A dedicated orbiter could study its atmosphere, rings, and Triton."

	p.learning_prompts = [
		{"title": "Explain", "text": "Why is Triton’s backward orbit a clue about capture?"},
		{"title": "Compare", "text": "What makes Neptune more visually dramatic than Uranus?"},
		{"title": "Investigate", "text": "What questions could a Neptune orbiter answer?"},
	]

	p.planet_radius_px = 143
	p.planet_turning_speed = 0.85
	p.planet_axial_tilt_deg = 28.32

	_apply_game_data(
		p,
		"Planetary",
		"Storm-active",
		"Outer orbit",
		45,
		[
			_score("Habitability", 4, "red"),
			_score("Magnetic Field", 68, "purple"),
			_score("Atmosphere", 94, "blue"),
			_score("Geology", 22, "gray"),
			_score("Gravity", 74, "purple"),
			_score("Radiation Safety", 42, "yellow"),
		],
		[
			_badge("Wind", "Extreme", "blue"),
			_badge("Type", "Ice giant", "purple"),
			_badge("Moon", "Triton", "accent"),
		]
	)

	return _apply_colors(p, PackedColorArray([
		Color("#2f57d8"),
		Color("#1f3fb3"),
		Color("#152b7a"),
		Color("#5c82ff"),
		Color("#0b1645"),
	]))

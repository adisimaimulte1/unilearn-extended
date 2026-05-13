extends Node

signal cards_changed(cards: Array[PlanetData])
signal loading_changed(is_loading: bool)

var _cards_by_id: Dictionary = {}
var _loaded := false
var _loading := false


func is_loaded() -> bool:
	return _loaded


func get_all_cards() -> Array[PlanetData]:
	var result: Array[PlanetData] = []

	for card in _cards_by_id.values():
		if card is PlanetData:
			result.append(card)

	result.sort_custom(func(a: PlanetData, b: PlanetData) -> bool:
		return a.name.to_lower() < b.name.to_lower()
	)

	return result


func get_card(card_id: String) -> PlanetData:
	card_id = card_id.strip_edges()

	if _cards_by_id.has(card_id):
		return _cards_by_id[card_id]

	return null


func ensure_loaded(force_refresh: bool = false) -> Array[PlanetData]:
	if _loaded and not force_refresh:
		return get_all_cards()

	if _loading:
		while _loading:
			await get_tree().process_frame

		return get_all_cards()

	await reload()

	return get_all_cards()


func reload() -> bool:
	if _loading:
		return false

	_loading = true
	loading_changed.emit(true)

	var result: Dictionary = await FirebaseDatabase.get_planet_cards()

	_loading = false
	loading_changed.emit(false)

	if not result.get("success", false):
		print("Planet cards load failed: ", result)
		return false

	_cards_by_id.clear()

	var raw_cards: Array = result.get("cards", [])

	for raw in raw_cards:
		if raw is Dictionary:
			var card := PlanetData.from_firebase_dict(raw)
			var id := card.instance_id.strip_edges()

			if id == "":
				id = str(raw.get("id", "")).strip_edges()
				card.instance_id = id

			if id != "":
				_cards_by_id[id] = card

	_loaded = true
	cards_changed.emit(get_all_cards())

	return true


func save_card(card: PlanetData) -> Dictionary:
	if card == null:
		return {
			"success": false,
			"error": "NULL_CARD"
		}

	var result: Dictionary = await FirebaseDatabase.save_planet_card(card)

	if not result.get("success", false):
		return result

	_cards_by_id[card.instance_id] = card
	_loaded = true
	cards_changed.emit(get_all_cards())

	return result


func delete_card(card_id: String) -> Dictionary:
	card_id = card_id.strip_edges()

	if card_id == "":
		return {
			"success": false,
			"error": "EMPTY_CARD_ID"
		}

	var result: Dictionary = await FirebaseDatabase.delete_planet_card(card_id)

	if not result.get("success", false):
		return result

	_cards_by_id.erase(card_id)
	cards_changed.emit(get_all_cards())

	return result


func clear_cache() -> void:
	_cards_by_id.clear()
	_loaded = false
	_loading = false
	cards_changed.emit([])

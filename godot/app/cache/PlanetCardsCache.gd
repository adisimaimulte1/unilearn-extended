extends Node

signal cards_changed(cards: Array[PlanetData])
signal loading_changed(is_loading: bool)

signal card_generation_started(query: String, predicted_id: String)
signal card_generation_finished(card: PlanetData)
signal card_generation_failed(query: String, error: String)

var _cards_by_id: Dictionary = {}
var _loaded := false
var _loading := false

var _generating_by_id: Dictionary = {}
var _generating_queries_by_id: Dictionary = {}


func is_loaded() -> bool:
	return _loaded


func is_generating_any_card() -> bool:
	return not _generating_by_id.is_empty()


func get_active_generation_ids() -> Array[String]:
	var result: Array[String] = []

	for id in _generating_by_id.keys():
		result.append(str(id))

	return result


func get_active_generation_queries() -> Array[String]:
	var result: Array[String] = []

	for query in _generating_queries_by_id.values():
		result.append(str(query))

	return result


func is_generating_card(card_id: String) -> bool:
	card_id = card_id.strip_edges()
	return _generating_by_id.has(card_id)


func is_generating_query(query: String) -> bool:
	var predicted_id := normalize_card_id(query)
	return is_generating_card(predicted_id)


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


func has_card(card_id: String) -> bool:
	card_id = card_id.strip_edges()
	return _cards_by_id.has(card_id)


func has_matching_card(query: String) -> bool:
	var clean_query := query.strip_edges().to_lower()

	if clean_query.is_empty():
		return false

	var normalized_query := normalize_card_id(clean_query)

	for card in _cards_by_id.values():
		if not (card is PlanetData):
			continue

		var planet := card as PlanetData

		if planet.instance_id.strip_edges().to_lower() == normalized_query:
			return true

		if planet.name.strip_edges().to_lower() == clean_query:
			return true

		if normalize_card_id(planet.name) == normalized_query:
			return true

	return false


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


func add_or_update_card(card: PlanetData) -> void:
	if card == null:
		return

	var id := card.instance_id.strip_edges()

	if id == "":
		return

	_cards_by_id[id] = card
	_loaded = true
	cards_changed.emit(get_all_cards())


func save_card(card: PlanetData) -> Dictionary:
	if card == null:
		return {
			"success": false,
			"error": "NULL_CARD"
		}

	var result: Dictionary = await FirebaseDatabase.save_planet_card(card)

	if not result.get("success", false):
		return result

	add_or_update_card(card)

	return result


func generate_card_in_background(query: String) -> bool:
	query = query.strip_edges()

	if query.length() < 2:
		return false

	var predicted_id := normalize_card_id(query)

	if predicted_id.is_empty():
		return false

	if _generating_by_id.has(predicted_id):
		return false

	if has_matching_card(query):
		return false

	_generating_by_id[predicted_id] = true
	_generating_queries_by_id[predicted_id] = query
	card_generation_started.emit(query, predicted_id)

	_generate_card_background_task(query, predicted_id)

	return true


func _generate_card_background_task(query: String, predicted_id: String) -> void:
	var result: Dictionary = await _request_generated_card(query)

	if not result.get("success", false):
		_generating_by_id.erase(predicted_id)
		_generating_queries_by_id.erase(predicted_id)
		card_generation_failed.emit(query, str(result.get("error", "GENERATION_FAILED")))
		return

	var raw_card: Variant = result.get("card", null)

	if not (raw_card is Dictionary):
		_generating_by_id.erase(predicted_id)
		_generating_queries_by_id.erase(predicted_id)
		card_generation_failed.emit(query, "INVALID_CARD_RESPONSE")
		return

	var card := PlanetData.from_firebase_dict(raw_card)

	if card.instance_id.strip_edges().is_empty():
		card.instance_id = str(result.get("cardId", predicted_id)).strip_edges()

	if card.instance_id.strip_edges().is_empty():
		card.instance_id = predicted_id

	var save_result: Dictionary = await save_card(card)

	_generating_by_id.erase(predicted_id)
	_generating_queries_by_id.erase(predicted_id)

	if not save_result.get("success", false):
		card_generation_failed.emit(query, str(save_result.get("error", "SAVE_FAILED")))
		return

	card_generation_finished.emit(card)


func _request_generated_card(query: String) -> Dictionary:
	if not FirebaseDatabase.has_method("generate_planet_card"):
		return {
			"success": false,
			"error": "MISSING_FIREBASE_GENERATE_PLANET_CARD_METHOD"
		}

	var result: Variant = await FirebaseDatabase.generate_planet_card(query)

	if result is Dictionary:
		return result

	return {
		"success": false,
		"error": "INVALID_GENERATE_RESPONSE"
	}


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
	_generating_by_id.clear()
	_generating_queries_by_id.clear()
	cards_changed.emit([])


func normalize_card_id(value: String) -> String:
	var result := value.strip_edges().to_lower()
	result = result.replace("'", "")
	result = result.replace("\"", "")
	result = result.replace(" ", "_")
	result = result.replace("-", "_")
	result = result.replace(".", "_")
	result = result.replace(",", "_")
	result = result.replace(":", "_")
	result = result.replace(";", "_")
	result = result.replace("/", "_")
	result = result.replace("\\", "_")

	while result.contains("__"):
		result = result.replace("__", "_")

	return result.strip_edges()

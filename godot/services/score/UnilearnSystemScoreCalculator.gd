extends RefCounted
class_name UnilearnSystemScoreCalculator

const STAT_KEYS := ["habitability", "magnetic_field", "atmosphere", "geology", "gravity", "radiation_safety"]

static func calculate_overall_score(stats: Dictionary, average_level: float = 1.0, max_level: int = 1, object_count: int = 0, star_count: int = 0, moon_count: int = 0) -> int:
	if object_count <= 0:
		return 0
	var weighted := 0.0
	var harmonic_inverse := 0.0
	var weakest := 100.0
	var count := 0.0
	for stat_key in STAT_KEYS:
		var value := float(stats.get(stat_key, 50.0))
		var weight := _overall_stat_weight(stat_key)
		weighted += value * weight
		harmonic_inverse += weight / max(value + 6.0, 1.0)
		weakest = min(weakest, value)
		count += weight
	var mean: float = weighted / max(count, 0.001)
	var harmonic: float = (count / max(harmonic_inverse, 0.001)) - 6.0
	var balance: int = balance_score(stats)
	var base_score := mean * 0.38 + harmonic * 0.34 + weakest * 0.18 + balance * 0.10
	var level_bonus: float = min(sqrt(max(average_level, 1.0)) * 4.0 + sqrt(max(float(max_level), 1.0)) * 2.5, 32.0)
	var architecture_bonus: float = 0.0
	if object_count >= 3:
		architecture_bonus += min(float(object_count - 2) * 1.4, 16.0)
	if moon_count > 0:
		architecture_bonus += min(float(moon_count) * 0.8, 8.0)
	if star_count == 1:
		architecture_bonus += 10.0
	elif star_count == 2:
		architecture_bonus += 5.0
	elif star_count > 2:
		architecture_bonus -= float(star_count - 2) * 14.0
	else:
		architecture_bonus -= 12.0
	return clampi(roundi(base_score + level_bonus + architecture_bonus), 0, 100)

static func balance_score(stats: Dictionary) -> int:
	var values: Array[float] = []
	for stat_key in STAT_KEYS:
		values.append(float(stats.get(stat_key, 50.0)))
	var mean := 0.0
	for v in values: mean += v
	mean /= max(float(values.size()), 1.0)
	var variance := 0.0
	for v in values: variance += pow(v - mean, 2.0)
	variance /= max(float(values.size()), 1.0)
	return clampi(roundi(100.0 - sqrt(variance) * 1.65), 0, 100)

static func grade_for_score(score: int) -> String:
	if score <= 0: return "--"
	if score >= 98: return "Ω"
	if score >= 94: return "SSS"
	if score >= 90: return "SS"
	if score >= 84: return "S+"
	if score >= 78: return "S"
	if score >= 68: return "A"
	if score >= 58: return "B"
	if score >= 48: return "C"
	if score >= 35: return "D"
	return "E"

static func _overall_stat_weight(stat_key: String) -> float:
	match stat_key:
		"habitability": return 1.12
		"radiation_safety": return 1.08
		"gravity": return 1.02
		_: return 1.0

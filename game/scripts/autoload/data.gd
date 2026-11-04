extends Node
## Every balance number and every list of things in the game, read from game/data.

var balance := {}
var motifs := {}
var motif_order: Array = []
var borders := {}
var border_order: Array = []
var rooms := {}
var clients := {}
var client_order: Array = []
var chapters: Array = []
var upgrades := {}
var upgrade_order: Array = []
var names := {}


func _ready() -> void:
	reload()


func reload() -> void:
	balance = _read("balance.json", {})
	var m := _by_id(_read("motifs.json", []))
	motifs = m[0]
	motif_order = m[1]
	var b := _by_id(_read("borders.json", []))
	borders = b[0]
	border_order = b[1]
	rooms = _by_id(_read("rooms.json", []))[0]
	var c := _by_id(_read("clients.json", []))
	clients = c[0]
	client_order = c[1]
	chapters = _read("chapters.json", [])
	var u := _by_id(_read("upgrades.json", []))
	upgrades = u[0]
	upgrade_order = u[1]
	names = _read("names.json", {})


## A balance number by its dotted path, such as "pricing.falloff".
func num(path: String, fallback: float = 0.0) -> float:
	var v = value(path, fallback)
	return float(v) if (v is float or v is int) else fallback


func value(path: String, fallback = null):
	var node = balance
	for part in path.split("."):
		if node is Dictionary and node.has(part):
			node = node[part]
		else:
			return fallback
	return node


func motif(id: String) -> Dictionary:
	return motifs.get(id, {})


func room(id: String) -> Dictionary:
	return rooms.get(id, {})


func client(id: String) -> Dictionary:
	return clients.get(id, {})


func chapter(n: int) -> Dictionary:
	return chapters[n - 1] if n >= 1 and n <= chapters.size() else {}


func stone_price(id: String) -> float:
	return float(value("stone_price." + id, 5)) / num("sack", 100)


func _read(file: String, fallback):
	var path := "res://data/" + file
	if not FileAccess.file_exists(path):
		return fallback
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		push_error("could not read " + path)
		return fallback
	return parsed


func _by_id(list) -> Array:
	var d := {}
	var order := []
	if list is Array:
		for item in list:
			d[item["id"]] = item
			order.append(item["id"])
	return [d, order]

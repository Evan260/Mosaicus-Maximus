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
var achievements: Array = []
var festivals: Array = []
## Everyone in town who isn't a regular client, each with a name, a face and, for the townsfolk, a trade.
var people := {}


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
	achievements = _read("achievements.json", [])
	festivals = _read("festivals.json", [])
	people = _read("people.json", {})


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


## A motif's name as a title, in the player's language.
func motif_title(id: String) -> String:
	return tr(str(motif(id).get("name", id)))


## A motif's name inside a sentence, in the player's language.
func motif_name(id: String) -> String:
	return tr(motif_lower(id))


## A motif's English name inside a sentence, the key of its translation: lower case, unless it keeps its capitals.
func motif_lower(id: String) -> String:
	var m := motif(id)
	return str(m.get("lower", str(m.get("name", id)).to_lower()))


## A motif's English name with "a" or "an" in front, or as it is said when it takes neither, like "loaves".
func motif_with_article(id: String) -> String:
	var m := motif(id)
	if m.has("a"):
		return str(m["a"])
	var name := motif_lower(id)
	return ("an " if name.left(1) in ["a", "e", "i", "o", "u"] else "a ") + name


## A motif's name with its article, in the player's language: "a dolphin".
func motif_a(id: String) -> String:
	return tr(motif_with_article(id))


## A room's name as a title, and inside a sentence, in the player's language.
func room_title(id: String) -> String:
	return tr(str(room(id).get("name", id)))


func room_name(id: String) -> String:
	return tr(str(room(id).get("name", id)).to_lower())


func border_title(id: String) -> String:
	return tr(str(borders.get(id, {}).get("name", id)))


func border_name(id: String) -> String:
	return tr(str(borders.get(id, {}).get("name", id)).to_lower())


## The rooms clients can ask for: every room but the bench's square for picture panels, and without walls when asked.
func job_rooms(walls := true) -> Array:
	return rooms.keys().filter(func(id: String) -> bool: return not bool(rooms[id].get("bench", false)) and (walls or not bool(rooms[id].get("wall", false))))


## A person's portrait, or until it is painted, one of the two old townsfolk faces of the same sex.
func face(person: Dictionary) -> String:
	var id := str(person.get("portrait", person.get("id", "")))
	if ResourceLoader.exists("res://assets/art/portraits/%s.png" % id):
		return id
	var second := absi(hash(id)) % 2 == 1
	if bool(person.get("woman", false)):
		return "towns_4" if second else "towns_2"
	return "towns_3" if second else "towns_1"


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

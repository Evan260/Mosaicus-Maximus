class_name Stones
## The stones the workshop lays. Design maps use each stone's exact map colour, and saved designs use its id.

enum Kind { LIMESTONE, BLACK_STONE, TERRACOTTA, MARBLE, GLASS, GOLD }

const NO_TILE := 255  # label for floor outside the room's shape, where nothing is laid
const NO_TILE_COLOUR := Color8(255, 0, 255)

const LIST := [
	{"id": "limestone", "name": "Limestone", "map": Color8(226, 214, 188), "tile": Color8(224, 210, 180), "material": Kind.LIMESTONE, "ground": true, "tier": 1},
	{"id": "black_stone", "name": "Black stone", "map": Color8(44, 40, 42), "tile": Color8(50, 46, 48), "material": Kind.BLACK_STONE, "ground": false, "tier": 1},
	{"id": "white_marble", "name": "White marble", "map": Color8(240, 236, 226), "tile": Color8(240, 234, 222), "material": Kind.MARBLE, "ground": true, "tier": 1},
	{"id": "grey_stone", "name": "Grey stone", "map": Color8(138, 132, 124), "tile": Color8(140, 134, 126), "material": Kind.LIMESTONE, "ground": false, "tier": 1},
	{"id": "terracotta", "name": "Terracotta", "map": Color8(168, 86, 54), "tile": Color8(172, 88, 56), "material": Kind.TERRACOTTA, "ground": false, "tier": 2},
	{"id": "red_marble", "name": "Red marble", "map": Color8(146, 50, 46), "tile": Color8(152, 54, 48), "material": Kind.MARBLE, "ground": false, "tier": 2},
	{"id": "ochre_marble", "name": "Ochre marble", "map": Color8(200, 148, 66), "tile": Color8(206, 152, 70), "material": Kind.MARBLE, "ground": false, "tier": 2},
	{"id": "green_marble", "name": "Green marble", "map": Color8(86, 112, 70), "tile": Color8(90, 118, 74), "material": Kind.MARBLE, "ground": false, "tier": 2},
	{"id": "brown_stone", "name": "Brown stone", "map": Color8(112, 76, 52), "tile": Color8(116, 80, 54), "material": Kind.LIMESTONE, "ground": false, "tier": 2},
	{"id": "pink_marble", "name": "Pink marble", "map": Color8(222, 168, 140), "tile": Color8(226, 172, 144), "material": Kind.MARBLE, "ground": false, "tier": 3},
	{"id": "wine_marble", "name": "Wine-red marble", "map": Color8(104, 34, 34), "tile": Color8(110, 38, 38), "material": Kind.MARBLE, "ground": false, "tier": 3},
	{"id": "yellow_marble", "name": "Yellow marble", "map": Color8(226, 200, 98), "tile": Color8(230, 204, 104), "material": Kind.MARBLE, "ground": false, "tier": 3},
	{"id": "blue_glass", "name": "Blue glass", "map": Color8(54, 92, 136), "tile": Color8(50, 96, 150), "material": Kind.GLASS, "ground": false, "tier": 4},
	{"id": "turquoise_glass", "name": "Turquoise glass", "map": Color8(64, 150, 150), "tile": Color8(60, 156, 158), "material": Kind.GLASS, "ground": false, "tier": 4},
	{"id": "green_glass", "name": "Green glass", "map": Color8(60, 126, 74), "tile": Color8(58, 136, 80), "material": Kind.GLASS, "ground": false, "tier": 4},
	{"id": "gold", "name": "Gold", "map": Color8(212, 174, 74), "tile": Color8(226, 186, 82), "material": Kind.GOLD, "ground": false, "tier": 4},
]

static var _by_id := {}


static func lookup() -> Dictionary:
	var by_colour := {}
	for i in LIST.size():
		var c: Color = LIST[i]["map"]
		by_colour[(c.r8 << 16) | (c.g8 << 8) | c.b8] = i
	by_colour[(255 << 16) | 255] = NO_TILE
	return by_colour


## The stone among the allowed ones that looks most like this one, or the stone itself when it is allowed.
static func nearest(id: String, allowed: Array) -> String:
	if id in allowed or allowed.is_empty():
		return id
	var best: String = allowed[0]
	for other in allowed:
		if difference(id, other) < difference(id, best):
			best = other
	return best


## A stone's name as a title, and inside a sentence, in the player's language.
static func title(id: String) -> String:
	return TranslationServer.translate(str(LIST[index(id)]["name"]))


static func lower(id: String) -> String:
	return TranslationServer.translate(str(LIST[index(id)]["name"]).to_lower())


static func index(id: String) -> int:
	if _by_id.is_empty():
		for i in LIST.size():
			_by_id[LIST[i]["id"]] = i
	return _by_id.get(id, 0)


static func id_of(i: int) -> String:
	return LIST[i]["id"]


static func map_colour(id: String) -> Color:
	return LIST[index(id)]["map"]


static func is_ground(stone: int) -> bool:
	return stone != NO_TILE and LIST[stone]["ground"]


## How unlike two stones look, from 0 (the same) to about 1 (black against white), for scoring repairs.
static func difference(a: String, b: String) -> float:
	var ca: Color = LIST[index(a)]["tile"]
	var cb: Color = LIST[index(b)]["tile"]
	return Vector3(ca.r - cb.r, ca.g - cb.g, ca.b - cb.b).length() / sqrt(3.0)

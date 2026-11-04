class_name FloorDesign
extends RefCounted
## One floor's design: the room it fills, the ground stone, the border, and every motif placed on it.

var room := ""
var w := 40
var h := 28
var shape := "rect"
var pool: Array = []  # left, top, width and height of a pool as shares of the room, for rooms with one
var ground := "limestone"
var border := {"id": "", "width": 0, "margin": 1, "stones": []}
## Each placement: {motif, x, y (centre in tiles), size (longest side in tiles), rot (quarter turns), flip, stones (role to stone id)}.
var placements: Array = []


static func for_room(room_id: String) -> FloorDesign:
	var d := FloorDesign.new()
	var r := Data.room(room_id)
	d.room = room_id
	d.w = int(r.get("w", 40))
	d.h = int(r.get("h", 28))
	d.shape = str(r.get("shape", "rect"))
	d.pool = r.get("pool", [])
	return d


func room_data() -> Dictionary:
	return {"shape": shape, "pool": pool}


## Adds a motif with the stones it starts with, centred where asked. Returns the new placement.
func add(motif_id: String, x: float, y: float, size: float, rot: int = 0, flip: bool = false) -> Dictionary:
	var m := Data.motif(motif_id)
	var stones := {}
	for k in m.get("stones", {}):
		stones[k] = m["stones"][k]
	var p := {"motif": motif_id, "x": x, "y": y, "size": size, "rot": rot, "flip": flip, "stones": stones, "outline": m.get("outline", "")}
	placements.append(p)
	return p


func set_border(border_id: String) -> void:
	if border_id == "":
		border = {"id": "", "width": 0, "margin": 1, "stones": []}
		return
	var b: Dictionary = Data.borders.get(border_id, {})
	border = {"id": border_id, "width": int(b.get("width", 3)), "margin": 1, "stones": (b.get("stones", []) as Array).duplicate()}


## Every stone the design uses, for checking it against what the player has unlocked.
func stones_used() -> Array:
	var out := [ground]
	for s in border.get("stones", []):
		if border.get("id", "") != "" and not s in out:
			out.append(s)
	for p in placements:
		for s in p["stones"].values():
			if not s in out:
				out.append(s)
		if p.get("outline", "") != "" and not p["outline"] in out:
			out.append(p["outline"])
	return out


func to_dict() -> Dictionary:
	return {"room": room, "w": w, "h": h, "shape": shape, "pool": pool, "ground": ground, "border": border.duplicate(true), "placements": placements.duplicate(true)}


static func from_dict(d: Dictionary) -> FloorDesign:
	var f := FloorDesign.new()
	f.room = str(d.get("room", ""))
	f.w = int(d.get("w", 40))
	f.h = int(d.get("h", 28))
	f.shape = str(d.get("shape", "rect"))
	f.pool = d.get("pool", [])
	f.ground = str(d.get("ground", "limestone"))
	f.border = (d.get("border", f.border) as Dictionary).duplicate(true)
	f.placements = (d.get("placements", []) as Array).duplicate(true)
	return f

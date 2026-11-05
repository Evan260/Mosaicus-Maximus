"""Paint the clients' rooms the reveal shows a finished floor in, one painting per kind of room.

Each room is a cutaway seen from above the front, like a dollhouse: a back wall, two side walls and the floor. The script
draws that shape itself, in the room's own proportions, so the floor's four corners are known exactly. PixelLab then
paints the walls and, one at a time, the furniture standing against them; the floor is never repainted, and where it
still shows the painting is left clear so the game can lay the player's floor there in perspective.

Usage: python tools/art/make_rooms.py [room ...]
Writes tools/art/sources/rooms/<room>_*.png while it works, and game/assets/art/rooms/<room>.png and rooms.json.
"""
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "game"
SRC = ROOT / "tools" / "art" / "sources" / "rooms"
OUT = GAME / "assets" / "art" / "rooms"
W, H = 240, 136
SCALE = 2

# The camera: the vanishing point sits right of centre to leave room for the client on the left, and above the picture,
# so the room is seen from above its walls.
VX = 152
HORIZON = -60
FRONT_Y = 132
FRONT_W = 144
FOCAL = 240
WALL_HEIGHT = 0.55

VOID = (34, 27, 24)
PLASTER = (200, 168, 128)
EDGE = (222, 204, 176)
FLOOR = (172, 158, 134)
STYLE = "ancient Roman house interior, seen from above the front like a dollhouse cutaway, warm cozy pixel art, soft daylight"

# For each room: what its walls look like, and the furniture painted in one piece at a time, each as a box in floor
# terms: left and right across the back wall from 0 to 1, how high it stands as a share of the wall, and how far it
# reaches onto the floor as a share of the floor's depth.
ROOMS = {
    "study": {
        "walls": "the walls painted with deep red fresco panels framed by black and ochre bands, a small window with open wooden shutters in the back wall",
        "furniture": [
            ("desk", (0.06, 0.42, 0.55, 0.14), "a big Roman wooden writing desk filling the whole area, standing on the floor against the back wall, covered with rolled scrolls, wax tablets and an inkwell"),
            ("cupboard", (0.69, 0.96, 0.95, 0.12), "a tall wooden cupboard filling the whole area, standing on the floor against the back wall, its open doors showing shelves packed with rolled parchment scrolls"),
        ],
    },
    "dining_room": {
        "walls": "the walls painted with black fresco panels framed in red and gold bands, with painted garlands and little birds",
        "furniture": [
            ("couch", (0.05, 0.58, 0.45, 0.10), "a Roman dining couch like a wide wooden daybed with a thick red mattress and plump cushions, filling the whole area, standing on the floor against the back wall"),
            ("sideboard", (0.70, 0.95, 0.75, 0.12), "a tall bronze lampstand beside a wooden sideboard with silver jugs, filling the whole area, standing on the floor against the back wall"),
        ],
    },
    "vestibule": {
        "walls": "the walls painted with pale ochre and white fresco panels with thin red lines, a tall wooden double door in the middle of the back wall",
        "furniture": [
            ("bench", (0.05, 0.34, 0.40, 0.12), "a long stone bench filling the whole area, standing on the floor against the back wall"),
            ("plant", (0.72, 0.94, 0.75, 0.12), "a tall potted laurel tree in a big terracotta pot filling the whole area, standing on the floor against the back wall"),
        ],
    },
    "bedroom": {
        "walls": "the walls painted with soft yellow fresco panels with small painted birds and garlands, a small high window in the back wall",
        "furniture": [
            ("bed", (0.06, 0.55, 0.55, 0.22), "a Roman wooden bed with a striped woollen blanket and cushions filling the whole area, standing on the floor against the back wall"),
            ("chest", (0.70, 0.94, 0.40, 0.12), "a wooden clothes chest with bronze fittings filling the whole area, standing on the floor against the back wall"),
        ],
    },
    # The shop borrows the bakery's bare walls, with their table and wine jar: the two rooms are the same shape to within
    # a pixel. A walls description of its own, with furniture, takes their place once it is painted.
    "shop": {
        "walls_from": "bakery",
        "furniture": [],
    },
    "bakery": {
        "walls": "the walls of warm plastered brick with a simple red band, a small window in the back wall",
        "furniture": [
            ("oven", (0.04, 0.44, 0.85, 0.22), "a big round brick bread oven built out from the back wall into the room, a solid 3D dome seen from above so its rounded top and curved side show, a dark arched mouth with a glowing fire, standing on the floor and casting a shadow on it, filling the whole area"),
            ("table", (0.58, 0.94, 0.45, 0.16), "a wooden baker's table filling the whole area, standing on the floor against the back wall, covered with round loaves of bread"),
        ],
    },
    "tavern": {
        "walls": "the walls of rough plaster painted dull red, with wine jugs hanging on pegs and a painted price list on the wall",
        "furniture": [
            ("bar", (0.04, 0.58, 0.55, 0.20), "a masonry tavern counter with big clay wine jars set into its top filling the whole area, standing on the floor against the back wall"),
            ("jars", (0.70, 0.96, 0.45, 0.16), "a stack of amphorae and a wooden stool filling the whole area, standing on the floor against the back wall"),
        ],
    },
    "changing_room": {
        "walls": "the walls painted white with blue fish and dolphins, a row of small arched niches for clothes along the back wall",
        "furniture": [
            ("bench", (0.05, 0.95, 0.30, 0.12), "a long stone bench running the whole width against the back wall, filling the whole area, with folded towels on it"),
        ],
    },
    "villa_dining": {
        "walls": "grand walls painted with deep red fresco panels between painted columns and little landscapes, a wide doorway in the back wall to a sunny garden",
        "furniture": [
            ("couch", (0.05, 0.55, 0.40, 0.20), "a Roman dining couch with purple cushions and a low marble table with silver dishes, filling the whole area, standing on the floor against the back wall"),
            ("statue", (0.76, 0.95, 0.95, 0.12), "a white marble statue of a goddess on a plinth filling the whole area, standing on the floor against the back wall"),
        ],
    },
}


def room_data():
    return {r["id"]: r for r in json.loads((GAME / "data" / "rooms.json").read_text(encoding="utf-8"))}


def geometry(room):
    """The floor's corners and the walls, from the room's width and depth, in the picture's pixels."""
    aspect = room["w"] / room["h"]
    r = 1.0 + FRONT_W / (aspect * FOCAL)
    back_y = HORIZON + (FRONT_Y - HORIZON) / r
    back_w = FRONT_W / r
    bl, br = (VX - back_w / 2, back_y), (VX + back_w / 2, back_y)
    fl, fr = (VX - FRONT_W / 2, FRONT_Y), (VX + FRONT_W / 2, FRONT_Y)
    up_back, up_front = WALL_HEIGHT * back_w, WALL_HEIGHT * FRONT_W
    return {
        "floor": [bl, br, fr, fl],
        "back": [(bl[0], back_y - up_back), (br[0], back_y - up_back), br, bl],
        "left": [(fl[0], FRONT_Y - up_front), (bl[0], back_y - up_back), bl, fl],
        "right": [(br[0], back_y - up_back), (fr[0], FRONT_Y - up_front), fr, br],
        "back_y": back_y, "back_w": back_w, "up_back": up_back,
    }


def polygon_mask(points):
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).polygon([(round(x), round(y)) for x, y in points], fill=255)
    return m


def base(g):
    img = Image.new("RGB", (W, H), VOID)
    d = ImageDraw.Draw(img)
    for part in ("back", "left", "right"):
        d.polygon([(round(x), round(y)) for x, y in g[part]], fill=PLASTER)
    d.polygon([(round(x), round(y)) for x, y in g["floor"]], fill=FLOOR)
    # The cut tops and front edges of the walls, as a cutaway model shows them.
    for a, b in ((g["left"][0], g["left"][1]), (g["back"][0], g["back"][1]), (g["right"][0], g["right"][1]),
                 (g["left"][0], g["left"][3]), (g["right"][1], g["right"][2])):
        d.line([(round(a[0]), round(a[1])), (round(b[0]), round(b[1]))], fill=EDGE, width=2)
    return img


def walls_mask(g):
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    for part in ("back", "left", "right"):
        d.polygon([(round(x), round(y)) for x, y in g[part]], fill=255)
    for a, b in ((g["left"][0], g["left"][1]), (g["back"][0], g["back"][1]), (g["right"][0], g["right"][1]),
                 (g["left"][0], g["left"][3]), (g["right"][1], g["right"][2])):
        d.line([(round(a[0]), round(a[1])), (round(b[0]), round(b[1]))], fill=0, width=3)
    return m


def furniture_box(g, box):
    x0, x1, up, onto = box
    bl, br, fr, fl = g["floor"]
    left = bl[0] + (br[0] - bl[0]) * x0
    right = bl[0] + (br[0] - bl[0]) * x1
    depth = (fl[1] - bl[1]) * onto
    return (round(left), round(g["back_y"] - g["up_back"] * up), round(right), round(g["back_y"] + depth))


def inpaint(image_path, mask_path, description, out_path):
    for attempt in range(3):
        run = subprocess.run([sys.executable, str(ROOT / "tools" / "art" / "pixellab.py"), "inpaint",
                              str(image_path.relative_to(ROOT)), str(mask_path.relative_to(ROOT)),
                              f"{description}, {STYLE}", "--out", str(out_path.relative_to(ROOT))],
                             cwd=ROOT, capture_output=True, text=True, timeout=300)
        if out_path.exists():
            return
        print(run.stdout[-400:], run.stderr[-400:])
    raise SystemExit(f"could not paint {out_path}")


def floor_alpha(img, g, touched):
    """Clear wherever the plain floor still shows, keep furniture, and keep shadows on it as see-through dark."""
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    inside = np.asarray(polygon_mask(g["floor"])) > 0
    base_c = np.array(FLOOR, np.float32)
    diff = np.abs(a - base_c).sum(axis=2)
    shade = a.sum(axis=2) / base_c.sum()
    hue = np.abs(a / np.maximum(a.sum(axis=2, keepdims=True), 1) - base_c / base_c.sum()).sum(axis=2)
    alpha = np.full((H, W), 255, np.float32)
    colour = a.copy()
    plain = inside & ((diff < 30) | ~touched)
    alpha[plain] = 0
    shadow = inside & touched & ~plain & (hue < 0.05) & (shade < 1.0)
    alpha[shadow] = np.clip((1.0 - shade[shadow]) * 255 * 1.4, 0, 200)
    colour[shadow] = (12, 8, 6)
    out = np.dstack([colour, alpha]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def make(room_id, info):
    room = room_data()[room_id]
    g = geometry(room)
    SRC.mkdir(parents=True, exist_ok=True)
    step = SRC / f"{room_id}_0.png"
    if not step.exists():
        base(g).save(step)
    mask = SRC / f"{room_id}_mask_walls.png"
    walls_mask(g).save(mask)
    walled = SRC / f"{info.get('walls_from', room_id)}_1.png"
    if not walled.exists():
        inpaint(step, mask, info["walls"], walled)
    current = walled
    touched = np.zeros((H, W), bool)
    for n, (name, box, description) in enumerate(info["furniture"], 2):
        x0, y0, x1, y1 = furniture_box(g, box)
        m = Image.new("L", (W, H), 0)
        ImageDraw.Draw(m).rectangle((x0, y0, x1, y1), fill=255)
        mask = SRC / f"{room_id}_mask_{name}.png"
        m.save(mask)
        touched |= np.asarray(m) > 0
        nxt = SRC / f"{room_id}_{n}.png"
        if not nxt.exists():
            inpaint(current, mask, description, nxt)
        current = nxt
    # The walls step keeps the floor as it was, so only furniture can stand on it.
    painted = Image.open(current).convert("RGB")
    cut = floor_alpha(painted, g, touched)
    OUT.mkdir(parents=True, exist_ok=True)
    cut.resize((W * SCALE, H * SCALE), Image.NEAREST).save(OUT / f"{room_id}.png")
    return {"floor": [[round(x * SCALE, 1), round(y * SCALE, 1)] for x, y in g["floor"]], "size": [W * SCALE, H * SCALE]}


def main():
    wanted = sys.argv[1:] or list(ROOMS)
    layout_path = OUT / "rooms.json"
    layout = json.loads(layout_path.read_text(encoding="utf-8")) if layout_path.exists() else {}
    for room_id in wanted:
        layout[room_id] = make(room_id, ROOMS[room_id])
        print("made", room_id)
    layout_path.write_text(json.dumps(layout, indent="\t"), encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()

"""Generate and clean up game art with the PixelLab API.

Usage examples (run from the project folder):
  python tools/art/pixellab.py balance
  python tools/art/pixellab.py pixen "lavender bush in bloom" 32x32 --out game/assets/sprites/lavender/bloom.png --transparent
  python tools/art/pixellab.py character "small farm dog" 48x48 --template dog --out-dir game/assets/sprites/dog
  python tools/art/pixellab.py animate CHARACTER_ID "walking calmly" --frames 8 --direction east --out-dir game/assets/sprites/dog/walk
  python tools/art/pixellab.py slice sheet.png 32x32 --out-dir game/assets/sprites/lavender/variants
  python tools/art/pixellab.py clean sprite.png --min-area 40
"""

import argparse
import base64
import csv
import datetime
import io
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
API = "https://api.pixellab.ai/v2"
LEDGER = Path(__file__).with_name("ledger.csv")
STYLE = ("flat colour Roman floor mosaic emblem, bold simple shapes, few colours, crisp outline")


def token():
    for line in (ROOT / ".env").read_text().splitlines():
        if line.startswith("PIXELLAB_TOKEN="):
            return line.split("=", 1)[1].strip()
    sys.exit("PIXELLAB_TOKEN missing from .env")


def call(method, path, body=None):
    req = urllib.request.Request(
        API + path, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            return json.loads(r.read() or b"null")
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code}: {e.read().decode()[:1500]}")


def balance():
    b = call("GET", "/balance")
    return b["credits"]["usd"], b["subscription"].get("generations", 0)


def record(kind, name, before, after):
    # The ledger shows what each asset really cost, since PixelLab's listed prices are only estimates.
    new = not LEDGER.exists()
    usd = before[0] - after[0]
    gens = before[1] - after[1]
    with LEDGER.open("a", newline="") as f:
        w = csv.writer(f)
        if new:
            w.writerow(["time", "kind", "name", "cost_usd", "cost_generations", "usd_left"])
        w.writerow([datetime.datetime.now().isoformat(timespec="seconds"), kind, name,
                    f"{usd:.4f}", f"{gens:g}", f"{after[0]:.4f}"])
    print(f"cost: ${usd:.4f} and {gens:g} generations  (balance ${after[0]:.2f})")


def wait(job_id, every=8, limit=1500):
    start = time.time()
    while time.time() - start < limit:
        job = call("GET", f"/background-jobs/{job_id}")
        if job.get("status") != "processing":
            return job
        time.sleep(every)
    sys.exit(f"job {job_id} timed out")


def download(url, path):
    # The file host rejects Python's default user agent, so curl does the download.
    subprocess.run(["curl", "-s", "-f", "-o", str(path), url], check=True)


def size(text):
    w, h = text.lower().split("x")
    return {"width": int(w), "height": int(h)}


def save_b64(data, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.open(io.BytesIO(base64.b64decode(data))).convert("RGBA").save(path)
    print("saved", path)


def cmd_balance(a):
    usd, gens = balance()
    print(f"credits: ${usd:.4f}   subscription generations: {gens}")


def cmd_pixen(a):
    before = balance()
    body = {"description": a.description if a.raw else f"{a.description}, {STYLE}",
            "image_size": size(a.size), "no_background": a.transparent,
            "view": a.view, "outline": a.outline, "detail": a.detail}
    if a.direction:
        body["direction"] = a.direction
    if a.seed is not None:
        body["seed"] = a.seed
    r = call("POST", "/create-image-pixen", body)
    save_b64(r["image"]["base64"], ROOT / a.out)
    record("pixen", a.out, before, balance())


def cmd_character(a):
    before = balance()
    if a.style:
        r = call("POST", "/create-character-pro-flash", {
            "description": a.description, "image_size": size(a.size), "template_id": a.template,
            "view": a.view, "n_directions": 8, "style_image": style_ref(a.style, a.style_use, *size(a.size).values())})
    else:
        r = call("POST", "/create-character-v3", {
            "description": a.description, "image_size": size(a.size), "template_id": a.template,
            "view": a.view, "outline": a.outline, "detail": a.detail})
    job = wait(r["background_job_id"])
    if job.get("status") != "completed":
        sys.exit(json.dumps(job)[:1500])
    out = ROOT / a.out_dir
    out.mkdir(parents=True, exist_ok=True)
    for direction, url in job["last_response"]["storage_urls"].items():
        download(url, out / f"{direction}.png")
    (out / "character.json").write_text(json.dumps({"character_id": r["character_id"]}, indent=2))
    print("character_id:", r["character_id"])
    record("character", a.out_dir, before, balance())


def cmd_animate(a):
    before = balance()
    r = call("POST", "/animate-character", {
        "character_id": a.character_id, "mode": "pixminimax", "action_description": a.action,
        "frame_count": a.frames, "directions": [a.direction]})
    out = ROOT / a.out_dir
    for job_id in r.get("background_job_ids", []):
        job = wait(job_id, every=10)
        if job.get("status") != "completed":
            sys.exit(json.dumps(job)[:1500])
        for i, img in enumerate(job["last_response"]["images"]):
            save_b64(img["base64"], out / f"frame_{i:02d}.png")
    record("animate", a.out_dir, before, balance())


def b64(path):
    return {"type": "base64", "base64": base64.b64encode((ROOT / path).read_bytes()).decode()}


def sized(path):
    w, h = Image.open(ROOT / path).size
    return {"image": b64(path), "size": {"width": w, "height": h}}


def first_image(payload):
    if isinstance(payload, dict):
        if "base64" in payload and isinstance(payload["base64"], str):
            return payload["base64"]
        for key in ("image", "images", "last_response", "result", "output"):
            if key in payload:
                found = first_image(payload[key])
                if found:
                    return found
    if isinstance(payload, list):
        for item in payload:
            found = first_image(item)
            if found:
                return found
    return None


def png_b64(im):
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode()}


def tiles(box, limit=256):
    # Pro Flash inpaints at most 256 pixels per side, so larger areas are split into overlapping tiles.
    x0, y0, x1, y1 = box
    step = max(limit // 2, limit - 32)
    xs = list(range(x0, max(x0 + 1, x1 - limit + 1), step)) or [x0]
    ys = list(range(y0, max(y0 + 1, y1 - limit + 1), step)) or [y0]
    if xs[-1] + limit < x1:
        xs.append(x1 - limit)
    if ys[-1] + limit < y1:
        ys.append(y1 - limit)
    return [(x, y) for y in ys for x in xs]


def context_around(image, rect):
    """The surroundings sent with a tile: PixelLab takes at most three times the tile on each side, so larger
    pictures are cropped around the tile, never rescaled."""
    W, H = image.size
    tx, ty, x1, y1 = rect
    tw, th = x1 - tx, y1 - ty
    cw, ch = min(W, 3 * tw), min(H, 3 * th)
    cx = min(max(0, tx + tw // 2 - cw // 2), W - cw)
    cy = min(max(0, ty + th // 2 - ch // 2), H - ch)
    return {"context_image": png_b64(image.crop((cx, cy, cx + cw, cy + ch))),
            "bounding_box": {"x": tx - cx, "y": ty - cy, "width": tw, "height": th}}


def cmd_inpaint(a):
    before = balance()
    image = Image.open(ROOT / a.image).convert("RGBA")
    mask = Image.open(ROOT / a.mask).convert("L").point(lambda v: 255 if v > 127 else 0)
    bx = mask.getbbox()
    if not bx:
        sys.exit("mask is empty")
    W, H = image.size
    # PixelLab repaints areas from 32 to 256 pixels a side, so a thin area is sent with some of its surroundings.
    least = size(a.tile) if a.tile else {"width": 32, "height": 32}
    tw = min(256, max(least["width"], (bx[2] - bx[0] + 3) // 4 * 4), W // 4 * 4)
    th = min(256, max(least["height"], (bx[3] - bx[1] + 3) // 4 * 4), H // 4 * 4)
    done = Image.new("L", image.size, 0)
    for tx, ty in tiles(bx, max(tw, th)):
        tx = min((max(0, tx) + 3) // 4 * 4, (W - tw) // 4 * 4)
        ty = min((max(0, ty) + 3) // 4 * 4, (H - th) // 4 * 4)
        rect = (tx, ty, tx + tw, ty + th)
        todo = ((np.asarray(mask.crop(rect)) > 0) & (np.asarray(done.crop(rect)) == 0)).astype(np.uint8) * 255
        if not todo.any():
            continue
        tile_mask = Image.fromarray(todo).convert("RGB")
        r = call("POST", "/inpaint-image-pro-flash", {
            "image": png_b64(image.crop(rect)), "mask_image": png_b64(tile_mask),
            "description": a.description, "no_background": a.transparent,
            "output_method": "Modify current layer",
            **({} if a.no_context else context_around(image, rect))})
        job = wait(r["background_job_id"]) if "background_job_id" in r else r
        data = first_image(job.get("last_response", job))
        if not data:
            sys.exit(json.dumps(job)[:1500])
        result = Image.open(io.BytesIO(base64.b64decode(data))).convert("RGBA").resize((tw, th), Image.NEAREST)
        image.paste(result, (tx, ty), Image.fromarray(todo))
        done.paste(255, rect, Image.fromarray(todo))
        print(f"inpainted tile {rect}")
    out = ROOT / a.out
    out.parent.mkdir(parents=True, exist_ok=True)
    image.save(out)
    print("saved", out)
    record("inpaint", a.out, before, balance())


def style_ref(path, what, max_w=256, max_h=256):
    # PixelLab rejects a style image larger than the output canvas, so it is cropped to fit.
    im = Image.open(ROOT / path).convert("RGBA")
    w, h = min(max_w, im.width // 4 * 4), min(max_h, im.height // 4 * 4)
    im = im.crop((0, 0, w, h))
    return {"image": png_b64(im), "size": {"width": w, "height": h}, "usage_description": what}


def cmd_proflash(a):
    before = balance()
    body = {"description": a.description, "image_size": size(a.size), "no_background": a.transparent}
    if a.style:
        body["style_image"] = style_ref(a.style, a.style_use, *size(a.size).values())
    if a.seed is not None:
        body["seed"] = a.seed
    r = call("POST", "/create-image-pro-flash", body)
    job = wait(r["background_job_id"]) if "background_job_id" in r else r
    data = first_image(job.get("last_response", job))
    if not data:
        sys.exit(json.dumps(job)[:1500])
    save_b64(data, ROOT / a.out)
    record("proflash", a.out, before, balance())


def cmd_ui(a):
    before = balance()
    r = call("POST", "/generate-ui-v2", {"description": a.description, "image_size": size(a.size),
                                         "no_background": True, "color_palette": a.palette})
    job = wait(r["background_job_id"]) if "background_job_id" in r else r
    data = first_image(job.get("last_response", job))
    if not data:
        sys.exit(json.dumps(job)[:1500])
    save_b64(data, ROOT / a.out)
    record("ui", a.out, before, balance())


def cmd_edit(a):
    before = balance()
    im = Image.open(ROOT / a.image).convert("RGBA")
    r = call("POST", "/edit-image-pixen", {"image": png_b64(im), "description": a.description,
                                           "no_background": True})
    job = wait(r["background_job_id"]) if "background_job_id" in r else r
    data = first_image(job.get("last_response", job))
    if not data:
        sys.exit(json.dumps(job)[:1500])
    save_b64(data, ROOT / a.out)
    record("edit", a.out, before, balance())


def cmd_slice(a):
    sheet = Image.open(ROOT / a.sheet).convert("RGBA")
    cw, ch = size(a.cell).values()
    out = ROOT / a.out_dir
    out.mkdir(parents=True, exist_ok=True)
    n = 0
    for y in range(0, sheet.height - ch + 1, ch):
        for x in range(0, sheet.width - cw + 1, cw):
            cell = sheet.crop((x, y, x + cw, y + ch))
            if cell.getchannel("A").getbbox():
                cell.save(out / f"{a.prefix}_{n:02d}.png")
                n += 1
    print(f"saved {n} cells to {out}")


def cmd_clean(a):
    path = ROOT / a.image
    arr = np.asarray(Image.open(path).convert("RGBA")).copy()
    n, labels, stats, _ = cv2.connectedComponentsWithStats((arr[:, :, 3] > 0).astype(np.uint8), 8)
    removed = 0
    for i in range(1, n):
        if stats[i][4] < a.min_area:
            arr[labels == i, 3] = 0
            removed += 1
    Image.fromarray(arr, "RGBA").save(path)
    print(f"removed {removed} stray fragments from {path}")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("balance").set_defaults(fn=cmd_balance)

    s = sub.add_parser("pixen")
    s.add_argument("description")
    s.add_argument("size", help="WIDTHxHEIGHT, multiples of 4")
    s.add_argument("--out", required=True, help="path relative to the project folder")
    s.add_argument("--transparent", action="store_true")
    s.add_argument("--view", default="side", choices=["side", "low top-down", "high top-down"])
    s.add_argument("--direction")
    s.add_argument("--outline", default="lineless")
    s.add_argument("--detail", default="medium detail")
    s.add_argument("--seed", type=int)
    s.add_argument("--raw", action="store_true", help="do not append the shared style ending")
    s.set_defaults(fn=cmd_pixen)

    s = sub.add_parser("character")
    s.add_argument("description")
    s.add_argument("size")
    s.add_argument("--out-dir", required=True)
    s.add_argument("--template", default="mannequin")
    s.add_argument("--view", default="side")
    s.add_argument("--outline", default="lineless")
    s.add_argument("--detail", default="medium detail")
    s.add_argument("--style", help="image whose style to copy (uses Pro Flash)")
    s.add_argument("--style-use", default="match this art style, palette, shading and lighting; no outlines")
    s.set_defaults(fn=cmd_character)

    s = sub.add_parser("animate")
    s.add_argument("character_id")
    s.add_argument("action")
    s.add_argument("--frames", type=int, default=8)
    s.add_argument("--direction", default="east")
    s.add_argument("--out-dir", required=True)
    s.set_defaults(fn=cmd_animate)

    s = sub.add_parser("inpaint", help="repaint the white area of a mask")
    s.add_argument("image")
    s.add_argument("mask", help="white = repaint, black = keep")
    s.add_argument("description")
    s.add_argument("--out", required=True)
    s.add_argument("--transparent", action="store_true")
    s.add_argument("--no-context", action="store_true", help="do not send the full image; use when it contains what is being removed")
    s.add_argument("--tile", help="WIDTHxHEIGHT, the least each tile sent may be, so a thin area is painted seeing more of the picture round it")
    s.set_defaults(fn=cmd_inpaint)

    s = sub.add_parser("proflash", help="Pro Flash image, optionally matching a style reference")
    s.add_argument("description")
    s.add_argument("size", help="WIDTHxHEIGHT, 16 to 256, multiples of 4")
    s.add_argument("--out", required=True)
    s.add_argument("--style", help="image whose style to copy")
    s.add_argument("--style-use", default="match this art style, palette and lighting")
    s.add_argument("--transparent", action="store_true")
    s.add_argument("--seed", type=int)
    s.set_defaults(fn=cmd_proflash)

    s = sub.add_parser("ui", help="interface element such as a panel or button")
    s.add_argument("description")
    s.add_argument("size")
    s.add_argument("--out", required=True)
    s.add_argument("--palette", default="warm cream, terracotta and dark brown")
    s.set_defaults(fn=cmd_ui)

    s = sub.add_parser("edit", help="change an existing sprite with a text instruction")
    s.add_argument("image")
    s.add_argument("description")
    s.add_argument("--out", required=True)
    s.set_defaults(fn=cmd_edit)

    s = sub.add_parser("slice")
    s.add_argument("sheet")
    s.add_argument("cell", help="WIDTHxHEIGHT")
    s.add_argument("--out-dir", required=True)
    s.add_argument("--prefix", default="cell")
    s.set_defaults(fn=cmd_slice)

    s = sub.add_parser("clean")
    s.add_argument("image")
    s.add_argument("--min-area", type=int, default=40)
    s.set_defaults(fn=cmd_clean)

    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()

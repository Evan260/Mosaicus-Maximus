#!/usr/bin/env bash
# Paints the workshop's furniture into the empty room one piece at a time, so each piece shares the room's light.
# Each step reads the one before; the upgrades are painted onto the finished room as separate overlays.
cd "$(dirname "$0")/../.."
D=tools/art/sources/workshop
STYLE="seen straight on from the front, warm cozy pixel art, same style and light as the room"
step() {
	src="$1"; name="$2"; out="$3"; shift 3; desc="$*"
	[ -f "$out" ] && return
	for attempt in 1 2 3; do
		if timeout 280 python tools/art/pixellab.py inpaint "$src" "$D/mask_$name.png" "$desc, $STYLE" --out "$out" 2>&1 | grep -q "cost:"; then
			echo "made $out"; return
		fi
		sleep 8
	done
	echo "FAILED $out"
}
step $D/step1.png shelves $D/step2.png "tall wooden shelves standing on the floor against the wall, filling the whole area, packed with sacks and baskets of colourful mosaic stone tiles in red, white, black, ochre and green"
step $D/step2.png bench $D/step3.png "a sturdy wooden stonemason's workbench standing on the floor against the wall under the window, filling the whole area, a hammer, chisels and little heaps of coloured tiles on top"
step $D/step3.png table $D/step4.png "a big wooden drawing table in the front of the room filling the whole area, its top tilted toward the viewer, an open pattern book of mosaic designs, compasses and wax tablets on it"
step $D/step4.png scrolls $D/step5.png "a wooden wall rack of square pigeonholes hanging on the wall, each holding rolled parchment scrolls, filling the whole area"
step $D/step5.png bed $D/step6.png "a round woven wicker dog basket with a soft folded red woollen blanket inside, on the tiled floor"
step $D/step6.png amphorae $D/up_amphorae.png "three tall clay amphorae standing together on the floor in the corner"
step $D/step6.png plants $D/up_plants.png "two potted green plants in terracotta pots standing on the floor against the wall"
step $D/step6.png lamp_a $D/up_lamp_a.png "a bronze oil lamp hanging from the ceiling beam on a chain, lit with a small warm flame"
step $D/up_lamp_a.png lamp_b $D/up_lamps.png "a bronze oil lamp hanging from the ceiling beam on a chain, lit with a small warm flame"
echo done

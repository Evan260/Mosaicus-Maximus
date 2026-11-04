#!/usr/bin/env bash
# Generates the game's figure art with PixelLab, retrying when the connection drops. Skips files that already exist.
cd "$(dirname "$0")/../.."
gen() {
	out="$1"; size="$2"; view="$3"; shift 3; desc="$*"
	[ -f "$out" ] && return
	for attempt in 1 2 3 4; do
		if timeout 170 python tools/art/pixellab.py pixen "$desc" "$size" --out "$out" --transparent --outline "single color black outline" --detail "medium detail" --view "$view" --raw 2>&1 | grep -q "cost:"; then
			echo "made $out"; return
		fi
		sleep 8
	done
	echo "FAILED $out"
}
P=game/assets/art/portraits
pt() { gen "$P/$1.png" 64x64 side "head and shoulders portrait of $2, ancient Rome, front view, friendly expression, cozy pixel art, warm light"; }
pt septimus "an old man with a white beard and a kind face, plain brown tunic"
pt cornelia "an anxious elderly widow with grey hair in a bun and a dark shawl"
pt felix "a cheerful round-faced baker with flour on his cheeks and a white cap"
pt marcus "a stern retired legionary with short grey hair and a scar, red tunic"
pt gaius "a jolly bald bathhouse owner with a towel over his shoulder"
pt livia "a young smiling woman with braided dark hair and a flower crown"
pt aulus "a burly innkeeper with a curly black beard and an apron"
pt trimalchio "a fat rich man with gold rings, a gold necklace and a smug grin"
pt valeria "a serene priestess with a white veil and gold earrings"
pt quintus "a self-important magistrate in a white toga with a purple stripe"
pt towns_1 "a townsman with short brown hair and a plain green tunic"
pt towns_2 "a townswoman with red hair tied back and a blue dress"
pt towns_3 "a young scribe with curly hair holding a wax tablet"
pt towns_4 "an old woman with a white headscarf and a basket"
W=game/assets/art/workshop
mkdir -p $W game/assets/art/furniture game/assets/art/people game/assets/art/town
gen $W/job_board.png 64x64 side "a wooden notice board on two legs covered in pinned notes and wax tablets, cozy pixel art, isolated sprite"
gen $W/design_table.png 96x64 side "a wooden work table with an open pattern book, wax tablets and drawing tools on it, side view, cozy pixel art, isolated sprite"
gen $W/shelves.png 80x80 side "wooden shelves stacked with sacks and baskets of colourful stone tiles, side view, cozy pixel art, isolated sprite"
gen $W/bench.png 64x48 side "a stone mason's workbench with a hammer, a chisel and little piles of coloured tiles, side view, cozy pixel art, isolated sprite"
gen $W/dog.png 48x32 side "a small sleeping brown dog curled up, side view, cozy pixel art, isolated sprite"
gen $W/amphora.png 32x48 side "a tall clay amphora jar, side view, cozy pixel art, isolated sprite"
gen $W/plant.png 32x40 side "a potted green plant in a terracotta pot, side view, cozy pixel art, isolated sprite"
gen $W/lamp.png 32x48 side "a bronze oil lamp on a tall stand, lit, side view, cozy pixel art, isolated sprite"
F=game/assets/art/furniture
fu() { gen "$F/$1.png" "$2" "high top-down" "$3 seen from directly above, top-down view, ancient Roman, cozy pixel art, isolated sprite"; }
fu bench 64x32 "a long wooden bench"
fu bed 48x64 "a Roman bed with a red blanket and a pillow"
fu chest 32x32 "a wooden storage chest"
fu lamp 32x32 "a bronze oil lamp on a stand"
fu desk 64x32 "a wooden writing desk with scrolls"
fu chair 32x32 "a wooden chair"
fu shelf 32x64 "a tall wooden shelf of scrolls against a wall"
fu plant 32x32 "a potted palm in a big terracotta pot"
fu counter 64x32 "a shop counter with jars set into it"
fu amphorae 32x32 "three clay amphorae leaning together"
fu table 40x40 "a round wooden table with a bowl of fruit"
fu stool 32x32 "a small wooden stool"
fu couch 64x32 "a dining couch with cushions"
fu baskets 32x32 "baskets of bread loaves"
fu statue 32x32 "a marble statue on a plinth"
fu fountain 48x48 "a round stone fountain with water"
fu altar 32x32 "a small stone altar with a flame"
PE=game/assets/art/people
pe() { gen "$PE/$1.png" 32x32 "high top-down" "$2 seen from directly above, top-down view, walking, ancient Rome, cozy pixel art, isolated sprite"; }
pe man "a man in a brown tunic"
pe woman "a woman in a blue dress"
pe child "a small child in a white tunic"
pe toga "a man in a white toga"

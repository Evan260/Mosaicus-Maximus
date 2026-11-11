class_name Daylight
## The light at each hour of the day, as in Farmus Maximus: the room is multiplied by it, so it looks as painted at
## midday, warm at dusk and blue at night. Also the sky's colours, top and horizon, at each hour.

const LIGHT := [
	[0.0, Color(0.33, 0.37, 0.62)],
	[4.5, Color(0.33, 0.37, 0.62)],
	[6.0, Color(0.86, 0.72, 0.82)],
	[8.0, Color(1.0, 1.0, 1.0)],
	[16.5, Color(1.0, 1.0, 1.0)],
	[18.5, Color(0.95, 0.76, 0.74)],
	[20.0, Color(0.33, 0.37, 0.62)],
	[24.0, Color(0.33, 0.37, 0.62)],
]
const SKY := [
	[0.0, Color8(14, 18, 44), Color8(38, 44, 82)],
	[4.5, Color8(14, 18, 44), Color8(38, 44, 82)],
	[6.0, Color8(92, 92, 152), Color8(240, 172, 140)],
	[8.0, Color8(104, 164, 232), Color8(186, 222, 246)],
	[16.5, Color8(104, 164, 232), Color8(186, 222, 246)],
	[18.5, Color8(84, 82, 150), Color8(250, 150, 98)],
	[20.0, Color8(14, 18, 44), Color8(38, 44, 82)],
	[24.0, Color8(14, 18, 44), Color8(38, 44, 82)],
]


static func light(hour: float) -> Color:
	var h := fposmod(hour, 24.0)
	for k in LIGHT.size() - 1:
		if h >= LIGHT[k][0] and h <= LIGHT[k + 1][0]:
			return (LIGHT[k][1] as Color).lerp(LIGHT[k + 1][1], (h - LIGHT[k][0]) / (LIGHT[k + 1][0] - LIGHT[k][0]))
	return LIGHT[0][1]


## The sky's top and horizon colours.
static func sky(hour: float) -> Array:
	var h := fposmod(hour, 24.0)
	for k in SKY.size() - 1:
		if h >= SKY[k][0] and h <= SKY[k + 1][0]:
			var u: float = (h - SKY[k][0]) / (SKY[k + 1][0] - SKY[k][0])
			return [(SKY[k][1] as Color).lerp(SKY[k + 1][1], u), (SKY[k][2] as Color).lerp(SKY[k + 1][2], u)]
	return [SKY[0][1], SKY[0][2]]


## 0 in daylight, 1 in full night.
static func night(hour: float) -> float:
	return clampf((1.0 - light(hour).g) / (1.0 - 0.37), 0.0, 1.0)


## How lit the lamps are, from 0 to 1: out in daylight, since oil cost money, and lit as the light fades.
static func lamps_lit(hour: float) -> float:
	return clampf(night(hour) * 3.0, 0.0, 1.0)


## The part of the day in the player's language.
static func part_name(part: String) -> String:
	return {"morning": TranslationServer.translate("morning"), "afternoon": TranslationServer.translate("afternoon"),
		"evening": TranslationServer.translate("evening")}.get(part, TranslationServer.translate("night"))


static func part_of_day(hour: float) -> String:
	if hour < 11.0:
		return "morning"
	if hour < 17.0:
		return "afternoon"
	if hour < 20.0:
		return "evening"
	return "night"

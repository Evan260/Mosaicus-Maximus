class_name Pricing
## Money and reputation: whether a client accepts a price, what they pay for the floor they get, and what stone costs.


## How likely a client is to accept the asked price. Asking the budget is usually fine; far above it rarely is.
static func accept_chance(asked: int, budget: int, reputation: int) -> float:
	var ratio := float(asked) / maxf(1.0, budget)
	var base := Data.num("pricing.accept_at_budget", 0.9)
	var bonus := reputation * Data.num("pricing.reputation_per_point", 0.003)
	if ratio <= 1.0:
		return minf(0.99, base + (1.0 - ratio) * 0.5 + bonus)
	return clampf(base * exp(-Data.num("pricing.falloff", 2.4) * (ratio - 1.0)) + bonus * 0.5, 0.0, 0.99)


## The score a client expects for the price agreed: asking more than their budget raises the bar.
static func expectation(asked: int, budget: int) -> float:
	var ratio := float(asked) / maxf(1.0, budget)
	return clampf(0.5 + Data.num("pricing.expectation", 0.25) * (ratio - 1.0) * 2.0, 0.3, 0.95)


## What the client pays: the full price when pleased, less when the floor falls short, and a tip when delighted.
static func payment(asked: int, score: float, expected: float) -> int:
	if score >= expected:
		var tip := Data.num("payment.tip", 0.12) if score >= Data.num("payment.tip_above", 0.95) else 0.0
		return int(round(asked * (1.0 + tip)))
	var share := maxf(Data.num("payment.minimum_share", 0.55), score / maxf(expected, 0.01))
	return int(round(asked * share))


static func reputation(score: float, tiles: int) -> int:
	if score < Data.num("reputation.unhappy_below", 0.45):
		return -1
	var gain := Data.num("reputation.base", 2) + Data.num("reputation.per_score", 8) * (score - 0.5) + Data.num("reputation.per_100_tiles", 0.4) * tiles / 100.0
	return maxi(1, int(round(gain)))


## The cost in denarii of the stone a floor still needs beyond what is in stock.
static func stone_cost(counts: Dictionary) -> int:
	return Game.shortfall_cost(counts)


## The most expensive stone in a floor and the cheapest similar unlocked stone to use instead, with the money saved.
## Empty when there is nothing cheaper to swap to.
static func cheaper_swap(counts: Dictionary, unlocked: Array) -> Dictionary:
	var worst := ""
	var worst_cost := 0.0
	for id in counts:
		var c := float(counts[id]) * Data.stone_price(id)
		if c > worst_cost:
			worst = id
			worst_cost = c
	if worst == "":
		return {}
	var best := ""
	var best_score := INF
	for id in unlocked:
		if id == worst or Data.stone_price(id) >= Data.stone_price(worst):
			continue
		var s := Stones.difference(worst, id) * 3.0 + Data.stone_price(id) * 10.0
		if s < best_score:
			best = id
			best_score = s
	if best == "":
		return {}
	var saving := int(round(float(counts[worst]) * (Data.stone_price(worst) - Data.stone_price(best))))
	return {"from": worst, "to": best, "saving": saving}

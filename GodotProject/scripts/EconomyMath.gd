class_name EconomyMath
extends RefCounted


const STOCK_CASH_DIVISOR: = 10000.0


static func stock_trade_value(price: float, shares: int, price_multiplier: = 1.0) -> int:
	if price < 0.0 or shares < 0 or price_multiplier < 0.0:
		return 0
	return ceili(stock_position_value(price, shares, price_multiplier))


static func stock_position_value(price: float, shares: int, price_multiplier: = 1.0) -> float:
	if price < 0.0 or shares < 0 or price_multiplier < 0.0:
		return 0.0
	return price * float(shares) * price_multiplier / STOCK_CASH_DIVISOR

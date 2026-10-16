class_name CityActionAssetRegistry
extends RefCounted

const PATHS: = {
	"Talent": "res://assets/images/v13/city_icons/talent.png", 
	"News": "res://assets/images/v13/city_icons/news.png", 
	"Startup": "res://assets/images/v13/city_icons/startup.png", 
	"Auction": "res://assets/images/v13/city_icons/auction.png", 
	"Cards": "res://assets/images/v13/city_icons/cards.png", 
	"Stocks": "res://assets/images/v13/city_icons/stocks.png", 
	"Bank": "res://assets/images/v13/city_icons/bank.png", 
}


static func icon(kind: String) -> Texture2D:
	return load(str(PATHS.get(kind, PATHS.Cards))) as Texture2D

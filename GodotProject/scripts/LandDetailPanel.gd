extends PanelContainer

signal buy_requested(land_id: String)
signal build_requested(land_id: String)
var land_id: = ""

func setup(land: Dictionary) -> void :
	land_id = str(land.id)
	$Body / Title.text = "%s  %s" % [land.id, land.district_name]
	$Body / Price.text = "地价 %d 万" % int(land.price)
	$Body / Environment.text = "环境线索：%s" % " / ".join(land.environment)
	$Body / Buy.visible = str(land.state) == "available"
	$Body / Build.visible = str(land.state) == "owned_empty"

func _ready() -> void :
	$Body / Buy.pressed.connect( func() -> void : buy_requested.emit(land_id))
	$Body / Build.pressed.connect( func() -> void : build_requested.emit(land_id))

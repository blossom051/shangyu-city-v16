extends Node


const BODY_FONT: Font = preload("res://Themes/V9141BodyFont.tres")
const MEDIUM_FONT: Font = preload("res://Themes/V9141BodyMediumFont.tres")
const DISPLAY_FONT: Font = preload("res://Themes/V9141DisplayFont.tres")

const DISPLAY_NAMES: = {
	"Logo": true, 
	"Title": true, 
	"HeaderTitle": true, 
	"LotTitle": true, 
	"BiddersTitle": true, 
	"DirectTitle": true, 
	"MortgageTitle": true, 
	"LoansTitle": true, 
	"PositionsTitle": true, 
	"DeskTitle": true, 
}


func _ready() -> void :
	get_tree().node_added.connect(_on_node_added)
	_apply_tree(get_tree().root)


func _on_node_added(node: Node) -> void :
	if node is Control:
		call_deferred("_apply_control", node)


func _apply_tree(node: Node) -> void :
	if node is Control:
		_apply_control(node)
	for child: Node in node.get_children():
		_apply_tree(child)


func _apply_control(control: Variant) -> void :
	if not is_instance_valid(control) or not control is Control:
		return
	var target: = control as Control
	if target is Label and _is_display_label(target as Label):
		target.add_theme_font_override("font", DISPLAY_FONT)
	elif target is Button:
		target.add_theme_font_override("font", MEDIUM_FONT)


func _is_display_label(label: Label) -> bool:
	if not DISPLAY_NAMES.has(label.name):
		return false
	return label.get_theme_font_size("font_size") >= 20


func apply_display(control: Control) -> void :
	control.add_theme_font_override("font", DISPLAY_FONT)


func typography_profile() -> Dictionary:
	return {
		"body": "Source Han Sans CN Regular", 
		"medium": "Source Han Sans CN Medium", 
		"display": "Smiley Sans Oblique", 
		"global_body": true, 
	}

class_name InfoLinkButton extends LinkButton


@export var page_name: String


func _ready() -> void:
	pressed.connect(open)


func open() -> void:
	Globals.main.get_node("TabContainer/Info").add_page_node_and_select(InfoManager.make_new_page_from_file(page_name))

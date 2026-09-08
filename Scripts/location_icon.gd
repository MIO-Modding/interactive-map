class_name LocationIcon extends Polygon2D


const MAP_ICON_TEXTURES := {
	"Ability": preload("res://Sprites/map-icons/UNLOCK_HOOK.png"),
	"Boss": preload("res://Sprites/map-icons/MAP_MARK_4.png"),
	"Candle": preload("res://Sprites/map-icons/CANDLE.png"),
	"Coating Component": preload("res://Sprites/map-icons/SHIELD_FRAGMENT.png"),
	"Curio": preload("res://Sprites/map-icons/DATAPAD_CURIO_MARBLES.png"),
	"Flash Memory": preload("res://Sprites/map-icons/DATAPAD_MEM_LIBRARIAN.png"),
	"Forebears' Legacy": preload("res://Sprites/map-icons/ATTACK_POWER.png"),
	"Key": preload("res://Sprites/map-icons/KEY_ROOTS_CORRIDOR.png"),
	"Misc": preload("res://Sprites/map-icons/TRINKET_MISSING_ICON.png"),
	"Modifier Extension": preload("res://Sprites/map-icons/TRINKET_SLOT_UPGRADE.png"),
	"Modifier": preload("res://Sprites/map-icons/TRINKET_HUD.png"),
	"Nacre": preload("res://Sprites/map-icons/RESOURCE_PEARL_SHARDS.png"),
	"Npc": preload("res://Sprites/map-icons/MAP_MARK_3.png"),
	"Old Core": preload("res://Sprites/map-icons/RESOURCE_FULL_PEARLS.png"),
	"Overseer": preload("res://Sprites/map-icons/MAP_MARK_1.png"),
	"Pearl Record": preload("res://Sprites/map-icons/DATAPAD_PEARL_KHLIA.png"),
	"Serial Number": preload("res://Sprites/map-icons/CHEST_KEY.png"),
	"Tomo Letter": preload("res://Sprites/map-icons/DATAPAD_LETTER_FIRST_CASE.png"),
	"Traveller's Log": preload("res://Sprites/map-icons/DATAPAD_TXT_TRAVELLER_LOG1_TRANSLATED.png"),
	"Tremor": preload("res://Sprites/map-icons/MAP_MARK_2.png"),
	"Voice": preload("res://Sprites/map-icons/VOICE_ASMA.png"),
	"Default": preload("res://Sprites/map-icons/TRINKET_MISSING_ICON.png"),
}

var icon_type: String:
	set(v):
		if v not in MAP_ICON_TEXTURES:
			v = "Default"
		icon_type = v
		$icon_image.texture = MAP_ICON_TEXTURES[icon_type]

var is_checked: bool:
	set(v):
		is_checked = v
		if v:
			self_modulate.a = 0.05
			modulate.a = 0.3
		else:
			self_modulate.a = 1.0
			modulate.a = 1.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

extends Node

const KIT_TEXTURE_PATH = "res://assets/ui/keycap_kit_6.png"
var kit_tex: Texture2D

const SLICES = {
	"cap_unpressed": {
		"slate": Rect2(83, 66, 350, 315),
		"red": Rect2(530, 66, 350, 315),
		"blue": Rect2(978, 66, 349, 315),
		"brown": Rect2(1425, 66, 350, 315),
		"black": Rect2(1871, 66, 351, 315),
		"gold": Rect2(2319, 66, 350, 315),
	},
	"cap_pressed": {
		"slate": Rect2(83, 467, 350, 298),
		"red": Rect2(530, 479, 350, 286),
		"blue": Rect2(978, 479, 349, 287),
		"brown": Rect2(1425, 485, 349, 281),
		"black": Rect2(1872, 490, 350, 276),
		"gold": Rect2(2319, 490, 350, 275),
	},
	"switches": {
		"mx_red": Rect2(477, 868, 262, 258),
		"mx_blue": Rect2(866, 868, 261, 258),
		"mx_brown": Rect2(1245, 868, 262, 258),
		"mx_black": Rect2(1625, 868, 262, 258),
		"mx_speed": Rect2(2025, 868, 263, 258),
		"clicky": Rect2(866, 868, 261, 258),
		"linear": Rect2(477, 868, 262, 258),
		"tactile": Rect2(1245, 868, 262, 258),
		"heavy_tactile": Rect2(1625, 868, 262, 258),
		"silent": Rect2(2025, 868, 263, 258),
	},
	"overlays": {
		"holographic": Rect2(576, 1201, 304, 281),
		"foil": Rect2(1000, 1190, 316, 292),
		"glass": Rect2(1448, 1201, 304, 281),
		"sticker_gold": Rect2(1884, 1201, 280, 281),
	}
}

var _cached_atlases: Dictionary = {}

func _ready() -> void:
	if ResourceLoader.exists(KIT_TEXTURE_PATH):
		kit_tex = load(KIT_TEXTURE_PATH)

func get_atlas(category: String, key: String) -> AtlasTexture:
	var cache_key = category + "_" + key
	if _cached_atlases.has(cache_key):
		return _cached_atlases[cache_key]
	if not kit_tex or not SLICES.has(category) or not SLICES[category].has(key):
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = kit_tex
	atlas.region = SLICES[category][key]
	_cached_atlases[cache_key] = atlas
	return atlas

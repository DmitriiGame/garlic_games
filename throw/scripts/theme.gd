@tool
extends RefCounted
class_name ThrowTheme
## Все цвета интерфейса, неба, бабушки и тапка. Краски краёв и нечисти живут в data/.

const BG := Color("1a1714")
const BG_RAISED := Color("2a241e")
const INK := Color("f3ead7")
const MUTED := Color("b3a790")
const PAPER := Color("efe4cf")
const ACCENT := Color("e07a3d")
const ACCENT_DEEP := Color("8c3d22")
const GOOD := Color("c5d47a")
const BAD := Color("d45d4a")
const LINE := Color("3c342c")
const METER := Color("e0b15a")
const TRACK := Color("3a332c")
const SKY := Color("b7c6d4")
const CLOUD := Color("d5e0ea")
const WOOD := Color("3a2c24")
const SILL := Color("6b5344")
const GRASS := Color("4a5a38")
const SLIPPER := Color("8a4b32")
const UNCAUGHT := Color("2a2622")
const SLOT := Color("241f1b")
const SKIN := Color("e0b59a")
const SCARF := Color("9a3d32")
const DRESS := Color("2f3b56")
const HAIR := Color("d8d2c8")
const SHADOW := Color(0, 0, 0, 0.28)


static func color_or(hex: String, fallback: Color) -> Color:
	var text := hex.strip_edges()
	if text == "":
		return fallback
	if not text.begins_with("#"):
		text = "#" + text
	if not Color.html_is_valid(text):
		return fallback
	return Color.html(text)

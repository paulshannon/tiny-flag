class_name FlagUi
extends RefCounted
## The Kenney UI Pack theme for Tiny Flag's HUD and menu, built in code once and shared.
## Set it as `theme` on a root Control (children inherit it) and pick the accent looks
## with `theme_type_variation` (LOCK_BUTTON, BAR, TEAM_TAG[team], ...). Paths come from
## FlagArt.
##
## The pack's 192x64 and 64x64 PNGs have 4 px rounded corners inside a 2 px border and
## a 2 px highlight; the "depth" ones add a 4 px darker base. So 8 px texture margins keep
## the corners and border unstretched (12 px at the bottom of a depth image).

## Button variations (base: Button, which is Blue).
const LOCK_BUTTON: StringName = &"LockButton"
const CLEAR_BUTTON: StringName = &"ClearButton"
## PanelContainer variations: the light bars behind the HUD text, the menu card and toasts.
const BAR: StringName = &"Bar"
const CARD: StringName = &"Card"
const TOAST: StringName = &"Toast"
## Per team (FlagMap.RED, FlagMap.BLUE): the "You: Red" tag and the result banner.
const TEAM_TAG: Array[StringName] = [&"TagRed", &"TagBlue"]
const NEUTRAL_TAG: StringName = &"TagNeutral"
const TEAM_BANNER: Array[StringName] = [&"BannerRed", &"BannerBlue"]
const NEUTRAL_BANNER: StringName = &"BannerNeutral"
## Label variation for white text on a coloured tag, banner or button.
const LIGHT_LABEL: StringName = &"LightLabel"

const FONT_SIZE: int = 20
## The HUD hint line.
const SMALL_FONT_SIZE: int = 16
const TEXT: Color = Color(0.23, 0.25, 0.32)
const LIGHT_TEXT: Color = Color(1, 1, 1)
const DARK_TEXT: Color = Color(0.36, 0.26, 0.04)
const FOCUS: Color = Color(1.0, 0.76, 0.2)

static var _theme: Theme


## The shared theme; built on the first call.
static func make_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## A 9-sliced UI Pack tile in `colour` (FlagArt.UI_COLOURS).
static func panel(colour: String, raised: bool = false) -> StyleBoxTexture:
	var file := FlagArt.UI_PANEL_RAISED if raised else FlagArt.UI_PANEL
	var s := _slice(FlagArt.ui_png(colour, file), 12 if raised else 8)
	s.set_content_margin_all(10)
	s.content_margin_left = 16
	s.content_margin_right = 16
	if raised:
		s.content_margin_bottom = 14
	return s


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = _font(FlagArt.UI_FONT)
	t.default_font_size = FONT_SIZE

	t.set_color("font_color", "Label", TEXT)
	_variation(t, LIGHT_LABEL, "Label")
	t.set_color("font_color", LIGHT_LABEL, LIGHT_TEXT)
	t.set_color("font_outline_color", LIGHT_LABEL, Color(0, 0, 0, 0.45))
	t.set_constant("outline_size", LIGHT_LABEL, 4)

	_buttons(t, "Button", FlagArt.UI_BLUE, LIGHT_TEXT)
	_variation(t, LOCK_BUTTON, "Button")
	_buttons(t, LOCK_BUTTON, FlagArt.UI_GREEN, LIGHT_TEXT)
	_variation(t, CLEAR_BUTTON, "Button")
	_buttons(t, CLEAR_BUTTON, FlagArt.UI_YELLOW, DARK_TEXT)
	t.set_icon("icon", CLEAR_BUTTON, load(FlagArt.ui_png(FlagArt.UI_YELLOW, FlagArt.UI_ICON_CROSS)) as Texture2D)
	t.set_constant("h_separation", CLEAR_BUTTON, 10)
	for c: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		t.set_color(c, CLEAR_BUTTON, Color(0.6, 0.6, 0.6))  # darkens the pale gold cross

	t.set_stylebox("panel", "PanelContainer", panel(FlagArt.UI_GREY))
	_panel_variation(t, BAR, panel(FlagArt.UI_GREY))
	var card := panel(FlagArt.UI_GREY, true)
	card.content_margin_left = 24
	card.content_margin_right = 24
	card.content_margin_top = 20
	card.content_margin_bottom = 24
	_panel_variation(t, CARD, card)
	_panel_variation(t, TOAST, panel(FlagArt.UI_GREY))
	var tag_colours: Array[String] = [FlagArt.UI_RED, FlagArt.UI_BLUE]
	for team: int in TEAM_TAG.size():
		_panel_variation(t, TEAM_TAG[team], panel(tag_colours[team]))
		_panel_variation(t, TEAM_BANNER[team], _banner(tag_colours[team]))
	_panel_variation(t, NEUTRAL_TAG, panel(FlagArt.UI_GREY))
	_panel_variation(t, NEUTRAL_BANNER, _banner(FlagArt.UI_YELLOW))
	return t


## Normal / hover / pressed / disabled / focus for one button type.
static func _buttons(t: Theme, type: StringName, colour: String, text: Color) -> void:
	var normal := _button_box(FlagArt.ui_png(colour, FlagArt.UI_BUTTON_UP), true)
	var hover := _button_box(FlagArt.ui_png(colour, FlagArt.UI_BUTTON_HOVER), true)
	var pressed := _button_box(FlagArt.ui_png(colour, FlagArt.UI_BUTTON_DOWN), false)
	var disabled := _button_box(FlagArt.ui_png(FlagArt.UI_GREY, FlagArt.UI_BUTTON_UP), true)
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, pressed)
	t.set_stylebox("disabled", type, disabled)
	t.set_stylebox("focus", type, _focus())
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, type, text)
	t.set_color("font_disabled_color", type, Color(TEXT, 0.6))


## A raised button keeps 4 px of base below its face, so its text sits 2 px higher; the
## pressed (flat) one has no base and its text drops by the same amount.
static func _button_box(path: String, raised: bool) -> StyleBoxTexture:
	var s := _slice(path, 12 if raised else 8)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 6 if raised else 8
	s.content_margin_bottom = 10 if raised else 8
	return s


static func _banner(colour: String) -> StyleBoxTexture:
	var s := panel(colour, true)
	s.content_margin_left = 48
	s.content_margin_right = 48
	s.content_margin_top = 16
	s.content_margin_bottom = 24
	return s


static func _focus() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = FOCUS
	s.set_border_width_all(3)
	s.set_corner_radius_all(8)
	s.set_expand_margin_all(3)
	return s


## 9-slice with 8 px margins, `bottom` px at the bottom.
static func _slice(path: String, bottom: int) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(path) as Texture2D
	s.texture_margin_left = 8
	s.texture_margin_right = 8
	s.texture_margin_top = 8
	s.texture_margin_bottom = bottom
	return s


## A pack font (Kenney Future; its Narrow cut has wider letter spacing and read worse in
## the screenshots, so it isn't used). No fallback: the web build has no system fonts to fall back on, so every
## HUD and menu string must use glyphs the pack font has (test_tiny_flag_ui checks).
static func _font(path: String) -> FontFile:
	return load(path) as FontFile


static func _variation(t: Theme, name: StringName, base: StringName) -> void:
	t.set_type_variation(name, base)


static func _panel_variation(t: Theme, name: StringName, box: StyleBox) -> void:
	t.set_type_variation(name, "PanelContainer")
	t.set_stylebox("panel", name, box)

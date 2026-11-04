class_name AppTheme
extends RefCounted

## One runtime-built theme for every screen (ui.md: colors, font sizes and
## spacing come from the Theme, not per-node overrides). `build()` is installed
## once on the window root by the app shell, so scenes carry layout only.

const FONT_SIZE := 20
const SMALL_FONT_SIZE := 16
const BUTTON_FONT_SIZE := 22
const PANEL_TITLE_FONT_SIZE := 34
const TITLE_FONT_SIZE := 46

const TEXT_COLOR := Color(0.88, 0.93, 1.0, 1.0)
const MUTED_COLOR := Color(0.55, 0.65, 0.78, 1.0)
const ACCENT_COLOR := Color(0.25, 0.90, 1.0, 1.0)
const FOCUS_COLOR := Color(1.0, 0.78, 0.45, 1.0)
const BACKGROUND_COLOR := Color(0.035, 0.05, 0.09, 1.0)
const PANEL_COLOR := Color(0.055, 0.075, 0.12, 0.97)
const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.65)
const BUTTON_COLOR := Color(0.08, 0.12, 0.19, 1.0)
const BUTTON_HOVER_COLOR := Color(0.13, 0.20, 0.30, 1.0)
const BUTTON_PRESSED_COLOR := Color(0.05, 0.16, 0.24, 1.0)
const BUTTON_DISABLED_COLOR := Color(0.06, 0.08, 0.12, 1.0)
const BORDER_COLOR := Color(0.18, 0.28, 0.40, 1.0)

const BUTTON_MINIMUM := Vector2(44, 44)
const BORDER_WIDTH := 1
const FOCUS_BORDER_WIDTH := 3
const CORNER_RADIUS := 6
const PANEL_RADIUS := 10
const BUTTON_CONTENT_MARGIN := 16.0
const MENU_SEPARATION := 14
const MARGIN := 32

static var _shared: Theme = null


## The one theme instance every screen installs on its root Control. A
## CanvasLayer is not a CanvasItem, so a screen inside one cannot inherit the
## window theme; assigning it to the root Control keeps the lookup chain local.
static func shared() -> Theme:
	if _shared == null:
		_shared = build()
	return _shared


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	theme.set_color(&"font_color", &"Label", TEXT_COLOR)
	_style_buttons(theme)
	_style_panels(theme)
	_style_containers(theme)
	_style_variations(theme)
	return theme


static func _style_buttons(theme: Theme) -> void:
	theme.set_font_size(&"font_size", &"Button", BUTTON_FONT_SIZE)
	theme.set_color(&"font_color", &"Button", TEXT_COLOR)
	theme.set_color(&"font_hover_color", &"Button", ACCENT_COLOR)
	theme.set_color(&"font_focus_color", &"Button", TEXT_COLOR)
	theme.set_color(&"font_pressed_color", &"Button", ACCENT_COLOR)
	theme.set_color(&"font_disabled_color", &"Button", MUTED_COLOR)
	theme.set_stylebox(&"normal", &"Button", _button_style(BUTTON_COLOR))
	theme.set_stylebox(&"hover", &"Button", _button_style(BUTTON_HOVER_COLOR))
	theme.set_stylebox(&"pressed", &"Button", _button_style(BUTTON_PRESSED_COLOR))
	theme.set_stylebox(&"disabled", &"Button", _button_style(BUTTON_DISABLED_COLOR))
	theme.set_stylebox(&"focus", &"Button", _focus_style())


static func _style_panels(theme: Theme) -> void:
	theme.set_stylebox(&"panel", &"PanelContainer", _panel_style(PANEL_COLOR, true))
	theme.set_stylebox(&"panel", &"BackdropPanel", _panel_style(BACKGROUND_COLOR, false))
	theme.set_stylebox(&"panel", &"DimPanel", _panel_style(DIM_COLOR, false))


static func _style_containers(theme: Theme) -> void:
	theme.set_constant(&"separation", &"VBoxContainer", MENU_SEPARATION)
	theme.set_constant(&"separation", &"HBoxContainer", MENU_SEPARATION)
	for side: String in ["left", "right", "top", "bottom"]:
		theme.set_constant(&"margin_" + side, &"MarginContainer", MARGIN)


static func _style_variations(theme: Theme) -> void:
	theme.set_type_variation(&"TitleLabel", &"Label")
	theme.set_font_size(&"font_size", &"TitleLabel", TITLE_FONT_SIZE)
	theme.set_color(&"font_color", &"TitleLabel", ACCENT_COLOR)

	theme.set_type_variation(&"PanelTitleLabel", &"Label")
	theme.set_font_size(&"font_size", &"PanelTitleLabel", PANEL_TITLE_FONT_SIZE)
	theme.set_color(&"font_color", &"PanelTitleLabel", ACCENT_COLOR)

	theme.set_type_variation(&"StatLabel", &"Label")
	theme.set_font_size(&"font_size", &"StatLabel", FONT_SIZE)
	theme.set_color(&"font_color", &"StatLabel", TEXT_COLOR)

	theme.set_type_variation(&"AccentLabel", &"Label")
	theme.set_font_size(&"font_size", &"AccentLabel", FONT_SIZE)
	theme.set_color(&"font_color", &"AccentLabel", FOCUS_COLOR)

	theme.set_type_variation(&"MutedLabel", &"Label")
	theme.set_font_size(&"font_size", &"MutedLabel", SMALL_FONT_SIZE)
	theme.set_color(&"font_color", &"MutedLabel", MUTED_COLOR)


static func _button_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = BORDER_COLOR
	style.set_border_width_all(BORDER_WIDTH)
	style.set_corner_radius_all(CORNER_RADIUS)
	style.content_margin_left = BUTTON_CONTENT_MARGIN
	style.content_margin_right = BUTTON_CONTENT_MARGIN
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


static func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = FOCUS_COLOR
	style.set_border_width_all(FOCUS_BORDER_WIDTH)
	style.set_corner_radius_all(CORNER_RADIUS)
	style.set_expand_margin_all(2.0)
	return style


static func _panel_style(background: Color, bordered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(PANEL_RADIUS)
	if bordered:
		style.border_color = BORDER_COLOR
		style.set_border_width_all(BORDER_WIDTH)
	return style

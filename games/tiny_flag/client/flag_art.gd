class_name FlagArt
extends RefCounted
## Every Kenney sheet and tile index Tiny Flag draws with; the only file that names Kenney
## paths. Both sheets are 16 px tiles with no spacing (tilemap_packed.png). Indices count
## left to right, top to bottom (the numbers in each pack's Tiles/tile_NNNN.png).

const TILE: int = 16

const FARM_SHEET: String = "res://assets/kenney/tiny-farm/Tilemap/tilemap_packed.png"
const FARM_COLUMNS: int = 12
const BATTLE_SHEET: String = "res://assets/kenney/tiny-battle/Tilemap/tilemap_packed.png"
const BATTLE_COLUMNS: int = 18

## TileSet source ids.
const FARM: int = 0
const BATTLE: int = 1

# --- Tiny Battle: ground --------------------------------------------------------
const GRASS: Array[int] = [0, 0, 0, 1, 0, 0, 2, 0]  # mostly plain, some tufts and flowers
const WATER: int = 37
## Pond corners, used when the water tile has water on those two sides.
const WATER_TOP_LEFT: int = 18
const WATER_TOP_RIGHT: int = 20
const WATER_BOTTOM_LEFT: int = 54
const WATER_BOTTOM_RIGHT: int = 56

# --- Tiny Farm: dirt path (light dirt strip on grass) ---------------------------
const PATH_ALONE: int = 63
const PATH_LEFT_END: int = 60
const PATH_ACROSS: int = 61
const PATH_RIGHT_END: int = 62
const PATH_TOP_END: int = 13
const PATH_DOWN: int = 25
const PATH_BOTTOM_END: int = 37

# --- Tiny Farm: props drawn over the ground --------------------------------------
const CROPS: int = 66      # tall wheat
const TREE: int = 27       # small pine (15 is the bottom half of the tall two-tile pine)
const HEDGE: int = 39      # bush
## Buildings are one-tile hay bales (the pack's barn is many tiles tall); a run of them
## alternates plain and banded.
const BUILDING_LEFT: int = 96    # hay bale
const BUILDING_RIGHT: int = 97   # hay bale with red bands

# --- Tiny Battle: pieces and flags -----------------------------------------------
## Per team (FlagMap.RED, FlagMap.BLUE).
const SOLDIER: Array[int] = [160, 142]
const FLAG: Array[int] = [70, 52]

# --- UI Pack: HUD and menu (FlagUi builds the theme from these) -----------------
const UI_DIR: String = "res://assets/kenney/ui-pack/"
const UI_FONT: String = UI_DIR + "Font/Kenney Future.ttf"
## Colour folders under PNG/ (Default size, 192x64 rectangles and 64x64 squares).
const UI_BLUE: String = "Blue"
const UI_GREEN: String = "Green"
const UI_GREY: String = "Grey"
const UI_RED: String = "Red"
const UI_YELLOW: String = "Yellow"
const UI_COLOURS: Array[String] = [UI_BLUE, UI_GREEN, UI_GREY, UI_RED, UI_YELLOW]
## Raised button (4 px darker base under the face), the same lit from above (hover),
## and the flat one with no base (pressed).
const UI_BUTTON_UP: String = "button_rectangle_depth_flat.png"
const UI_BUTTON_HOVER: String = "button_rectangle_depth_gradient.png"
const UI_BUTTON_DOWN: String = "button_rectangle_flat.png"
## Square tile for panels, tags and banners; 9-sliced.
const UI_PANEL: String = "button_square_flat.png"
const UI_PANEL_RAISED: String = "button_square_depth_flat.png"
## 18x18 cross, the Clear path button's icon (the pack font has no "✕").
const UI_ICON_CROSS: String = "icon_cross.png"
const UI_FILES: Array[String] = [UI_BUTTON_UP, UI_BUTTON_HOVER, UI_BUTTON_DOWN, UI_PANEL, UI_PANEL_RAISED,
		UI_ICON_CROSS]

## Team colours for overlays (bases, paths, HUD).
const TEAM_COLOR: Array[Color] = [Color(0.86, 0.25, 0.22), Color(0.2, 0.45, 0.9)]
const TEAM_NAME: Array[String] = ["Red", "Blue"]


static func coords(index: int, columns: int) -> Vector2i:
	return Vector2i(index % columns, index / columns)


## A UI Pack PNG: `colour` is one of UI_COLOURS, `file` one of UI_FILES.
static func ui_png(colour: String, file: String) -> String:
	return UI_DIR + "PNG/" + colour + "/Default/" + file


## Every UI Pack file FlagUi can load.
static func ui_paths() -> Array[String]:
	var paths: Array[String] = [UI_FONT]
	for c: String in UI_COLOURS:
		for f: String in UI_FILES:
			paths.append(ui_png(c, f))
	return paths


static func farm_sheet() -> Texture2D:
	return load(FARM_SHEET) as Texture2D


static func battle_sheet() -> Texture2D:
	return load(BATTLE_SHEET) as Texture2D


## One Tiny Battle tile as a texture (pieces, flags, markers).
static func battle_tile(index: int) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = battle_sheet()
	var c := coords(index, BATTLE_COLUMNS)
	t.region = Rect2(c.x * TILE, c.y * TILE, TILE, TILE)
	return t


## A TileSet with both sheets as atlas sources (FARM, BATTLE), every tile created.
static func tile_set() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_source(_source(farm_sheet()), FARM)
	ts.add_source(_source(battle_sheet()), BATTLE)
	return ts


static func _source(sheet: Texture2D) -> TileSetAtlasSource:
	var src := TileSetAtlasSource.new()
	src.texture = sheet
	src.texture_region_size = Vector2i(TILE, TILE)
	var grid := src.get_atlas_grid_size()
	for y: int in grid.y:
		for x: int in grid.x:
			src.create_tile(Vector2i(x, y))
	return src

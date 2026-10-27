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
const TREE: int = 15       # round pine
const HEDGE: int = 39      # bush
const BUILDING_LEFT: int = 126   # barn wall with doors
const BUILDING_RIGHT: int = 128  # barn wall with window

# --- Tiny Battle: pieces and flags -----------------------------------------------
## Per team (FlagMap.RED, FlagMap.BLUE).
const SOLDIER: Array[int] = [160, 142]
const FLAG: Array[int] = [70, 52]

## Team colours for overlays (bases, paths, HUD).
const TEAM_COLOR: Array[Color] = [Color(0.86, 0.25, 0.22), Color(0.2, 0.45, 0.9)]
const TEAM_NAME: Array[String] = ["Red", "Blue"]


static func coords(index: int, columns: int) -> Vector2i:
	return Vector2i(index % columns, index / columns)


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

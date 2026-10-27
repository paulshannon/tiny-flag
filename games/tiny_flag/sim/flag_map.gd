class_name FlagMap
extends RefCounted
## A Tiny Flag board: terrain per tile, the two halves and the two 3x3 bases.
## Pure rules, no nodes. Parsed from a text map (one character per tile).

enum Terrain { GRASS, PATH, CROPS, TREE, HEDGE, BUILDING, WATER, BASE }

const RED: int = 0
const BLUE: int = 1
const FARM_PATH: String = "res://games/tiny_flag/maps/farm.txt"
const HOME_COUNT: int = 5

## Map character -> terrain. 'R' and 'U' are both BASE; the character says whose.
const CHARS: Dictionary = {
	".": Terrain.GRASS, "=": Terrain.PATH, "w": Terrain.CROPS, "t": Terrain.TREE,
	"h": Terrain.HEDGE, "B": Terrain.BUILDING, "~": Terrain.WATER,
	"R": Terrain.BASE, "U": Terrain.BASE,
}
## Half-points to enter a tile; terrain missing here is impassable.
const COSTS: Dictionary = {
	Terrain.GRASS: 2, Terrain.PATH: 1, Terrain.CROPS: 4, Terrain.TREE: 4, Terrain.BASE: 2,
}

var width: int = 0
var height: int = 0
var _terrain: PackedByteArray = PackedByteArray()
## Per team: top-left corner of that team's 3x3 base.
var _base_origin: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO]


## Returns null (after one push_error starting "FlagMap:") if the text is not a valid map.
static func parse(text: String) -> FlagMap:
	var rows: PackedStringArray = []
	for line: String in text.split("\n"):
		var row := line.strip_edges(false, true)
		if not row.is_empty():
			rows.append(row)
	if rows.is_empty():
		return _fail("no rows")
	var m := FlagMap.new()
	m.width = rows[0].length()
	m.height = rows.size()
	if m.width % 2 != 0:
		return _fail("odd width %d" % m.width)
	m._terrain.resize(m.width * m.height)
	var cells: Array = [[], []]  # per team: Array[Vector2i] of base characters
	for y: int in m.height:
		if rows[y].length() != m.width:
			return _fail("row %d is %d wide, expected %d" % [y, rows[y].length(), m.width])
		for x: int in m.width:
			var ch := rows[y][x]
			if not CHARS.has(ch):
				return _fail("unknown character '%s' at %d,%d" % [ch, x, y])
			m._terrain[y * m.width + x] = CHARS[ch]
			if ch == "R":
				cells[RED].append(Vector2i(x, y))
			elif ch == "U":
				cells[BLUE].append(Vector2i(x, y))
	for team: int in [RED, BLUE]:
		var problem := m._check_base(team, cells[team])
		if not problem.is_empty():
			return _fail(problem)
	return m


static func load_map(path: String) -> FlagMap:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("cannot open %s" % path)
	return parse(file.get_as_text())


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func terrain(c: Vector2i) -> Terrain:
	return _terrain[c.y * width + c.x] as Terrain


## Half-points to enter `c`; -1 if impassable or out of bounds.
func cost(c: Vector2i) -> int:
	if not in_bounds(c):
		return -1
	return COSTS.get(terrain(c), -1)


func blocks_sight(c: Vector2i) -> bool:
	if not in_bounds(c):
		return true
	var t := terrain(c)
	return t == Terrain.TREE or t == Terrain.HEDGE or t == Terrain.BUILDING


## True if a piece standing on `c` is hidden from viewers who aren't adjacent.
func hides(c: Vector2i) -> bool:
	return in_bounds(c) and terrain(c) == Terrain.CROPS


func side_of(c: Vector2i) -> int:
	return RED if c.x < width / 2 else BLUE


func base_tiles(team: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var o := _base_origin[team]
	for y: int in 3:
		for x: int in 3:
			out.append(o + Vector2i(x, y))
	return out


func in_base(c: Vector2i, team: int) -> bool:
	var d := c - _base_origin[team]
	return d.x >= 0 and d.y >= 0 and d.x < 3 and d.y < 3


func flag_home(team: int) -> Vector2i:
	return _base_origin[team] + Vector2i(1, 1)


## The first HOME_COUNT base tiles other than the centre, in reading order.
func home_tiles(team: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var centre := flag_home(team)
	for c: Vector2i in base_tiles(team):
		if c != centre and out.size() < HOME_COUNT:
			out.append(c)
	return out


## Empty string if `cells` form exactly one 3x3 block on `team`'s own half.
func _check_base(team: int, cells: Array) -> String:
	var name := "Red" if team == RED else "Blue"
	if cells.size() != 9:
		return "%s base has %d tiles, expected one 3x3 block" % [name, cells.size()]
	var lo: Vector2i = cells[0]
	var hi: Vector2i = cells[0]
	for c: Vector2i in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	if hi.x - lo.x != 2 or hi.y - lo.y != 2:
		return "%s base is not one 3x3 block" % name
	if side_of(lo) != team or side_of(hi) != team:
		return "%s base is not on its own half" % name
	_base_origin[team] = lo
	return ""


static func _fail(reason: String) -> FlagMap:
	push_error("FlagMap: " + reason)
	return null

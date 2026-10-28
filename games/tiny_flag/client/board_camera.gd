class_name BoardCamera
extends Node
## Pan and zoom for the BoardView, and every pointer gesture on it. A press and release
## that didn't drag becomes `clicked` (mouse) or `tapped` (one finger, no second one);
## OrderInput turns those into orders. Everything else moves the view:
##   Mouse: wheel zooms at the cursor (whole steps, crisp pixels); left or middle drag
##   pans. Trackpad: pinch zooms, two-finger scroll pans.
##   Touch: one-finger drag pans; two fingers pinch-zoom and pan.
## The view never zooms out past the whole zoom that fits the board between the HUD bars
## (the old fixed view), and the board can't be dragged off the screen.
##
## A gesture starts in _unhandled_input, so presses on HUD controls (and `blocked`
## points) never start one; it is followed in _input, so a release a Control consumes
## still ends it. Finger bookkeeping is in _input too and is cleared on focus loss.

## A mouse press and release on the board without a drag in between.
signal clicked(pos: Vector2, button: MouseButton)
## One finger down and up on the board without a drag or a second finger.
signal tapped(pos: Vector2)

const MAX_ZOOM: float = 6.0
## Screen pixels a press can move and still count as a click or tap.
const DRAG_THRESHOLD: float = 8.0
## Trackpad two-finger scroll: screen pixels per unit of InputEventPanGesture.delta.
const PAN_GESTURE_SPEED: float = 12.0

var board: BoardView
## Returns true for screen points over HUD controls, where gestures must not start.
var blocked: Callable
var zoom: float = 1.0
var min_zoom: float = 0.0

## The screen rect the board is shown in (between the HUD bars).
var _area: Rect2 = Rect2()
## Board-local point (pixels) shown at the centre of _area.
var _centre: Vector2 = Vector2.ZERO

# Mouse gesture.
var _mouse_button: MouseButton = MOUSE_BUTTON_NONE
var _mouse_start: Vector2 = Vector2.ZERO
var _mouse_dragging: bool = false

# Touch gesture. Browsers number touches freely (iOS Safari uses large ids, Chrome
# counts up), so fingers are only ever counted, never looked up as index 0.
var _fingers: Dictionary[int, Vector2] = {}
var _touching: bool = false
var _tap_ok: bool = false
var _touch_start: Vector2 = Vector2.ZERO
var _pinch_dist: float = 0.0
var _pinch_zoom: float = 1.0


func _init(board_view: BoardView) -> void:
	board = board_view
	name = "BoardCamera"


## Shows the board in the `size` viewport between `top` and `bottom` margins. The first
## call (and any resize that makes the current zoom too small) fits the whole board.
func fit(size: Vector2, top: float, bottom: float) -> void:
	_area = Rect2(0.0, top, size.x, maxf(1.0, size.y - top - bottom))
	var px := _board_px()
	var fit_zoom := maxf(1.0, floorf(minf(_area.size.x / px.x, _area.size.y / px.y)))
	var first := min_zoom == 0.0
	min_zoom = fit_zoom
	if first or zoom < min_zoom:
		zoom = min_zoom
		_centre = px / 2.0
	_apply()


## Zooms to `new_zoom` (clamped) keeping the board point under `screen_pos` in place.
func zoom_at(screen_pos: Vector2, new_zoom: float) -> void:
	var local := to_board(screen_pos)
	zoom = clampf(new_zoom, min_zoom, MAX_ZOOM)
	_centre = local - (screen_pos - _area.get_center()) / zoom
	_apply()


## The next whole zoom in (`steps` > 0) or out (< 0).
func step_zoom(screen_pos: Vector2, steps: int) -> void:
	var z := floorf(zoom + 0.001) + steps if steps > 0 else ceilf(zoom - 0.001) + steps
	zoom_at(screen_pos, z)


## Moves the view so the board follows a pointer that moved by `screen_delta`.
func pan_by(screen_delta: Vector2) -> void:
	_centre -= screen_delta / zoom
	_apply()


## Board-local pixels under a screen point.
func to_board(screen_pos: Vector2) -> Vector2:
	return (screen_pos - board.position) / board.scale.x


func is_zoomed_in() -> bool:
	return zoom > min_zoom + 0.001


func _board_px() -> Vector2:
	return Vector2(board.map.width, board.map.height) * FlagArt.TILE


## Clamps the centre so the board covers the area (or sits centred where it's smaller),
## then places the board on whole screen pixels.
func _apply() -> void:
	var px := _board_px()
	var half := _area.size / (2.0 * zoom)
	for axis: int in 2:
		if px[axis] <= half[axis] * 2.0:
			_centre[axis] = px[axis] / 2.0
		else:
			_centre[axis] = clampf(_centre[axis], half[axis], px[axis] - half[axis])
	if board.scale.x != zoom:
		board.scale = Vector2(zoom, zoom)
		board.zoom_changed()
	board.position = (_area.get_center() - _centre * zoom).round()


func _input(event: InputEvent) -> void:
	_follow(event)


func _unhandled_input(event: InputEvent) -> void:
	if _start(event):
		get_viewport().set_input_as_handled()


## Releases eaten by an app switch or a system gesture never arrive: start clean.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		_fingers.clear()
		_touching = false
		_mouse_button = MOUSE_BUTTON_NONE


## Both stages, as the engine runs them (_input first): for tests. True if the event
## started a gesture or ended one in a click or tap.
func handle_event(event: InputEvent) -> bool:
	var ended := _follow(event)
	return _start(event) or ended


## Starts gestures and handles one-shot ones (wheel, trackpad). True if used.
func _start(event: InputEvent) -> bool:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.device != InputEvent.DEVICE_ID_EMULATION:
		if not _on_board(mb.position):
			return false
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				step_zoom(mb.position, 1)
				return true
			MOUSE_BUTTON_WHEEL_DOWN:
				step_zoom(mb.position, -1)
				return true
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				if _mouse_button == MOUSE_BUTTON_NONE:
					_mouse_button = mb.button_index
					_mouse_start = mb.position
					_mouse_dragging = mb.button_index == MOUSE_BUTTON_MIDDLE
				return true
		return false
	var mg := event as InputEventMagnifyGesture
	if mg != null and _on_board(mg.position):
		zoom_at(mg.position, zoom * mg.factor)
		return true
	var pg := event as InputEventPanGesture
	if pg != null and _on_board(pg.position):
		pan_by(-pg.delta * PAN_GESTURE_SPEED)
		return true
	var st := event as InputEventScreenTouch
	if st != null and st.pressed and _fingers.size() == 1 and _fingers.has(st.index) and not _touching:
		if not _on_board(st.position):
			return false  # e.g. the starter's touch Menu button: leave it to other controls
		_touching = true
		_tap_ok = true
		_touch_start = st.position
		return true
	return false


## Follows gestures already started, and keeps finger bookkeeping for every touch.
## True if this event ended a gesture in a click or tap.
func _follow(event: InputEvent) -> bool:
	var mm := event as InputEventMouseMotion
	if mm != null and _mouse_button != MOUSE_BUTTON_NONE and mm.device != InputEvent.DEVICE_ID_EMULATION:
		if not _mouse_dragging and mm.position.distance_to(_mouse_start) > DRAG_THRESHOLD:
			_mouse_dragging = _mouse_button != MOUSE_BUTTON_RIGHT
			if not _mouse_dragging:
				_mouse_button = MOUSE_BUTTON_NONE  # a right drag is no click and no pan
		if _mouse_dragging:
			pan_by(mm.relative)
		return false
	var mb := event as InputEventMouseButton
	if mb != null and not mb.pressed and mb.button_index == _mouse_button \
			and mb.device != InputEvent.DEVICE_ID_EMULATION:
		var was_click := not _mouse_dragging
		_mouse_button = MOUSE_BUTTON_NONE
		if was_click and not _is_blocked(mb.position):
			clicked.emit(mb.position, mb.button_index)
			return true
		return false
	var st := event as InputEventScreenTouch
	if st != null:
		if st.pressed:
			_fingers[st.index] = st.position
			if _fingers.size() == 2 and _touching:
				_tap_ok = false
				_begin_pinch()
			return false
		_fingers.erase(st.index)
		if _fingers.size() == 1:
			_pinch_dist = 0.0
		if not _fingers.is_empty() or not _touching:
			return false
		_touching = false
		if _tap_ok and not _is_blocked(st.position):
			tapped.emit(st.position)
			return true
		return false
	var sd := event as InputEventScreenDrag
	if sd != null and _fingers.has(sd.index):
		var before: Vector2 = _fingers[sd.index]
		_fingers[sd.index] = sd.position
		if not _touching:
			return false
		if _fingers.size() == 1:
			if _tap_ok and sd.position.distance_to(_touch_start) <= DRAG_THRESHOLD:
				return false
			_tap_ok = false
			pan_by(sd.position - before)
		elif _fingers.size() == 2 and _pinch_dist > 0.0:
			# The board point that was between the fingers stays between them: zoom
			# around where it was, then carry it to where the midpoint is now.
			var mid := _midpoint()
			var mid_before := mid + (before - sd.position) / 2.0
			zoom_at(mid_before, _pinch_zoom * _finger_dist() / _pinch_dist)
			pan_by(mid - mid_before)
	return false


func _begin_pinch() -> void:
	_pinch_dist = maxf(_finger_dist(), 1.0)
	_pinch_zoom = zoom


func _finger_dist() -> float:
	var pts := _fingers.values()
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


func _midpoint() -> Vector2:
	var pts := _fingers.values()
	return ((pts[0] as Vector2) + (pts[1] as Vector2)) / 2.0


func _on_board(pos: Vector2) -> bool:
	return _area.has_point(pos) and board.map.in_bounds(board.tile_at(pos)) and not _is_blocked(pos)


func _is_blocked(pos: Vector2) -> bool:
	return blocked.is_valid() and bool(blocked.call(pos))

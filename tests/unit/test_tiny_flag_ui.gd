extends TestCase
## FlagUi's theme (Kenney UI Pack) and the UI paths FlagArt names.


func test_theme_builds_without_errors() -> void:
	var theme := FlagUi.make_theme()
	assert_true(theme is Theme)
	assert_true(theme.has_stylebox("normal", "Button"))
	assert_true(theme.has_stylebox("hover", "Button"))
	assert_true(theme.has_stylebox("pressed", "Button"))
	assert_true(theme.has_stylebox("disabled", "Button"))
	assert_true(theme.has_stylebox("focus", "Button"))
	assert_true(theme.has_stylebox("panel", "PanelContainer"))
	assert_true(theme.has_default_font())
	assert_true(theme.default_font is FontFile)
	assert_true(theme.has_icon("icon", FlagUi.CLEAR_BUTTON))
	for v: StringName in [FlagUi.LOCK_BUTTON, FlagUi.CLEAR_BUTTON, FlagUi.BAR, FlagUi.CARD]:
		assert_true(not theme.get_type_variation_base(v).is_empty(), "variation %s" % v)
	for t: StringName in FlagUi.TEAM_TAG:
		assert_true(theme.has_stylebox("panel", t), "team tag %s" % t)
	for t: StringName in FlagUi.TEAM_BANNER:
		assert_true(theme.has_stylebox("panel", t), "team banner %s" % t)


func test_every_ui_path_loads() -> void:
	var paths: Array[String] = FlagArt.ui_paths()
	assert_true(paths.size() >= 7, "expected the UI paths, got %d" % paths.size())
	for p: String in paths:
		assert_true(p.begins_with("res://assets/kenney/ui-pack/"), p)
		var r: Resource = load(p)
		if p.ends_with(".ttf"):
			assert_true(r is FontFile, p)
		else:
			assert_true(r is Texture2D, p)


func test_theme_is_cached() -> void:
	assert_true(FlagUi.make_theme() == FlagUi.make_theme())


## The web build has no system fonts, so a glyph the pack font lacks draws as a box.
## Builds the HUD and menu, drives them through their states and checks every string.
func test_hud_and_menu_text_has_glyphs_in_the_pack_font() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var hud := TurnHud.new()
	tree.root.add_child(hud)
	var menu := FlagMenu.new({InputSetup.MENU: "Back to select"})
	tree.root.add_child(menu)
	var texts: Array[String] = []
	var view := {"team": FlagMap.RED, "turn": 6, "turn_limit": 40, "score": [1, 2]}
	hud.on_turn_started(30.0, view)
	hud._process(0.5)
	_collect(hud, texts)
	hud.on_event({"kind": "tag", "piece": 6})
	hud.on_event({"kind": "pickup", "piece": 1, "flag": 1})
	hud.on_event({"kind": "capture", "piece": 7})
	hud.on_turn_resolved({"turn": 6})
	hud.on_match_over({"result": FlagState.Result.BLUE_WINS, "score": [1, 3]})
	_collect(hud, texts)
	view["team"] = FlagWire.SPECTATOR
	hud.on_turn_started(30.0, view)
	hud.on_match_over({"result": FlagState.Result.DRAW, "score": [3, 3]})
	_collect(hud, texts)
	menu.show_menu("Disconnected from server", "Try again")
	_collect(menu, texts)
	menu._show_controls()
	_collect(menu, texts)
	var font := load(FlagArt.UI_FONT) as FontFile
	for s: String in texts:
		for i: int in s.length():
			var c := s.unicode_at(i)
			assert_true(c == 10 or font.has_char(c), "%s lacks %s in \"%s\"" % [FlagArt.UI_FONT.get_file(), s[i], s])
	assert_true(texts.size() > 10, "collected %d strings" % texts.size())
	hud.free()
	menu.free()


func _collect(n: Node, out: Array[String]) -> void:
	if n is Label and not (n as Label).text.is_empty():
		out.append((n as Label).text)
	elif n is Button and not (n as Button).text.is_empty():
		out.append((n as Button).text)
	for c: Node in n.get_children():
		_collect(c, out)

extends TestCase
## The join choice a client sends before its player spawns (GameBase): the
## server must turn anything into valid spawn data. A game's _sanitize_choice()
## builds it from GameBase.choice_int, so that is what's tested here.


func test_choice_int_reads_numbers_only() -> void:
	assert_eq(GameBase.choice_int({"k": 3}, "k", 7), 3)
	assert_eq(GameBase.choice_int({"k": 2.9}, "k", 7), 2)
	assert_eq(GameBase.choice_int({}, "k", 7), 7, "missing")
	assert_eq(GameBase.choice_int({"k": "3"}, "k", 7), 7, "a string isn't a number")
	assert_eq(GameBase.choice_int({"k": [1]}, "k", 7), 7)
	assert_eq(GameBase.choice_int({"k": NAN}, "k", 7), 7)
	assert_eq(GameBase.choice_int({"k": INF}, "k", 7), 7)


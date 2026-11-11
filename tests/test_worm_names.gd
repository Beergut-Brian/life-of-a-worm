## D90: the green worm is Gulp, the red worm is Burp, and the menus say so.
class_name TestWormNames
extends GdUnitTestSuite


func test_worm_display_names_are_gulp_and_burp() -> void:
	assert_str(WormNames.of(Players.P1)).is_equal("Gulp")
	assert_str(WormNames.of(Players.P2)).is_equal("Burp")


func test_menu_player_labels_use_the_worm_names() -> void:
	assert_str(UiStyle.player_name(Players.P1)).is_equal("Gulp")
	assert_str(UiStyle.player_name(Players.P2)).is_equal("Burp")
	# The names follow the slot colours: green Gulp, red Burp.
	assert_object(UiStyle.player_color(Players.P1)).is_equal(Color("3cc24a"))
	assert_object(UiStyle.player_color(Players.P2)).is_equal(Color("e4393c"))

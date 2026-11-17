## PictoBubble's picture registry is a static Dictionary that lives until the engine quits, after
## the scripts that registered into it are destroyed. A lambda left in it is an "orphaned lambda":
## when the Dictionary lets go of it, Godot frees it against its dead script, which corrupts the heap
## and aborts the process (exit 134, "corrupted size vs. prev_size") after every test has passed.
## So every drawer the game registers must be a plain method Callable, never a lambda.
class_name TestPictoRegistryNoLambdas
extends GdUnitTestSuite


func _lambdas() -> Array[String]:
	var bad: Array[String] = []
	for id in PictoBubble._drawers:
		var cb: Callable = PictoBubble._drawers[id]
		if cb.is_custom():
			bad.append("drawer %s" % id)
	for p in PictoBubble._prefixes:
		var cb: Callable = PictoBubble._prefixes[p]
		if cb.is_custom():
			bad.append("prefix %s" % p)
	return bad


func test_every_static_registrar_uses_named_funcs() -> void:
	SecretLook.register()
	StoryPictures.register_all()
	PetLook.register_pictures()
	assert_array(_lambdas()).override_failure_message("lambdas in PictoBubble: %s" % [_lambdas()]).is_empty()
	# The prefix still draws through the named func (same picture as before).
	assert_bool(PictoBubble.has_picture(&"secret:ant_city")).is_true()

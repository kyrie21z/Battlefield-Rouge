extends SceneTree
## Native rendering regression for the user's clipped-hand report.
const Avatar = preload("res://ui/pride_opening/crown_avatar.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(384, 300)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var avatar := Avatar.new()
	avatar.size = Vector2(384, 300)
	avatar.motion_enabled = false
	viewport.add_child(avatar)
	var source := Avatar.ATLAS.get_image()
	for cell in range(6):
		var origin := Vector2i((cell % 2) * 512, (cell / 2) * 512)
		var source_alpha: float = 0.0
		for i in range(512):
			source_alpha = maxf(source_alpha, source.get_pixel(origin.x + i, origin.y).a)
			source_alpha = maxf(source_alpha, source.get_pixel(origin.x + i, origin.y + 511).a)
			source_alpha = maxf(source_alpha, source.get_pixel(origin.x, origin.y + i).a)
			source_alpha = maxf(source_alpha, source.get_pixel(origin.x + 511, origin.y + i).a)
		checks += 1
		if source_alpha > 0.01:
			failures += 1
			push_error("Source atlas clips a silhouette at cell %d" % cell)
	for variant in [["greeting", true], ["explaining", true], ["waiting", false], ["waiting", true], ["encouraging", true]]:
		for time in [0.0, PI / 12.0, PI / 4.0, 4.4]:
			avatar.pose = variant[0]
			avatar.clock = time
			avatar.speaking = variant[1]
			avatar.queue_redraw()
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			var border_alpha: float = 0.0
			for x in range(384):
				border_alpha = maxf(border_alpha, maxf(image.get_pixel(x, 0).a, image.get_pixel(x, 299).a))
			for y in range(300):
				border_alpha = maxf(border_alpha, maxf(image.get_pixel(0, y).a, image.get_pixel(383, y).a))
			checks += 1
			if border_alpha > 0.01 or image.get_pixel(192, 165).a < 0.5:
				failures += 1
				push_error("Clipped or empty crown: %s @ %s; edge alpha=%s" % [variant[0], time, border_alpha])
	viewport.queue_free()
	await process_frame
	print("AVATAR BOUNDS TEST: ", checks, " checks (6 source cells, 20 rendered poses), ", failures, " failures")
	quit(0 if failures == 0 else 1)

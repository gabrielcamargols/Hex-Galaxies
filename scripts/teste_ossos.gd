extends Node
func run() -> void:
	for c in ["k_cmd", "rhazur", "rei_mina", "w_mamute", "l_general", "karo"]:
		var inst = load(get_parent().board.FIG3D[c]["path"]).instantiate()
		add_child(inst)
		var s = c + ": "
		for sk in inst.find_children("*", "Skeleton3D", true, false):
			s += "%d ossos; " % sk.get_bone_count()
			for i in sk.get_bone_count():
				var n = sk.get_bone_name(i)
				if c in ["w_mamute", "l_general"] and not ("finger" in n.to_lower() or "Index" in n or "Thumb" in n or "Mid" in n or "Ring" in n or "Pinky" in n):
					s += n.replace("mixamorig_", "").replace("mixamorig:", "") + " "
		for ap in inst.find_children("*", "AnimationPlayer", true, false):
			s += " | anims: " + str(ap.get_animation_list())
		print(s)
		inst.queue_free()

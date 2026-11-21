extends Node
## Grava o especial de um líder: CID=k_cmd|rhazur|rei_mina|w_mamute|l_general|karo
func run() -> void:
	var m = get_parent()
	m._start_deus()
	for i in 200:
		await get_tree().process_frame
	m.ui.visible = false
	var g = m.game
	var b = m.board
	var cid = OS.get_environment("CID")
	var livre = func(h): return g.is_free(h) and not g.blocks.has(h) and int(g.terr(h).get("h", 0)) == 0
	var D = DB.DIRS[0]
	var hs = DB.hexes.filter(func(h): return livre.call(h) and range(1, 6).all(func(i): return livre.call(h + D * i)) and DB.nbrs(h + D * 4).all(func(n): return livre.call(n)) and DB.nbrs(h + D * 3).all(func(n): return livre.call(n)))
	var h0 = hs[hs.size() / 2]
	var u = g._mk(cid, 0, "field")
	u.q = h0.x
	u.r = h0.y
	var alvo = h0 + D * 4
	var inimigos = []
	var pos_e = {"k_cmd": [alvo, alvo + DB.DIRS[1], alvo + DB.DIRS[3]], "rhazur": [alvo + D], "l_general": [h0 + D * 3, h0 + D * 3 + DB.DIRS[2]], "w_mamute": [h0 + D * 2], "rei_mina": [alvo + D], "karo": [alvo + D]}[cid]
	for i in range(pos_e.size()):
		var e = g._mk(["k_tank", "k_front", "z_vang"][i % 3] if cid != "k_cmd" else ["z_tank", "z_vang", "z_brawler"][i % 3], 1, "field")
		e.q = pos_e[i].x
		e.r = pos_e[i].y
		e.hp = 30
		e.maxhp = 30
		inimigos.append(e)
	m.refresh()
	var foco = h0 + D * 2
	b.cam_goal = null
	b.cam_target = Vector3(b.world_xz(foco).x, b.top_y(foco) + 1.0, b.world_xz(foco).y)
	b.cam_dist = 11.0
	b.cam_pitch = 0.42
	var dv = Vector3(b.world_xz(alvo).x - b.world_xz(h0).x, 0, b.world_xz(alvo).y - b.world_xz(h0).y)
	b.cam_yaw = atan2(dv.x, dv.z) + PI / 2.0 + 0.55
	for i in 40:
		await get_tree().process_frame
	# respostas automáticas às perguntas do especial
	var resp = []
	match cid:
		"k_cmd": resp = [alvo]
		"rhazur": resp = [pos_e[0]]
		"l_general": resp = [pos_e[0]]
		"w_mamute": resp = [h0 + D * 3]
		"rei_mina": resp = [h0 + D * 2 + DB.DIRS[1], null, 0, 1, 2, 0, 1]
	g.question.connect(func(_p, q):
		var v = resp.pop_front() if not resp.is_empty() else null
		if v == null and q.get("t", "") == "hex" or (v == null and q.has("opts") and q["opts"] is Array and not q["opts"].is_empty() and q["opts"][0] is Vector2i):
			v = q["opts"][q["opts"].size() - 1]
		g.answered.emit.call_deferred(v))
	if cid == "karo":
		u.st = "reserve"
		m.refresh()
		await get_tree().process_frame
		u.st = "field"
		m.refresh()
		await g.entry_effect(u)
		m.refresh()
	else:
		g.start_activation(u)
		await g.act_ult(u)
	for i in 150:
		await get_tree().process_frame
	if OS.has_environment("DBG"):
		for x in g.units:
			if x.crystal != "" and b.unit_nodes.has(x.uid):
				var dd = b.unit_nodes[x.uid]
				print("CRISTAL ", x.uid, " st=", x.st, " vis=", dd["node"].visible, " pos=", dd["node"].position, " brota=", dd.get("brota", "-"), " pop=", dd["pop"], " esc=", dd["node"].scale)

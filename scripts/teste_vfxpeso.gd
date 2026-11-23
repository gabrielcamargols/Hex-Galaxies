extends Node
## PESO DOS VFX (pensando no tablet / navegador): toca cada receita da Forja sozinha no palco da
## Oficina e mede o pico de chamadas de desenho, triângulos, partículas vivas, nós e o tempo de quadro.
## Também confere se tudo some no fim (nada vazando). Rodar no renderizador do navegador:
##   xvfb-run godot --path . --rendering-method gl_compatibility -- --teste=vfxpeso
## Saída: user://vfx_peso.json (ou PESO_SAIDA) e um resumo no console.

func _particulas(n: Node) -> int:
	var tot = 0
	for c in n.find_children("*", "CPUParticles3D", true, false):
		var cp: CPUParticles3D = c
		if cp.visible and cp.is_inside_tree():
			tot += cp.amount
	return tot


# cobertura de tela estimada: soma das áreas dos quads transparentes projetados / área da tela.
# 1.0 = a tela inteira pintada uma vez a mais (o que pesa no tablet é pintar pixel transparente várias vezes).
func _cobertura(vfx: Node, cam: Camera3D) -> float:
	var vp = get_viewport().get_visible_rect().size
	var f = vp.y / (2.0 * tan(deg_to_rad(cam.fov) * 0.5))
	var tot = 0.0
	for c in vfx.find_children("*", "GeometryInstance3D", true, false):
		if not (c as Node3D).is_visible_in_tree():
			continue
		var d = max(0.5, cam.global_position.distance_to(c.global_position))
		var w = 0.0
		var n = 1
		if c is CPUParticles3D:
			var cp: CPUParticles3D = c
			if not cp.emitting and cp.one_shot:
				continue
			var m = cp.mesh
			w = (m.size.x if m is QuadMesh else 0.3) * cp.scale_amount_max
			n = cp.amount
		elif c is Sprite3D:
			var sp: Sprite3D = c
			if sp.texture == null:
				continue
			w = sp.texture.get_width() / float(max(1, sp.hframes)) * sp.pixel_size
		elif c is MeshInstance3D:
			var ab = (c as MeshInstance3D).get_aabb()
			w = max(ab.size.x, ab.size.y) * (c as Node3D).global_transform.basis.get_scale().x
		var px = w * f / d
		tot += px * px * n
	return tot / (vp.x * vp.y)


# sobreposição (overdraw): só no Forward+ (o modo de depuração não existe no Compatibility).
# Calibração da skill de VFX: cada camada transparente soma ~0.070 de luma linear.
var od := false
var base_od := 0.0
func _camadas() -> Array:
	var img = get_viewport().get_texture().get_image()
	img.resize(320, 180, Image.INTERPOLATE_NEAREST)
	var vs = []
	for y in range(0, 180, 2):
		for x in range(0, 320, 2):
			var c = img.get_pixel(x, y).srgb_to_linear()
			vs.append(c.get_luminance() / 0.07)
	vs.sort()
	return [vs[int(vs.size() * 0.99)], vs[vs.size() - 1]]


func _quadro() -> float:
	var t0 = Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	return (Time.get_ticks_usec() - t0) / 1000.0


func run() -> void:
	var of = Node3D.new()
	of.set_script(load("res://scripts/oficina_vfx.gd"))
	add_child(of)
	for i in 10:
		await get_tree().process_frame
	if of.ui != null:
		of.ui.visible = false
	var vfx = of.vfx
	od = OS.get_environment("PESO_OVERDRAW") != ""
	if od:
		get_viewport().debug_draw = Viewport.DEBUG_DRAW_OVERDRAW
	var ids = []
	for id in vfx.receitas.keys():
		if not str(id).begins_with("_"):
			ids.append(id)
	ids.sort()
	var so = OS.get_environment("PESO_IDS")
	if so != "":
		ids = ids.filter(func(i): return Array(so.split(",")).any(func(k): return str(i).contains(k)))
	# base: palco parado, sem efeito
	var base_ms = []
	var base_dc = 0
	for i in 40:
		base_ms.append(await _quadro())
		base_dc = max(base_dc, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	base_ms.sort()
	base_od = _camadas()[0] if od else 0.0
	var base = base_ms[base_ms.size() / 2]
	var nos0 = vfx.get_child_count()
	var res = {}
	for id in ids:
		of.tocar(id)
		var pico = {"dc": 0, "tri": 0, "part": 0, "nos": 0, "ms": 0.0, "od99": 0.0, "odmax": 0.0, "cob": 0.0}
		var k = 0
		var mss = []
		var t = 0.0
		while t < 2.8:
			var ms = await _quadro()
			t += 1.0 / 60.0 if ms < 1000.0 / 60.0 else ms / 1000.0
			mss.append(ms)
			pico["dc"] = max(pico["dc"], int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)) - base_dc)
			pico["tri"] = max(pico["tri"], int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
			pico["part"] = max(pico["part"], _particulas(vfx))
			pico["nos"] = max(pico["nos"], vfx.get_child_count() - nos0)
			k += 1
			pico["cob"] = max(pico["cob"], snappedf(_cobertura(vfx, of.cam), 0.01))
			if od and k % 3 == 0:
				var cm = _camadas()
				pico["od99"] = max(pico["od99"], snappedf(cm[0] - base_od, 0.1))
				pico["odmax"] = max(pico["odmax"], snappedf(cm[1] - base_od, 0.1))
		mss.sort()
		pico["ms"] = snappedf(mss[int(mss.size() * 0.95)] - base, 0.01)   # p95 acima do palco parado
		# espera esvaziar (o que sobrar depois de 3 s é vazamento)
		var esp = 0.0
		while vfx.get_child_count() > nos0 and esp < 3.0:
			await get_tree().create_timer(0.1).timeout
			esp += 0.1
		pico["sobra"] = vfx.get_child_count() - nos0
		res[id] = pico
	var saida = OS.get_environment("PESO_SAIDA")
	if saida == "":
		saida = "user://vfx_peso.json"
	var f = FileAccess.open(saida, FileAccess.WRITE)
	f.store_string(JSON.stringify({"base_ms": base, "base_dc": base_dc, "fx": res}, " "))
	f.close()
	print("PESO base %.2f ms, %d receitas -> %s" % [base, res.size(), saida])

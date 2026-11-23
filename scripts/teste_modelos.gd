extends Node
## Mede os modelos 3D: pés escorregando, flutuar/afundar, mãos atravessando o corpo.
var b

func _p(fig: Node3D, sk: Skeleton3D, i: int) -> Vector3:
	return fig.get_parent().global_transform.affine_inverse() * (sk.global_transform * sk.get_bone_global_pose(i).origin)

func _seg(p: Vector3, a: Vector3, c: Vector3) -> float:
	var ab = c - a
	var t = clamp((p - a).dot(ab) / max(ab.length_squared(), 1e-6), 0.0, 1.0)
	return (a + ab * t).distance_to(p)

func run() -> void:
	b = get_parent().board
	var alvo = OS.get_environment("SO")
	for c in b.FIG3D.keys():
		if alvo != "" and c != alvo:
			continue
		var fig: Node3D = b._figure3d(c, 2.0)
		var holder = Node3D.new()
		add_child(holder)
		holder.add_child(fig)
		var sk: Skeleton3D = fig.get_meta("skel")
		var drag = fig.has_meta("dragao")
		var pes = []
		var maos = []
		var coxas = []
		var H = 2.0
		if drag:
			for n in ["0_Left_Limb_4", "0_Right_Limb_3", "1_Left_Limb_3", "1_Right_Limb_3"]:
				pes.append(sk.find_bone("tripo__" + n))
		else:
			for n in ["LeftToeBase", "RightToeBase", "LeftFoot", "RightFoot"]:
				pes.append(b._osso(sk, n))
			for n in ["LeftHand", "RightHand"]:
				maos.append(b._osso(sk, n))
			for s in ["Left", "Right"]:
				coxas.append([b._osso(sk, s + "UpLeg"), b._osso(sk, s + "Leg"), b._osso(sk, s + "Foot")])
		# altura real e chão de repouso
		await get_tree().process_frame
		sk.reset_bone_poses()
		var chao = 99.0
		for p in pes:
			chao = min(chao, _p(fig, sk, p).y)
		var ab = AABB()
		var first = true
		for mi in fig.find_children("*", "MeshInstance3D", true, false):
			var a = fig.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
			ab = a if first else ab.merge(a)
			first = false
		H = ab.size.y
		var out = "MODELO %s altura %.2f base_malha %.3f pe_repouso %.3f\n" % [c, H, ab.position.y, chao]
		for modo in ["parado", "andando", "correndo", "golpe", "dano", "conjura"]:
			if modo == "conjura" and not fig.has_meta("conjura"):
				continue
			sk.reset_bone_poses()
			for mm in ["walk_w", "run_w", "fase", "cj_t", "cj_w"]:
				fig.set_meta(mm, 0.0)
			var t = 0.0
			var slide = 0.0
			var lowmin = 99.0
			var lowmax = -99.0
			var lowsum = 0.0
			var nlow = 0
			var maomin = 99.0
			var ini = {}
			for k in 360:
				t += 1.0 / 30.0
				fig.position = Vector3.ZERO
				var walk = modo == "andando" or modo == "correndo"
				var lunge = 0.0
				var hurt = 0.0
				if modo == "golpe":
					lunge = max(0.0, 1.0 - fmod(t, 1.5) * 1.6)
				if modo == "dano":
					hurt = max(0.0, 1.0 - fmod(t, 1.5) * 2.5)
				if modo == "conjura" and k % 60 == 0:
					fig.set_meta("cj_t", 1.5)
				if drag:
					b._dragao_tick(fig, 1.0 / 30.0, t, walk, modo == "correndo", lunge, hurt)
				else:
					b._fig3d_tick(fig, 1.0 / 30.0, t, false, Color.WHITE, walk, lunge, hurt, modo == "correndo", Vector3.ZERO)
				if fig.has_meta("folga"):
					fig.get_meta("folga")._process_modification_with_delta(1.0 / 30.0)   # sem esperar o quadro: roda a folga na mão
				if k < 45:
					if fig.has_meta("folga"):
						fig.get_meta("folga").penetra_max = -1.0
						fig.get_meta("folga").resto_max = -1.0
					continue
				var low = 99.0
				for p in pes:
					var q = _p(fig, sk, p)
					low = min(low, q.y)
					if modo == "parado" or modo == "dano":
						if not ini.has(p):
							ini[p] = q
						slide = max(slide, Vector2(q.x - ini[p].x, q.z - ini[p].z).length())
				low -= chao
				lowmin = min(lowmin, low)
				lowmax = max(lowmax, low)
				lowsum += low
				nlow += 1
				for i in range(maos.size()):
					if maos[i] < 0:
						continue
					var h = _p(fig, sk, maos[i])
					for cx in coxas:
						if cx[0] < 0:
							continue
						var d = min(_seg(h, _p(fig, sk, cx[0]), _p(fig, sk, cx[1])), _seg(h, _p(fig, sk, cx[1]), _p(fig, sk, cx[2])))
						maomin = min(maomin, d)
			var fb = fig.get_meta("folga") if fig.has_meta("folga") else null
			var pen = fb.penetra_max if fb != null else -1.0
			if fb != null:
				fb.penetra_max = -1.0
			out += "  braço-entrando antes %.2f depois %.2f\n" % [pen, fb.resto_max if fb != null else -1.0]
			out += "  %-9s pe_mais_baixo(%%altura) med %+.1f min %+.1f max %+.1f | escorrega %.1f%% | mao-perna %.1f%%\n" % [modo, 100.0 * lowsum / nlow / H, 100.0 * lowmin / H, 100.0 * lowmax / H, 100.0 * slide / H, 100.0 * maomin / H if maomin < 90 else -1.0]
		print(out)
		holder.queue_free()
		await get_tree().process_frame

extends SkeletonModifier3D
## Folga dos braços: roda depois de toda pose (animação do arquivo, pose do código, gestos) e,
## se cotovelo, antebraço ou mão entrariam no tronco/quadril/roupa, abre o braço para fora o mínimo
## necessário. O "corpo" é medido uma vez a partir da própria malha (vértices presos ao tronco),
## então serve para qualquer modelo: armadura larga, barriga, capa, casaco.

const OSSOS_TRONCO = ["Hips", "Spine", "Spine1", "Spine2"]
const N_FAIXAS = 18

var F := Vector3.FORWARD     # eixos do boneco no espaço do esqueleto (frente, lado esquerdo, cima)
var S := Vector3.LEFT
var U := Vector3.UP
var faixas: Array = []       # por altura: [osso, centro no espaço do osso em repouso, -S, +S, -F, +F]
var u0 := 0.0                # altura (em U) da primeira faixa
var du := 1.0                # altura de cada faixa
var braco := {}              # lado -> {arm, fore, hand, ponta, raio, fora(+1/-1)}
var aberto := {"Left": 0.0, "Right": 0.0}       # abertura atual do braço (rad)
var aberto_ab := {"Left": 0.0, "Right": 0.0}    # abertura extra do antebraço
var _t_ant := -1.0
var resto_max := -1.0       # o que sobrou depois da correção (tem que ficar <= 0)
var penetra_max := 0.0       # medida para o teste: quanto um ponto do braço chegou a entrar antes da correção


func prepara(sk: Skeleton3D, malhas: Array, bones: Dictionary, ax: Array, folga: float = 1.0) -> bool:
	F = ax[0]
	S = ax[1]
	U = ax[2]
	var tronco_ids = {}
	for nm in OSSOS_TRONCO:
		if bones.has(nm):
			tronco_ids[bones[nm]] = true
	var lados = {}
	for side in ["Left", "Right"]:
		if bones.has(side + "Arm") and bones.has(side + "ForeArm") and bones.has(side + "Hand"):
			lados[side] = {"arm": bones[side + "Arm"], "fore": bones[side + "ForeArm"], "hand": bones[side + "Hand"]}
	if tronco_ids.is_empty() or lados.is_empty():
		return false
	var pts_tronco: Array = []    # [pos esqueleto, osso]
	var dist_braco = {"Left": [], "Right": []}
	for mi in malhas:
		var skin: Skin = mi.skin
		if skin == null or mi.mesh == null:
			continue
		var bind_osso = []
		for i in skin.get_bind_count():
			var bo = skin.get_bind_bone(i)
			if bo < 0:
				bo = sk.find_bone(skin.get_bind_name(i))
			bind_osso.append(bo)
		for si in mi.mesh.get_surface_count():
			var arr = mi.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bs = arr[Mesh.ARRAY_BONES]
			var ws = arr[Mesh.ARRAY_WEIGHTS]
			if bs == null or ws == null or vs.size() == 0:
				continue
			var n = int(bs.size() / vs.size())
			var passo = max(1, int(vs.size() / 6000))     # amostra até ~6000 vértices por superfície
			for vi in range(0, vs.size(), passo):
				var melhor = -1
				var wmax = -1.0
				for j in n:
					if ws[vi * n + j] > wmax:
						wmax = ws[vi * n + j]
						melhor = bs[vi * n + j]
				if melhor < 0 or melhor >= bind_osso.size():
					continue
				var ob: int = bind_osso[melhor]
				if ob < 0:
					continue
				var p = sk.get_bone_global_rest(ob) * skin.get_bind_pose(melhor) * vs[vi]
				if tronco_ids.has(ob):
					pts_tronco.append([p, ob])
				else:
					for side in lados.keys():
						var L: Dictionary = lados[side]
						if ob == L["arm"] or ob == L["fore"]:
							var a = sk.get_bone_global_rest(ob).origin
							var filho = L["fore"] if ob == L["arm"] else L["hand"]
							var c = sk.get_bone_global_rest(filho).origin
							dist_braco[side].append(_dist_seg(p, a, c))
	if pts_tronco.size() < 30:
		return false
	# faixas de altura do quadril ao pescoço
	var umin = 1e9
	var umax = -1e9
	for e in pts_tronco:
		var u = e[0].dot(U)
		umin = min(umin, u)
		umax = max(umax, u)
	u0 = umin
	du = max((umax - umin) / N_FAIXAS, 0.001)
	var grupos = []
	for i in N_FAIXAS:
		grupos.append([])
	for e in pts_tronco:
		var i = clampi(int((e[0].dot(U) - u0) / du), 0, N_FAIXAS - 1)
		grupos[i].append(e)
	faixas = []
	for i in N_FAIXAS:
		var gr: Array = grupos[i]
		if gr.size() < 6:
			faixas.append(null)
			continue
		# osso que mais segura essa faixa, e o centro/limites (percentis, para uma ponta de capa não dominar)
		var conta = {}
		var ss = []
		var ff = []
		var cen = Vector3.ZERO
		for e in gr:
			conta[e[1]] = conta.get(e[1], 0) + 1
			ss.append(e[0].dot(S))
			ff.append(e[0].dot(F))
			cen += e[0]
		cen /= gr.size()
		ss.sort()
		ff.sort()
		var osso = conta.keys()[0]
		for k in conta.keys():
			if conta[k] > conta[osso]:
				osso = k
		var smin = ss[int(ss.size() * 0.04)]
		var smax = ss[int(ss.size() * 0.96) - 1]
		var fmin = ff[int(ff.size() * 0.04)]
		var fmax = ff[int(ff.size() * 0.96) - 1]
		var meio_s = (smin + smax) * 0.5
		var meio_f = (fmin + fmax) * 0.5
		var c_esq = S * meio_s + F * meio_f + U * cen.dot(U)
		faixas.append([osso, sk.get_bone_global_rest(osso).affine_inverse() * c_esq,
			(meio_s - smin) * folga, (smax - meio_s) * folga, (meio_f - fmin) * folga, (fmax - meio_f) * folga])
	# raio do braço (antebraço e manga), lado de fora
	var cen_tronco = Vector3.ZERO
	for e in pts_tronco:
		cen_tronco += e[0]
	cen_tronco /= pts_tronco.size()
	for side in lados.keys():
		var L: Dictionary = lados[side]
		var dl: Array = dist_braco[side]
		dl.sort()
		L["raio"] = min(dl[int(dl.size() * 0.5)], 0.09) if dl.size() > 10 else 0.04   # mediana: uma garra/ombreira enorme não abre o braço demais
		L["fora"] = 1.0 if (sk.get_bone_global_rest(L["arm"]).origin - cen_tronco).dot(S) > 0.0 else -1.0
		L["ponta"] = sk.find_bone(side + "HandMiddle1")
		if L["ponta"] < 0:
			L["ponta"] = sk.find_bone("mixamorig:" + side + "HandMiddle1")
		braco[side] = L
	return true


func _dist_seg(p: Vector3, a: Vector3, c: Vector3) -> float:
	var ab = c - a
	var t = clamp((p - a).dot(ab) / max(ab.length_squared(), 1e-8), 0.0, 1.0)
	return (a + ab * t).distance_to(p)


# quanto o ponto p (espaço do esqueleto, pose atual) está dentro do corpo: > 0 = dentro
func _dentro(sk: Skeleton3D, p: Vector3, r: float) -> float:
	var i = int(floor((p.dot(U) - u0) / du))
	if i < 0 or i >= N_FAIXAS or faixas[i] == null:
		return -1.0
	var fx: Array = faixas[i]
	var osso: int = fx[0]
	var mv: Transform3D = sk.get_bone_global_pose(osso) * sk.get_bone_global_rest(osso).affine_inverse()
	var c: Vector3 = sk.get_bone_global_pose(osso) * fx[1]
	var s_ax = (mv.basis * S).normalized()
	var f_ax = (mv.basis * F).normalized()
	var d = p - c
	var s = d.dot(s_ax)
	var f = d.dot(f_ax)
	var es = (fx[3] if s > 0.0 else fx[2]) + r
	var ef = (fx[5] if f > 0.0 else fx[4]) + r
	return 1.0 - sqrt((s / es) * (s / es) + (f / ef) * (f / ef))


# empurra o pior ponto para fora do corpo girando o osso (em volta do ombro ou do cotovelo) na direção
# que afasta o ponto do eixo do tronco; usado quando abrir para o lado não basta (mão na frente da barriga)
func _empurra(sk: Skeleton3D, osso: int, L: Dictionary, so_ante: bool, passos: int = 8) -> void:
	for it in passos:
		var pv = sk.get_bone_global_pose(osso).origin
		var pior = -0.035
		var pp = Vector3.ZERO
		for p in _pontos(sk, L, so_ante):
			var d = _dentro(sk, p, L["raio"])
			if d > pior:
				pior = d
				pp = p
		if pior <= -0.035:
			return
		var i = clampi(int(floor((pp.dot(U) - u0) / du)), 0, N_FAIXAS - 1)
		if faixas[i] == null:
			return
		var c: Vector3 = sk.get_bone_global_pose(faixas[i][0]) * faixas[i][1]
		var rad = pp - c
		rad -= U * rad.dot(U)
		if rad.length() < 0.001:
			rad = S * L["fora"]
		var eixo = (pp - pv).cross(rad.normalized())
		if eixo.length() < 0.0001:
			return
		_gira(sk, osso, eixo, 0.06)


func _pontos(sk: Skeleton3D, L: Dictionary, so_ante: bool) -> Array:
	var a = sk.get_bone_global_pose(L["arm"]).origin
	var c = sk.get_bone_global_pose(L["fore"]).origin
	var h = sk.get_bone_global_pose(L["hand"]).origin
	var pt = sk.get_bone_global_pose(L["ponta"]).origin if L["ponta"] >= 0 else h + (h - c) * 0.35
	var out = []
	if not so_ante:
		out.append(a.lerp(c, 0.55))
		out.append(c)
	out.append(c.lerp(h, 0.5))
	out.append(h)
	out.append(pt)
	return out


func _pior(sk: Skeleton3D, L: Dictionary, so_ante: bool) -> float:
	var pior = -1.0
	for p in _pontos(sk, L, so_ante):
		pior = max(pior, _dentro(sk, p, L["raio"]))
	return pior


func _gira(sk: Skeleton3D, osso: int, eixo: Vector3, ang: float) -> void:
	var gb = sk.get_bone_global_pose(osso)
	var par = sk.get_bone_parent(osso)
	var pg = sk.get_bone_global_pose(par) if par >= 0 else Transform3D.IDENTITY
	var nb = Basis(eixo.normalized(), ang) * gb.basis
	sk.set_bone_pose_rotation(osso, (pg.basis.inverse() * nb).get_rotation_quaternion())


func _process_modification_with_delta(delta: float) -> void:
	var sk = get_skeleton()
	if sk == null or faixas.is_empty():
		return
	for side in braco.keys():
		var L: Dictionary = braco[side]
		var q_arm = sk.get_bone_pose_rotation(L["arm"])
		var q_fore = sk.get_bone_pose_rotation(L["fore"])
		# eixo da abertura: a frente do peito (gira com o tronco); o sinal leva o cotovelo para fora
		var sp = sk.get_bone_parent(L["arm"])
		var b_par = sk.get_bone_global_pose(sp).basis if sp >= 0 else Basis.IDENTITY
		var b_par_rest = sk.get_bone_global_rest(sp).basis if sp >= 0 else Basis.IDENTITY
		var f_ax = (b_par * b_par_rest.inverse() * F).normalized()
		# eixo perpendicular ao próprio braço: abre para fora sem torcer (com o braço à frente, girar em volta
		# da frente do peito só torcia o braço e virava o cotovelo para cima)
		var lado_ax = (b_par * b_par_rest.inverse() * S).normalized() * L["fora"]
		var d_arm = (sk.get_bone_global_pose(L["fore"]).origin - sk.get_bone_global_pose(L["arm"]).origin).normalized()
		var eixo = d_arm.cross(lado_ax)
		if eixo.length() < 0.2:
			eixo = f_ax * L["fora"]
		eixo = eixo.normalized()
		var pior0 = _pior(sk, L, false)
		penetra_max = max(penetra_max, pior0)
		# menor abertura que tira o braço do corpo (e uma margem pequena)
		var alvo = 0.0
		if pior0 > -0.04:
			var ang = 0.0
			while ang < 0.9:
				ang += 0.05
				sk.set_bone_pose_rotation(L["arm"], q_arm)
				_gira(sk, L["arm"], eixo, ang)
				if _pior(sk, L, false) <= -0.04:
					break
			alvo = ang
		# abre na hora (nunca atravessa) e fecha devagar (sem tranco)
		var a: float = aberto[side]
		a = alvo if alvo > a else move_toward(a, alvo, delta * 2.5)
		aberto[side] = a
		sk.set_bone_pose_rotation(L["arm"], q_arm)
		if a > 0.0001:
			_gira(sk, L["arm"], eixo, a)
		# se ainda sobra antebraço/mão dentro (cotovelo muito dobrado para a barriga), abre o antebraço também
		var alvo2 = 0.0
		if _pior(sk, L, true) > -0.03:
			var q_f2 = sk.get_bone_pose_rotation(L["fore"])
			var ang2 = 0.0
			while ang2 < 1.0:
				ang2 += 0.05
				sk.set_bone_pose_rotation(L["fore"], q_f2)
				_gira(sk, L["fore"], eixo, ang2)
				if _pior(sk, L, true) <= -0.03:
					break
			alvo2 = ang2
			sk.set_bone_pose_rotation(L["fore"], q_f2)
		var a2: float = aberto_ab[side]
		a2 = alvo2 if alvo2 > a2 else move_toward(a2, alvo2, delta * 2.5)
		aberto_ab[side] = a2
		if a2 > 0.0001:
			_gira(sk, L["fore"], eixo, a2)
		if a <= 0.0001 and a2 <= 0.0001:
			sk.set_bone_pose_rotation(L["fore"], q_fore)
		# o que ainda sobra (antebraço cruzando na frente do corpo): empurra para fora de onde está
		if _pior(sk, L, false) > -0.035:
			_empurra(sk, L["fore"], L, true, 14)
			if _pior(sk, L, false) > -0.035:
				_empurra(sk, L["arm"], L, false, 5)
		resto_max = max(resto_max, _pior(sk, L, false))

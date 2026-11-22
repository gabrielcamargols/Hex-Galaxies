extends Node
## Partida online de verdade entre dois processos (TCP local), cada lado jogado pela CPU:
##   PAPEL=host godot --headless --path . -- --teste=online &
##   PAPEL=guest godot --headless --path . -- --teste=online
## Cada lado imprime o estado no fim (ONLINE FIM ...); os dois têm que bater (sem dessincronia).
## QUEDA=guest_r3 derruba a conexão do convidado no round 3 (teste de reconexão).
var m


func estado(g) -> String:
	var xs = []
	for u in g.units:
		if u.st == "field" or u.st == "dead":
			xs.append("%d:%s:%d:%d,%d" % [u.uid, u.st, u.hp, u.q, u.r])
	xs.sort()
	return "%d|%d|%s" % [g.round_no, g.winner, str(hash(",".join(xs)))]


func run() -> void:
	m = get_parent()
	var papel = OS.get_environment("PAPEL")
	var queda = OS.get_environment("QUEDA")
	m.setup_cfg["map"] = OS.get_environment("MAPA") if OS.get_environment("MAPA") != "" else "tarhut"
	m.setup_cfg["fac"] = "KRI" if papel == "host" else "WAC"
	m.setup_cfg["modo"] = ""
	m.stage = "army"
	m.mix = false
	m._army_random()
	Engine.time_scale = 8.0
	if papel == "host":
		m.net.host()
	else:
		await get_tree().create_timer(1.5 * 8.0).timeout
		m.net.join("127.0.0.1")
	var t0 = Time.get_ticks_msec()
	while m.game == null and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
	if m.game == null:
		print("ONLINE SEM PARTIDA ", papel)
		get_tree().quit()
		return
	m.game.cpu[m.me] = true
	print("ONLINE COMEÇOU ", papel, " eu=", m.me)
	var ultimo = ""
	var caiu = false
	while m.game != null and m.game.winner == Game.NONE and Time.get_ticks_msec() - t0 < 900000:
		if m.asking != null:
			m._answer(false)
		if not m.busy and m.game.cur == m.me and not m.running:
			m.after()
		if queda != "" and not caiu and papel + "_r" + str(m.game.round_no) == queda:
			caiu = true
			print("ONLINE DERRUBANDO ", papel)
			m.net.simular_queda()
		var e = estado(m.game)
		if e.split("|")[0] != ultimo:
			ultimo = e.split("|")[0]
			print("ONLINE ROUND ", papel, " ", e)
		if not m.online and m.game.winner == Game.NONE:
			print("ONLINE CONEXAO PERDIDA ", papel)
			break
		await get_tree().create_timer(0.25 * 8.0).timeout
	if m.game != null:
		print("ONLINE FIM ", papel, " ", estado(m.game))
	get_tree().quit()

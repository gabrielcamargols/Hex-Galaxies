extends Node
## Mede o custo por quadro numa partida CPU x CPU inteira (godot-performance-export):
## godot --path . -- --teste=bench [map=posto fac=KRI cpu=WAC]   (com tela: mede também draw calls)
## Imprime BENCH com mediana, p95, pior quadro e os quadros acima de 33 ms (travadas).

var m
var t_prev := 0
var quadros: Array = []
var draws: Array = []
var piores: Array = []   # [ms, round, evento recente]


func _process(_d: float) -> void:
	var t = Time.get_ticks_usec()
	if t_prev > 0:
		var ms = (t - t_prev) / 1000.0
		quadros.append(ms)
		if m != null and m.game != null and ms > 33.0:
			var lg = m.game.logs
			piores.append([ms, m.game.round_no, str(lg[-1]) if not lg.is_empty() else ""])
	t_prev = t
	draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


func _pct(a: Array, p: float) -> float:
	if a.is_empty():
		return 0.0
	var s = a.duplicate()
	s.sort()
	return s[min(s.size() - 1, int(s.size() * p))]


func run() -> void:
	m = get_parent()
	process_priority = -1000
	m.autotest = true
	Engine.time_scale = 25.0
	for a in OS.get_cmdline_user_args():
		var kv = a.split("=")
		if kv.size() == 2 and m.setup_cfg.has(kv[0]):
			m.setup_cfg[kv[0]] = kv[1]
	m._start_match(null)
	var t0 = Time.get_ticks_msec()
	while (m.game == null or m.game.winner == Game.NONE) and Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
	_resumo()


var feito := false


func _exit_tree() -> void:
	_resumo()   # a partida automática fecha o jogo sozinha ao acabar


func _resumo() -> void:
	if feito:
		return
	feito = true
	var obj = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	piores.sort_custom(func(a, b): return a[0] > b[0])
	print("BENCH quadros=%d mediana=%.1fms p95=%.1fms pior=%.1fms travadas(>33ms)=%d nos=%d draw_calls_p95=%d draw_calls_max=%d" % [quadros.size(), _pct(quadros, 0.5), _pct(quadros, 0.95), _pct(quadros, 1.0), piores.size(), obj, _pct(draws, 0.95), _pct(draws, 1.0)])
	for x in piores.slice(0, 8):
		print("  TRAVADA %.0fms round %d  %s" % [x[0], x[1], x[2].substr(0, 110)])

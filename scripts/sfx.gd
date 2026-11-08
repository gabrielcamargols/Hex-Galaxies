extends Node
## Sons: efeitos curtos (vários ao mesmo tempo) e ambientes em loop com fade.

const NAMES = ["golpe", "impacto", "tiro_laser", "tiro_cristal", "tiro_energia", "projetil", "cura", "escudo", "poder",
	"maldicao", "fenix", "armadilha", "invocar", "derrota", "passo", "explosao", "verme_rumor", "verme_ataque", "dunas",
	"round", "clique", "confirmar", "carta", "vento_loop", "tempestade_loop", "ilha_loop", "musica_deserto", "musica_galaxia", "musica_valak", "musica_abnara", "musica_goraida",
	"musica_fau", "musica_aby", "musica_kri", "musica_wac", "musica_zuk", "musica_lit", "musica_ter",
	"entrada_fau", "entrada_aby", "entrada_kri", "entrada_wac", "entrada_zuk", "entrada_lit", "entrada_ter", "tensao_loop", "heli_loop", "abismo_loop", "caverna_loop"]

var streams: Dictionary = {}
var pool: Array = []
var loops: Dictionary = {}     # nome -> AudioStreamPlayer
var master_db: float = 0.0


# canais de volume: música, efeitos e vozes (ajustados nas Configurações)
func bus_of(n: String) -> String:
	if n.begins_with("musica") or n.begins_with("entrada") or n == "tensao_loop":
		return "Musica"
	if n.begins_with("v_"):
		return "Vozes"
	return "Efeitos"


func set_volume(bus: String, pct: float) -> void:
	var i = AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, pct <= 0.5)
	AudioServer.set_bus_volume_db(i, linear_to_db(clamp(pct / 100.0, 0.001, 1.5)))


func _ready() -> void:
	for b in ["Musica", "Efeitos", "Vozes"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for n in NAMES:
		var path = "res://sounds/%s.wav" % n
		if not ResourceLoader.exists(path):
			path = "res://sounds/%s.ogg" % n
			if not ResourceLoader.exists(path):
				continue
		var s = load(path)
		if s is AudioStreamOggVorbis:
			s.loop = n.begins_with("musica") or n.ends_with("_loop")
		if n.ends_with("_loop") and s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
		streams[n] = s
	for i in range(24):
		var p = AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)


# carrega um som pelo nome quando ele ainda não foi usado (vozes v_*, efeitos vfx_*)
func has_sound(n: String) -> bool:
	if streams.has(n):
		return streams[n] != null
	var s = null
	for ext in ["wav", "ogg"]:
		var path = "res://sounds/%s.%s" % [n, ext]
		if ResourceLoader.exists(path):
			s = load(path)
			break
	streams[n] = s
	return s != null


func play(n: String, vol_db: float = 0.0, pitch: float = 1.0, vary: float = 0.08) -> void:
	if not has_sound(n):
		return
	var p: AudioStreamPlayer = null
	for q in pool:
		if not q.playing:
			p = q
			break
	if p == null:
		p = pool[0]
	p.stream = streams[n]
	p.bus = bus_of(n)
	p.volume_db = vol_db + master_db
	p.pitch_scale = pitch * randf_range(1.0 - vary, 1.0 + vary)
	p.play()


func play_later(n: String, delay: float, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if delay <= 0.0:
		play(n, vol_db, pitch)
		return
	get_tree().create_timer(delay).timeout.connect(func(): play(n, vol_db, pitch))


func loop(n: String, vol_db: float = -8.0, fade: float = 1.5) -> void:
	if not streams.has(n):
		return
	var p: AudioStreamPlayer = loops.get(n, null)
	if p == null:
		p = AudioStreamPlayer.new()
		add_child(p)
		p.stream = streams[n]
		p.bus = bus_of(n)
		loops[n] = p
	if not p.playing:
		p.volume_db = vol_db - 14.0
		p.play()
	var tw = create_tween()
	tw.tween_property(p, "volume_db", vol_db + master_db, fade)


func stop_loop(n: String, fade: float = 2.0) -> void:
	var p: AudioStreamPlayer = loops.get(n, null)
	if p == null or not p.playing:
		return
	var tw = create_tween()
	tw.tween_property(p, "volume_db", -40.0, fade)
	tw.tween_callback(p.stop)


func stop_all_loops() -> void:
	for n in loops.keys():
		stop_loop(n, 0.5)


# aquece os efeitos curtos: o primeiro uso de cada som (principalmente na web) custa um engasgo,
# então eles tocam mudos, um por quadro, enquanto o menu carrega
func warm() -> void:
	var p = AudioStreamPlayer.new()
	add_child(p)
	p.bus = "Efeitos"
	p.volume_db = -80.0
	for n in streams.keys():
		var st = streams[n]
		if st == null or n.begins_with("musica") or n.begins_with("entrada") or n.ends_with("_loop") or n == "tensao_loop":
			continue
		p.stream = st
		p.play()
		await get_tree().process_frame
		p.stop()
	p.queue_free()

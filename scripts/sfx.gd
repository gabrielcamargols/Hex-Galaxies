extends Node
## Sons: efeitos curtos (vários ao mesmo tempo) e ambientes em loop com fade.

const NAMES = ["golpe", "impacto", "tiro_laser", "tiro_cristal", "tiro_energia", "projetil", "cura", "escudo", "poder",
	"maldicao", "fenix", "armadilha", "invocar", "derrota", "passo", "passo_lit1", "passo_lit2", "passo_lit3", "radio_on", "radio_off", "explosao", "verme_rumor", "verme_ataque", "dunas",
	"round", "clique", "confirmar", "carta", "vento_loop", "tempestade_loop", "ilha_loop", "musica_deserto", "musica_galaxia", "musica_tema", "musica_valak", "musica_abnara", "musica_goraida",
	"musica_fau", "musica_aby", "musica_kri", "musica_wac", "musica_zuk", "musica_lit", "musica_ter",
	"entrada_fau", "entrada_aby", "entrada_kri", "entrada_wac", "entrada_zuk", "entrada_lit", "entrada_ter", "tensao_loop", "heli_loop", "abismo_loop", "caverna_loop"]

var streams: Dictionary = {}
var pool: Array = []
var loops: Dictionary = {}     # nome -> AudioStreamPlayer
var master_db: float = 0.0
var voz_ate_ms: int = 0        # até quando algum personagem está falando (o narrador espera e abaixa)
var _duck_db: float = 0.0


# canais de volume: música, efeitos e vozes (ajustados nas Configurações)
func bus_of(n: String) -> String:
	if n.begins_with("musica") or n.begins_with("entrada") or n == "tensao_loop":
		return "Musica"
	if n.begins_with("v_k_") or n.begins_with("radio_"):
		return "Radio"     # os Krieg falam pelo rádio
	if n.begins_with("v_z_dragao"):
		return "Celeste"   # o Dragão Zukunft fala como um anjo
	if n.begins_with("v_l_general_l"):
		return "Cristal"   # o General Lithari fala pelos cristais
	if n.begins_with("v_sapturne"):
		return "Foca"
	for c in ROBO:
		if n.begins_with("v_%s_" % c):
			return "Robo"      # quem usa capacete fala com um leve tom robótico      # Sapturne: foca fofa (voz mais aguda) e maldosa (sombra grave por baixo)
	if n.begins_with("n_"):
		return "Narrador"  # locutor: volume próprio e abaixa sozinho quando um personagem fala
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
	for b in ["Musica", "Efeitos", "Vozes", "Narrador"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	# o narrador abaixa quando algum personagem fala (efeito de volume próprio, separado do volume das Configurações)
	var ni = AudioServer.get_bus_index("Narrador")
	if AudioServer.get_bus_effect_count(ni) == 0:
		AudioServer.add_bus_effect(ni, AudioEffectAmplify.new())
	_radio_bus()
	_celeste_bus()
	_cristal_bus()
	_foca_bus()
	_robo_bus()
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


# canal de rádio dos Krieg: faixa estreita de telefone, saturação leve e compressão;
# passa pelo canal Vozes, então o volume de vozes das Configurações também vale para ele
func _radio_bus() -> void:
	if AudioServer.get_bus_index("Radio") >= 0:
		return
	AudioServer.add_bus()
	var i = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, "Radio")
	AudioServer.set_bus_send(i, "Vozes")
	var hp = AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 380.0
	hp.db = AudioEffectFilter.FILTER_24DB
	AudioServer.add_bus_effect(i, hp)
	var lp = AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 3200.0
	lp.db = AudioEffectFilter.FILTER_24DB
	AudioServer.add_bus_effect(i, lp)
	var ds = AudioEffectDistortion.new()
	ds.mode = AudioEffectDistortion.MODE_OVERDRIVE
	ds.drive = 0.42
	ds.pre_gain = 4.0
	ds.post_gain = -5.0
	ds.keep_hf_hz = 4000.0
	AudioServer.add_bus_effect(i, ds)
	var cp = AudioEffectCompressor.new()
	cp.threshold = -18.0
	cp.ratio = 6.0
	cp.gain = 4.0
	AudioServer.add_bus_effect(i, cp)


# voz celestial (Dragão Zukunft): a voz principal num salão enorme com coro suave, e uma
# segunda camada uma oitava acima, baixinha e banhada em eco longo (o "brilho" angelical)
func _celeste_bus() -> void:
	if AudioServer.get_bus_index("Celeste") >= 0:
		return
	AudioServer.add_bus()
	var i = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, "Celeste")
	AudioServer.set_bus_send(i, "Vozes")
	var ch = AudioEffectChorus.new()
	ch.voice_count = 2
	ch.dry = 0.85
	ch.wet = 0.35
	AudioServer.add_bus_effect(i, ch)
	var rv = AudioEffectReverb.new()
	rv.room_size = 0.85
	rv.damping = 0.25
	rv.spread = 1.0
	rv.predelay_msec = 40.0
	rv.dry = 0.9
	rv.wet = 0.32
	rv.hipass = 0.15
	AudioServer.add_bus_effect(i, rv)
	AudioServer.add_bus()
	var j = AudioServer.bus_count - 1
	AudioServer.set_bus_name(j, "CelesteAlto")
	AudioServer.set_bus_send(j, "Vozes")
	AudioServer.set_bus_volume_db(j, -15.0)
	var ps = AudioEffectPitchShift.new()
	ps.pitch_scale = 2.0
	AudioServer.add_bus_effect(j, ps)
	var hp = AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 700.0
	AudioServer.add_bus_effect(j, hp)
	var rv2 = AudioEffectReverb.new()
	rv2.room_size = 0.95
	rv2.damping = 0.1
	rv2.spread = 1.0
	rv2.predelay_msec = 80.0
	rv2.dry = 0.35
	rv2.wet = 0.8
	AudioServer.add_bus_effect(j, rv2)


# voz de cristal (General Lithari): a voz soa como cristal vibrando. Faseamento metálico e coro
# curto desafinado (várias faces do cristal), agudos realçados e eco claro e curto de câmara de vidro;
# por baixo, uma camada uma quinta acima, fina e tilintante, como o cristal ressoando junto
func _cristal_bus() -> void:
	if AudioServer.get_bus_index("Cristal") >= 0:
		return
	AudioServer.add_bus()
	var i = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, "Cristal")
	AudioServer.set_bus_send(i, "Vozes")
	AudioServer.set_bus_volume_db(i, -3.5)   # o realce dos agudos aumenta o pico
	var ph = AudioEffectPhaser.new()
	ph.range_min_hz = 900.0
	ph.range_max_hz = 5200.0
	ph.rate_hz = 0.35
	ph.feedback = 0.72
	ph.depth = 0.8
	AudioServer.add_bus_effect(i, ph)
	var ch = AudioEffectChorus.new()
	ch.voice_count = 3
	ch.dry = 0.8
	ch.wet = 0.45
	AudioServer.add_bus_effect(i, ch)
	var eq = AudioEffectEQ6.new()
	eq.set_band_gain_db(0, -3.0)
	eq.set_band_gain_db(4, 3.5)
	eq.set_band_gain_db(5, 5.0)
	AudioServer.add_bus_effect(i, eq)
	var rv = AudioEffectReverb.new()
	rv.room_size = 0.45
	rv.damping = 0.05
	rv.spread = 1.0
	rv.predelay_msec = 15.0
	rv.dry = 0.9
	rv.wet = 0.28
	rv.hipass = 0.3
	AudioServer.add_bus_effect(i, rv)
	AudioServer.add_bus()
	var j = AudioServer.bus_count - 1
	AudioServer.set_bus_name(j, "CristalAlto")
	AudioServer.set_bus_send(j, "Vozes")
	AudioServer.set_bus_volume_db(j, -13.0)
	var ps = AudioEffectPitchShift.new()
	ps.pitch_scale = 1.5
	AudioServer.add_bus_effect(j, ps)
	var hp = AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 1500.0
	AudioServer.add_bus_effect(j, hp)
	var rv2 = AudioEffectReverb.new()
	rv2.room_size = 0.6
	rv2.damping = 0.0
	rv2.spread = 1.0
	rv2.dry = 0.4
	rv2.wet = 0.7
	AudioServer.add_bus_effect(j, rv2)


# voz de foca (Sapturne): a voz sobe de tom (fofinha, bochechuda), com um brilho leve e um quartinho
# pequeno; por baixo, uma sombra grave e abafada bem baixinha, o lado maldoso
# personagens de capacete (fora os Krieg, que já falam pelo rádio): voz com leve efeito robótico
const ROBO = ["z_vang", "z_tank"]


func _robo_bus() -> void:
	if AudioServer.get_bus_index("Robo") >= 0:
		return
	AudioServer.add_bus()
	var i = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, "Robo")
	AudioServer.set_bus_send(i, "Vozes")
	# eco metálico curtinho (pente de atrasos fixos), como a voz batendo dentro do capacete
	var ch = AudioEffectChorus.new()
	ch.voice_count = 2
	ch.set_voice_delay_ms(0, 5.5)
	ch.set_voice_rate_hz(0, 0.1)
	ch.set_voice_depth_ms(0, 0.0)
	ch.set_voice_level_db(0, -2.0)
	ch.set_voice_cutoff_hz(0, 9000.0)
	ch.set_voice_delay_ms(1, 9.0)
	ch.set_voice_rate_hz(1, 0.1)
	ch.set_voice_depth_ms(1, 0.0)
	ch.set_voice_level_db(1, -5.0)
	ch.set_voice_cutoff_hz(1, 7000.0)
	ch.dry = 0.85
	ch.wet = 0.45
	AudioServer.add_bus_effect(i, ch)
	var eq = AudioEffectEQ6.new()
	eq.set_band_gain_db(0, -3.0)
	eq.set_band_gain_db(3, 2.5)
	eq.set_band_gain_db(4, 1.5)
	AudioServer.add_bus_effect(i, eq)
	var rv = AudioEffectReverb.new()
	rv.room_size = 0.08
	rv.damping = 0.2
	rv.dry = 0.95
	rv.wet = 0.1
	AudioServer.add_bus_effect(i, rv)


func _foca_bus() -> void:
	if AudioServer.get_bus_index("Foca") >= 0:
		return
	AudioServer.add_bus()
	var i = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, "Foca")
	AudioServer.set_bus_send(i, "Vozes")
	var ps = AudioEffectPitchShift.new()
	ps.pitch_scale = 1.22
	AudioServer.add_bus_effect(i, ps)
	var eq = AudioEffectEQ6.new()
	eq.set_band_gain_db(0, -2.0)
	eq.set_band_gain_db(3, 2.0)
	eq.set_band_gain_db(4, 2.5)
	AudioServer.add_bus_effect(i, eq)
	var rv = AudioEffectReverb.new()
	rv.room_size = 0.25
	rv.damping = 0.4
	rv.dry = 0.95
	rv.wet = 0.12
	AudioServer.add_bus_effect(i, rv)
	AudioServer.add_bus()
	var j = AudioServer.bus_count - 1
	AudioServer.set_bus_name(j, "FocaGrave")
	AudioServer.set_bus_send(j, "Vozes")
	AudioServer.set_bus_volume_db(j, -17.0)
	var ps2 = AudioEffectPitchShift.new()
	ps2.pitch_scale = 0.62
	AudioServer.add_bus_effect(j, ps2)
	var lp = AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 1400.0
	AudioServer.add_bus_effect(j, lp)


func play(n: String, vol_db: float = 0.0, pitch: float = 1.0, vary: float = 0.08) -> void:
	if not has_sound(n):
		return
	if n.begins_with("v_sapturne"):
		_play_raw(n, vol_db, pitch, 0.0, "FocaGrave")
	if n.begins_with("v_"):
		var fim = Time.get_ticks_msec() + int(streams[n].get_length() / max(pitch, 0.1) * 1000.0)
		voz_ate_ms = max(voz_ate_ms, fim)
	if n.begins_with("v_l_general_l"):
		_play_raw(n, vol_db, pitch, 0.0, "CristalAlto")
	if n.begins_with("v_z_dragao"):
		_play_raw(n, vol_db, pitch, 0.0, "CelesteAlto")
	if n.begins_with("v_k_"):
		# abre o rádio, fala e fecha com o chiado
		_play_raw("radio_on", vol_db - 4.0, 1.0)
		var dur = streams[n].get_length() / max(pitch, 0.1)
		get_tree().create_timer(dur + 0.05).timeout.connect(func(): _play_raw("radio_off", vol_db - 6.0, 1.0))
	_play_raw(n, vol_db, pitch, vary)


func _play_raw(n: String, vol_db: float = 0.0, pitch: float = 1.0, vary: float = 0.0, bus: String = "") -> void:
	if not has_sound(n):
		return
	var bb = bus if bus != "" else bus_of(n)
	var lista = pool
	if BUS_COM_EFEITO.has(bb):
		lista = _pool_efeito()
	var p: AudioStreamPlayer = null
	for q in lista:
		if not q.playing:
			p = q
			break
	if p == null:
		p = lista[0]
	p.stream = streams[n]
	p.bus = bb
	p.volume_db = vol_db + master_db
	p.pitch_scale = pitch * randf_range(1.0 - vary, 1.0 + vary)
	p.play()


# Na web o Godot toca os sons no modo "sample" do navegador, que ignora os efeitos dos buses
# (rádio, celestial, cristal, foca). As vozes com efeito usam players próprios no modo "stream",
# que passa pelo mixer do Godot e aplica os efeitos.
const BUS_COM_EFEITO = ["Radio", "Celeste", "CelesteAlto", "Cristal", "CristalAlto", "Foca", "FocaGrave", "Robo", "Narrador"]
var pool_fx: Array = []


func _pool_efeito() -> Array:
	if pool_fx.is_empty():
		for i in range(6):
			var q = AudioStreamPlayer.new()
			q.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
			add_child(q)
			pool_fx.append(q)
	return pool_fx


# interrompe um som que esteja tocando (ex.: fala gravada quando a cena é pulada)
func stop_sound(n: String) -> void:
	if not streams.has(n):
		return
	for q in pool + pool_fx:
		if q.playing and q.stream == streams[n]:
			q.stop()


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



# enquanto um personagem fala, o narrador fica bem mais baixo (volta devagar depois)
func _process(dt: float) -> void:
	var alvo = -16.0 if Time.get_ticks_msec() < voz_ate_ms else 0.0
	_duck_db = move_toward(_duck_db, alvo, dt * (80.0 if alvo < _duck_db else 20.0))
	var ni = AudioServer.get_bus_index("Narrador")
	if ni >= 0 and AudioServer.get_bus_effect_count(ni) > 0:
		var a = AudioServer.get_bus_effect(ni, 0)
		if a is AudioEffectAmplify:
			a.volume_db = _duck_db

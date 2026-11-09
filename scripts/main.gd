extends Node
## Controlador: menu, interface (HUD), turnos do jogador e da CPU.

const TDESC = {
	"plano": "Terreno aberto.", "lama": "Terreno difícil: custa 2 de movimento.", "escombros": "Destroços: custa 2 de movimento.",
	"colina": "Altura 1. Sobe-se por qualquer lado (+1 de custo).", "plataforma": "Bordas são penhascos: só se sobe pela rampa. Dá para pular para baixo 1 nível.",
	"rampa": "Liga o chão à plataforma. Subir custa +1.", "floresta": "Custa 2. Bloqueia tiros que passam por ela; quem está dentro sofre -1 de tiros.",
	"rocha": "Intransponível. Bloqueia tiros e abriga quem está ao lado (-2), do lado da rocha.", "ruina": "Intransponível. Bloqueia tiros e abriga quem está ao lado (-2).",
	"galpao": "Intransponível e alto. Bloqueia tiros e abriga quem está ao lado (-2).",
	"areia": "Areia firme. Terreno aberto.", "duna": "Duna de areia fofa, de até 5 níveis. Sobe-se 1 nível por vez (custa 1 por degrau; os 2 últimos níveis custam 2). Quem está no alto ganha altura e linha de tiro, mas se a duna mudar sofre queda.",
	"movedica": "Armadilha: quem entra para na hora. Sair custa +2.", "instavel": "Areia instável: custa 2 de movimento.",
	"ossada": "Ossada baixa. Intransponível, abriga quem está ao lado (-2).", "ossada_c": "Ossada central. Dá para entrar; quem está dentro sofre -1 de tiros.",
	"buraco": "Buraco de verme. Intransponível enquanto estiver aberto (2 rounds).",
	"trilha": "Trilha da selva. Terreno aberto; sobe-se 1 nível por vez.", "clareira": "Clareira perto da base: chão seguro, terreno aberto.",
	"mata": "Mata densa. Dá para entrar, mas bloqueia tiros que passam por ela (não esconde ninguém).",
	"raiz": "Raiz maciça. Intransponível; bloqueia tiros e abriga quem está ao lado (-2).",
	"correnteza": "Correnteza. Dá para entrar; no fim do round o rio leva quem está nela 1 casa na direção da seta.",
	"ponte": "Ponte vegetal. Travessia segura por cima do rio.", "ruina_alta": "Ruína alta. Intransponível e alta: bloqueia tiros e abriga quem está ao lado (-2).",
	"planta": "Planta predadora. Intransponível; no fim de cada round morde (1 de dano) quem estiver ao lado dela.",
	"neve": "Neve firme. Terreno aberto; sobe-se 1 nível por vez.", "neve_base": "Neve perto da base: chão seguro, terreno aberto.",
	"gelo": "Gelo liso. Quem termina o movimento aqui desliza mais 1 casa na direção em que vinha, se estiver livre.",
	"gelo_fragil": "Gelo frágil. Por enquanto é terreno aberto; vai rachar e romper com aviso (próxima etapa).",
	"fenda": "Fenda aberta. Ninguém atravessa andando, mas os tiros passam por cima.",
	"parede_gelo": "Parede glacial. Intransponível e alta: bloqueia tiros e abriga quem está ao lado (-2).",
	"avalanche": "Corredor de avalanche. Dá para andar; as avalanches com aviso vêm na próxima etapa.",
}
const RULES = "[b]Objetivo:[/b] derrotar o Comandante inimigo (ele entra no round 4). No fim do round 10 vence quem tiver mais Vida no Comandante; empate: soma da Vida dos aliados.\n\n[b]Turno:[/b] os lados se alternam ativando 1 peça por vez. Cada peça ativada tem [b]2 ações[/b], e cada tipo só pode ser usado [b]1 vez por turno[/b]: mover 1 vez, atacar 1 vez, usar habilidade ativa (ex.: mover + atacar). [b]Táticas não gastam ação:[/b] cada peça ativada pode jogar 1 carta de graça. Arraste a carta e solte no personagem (ou na casa) destacado para escolher quem recebe o efeito. Habilidades passivas não gastam ação. Colocar uma reserva em campo gasta 1 ação. [b]A área de entrada cresce:[/b] a cada 3 rounds (nos rounds 1 a 3 vai até 1 casa da sua base, 4 a 6 até 2 casas...) e, no Tarhut, a cada 2 rounds (1 casa nos rounds 1-2, 2 nos rounds 3-4... até 5), sempre na sua metade do mapa.\n\n[b]Chuva (Abnara):[/b] a partir do round 6 chove: todos os ataques causam 3 a menos de dano e o céu escurece. Raios caem em casas aleatórias; se acertarem a mata ela pega fogo, o incêndio se espalha pelas árvores vizinhas e quem estiver numa casa em chamas ou ao lado perde 1 de Vida a cada round. A mata queimada vira clareira.

[b]Altura:[/b] atacar de cima +1 de dano, de baixo -1. Tiros (alcance 2+) de cima ganham +1 de alcance. Corpo a corpo só com até 1 nível de diferença.\n\n[b]Núcleo:[/b] nos rounds 2, 4, 6 e 8 surge um núcleo de energia que fica 2 rounds. Leve uma peça até ele para capturar: 2 cartas, +2 ATQ ou +4 Vida com defesa. O local do próximo aparece antes, marcado no mapa.\n\n[b]Controle Lithari:[/b] [b]Lento[/b] = -1 de Movimento até o fim do round (mínimo 1). [b]Enraizado[/b] = não anda até o fim do próximo round; depois de se soltar, a peça fica imune a novo enraizamento por 1 round. [b]Zona de Cristal[/b] = casas marcadas (\"CRISTAL\") por 2 rounds: inimigo que entra nelas fica Lento. Lithari não são afetados pelas zonas deles.\n\n[b]Impulso:[/b] derrubar uma tropa dá 1 casa de movimento grátis (1 vez por ativação).\n\n[b]Linha de tiro:[/b] uma casa no caminho bloqueia se o topo dela for mais alto que o atacante e o alvo.\n\n[b]Abrigo:[/b] -2 de dano se uma rocha/ruína/ossada vizinha ao alvo estiver do lado do atacante.\n\n[b]Tarhut (o mapa mais difícil):[/b] as dunas, com até 5 níveis de altura, mudam inteiras a cada 3 rounds (aviso 1 round antes, nos rounds 4, 7 e 10). Elas bloqueiam tiros e dão vantagem de altura; quem estiver no alto quando a duna baixar despenca: 1 de dano, +1 se cair 3 níveis e +1 se cair 5. A cada 3 rounds o [color=#ff6a4a]Verme Gigante[/color] sai da areia (o \"!\" avisa 1 round antes): quem estiver no buraco sofre 4 de dano e quem estiver ao lado, 1. Fuja das casas marcadas! O deserto é enorme.\n\n[b]Valak (caverna de cristais):[/b] um labirinto de cristais que muda a cada partida. Cristais bloqueiam passagem e tiros; um ataque quebra um cristal e o efeito atinge TODOS ao lado: [color=#7dff4a]verde[/color] cura 2, [color=#5ae8ff]azul[/color] dá +1 de Movimento no próximo movimento do round, [color=#ff5ae0]roxo[/color] causa 2 de dano. No centro vive a [color=#ff4ad0]Garra[/color]: andar (+1), atacar ou usar habilidade (+2) a até 3 casas do buraco, ou passar um carrinho por ali (+3), aumenta a VIBRAÇÃO. Em 5, a garra ataca: quem está a 1 casa do buraco é arrastado e morre; a 2 ou 3 casas sofre 2 de dano e é puxado 1 casa. Carrinhos: uma peça ao lado gasta 1 ação para empurrar; ele anda até 3 casas no trilho e o primeiro atingido sofre 3 e é empurrado. [color=#ffb14a]Tempestade de areia:[/color] no round em que o vento muda (3, 6, 9) e no round em que as dunas mudam (4, 7, 10), todos os ataques causam 2 a menos de dano.\n\n[b]Escaravelhos Verdes (Tarhut):[/b] basta passar por cima de um (ou parar nele) para guardá-lo, sem gastar ação. [b]1 escaravelho[/b] restaura 6 de Vida de uma peça; [b]2 escaravelhos[/b] deixam uma peça usar a ativa mais uma vez; os que sobrarem no fim somam +1 de Vida ao seu comandante na contagem do round 10. Para gastá-los (curar ou reativar), use os botões do escaravelho no painel de exército.\n\n[b]Online:[/b] na tela do exército, toque em \"⚡ Online\". Um jogador cria a sala e passa o código de 6 letras; o outro digita o código e entra. O mapa é o planeta de quem criou a sala. No app instalado (PC/Android), a sala usa o IP da rede local no lugar do código.\n\n[b]Controles:[/b] clique numa peça sua e depois numa casa verde (mover) ou num inimigo vermelho (atacar), ou arraste a peça e solte. Confirme a prévia. Botão direito gira a câmera, arrastar o fundo move o mapa, a roda aproxima. Q/E giram. Enter confirma, Esc cancela.\n\n[b]Toque (tablet/celular):[/b] toque numa peça e numa casa para agir. 1 dedo arrasta o mapa; pinça com 2 dedos aproxima/afasta; girar os 2 dedos gira a câmera; arrastar os 2 dedos para cima/baixo inclina a visão. \"Tudo\" recentraliza."

var board
var game: Game = null
var ui: Control
var w: Dictionary = {}

# código de cores: o mesmo em botões, casas do tabuleiro e legenda
# paleta oficial do universo: Azul espacial #10145A, Branco estelar #F8FAFF, Ciano cósmico #27DDF4,
# Roxo galáctico #A957EC, Magenta HQ #F438A9, Amarelo solar #FFD12E (as facções expandem a partir dela)
const C_SPACE = Color("#10145A")
const C_MOVE = Color("#4cff6a")     # andar
const C_ATK = Color("#ff3b4d")      # atacar / inimigo atacável
const C_ABIL = Color("#A957EC")     # habilidade / escolher alvo de efeito
const C_CARD = Color("#3da0ff")     # cartas táticas
const C_DEPLOY = Color("#27DDF4")   # colocar reserva em campo
const C_YOU = Color("#2fa8ff")      # seu lado
const C_CPU = Color("#ff7a1a")      # lado da CPU
const C_GOLD = Color("#FFD12E")     # títulos e destaque
const C_END = Color("#F8FAFF")      # encerrar / passar
const C_HUD = Color("#3340b8")      # molduras da HUD
const C_TXT = Color("#F8FAFF")      # texto principal
const C_DIM = Color("#cbbdff")      # texto secundário
var font_title: Font = null
var font_btn: Font = null
var setup_cfg: Dictionary = {"map": "tarhut", "fac": "ABY", "cpu": "FAU"}
var army_picks: Array = []     # 5 ids escolhidos pelo jogador
var mix: bool = false          # modo Mix: tropas e comandante de qualquer facção
var mix_cmd: String = ""
var mix_filter: String = ""    # filtro de facção na grade do Mix ("" = todas)
var army_start: Array = []     # até 2 ids que começam em campo
var army_fac: String = ""
var army_detail: String = ""   # peça mostrada no painel de detalhes
var galaxy = null              # galáxia do menu (scripts/galaxy.gd)
var fader: ColorRect           # cortina de transição (cor do planeta / preto)
var stage: String = ""         # title, select, army, dive, battle
var planet_id: String = "tarhut"
var intro: bool = false        # próxima partida começa com o zoom no planeta
var card_hover: String = ""      # carta com o mouse em cima (destaca o que ela afeta)
var last_st: Dictionary = {}       # destaques atuais do tabuleiro (sem a carta)
var dlg: Dictionary = {}           # falas (data/dialogos.json)
var bubbles: Array = []            # balões de fala ativos
var plates: Dictionary = {}        # uid -> placa de vida 2D (estilo da HUD)
var rgb_on: bool = true          # desalinho RGB sobre o 3D (leve)
var rgb_rect: ColorRect = null
var rgb_mask: SubViewport = null
var rgb_mask_cam: Camera3D = null
var vol = {"Musica": 80.0, "Efeitos": 90.0, "Vozes": 90.0}
var res_pref: String = "1600x900"
var fullscreen: bool = false
var render_q: float = 1.0
var voice_on: bool = true       # líderes leem as falas em voz alta (voz do aparelho)
var fast_mode: bool = false      # modo rápido: sem confirmar, prévia ao apontar, animações 2×
var pend_hover: bool = false
var intense: bool = false
var ui_pref: String = "auto"       # tamanho da interface: auto, 100, 125, 150, 175
var compact: bool = false          # tela pequena (celular): HUD enxuta e letras maiores
var cpu_open: bool = false         # painel da CPU aberto no modo compacto
var last_banter_ms: int = -100000
var autotest: bool = false   # godot --headless -- --autotest fac=ABY cpu=FAU map=tarhut
var last_sides: Variant = null

var sel: int = -1
var dsel: int = -1
var pend: Variant = null
var am: String = ""
var ab: bool = false
var tip: Variant = null
var inspect: int = -1
var hex_info: Variant = null
var asking: Variant = null
var busy: bool = false
var running: bool = false
var panel_open: String = ""
var res_drag: Variant = null
var card_drag: Variant = null
# ---- online ----
var me: int = 0                  # índice do jogador deste aparelho (0 offline; 0 ou 1 online)
var online: bool = false
var net: Node = null
var net_queue: Array = []        # jogadas do outro aparelho esperando para serem repetidas
var net_busy: bool = false
var opp_thinking: bool = false   # o motor espera uma resposta do outro jogador
var net_seed: int = 0
var tut: bool = false            # tutorial em andamento: a CPU só passa a vez
var tut_node: Node = null
var net_pre_ans: Array = []      # respostas que chegaram antes da partida começar aqui   # carta de tática sendo arrastada: {id, start, on}
var sfx = null
var vfx = null
var impact_delay: float = 0.0
var impact_until: int = 0


func _ready() -> void:
	randomize()
	net = Node.new()
	net.set_script(load("res://scripts/net.gd"))
	add_child(net)
	net.connected.connect(_net_connected)
	net.message.connect(_net_msg)
	net.closed.connect(_net_closed)
	net.status.connect(_net_status)
	board = Node3D.new()
	board.set_script(load("res://scripts/board.gd"))
	add_child(board)
	board.hex_tapped.connect(_on_hex_tapped)
	board.hex_hovered.connect(_on_hex_hover)
	board.unit_dropped.connect(_on_unit_dropped)
	board.unit_drag_started.connect(_on_unit_drag_started)
	board.worm_roar.connect(_on_worm_roar)
	board.worm_bite.connect(_on_worm_bite)
	vfx = Node3D.new()
	vfx.set_script(load("res://scripts/vfx.gd"))
	board.add_child(vfx)
	vfx.board = board
	sfx = Node.new()
	sfx.set_script(load("res://scripts/sfx.gd"))
	add_child(sfx)
	vfx.sfx = sfx
	get_tree().create_timer(1.5).timeout.connect(func(): sfx.warm())
	# desalinho RGB sobre o 3D (fica abaixo da interface)
	var rgb_layer = CanvasLayer.new()
	rgb_layer.layer = -1
	add_child(rgb_layer)
	rgb_rect = ColorRect.new()
	rgb_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rgb_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rm = ShaderMaterial.new()
	rm.shader = load("res://shaders/rgb.gdshader")
	rgb_rect.material = rm
	# máscara dos personagens: o RGB fica fraco neles e forte no cenário
	rgb_mask = SubViewport.new()
	rgb_mask.transparent_bg = true
	rgb_mask.own_world_3d = false
	rgb_mask.world_3d = get_viewport().world_3d
	rgb_mask.size = Vector2i(640, 360)
	rgb_mask.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	rgb_mask.msaa_3d = Viewport.MSAA_DISABLED
	add_child(rgb_mask)
	rgb_mask_cam = Camera3D.new()
	rgb_mask_cam.cull_mask = 2
	rgb_mask.add_child(rgb_mask_cam)
	rm.set_shader_parameter("mask", rgb_mask.get_texture())
	rgb_layer.add_child(rgb_rect)
	rgb_rect.visible = rgb_on
	var layer = CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = _make_theme()
	layer.add_child(ui)
	board._setup_sky()
	board.visible = false
	galaxy = Node3D.new()
	galaxy.set_script(load("res://scripts/galaxy.gd"))
	add_child(galaxy)
	galaxy.env = board.env
	galaxy.planet_hover.connect(_on_planet_hover)
	galaxy.planet_click.connect(_planet_info)
	var top_layer = CanvasLayer.new()
	top_layer.layer = 20
	add_child(top_layer)
	fader = ColorRect.new()
	fader.color = Color(0.012, 0.02, 0.045, 1.0)
	fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	fader.mouse_filter = Control.MOUSE_FILTER_STOP
	top_layer.add_child(fader)
	if FileAccess.file_exists("res://data/dialogos.json"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogos.json"))
		if parsed is Dictionary:
			dlg = parsed
	_load_prefs()
	if rgb_rect != null:
		rgb_rect.visible = rgb_on
	_apply_settings.call_deferred()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--uiscale="):
			ui_pref = a.substr(10)
	_apply_ui_scale()
	get_window().size_changed.connect(_apply_ui_scale)
	_show_menu()
	var args = OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--shots="):
			_shots(a.substr(8))
			return
	for a in args:
		if a.begins_with("--oficina"):
			_open_oficina(a == "--oficina=auto", "aby")
			return
	for a in args:
		if a.begins_with("--cenario="):
			board.visible = true
			galaxy.deactivate()
			fader.visible = false
			ui.visible = false
			var pv = Node3D.new()
			pv.set_script(load("res://scripts/cenario_preview.gd"))
			add_child(pv)
			await pv.run(a.substr(10), board)
			get_tree().quit()
			return
		if a.begins_with("--teste="):
			var tn = Node.new()
			tn.set_script(load("res://scripts/teste_%s.gd" % a.substr(8)))
			add_child(tn)
			await tn.run()
			get_tree().quit()
			return
		if a.begins_with("--balance="):
			var n = int(a.substr(10))
			var outp = "user://balance.json"
			var mps = ["tarhut", "posto", "abnara", "goraida"]
			var only = ""
			for b in args:
				if b.begins_with("only="):
					only = b.substr(5)
				if b.begins_with("out="):
					outp = b.substr(4)
				if b.begins_with("maps="):
					mps = Array(b.substr(5).split(","))
			var bal = Node.new()
			bal.set_script(load("res://scripts/balance.gd"))
			add_child(bal)
			await bal.run(n, outp, mps, only)
			get_tree().quit()
			return
	if args.has("--autotest"):
		autotest = true
		for a in args:
			var kv = a.split("=")
			if kv.size() == 2 and setup_cfg.has(kv[0]):
				setup_cfg[kv[0]] = kv[1]
		Engine.time_scale = 25.0
		print("AUTOTESTE: ", setup_cfg)
		_start_match(null)


# ================= tema e ajudantes de interface =================
func _make_theme() -> Theme:
	var th = Theme.new()
	th.default_font_size = 17
	if ResourceLoader.exists("res://ui/fonts/Inter-SemiBold.otf"):
		var fv = FontVariation.new()
		fv.base_font = load("res://ui/fonts/Inter-SemiBold.otf")
		fv.spacing_glyph = 1
		th.default_font = fv
	# Orbitron (tecnológica) para títulos e botões; Inter para textos longos
	if ResourceLoader.exists("res://ui/fonts/InterDisplay-BlackItalic.otf"):
		# estilo HQ: letra pesada e inclinada, com contorno de tinta preta
		var hq = load("res://ui/fonts/InterDisplay-BlackItalic.otf")
		if ResourceLoader.exists("res://ui/fonts/Inter-SemiBold.otf"):
			hq.fallbacks = [load("res://ui/fonts/Inter-SemiBold.otf")]
		var ft3 = FontVariation.new()
		ft3.base_font = hq
		ft3.spacing_glyph = 1
		font_title = ft3
		var fb3 = FontVariation.new()
		fb3.base_font = hq
		fb3.spacing_glyph = 1
		font_btn = fb3
		th.set_font("font", "Button", fb3)
		th.set_font_size("font_size", "Button", 16)
	elif ResourceLoader.exists("res://ui/fonts/Orbitron.woff2"):
		var orb = load("res://ui/fonts/Orbitron.woff2")
		# símbolos que a Orbitron não tem (·, ●, ★...) vêm da Inter (na web não há fontes do sistema)
		if ResourceLoader.exists("res://ui/fonts/Inter-SemiBold.otf"):
			orb.fallbacks = [load("res://ui/fonts/Inter-SemiBold.otf")]
		var ft = FontVariation.new()
		ft.base_font = orb
		ft.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
		ft.spacing_glyph = 2
		font_title = ft
		var fb = FontVariation.new()
		fb.base_font = orb
		fb.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
		fb.spacing_glyph = 1
		font_btn = fb
		th.set_font("font", "Button", fb)
		th.set_font_size("font_size", "Button", 15)
	elif ResourceLoader.exists("res://ui/fonts/InterDisplay-Bold.otf"):
		var ft2 = FontVariation.new()
		ft2.base_font = load("res://ui/fonts/InterDisplay-Bold.otf")
		ft2.spacing_glyph = 3
		font_title = ft2
	th.set_stylebox("panel", "PanelContainer", _tex_box("res://ui/panel.png", 30, C_HUD, 20, 16))
	th.set_stylebox("normal", "Button", _tex_box("res://ui/btn.png", 14, C_HUD, 16, 9))
	th.set_stylebox("hover", "Button", _tex_box("res://ui/btn_on.png", 14, C_HUD.darkened(0.25), 16, 9))
	th.set_stylebox("pressed", "Button", _tex_box("res://ui/btn_on.png", 14, C_HUD, 16, 9))
	th.set_stylebox("disabled", "Button", _tex_box("res://ui/btn.png", 14, Color(0.2, 0.22, 0.3), 16, 9))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", C_TXT)
	th.set_color("font_outline_color", "Button", Color.BLACK)
	th.set_constant("outline_size", "Button", 6)
	th.set_color("font_outline_color", "Label", Color(0.03, 0.0, 0.08))
	th.set_constant("outline_size", "Label", 4)
	th.set_color("font_outline_color", "RichTextLabel", Color(0.03, 0.0, 0.08))
	th.set_constant("outline_size", "RichTextLabel", 3)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(0.82, 0.86, 0.92))
	th.set_color("font_color", "Label", C_TXT)
	th.set_color("default_color", "RichTextLabel", C_TXT)
	th.set_color("font_color", "OptionButton", C_TXT)
	# barras de rolagem grandes e fáceis de pegar no toque: trilho escuro + pegador azul
	for bar in ["VScrollBar", "HScrollBar"]:
		th.set_constant("minimum_grab_thickness", bar, 26)
		th.set_stylebox("scroll", bar, _scroll_box(Color(0.04, 0.05, 0.12, 0.9), Color("#25308a")))
		th.set_stylebox("grabber", bar, _scroll_box(C_HUD, Color("#8fa0ff")))
		th.set_stylebox("grabber_highlight", bar, _scroll_box(C_HUD.lightened(0.2), Color("#c4ceff")))
		th.set_stylebox("grabber_pressed", bar, _scroll_box(C_GOLD, Color("#fff6a0")))
	th.set_constant("scrollbar_v_separation", "ScrollContainer", 14)
	th.set_constant("scrollbar_h_separation", "ScrollContainer", 14)
	return th


# barra de rolagem grande (fácil de pegar com o dedo)
func _fat_scroll(sc: ScrollContainer) -> void:
	sc.get_v_scroll_bar().custom_minimum_size.x = 24
	sc.get_h_scroll_bar().custom_minimum_size.y = 24


func _scroll_box(bg: Color, border: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(0)
	return s


# moldura tecnológica (9-slice gerado por tools/uigen.py), tingida com uma cor
func _tex_box(path: String, margin: int, tint: Color, pad_h: int = 14, pad_v: int = 8) -> StyleBox:
	if not ResourceLoader.exists(path):
		var f = StyleBoxFlat.new()
		f.bg_color = Color(0.05, 0.08, 0.15, 0.88)
		f.border_color = tint
		f.set_border_width_all(2)
		f.set_content_margin_all(pad_v)
		return f
	var s = StyleBoxTexture.new()
	s.texture = load(path)
	s.texture_margin_left = margin
	s.texture_margin_right = margin
	s.texture_margin_top = margin
	s.texture_margin_bottom = margin
	s.modulate_color = tint
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s


func _panel(parent: Control) -> PanelContainer:
	var p = PanelContainer.new()
	parent.add_child(p)
	return p


func _vbox(parent: Control, sep: int = 6) -> VBoxContainer:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	parent.add_child(v)
	return v


func _hbox(parent: Control, sep: int = 6) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	parent.add_child(h)
	return h


func _label(parent: Control, text: String = "", size: int = 0, col = null) -> Label:
	var l = Label.new()
	l.text = text
	if compact and size > 0 and size < 13:
		size = 13
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if size >= 22 and font_title != null:
		l.add_theme_font_override("font", font_title)
	if col != null:
		l.add_theme_color_override("font_color", col)
		# texto escuro (sobre fundo claro) fica sem o contorno de tinta
		if col.get_luminance() < 0.35:
			l.add_theme_constant_override("outline_size", 0)
	parent.add_child(l)
	return l


func _rich(parent: Control, width: int = 0) -> RichTextLabel:
	var r = RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	if width > 0:
		r.custom_minimum_size = Vector2(width, 0)
	parent.add_child(r)
	return r


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _style_btn(b: Button, col: Color, active: bool = false) -> void:
	# HQ: botão de cor viva, contorno de tinta e letra branca com contorno preto
	b.add_theme_stylebox_override("normal", _tex_box("res://ui/btn_on.png" if active else "res://ui/btn.png", 14, col.lightened(0.12) if active else col.darkened(0.12), 16, 9))
	b.add_theme_stylebox_override("hover", _tex_box("res://ui/btn_on.png", 14, col.lightened(0.2), 16, 9))
	b.add_theme_stylebox_override("pressed", _tex_box("res://ui/btn_on.png", 14, col, 16, 9))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", _tex_box("res://ui/btn.png", 14, Color(0.2, 0.18, 0.28), 16, 9))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color("#fff6a0"))
	b.add_theme_color_override("font_disabled_color", Color(0.86, 0.84, 0.95))
	b.add_theme_color_override("font_outline_color", Color.BLACK)
	b.add_theme_constant_override("outline_size", 6)


# botão neutro do menu: azul-noite com contorno claro; o dourado fica só para a ação principal
func _menu_btn(b: Button) -> void:
	var base = Color("#262c86")
	b.add_theme_stylebox_override("normal", _tex_box("res://ui/btn.png", 14, base, 16, 9))
	b.add_theme_stylebox_override("hover", _tex_box("res://ui/btn_on.png", 14, base.lightened(0.25), 16, 9))
	b.add_theme_stylebox_override("pressed", _tex_box("res://ui/btn_on.png", 14, base.lightened(0.1), 16, 9))
	b.add_theme_color_override("font_color", C_TXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)


func _cbtn(parent: Control, text: String, col: Color, cb: Callable, active: bool = false) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(118, 46)
	b.add_theme_font_size_override("font_size", 15 if font_btn != null else 17)
	b.pressed.connect(cb)
	_style_btn(b, col, active)
	parent.add_child(b)
	return b


func _chip(parent: Control, col: Color, text: String) -> void:
	var hb = _hbox(parent, 5)
	var sw = Panel.new()
	sw.add_theme_stylebox_override("panel", _flat(col, Color(0.95, 0.95, 1.0), 1, 3, 0))
	sw.custom_minimum_size = Vector2(16, 16)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(sw)
	_label(hb, text, 13, C_TXT)


func _place(c: Control, preset: Control.LayoutPreset, margin: int = 10) -> void:
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, margin)
	if preset == Control.PRESET_CENTER_TOP:
		c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	elif preset == Control.PRESET_CENTER_BOTTOM:
		c.grow_horizontal = Control.GROW_DIRECTION_BOTH
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	elif preset == Control.PRESET_BOTTOM_LEFT:
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	elif preset == Control.PRESET_BOTTOM_RIGHT:
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	elif preset == Control.PRESET_TOP_RIGHT:
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	elif preset == Control.PRESET_CENTER_RIGHT:
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		c.grow_vertical = Control.GROW_DIRECTION_BOTH
	elif preset == Control.PRESET_CENTER_LEFT:
		c.grow_vertical = Control.GROW_DIRECTION_BOTH
	elif preset == Control.PRESET_CENTER:
		c.grow_horizontal = Control.GROW_DIRECTION_BOTH
		c.grow_vertical = Control.GROW_DIRECTION_BOTH


func _clear_ui() -> void:
	for c in ui.get_children():
		c.queue_free()
	w.clear()


# ================= transições (sem tela de loading) =================
func _fade(to_a: float, dur: float, col = null) -> void:
	if col != null:
		fader.color = Color(col.r, col.g, col.b, fader.color.a)
	fader.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw = create_tween()
	tw.tween_property(fader, "color:a", to_a, dur)
	await tw.finished
	if to_a < 0.01:
		fader.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ui_fade(to_a: float, dur: float) -> void:
	var tw = create_tween()
	tw.tween_property(ui, "modulate:a", to_a, dur)
	await tw.finished


func _vignette() -> void:
	var tr = TextureRect.new()
	var gt = GradientTexture2D.new()
	var gr = Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0))
	gr.set_color(1, Color(0.0, 0.01, 0.04, 0.78))
	gr.set_offset(0, 0.45)
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = 256
	gt.height = 256
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(tr)


func _planet_of_map(m: String) -> String:
	for p in galaxy.PLANETS:
		if p.get("map", "") == m:
			return p["id"]
	return "tarhut"


func _stop_battle_loops() -> void:
	for n in ["vento_loop", "musica_deserto", "ilha_loop", "caverna_loop", "tempestade_loop", "musica_valak", "musica_abnara", "musica_goraida"]:
		sfx.stop_loop(n, 0.8)
	_fac_music("")


# trilha de cada facção (tools/musica_faccoes.py): toca na montagem do exército
const FAC_MUSIC = {"FAU": ["musica_fau", -9.0], "ABY": ["musica_aby", -8.0], "KRI": ["musica_kri", -9.0], "WAC": ["musica_wac", -9.0],
	"ZUK": ["musica_zuk", -9.5], "LIT": ["musica_lit", -6.0], "TER": ["musica_ter", -6.5]}
var fac_music_on: String = ""


func _fac_music(fac: String) -> void:
	if fac == fac_music_on:
		return
	if fac_music_on != "" and FAC_MUSIC.has(fac_music_on):
		sfx.stop_loop(FAC_MUSIC[fac_music_on][0], 1.2)
	fac_music_on = fac
	if fac != "" and FAC_MUSIC.has(fac):
		sfx.loop(FAC_MUSIC[fac][0], FAC_MUSIC[fac][1], 1.5)


# sai da batalha (se houver) e volta para a galáxia
func _leave_battle() -> void:
	Engine.time_scale = 1.0
	if intense:
		intense = false
		sfx.stop_loop("tensao_loop", 1.0)
	if tut_node != null and is_instance_valid(tut_node):
		tut_node.queue_free()
	tut_node = null
	if vfx != null:
		vfx.setup_ambient("")
	_clear_ui()
	game = null
	board.g = null
	board.visible = false
	bubbles.clear()
	_stop_battle_loops()
	sfx.loop("musica_galaxia", -9.0, 0.8)
	galaxy.activate()


# ================= menu: galáxia =================
# versão gravada pela publicação web (data/version.json); no editor aparece "dev"
func _version_text() -> String:
	var path = "res://data/version.json"
	if FileAccess.file_exists(path):
		var v = JSON.parse_string(FileAccess.get_file_as_string(path))
		if v is Dictionary:
			return "Versão %s · %s · %s" % [str(v.get("n", "?")), str(v.get("date", "")), str(v.get("sha", ""))]
	return "Versão dev (local)"


func _show_menu() -> void:
	tut = false
	if online:
		online = false
		net.send({"t": "bye"})
		net.close()
	var from_battle = board.visible
	if from_battle:
		await _fade(1.0, 0.35, Color("#03050b"))
	_leave_battle()
	stage = "title"
	galaxy.set_mode("title")
	if from_battle or fader.color.a > 0.5:
		galaxy.snap_camera()
	ui.modulate.a = 0.0
	_vignette()
	var col = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	ui.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = get_viewport().get_visible_rect().size.y * 0.05
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# raios de HQ atrás do logo (mesma linguagem da tela do exército), bem suaves
	if ResourceLoader.exists("res://ui/rays.png"):
		var mr = TextureRect.new()
		mr.texture = load("res://ui/rays.png")
		mr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mr.stretch_mode = TextureRect.STRETCH_SCALE
		mr.set_anchors_preset(Control.PRESET_FULL_RECT)
		mr.modulate = Color(0.75, 0.78, 1, 0.3)
		mr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(mr)
	var vlab = _label(ui, _version_text(), 13, C_TXT)
	vlab.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	vlab.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	vlab.grow_vertical = Control.GROW_DIRECTION_BEGIN
	vlab.offset_right = -14
	vlab.offset_bottom = -10
	vlab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vlab.modulate.a = 0.8
	vlab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k = _label(col, "U M A   G A L Á X I A   E M   G U E R R A", 14, C_TXT)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ResourceLoader.exists("res://ui/logo.png"):
		var lg = _tex_rect(load("res://ui/logo.png"), Vector2(0, 250 if compact else 380))
		lg.size_flags_horizontal = Control.SIZE_FILL
		col.add_child(lg)
		var tw = lg.create_tween().set_loops()
		lg.pivot_offset = Vector2(get_viewport().get_visible_rect().size.x / 2.0, 190)
		tw.tween_property(lg, "scale", Vector2(1.03, 1.03), 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_property(lg, "scale", Vector2(1.0, 1.0), 0.9).set_trans(Tween.TRANS_SINE)
	else:
		var t = _label(col, "HEX GALAXIES", 62 if compact else 86, C_GOLD)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sp = Control.new()
	sp.custom_minimum_size = Vector2(0, 22)
	col.add_child(sp)
	var row = _hbox(col, 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var play = _cbtn(row, "JOGAR", C_GOLD, _on_play, true)
	_primary(play)
	play.custom_minimum_size = Vector2(320, 70)
	play.add_theme_font_size_override("font_size", 28)
	var sp2 = Control.new()
	sp2.custom_minimum_size = Vector2(0, 6)
	col.add_child(sp2)
	var row2 = _hbox(col, 10)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	# três botões iguais, mesma altura e largura, em cores do jogo
	var tb = _cbtn(row2, "TUTORIAL", C_DEPLOY, _start_tutorial)
	var rb = _cbtn(row2, "COMO JOGAR", C_ABIL, _rules_popup)
	var cfgb = _cbtn(row2, "CONFIGURAÇÕES", C_HUD, _settings_panel)
	for mb in [tb, rb, cfgb]:
		_menu_btn(mb)
		mb.custom_minimum_size = Vector2(196, 52)
		mb.add_theme_font_size_override("font_size", 17)
	_ui_fade(1.0, 0.9)
	if fader.color.a > 0.0:
		_fade(0.0, 0.7)


# ================= configurações: vídeo e som =================
const RESOLUTIONS = ["1280x720", "1366x768", "1600x900", "1920x1080", "2560x1440"]


func _apply_settings() -> void:
	for b in vol.keys():
		sfx.set_volume(b, vol[b])
	get_viewport().scaling_3d_scale = render_q
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		if fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var p = res_pref.split("x")
			var sz = Vector2i(int(p[0]), int(p[1]))
			DisplayServer.window_set_size(sz)
			var scr2 = DisplayServer.screen_get_usable_rect()
			DisplayServer.window_set_position(scr2.position + (scr2.size - sz) / 2)


func _settings_panel() -> void:
	if w.has("settings") and is_instance_valid(w["settings"]):
		w["settings"].queue_free()
		return
	sfx.play("clique", -8.0)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.z_index = 60
	ui.add_child(dim)
	w["settings"] = dim
	var cc = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _flat(Color(0.03, 0.05, 0.11, 0.97), C_HUD, 2, 12, 22))
	cc.add_child(p)
	var outer = _vbox(p, 10)
	outer.custom_minimum_size = Vector2(min(480, get_viewport().get_visible_rect().size.x - 40), 0)
	_label(outer, "CONFIGURAÇÕES", 28, C_GOLD)
	var scr = ScrollContainer.new()
	scr.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scr.custom_minimum_size = Vector2(0, min(520.0, get_viewport().get_visible_rect().size.y * 0.66))
	outer.add_child(scr)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scr.add_child(v)
	_label(v, "SOM", 13, C_HUD)
	for b in [["Musica", "Música"], ["Efeitos", "Efeitos sonoros"], ["Vozes", "Vozes"]]:
		var h = _hbox(v, 10)
		var l = _label(h, b[1], 16, C_TXT)
		l.custom_minimum_size = Vector2(150, 0)
		var sl = HSlider.new()
		sl.min_value = 0
		sl.max_value = 100
		sl.step = 5
		sl.value = vol[b[0]]
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.custom_minimum_size = Vector2(0, 32)
		h.add_child(sl)
		var pl = _label(h, "%d%%" % int(vol[b[0]]), 15, C_DIM)
		pl.custom_minimum_size = Vector2(50, 0)
		var bus = b[0]
		sl.value_changed.connect(func(x):
			vol[bus] = x
			pl.text = "%d%%" % int(x)
			sfx.set_volume(bus, x)
			if bus == "Efeitos":
				sfx.play("clique", -4.0)
			_save_prefs())
	_label(v, "VÍDEO", 13, C_HUD)
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		var h2 = _hbox(v, 10)
		_label(h2, "Resolução", 16, C_TXT).custom_minimum_size = Vector2(150, 0)
		var ob = OptionButton.new()
		for r in RESOLUTIONS:
			ob.add_item(r.replace("x", " × "))
		ob.selected = max(0, RESOLUTIONS.find(res_pref))
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h2.add_child(ob)
		ob.item_selected.connect(func(i):
			res_pref = RESOLUTIONS[i]
			fullscreen = false
			_apply_settings()
			_save_prefs())
		var fs = CheckButton.new()
		fs.text = "Tela cheia"
		fs.button_pressed = fullscreen
		v.add_child(fs)
		fs.toggled.connect(func(on):
			fullscreen = on
			_apply_settings()
			_save_prefs())
	else:
		var nt = _label(v, "No navegador e no celular o tamanho da tela segue o aparelho. Use a qualidade abaixo para deixar mais leve ou mais nítido.", 13, C_DIM)
		nt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var h3 = _hbox(v, 10)
	_label(h3, "Qualidade 3D", 16, C_TXT).custom_minimum_size = Vector2(150, 0)
	var qb = OptionButton.new()
	var qs = [[0.5, "Baixa (mais leve)"], [0.75, "Média"], [1.0, "Alta"]]
	for q in qs:
		qb.add_item(q[1])
	qb.selected = 2 if render_q >= 0.99 else (1 if render_q >= 0.7 else 0)
	qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h3.add_child(qb)
	qb.item_selected.connect(func(i):
		render_q = qs[i][0]
		_apply_settings()
		_save_prefs())
	var rgbc = CheckButton.new()
	rgbc.text = "Efeito RGB (impressão)"
	rgbc.button_pressed = rgb_on
	rgbc.tooltip_text = "Desalinho de cor nas bordas, como nos quadrinhos. Desligue se o aparelho ficar lento."
	v.add_child(rgbc)
	rgbc.toggled.connect(func(on):
		rgb_on = on
		if rgb_rect != null:
			rgb_rect.visible = rgb_on
		_save_prefs())
	_label(v, "JOGO", 13, C_HUD)
	var fb = _cbtn(v, _fast_label(), C_HUD, func(): pass)
	fb.custom_minimum_size = Vector2(0, 40)
	fb.tooltip_text = "Sem confirmação para mover e atacar, prévia de dano ao apontar o alvo e animações em velocidade 2×."
	fb.pressed.connect(func():
		fast_mode = not fast_mode
		_save_prefs()
		fb.text = _fast_label())
	var vb = _cbtn(v, _voice_label(), C_HUD, func(): pass)
	vb.custom_minimum_size = Vector2(0, 40)
	vb.tooltip_text = "Os líderes de cada facção leem as próprias falas em voz alta (usa a voz do aparelho)."
	vb.pressed.connect(func():
		voice_on = not voice_on
		if not voice_on:
			DisplayServer.tts_stop()
		_save_prefs()
		vb.text = _voice_label())
	var ub = _cbtn(v, _ui_scale_label(), C_HUD, func(): pass)
	ub.custom_minimum_size = Vector2(0, 40)
	ub.tooltip_text = "Tamanho dos botões e textos."
	ub.pressed.connect(func():
		_cycle_ui_scale(false)
		ub.text = _ui_scale_label())
	if stage == "battle" and game != null:
		_label(v, "TESTE DE EFEITOS", 13, C_HUD)
		var gb = _cbtn(v, "Galeria de impactos das facções", C_HUD, func():
			dim.queue_free()
			_vfx_gallery())
		gb.custom_minimum_size = Vector2(0, 40)
		gb.tooltip_text = "Dispara o impacto de cada facção lado a lado no mapa atual, para conferir cor e leitura."
	if stage != "battle":
		_label(v, "FERRAMENTAS", 13, C_HUD)
		var ob = _cbtn(v, "Oficina de VFX", C_ABIL, func():
			dim.queue_free()
			_open_oficina(false))
		ob.custom_minimum_size = Vector2(0, 40)
		ob.tooltip_text = "Palco para revisar os efeitos da Forja: câmera lenta, laço, fundos e lados."
	var close = _cbtn(outer, "Fechar", C_GOLD, func(): dim.queue_free(), true)
	_primary(close)
	close.custom_minimum_size = Vector2(0, 42)


func _undo_move() -> void:
	if game == null or not my_turn() or not game.can_undo():
		return
	var uid = game.undo["uid"]
	sfx.play("clique", -6.0, 0.8)
	game.undo_move()
	pend = null
	sel = uid
	refresh()


func _voice_label() -> String:
	return "Voz dos líderes: " + ("LIGADA" if voice_on else "desligada")


func _fast_label() -> String:
	return "Modo rápido: " + ("LIGADO" if fast_mode else "desligado")


func _apply_speed() -> void:
	Engine.time_scale = 2.0 if fast_mode and game != null and stage == "battle" and not tut else 1.0


# pausa curtíssima no impacto (o tempo quase para e volta)
func _hitstop(sec: float) -> void:
	Engine.time_scale = 0.06
	await get_tree().create_timer(sec, true, false, true).timeout
	_apply_speed()


# música mais intensa quando um comandante está em perigo
func _check_tension() -> void:
	if game == null or stage != "battle":
		return
	var danger = false
	for p in range(2):
		var c = game.commander(p)
		if c != null and c.st == "field" and c.hp * 2 <= c.maxhp:
			danger = true
	if danger and not intense:
		intense = true
		sfx.loop("tensao_loop", -6.0, 2.0)
		banner("COMANDANTE EM PERIGO", "a batalha está decidida por um fio")
	elif not danger and intense:
		intense = false
		sfx.stop_loop("tensao_loop", 2.5)


# modo rápido: apontar um inimigo mostra a prévia do dano (o clique ataca direto)
func _on_hex_hover(h) -> void:
	if not fast_mode or game == null or not my_turn() or ab or dsel >= 0 or card_drag != null:
		return
	var u = sel_unit()
	var at = game.unit_at(h) if h != null else null
	if u != null and at != null and at.owner != u.owner and (game.is_live(u) or game.can_start(u)):
		var H = highlights()
		if H["at"].has(h):
			var pm = _pend_move()
			pend = {"kind": "moveatk", "h": pm["h"], "cost": pm["cost"], "tuid": at.uid} if pm != null else {"kind": "attack", "tuid": at.uid}
			pend_hover = true
			refresh()
			return
	if pend_hover:
		pend = null
		pend_hover = false
		refresh()


# ================= tutorial =================
func _start_tutorial() -> void:
	sfx.play("confirmar", -6.0)
	online = false
	mix = false
	tut = true
	setup_cfg["map"] = "posto"
	setup_cfg["fac"] = "KRI"
	planet_id = _planet_of_map("posto")
	DB.set_map("posto")
	var s0 = DB.entry[0]
	var s1 = DB.entry[1]
	var sides = [
		{"fac": "KRI", "picks": ["k_brawler", "k_sniper", "k_tank", "k_medico", "k_estandarte"], "start": [{"id": "k_brawler", "h": s0[0]}, {"id": "k_sniper", "h": s0[s0.size() - 1]}]},
		{"fac": "ABY", "picks": ["strahl", "balu", "klang", "kling", "sterina"], "start": [{"id": "strahl", "h": s1[0]}, {"id": "balu", "h": s1[s1.size() - 1]}]},
	]
	await _ui_fade(0.0, 0.3)
	galaxy.set_mode("dive", planet_id)
	await get_tree().create_timer(0.9).timeout
	await _fade(1.0, 0.5, galaxy.data(planet_id).get("dive", Color("#e0b070")))
	intro = true
	_start_match(sides)


func _rules_popup() -> void:
	if w.has("rules_pop") and is_instance_valid(w["rules_pop"]):
		w["rules_pop"].queue_free()
		w.erase("rules_pop")
		return
	var p = _panel(ui)
	# balão menor e com rolagem: cabe em celular e não cobre o campo
	var vw = ui.get_viewport_rect().size
	var pw = min(520.0, vw.x - 40.0)
	p.custom_minimum_size = Vector2(pw, 0)
	_place(p, Control.PRESET_CENTER)
	var v = _vbox(p, 8)
	_label(v, "COMO JOGAR", 22, C_GOLD)
	var sc = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(pw - 40.0, min(380.0, vw.y * 0.5))
	v.add_child(sc)
	_fat_scroll(sc)
	var body = _vbox(sc, 0)
	var r = _rich(body, int(pw - 80.0))
	r.add_theme_font_size_override("normal_font_size", 14)
	r.text = RULES
	_cbtn(v, "Fechar", C_HUD, _rules_popup)
	w["rules_pop"] = p


func _on_play() -> void:
	if stage != "title":
		return
	stage = "to_select"
	sfx.play("confirmar", -6.0)
	sfx.play("vfx_dash", -12.0)
	await _ui_fade(0.0, 0.45)
	_show_select()


func _show_select() -> void:
	stage = "select"
	_clear_ui()
	galaxy.set_mode("select")
	ui.modulate.a = 0.0
	_vignette()
	# título em faixa de HQ inclinada
	var tb = PanelContainer.new()
	tb.add_theme_stylebox_override("panel", _hq_box(C_SPACE, Color("#262c86"), 8))
	tb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(tb)
	var tl = _label(tb, "ESCOLHA O PLANETA", 30 if compact else 38, C_GOLD)
	if font_title != null:
		tl.add_theme_font_override("font", font_title)
	tl.add_theme_constant_override("outline_size", 10)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(tb, Control.PRESET_CENTER_TOP, 22)
	var back = _cbtn(ui, "◀  Voltar", C_HUD, _back_title)
	_menu_btn(back)
	_place(back, Control.PRESET_BOTTOM_LEFT, 22)
	# em cada planeta, só o nome (o modelo 3D mostra o resto); a descrição aparece ao tocar
	w["tags"] = {}
	for id in galaxy.pickable():
		var d = galaxy.data(id)
		var tag = Button.new()
		tag.text = d["name"].to_upper()
		tag.add_theme_font_size_override("font_size", 17 if compact else 20)
		if font_title != null:
			tag.add_theme_font_override("font", font_title)
		var ac: Color = d["atm"]
		for st in ["normal", "hover", "pressed", "focus"]:
			tag.add_theme_stylebox_override(st, _hq_box(C_SPACE.darkened(0.25) if st != "hover" else C_SPACE.lightened(0.12), Color("#262c86"), 4))
		for st in ["normal", "hover", "pressed", "focus"]:
			var sbx = tag.get_theme_stylebox(st) as StyleBoxFlat
			sbx.set_content_margin_all(5)
			sbx.content_margin_left = 16
			sbx.content_margin_right = 16
			sbx.set_border_width_all(3)
		tag.add_theme_color_override("font_color", C_TXT)
		tag.add_theme_color_override("font_hover_color", Color.WHITE)
		tag.add_theme_color_override("font_outline_color", Color("#0a0410"))
		tag.add_theme_constant_override("outline_size", 4)
		tag.pressed.connect(_planet_info.bind(id))
		ui.add_child(tag)
		tag.position = Vector2(-1000, -1000)
		w["tags"][id] = tag
	await get_tree().create_timer(0.55).timeout
	if stage == "select":
		_ui_fade(1.0, 0.6)


# caixa de HQ: inclinada, contorno de tinta e sombra dura colorida (impressão deslocada)
func _hq_box(bg: Color, shadow: Color, shift: int = 6) -> StyleBoxFlat:
	var b = StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = Color("#0a0410")
	b.set_border_width_all(4)
	b.set_corner_radius_all(2)
	b.shadow_color = shadow
	b.shadow_size = 1
	b.shadow_offset = Vector2(shift, shift)
	b.skew = Vector2(-0.12, 0)
	b.set_content_margin_all(12)
	b.content_margin_left = 26
	b.content_margin_right = 26
	return b


# tocou num planeta: ele vai para a esquerda e a ficha com a descrição e as arenas aparece à direita
func _planet_info(id: String) -> void:
	if stage != "select":
		return
	stage = "planet_info"
	planet_id = id
	sfx.play("confirmar", -8.0)
	await _ui_fade(0.0, 0.25)
	_clear_ui()
	_vignette()
	galaxy.set_mode("focus", id)
	var d = galaxy.data(id)
	var ac: Color = d["atm"]
	ac.a = 1.0
	var panel = PanelContainer.new()
	var pb = _hq_box(C_SPACE.lerp(ac.darkened(0.8), 0.25), ac, 10)
	pb.content_margin_left = 34
	pb.content_margin_right = 34
	pb.content_margin_top = 22
	pb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", pb)
	ui.add_child(panel)
	var v = _vbox(panel, 8)
	var nm = _label(v, d["name"].to_upper(), 46 if compact else 60, ac.lightened(0.35))
	if font_title != null:
		nm.add_theme_font_override("font", font_title)
	nm.add_theme_constant_override("outline_size", 12)
	_label(v, d.get("sub", "").to_upper(), 17, C_GOLD)
	var dl = _label(v, d.get("desc", ""), 20 if compact else 19, C_TXT)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size = Vector2(360 if compact else 440, 0)
	var sp = Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	v.add_child(sp)
	var ah = _label(v, "ARENAS", 22, ac.lightened(0.3))
	if font_btn != null:
		ah.add_theme_font_override("font", font_btn)
	for ar in d.get("arenas", [{"name": d["name"], "map": d["map"], "desc": ""}]):
		var row = PanelContainer.new()
		row.add_theme_stylebox_override("panel", _flat(Color(0, 0, 0, 0.35), ac.darkened(0.2), 2, 3, 10))
		v.add_child(row)
		var rv = _vbox(row, 4)
		var an = _label(rv, ar["name"].to_upper(), 24, Color.WHITE)
		if font_btn != null:
			an.add_theme_font_override("font", font_btn)
		if ar.get("desc", "") != "":
			var ad = _label(rv, ar["desc"], 17, C_TXT.darkened(0.1))
			ad.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ad.custom_minimum_size = Vector2(340 if compact else 420, 0)
		var bb = _cbtn(rv, "BATALHAR AQUI", C_GOLD, _choose_planet.bind(id, ar["map"]))
		_primary(bb)
		bb.custom_minimum_size = Vector2(0, 56)
		bb.add_theme_font_size_override("font_size", 22)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 40)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var back = _cbtn(ui, "◀  Planetas", C_HUD, _back_to_select)
	_place(back, Control.PRESET_BOTTOM_LEFT, 22)
	await _ui_fade(1.0, 0.4)


func _back_to_select() -> void:
	if stage != "planet_info":
		return
	sfx.play("clique", -8.0)
	await _ui_fade(0.0, 0.25)
	_show_select()


func _back_title() -> void:
	if stage != "select":
		return
	stage = "to_title"
	sfx.play("clique", -8.0)
	await _ui_fade(0.0, 0.35)
	_show_menu()


func _on_planet_hover(id: String) -> void:
	if not w.has("tags"):
		return
	for k in w["tags"].keys():
		var tg = w["tags"][k]
		if is_instance_valid(tg):
			tg.modulate = Color(1, 1, 1, 1) if (id == "" or id == k) else Color(1, 1, 1, 0.55)
	if id != "":
		sfx.play("clique", -14.0, 1.4)


func _update_tags() -> void:
	if not w.has("tags"):
		return
	var vp = get_viewport().get_visible_rect().size
	var placed = []
	for id in w["tags"].keys():
		var tg: Control = w["tags"][id]
		if not is_instance_valid(tg):
			continue
		var sp: Variant = galaxy.screen_pos(id)
		if sp == null:
			tg.visible = false
			continue
		tg.visible = true
		var r = galaxy.screen_radius(id)
		# nome logo abaixo do planeta, centralizado
		var pos = sp + Vector2(-tg.size.x * 0.5, r * 1.15 + 12.0)
		pos.x = clamp(pos.x, 12.0, vp.x - tg.size.x - 12.0)
		pos.y = clamp(pos.y, 90.0, vp.y - tg.size.y - 80.0)
		# não deixa uma etiqueta cobrir a outra
		for other in placed:
			var ra = Rect2(pos, tg.size)
			if ra.intersects(other):
				pos.y = other.position.y + other.size.y + 8.0 if pos.y >= other.position.y else other.position.y - tg.size.y - 8.0
		placed.append(Rect2(pos, tg.size))
		tg.position = tg.position.lerp(pos, 0.35) if tg.position.x > -900.0 else pos


func _choose_planet(id: String, map_id: String = "") -> void:
	if stage != "select" and stage != "planet_info":
		return
	stage = "to_army"
	planet_id = id
	setup_cfg["map"] = map_id if map_id != "" else galaxy.data(id)["map"]
	sfx.play("confirmar", -6.0)
	sfx.play("vfx_portal", -12.0)
	_ui_fade(0.0, 0.35)
	galaxy.set_mode("focus", id)
	await get_tree().create_timer(0.75).timeout
	_show_army()
	ui.modulate.a = 0.0
	_ui_fade(1.0, 0.6)


# volta da batalha direto para a montagem do exército
func _to_army() -> void:
	await _fade(1.0, 0.35, Color("#03050b"))
	_leave_battle()
	planet_id = _planet_of_map(setup_cfg["map"])
	galaxy.set_mode("focus", planet_id)
	galaxy.snap_camera()
	_show_army()
	ui.modulate.a = 0.0
	_ui_fade(1.0, 0.6)
	_fade(0.0, 0.6)


# ================= montar exército =================
func _army_pool() -> Array:
	if mix:
		return DB.card_list.filter(func(c): return not c.get("cmd", false) and (mix_filter == "" or c["f"] == mix_filter))
	return DB.card_list.filter(func(c): return c["f"] == setup_cfg["fac"] and not c.get("cmd", false))


func _cur_cmd() -> String:
	if mix and mix_cmd != "":
		return mix_cmd
	return DB.factions[setup_cfg["fac"]]["cmd"]


func _mix_cmd_step(d: int) -> void:
	var cmds = []
	for f in DB.factions.keys():
		cmds.append(DB.factions[f]["cmd"])
	var i = cmds.find(mix_cmd)
	mix_cmd = cmds[(i + d + cmds.size()) % cmds.size()]
	setup_cfg["fac"] = DB.cards[mix_cmd]["f"]
	army_detail = mix_cmd
	sfx.play("clique", -8.0)
	_fac_music(setup_cfg["fac"])
	_army_refresh()


func _mix_filter_pick(f: String) -> void:
	mix_filter = f
	sfx.play("clique", -8.0)
	_army_refresh_rest()


func _fac_col(f: String) -> Color:
	return Color(DB.factions[f]["color"])


func _flat(bg: Color, border: Color, bw: int = 2, rad: int = 10, pad: int = 10) -> StyleBoxFlat:
	# HQ: cantos quase retos, borda mais grossa e sombra dura de tinta
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(max(bw, 3) if bw > 0 else 0)
	s.set_corner_radius_all(min(rad, 4))
	s.set_content_margin_all(pad)
	if bg.a > 0.3:
		s.shadow_color = Color(0, 0, 0, 0.85)
		s.shadow_size = 1
		s.shadow_offset = Vector2(4, 4)
	return s


func _tex_rect(tex: Texture2D, size: Vector2) -> TextureRect:
	var t = TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


# "ATIVA · 1 AÇÃO · RECARGA 1 ROUND" (ativas que voltam a cada round) ou "1 VEZ POR PARTIDA"
func _per_label(a: Dictionary) -> String:
	if a.get("per", "partida") == "round":
		return "ATIVA · 1 AÇÃO · RECARGA %d ROUND%s" % [Game.ABIL_RECHARGE, "" if Game.ABIL_RECHARGE == 1 else "S"]
	return "ATIVA · 1 VEZ POR PARTIDA"


# tipo da habilidade (como ela é usada)
func _ab_kind(c: Dictionary) -> Array:
	var k = c.get("k", {})
	var abk = c.get("ab", {}).get("kind", "")
	if abk == "ativa":
		return [_per_label(c["ab"]), C_ABIL]
	if abk == "especial":
		return ["AÇÃO ESPECIAL", C_ABIL]
	if k.has("action"):
		return ["ATIVA · GASTA 1 AÇÃO", C_ABIL]
	if k.has("entry"):
		return ["AO ENTRAR EM CAMPO", C_DEPLOY]
	if k.has("after"):
		return ["AO ATACAR", C_ATK]
	return ["PASSIVA · SEMPRE LIGADA", C_CARD]


# o que a peça faz no jogo: etiquetas e um resumo
func _impact(c: Dictionary) -> Dictionary:
	var tags = []
	var k = c.get("k", {})
	var txt = (c["ab"]["text"] + " " + c.get("ab2", {}).get("text", "")).to_lower()
	var hp = int(c["int"])
	var atk = int(c["atk"])
	var mov = int(c["mov"])
	var alc = int(c["alc"])
	if alc >= 3:
		tags.append(["Ataque à distância", C_CARD])
	else:
		tags.append(["Corpo a corpo", C_ATK])
	if hp >= 12:
		tags.append(["Muito resistente", Color("#ff5a6a")])
	elif hp <= 5:
		tags.append(["Frágil", Color("#ff9a5a")])
	if atk >= 5:
		tags.append(["Dano alto", C_GOLD])
	if mov >= 3 or k.has("after") and str(k["after"]) == "freeMove" or k.has("action") and str(k["action"]) in ["moveAttack", "tunnel"]:
		tags.append(["Mobilidade", C_MOVE])
	if "restaure" in txt or "cura" in txt or k.has("endHeal"):
		tags.append(["Cura aliados", Color("#5ee08a")])
	if "empurr" in txt or "puxa" in txt or "não pode se mover" in txt or "perde sua habilidade" in txt or "atq até" in txt or "mova o alvo" in txt:
		tags.append(["Controle do inimigo", C_ABIL])
	if "barreira" in txt or "terreno" in txt or "buraco" in txt or "duna" in txt or "rocha" in txt or "ponte" in txt or "fenda" in txt or "estaca" in txt or "casa livre adjacente" in txt or k.has("terra"):
		tags.append(["Mexe no terreno", Color("#e0925a")])
	if k.has("auraAtk") or k.has("auraRed") or k.has("guard") or k.has("guardClan") or k.has("taunt") or "aliado" in txt:
		tags.append(["Apoia aliados", C_DEPLOY])
	if k.has("selfRed") or k.has("firstHitRed") or k.has("selfRedHome") or "reduz" in txt or "não pode ser alvo" in txt:
		tags.append(["Defesa", C_YOU])
	if "dano a cada" in txt or "dano a todas" in txt or "splash" in str(k.get("after", "")):
		tags.append(["Dano em área", Color("#ff6a3a")])
	var parts = []
	if hp >= 12:
		parts.append("segura a linha de frente")
	elif alc >= 3:
		parts.append("ataca de longe, protegido atrás dos aliados")
	elif mov >= 3:
		parts.append("chega rápido onde precisa")
	else:
		parts.append("luta de perto")
	var kd = _ab_kind(c)[0]
	if kd.begins_with("AO ENTRAR"):
		parts.append("o efeito acontece no momento em que entra em campo — escolha bem quando colocá-lo")
	elif kd.begins_with("ATIVA"):
		parts.append("a habilidade gasta 1 ação da ativação")
	elif kd.begins_with("AO ATACAR"):
		parts.append("fica mais forte a cada ataque")
	else:
		parts.append("a habilidade funciona sozinha, sem gastar ação")
	var resumo = parts[0].substr(0, 1).to_upper() + parts[0].substr(1) + "; " + parts[1] + "."
	return {"tags": tags, "resumo": resumo}


func _show_army() -> void:
	stage = "army"
	sfx.stop_loop("musica_galaxia", 1.5)
	_fac_music(setup_cfg["fac"])
	var akey = "MIX" if mix else setup_cfg["fac"]
	if army_fac != akey:
		army_fac = akey
		army_picks = []
		army_start = []
	_clear_ui()
	_vignette()
	if ResourceLoader.exists("res://ui/rays.png"):
		var rays = TextureRect.new()
		rays.texture = load("res://ui/rays.png")
		rays.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rays.stretch_mode = TextureRect.STRETCH_SCALE
		rays.set_anchors_preset(Control.PRESET_FULL_RECT)
		rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(rays)
		w["rays"] = rays
	var pd = galaxy.data(planet_id)
	# --- barra do alto: planeta, facções, adversário ---
	var topbar = _hbox(ui, 14)
	topbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	topbar.offset_left = 22
	topbar.offset_right = -22
	topbar.offset_top = 14
	var pv = _vbox(topbar, 0)
	_label(pv, pd.get("name", "").to_upper(), 30, C_GOLD)
	_label(pv, pd.get("sub", "").to_upper(), 12, pd.get("atm", C_HUD).lightened(0.2))
	var sp1 = Control.new()
	sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topbar.add_child(sp1)
	var tabs = _hbox(topbar, 6)
	w["tabs"] = tabs
	var sp2 = Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topbar.add_child(sp2)
	var ov = _vbox(topbar, 2)
	_label(ov, "ADVERSÁRIO (CPU)", 11, C_DIM)
	var ob = OptionButton.new()
	ob.add_item("Aleatório")
	ob.set_item_metadata(0, "RND")
	for f in DB.factions.keys():
		ob.add_item(DB.factions[f]["short"])
		ob.set_item_metadata(ob.item_count - 1, f)
	ob.add_item("Mix (misturado)")
	ob.set_item_metadata(ob.item_count - 1, "MIX")
	for i in range(ob.item_count):
		if ob.get_item_metadata(i) == setup_cfg["cpu"]:
			ob.selected = i
	ob.item_selected.connect(_army_cpu.bind(ob))
	ob.custom_minimum_size = Vector2(170, 38)
	ov.add_child(ob)
	var b4 = _cbtn(ov, "⚡ JOGAR ONLINE", C_DEPLOY, _online_panel)
	b4.custom_minimum_size = Vector2(170, 34)
	b4.tooltip_text = "Jogar contra outra pessoa pela internet, com código de sala"
	# --- comandante (embaixo à esquerda, o planeta aparece acima) ---
	var cmdp = PanelContainer.new()
	ui.add_child(cmdp)
	cmdp.anchor_left = 0.0
	cmdp.anchor_right = 0.3
	cmdp.anchor_top = 1.0
	cmdp.anchor_bottom = 1.0
	cmdp.offset_left = 18
	cmdp.offset_right = -6
	cmdp.offset_bottom = -16
	cmdp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	w["cmdp"] = cmdp
	# --- grade de tropas (meio) ---
	var mid = VBoxContainer.new()
	mid.add_theme_constant_override("separation", 6)
	ui.add_child(mid)
	mid.anchor_left = 0.305
	mid.anchor_right = 0.655
	mid.anchor_top = 0.15 if compact else 0.125
	mid.anchor_bottom = 0.785
	var mh = _hbox(mid, 8)
	_label(mh, "TROPAS", 22, C_TXT)
	var mt = _label(mh, "toque para pôr ou tirar do exército", 12, C_DIM)
	mt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var mixbar = HFlowContainer.new()
	mixbar.add_theme_constant_override("h_separation", 5)
	mixbar.add_theme_constant_override("v_separation", 5)
	mid.add_child(mixbar)
	w["mixbar"] = mixbar
	var sc = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_fat_scroll(sc)
	mid.add_child(sc)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(grid)
	w["grid"] = grid
	w["grid_sc"] = sc
	# --- detalhe (direita) ---
	var det = PanelContainer.new()
	ui.add_child(det)
	det.anchor_left = 0.665
	det.anchor_right = 1.0
	det.anchor_top = 0.125
	det.anchor_bottom = 0.785
	det.offset_right = -18
	w["det"] = det
	# --- barra de baixo: exército escolhido ---
	var bot = PanelContainer.new()
	ui.add_child(bot)
	bot.anchor_left = 0.305
	bot.anchor_right = 1.0
	bot.anchor_top = 0.8
	bot.anchor_bottom = 1.0
	bot.offset_right = -18
	bot.offset_bottom = -16
	var bh = _hbox(bot, 10)
	var slots = _hbox(bh, 6)
	w["slots"] = slots
	var bv = _vbox(bh, 6)
	bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hint = _label(bv, "", 13, C_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w["army_hint"] = hint
	if compact:
		hint.add_theme_font_size_override("font_size", 12)
	var br = _hbox(bv, 6)
	if compact:
		# celular: "voltar" vai para o alto, embaixo de nome do planeta
		var b1c = _cbtn(pv, "◀ Planetas", C_HUD, _army_back)
		b1c.custom_minimum_size = Vector2(0, 34)
		b1c.add_theme_font_size_override("font_size", 12)
		b1c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	else:
		var b1 = _cbtn(br, "◀ Planetas", C_HUD, _army_back)
		b1.custom_minimum_size = Vector2(0, 38)
	var b2 = _cbtn(br, "Sortear", C_HUD, _army_random)
	b2.custom_minimum_size = Vector2(0, 38)
	var b3 = _cbtn(br, "Limpar", C_HUD, _army_clear)
	b3.custom_minimum_size = Vector2(0, 38)

	if compact:
		for bb in [b2, b3]:
			bb.add_theme_font_size_override("font_size", 12)
	var go = _cbtn(bh, "BATALHAR", C_GOLD, _army_go, true)
	_primary(go)
	go.custom_minimum_size = Vector2(130 if compact else 190, 0)
	go.add_theme_font_size_override("font_size", 17 if compact else 22)
	w["go"] = go
	if army_detail == "" or not DB.cards.has(army_detail) or (not mix and DB.cards[army_detail]["f"] != setup_cfg["fac"]):
		army_detail = _cur_cmd()
	_army_refresh()


func _army_refresh() -> void:
	if stage != "army" or not w.has("grid"):
		return
	var fac = setup_cfg["fac"]
	var fc = _fac_col(fac)
	if w.has("rays") and is_instance_valid(w["rays"]):
		w["rays"].modulate = fc.lightened(0.25)
	# abas de facção
	for c in w["tabs"].get_children():
		c.queue_free()
	for f in DB.factions.keys() + ["MIX"]:
		var on = (f == fac and not mix) if f != "MIX" else mix
		var b = Button.new()
		b.custom_minimum_size = Vector2(56, 54) if compact else Vector2(52 + (DB.factions[f]["short"].length() if f != "MIX" else 4) * 9, 54)
		b.tooltip_text = DB.factions[f]["short"] if f != "MIX" else "Mix: misture todas as facções"
		var col = _fac_col(f) if f != "MIX" else Color("#e8e0ff")
		b.add_theme_stylebox_override("normal", _flat(Color(col.darkened(0.55), 0.92) if on else Color(0.03, 0.05, 0.1, 0.85), col if on else col.darkened(0.35), 2 if on else 1, 8, 4))
		b.add_theme_stylebox_override("hover", _flat(Color(col.darkened(0.5), 0.95), col.lightened(0.2), 2, 8, 4))
		b.add_theme_stylebox_override("pressed", _flat(Color(col.darkened(0.4), 0.95), col.lightened(0.3), 2, 8, 4))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_army_fac_pick.bind(f))
		var hb = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 5)
		hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hb)
		if f == "MIX":
			var ml = _label(hb, "✦", 24, Color.WHITE if on else col)
			ml.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ml.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			var cid = DB.factions[f]["cmd"]
			if DB.portraits.has(cid):
				hb.add_child(_tex_rect(DB.portraits[cid], Vector2(38, 42)))
		var tl = _label(hb, DB.factions[f]["short"] if f != "MIX" else "Mix", 11, Color.WHITE if on else col.lightened(0.45))
		tl.visible = not compact
		tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not on:
			b.modulate = Color(1, 1, 1, 0.8)
		w["tabs"].add_child(b)
	# comandante
	for c in w["cmdp"].get_children():
		c.queue_free()
	w["cmdp"].add_theme_stylebox_override("panel", _flat(Color(0.03, 0.05, 0.11, 0.86), fc, 2, 12, 12))
	var cid2 = _cur_cmd()
	var cc = DB.cards[cid2]
	w["cmdp"].mouse_filter = Control.MOUSE_FILTER_STOP
	w["cmdp"].tooltip_text = "Toque para ver os detalhes do comandante"
	for sg in w["cmdp"].gui_input.get_connections():
		w["cmdp"].gui_input.disconnect(sg["callable"])
	w["cmdp"].gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_army_show(cid2))
	var cv = _vbox(w["cmdp"], 6)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ch = _hbox(cv, 10)
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if DB.portraits.has(cid2):
		ch.add_child(_tex_rect(DB.portraits[cid2], Vector2(72, 72)))
	var cnv = _vbox(ch, 1)
	cnv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(cnv, ("COMANDANTE · %s" % DB.factions[fac]["short"].to_upper()) if not mix else ("MIX · COMANDANTE (%s)" % DB.factions[fac]["short"].to_upper()), 11, fc.lightened(0.45)).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(cnv, cc["name"], 24, C_GOLD).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(cnv, "entra em campo no round %d" % Game.CMD_ROUND, 12, C_DIM).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mix:
		var sw = _hbox(cnv, 6)
		var pb = _cbtn(sw, "◀", C_HUD, _mix_cmd_step.bind(-1))
		pb.custom_minimum_size = Vector2(44, 32)
		_label(sw, "trocar", 11, C_DIM).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var nb = _cbtn(sw, "▶", C_HUD, _mix_cmd_step.bind(1))
		nb.custom_minimum_size = Vector2(44, 32)
	if compact:
		_army_refresh_rest()
		return
	var cst = _hbox(cv, 6)
	cst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stat_cells(cst, cc)
	# só os nomes das habilidades: o texto completo fica no painel de detalhes
	var chips = HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 4)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(chips)
	var abk2 = cc["ab"].get("kind", "")
	_ab_chip(chips, "ATIVA" if abk2 == "ativa" else ("ESPECIAL" if abk2 == "especial" else "PASSIVA"), C_GOLD if abk2 == "ativa" or abk2 == "especial" else C_CARD, cc["ab"]["name"])
	if cc.has("ab2"):
		var k2 = cc["ab2"].get("kind", "ativa")
		_ab_chip(chips, "ATIVA" if k2 != "passiva" else "PASSIVA", C_GOLD if k2 != "passiva" else C_CARD, cc["ab2"]["name"])
	_army_refresh_rest()


func _ab_chip(parent: Control, kind: String, col: Color, nm: String) -> void:
	var pc = PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_theme_stylebox_override("panel", _flat(Color(col.darkened(0.6), 0.95), col, 2, 4, 4))
	parent.add_child(pc)
	var hb = _hbox(pc, 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(hb, kind, 9, col.lightened(0.3)).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(hb, nm, 12, C_TXT).mouse_filter = Control.MOUSE_FILTER_IGNORE


# quatro atributos: número grande com a legenda embaixo
func _stat_cells(parent: Control, c: Dictionary) -> void:
	var vals = [int(c["int"]), int(c["atk"]), int(c["mov"]), int(c["alc"])]
	var caps = ["VIDA", "ATQ", "MOV", "ALC"]
	for i in range(4):
		var pc = PanelContainer.new()
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pc.add_theme_stylebox_override("panel", _flat(Color(ST_COL[i].darkened(0.65), 0.95), ST_COL[i], 2, 4, 2))
		parent.add_child(pc)
		var v = _vbox(pc, 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var n = _label(v, str(vals[i]), 17, ST_COL[i].lightened(0.35))
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cp = _label(v, caps[i], 9, C_DIM)
		cp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cp.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _army_refresh_rest() -> void:
	# filtro de facção (só no Mix)
	for c in w["mixbar"].get_children():
		c.queue_free()
	w["mixbar"].visible = mix
	if mix:
		for f in [""] + DB.factions.keys():
			var col = Color("#e8e0ff") if f == "" else _fac_col(f)
			var on = mix_filter == f
			var fb = Button.new()
			fb.text = "Todas" if f == "" else DB.factions[f]["short"]
			fb.add_theme_font_size_override("font_size", 11 if compact else 12)
			fb.add_theme_stylebox_override("normal", _flat(Color(col.darkened(0.55), 0.92) if on else Color(0.03, 0.05, 0.1, 0.85), col if on else col.darkened(0.35), 2 if on else 1, 6, 5))
			fb.add_theme_stylebox_override("hover", _flat(Color(col.darkened(0.5), 0.95), col.lightened(0.2), 2, 6, 5))
			fb.add_theme_stylebox_override("pressed", _flat(Color(col.darkened(0.4), 0.95), col, 2, 6, 5))
			fb.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			fb.add_theme_color_override("font_color", Color.WHITE if on else col.lightened(0.4))
			fb.pressed.connect(_mix_filter_pick.bind(f))
			w["mixbar"].add_child(fb)
	# grade
	for c in w["grid"].get_children():
		c.queue_free()
	for c in _army_pool():
		w["grid"].add_child(_army_card(c))
	# vagas
	for c in w["slots"].get_children():
		c.queue_free()
	for i in range(5):
		w["slots"].add_child(_army_slot(army_picks[i] if i < army_picks.size() else ""))
	var ready_ok = army_picks.size() == 5 and army_start.size() == 2
	w["go"].disabled = not ready_ok
	var hint = "Exército %d/5 · ★ começa em campo (%d/2). Os outros ficam na reserva." % [army_picks.size(), army_start.size()]
	if army_picks.size() < 5:
		hint = "Escolha mais %d tropa(s). ★ = começa em campo (%d/2)." % [5 - army_picks.size(), army_start.size()]
	elif army_start.size() < 2:
		hint = "Marque mais %d tropa(s) com ★ para começar em campo." % (2 - army_start.size())
	if compact:
		hint = "%d/5 tropas · ★ em campo %d/2" % [army_picks.size(), army_start.size()]
	w["army_hint"].text = hint
	w["army_hint"].add_theme_color_override("font_color", C_DIM if ready_ok else Color("#ffb070"))
	_army_detail_build()


func _ab_box(parent: Control, kind: String, col: Color, nm: String, text: String, width: int) -> void:
	var p = PanelContainer.new()
	var s = _flat(Color(0.06, 0.09, 0.17, 0.92), col.darkened(0.2), 0, 8, 8)
	s.border_width_left = 3
	p.add_theme_stylebox_override("panel", s)
	parent.add_child(p)
	var v = _vbox(p, 2)
	var h = _hbox(v, 8)
	var kl = _label(h, kind, 10, col)
	kl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label(h, nm, 15, C_TXT)
	var t = _label(v, text, 13, C_DIM)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(width, 0)


func _stat_mini(parent: Control, col: Color, v: int) -> void:
	var h = _hbox(parent, 3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sw = ColorRect.new()
	sw.color = col
	sw.custom_minimum_size = Vector2(7, 7)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(sw)
	var l = _label(h, str(v), 13, C_TXT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


# botão principal: dourado cheio, texto escuro
func _primary(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _tex_box("res://ui/btn_on.png", 14, Color("#ffd21f"), 18, 10))
	b.add_theme_stylebox_override("hover", _tex_box("res://ui/btn_on.png", 14, Color("#ffe76a"), 18, 10))
	b.add_theme_stylebox_override("pressed", _tex_box("res://ui/btn_on.png", 14, Color("#ff9d1f"), 18, 10))
	b.add_theme_stylebox_override("disabled", _tex_box("res://ui/btn.png", 14, Color(0.2, 0.18, 0.28), 18, 10))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.86, 0.84, 0.95))
	b.add_theme_color_override("font_outline_color", Color("#2a0838"))
	b.add_theme_constant_override("outline_size", 8)


const ST_COL = [Color("#ff5a6a"), Color("#ffab40"), Color("#4cd964"), Color("#4da3ff")]


func _army_card(c: Dictionary) -> Control:
	var id = c["id"]
	var chosen = army_picks.has(id)
	var fc = _fac_col(c["f"])
	var b = Button.new()
	b.custom_minimum_size = Vector2(0, 176 if compact else 212)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tint = C_GOLD if chosen else (C_HUD if id == army_detail else fc)
	b.add_theme_stylebox_override("normal", _tex_box("res://ui/card.png", 20, tint, 9, 7))
	b.add_theme_stylebox_override("hover", _tex_box("res://ui/card.png", 20, tint.lightened(0.25) if not chosen else C_GOLD.lightened(0.3), 9, 7))
	b.add_theme_stylebox_override("pressed", _tex_box("res://ui/card.png", 20, C_GOLD, 9, 7))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(_army_toggle.bind(id))
	b.mouse_entered.connect(_army_show.bind(id))
	if army_picks.size() >= 5 and not chosen:
		b.modulate = Color(0.55, 0.57, 0.64, 1.0)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 9)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var pic = PanelContainer.new()
	pic.add_theme_stylebox_override("panel", _flat(fc.darkened(0.55), Color.BLACK, 2, 4, 2))
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pic)
	var tex = DB.portraits.get(id, DB.art.get(id, null))
	pic.add_child(_tex_rect(tex, Vector2(0, 66 if compact else 88)))
	if chosen:
		var bp = PanelContainer.new()
		bp.add_theme_stylebox_override("panel", _flat(C_GOLD, Color.BLACK, 2, 3, 2))
		bp.size_flags_horizontal = Control.SIZE_SHRINK_END
		bp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.add_child(bp)
		var badge = _label(bp, "★ EM CAMPO" if army_start.has(id) else "RESERVA", 10, Color("#2a1a00"))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nl = _label(v, c["name"], 15, C_GOLD if chosen else C_TXT)
	nl.clip_text = true
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rl = _label(v, c["role"], 11, fc.lightened(0.5))
	rl.clip_text = true
	rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sr = _hbox(v, 3)
	sr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stat_cells(sr, c)
	var kd = _ab_kind(c)
	var al = _label(v, c["ab"]["name"], 11, kd[1].lightened(0.4))
	al.clip_text = true
	al.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _army_slot(id: String) -> Control:
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(76 if compact else 104, 0)
	if id == "":
		p.add_theme_stylebox_override("panel", _flat(Color(0.03, 0.05, 0.1, 0.6), Color(0.3, 0.42, 0.55, 0.6), 1, 8, 6))
		var l = _label(p, "vaga\nlivre", 12, Color(0.68, 0.74, 0.85))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return p
	var on = army_start.has(id)
	p.add_theme_stylebox_override("panel", _flat(Color(0.05, 0.08, 0.16, 0.92), C_GOLD if on else _fac_col(DB.cards[id]["f"]), 2, 8, 5))
	var v = _vbox(p, 2)
	var tex = DB.portraits.get(id, null)
	v.add_child(_tex_rect(tex, Vector2(0, 36 if compact else 50)))
	var nl = _label(v, _short(id), 11, C_TXT)
	nl.clip_text = true
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var h = _hbox(v, 3)
	var sb = Button.new()
	sb.text = "★" if on else "☆"
	sb.tooltip_text = "Começa em campo" if on else "Fica na reserva (toque para começar em campo)"
	sb.custom_minimum_size = Vector2(36, 26) if compact else Vector2(46, 28)
	_style_btn(sb, C_GOLD, on)
	sb.pressed.connect(_army_star.bind(id))
	h.add_child(sb)
	var xb = Button.new()
	xb.text = "×"
	xb.custom_minimum_size = Vector2(30, 26) if compact else Vector2(40, 28)
	_style_btn(xb, C_ATK)
	xb.pressed.connect(_army_toggle.bind(id))
	h.add_child(xb)
	xb.visible = not compact   # no celular: toque na carta da tropa para tirar
	return p


func _army_show(id: String) -> void:
	if army_detail == id:
		return
	army_detail = id
	_army_detail_build()


func _army_detail_build() -> void:
	if not w.has("det") or not is_instance_valid(w["det"]):
		return
	var id = army_detail
	if not DB.cards.has(id):
		return
	var c = DB.cards[id]
	var fc = _fac_col(c["f"])
	var det: PanelContainer = w["det"]
	for ch in det.get_children():
		ch.queue_free()
	det.add_theme_stylebox_override("panel", _flat(Color(0.03, 0.05, 0.11, 0.9), fc, 2, 12, 12))
	var sc = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_fat_scroll(sc)
	det.add_child(sc)
	var v = _vbox(sc, 7)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# arte com fundo na cor da facção
	var art = PanelContainer.new()
	var gs = StyleBoxTexture.new()
	var gt = GradientTexture2D.new()
	var gr = Gradient.new()
	gr.set_color(0, fc.darkened(0.25))
	gr.set_color(1, Color(fc.darkened(0.7), 0.0))
	gt.gradient = gr
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gs.texture = gt
	art.add_theme_stylebox_override("panel", gs)
	v.add_child(art)
	art.add_child(_tex_rect(DB.art.get(id, DB.portraits.get(id, null)), Vector2(0, 165)))
	_label(v, c["name"], 26, C_GOLD)
	_label(v, "%s · %s" % [c["role"], DB.factions[c["f"]]["short"]], 13, fc.lightened(0.35))
	# barras de atributos
	var names = ["VIDA", "ATAQUE", "MOVIMENTO", "ALCANCE"]
	var vals = [int(c["int"]), int(c["atk"]), int(c["mov"]), int(c["alc"])]
	var maxs = [14.0, 6.0, 4.0, 6.0]
	for i in range(4):
		var h = _hbox(v, 8)
		var nl = _label(h, names[i], 11, C_DIM)
		nl.custom_minimum_size = Vector2(88, 0)
		var bar = Control.new()
		bar.custom_minimum_size = Vector2(0, 10)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(bar)
		var bg = ColorRect.new()
		bg.color = Color(1, 1, 1, 0.08)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bar.add_child(bg)
		var fill = ColorRect.new()
		fill.color = ST_COL[i]
		fill.anchor_bottom = 1.0
		fill.anchor_right = clamp(vals[i] / maxs[i], 0.05, 1.0)
		bar.add_child(fill)
		var vl = _label(h, str(vals[i]), 14, ST_COL[i].lightened(0.2))
		vl.custom_minimum_size = Vector2(24, 0)
	# habilidades
	var kd = _ab_kind(c)
	if c.get("cmd", false):
		kd = ["PASSIVA", C_CARD]
	var dw = int(clamp(get_viewport().get_visible_rect().size.x * 0.335 - 60.0, 220.0, 420.0))
	_ab_box(v, kd[0], kd[1], c["ab"]["name"], c["ab"]["text"], dw)
	if c.has("ab2"):
		var k2 = c["ab2"].get("kind", "ativa")
		_ab_box(v, _per_label(c["ab2"]) if k2 != "passiva" else "PASSIVA", C_GOLD if k2 != "passiva" else C_CARD, c["ab2"]["name"], c["ab2"]["text"], dw)
	# impacto no jogo
	var im = _impact(c)
	_label(v, "IMPACTO NO JOGO", 12, C_HUD)
	var flow = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	v.add_child(flow)
	for t in im["tags"]:
		var tp = PanelContainer.new()
		tp.add_theme_stylebox_override("panel", _flat(Color(t[1], 0.16), t[1], 1, 10, 4))
		flow.add_child(tp)
		var tl = _label(tp, t[0], 12, t[1].lightened(0.3))
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not c.get("cmd", false):
		var chosen = army_picks.has(id)
		var h2 = _hbox(v, 8)
		var ab = _cbtn(h2, "REMOVER" if chosen else "+ ADICIONAR", C_ATK if chosen else C_MOVE, _army_toggle.bind(id), not chosen)
		ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ab.disabled = not chosen and army_picks.size() >= 5
		if chosen:
			_cbtn(h2, "★ EM CAMPO" if army_start.has(id) else "☆ RESERVA", C_GOLD, _army_star.bind(id), army_start.has(id))


func _army_fac_pick(f: String) -> void:
	if f == "MIX":
		if mix:
			return
		# entra no Mix mantendo as tropas já escolhidas
		mix = true
		mix_cmd = DB.factions[setup_cfg["fac"]]["cmd"]
		mix_filter = ""
		army_fac = "MIX"
		army_detail = mix_cmd
		sfx.play("clique", -8.0)
		_army_refresh()
		return
	if f == setup_cfg["fac"] and not mix:
		return
	mix = false
	setup_cfg["fac"] = f
	army_fac = f
	army_picks = []
	army_start = []
	army_detail = DB.factions[f]["cmd"]
	sfx.play("clique", -8.0)
	_fac_music(f)
	_army_refresh()


func _army_cpu(i: int, ob: OptionButton) -> void:
	setup_cfg["cpu"] = ob.get_item_metadata(i)


func _army_back() -> void:
	if stage != "army":
		return
	stage = "to_select"
	sfx.play("clique", -8.0)
	_fac_music("")
	sfx.loop("musica_galaxia", -9.0, 2.0)
	await _ui_fade(0.0, 0.35)
	_show_select()


func _army_toggle(id: String) -> void:
	army_detail = id
	if army_picks.has(id):
		army_picks.erase(id)
		army_start.erase(id)
	elif army_picks.size() < 5:
		army_picks.append(id)
		if army_start.size() < 2:
			army_start.append(id)
	if sfx != null:
		sfx.play("clique", -8.0)
	_army_refresh()


func _army_star(id: String) -> void:
	if army_start.has(id):
		army_start.erase(id)
	elif army_start.size() < 2:
		army_start.append(id)
	else:
		army_start.pop_front()
		army_start.append(id)
	if sfx != null:
		sfx.play("clique", -8.0)
	_army_refresh()


func _army_random() -> void:
	var x = AI.setup_mix()["picks"] if mix else AI.setup(setup_cfg["fac"])["picks"]
	for id in x:
		if army_picks.size() < 5 and not army_picks.has(id):
			army_picks.append(id)
	var pool = _army_pool()
	pool.shuffle()
	for c in pool:
		if army_picks.size() < 5 and not army_picks.has(c["id"]):
			army_picks.append(c["id"])
	if army_start.size() < 2:
		var tough = army_picks.filter(func(i): return not army_start.has(i))
		tough.sort_custom(func(a, b): return int(DB.cards[a]["int"]) > int(DB.cards[b]["int"]))
		for i in tough:
			if army_start.size() < 2:
				army_start.append(i)
	_army_refresh()


func _army_clear() -> void:
	army_picks = []
	army_start = []
	_army_refresh()


func _cpu_fac() -> String:
	if setup_cfg["cpu"] == "MIX" or (setup_cfg["cpu"] != "RND" and DB.factions.has(setup_cfg["cpu"])):
		return setup_cfg["cpu"]
	var fs = DB.factions.keys().filter(func(f): return f != setup_cfg["fac"])
	return fs[randi() % fs.size()]


func _army_go() -> void:
	if army_picks.size() != 5 or army_start.size() != 2 or stage != "army":
		return
	stage = "dive"
	sfx.play("confirmar", -6.0)
	DB.set_map(setup_cfg["map"])
	var spots = DB.entry[0]
	var mine = {"fac": setup_cfg["fac"], "cmd": _cur_cmd(), "mix": mix, "picks": army_picks.duplicate(), "start": [{"id": army_start[0], "h": spots[0]}, {"id": army_start[1], "h": spots[spots.size() - 1]}]}
	var sides = [mine, _cpu_side(1, _cpu_fac())]
	await _ui_fade(0.0, 0.4)
	sfx.play("vfx_portal", -6.0)
	sfx.play("vfx_dash", -8.0)
	sfx.stop_loop("musica_galaxia", 2.5)
	_fac_music("")
	galaxy.set_mode("dive")
	await get_tree().create_timer(1.15).timeout
	await _fade(1.0, 0.55, galaxy.data(planet_id).get("dive", Color("#e0b070")))
	intro = true
	_start_match(sides)


func _cpu_side(p: int, fac: String) -> Dictionary:
	DB.set_map(setup_cfg["map"])
	var s = AI.setup_mix() if fac == "MIX" else AI.setup(fac)
	var tough = s["picks"].duplicate()
	tough.sort_custom(func(a, b): return int(DB.cards[a]["int"]) > int(DB.cards[b]["int"]))
	var spots = DB.entry[p]
	s["start"] = [{"id": tough[0], "h": spots[0]}, {"id": tough[1], "h": spots[spots.size() - 1]}]
	return s


func _start_match(sides) -> void:
	DB.set_map(setup_cfg["map"])
	if sides == null:
		sides = []
		for p in range(2):
			var fac = setup_cfg["fac"] if p == 0 else setup_cfg["cpu"]
			var s = AI.setup_mix() if fac == "MIX" else AI.setup(fac)
			var tough = s["picks"].duplicate()
			tough.sort_custom(func(a, b): return int(DB.cards[a]["int"]) > int(DB.cards[b]["int"]))
			var spots = DB.entry[p]
			s["start"] = [{"id": tough[0], "h": spots[0]}, {"id": tough[1], "h": spots[spots.size() - 1]}]
			sides.append(s)
	last_sides = sides
	game = Game.new()
	game.tree = get_tree()
	game.cpu = [autotest, true]
	game.tut = tut
	game.clock_on = false   # sem relógio de xadrez
	if online:
		game.rng.seed = net_seed
		game.cpu = [false, false]
		game.remote = [me != 0, me != 1]
		game.net_send = net.send
		game.ans_buf = net_pre_ans
		net_pre_ans = []
		net_busy = false
		opp_thinking = false
	else:
		me = 0
		game.rng.randomize()
	board.me = me
	# no online cada jogador se vê sempre do lado direito
	board.flip_view = online
	turn_seen = -1
	game.setup(sides, setup_cfg["map"])
	game.question.connect(_on_question)
	if not autotest:
		game.cine = _cine_commanders
	game.changed.connect(refresh)
	game.fx_event.connect(_on_fx)
	sel = -1
	dsel = -1
	pend = null
	am = ""
	ab = false
	tip = null
	inspect = -1
	hex_info = null
	asking = null
	busy = true
	running = false
	panel_open = ""
	stage = "battle"
	_build_hud()
	galaxy.deactivate()
	board.visible = true
	board.build(game)
	board.cam.make_current()
	if intro:
		intro = false
		# chegada: a câmera desce do alto do planeta até o tabuleiro
		var gy = board.cam_yaw
		board.cam_dist = 120.0
		board.cam_pitch = 1.42
		board.cam_yaw = gy + 0.9
		board.cam_speed = 1.7
		board.fit_camera(false)
		ui.modulate.a = 0.0
		_fade(0.0, 0.8)
		_later(1.2, func(): _ui_fade(1.0, 0.7))
		_later(3.0, func(): board.cam_speed = 8.0)
	else:
		ui.modulate.a = 1.0
		if fader.color.a > 0.0:
			_fade(0.0, 0.4)
	vfx.setup_ambient(game.map_id)
	sfx.stop_all_loops()
	if game.map_id == "tarhut" or game.map_id == "goraida":
		sfx.loop("vento_loop", -15.0, 2.0)
	elif game.map_id == "abnara":
		sfx.loop("ilha_loop", -14.0, 2.0)
	else:
		sfx.loop("caverna_loop", -12.0, 2.0)
	if autotest:
		_map_music()
	refresh()
	if tut:
		_map_music()
		var tn = Node.new()
		tn.set_script(load("res://scripts/tutorial.gd"))
		add_child(tn)
		tn.start(self)
		tut_node = tn
	elif not autotest:
		await _entrance()
	_apply_speed()
	await game.begin_game()
	busy = false
	await after()


# ================= HUD da batalha =================
func _build_hud() -> void:
	_clear_ui()
	plates.clear()
	var plr = Control.new()
	plr.set_anchors_preset(Control.PRESET_FULL_RECT)
	plr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(plr)
	w["plates"] = plr
	# coluna do alto: título, avisos de ação e perguntas
	var topcol = _vbox(ui, 4)
	_place(topcol, Control.PRESET_CENTER_TOP, 6)
	topcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top = _panel(topcol)
	var tv = _vbox(top, 2)
	w["title"] = _label(tv, "", 22, C_GOLD)
	w["title"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w["events"] = _label(tv, "", 14, Color("#ffcf9a"))
	w["events"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# botões do canto
	var topr = _hbox(ui, 6)
	_place(topr, Control.PRESET_TOP_RIGHT, 8)
	if compact and not online:
		_button(topr, "CPU", _toggle_cpu)
	_button(topr, "Cartas", func(): _toggle_panel("cards"))
	if not compact:
		_button(topr, "Registro", func(): _toggle_panel("log"))
	_button(topr, "Regras", func(): _toggle_panel("rules"))
	_button(topr, "Opções", _settings_panel)
	_button(topr, "Menu", _show_menu)
	# câmera: linha compacta acima do painel de fim de turno
	var camv = _hbox(ui, 4)
	_place(camv, Control.PRESET_BOTTOM_RIGHT, 8)
	camv.offset_top -= 116 if compact else 128
	camv.offset_bottom -= 116 if compact else 128
	for cb in [["<", func(): board.rotate_cam(-1), "Girar a câmera"], [">", func(): board.rotate_cam(1), "Girar a câmera"], ["+", func(): board.zoom_cam(0.7), "Aproximar (roda do mouse)"], ["-", func(): board.zoom_cam(1.4), "Afastar (roda do mouse)"], ["Tudo", func(): board.fit_camera(false), "Ver o tabuleiro inteiro"]]:
		var bb = _button(camv, cb[0], cb[1])
		bb.tooltip_text = cb[2]
		bb.custom_minimum_size = Vector2(44, 40)
		# no toque (Android/tablet) a câmera é só por gestos; fica só o "Tudo"
		if _is_touch() and cb[0] != "Tudo":
			bb.visible = false
	# colunas de peças
	var left = _panel(ui)
	_place(left, Control.PRESET_TOP_LEFT, 8)
	w["party0_sc"] = _roster_scroll(left)
	w["party0"] = _vbox(w["party0_sc"], 3)
	# avisos de ação (no alto)
	var aw = _panel(topcol)
	aw.add_theme_stylebox_override("panel", _tex_box("res://ui/panel_soft.png", 22, C_HUD, 16, 8))
	var av = _vbox(aw, 4)
	w["note"] = _label(av, "", 16)
	w["note"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w["why"] = _label(av, "", 13, Color("#ffcf9a"))
	w["why"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w["why"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var vw = get_viewport().get_visible_rect().size
	w["why"].custom_minimum_size = Vector2(min(560.0, vw.x * 0.45), 0)
	var lg = _hbox(av, 14)
	lg.alignment = BoxContainer.ALIGNMENT_CENTER
	_chip(lg, C_MOVE, "Andar (nº = custo)")
	_chip(lg, C_ATK, "Atacar")
	_chip(lg, C_ABIL, "Habilidade / escolher")
	_chip(lg, C_DEPLOY, "Entrar em campo")
	_chip(lg, Color(0.12, 0.1, 0.08), "Fora de alcance (clique: por quê?)")
	w["legend"] = lg
	if compact:
		lg.visible = false
	# perguntas e prévias (logo abaixo dos avisos)
	var pr = _panel(topcol)
	pr.custom_minimum_size = Vector2(min(560.0, vw.x * 0.48), 0)
	var pv = _vbox(pr, 8)
	w["prompt_text"] = _rich(pv, int(min(540.0, vw.x * 0.46)))
	w["prompt_btns"] = _hbox(pv, 8)
	w["prompt_btns"].alignment = BoxContainer.ALIGNMENT_END
	w["prompt"] = pr
	# ficha da peça
	var uc = _panel(ui)
	_place(uc, Control.PRESET_BOTTOM_LEFT, 8)
	w["ucard_text"] = _rich(uc, 200 if compact else 232)
	w["ucard_text"].add_theme_font_size_override("normal_font_size", 12)
	w["ucard_text"].add_theme_font_size_override("bold_font_size", 12)
	w["ucard_text"].add_theme_font_size_override("italics_font_size", 12)
	w["ucard"] = uc
	# embaixo: mão de cartas + botões de ação
	var botcol = _vbox(ui, 6)
	_place(botcol, Control.PRESET_CENTER_BOTTOM, 8)
	botcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# prévia/perguntas logo acima das cartas
	w["prompt"].reparent(botcol)
	w["prompt"].size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	w["hand"] = _hbox(botcol, 6)
	w["hand"].alignment = BoxContainer.ALIGNMENT_CENTER
	var ab_p = _panel(botcol)
	w["abp"] = ab_p
	var abv = _vbox(ab_p, 4)
	w["btns"] = _hbox(abv, 6)
	w["btns"].alignment = BoxContainer.ALIGNMENT_CENTER
	# camada dos balões de fala
	var bub = Control.new()
	bub.set_anchors_preset(Control.PRESET_FULL_RECT)
	bub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bub)
	w["bubbles"] = bub
	# fim de turno
	var eb = _panel(ui)
	_place(eb, Control.PRESET_BOTTOM_RIGHT, 8)
	w["end_panel"] = eb
	var ev = _vbox(eb, 4)
	w["end_hint"] = _label(ev, "", 13, C_DIM)
	w["end_hint"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w["end"] = _button(ev, "PASSAR O ROUND", _on_end_pressed)
	w["end"].custom_minimum_size = Vector2(210 if compact else 270, 60 if compact else 72)
	w["end"].add_theme_font_size_override("font_size", 20 if compact else 24)
	if font_title != null:
		w["end"].add_theme_font_override("font", font_title)
	# coluna da CPU (à direita, acima do fim de turno)
	var right = _panel(ui)
	_place(right, Control.PRESET_TOP_RIGHT, 8)
	right.offset_top = 64
	w["party1_sc"] = _roster_scroll(right)
	w["party1"] = _vbox(w["party1_sc"], 3)
	w["party1_panel"] = right
	right.visible = cpu_open or not compact
	# painel lateral (cartas / registro / regras)
	var side = _panel(ui)
	_place(side, Control.PRESET_CENTER, 0)
	side.custom_minimum_size = Vector2(min(620.0, vw.x - 40.0), 0)
	var sv = _vbox(side, 10)
	w["side_title"] = _label(sv, "", 26, C_GOLD)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(min(600.0, vw.x - 60.0), min(420.0, vw.y - 190.0))
	_fat_scroll(scroll)
	sv.add_child(scroll)
	w["side_body"] = _vbox(scroll, 8)
	w["side_body"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(sv, "Fechar", func(): _toggle_panel(""))
	w["side"] = side
	side.visible = false
	# arraste de reserva
	var dr = TextureRect.new()
	dr.custom_minimum_size = Vector2(70, 70)
	dr.size = Vector2(70, 70)
	dr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dr.visible = false
	ui.add_child(dr)
	w["drag_icon"] = dr
	# pergunta que trava o jogo: balão destacado no meio da tela
	var adim = ColorRect.new()
	adim.color = Color(0.0, 0.01, 0.04, 0.42)
	adim.set_anchors_preset(Control.PRESET_FULL_RECT)
	adim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	adim.visible = false
	ui.add_child(adim)
	w["ask_dim"] = adim
	var ask = PanelContainer.new()
	var asb = _flat(Color(0.03, 0.05, 0.12, 0.97), Color("#ffab40"), 3, 14, 20)
	asb.shadow_color = Color(1.0, 0.6, 0.15, 0.35)
	asb.shadow_size = 18
	ask.add_theme_stylebox_override("panel", asb)
	w["ask_sb"] = asb
	ui.add_child(ask)
	ask.set_anchors_preset(Control.PRESET_CENTER)
	ask.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ask.grow_vertical = Control.GROW_DIRECTION_BOTH
	ask.z_index = 30
	ask.visible = false
	var akv = _vbox(ask, 12)
	var akh = _label(akv, "SUA DECISÃO", 13, C_GOLD)
	akh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w["ask_head"] = akh
	w["ask_text"] = _rich(akv, int(min(600.0, vw.x * 0.62)))
	w["ask_text"].add_theme_font_size_override("normal_font_size", 18 if compact else 19)
	w["ask_text"].add_theme_font_size_override("bold_font_size", 20 if compact else 21)
	w["ask_btns"] = _hbox(akv, 10)
	w["ask_btns"].alignment = BoxContainer.ALIGNMENT_CENTER
	w["ask"] = ask
	# faixa de anúncios
	var bn = Label.new()
	bn.add_theme_font_size_override("font_size", 64)
	if font_title != null:
		bn.add_theme_font_override("font", font_title)
	bn.add_theme_constant_override("outline_size", 14)
	bn.add_theme_color_override("font_outline_color", Color.BLACK)
	bn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bn)
	_place(bn, Control.PRESET_CENTER, 0)
	bn.modulate.a = 0.0
	w["banner"] = bn


func banner(big: String, small: String = "") -> void:
	var bn: Label = w.get("banner", null)
	if bn == null:
		return
	bn.text = big + ("\n" + small if small != "" else "")
	bn.remove_theme_color_override("font_color")
	bn.modulate.a = 1.0
	var tw = create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(bn, "modulate:a", 0.0, 0.6)


func _toggle_panel(which: String) -> void:
	panel_open = "" if panel_open == which else which
	_refresh_side()


# ================= estado do jogador =================
func viewer() -> int:
	return 0


# ---- colocar reservas em campo: quando e onde ----
func can_deploy_now() -> bool:
	return my_turn() and game.act == null and not game.reserve_of(me).is_empty() and not game.deploy_hexes(me).is_empty()


func deploy_block_reason() -> String:
	if game.reserve_of(me).is_empty():
		return "Sem reservas: todas as suas peças já estão em campo."
	if game.winner != Game.NONE:
		return "Fim de jogo."
	if game.cpu[game.cur] or busy:
		return "Aguarde a sua vez para colocar reservas."
	if game.act != null:
		return "Termine a ativação de %s (botão Encerrar ativação) para colocar uma reserva." % game.nm(game.active_unit())
	if game.deploy_hexes(me).is_empty():
		return "Sua entrada está lotada: tire uma peça de lá para abrir espaço."
	return ""


func my_turn() -> bool:
	return game != null and game.winner == Game.NONE and not game.cpu[game.cur] and game.cur == me and not game.remote[game.cur] and not busy and asking == null


func sel_unit() -> Variant:
	return game.by_uid(sel) if sel >= 0 else null


func act_unit() -> Variant:
	return game.active_unit() if game.act != null else null


func sel_or_act() -> Variant:
	var a = act_unit()
	if a != null:
		return a
	var u = sel_unit()
	if u != null and game.can_start(u):
		return u
	return null


func can_drag_unit(u) -> bool:
	return my_turn() and u.owner == game.cur and not u.barrier and (game.can_start(u) or game.is_live(u))


func highlights() -> Dictionary:
	var H = {"mv": [], "at": [], "pk": [], "ghost": null}
	if asking != null and asking["q"]["t"] == "hex":
		H["pk"] = asking["q"]["opts"]
		return H
	if not my_turn():
		return H
	if dsel >= 0:
		H["pk"] = game.deploy_hexes(game.cur)
		return H
	var u = sel_unit()
	if u == null or u.owner != game.cur or u.st != "field":
		return H
	var live = game.is_live(u)
	if not live and not game.can_start(u):
		return H
	if ab:
		if game.K(u).get("action", "") == "tunnel":
			H["pk"] = game.tunnel_opts(u)
		else:
			H["pk"] = [u.pos()]
			if not (live and game.act["moved"]):
				for m in game.move_opts(u, game.mov_of(u)):
					H["pk"].append(m["h"])
		if pend != null and pend["kind"] == "ab":
			H["ghost"] = pend["h"]
		return H
	var acts = game.act["actions"] if live else 2
	var can_atk = not live or (not game.act["attacked"] and not game.act["cant_attack"])
	if acts > 0 and not game.rooted(u) and not (live and game.act["moved"]):
		H["mv"] = game.move_opts(u, game.mov_of(u))
	var pm = _pend_move()
	if pm != null:
		H["ghost"] = pm["h"]
		if acts - 1 > 0 and can_atk:
			for t in game.attack_targets(u, pm["h"]):
				H["at"].append(t.pos())
	elif acts > 0 and can_atk:
		for t in game.attack_targets(u):
			H["at"].append(t.pos())
	if am == "mv":
		H["at"] = []
	if am == "at":
		H["mv"] = []
	return H


func _pend_move() -> Variant:
	if pend != null and (pend["kind"] == "move" or pend["kind"] == "moveatk"):
		return pend
	return null


# ================= redesenho =================
var turn_seen := -1


func refresh() -> void:
	if game == null or not w.has("title"):
		return
	_turn_sound()
	var H = highlights()
	var st = {"hl": {}, "lit": null, "labels": {}, "label_colors": {}, "tags": {}, "sel_uid": -1, "ghost": null}
	for p in range(2):
		for h in game.entry_zone(p):
			st["hl"][h] = "entry%d" % (0 if p == me else 1)
	if can_deploy_now() or dsel >= 0 or (res_drag != null and res_drag.get("on", false)):
		var show_lbl = dsel >= 0 or (res_drag != null and res_drag.get("on", false))
		for h in game.deploy_hexes(me):
			st["hl"][h] = "deploy"
			if show_lbl:
				st["labels"][h] = "+ ENTRAR"
				st["label_colors"][h] = C_DEPLOY.lightened(0.4)
	# bombas escondidas do Rappy: só o dono vê
	for mn in game.mines:
		if mn["owner"] == me:
			st["labels"][mn["h"]] = "BOMBA" if mn.get("hidden", false) else "MINA"
			st["label_colors"][mn["h"]] = Color("#ff9a3a")
	for fr in game.fires:
		st["labels"][fr["h"]] = "FOGO"
		st["label_colors"][fr["h"]] = Color("#ff6a2a")
	for sh in game.shells:
		st["labels"][sh["h"]] = "ARTILHARIA"
		st["label_colors"][sh["h"]] = Color("#ffcc55")
	board.sync_bananas(game.bananas, me)
	board.sync_core(game.core, game.core_next if game.core == null or game.core_next != game.core else null)
	if game.core != null:
		st["labels"][game.core] = "NÚCLEO"
		st["label_colors"][game.core] = Color("#7ff0ff")
	if game.core_next != null and game.core_next != game.core:
		st["labels"][game.core_next] = "próximo núcleo · round %d" % game.core_next_round
		st["label_colors"][game.core_next] = Color("#9fd8e8")
	_check_tension()
	# Valak: área de perigo da garra (mais forte quando a vibração está alta)
	if not game.hole.is_empty() and game.vib >= int(game.vrule("vib_max", 5)) - 2:
		for h in DB.hexes:
			if game.in_zone(h) and not st["hl"].has(h) and not game.hole.has(h):
				st["hl"][h] = "danger"
	board.sync_carts(game.carts)
	for h in game.tremors:
		st["hl"][h] = "danger" if game.warn_kind == "avalanche" else "trem"
		st["labels"][h] = "!"
		st["label_colors"][h] = Color("#ffe39a")
	if game.dune_next >= 0:
		var nd = game.dune_heights(game.dune_next)
		for h in nd.keys():
			st["hl"][h] = "dnext"
			st["labels"][h] = "vai p/ %d" % nd[h]
			st["label_colors"][h] = Color("#9ff0ff")
	var su = sel_unit()
	var focus = my_turn() and ((su != null and su.owner == game.cur and su.st == "field" and (game.can_start(su) or game.is_live(su))) or dsel >= 0)
	if focus:
		var lit = {}
		for m in H["mv"]:
			lit[m["h"]] = true
		for h in H["at"]:
			lit[h] = true
		for h in H["pk"]:
			lit[h] = true
		if su != null and dsel < 0:
			lit[su.pos()] = true
		if H["ghost"] != null:
			lit[H["ghost"]] = true
		st["lit"] = lit
	for m in H["mv"]:
		st["hl"][m["h"]] = "mv"
		if m["c"] > 0:
			st["labels"][m["h"]] = str(m["c"])
			st["label_colors"][m["h"]] = Color.WHITE
	for h in H["at"]:
		st["hl"][h] = "at"
	for h in H["pk"]:
		st["hl"][h] = "pk"
	if su != null and su.st == "field":
		st["hl"][su.pos()] = "prev" if H["ghost"] != null else "sel"
		st["sel_uid"] = su.uid
	if H["ghost"] != null:
		st["hl"][H["ghost"]] = "sel"
		st["ghost"] = H["ghost"]
	if pend != null and pend.has("tuid"):
		var tt = game.by_uid(pend["tuid"])
		if tt != null:
			st["hl"][tt.pos()] = "tgt"
	if tip != null:
		if tip.has("hex"):
			st["hl"][tip["hex"]] = "no"
		if tip.get("block", null) != null:
			st["hl"][tip["block"]] = "no"
	# etiquetas sobre os inimigos
	var att = su
	var foe_view = att != null and my_turn() and att.owner == game.cur and att.st == "field" and (game.can_start(att) or game.is_live(att))
	if foe_view:
		var fpos = H["ghost"] if (H["ghost"] != null and not ab) else null
		for t in game.field():
			if t.owner == att.owner or t.barrier:
				continue
			if H["at"].has(t.pos()):
				var pv = game.preview_damage(att, t, fpos)
				var tx = "-%d" % pv["dmg"]
				if pv["high"]:
					tx += " (do alto)"
				if pv["cover"]:
					tx += " (abrigado)"
				if pv["kills"]:
					tx += " DERRUBA"
				st["tags"][t.uid] = {"text": tx, "color": C_ATK.lightened(0.25)}
			else:
				var wn = game.why_no_attack(att, t, fpos)
				if wn != null:
					st["tags"][t.uid] = {"text": wn["s"], "color": Color("#ffd9b0")}
	last_st = st
	board.set_state(_with_card_hover(st))
	_refresh_top()
	_refresh_party()
	_refresh_ucard()
	_refresh_actbar()
	_refresh_hand()
	_refresh_prompt()
	_refresh_side()


# cinemática do round 4: cada comandante assiste ao campo antes de entrar
func _cine_commanders() -> void:
	if tut or game == null:
		return
	var cmds = []
	for p in [me, 1 - me]:
		var c = game.commander(p)
		if c != null and c.st == "off" and DB.art.has(c.cid):
			cmds.append({"cid": c.cid, "owner": p})
	if cmds.is_empty():
		return
	var was = ui.visible
	ui.visible = false
	var cn = Node3D.new()
	cn.set_script(load("res://scripts/cinematica.gd"))
	add_child(cn)
	await cn.run(self, cmds)
	cn.queue_free()
	ui.visible = was
	refresh()


# aviso sonoro quando a vez muda de jogador
func _turn_sound() -> void:
	if game.winner != Game.NONE or autotest:
		return
	if game.cur == turn_seen:
		return
	turn_seen = game.cur
	if game.cur == me:
		sfx.play("vez_sua", -4.0, 1.0, 0.0)
	else:
		sfx.play("vez_rival", -9.0, 1.0, 0.0)


var title_base: String = ""


func _fmt_clock(t: float) -> String:
	var sec = int(ceil(max(0.0, t)))
	return "%02d:%02d" % [sec / 60, sec % 60]


func _apply_title() -> void:
	if not w.has("title") or not is_instance_valid(w["title"]):
		return
	if w["title"].text != title_base:
		w["title"].text = title_base
	if game == null or not game.clock_on:
		return
	for p in range(2):
		var cl = w.get("clock%d" % p, null)
		if cl == null or not is_instance_valid(cl):
			continue
		var t = float(game.clock[p])
		var run = game.cur == p and game.winner == Game.NONE
		var tx = "⏱ %s%s" % [_fmt_clock(t), "  ◀ jogando" if run else ""]
		if cl.text == tx and cl.has_meta("run") and cl.get_meta("run") == run:
			continue
		cl.set_meta("run", run)
		cl.text = tx
		cl.add_theme_color_override("font_color", Color("#ff5a4a") if t < 60.0 else (Color("#ffe39a") if run else Color("#8fb8cc")))


# relógio de xadrez: só corre para quem está jogando (e não durante animações)
func _tick_clock(delta: float) -> void:
	if game == null or not game.clock_on or game.winner != Game.NONE or not ui.visible:
		return
	var p = game.cur
	if game.cpu[p] and not online:
		# a CPU gasta tempo no turno dela (inclusive nas animações), mas nunca perde por tempo
		game.clock[p] = max(1.0, float(game.clock[p]) - delta)
		return
	if busy and asking == null:
		return
	if opp_thinking:
		return
	game.clock[p] = float(game.clock[p]) - delta
	if game.clock[p] <= 0.0 and not game.remote[p]:
		game.flag_time(p)


func _refresh_top() -> void:
	var who = "Você" if game.cur == me else _opp()
	var status = "Fim de jogo" if game.winner != Game.NONE else ("Sua vez" if game.cur == me else ("Vez do " + _opp().to_lower() + (" (jogando...)" if busy or opp_thinking else "")))
	title_base = "%s  ·  Round %d/10  ·  %s" % [game.map_name, game.round_no, status]
	_apply_title()
	var tcol = C_GOLD if game.winner != Game.NONE else (C_YOU if game.cur == me else C_CPU)
	w["title"].add_theme_color_override("font_color", tcol)
	var ev = []
	if not game.hole.is_empty():
		var vm = int(game.vrule("vib_max", 5))
		ev.append("VIBRAÇÃO %s %d/%d%s" % ["●".repeat(game.vib) + "○".repeat(max(0, vm - game.vib)), game.vib, vm, "  ⚠ A GARRA VAI ATACAR" if game.vib >= vm - 1 else ""])
	if game.storm_on():
		ev.append("TEMPESTADE DE AREIA: ATAQUES -2")
	if game.rain_on():
		ev.append("CHUVA: ATAQUES -3" + (" · INCÊNDIO: PERTO = -1 VIDA/ROUND" if not game.fire.is_empty() else ""))
	var def = DB.maps[game.map_id]
	if def.has("dunes"):
		if game.dune_next >= 0:
			ev.append("DUNAS MUDAM NO PRÓXIMO ROUND")
		else:
			var nd = game.round_no + 1
			while (nd - 1) % Game.DUNE_EVERY != 0:
				nd += 1
			if nd <= 10:
				ev.append("Dunas mudam no round %d" % nd)
	if def.get("worms", false):
		if not game.tremors.is_empty():
			ev.append("TREMOR: VERMES NO PRÓXIMO ROUND")
		else:
			var wr = game.round_no + 1
			while not game.worm_round(wr):
				wr += 1
			if wr <= 10:
				ev.append("Vermes no round %d" % wr)
	if game.core != null:
		ev.insert(0, "NÚCLEO ATIVO até o round %d" % game.core_until)
	elif game.core_next != null:
		ev.insert(0, "Núcleo surge no round %d" % game.core_next_round)
	w["events"].text = "   ·   ".join(ev)
	w["events"].visible = not ev.is_empty()


var party_sig: String = ""
var hand_sig: String = ""


func _party_signature() -> String:
	var s = "%d|%d|%d|%d|%d|%s|%s|%s|%s|%s|%s|%s|" % [sel, dsel, inspect, me, game.cur, str(can_deploy_now()), str(busy), str(my_turn()), str(game.clock_on), str(compact), str(res_drag != null and res_drag.get("on", false)), deploy_block_reason()]
	for pp in range(2):
		s += "%d,%s;" % [game.scarabs_of(pp), str(game.P[pp].get("mix", false))]
	for u in game.units:
		if u.barrier:
			continue
		s += "%d:%s:%d:%d:%d:%d:%s:%s;" % [u.uid, u.st, u.hp, u.maxhp, u.q, u.r, str(u.activated), u.eq]
	return s


func _refresh_party() -> void:
	var psg = _party_signature()
	if psg == party_sig and w.has("party0") and is_instance_valid(w["party0"]) and w["party0"].get_child_count() > 0:
		return
	party_sig = psg
	for p in range(2):
		var box: VBoxContainer = w["party%d" % p]
		for c in box.get_children():
			c.queue_free()
		var col = Color("#4f9be0") if p == me else Color("#e0563f")
		_label(box, ("VOCÊ · " if p == me else (_opp().to_upper() + " · ")) + ("Mix" if game.P[p].get("mix", false) else DB.factions[game.P[p]["fac"]]["short"]), 14, col.lightened(0.4))
		if game.clock_on:
			w["clock%d" % p] = _label(box, "", 18, col)
		var res = []
		var fld = []
		var dead = []
		for u in game.units:
			if u.owner != p or u.barrier:
				continue
			if u.st == "field":
				fld.append(u)
			elif u.st == "dead":
				dead.append(u)
			else:
				res.append(u)
		var dep_ok = p == me and can_deploy_now()
		# escaravelhos verdes (só em mapas que os têm): todos veem a contagem; só o dono usa
		var nsc = game.scarabs_of(p)
		if nsc > 0 or (p == me and DB.maps[game.map_id].has("res") and DB.maps[game.map_id]["res"].any(func(r): return r[2] == "escaravelho")):
			var sp = PanelContainer.new()
			var ssb = StyleBoxFlat.new()
			ssb.bg_color = Color("#0c2a16")
			ssb.border_color = Color("#0a0410")
			ssb.set_border_width_all(3)
			ssb.set_corner_radius_all(2)
			ssb.shadow_color = Color("#2fd66a")
			ssb.shadow_size = 1
			ssb.shadow_offset = Vector2(4, 4)
			ssb.set_content_margin_all(6)
			sp.add_theme_stylebox_override("panel", ssb)
			box.add_child(sp)
			var sv = _vbox(sp, 4)
			var sh = _label(sv, "ESCARAVELHOS · %d" % nsc, 15, Color("#8dff9f"))
			if font_btn != null:
				sh.add_theme_font_override("font", font_btn)
			if p == me:
				var shb = _hbox(sv, 4)
				var b1 = _cbtn(shb, "CURAR +6 ·1", Color("#2fb85a"), func(): _on_scarab("heal"))
				b1.custom_minimum_size = Vector2((_roster_w() - 20) / 2.0, 36)
				b1.add_theme_font_size_override("font_size", 12)
				b1.disabled = not game.can_scarab(p, "heal") or busy or not my_turn()
				b1.tooltip_text = "Gasta 1 escaravelho: uma peça sua restaura 6 de Vida."
				var b2 = _cbtn(shb, "ATIVA +1 ·2", Color("#2fb85a"), func(): _on_scarab("ult"))
				b2.custom_minimum_size = Vector2((_roster_w() - 20) / 2.0, 36)
				b2.add_theme_font_size_override("font_size", 12)
				b2.disabled = not game.can_scarab(p, "ult") or busy or not my_turn()
				b2.tooltip_text = "Gasta 2 escaravelhos: uma peça que já usou a ativa pode usá-la mais uma vez."
				var tl = _label(sv, "Sobrando no fim: +1 de Vida\nno comandante por escaravelho", 10, Color("#a8d8b4"))
				tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				tl.custom_minimum_size = Vector2(_roster_w() - 12, 0)
		# reservas primeiro: é o que o jogador procura para colocar em campo
		if not res.is_empty():
			var hd = PanelContainer.new()
			var ready_n = res.filter(func(x): return x.st == "reserve").size()
			hd.add_theme_stylebox_override("panel", _flat(C_DEPLOY.darkened(0.15) if dep_ok else Color(0.1, 0.14, 0.2, 0.9), C_DEPLOY if dep_ok else Color(0.25, 0.32, 0.4), 1, 6, 5))
			box.add_child(hd)
			var hv = _vbox(hd, 0)
			var t1 = _label(hv, ("PARA ENTRAR · %d" % ready_n) if dep_ok else ("RESERVA · %d" % res.size()), 13, Color("#06201e") if dep_ok else Color("#9fd8e8"))
			if dep_ok:
				_label(hv, "Arraste até \"+ ENTRAR\" (1 ação)", 11, Color("#06201e"))
			elif p == me:
				var why = deploy_block_reason()
				if why != "" and ready_n > 0:
					var wl = _label(hv, why, 11, Color("#8fb8cc"))
					wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					wl.custom_minimum_size = Vector2(_roster_w() - 12, 0)
			t1.add_theme_constant_override("outline_size", 0)
			var grid = GridContainer.new()
			grid.columns = 3
			grid.add_theme_constant_override("h_separation", 3)
			grid.add_theme_constant_override("v_separation", 3)
			box.add_child(grid)
			for u in res:
				grid.add_child(_res_tile(u, p, dep_ok))
		if not fld.is_empty():
			_label(box, "EM CAMPO · %d" % fld.size(), 11, C_DIM)
			for u in fld:
				box.add_child(_field_row(u))
		if not dead.is_empty():
			var names = dead.map(func(x): return _short(x.cid))
			var dl = _label(box, "Caídos: " + ", ".join(names), 11, Color(0.55, 0.58, 0.62))
			dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			dl.custom_minimum_size = Vector2(_roster_w(), 0)


func _roster_w() -> float:
	return 186.0 if compact else 200.0


func _roster_scroll(parent: Control) -> ScrollContainer:
	var sc = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_fat_scroll(sc)
	parent.add_child(sc)
	return sc


# limita a altura das listas para não ficarem embaixo da ficha nem do botão de passar
var fit_t: float = 0.0


func _fit_rosters() -> void:
	var now = Time.get_ticks_msec()
	if now - fit_t < 250:
		return
	fit_t = now
	if not w.has("party0_sc") or not is_instance_valid(w["party0_sc"]):
		return
	var vh = ui.size.y
	var uc: Control = w["ucard"]
	var avail0 = vh - 32.0 - ((uc.size.y + 10.0) if uc.visible else 0.0)
	var avail1 = vh - 64.0 - 24.0 - w["end_panel"].size.y - 56.0
	for pair in [[w["party0_sc"], w["party0"], avail0], [w["party1_sc"], w["party1"], avail1]]:
		var need = pair[1].get_combined_minimum_size()
		var h = clamp(need.y, 60.0, max(60.0, pair[2]))
		var cur: Vector2 = pair[0].custom_minimum_size
		var nw = need.x + (10.0 if need.y > h else 0.0)
		if abs(cur.y - h) > 1.0 or abs(cur.x - nw) > 1.0:
			pair[0].custom_minimum_size = Vector2(nw, h)


func _unit_btn(u, text: String) -> Button:
	var b = Button.new()
	b.text = text
	if DB.portraits.has(u.cid):
		b.icon = DB.portraits[u.cid]
		b.expand_icon = true
	var uid = u.uid
	b.pressed.connect(func(): _on_roster(uid))
	if u.uid == sel or u.uid == dsel or u.uid == inspect:
		b.modulate = Color(1.25, 1.15, 0.7)
	return b


# reserva: retrato grande com o nome embaixo (3 por linha)
func _res_tile(u, p: int, dep_ok: bool) -> Button:
	var off = u.st == "off"
	var b = _unit_btn(u, ("R%d" % Game.CMD_ROUND) if off else _short(u.cid))
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_constant_override("icon_max_width", 50 if compact else 54)
	b.clip_text = true
	b.custom_minimum_size = Vector2((_roster_w() - 6.0) / 3.0, 74 if compact else 78)
	var c = DB.cards[u.cid]
	b.tooltip_text = "%s\nVida %d · Ataque %d · Movimento %d · Alcance %d" % [c["name"], u.maxhp, c.get("atk", 0), c.get("mov", 0), c.get("alc", 1)]
	if off:
		b.tooltip_text += "\nComandante: entra no round %d" % Game.CMD_ROUND
	var ok = dep_ok and not off
	if ok:
		b.add_theme_stylebox_override("normal", _flat(C_DEPLOY.darkened(0.7), C_DEPLOY, 2, 6, 3))
		b.add_theme_stylebox_override("hover", _flat(C_DEPLOY.darkened(0.45), C_DEPLOY.lightened(0.3), 2, 6, 3))
		b.add_theme_color_override("font_color", C_DEPLOY.lightened(0.5))
		b.tooltip_text += "\nClique e escolha uma casa ciano, ou arraste até ela (1 ação)."
		var uid = u.uid
		b.button_down.connect(func(): _start_res_drag(uid))
	else:
		b.add_theme_stylebox_override("normal", _flat(Color(0.06, 0.09, 0.14, 0.9), Color(0.2, 0.26, 0.34), 1, 6, 3))
		if not (u.uid == sel or u.uid == dsel or u.uid == inspect):
			b.modulate = Color(0.75, 0.75, 0.75) if off or p != me else Color(0.9, 0.9, 0.9)
		if p == me and not off:
			b.tooltip_text += "\n" + deploy_block_reason()
	return b


# em campo: uma linha só (retrato, nome, vida e se ainda pode agir)
func _field_row(u) -> Button:
	var used = u.activated
	var b = _unit_btn(u, "%s  %d/%d%s" % [_short(u.cid), max(0, u.hp), u.maxhp, "  · usado" if used else ""])
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_constant_override("icon_max_width", 30)
	b.custom_minimum_size = Vector2(_roster_w(), 42)
	b.tooltip_text = "%s · Vida %d/%d · %s" % [DB.cards[u.cid]["name"], max(0, u.hp), u.maxhp, "já agiu neste round" if used else "pronto para agir"]
	if u.is_cmd:
		b.text = "★ " + b.text
	var hp_frac = float(max(0, u.hp)) / max(1.0, float(u.maxhp))
	var fc = Color("#7fe08a") if hp_frac > 0.6 else (Color("#ffcf5a") if hp_frac > 0.3 else Color("#ff6a5a"))
	b.add_theme_color_override("font_color", fc)
	# barra de vida embaixo do avatar/nome
	var tr = ColorRect.new()
	tr.color = Color(0, 0, 0, 0.55)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.anchor_left = 0.0
	tr.anchor_right = 1.0
	tr.anchor_top = 1.0
	tr.anchor_bottom = 1.0
	tr.offset_left = 4
	tr.offset_right = -4
	tr.offset_top = -8
	tr.offset_bottom = -3
	b.add_child(tr)
	var fl = ColorRect.new()
	fl.color = fc
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.anchor_right = hp_frac
	fl.anchor_bottom = 1.0
	tr.add_child(fl)
	if used and not (u.uid == sel or u.uid == inspect):
		b.modulate = Color(0.62, 0.62, 0.66)
	return b


func _refresh_ucard() -> void:
	var u = sel_unit()
	if u == null and inspect >= 0:
		u = game.by_uid(inspect)
	var txt = ""
	if u != null:
		if u.crystal != "":
			var cfx = {"verde": "cura %d de Vida" % int(game.vrule("green_heal", 2)), "azul": "dá +1 de Movimento no próximo movimento (neste round)", "roxo": "causa %d de dano" % int(game.vrule("purple_dmg", 2))}
			txt = "[b]Cristal %s[/b]\nBloqueia passagem e tiros. Um ataque o quebra (gasta a ação de ataque).\nAo quebrar, %s em TODOS os personagens ao lado, aliados e inimigos." % [u.crystal, cfx.get(u.crystal, "")]
		elif u.barrier:
			txt = "[b]Barreira[/b]\nVida %d/%d\nBloqueia passagem e tiros. Pode ser atacada." % [u.hp, u.maxhp]
		else:
			var c = DB.cards[u.cid]
			var fcol = DB.factions[c["f"]]["color"]
			txt = "[color=%s]%s[/color] · %s\n[font_size=16][b]%s[/b][/font_size]\n" % [fcol, DB.factions[c["f"]]["name"].to_upper(), "Você" if u.owner == me else _opp(), c["name"]]
			txt += "%s\n[b]Vida[/b] %d/%d   [b]Ataque[/b] %d   [b]Movimento[/b] %d   [b]Alcance[/b] %d\n" % [c["role"], max(0, u.hp), u.maxhp, game.atk_of(u, null), game.mov_of(u), game.alc_of(u)]
			if u.st == "field":
				txt += "[i]%s[/i]\n" % game.t_name(u.pos())
			elif u.st == "reserve":
				txt += "[i]Na reserva (arraste para a entrada)[/i]\n"
			elif u.st == "off":
				txt += "[i]Entra no round %d[/i]\n" % Game.CMD_ROUND
			if u.eq != "":
				txt += "Equipado: %s\n" % DB.tactics[u.eq]["name"]
			var abk3 = c["ab"].get("kind", "")
			var passive = "ativa (gasta 1 ação)" if (c["k"].has("action") or abk3 == "ativa") else ("ação especial" if abk3 == "especial" else "passiva (não gasta ação)")
			if abk3 == "ativa" and c["ab"].get("per", "partida") == "round":
				passive = "ativa · 1 ação · recarga %d round(s)" % Game.ABIL_RECHARGE + (" · [color=#ff8a6a]JÁ USADA[/color]" if game.ult_spent(u) else "")
			txt += "[color=#ffab40][b]%s[/b][/color] [color=#8fb8cc](%s)[/color]\n%s" % [c["ab"]["name"], passive, c["ab"]["text"]]
			if c.has("ab2"):
				var a2 = c["ab2"]
				var kind2 = "passiva (não gasta ação)" if a2.get("kind", "") == "passiva" else ("ativa · 1 vez por %s · 1 ação" % a2.get("per", "partida") + (" · [color=#ff8a6a]JÁ USADA[/color]" if game.ult_spent(u) else ""))
				txt += "\n[color=#ffab40][b]★ %s[/b][/color] [color=#8fb8cc](%s)[/color]\n%s" % [a2["name"], kind2, a2["text"]]
			if game.imprisoned(u):
				txt += "\n[color=#9fdcff]Preso na Prisão de Cristal até o fim do próximo round.[/color]"
			elif game.rooted(u):
				txt += "\n[color=#9fdcff]Enraizado: não anda até o fim do próximo round.[/color]"
			if game.slowed(u):
				txt += "\n[color=#9fdcff]Lento: -1 de Movimento neste round.[/color]"
	elif hex_info != null:
		var t = game.terr(hex_info)
		var tt = game.tt_of(t["k"])
		txt = "[b]%s[/b]\nAltura %d · %s\n%s" % [tt["name"], t["h"], ("custo para andar %d" % tt["c"]) if tt.get("pass", 0) else "não dá para entrar", TDESC.get(t["k"], "")]
		var o = DB.obj_at(hex_info)
		if o != null:
			txt += "\n[color=#ffab40]Objetivo %s:[/color] %s" % [o["name"], o["text"]]
		if game.res.has(hex_info):
			var rr = DB.res[game.res[hex_info]]
			txt += "\n[color=#5ec8f0]Recurso %s:[/color] %s (%s)" % [rr["name"], rr["text"], "é coletado ao passar por cima" if game.res[hex_info] == "escaravelho" else "coletar gasta 1 ação"]
		if game.tremors.has(hex_info):
			if game.warn_kind == "raiz":
				txt += "\n[color=#9be85a]Raiz brotando: esta casa vira uma raiz maciça no próximo round (dura 3 rounds).[/color]"
			elif game.warn_kind == "fratura":
				txt += "\n[color=#9fe8ff]Gelo rachado: rompe no próximo round. Quem estiver aqui leva 2 e cai para a borda.[/color]"
			elif game.warn_kind == "avalanche":
				txt += "\n[color=#9fe8ff]Corredor de avalanche: no próximo round quem estiver aqui leva 2 e é empurrado 1 casa.[/color]"
			else:
				txt += "\n[color=#ffb14a]A areia treme: um buraco de verme abre aqui no próximo round.[/color]"
	w["ucard"].visible = txt != ""
	w["ucard_text"].text = txt


func _refresh_actbar() -> void:
	var box: HBoxContainer = w["btns"]
	for c in box.get_children():
		c.queue_free()
	var mine = my_turn()
	var u = sel_or_act() if mine else null
	var note = ""
	var why = []
	if not mine:
		if game.winner != Game.NONE:
			note = "Fim de jogo"
		elif asking != null:
			note = "Responda à pergunta"
		else:
			note = "A CPU está jogando..." if game.cpu[game.cur] else ("O oponente está jogando..." if online else "Aguarde")
	elif dsel >= 0:
		note = "Escolha uma casa CIANO da sua entrada (entrar gasta 1 ação)"
	elif u == null:
		if game.act != null:
			note = "Sem ações restantes: clique em Encerrar"
		elif can_deploy_now():
			note = "1) Clique numa peça sua  —  ou  —  coloque uma reserva numa casa CIANO \"+ ENTRAR\""
		else:
			note = "1) Clique numa peça sua para ativá-la"
	if u != null:
		var live = game.is_live(u)
		var left = game.act["actions"] if live else 2
		var attacked = live and game.act["attacked"]
		var cant = live and game.act["cant_attack"]
		var n_t = game.attack_targets(u).size()
		var moved = live and game.act["moved"]
		var can_mv = left > 0 and not moved and not game.rooted(u) and not game.move_opts(u, game.mov_of(u)).is_empty()
		var can_at = left > 0 and not attacked and not cant and n_t > 0
		note = "%s  ·  Ações: %s  ·  2) escolha o que fazer" % [DB.cards[u.cid]["name"], "●".repeat(left) + "○".repeat(max(0, 2 - left))]
		var bm = _cbtn(box, "Mover" + (" (feito)" if moved else ""), C_MOVE, func(): _set_am("mv"), am == "mv")
		bm.disabled = not can_mv
		bm.tooltip_text = "Mover: 1 ação, no máximo 1 vez por turno. Casas VERDES."
		if game.can_undo() and my_turn():
			var bu = _cbtn(box, "↶ Desfazer", C_HUD, _undo_move)
			bu.tooltip_text = "Volta a peça para onde estava e devolve a ação (Ctrl+Z). Só vale se nada aconteceu no caminho e ela ainda não atacou."
		var ba = _cbtn(box, "Atacar" + (" (feito)" if attacked else ""), C_ATK, func(): _set_am("at"), am == "at")
		ba.disabled = not can_at
		ba.tooltip_text = "Atacar: 1 ação, no máximo 1 vez por turno. Inimigos em VERMELHO."
		var k = game.K(u)
		if k.has("action"):
			var bab = _cbtn(box, DB.cards[u.cid]["ab"]["name"], C_ABIL, func(): _toggle_ab(), ab)
			bab.disabled = left <= 0 or (moved and k.get("action", "") == "tunnel")
			bab.tooltip_text = "Habilidade ativa: 1 ação. Casas com X."
		var act_ab = DB.active_of(u.cid)
		if k.has("ult") and not act_ab.is_empty():
			var ok_ult = (game.can_ult(u) if live else (game.can_start(u) and not game.ult_spent(u) and not game.ult_opts(u).is_empty()))
			var bu = _cbtn(box, "★ " + act_ab["name"], C_ABIL, _on_ult)
			bu.disabled = not ok_ult or left <= 0
			var per2 = act_ab.get("per", "partida")
			bu.tooltip_text = ("Ativa · 1 ação · recarga %d round(s)\n%s" % [Game.ABIL_RECHARGE, act_ab["text"]]) if per2 == "round" else ("Ativa · 1 vez por partida · 1 ação\n%s" % act_ab["text"])
			if game.ult_spent(u):
				why.append("%s: já usada neste %s." % [act_ab["name"], "round" if per2 == "round" else "jogo"])
		if k.has("manip"):
			var ok_mp = game.can_manip(u) if live else game.can_start(u)
			var bmp = _cbtn(box, "◆ Manipulação Mineral", C_ABIL, _on_manip)
			bmp.disabled = not ok_mp or left <= 0
			bmp.tooltip_text = "Ação especial · 1 ação\n" + DB.cards[u.cid]["ab"]["text"]
		if live and game.can_mexit(u):
			var bmx = _cbtn(box, "Entrar no túnel", C_MOVE, _on_mexit)
			bmx.tooltip_text = "Movimento: uma peça aliada ao lado de uma entrada sai pela outra."
		elif not live and game.act == null and game.tunnels.any(func(t): return t["owner"] == u.owner) and game.can_start(u):
			var bmx2 = _cbtn(box, "Entrar no túnel", C_MOVE, _on_mexit)
			bmx2.disabled = game.tunnel_exits(u).is_empty()
		if live and game.can_cart(u):
			var bct = _cbtn(box, "Empurrar carrinho", C_ABIL, _on_cart)
			bct.tooltip_text = "1 ação: o carrinho anda até %d casas no trilho; o primeiro personagem atingido sofre %d e é empurrado." % [int(game.vrule("cart_steps", 3)), int(game.vrule("cart_dmg", 3))]
		if game.res.has(u.pos()) and game.res[u.pos()] != "escaravelho":
			var bc = _button(box, "Pegar " + DB.res[game.res[u.pos()]]["name"].split(" ")[0], _on_collect)
			bc.disabled = left <= 0
		var o = DB.obj_at(u.pos())
		if o != null:
			var bo = _button(box, o["name"], _on_interact)
			bo.disabled = left <= 0 or game.P[u.owner]["obj_used"].has(o["id"])
		if left < 1:
			why.append("Sem ações: o turno passa para o rival.")
		else:
			if not can_mv:
				why.append("Mover: já se moveu neste turno (máx. 1)." if moved else ("Mover: está preso." if game.rooted(u) else "Mover: nenhuma casa livre ao alcance."))
			if not can_at:
				why.append("Atacar: já atacou neste turno (máx. 1)." if attacked else ("Atacar: não pode neste turno." if cant else "Atacar: nenhum inimigo ao alcance."))
	if mine and game.act == null and can_deploy_now():
		var bres = _cbtn(box, "+ Colocar reserva (%d)" % game.reserve_of(me).size(), C_DEPLOY, _pick_first_reserve, dsel >= 0)
		bres.tooltip_text = "Escolhe a primeira reserva; depois clique numa casa ciano da entrada. Para escolher outra, clique no retrato dela à esquerda."
	var tac_ok = false
	if mine:
		tac_ok = _any_card_playable()
	w["note"].text = note
	if w.has("abp"):
		w["abp"].visible = u != null
	w["why"].text = "  ·  ".join(why)
	w["legend"].visible = mine and (u != null or dsel >= 0)
	var e = w["end"]
	var acting = game.act != null and mine
	e.text = "ENCERRAR ATIVAÇÃO" if acting else "PASSAR O ROUND ▶"
	e.disabled = not mine
	var hint = ""
	var pulse = false
	if asking != null:
		hint = "Responda à pergunta"
	elif not mine:
		hint = "Fim de jogo" if game.winner != Game.NONE else ("Vez do " + _opp().to_lower())
	elif acting:
		pulse = game.act["actions"] <= 0
		hint = "Sem ações: encerre" if pulse else "Termina a vez desta peça"
	else:
		var idle = game.field().filter(func(x): return x.owner == me and not x.barrier and game.can_start(x)).is_empty()
		pulse = idle and not can_deploy_now()
		hint = "Todas as suas peças já agiram" if idle else "Quando não quiser ativar mais peças"
	w["end_hint"].text = hint
	if mine:
		_primary(e)
	else:
		_style_btn(e, C_END, false)
	e.set_meta("pulse", pulse)


func _refresh_prompt() -> void:
	for bx in [w["prompt_btns"], w["ask_btns"]]:
		for c in bx.get_children():
			c.queue_free()
	var text = ""
	var is_mull = asking != null and asking["q"].get("kind", "") == "mulligan"
	var big = asking != null and not is_mull
	var box: HBoxContainer = w["ask_btns"] if big else w["prompt_btns"]
	if is_mull:
		_show_mull(asking["q"]["show"])
	else:
		_hide_mull()
	if asking != null and not is_mull:
		var q = asking["q"]
		text = "[b]%s[/b]" % q.get("text", "")
		match q["t"]:
			"hex":
				text += "\n[color=#8fb8cc](clique numa casa com [color=#b06cff][b]X[/b][/color])[/color]"
				if q.get("optional", false):
					_button(box, "Pular", func(): _answer(null))
			"yesno":
				if q.has("show"):
					text += "\n" + _cards_text(q["show"])
				var mull = q.get("kind", "") == "mulligan"
				var ea = q.get("kind", "") == "earth"
				_button(box, "Manter a mão" if mull else ("▼ Descer" if ea else "Não"), func(): _answer(false))
				_button(box, "Trocar a mão" if mull else ("▲ Subir" if ea else "Sim"), func(): _answer(true))
			"card":
				for id in q["opts"]:
					var cid = id
					var bt = _button(box, DB.tactics[id]["name"], func(): _answer(cid))
					bt.tooltip_text = DB.tactics[id]["text"]
				if q.get("optional", false):
					_button(box, "Não usar", func(): _answer(null))
			"peek":
				text += "\n" + _cards_text([q["card"]])
				_button(box, "Mandar para o fundo", func(): _answer("bottom"))
				_button(box, "Manter no topo", func(): _answer("keep"))
			"show":
				text += "\n" + (_cards_text(q["cards"]) if not q["cards"].is_empty() else "A mão está vazia.")
				_button(box, "Fechar", func(): _answer(true))
			"choice":
				for i in range(q["opts"].size()):
					var ii = i
					var bt2 = _button(box, q["opts"][i], func(): _answer(ii))
					bt2.custom_minimum_size = Vector2(0, 40)
			"unitlist":
				for uid in q["opts"]:
					var u2 = game.by_uid(uid)
					var id2 = uid
					_button(box, DB.cards[u2.cid]["name"], func(): _answer(id2))
	elif dsel >= 0 and my_turn():
		text = "Escolha uma casa [color=#22d3c5][b]CIANO[/b][/color] da sua entrada para [b]%s[/b]." % DB.cards[game.by_uid(dsel).cid]["name"]
		_button(box, "Cancelar", _cancel_dsel)
	elif pend != null and my_turn() and sel_unit() != null:
		var u = sel_unit()
		var nm_u = DB.cards[u.cid]["name"]
		if pend["kind"] == "move" or pend["kind"] == "moveatk":
			text = "Prévia: [b]%s[/b] vai para %s gastando %d de %d de movimento · 1 ação." % [nm_u, game.t_name(pend["h"]), pend["cost"], game.mov_of(u)]
		if pend["kind"] == "attack" or pend["kind"] == "moveatk":
			var t = game.by_uid(pend["tuid"])
			var pv = game.preview_damage(u, t, pend["h"] if pend["kind"] == "moveatk" else null)
			var res_txt = " (derrota o alvo)" if pv["kills"] else " (fica com %d de Vida)" % (t.hp - pv["dmg"])
			text += ("\nDepois ataca " if text != "" else "Prévia: [b]%s[/b] ataca " % nm_u) + "[b]%s[/b]: %s = [color=#ffb14a][b]%d de dano[/b][/color]%s. Reações do rival podem reduzir." % [game.nm(t), " ".join(pv["parts"]), pv["dmg"], res_txt]
		if pend["kind"] == "ab":
			text = "Prévia: [b]%s[/b] para a casa marcada · 1 ação." % DB.cards[u.cid]["ab"]["name"]
		var n = 2 if pend["kind"] == "moveatk" else 1
		_cbtn(box, "Cancelar", C_END, _cancel_pend)
		_cbtn(box, "3) Confirmar (%d %s)" % [n, "ações" if n > 1 else "ação"], C_GOLD, _confirm_pend, true)
	elif ab and my_turn() and sel_or_act() != null:
		text = "Túnel: escolha uma casa livre a até 3." if game.K(sel_or_act()).get("action", "") == "tunnel" else "Escolha para onde mover (ou a própria casa); depois escolha o alvo."
		_button(box, "Cancelar", _cancel_ab)
	elif tip != null and my_turn():
		text = "[color=#ffb08a][b]Por quê?[/b][/color] " + tip["l"]
		_button(box, "Ok", _clear_tip)
	if big:
		_show_ask(text, asking["q"])
	else:
		_hide_ask()
		w["prompt"].visible = text != ""
		w["prompt_text"].text = text


# mostra a pergunta no centro; se for para clicar numa casa, sobe para não cobrir o tabuleiro
func _show_ask(text: String, q: Dictionary) -> void:
	w["prompt"].visible = false
	w["note"].get_parent().get_parent().visible = false
	var ask: PanelContainer = w["ask"]
	var on_board = q["t"] == "hex"
	var y = 0.2 if on_board else 0.5
	ask.anchor_top = y
	ask.anchor_bottom = y
	w["ask_dim"].visible = not on_board
	w["ask_head"].text = "ESCOLHA NO TABULEIRO" if on_board else "SUA DECISÃO"
	w["ask_text"].text = "[center]" + text + "[/center]"
	var nb = 0
	for b in w["ask_btns"].get_children():
		if b is Button and not b.is_queued_for_deletion():
			if nb == 0 and q["t"] != "hex":
				_primary(b)
			nb += 1
			b.custom_minimum_size = Vector2(max(130.0, b.custom_minimum_size.x), 50)
			b.add_theme_font_size_override("font_size", 18)
	var first = not ask.visible or ask.get_meta("q", null) != q
	ask.set_meta("q", q)
	ask.visible = true
	ask.reset_size()
	ask.offset_left = -ask.size.x / 2.0
	ask.offset_right = ask.size.x / 2.0
	ask.offset_top = -ask.size.y / 2.0
	ask.offset_bottom = ask.size.y / 2.0
	if first:
		_recenter_ask.call_deferred()
		ask.pivot_offset = ask.size / 2.0
		ask.scale = Vector2(0.85, 0.85)
		ask.modulate.a = 0.0
		var tw = create_tween().set_parallel(true)
		tw.tween_property(ask, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(ask, "modulate:a", 1.0, 0.18)
		sfx.play("carta", -8.0)


func _recenter_ask() -> void:
	if not w.has("ask") or not is_instance_valid(w["ask"]):
		return
	var ask: PanelContainer = w["ask"]
	ask.reset_size()
	ask.offset_left = -ask.size.x / 2.0
	ask.offset_right = ask.size.x / 2.0
	ask.offset_top = -ask.size.y / 2.0
	ask.offset_bottom = ask.size.y / 2.0
	ask.pivot_offset = ask.size / 2.0


func _hide_ask() -> void:
	if w.has("ask") and is_instance_valid(w["ask"]):
		w["ask"].visible = false
		w["ask"].set_meta("q", null)
		w["note"].get_parent().get_parent().visible = true
		w["ask_dim"].visible = false


func _pick_first_reserve() -> void:
	var rs = game.reserve_of(0)
	if rs.is_empty() or not can_deploy_now():
		return
	dsel = rs[0].uid
	sel = -1
	pend = null
	am = ""
	ab = false
	refresh()


func _cancel_dsel() -> void:
	dsel = -1
	refresh()


func _cancel_pend() -> void:
	pend = null
	refresh()


func _cancel_ab() -> void:
	ab = false
	refresh()


func _clear_tip() -> void:
	tip = null
	refresh()


func _cards_text(ids: Array) -> String:
	var parts = []
	for id in ids:
		parts.append("[color=#ffab40]%s[/color] (%s): %s" % [DB.tactics[id]["name"], DB.tactics[id]["type"], DB.tactics[id]["text"]])
	return "\n".join(parts)


func _refresh_side() -> void:
	if not w.has("side"):
		return
	w["side"].visible = panel_open != ""
	if panel_open == "":
		return
	var body: VBoxContainer = w["side_body"]
	for c in body.get_children():
		c.queue_free()
	match panel_open:
		"cards":
			var pl = game.P[me]
			w["side_title"].text = "Suas cartas · %d na mão · baralho %d" % [pl["hand"].size(), pl["deck"].size()]
			_label(body, "Jogar uma carta gasta 1 ação (reações são oferecidas sozinhas no turno do rival).", 13, Color("#8fb8cc"))
			for id in pl["hand"]:
				var t = DB.tactics[id]
				var row = _hbox(body, 8)
				var r = _rich(row, 420)
				r.text = "[color=#ffab40][b]%s[/b][/color]  [color=#8fb8cc]%s · custo %d[/color]\n%s" % [t["name"], t["type"], t["cost"], t["text"]]
				var ok = _card_playable(id)
				var cid = id
				var b = _button(row, "Jogar", func(): _play_card(cid))
				b.disabled = not ok
		"log":
			w["side_title"].text = "Registro"
			var r2 = _rich(body, 580)
			var lines = []
			var start = max(0, game.logs.size() - 80)
			for i in range(start, game.logs.size()):
				var l = game.logs[i]
				var col = "#ffab40" if l["p"] < 0 else ("#7cc0ff" if l["p"] == me else "#ff8a6a")
				lines.append("[color=%s]•[/color] %s" % [col, l["text"]])
			r2.text = "\n".join(lines)
		"rules":
			w["side_title"].text = "Regras e controles"
			var r3 = _rich(body, 580)
			r3.text = RULES


# ================= cartas =================
const TYPE_COL = {"Manobra": Color("#4cd964"), "Comando": Color("#4da3ff"), "Equipamento": Color("#ffab40"), "Reação": Color("#5fd6e8")}


# o que a carta afeta: texto curto + casas para destacar no tabuleiro
func _card_targets(id: String) -> Dictionary:
	var u = sel_or_act() if game != null else null
	var hs = []
	var txt = ""
	match id:
		"flanquear":
			txt = "Mapa: o ativo anda 1 casa"
			if u != null:
				hs = game.step_free(u.pos())
		"retirada":
			txt = "Reação: após atacar, recua 1 casa"
			if u != null:
				hs = game.step_free(u.pos())
		"troca":
			txt = "Ativo + aliado ao lado trocam de lugar"
			if u != null:
				for x in game.allies_of(u):
					if DB.dist(x.pos(), u.pos()) == 1:
						hs.append(x.pos())
		"avanco":
			txt = "Até 2 aliados andam 1 casa"
			for x in game.field():
				if x.owner == me and not x.barrier:
					hs.append(x.pos())
		"cobertura":
			txt = "Reação: aliado atacado de longe sofre -3"
		"escudo":
			txt = "Reação: aliado atacado de perto sofre -2"
		"dispersao":
			txt = "Reação: aliado atacado recua 1 casa"
		"propulsor":
			txt = "Seu personagem (arraste): +1 Movimento"
		"placas":
			txt = "Seu personagem (arraste): -1 dano recebido"
		"lente":
			txt = "Seu personagem (arraste): +1 Alcance"
		"reparo":
			txt = "Seu personagem (arraste): +4 de Vida"
		"fogo":
			txt = "Personagem ativo: +2 dano no ataque"
		"dados":
			txt = "Sua mão: compra 2, descarta 1"
		"reforco":
			txt = "Reserva que entrar: chega com 2 ações"
			hs = game.deploy_hexes(me)
		"pulso":
			txt = "Inimigo a até 2 casas perde o equipamento"
			if u != null:
				for x in game.enemies_of(u):
					if x.eq != "" and DB.dist(x.pos(), u.pos()) <= 2:
						hs.append(x.pos())
		"granada":
			txt = "Inimigos numa área: 1 de dano cada"
			if u != null:
				hs = game.granada_opts(u)
		"sinalizador":
			txt = "Inimigo marcado: +1 dano contra ele"
			if u != null:
				for x in game.enemies_of(u):
					if DB.dist(x.pos(), u.pos()) <= 4 and game.los(u.pos(), x.pos()):
						hs.append(x.pos())
		"adrenalina":
			txt = "Ativo: -1 Vida, +1 ação"
		"barreira":
			txt = "Casa ao lado: barreira de 3 Vida"
			if u != null:
				hs = game.adj_free(u.pos())
		"gancho":
			txt = "Inimigo a até 3: puxado 1 casa"
			if u != null:
				for x in game.gancho_targets(u):
					hs.append(x.pos())
		"camuflagem":
			txt = "Seu personagem (arraste): não pode ser atacado no round"
		"onda":
			txt = "Inimigos ao lado: empurrados 1 casa"
			if u != null:
				for x in game.enemies_of(u):
					if DB.dist(x.pos(), u.pos()) == 1:
						hs.append(x.pos())
		"orbital":
			txt = "Inimigo a até 5: 3 de dano"
			if u != null:
				for x in game.enemies_of(u):
					if DB.dist(x.pos(), u.pos()) <= 5:
						hs.append(x.pos())
		"kit":
			txt = "Ativo e aliados a até 2: +2 Vida"
			if u != null:
				for x in game.allies_of(u, true):
					if DB.dist(x.pos(), u.pos()) <= 2:
						hs.append(x.pos())
		"ultimo":
			txt = "Ativo ferido (metade da Vida): +3 dano no ataque"
		"revide":
			txt = "Reação: aliado atacado de perto devolve 2 de dano"
		"resgate":
			txt = "Ativo troca de lugar com aliado a até 4"
			if u != null:
				for x in game.allies_of(u):
					if not x.barrier and DB.dist(x.pos(), u.pos()) <= 4:
						hs.append(x.pos())
		"quantica":
			txt = "Um aliado e um inimigo a até 3 trocam de lugar"
			if u != null:
				for x in game.quantica_allies(u) + game.quantica_enemies(u):
					hs.append(x.pos())
		"interceptar":
			txt = "Rouba 1 carta aleatória do oponente"
		"grito":
			txt = "Todos os seus em campo: +1 ATQ no round"
			if u != null:
				for x in game.allies_of(u, true):
					if not x.barrier:
						hs.append(x.pos())
		"evacuacao":
			txt = "Último aliado derrotado volta à reserva"
		"execucao":
			txt = "Inimigo ao lado com até 3 de Vida cai na hora"
			if u != null:
				for x in game.execucao_targets(u):
					hs.append(x.pos())
		"contra":
			txt = "Se estiver em desvantagem: +1 ação e 1 carta"
		"rede":
			txt = "Inimigo a até 3 não se move até o próximo round"
			if u != null:
				for x in game.rede_targets(u):
					hs.append(x.pos())
	if hs.is_empty() and u != null and ["propulsor", "placas", "lente", "reparo", "fogo", "adrenalina", "camuflagem", "ultimo", "contra"].has(id):
		hs = [u.pos()]
	return {"txt": txt, "hexes": hs}


func _with_card_hover(st: Dictionary) -> Dictionary:
	if card_hover == "" or game == null:
		return st
	var st2 = st.duplicate(true)
	var dragging = card_drag != null and card_drag["on"]
	var hs = _drop_hexes(card_hover) if dragging else _card_targets(card_hover)["hexes"]
	var col: Color = TYPE_COL.get(DB.tactics[card_hover]["type"], Color("#e0c8ff"))
	for h in hs:
		st2["hl"][h] = "pk"
		st2["labels"][h] = "solte aqui" if dragging else "carta"
		st2["label_colors"][h] = col.lightened(0.3)
	return st2


# casas onde a carta pode ser solta agora (calcula com a peça selecionada se ainda não há ativação)
func _drop_hexes(id: String) -> Array:
	if game == null or not my_turn():
		return []
	if game.act != null:
		return game.drop_opts(game.cur, id)
	var u = sel_unit()
	if u == null or not game.can_start(u):
		return []
	game.act = game._new_act(u, 2, false)
	var hs = game.drop_opts(game.cur, id)
	if hs.is_empty():
		hs = [u.pos()]
	game.act = null
	return hs


func _card_hover_set(id: String, card: Control, on: bool) -> void:
	if card_drag != null and card_drag["on"]:
		return
	card_hover = id if on else ""
	card.pivot_offset = Vector2(card.size.x / 2.0, card.size.y)
	var tw = create_tween()
	tw.tween_property(card, "scale", Vector2(1.35, 1.35) if on else Vector2.ONE, 0.12)
	card.z_index = 10 if on else 0
	if game != null:
		board.set_state(_with_card_hover(last_st))


func _refresh_hand() -> void:
	if not w.has("hand"):
		return
	var box: HBoxContainer = w["hand"]
	if game == null:
		for c in box.get_children():
			c.queue_free()
		return
	var pl = game.P[me]
	var hsg = "%s|%d|%s|%s|" % [str(my_turn()), pl["deck"].size(), str(compact), str(game.act != null)]
	for id in pl["hand"]:
		hsg += "%s:%s:%s;" % [id, str(_card_playable(id)), _card_targets(id)["txt"]]
	if hsg == hand_sig and box.get_child_count() > 0:
		return
	hand_sig = hsg
	for c in box.get_children():
		c.queue_free()
	for id in pl["hand"]:
		box.add_child(_make_card(id))
	var info = _label(box, "  Baralho\n  %d" % pl["deck"].size(), 13, C_TXT)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _make_card(id: String) -> Control:
	var t = DB.tactics[id]
	var col: Color = TYPE_COL.get(t["type"], C_CARD)
	var ok = _card_playable(id)
	var react = t["type"] == "Reação" or id == "retirada" or id == "reforco"
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(118, 150) if compact else Vector2(128, 172)
	# moldura de HQ por tipo (tools/cartas_hq.py): faixa do tipo, retícula e sombra dura
	var fpath = "res://ui/cartas/carta_%s.png" % t["type"].to_lower().replace("ç", "c").replace("ã", "a")
	if ResourceLoader.exists(fpath):
		var fs = StyleBoxTexture.new()
		fs.texture = load(fpath)
		fs.content_margin_left = 7
		fs.content_margin_right = 13
		fs.content_margin_top = 2
		fs.content_margin_bottom = 12
		card.add_theme_stylebox_override("panel", fs)
	else:
		card.add_theme_stylebox_override("panel", _tex_box("res://ui/card.png", 20, col if (ok or react) else col.darkened(0.55), 9, 7))
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	# na faixa cabe só o tipo; o custo aparece apenas quando a carta gasta ação
	var cost = _label(v, t["type"].to_upper() + ((" · %d AÇÃO" % int(t["cost"])) if int(t["cost"]) > 0 else ""), 10, Color("#0a0410"))
	cost.add_theme_constant_override("outline_size", 0)
	if font_btn != null:
		cost.add_theme_font_override("font", font_btn)
	if compact:
		cost.add_theme_font_size_override("font_size", 10)
	cost.clip_text = true
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# selo de explosão na cor do tipo, com o ícone em tinta por cima
	var ih = 46 if compact else 58
	var iw = Control.new()
	iw.custom_minimum_size = Vector2(0, ih + 4)
	iw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(iw)
	var own_ic = ResourceLoader.exists("res://ui/cartas/ic/%s.png" % id)
	if not own_ic and ResourceLoader.exists("res://ui/cartas/estouro.png"):
		var bst = TextureRect.new()
		bst.texture = load("res://ui/cartas/estouro.png")
		bst.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bst.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bst.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bst.modulate = col.lightened(0.2)
		bst.mouse_filter = Control.MOUSE_FILTER_IGNORE
		iw.add_child(bst)
	var ic = TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# ícone colorido próprio (adesivo pop) ocupa o selo inteiro; o antigo fica dentro do estouro
	ic.offset_top = -ih * 0.12 if own_ic else ih * 0.22
	ic.offset_bottom = ih * 0.04 if own_ic else -ih * 0.22
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ipath = "res://ui/cartas/ic/%s.png" % id
	if not ResourceLoader.exists(ipath):
		ipath = "res://ui/icons/%s.png" % id
	if ResourceLoader.exists(ipath):
		ic.texture = load(ipath)
	iw.add_child(ic)
	var nm = _label(v, t["name"], 13 if compact else 11, Color.WHITE)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font_btn != null:
		nm.add_theme_font_override("font", font_btn)
	var tg = _card_targets(id)
	var af = _label(v, tg["txt"], 10, col.lightened(0.75))
	if compact:
		af.add_theme_font_size_override("font_size", 11)
	af.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	af.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	af.custom_minimum_size = Vector2(104, 0)
	af.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var why_not = ""
	if react:
		why_not = "Esta carta é usada sozinha no momento certo (o jogo pergunta)."
	elif not ok:
		why_not = "Agora não dá: selecione uma peça sua que ainda pode agir e tenha ação sobrando." if my_turn() else "Espere a sua vez."
	card.tooltip_text = "%s (%s · %s)\n%s\nAFETA: %s%s" % [t["name"], t["type"], ("custa %d ação" % int(t["cost"])) if int(t["cost"]) > 0 else "grátis", t["text"], tg["txt"], ("\n" + why_not) if why_not != "" else ""]
	if not ok and not react:
		card.modulate = Color(0.75, 0.75, 0.8)
	card.mouse_entered.connect(_card_hover_set.bind(id, card, true))
	card.mouse_exited.connect(_card_hover_set.bind(id, card, false))
	card.gui_input.connect(_card_input.bind(id))
	return card


func _card_input(ev: InputEvent, id: String) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if _card_playable(id):
			# segurar e arrastar: solta no personagem; só tocar: usa como antes
			card_drag = {"id": id, "start": get_viewport().get_mouse_position(), "on": false}
		else:
			sfx.play("clique", -10.0, 0.7)
func _card_playable(id: String) -> bool:
	if not my_turn():
		return false
	if game.act != null:
		return game.tactic_playable(game.cur, id)
	var u = sel_unit()
	if u == null or not game.can_start(u):
		return false
	game.act = game._new_act(u, 2, false)
	var ok = game.tactic_playable(game.cur, id)
	game.act = null
	return ok


func _any_card_playable() -> bool:
	for id in game.P[me]["hand"]:
		if _card_playable(id):
			return true
	return false


func _play_card(id: String, drop: Variant = null) -> void:
	if not _card_playable(id):
		return
	panel_open = ""
	if game.act == null:
		game.start_activation(sel_unit())
	busy = true
	refresh()
	await game.play_tactic(game.cur, id, drop)
	busy = false
	await after()


# ================= ações do jogador =================
func _set_am(v: String) -> void:
	am = "" if am == v else v
	ab = false
	pend = null
	refresh()


func _toggle_ab() -> void:
	ab = not ab
	am = ""
	pend = null
	refresh()


func _on_cart() -> void:
	var u = sel_or_act()
	if u == null or not my_turn():
		return
	pend = null
	am = ""
	ab = false
	busy = true
	refresh()
	await game.act_cart(u)
	busy = false
	await after()


func _on_manip() -> void:
	var u = sel_or_act()
	if u == null or not my_turn():
		return
	if game.act == null and game.can_start(u):
		game.start_activation(u)
	pend = null
	am = ""
	ab = false
	busy = true
	refresh()
	await game.act_manip(u)
	busy = false
	await after()


func _on_mexit() -> void:
	var u = sel_or_act()
	if u == null or not my_turn():
		return
	if game.act == null and game.can_start(u):
		game.start_activation(u)
	pend = null
	am = ""
	ab = false
	busy = true
	refresh()
	await game.act_mexit(u)
	busy = false
	await after()


func _on_ult() -> void:
	var u = sel_or_act()
	if u == null or not my_turn():
		return
	if game.act == null and game.can_start(u):
		game.start_activation(u)
	pend = null
	am = ""
	ab = false
	busy = true
	refresh()
	await game.act_ult(u)
	busy = false
	await after()


func _on_scarab(mode: String) -> void:
	if not my_turn() or busy:
		return
	busy = true
	refresh()
	await game.act_scarab(me, mode)
	busy = false
	await after()


func _on_collect() -> void:
	var u = sel_or_act()
	if u == null or not my_turn():
		return
	if game.act == null and game.can_start(u):
		game.start_activation(u)
	pend = null
	busy = true
	await game.act_collect(u)
	busy = false
	await after()


func _on_interact() -> void:
	var u = sel_or_act()
	if u == null or not my_turn():
		return
	if game.act == null and game.can_start(u):
		game.start_activation(u)
	busy = true
	await game.act_interact(u)
	busy = false
	await after()


func _on_end_pressed() -> void:
	if not my_turn():
		return
	if game.act != null:
		ab = false
		pend = null
		busy = true
		await game.end_activation()
		busy = false
		sel = -1
		await after()
	else:
		sel = -1
		pend = null
		dsel = -1
		busy = true
		await game.pass_turn(game.cur)
		busy = false
		await after()


func _on_roster(uid: int) -> void:
	if res_drag != null and res_drag["on"]:
		return
	var u = game.by_uid(uid)
	if u == null:
		return
	pend = null
	tip = null
	if u.st == "reserve" and my_turn() and game.act == null and u.owner == game.cur and not game.deploy_hexes(game.cur).is_empty():
		dsel = u.uid
		sel = -1
	elif u.st == "field" and game.act == null and game.can_start(u):
		if sel != u.uid:
			am = ""
			ab = false
		sel = u.uid
		dsel = -1
		inspect = -1
	else:
		inspect = u.uid
		if game.act == null:
			sel = -1
		if u.st == "reserve" and my_turn() and u.owner == game.cur:
			if game.act != null:
				tip = {"l": "Uma peça por turno: termine as ações da peça atual antes de colocar uma reserva em campo."}
			else:
				tip = {"l": "Sua entrada está ocupada ou bloqueada. Tire uma peça das casas de entrada para abrir espaço."}
	refresh()


func _confirm_pend() -> void:
	if sfx != null:
		sfx.play("confirmar", -8.0, 1.0, 0.0)
	var p = pend
	var u = sel_unit()
	pend = null
	if p == null or u == null or not my_turn():
		refresh()
		return
	if not game.is_live(u):
		if not game.can_start(u):
			refresh()
			return
		game.start_activation(u)
	busy = true
	refresh()
	match p["kind"]:
		"move":
			await game.act_move(u, p["h"])
		"attack":
			await game.act_attack(u, game.by_uid(p["tuid"]))
		"moveatk":
			await game.act_move(u, p["h"])
			var t = game.by_uid(p["tuid"])
			if t != null and t.st == "field" and u.st == "field" and game.winner == Game.NONE:
				await game.act_attack(u, t)
		"ab":
			ab = false
			if game.K(u).get("action", "") == "tunnel":
				await game.act_tunnel(u, p["h"])
			else:
				await game.act_move_attack(u, p["h"], null)
	busy = false
	await after()


func after() -> void:
	if game == null:
		return
	pend = null
	am = ""
	tip = null
	if game.act != null and game.winner == Game.NONE and not game.cpu[game.act["p"]] and game.act["p"] == me and not game.can_undo() and game.act["actions"] <= 0 and not _any_hand_playable_now():
		ab = false
		busy = true
		await get_tree().create_timer(0.35).timeout
		await game.end_activation()
		busy = false
		sel = -1
	refresh()
	if game.winner != Game.NONE:
		_game_over()
		return
	if running:
		return
	running = true
	while game != null and game.winner == Game.NONE and game.cpu[game.cur]:
		busy = true
		refresh()
		await get_tree().create_timer(0.5).timeout
		if tut:
			# no tutorial o adversário só passa a vez
			await game.pass_turn(game.cur)
			continue
		await AI.activation(game, game.cur)
	if game == null:
		return
	busy = false
	running = false
	refresh()
	if game.winner != Game.NONE:
		_game_over()
		return
	_net_pump()


func _any_hand_playable_now() -> bool:
	for id in game.P[game.act["p"]]["hand"]:
		if game.tactic_playable(game.act["p"], id):
			return true
	return false


# ================= tabuleiro: toques e arraste =================
func _on_hex_tapped(h) -> void:
	if game == null:
		return
	if asking != null and asking["q"]["t"] == "hex":
		if asking["q"]["opts"].has(h):
			_answer(h)
		return
	tip = null
	var at = game.unit_at(h)
	if not my_turn():
		inspect = at.uid if at != null else -1
		hex_info = null if at != null else h
		refresh()
		return
	if dsel >= 0:
		if game.deploy_hexes(game.cur).has(h):
			var du = game.by_uid(dsel)
			dsel = -1
			busy = true
			refresh()
			await game.deploy(du, h)
			busy = false
			sel = du.uid
			await after()
		else:
			dsel = -1
			refresh()
		return
	var u = sel_unit()
	if u != null and u.owner == game.cur and u.st == "field":
		var live = game.is_live(u)
		if ab and (live or game.can_start(u)):
			var H0 = highlights()
			if H0["pk"].has(h):
				pend = {"kind": "ab", "h": h}
				refresh()
				return
			ab = false
			pend = null
			refresh()
			return
		if live or game.can_start(u):
			var H = highlights()
			var pm = _pend_move()
			if at != null and H["at"].has(h):
				# modo rápido: no PC ataca no clique (a prévia já apareceu ao apontar);
				# no toque, o 1º toque mostra a prévia e o 2º ataca
				var again = pend != null and pend.get("tuid", -1) == at.uid and not pend_hover
				if pm != null:
					pend = {"kind": "moveatk", "h": pm["h"], "cost": pm["cost"], "tuid": at.uid}
				else:
					pend = {"kind": "attack", "tuid": at.uid}
				pend_hover = false
				if fast_mode and (again or not _is_touch()):
					_confirm_pend()
					return
				refresh()
				return
			for m in H["mv"]:
				if m["h"] == h:
					pend = {"kind": "move", "h": h, "cost": m["c"]}
					pend_hover = false
					if fast_mode:
						_confirm_pend()
						return
					refresh()
					return
			if pend != null and (h == u.pos() or (pm != null and h == pm["h"])):
				pend = null
				refresh()
				return
			if h != u.pos() and not (at != null and at.owner == u.owner):
				if at != null and at.owner != u.owner:
					var wn = game.why_no_attack(u, at, pm["h"] if pm != null else null)
					tip = wn
				else:
					tip = {"l": game.why_no_move(u, h), "hex": h}
				refresh()
				return
	pend = null
	if at != null and game.act == null and game.can_start(at):
		if sel != at.uid:
			am = ""
			ab = false
		sel = at.uid
		inspect = -1
	else:
		if game.act == null:
			sel = -1
		inspect = at.uid if at != null else -1
	hex_info = null if at != null else h
	refresh()


func _on_unit_drag_started(uid: int) -> void:
	if sel != uid:
		am = ""
		ab = false
	sel = uid
	dsel = -1
	inspect = -1
	pend = null
	tip = null
	refresh()


func _on_unit_dropped(uid: int, h) -> void:
	var u = game.by_uid(uid)
	if h == null or u == null or h == u.pos():
		pend = null
		refresh()
		return
	_on_hex_tapped(h)


func _start_res_drag(uid: int) -> void:
	var u = game.by_uid(uid)
	if u == null or not my_turn() or game.act != null or game.deploy_hexes(game.cur).is_empty():
		return
	res_drag = {"uid": uid, "start": get_viewport().get_mouse_position(), "on": false}


func _input(event: InputEvent) -> void:
	if game == null:
		return
	if card_drag != null:
		if event is InputEventMouseMotion:
			var mp = (event as InputEventMouseMotion).position
			if not card_drag["on"] and mp.distance_to(card_drag["start"]) > 10.0:
				card_drag["on"] = true
				card_hover = card_drag["id"]
				var ipath = "res://ui/icons/%s.png" % card_drag["id"]
				w["drag_icon"].texture = load(ipath) if ResourceLoader.exists(ipath) else null
				w["drag_icon"].modulate = TYPE_COL.get(DB.tactics[card_drag["id"]]["type"], C_CARD)
				w["drag_icon"].visible = true
				w["drag_icon"].size = Vector2(96, 96)
				w["drag_icon"].z_index = 50
				for cc in w["hand"].get_children():
					cc.scale = Vector2.ONE
					cc.z_index = 0
				board.set_state(_with_card_hover(last_st))
			if card_drag["on"]:
				w["drag_icon"].position = mp - Vector2(48, 48)
		elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var cd = card_drag
			card_drag = null
			w["drag_icon"].visible = false
			w["drag_icon"].modulate = Color.WHITE
			w["drag_icon"].size = Vector2(70, 70)
			card_hover = ""
			if not cd["on"]:
				_play_card(cd["id"])
			else:
				get_viewport().set_input_as_handled()
				var h = board.pick_hex((event as InputEventMouseButton).position)
				if h != null and _drop_hexes(cd["id"]).has(h):
					_play_card(cd["id"], h)
				else:
					sfx.play("clique", -8.0, 0.7)
					board.set_state(last_st)
	if res_drag != null:
		if event is InputEventMouseMotion:
			var pos = (event as InputEventMouseMotion).position
			if not res_drag["on"] and pos.distance_to(res_drag["start"]) > 8.0:
				res_drag["on"] = true
				dsel = res_drag["uid"]
				sel = -1
				var cid = game.by_uid(res_drag["uid"]).cid
				w["drag_icon"].texture = DB.portraits.get(cid, null)
				w["drag_icon"].visible = true
				refresh()
			if res_drag["on"]:
				w["drag_icon"].position = pos - Vector2(35, 45)
		elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var was_on = res_drag["on"]
			res_drag = null
			w["drag_icon"].visible = false
			if was_on:
				get_viewport().set_input_as_handled()
				var h = board.pick_hex((event as InputEventMouseButton).position)
				if h != null:
					_on_hex_tapped(h)
				else:
					dsel = -1
					refresh()
	if event is InputEventKey and event.pressed:
		var ke = event as InputEventKey
		if ke.keycode == KEY_ENTER and pend != null and asking == null:
			_confirm_pend()
		elif ke.keycode == KEY_Z and ke.ctrl_pressed:
			_undo_move()
		elif ke.keycode == KEY_ESCAPE:
			if pend != null:
				pend = null
			elif ab:
				ab = false
			elif dsel >= 0:
				dsel = -1
			elif panel_open != "":
				panel_open = ""
			tip = null
			refresh()


# ================= perguntas do motor =================
func _on_question(p: int, q: Dictionary) -> void:
	if game.remote[p]:
		opp_thinking = true
		refresh()
		return
	asking = {"p": p, "q": q}
	refresh()


func _answer(v) -> void:
	if asking == null:
		return
	asking = null
	refresh()
	game.answered.emit(v)


# ================= efeitos =================
func _unit_pos(uid: int, lift: float = 0.9) -> Variant:
	if board.unit_nodes.has(uid):
		return board.unit_nodes[uid]["node"].position + Vector3(0, lift, 0)
	var u: Variant = game.by_uid(uid) if game != null else null
	if u != null and u.st == "field":
		return _hex_pos(u.pos(), lift)
	return null


# ================= estouro de quadrinho (onomatopeia) =================
const POP_COLS = [Color("#ffe14d"), Color("#ff3ea5"), Color("#29f0ff"), Color("#b05cff"), Color("#7dff5a")]


func _star_pts(r_out: float, r_in: float, n: int, seed_v: int) -> PackedVector2Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_v
	var pts = PackedVector2Array()
	for i in range(n * 2):
		var a = TAU * i / (n * 2) + rng.randf_range(-0.08, 0.08)
		var r = (r_out * rng.randf_range(0.8, 1.15)) if i % 2 == 0 else (r_in * rng.randf_range(0.85, 1.1))
		pts.append(Vector2(cos(a), sin(a) * 0.8) * r)
	return pts


func _comic_pop(world: Variant, word: String, big: bool = false) -> void:
	if world == null or board == null or board.cam == null or board.cam.is_position_behind(world):
		return
	var sp: Vector2 = board.cam.unproject_position(world)
	var root = Node2D.new()
	root.position = sp + Vector2(randf_range(-30, 30), -40 + randf_range(-20, 10))
	root.rotation = randf_range(-0.22, 0.22)
	ui.add_child(root)
	var sc = (1.5 if big else 1.0) * clamp(get_viewport().get_visible_rect().size.y / 900.0, 0.7, 1.4)
	var pts = _star_pts(70.0, 38.0, 11, randi())
	var col: Color = POP_COLS.pick_random()
	var sh = Polygon2D.new()
	sh.polygon = pts
	sh.color = Color(0.05, 0.0, 0.1)
	sh.position = Vector2(7, 7)
	root.add_child(sh)
	var outl = Polygon2D.new()
	outl.polygon = pts
	outl.color = Color(0.05, 0.0, 0.1)
	outl.scale = Vector2(1.08, 1.08)
	root.add_child(outl)
	var fill = Polygon2D.new()
	fill.polygon = pts
	fill.color = col
	root.add_child(fill)
	var inner = Polygon2D.new()
	inner.polygon = _star_pts(40.0, 24.0, 9, randi())
	inner.color = col.lightened(0.55)
	root.add_child(inner)
	var lb = Label.new()
	lb.text = word
	if font_title != null:
		lb.add_theme_font_override("font", font_title)
	lb.add_theme_font_size_override("font_size", 38)
	lb.add_theme_color_override("font_color", Color.WHITE)
	lb.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.1))
	lb.add_theme_constant_override("outline_size", 12)
	lb.add_theme_color_override("font_shadow_color", Color(0.05, 0.0, 0.1))
	lb.add_theme_constant_override("shadow_offset_x", 4)
	lb.add_theme_constant_override("shadow_offset_y", 4)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.size = Vector2(220, 60)
	lb.position = Vector2(-110, -32)
	root.add_child(lb)
	root.scale = Vector2(0.15, 0.15) * sc
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector2(1.18, 1.18) * sc, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "scale", Vector2(1.0, 1.0) * sc, 0.1)
	tw.tween_interval(0.45)
	tw.parallel().tween_property(root, "position:y", root.position.y - 18.0, 0.45)
	tw.tween_property(root, "modulate:a", 0.0, 0.22)
	tw.tween_callback(root.queue_free)


var splash_until: int = 0          # um letreiro grande por vez
var low_warned: Dictionary = {}    # uid -> já mostrou NO LIMITE nesta vida


# alvo sobreviveu com pouca Vida: letreiro NO LIMITE! (uma vez por vida do personagem)
func _check_low_hp(uid: int, amt: int, world: Variant) -> void:
	if game == null:
		return
	var u: Variant = game.by_uid(uid)
	if u == null or u.barrier or u.hp <= 0:
		return
	var thr = max(2, int(ceil(u.maxhp * 0.3)))
	if u.hp > thr:
		low_warned.erase(uid)
		return
	if low_warned.has(uid) or u.hp + amt <= thr:
		return
	low_warned[uid] = true
	_hq_splash("limite", world)


# letreiro de impacto estilo anime de luta: linhas de velocidade, estouro e palavra com retícula
func _hq_splash(kind: String, world: Variant) -> void:
	var now = Time.get_ticks_msec()
	if now < splash_until and kind != "nocaute":
		return
	var tex_w = load("res://ui/splash/%s.png" % kind) if ResourceLoader.exists("res://ui/splash/%s.png" % kind) else null
	if tex_w == null:
		return
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var big = kind == "nocaute"
	var low = kind == "limite"
	splash_until = now + (1500 if big else 1000)
	var center = vs * 0.5
	if not big and world != null and board != null and board.cam != null and not board.cam.is_position_behind(world):
		center = board.cam.unproject_position(world) + Vector2(0, -vs.y * 0.08)
	var ww = vs.x * (0.72 if big else (0.40 if low else 0.34))
	ww = min(ww, vs.y * (1.3 if big else 0.75))
	var hw = ww * 0.5 / max(1.0, float(tex_w.get_width()) / float(tex_w.get_height()))
	center.x = clamp(center.x, ww * 0.5 + 12, vs.x - ww * 0.5 - 12)
	center.y = clamp(center.y, hw + 70, vs.y - hw - 120)
	var root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)
	# clarão
	if not low:
		var fl = ColorRect.new()
		fl.color = Color(1, 1, 1, 0.55) if not big else Color(1, 0.95, 0.8, 0.75)
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(fl)
		var tf = fl.create_tween().set_ignore_time_scale(true)
		tf.tween_property(fl, "color:a", 0.0, 0.18)
	if big:
		var dim = ColorRect.new()
		dim.color = Color(0.06, 0.02, 0.12, 0.0)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(dim)
		dim.move_to_front()
		var td = dim.create_tween().set_ignore_time_scale(true)
		td.tween_property(dim, "color:a", 0.45, 0.12)
		td.tween_interval(1.0)
		td.tween_property(dim, "color:a", 0.0, 0.3)
	# linhas de velocidade convergindo no alvo
	var stage = Node2D.new()
	stage.position = center
	root.add_child(stage)
	if ResourceLoader.exists("res://ui/splash/linhas.png"):
		var ln = Sprite2D.new()
		ln.texture = load("res://ui/splash/linhas.png")
		var lsc = vs.length() * (2.2 if big else 1.4) / 1024.0
		ln.scale = Vector2.ONE * lsc * 1.3
		ln.modulate = Color(1, 0.55, 0.75, 0.0) if low else Color(1, 1, 1, 0.0)
		stage.add_child(ln)
		var tl = ln.create_tween().set_ignore_time_scale(true)
		tl.tween_property(ln, "modulate:a", 0.95, 0.08)
		tl.parallel().tween_property(ln, "scale", Vector2.ONE * lsc, 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tl.parallel().tween_property(ln, "rotation", 0.12, 1.2)
		tl.tween_interval(0.6 if not big else 0.9)
		tl.tween_property(ln, "modulate:a", 0.0, 0.25)
	# estouro atrás da palavra
	var bpath = "res://ui/splash/estouro_limite.png" if low else "res://ui/splash/estouro_ko.png"
	if ResourceLoader.exists(bpath):
		var bs = Sprite2D.new()
		bs.texture = load(bpath)
		var bsc = ww * (0.62 if not big else 0.5) / 900.0
		bs.scale = Vector2.ONE * bsc * 0.2
		bs.rotation = randf_range(-0.4, 0.4)
		bs.position = Vector2(randf_range(-ww * 0.12, ww * 0.12), hw * 0.15)
		stage.add_child(bs)
		var tb = bs.create_tween().set_ignore_time_scale(true)
		tb.tween_property(bs, "scale", Vector2.ONE * bsc * 1.1, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tb.parallel().tween_property(bs, "rotation", bs.rotation + 0.35, 1.1)
		tb.tween_interval(0.65 if not big else 0.95)
		tb.tween_property(bs, "scale", Vector2.ONE * bsc * 1.5, 0.22)
		tb.parallel().tween_property(bs, "modulate:a", 0.0, 0.22)
	# a palavra: entra gigante, bate, treme e some crescendo
	var wd = Sprite2D.new()
	wd.texture = tex_w
	var wsc = ww / float(tex_w.get_width())
	wd.scale = Vector2.ONE * wsc * 2.6
	wd.modulate.a = 0.0
	wd.rotation = randf_range(-0.12, -0.03) if randf() < 0.5 else randf_range(0.03, 0.1)
	stage.add_child(wd)
	var tw = wd.create_tween().set_ignore_time_scale(true)
	tw.tween_property(wd, "modulate:a", 1.0, 0.05)
	tw.parallel().tween_property(wd, "scale", Vector2.ONE * wsc * 0.92, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(wd, "scale", Vector2.ONE * wsc, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in range(4):
		var amp = (12.0 if big else 7.0) * (1.0 - i * 0.22)
		tw.tween_property(wd, "position", Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.035)
	tw.tween_property(wd, "position", Vector2.ZERO, 0.04)
	tw.tween_interval(0.62 if not big else 0.85)
	tw.tween_property(wd, "scale", Vector2.ONE * wsc * 1.15, 0.2)
	tw.parallel().tween_property(wd, "modulate:a", 0.0, 0.2)
	tw.tween_callback(root.queue_free)
	if big:
		board.shake = max(board.shake, 0.6)


func _hex_pos(h: Vector2i, lift: float = 0.9) -> Vector3:
	var wp = board.world_xz(h)
	return Vector3(wp.x, board.top_y(h) + lift, wp.y)


var hit_fac: Dictionary = {}    # uid do alvo -> facção de quem acabou de atacar (assinatura do impacto)


func _unit_fac(uid: int) -> String:
	var u: Variant = game.by_uid(uid) if game != null else null
	if u == null or u.barrier:
		return ""
	return DB.cards[u.cid]["f"]


# cor do efeito de ataque: a paleta de VFX da facção (manual), não a cor da interface
func _vfx_color(uid: int) -> Color:
	var f = _unit_fac(uid)
	return DB.pal(f) if f != "" else Color("#d9c9a8")


# galeria do Manual de VFX: os 7 impactos em fila no meio do mapa, repetindo 3 vezes
func _vfx_gallery() -> void:
	if game == null:
		return
	var facs = ["KRI", "WAC", "ZUK", "ABY", "TER", "LIT", "FAU"]
	# fila horizontal de 7 casas (uma sim, outra não) passando pelo centro do mapa
	var c = Vector2i.ZERO
	var cw = board.world_xz(c)
	var cands = []
	for h in board.tiles.keys():
		var wp = board.world_xz(h)
		if abs(wp.y - cw.y) < 0.5:
			cands.append([wp.x, h])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var mid = 0
	for k in range(cands.size()):
		if cands[k][1] == c:
			mid = k
	var row = []
	for i in range(-3, 4):
		var j = clamp(mid + i * 2, 0, cands.size() - 1)
		row.append(cands[j][1] if not cands.is_empty() else Vector2i(i, 0))
	var span = board.world_xz(row[6]).x - board.world_xz(row[0]).x
	board.cam_goal = {"yaw": 0.0, "pitch": 0.85, "dist": max(12.0, span * 1.05), "target": Vector3(cw.x, 0.5, cw.y)}
	await get_tree().create_timer(1.2).timeout
	for rep in range(3):
		# os 7 ao mesmo tempo, para comparar lado a lado
		for i in range(facs.size()):
			var h = row[i]
			if not board.tiles.has(h):
				continue
			var p = _hex_pos(h, 0.9)
			var f = facs[i]
			if rep == 0:
				board.float_text(h, DB.factions[f]["short"], DB.pal(f, "highlight"), 0.38)
			vfx.impact(p, DB.pal(f, "secondary"), 1.0)
			vfx.flip("imp_" + f.to_lower(), p - Vector3(0, 0.75, 0), 3.0, 0.55)
			vfx.flip("ring", _hex_pos(h, 0.0), 2.4, 0.5, DB.pal(f, "primary"), true)
		await get_tree().create_timer(1.3).timeout


# Oficina de VFX (palco à parte, scripts/oficina_vfx.gd). auto = toca tudo e fecha (gravação)
func _open_oficina(auto: bool, fac: String = "aby") -> void:
	board.visible = false
	galaxy.deactivate()
	fader.visible = false
	ui.visible = false
	var of = Node3D.new()
	of.set_script(load("res://scripts/oficina_vfx.gd"))
	of.fac = fac
	add_child(of)
	if auto:
		await get_tree().create_timer(0.8).timeout
		await of.auto(1, 2.0)
		get_tree().quit()


func _unit_color(uid: int) -> Color:
	var u: Variant = game.by_uid(uid) if game != null else null
	if u == null or u.barrier:
		return Color("#d9c9a8")
	return Color(DB.factions[DB.cards[u.cid]["f"]]["color"])


func _shot_style(uid: int) -> String:
	var u: Variant = game.by_uid(uid)
	if u == null or u.barrier:
		return "energia"
	var c = DB.cards[u.cid]
	if c["f"] == "LIT":
		return "cristal"
	if c["f"] == "ZUK":
		return "laser"
	if c["f"] == "ABY" or c["f"] == "TER":
		return "energia"
	return "bala"


# atraso para o impacto chegar junto com o projétil
func _later(delay: float, cb: Callable) -> void:
	if delay <= 0.01:
		cb.call()
	else:
		get_tree().create_timer(delay).timeout.connect(cb)


func _fx_dmg(h: Vector2i, amt: int, uid: int) -> void:
	board.float_text(h, ("-%d" % amt) if amt > 0 else "0", Color("#ff6a4a") if amt > 0 else Color("#8fb8cc"))
	board.hurt(uid)
	var p: Variant = _unit_pos(uid, 0.9)
	if p == null:
		p = _hex_pos(h)
	var k = _fx_scale()
	var hf = hit_fac.get(uid, "")
	hit_fac.erase(uid)
	if amt > 0:
		if hf != "":
			# assinatura de impacto da facção atacante (Manual de VFX)
			vfx.impact(p, DB.pal(hf, "secondary"), clamp(amt / 4.0, 0.6, 1.8) * k)
			vfx.flip("imp_" + hf.to_lower(), p - Vector3(0, 0.75, 0), clamp(2.3 + amt * 0.22, 2.5, 4.0), 0.55)
			vfx.flip("ring", _hex_pos(h, 0.0), 2.4, 0.5, DB.pal(hf, "primary"), true)
		else:
			vfx.impact(p, Color("#ff9a5a"), clamp(amt / 4.0, 0.6, 1.8) * k)
			vfx.flip("hit", p - Vector3(0, 0.75, 0), clamp(2.1 + amt * 0.22, 2.3, 3.8), 0.6)
			vfx.flip("ring", _hex_pos(h, 0.0), 2.4, 0.5, Color("#ff8a3a"), true)
		if amt >= 4:
			vfx.flip("boom", _hex_pos(h, 0.0), 2.0, 0.6, Color(1, 0.85, 0.7))
		board.shake = max(board.shake, clamp(amt * 0.08, 0.15, 0.5))
		_voice(uid, "dor", -1.0, 0.06)
		_check_low_hp(uid, amt, p)
	else:
		vfx.block(p)
		vfx.flip("shield", p - Vector3(0, 0.9, 0), 1.9, 0.55, Color("#bfe8ff"))


# efeitos maiores quando a câmera está longe (tabuleiro grande)
func _fx_scale() -> float:
	return clamp(board.cam_dist / 26.0, 1.0, 2.0)


# voz do personagem: v_<id>_atk (atacar) ou v_<id>_dor (sofrer dano)
func _voice(uid: int, kind: String, vol: float = 0.0, delay: float = 0.0, pitch: float = 1.0) -> void:
	if game == null or sfx == null:
		return
	var u: Variant = game.by_uid(uid)
	if u == null or u.barrier:
		return
	var n = "v_%s_%s" % [u.cid, kind]
	if delay > 0.0:
		sfx.play_later(n, delay, vol, pitch)
	else:
		sfx.play(n, vol, pitch, 0.05)


func _fx_die(p: Vector3, c: Color) -> void:
	vfx.death_fx(p, c)
	vfx.flip("smoke", p - Vector3(0, 0.2, 0), 2.4, 0.8)
	sfx.play("derrota", -3.0)


# efeitos 2.5D das habilidades: cada tipo tem seu desenho, cor e som
func _on_abfx(e: Dictionary) -> void:
	var g0 = _hex_pos(e["h"], 0.0)
	var fc = _unit_color(e["uid"]).lightened(0.35)
	var lit = false
	var uu: Variant = game.by_uid(e["uid"])
	if uu != null and not uu.barrier:
		lit = DB.cards[uu.cid]["f"] == "LIT"
	match e["k"]:
		"poison":
			vfx.flip("poison", g0, 1.9, 0.7)
		"glue", "root":
			vfx.flip("glue", g0, 2.0, 0.6)
		"splash":
			vfx.flip("crystal" if lit else "boom", g0, 2.6, 0.6, fc if lit else Color.WHITE)
			vfx.flip("ring", g0, 3.4, 0.5, fc, true)
		"nova":
			vfx.flip("crystal" if lit else "spikes", g0, 2.8, 0.6, fc if lit else Color.WHITE)
			vfx.flip("ring", g0, 3.6, 0.5, fc, true)
		"zap":
			vfx.flip("bolt", g0, 2.4, 0.4, Color("#fff07a"))
			vfx.flip("ring", g0, 3.4, 0.45, Color("#fff07a"), true)
		"bolt":
			vfx.flip("bolt", g0, 2.4, 0.4, Color("#bfe0ff"))
		"hook", "dash":
			vfx.flip("dash", g0, 2.0, 0.35, fc)
		"insight", "buff":
			vfx.flip("sparkle" if e["k"] == "insight" else "aura", g0, 2.2, 0.7, Color("#fff2a0"))
		"quake", "push":
			vfx.flip("ring", g0, 3.6, 0.5, Color("#e8c890"), true)
			vfx.flip("smoke", g0, 2.0, 0.6)
		"explode", "blast":
			vfx.flip("boom", g0, 2.6, 0.7)
		"sonic":
			vfx.flip("sonic", g0, 2.4, 0.5, fc)
		"debuff":
			vfx.flip("curse", g0, 2.0, 0.6)
		"silence":
			vfx.flip("ink", g0, 2.0, 0.6)
		"mark":
			vfx.flip("mark", g0, 2.0, 0.7)
		"heal":
			vfx.flip("heal", g0, 2.2, 0.8)
		"veil":
			vfx.flip("ink", g0, 2.4, 0.7)
		"mine":
			vfx.flip("spikes", g0, 1.6, 0.5, Color("#c8a0ff"))
		"barrier", "earth", "burrow":
			vfx.flip("rock", g0, 2.4, 0.6, fc if lit else Color.WHITE)
			vfx.flip("ring", g0, 3.0, 0.45, Color("#d8b888"), true)
		"portal":
			vfx.flip("portal", g0, 2.2, 0.6, fc)
		"abyss":
			vfx.flip("vortex", g0, 2.8, 0.8)
		"bombard":
			vfx.flip("beam", g0, 2.8, 0.45, Color("#ffd08a"))
			vfx.flip("boom", g0, 3.2, 0.8, Color.WHITE, false, 0.3)
			vfx.flip("ring", g0, 5.0, 0.6, Color("#ffb060"), true, 0.3)
		"burn":
			vfx.flip("boom", g0, 2.2, 0.8, Color("#ff7a2a"))
			vfx.flip("smoke", g0, 2.0, 0.7)
		"shell":
			vfx.flip("beam", g0, 2.8, 0.45, Color("#ffd08a"))
			vfx.flip("boom", g0, 3.2, 0.8, Color.WHITE, false, 0.3)
			vfx.flip("ring", g0, 4.4, 0.6, Color("#ffb060"), true, 0.3)
		"prison":
			vfx.flip("prison", g0, 2.6, 0.7, Color("#c8f4ff"))
		"stomp":
			vfx.flip("ring", g0, 3.2, 0.4, Color("#e8d8b8"), true)
			vfx.flip("smoke", g0, 1.8, 0.5)
		"orbital":
			vfx.flip("beam", g0, 2.8, 0.5, fc)
			vfx.flip("ring", g0, 4.6, 0.6, fc, true, 0.35)
			vfx.flip("boom", g0, 2.6, 0.7, Color.WHITE, false, 0.35)


func _fx_shield(p: Vector3) -> void:
	vfx.shield_fx(p)
	vfx.flip("shield", p, 1.9, 0.5, Color("#bfe8ff"))


func _fx_phoenix(p: Vector3) -> void:
	vfx.phoenix_fx(p)
	vfx.flip("fire", p, 2.4, 0.9)


func _storm_end() -> void:
	if vfx != null:
		vfx.sandstorm(false)
	sfx.stop_loop("tempestade_loop", 3.0)


func _on_fx(e: Dictionary) -> void:
	var now = Time.get_ticks_msec()
	var d = impact_delay if now < impact_until else 0.0
	match e["t"]:
		"strike":
			board.lunge(e["from"])
			var a: Variant = _unit_pos(e["from"], 1.0)
			var tgt: Variant = _unit_pos(e["to"], 0.9)
			var col = _vfx_color(e["from"])
			hit_fac[e["to"]] = _unit_fac(e["from"])
			if a == null or tgt == null:
				return
			var k = _fx_scale()
			_comic_pop(tgt, (["ZAP!", "PEW!", "FZZT!", "VUSH!"] if e["ranged"] else ["POW!", "BAM!", "WHAM!", "SOC!", "TUM!"]).pick_random())
			_voice(e["from"], "atk", -2.0)
			if e["ranged"]:
				var style = _shot_style(e["from"])
				# disparo: clarão na arma do atacante
				var muzzle = {"cristal": "crystal", "laser": "beam", "energia": "bolt"}.get(style, "hit")
				vfx.flip(muzzle, a - Vector3(0, 0.8, 0), 2.0, 0.5, col.lightened(0.3))
				impact_delay = vfx.projectile(a, tgt, col, style, k)
				impact_until = now + 120
				var snd = "projetil"
				if style == "cristal":
					snd = "tiro_cristal"
				elif style == "laser":
					snd = "tiro_laser"
				elif style == "energia":
					snd = "tiro_energia"
				sfx.play(snd, -3.0)
			else:
				impact_delay = 0.16
				impact_until = now + 160
				vfx.flip("dash", a - Vector3(0, 0.8, 0), 2.0, 0.5, col.lightened(0.2))
				vfx.slash(tgt, a, col, k)
				vfx.flip("slash", tgt - Vector3(0, 0.9, 0), 3.4, 0.65, col.lightened(0.25), false, 0.06)
		"dmg":
			var amt = e["amt"]
			var uid = e["uid"]
			var h = e["h"]
			_later(d, _fx_dmg.bind(h, amt, uid))
		"heal":
			board.float_text(e["h"], "+%d" % e["amt"], Color("#84d14f"))
			vfx.heal_fx(_hex_pos(e["h"], 0.1))
			sfx.play("cura", -4.0)
		"die":
			var du2 = game.by_uid(e["uid"])
			if du2 != null and not du2.barrier:
				var big = du2.is_cmd
				_later(d, _hq_splash.bind("nocaute" if big else "ko", _hex_pos(e["h"], 1.2)))
				_later(d + 0.05, func():
					_hitstop(0.22 if big else 0.09)
					board.quake()
					sfx.play("vfx_boom", -1.0 if big else -4.0, 0.7 if big else 0.85, 0.0))
				if big:
					_later(d + 1.7, func(): banner("COMANDANTE DERROTADO", game.nm(du2)))
			low_warned.erase(e["uid"])
			_banter_death(e["uid"])
			var hp = _hex_pos(e["h"], 0.2)
			var dc = _unit_color(e["uid"])
			_voice(e["uid"], "dor", 0.0, d + 0.1, 0.82)
			_later(d + 0.15, _fx_die.bind(hp, dc))
		"summon":
			_banter(e["uid"])
			vfx.summon_fx(_hex_pos(e["h"], 0.0), _unit_color(e["uid"]))
			vfx.flip("portal", _hex_pos(e["h"], 0.0), 2.2, 0.6, _unit_color(e["uid"]).lightened(0.4))
			sfx.play("invocar", -5.0)
		"move":
			sfx.play("passo", -10.0, 1.0, 0.2)
		"boom":
			_comic_pop(_hex_pos(e["h"], 0.8), ["KABOOM!", "BOOM!", "KRA-KOOM!"].pick_random(), true)
			board.boom(e["h"])
			vfx.explosion(_hex_pos(e["h"], 0.2))
			vfx.flip("boom", _hex_pos(e["h"], 0.0), 2.6, 0.7)
			sfx.play("explosao", -2.0)
		"passive":
			var pp: Variant = _unit_pos(e["uid"], 0.0)
			if pp == null:
				return
			match e["kind"]:
				"power", "ability":
					vfx.power_fx(pp)
					vfx.flip("aura" if e["kind"] == "power" else "sparkle", pp, 2.0, 0.6, Color("#ffe27a") if e["kind"] == "power" else _unit_color(e["uid"]).lightened(0.5))
				"shield":
					_later(d, _fx_shield.bind(pp))
				"curse":
					vfx.curse_fx(pp)
					vfx.flip("curse", pp, 1.9, 0.6)
				"phoenix":
					_later(d + 0.3, _fx_phoenix.bind(pp))
				"trap":
					vfx.trap_fx(pp)
					vfx.flip("spikes", pp, 1.8, 0.5)
				"slide":
					vfx.flip("sparkle", pp, 1.6, 0.5, Color("#bff6ff"))
		"card":
			sfx.play("carta", -4.0)
		"banana":
			var bcol = {"cura": Color("#5bd46a"), "dano": Color("#ff6a4a"), "alcance": Color("#5ec8f0")}.get(e["b"], C_GOLD)
			vfx.flip("sparkle", _hex_pos(e["h"], 0.6), 2.0, 0.6, bcol)
			board.float_text(e["h"], {"cura": "+3 VIDA", "dano": "+2 ATQ", "alcance": "+1 ALC"}.get(e["b"], ""), bcol)
			sfx.play("vfx_heal", -8.0)
		"music":
			var mp2: Variant = _unit_pos(e["uid"], 1.2)
			if mp2 != null:
				vfx.flip("ring", mp2 - Vector3(0, 1.1, 0), 3.0 + 2.2 * game.disc_radius(), 0.9, Color("#ff7ad8"), true)
				vfx.flip("sonic", mp2, 2.4, 0.8, Color("#ff7ad8"))
			sfx.play("vfx_aura", -6.0)
		"core":
			var cp2 = _hex_pos(e["h"], 0.1)
			match e["what"]:
				"spawn":
					vfx.flip("portal", cp2, 3.2, 1.0, Color("#7ff0ff"))
					vfx.flip("ring", cp2, 4.5, 0.9, Color("#7ff0ff"), true)
					sfx.play("vfx_portal", -4.0)
					_later(1.6, banner.bind("NÚCLEO DE ENERGIA", "capture com qualquer peça: cartas ou bônus"))
				"take":
					vfx.flip("sparkle", cp2 + Vector3(0, 0.8, 0), 3.0, 0.8, Color("#7ff0ff"))
					vfx.flip("ring", cp2, 3.6, 0.7, Color("#ffffff"), true)
					sfx.play("vfx_crystal", -3.0)
				"fade":
					vfx.flip("smoke", cp2, 2.2, 0.8)
		"danger":
			_later(1.0, banner.bind("O DESERTO DESPERTA", "%d buracos de verme no próximo round · fuja das casas marcadas" % int(e["n"])))
		"zone_grow":
			_later(2.2, banner.bind("ÁREA DE ENTRADA MAIOR", "Agora dá para colocar personagens até %d casas da sua base" % int(e["r"])))
			for pz in range(2):
				var ew = board.world_xz(DB.entry_c[pz])
				vfx.flip("ring", Vector3(ew.x, 0.3, ew.y), 3.0 + 2.6 * int(e["r"]), 0.9, C_DEPLOY if pz == me else C_CPU, true)
			sfx.play("vfx_portal", -8.0)
		"tactic_on":
			var tcol: Color = TYPE_COL.get(DB.tactics[e["id"]]["type"], C_CARD)
			var tp = _hex_pos(e["h"], 0.05)
			vfx.flip("ring", tp, 3.4, 0.55, tcol, true)
			vfx.flip("aura", tp + Vector3(0, 0.9, 0), 2.6, 0.75, tcol.lightened(0.25))
			vfx.flip("sparkle", tp + Vector3(0, 1.4, 0), 1.8, 0.6, tcol.lightened(0.5), false, 0.12)
			board.float_text(e["h"], DB.tactics[e["id"]]["name"], tcol.lightened(0.35))
			sfx.play("vfx_aura", -9.0)
		"abfx":
			_on_abfx(e)
		"ult":
			banner("★ " + str(e["name"]), ("Você" if e["p"] == me else _opp()) + " · " + game.nm(game.by_uid(e["uid"])))
			sfx.play("poder", -1.0, 0.8)
		"wind":
			banner("O vento muda!", "tempestade de areia: as dunas vão se mover")
			vfx.sandstorm(true)
			sfx.loop("tempestade_loop", -6.0, 3.0)
		"dunes":
			banner("As dunas se movem!", "o relevo mudou")
			board.quake()
			sfx.play("dunas", 0.0)
			get_tree().create_timer(4.0).timeout.connect(_storm_end)
		"vib":
			sfx.play("verme_rumor", -8.0 + float(e["v"]) * 1.5, 1.3)
			board.shake = max(board.shake, 0.08 + 0.05 * float(e["v"]))
			board.claw_twitch(float(e["v"]))
		"claw":
			banner("A GARRA ATACA!", "quem está perto do buraco é arrastado")
			if w.has("banner"):
				w["banner"].add_theme_color_override("font_color", Color("#ff4ad0"))
			sfx.play("garra_ataque", 2.0, 1.0, 0.03)
			board.claw_strike()
			var pc = _hex_pos(Vector2i(0, 0), 0.3)
			_comic_pop(_hex_pos(Vector2i(0, 0), 2.0), "KRRAAK!", true)
			# onda de choque saindo do buraco + poeira e pedras
			vfx.flip("ring", pc, 11.0, 0.7, Color("#ff5ae0"), true)
			vfx.flip("ring", pc, 7.0, 0.55, Color("#ffd23a"), true, 0.12)
			vfx.flip("smoke", pc + Vector3(0, 0.6, 0), 6.0, 1.0, Color("#b07ae8"))
			vfx.flip("rock", pc + Vector3(0, 0.4, 0), 4.0, 0.8)
			vfx.flip("curse", pc + Vector3(0, 1.0, 0), 5.0, 0.9)
			for ch in e["hexes"]:
				vfx.flip("slash", _hex_pos(ch, 0.9), 2.6, 0.5, Color("#ff7ae0"), false, 0.15)
		"claw_grab":
			# um dedo enorme sai do buraco, agarra o personagem e puxa
			sfx.play("garra_puxa", 0.0, 1.0, 0.06)
			board.claw_reach(e["h"], bool(e["kill"]))
			var gp = _hex_pos(e["h"], 0.9)
			vfx.flip("hit", gp, 2.6, 0.45, Color("#ff7ae0"))
			vfx.flip("dash", gp, 2.4, 0.4, Color("#b03ad8"))
			_comic_pop(gp, "NHAC!" if bool(e["kill"]) else ["PUXA!", "VEM!", "GRAB!"].pick_random(), bool(e["kill"]))
		"cart":
			board.move_cart(int(e["i"]), e["to"])
			sfx.play("passo", -4.0, 0.6)
		"tremor":
			sfx.play("verme_rumor", -2.0, 0.7)
			board.shake = max(board.shake, 0.35)
			banner("A AREIA TREME", "saia das casas marcadas: o verme vem no próximo round")
			if w.has("banner"):
				w["banner"].add_theme_color_override("font_color", Color("#ff9a5a"))
			for th in e["hexes"]:
				vfx.dust_burst(_hex_pos(th, 0.0), false)
		"rumble":
			sfx.play("verme_rumor", -6.0, 0.9)
			board.shake = max(board.shake, 0.2)
			for th in e["hexes"]:
				vfx.dust_burst(_hex_pos(th, 0.0), false)
		"warn_map":
			sfx.play("verme_rumor", -3.0, 0.6)
			board.shake = max(board.shake, 0.3)
			var wk = String(e["kind"])
			banner("AS RAÍZES SE MEXEM" if wk == "raiz" else ("O GELO ESTALA" if wk == "fratura" else "AVALANCHE À VISTA"), "saia das casas marcadas: acontece no próximo round")
			if w.has("banner"):
				w["banner"].add_theme_color_override("font_color", Color("#9be85a") if wk == "raiz" else Color("#9fe8ff"))
			for th in e["hexes"]:
				vfx.dust_burst(_hex_pos(th, 0.0), false)
		"rain_start":
			banner("COMEÇA A CHOVER!", "ataques -3 de dano · o céu escurece")
			vfx.rain(true)
			sfx.loop("tempestade_loop", -9.0, 3.0)
		"bolt":
			var bp = _hex_pos(e["h"], 0.0)
			vfx.lightning(bp)
			sfx.play("explosao", -4.0, 1.4)
			if e.get("fire", false):
				vfx.play_fx("abnara_ignicao", bp)
				board.float_text(e["h"], "🔥", Color("#ffb04c"))
		"fire_set":
			vfx.fire_set(e["hexes"], func(fh): return _hex_pos(fh, 0.0))
		"roots":
			board.shake = max(board.shake, 0.6)
			sfx.play("explosao", -6.0, 0.55)
			for th in e["hexes"]:
				vfx.dust_burst(_hex_pos(th, 0.0), true)
		"icebreak":
			banner("O GELO SE ROMPEU!", "fendas abertas por 3 rounds")
			board.quake()
			sfx.play("explosao", -2.0, 0.7)
			for th in e["hexes"]:
				vfx.dust_burst(_hex_pos(th, 0.0), true)
				vfx.flip("rock", _hex_pos(th, 0.0), 3.0, 0.7, Color("#bfeeff"))
		"avalanche":
			banner("AVALANCHE!", "a neve desce pelo corredor")
			board.quake()
			sfx.play("verme_ataque", 0.0, 0.55)
			for th in e["hexes"]:
				vfx.dust_burst(_hex_pos(th, 0.0), true)
				vfx.flip("boom", _hex_pos(th, 0.0), 3.5, 0.8, Color("#e8f6ff"))
		"worm":
			banner("VERME GIGANTE!", "quem estiver nos buracos é devorado")
			if w.has("banner"):
				w["banner"].add_theme_color_override("font_color", Color("#ff4a3a"))
			board.quake()
			sfx.play("verme_rumor", 2.0, 0.6)
			sfx.play_later("verme_rumor", 0.5, 0.0, 0.5)
			var hs = []
			for b in game.holes:
				hs.append(b["h"])
				vfx.dust_burst(_hex_pos(b["h"], 0.0), true)
			board.worm_emerge(hs)
		"round":
			sfx.play("round", -6.0)
			banner("Round %d" % e["round"], "os comandantes entram" if e["round"] == Game.CMD_ROUND else ("Você começa" if game.first == me else (_opp() + " começa")))
	board.sync_units()


# ================= diálogos e balões de fala =================
func _short(cid: String) -> String:
	var n: String = DB.cards[cid]["name"]
	for pre in ["Krieg ", "Wächter ", "Zukunft ", "Lithari "]:
		if n.begins_with(pre):
			n = n.substr(pre.length())
	n = n.replace(" Zukunft", "")
	return n.split(" ")[0] if n.split(" ").size() > 2 else n


func _fac_of(u) -> String:
	return DB.cards[u.cid]["f"]


func _pick(arr) -> String:
	if arr == null or not (arr is Array) or arr.is_empty():
		return ""
	return str(arr[randi() % arr.size()])


func _line(kind: String, u, target = null) -> String:
	var txt = ""
	var pc = dlg.get("personagem", {}).get(u.cid, {})
	if pc.has(kind) and randf() < 0.65:
		txt = _pick(pc[kind])
	if txt == "":
		txt = _pick(dlg.get(kind, {}).get(_fac_of(u), []))
	if target != null:
		txt = txt.replace("{nome}", _short(target.cid))
	return txt


# quando alguém entra em campo: fala com um aliado ou provoca um inimigo, e recebe resposta
func _banter(uid: int) -> void:
	if dlg.is_empty() or game == null:
		return
	var u: Variant = game.by_uid(uid)
	if u == null or u.barrier:
		return
	var now = Time.get_ticks_msec()
	if now - last_banter_ms < 3500 and not u.is_cmd:
		return
	last_banter_ms = now
	var others = game.field().filter(func(x): return x != u and not x.barrier)
	# duplas com conversa própria
	for pr in dlg.get("pares", []):
		var other_id = ""
		if pr["a"] == u.cid:
			other_id = pr["b"]
		elif pr["b"] == u.cid:
			other_id = pr["a"]
		if other_id == "":
			continue
		var o = null
		for x in others:
			if x.cid == other_id:
				o = x
		if o == null:
			continue
		var t0 = 0.6
		for i in range(pr["fala"].size()):
			var who = (u if pr["a"] == u.cid else o) if i % 2 == 0 else (o if pr["a"] == u.cid else u)
			var other = o if who == u else u
			_say(who.uid, pr["fala"][i], t0, "prov" if other.owner != who.owner else "fala")
			t0 += 2.2
		return
	var enemies = others.filter(func(x): return x.owner != u.owner)
	var allies = others.filter(func(x): return x.owner == u.owner)
	var near = func(arr):
		var best = null
		for x in arr:
			if best == null or DB.dist(x.pos(), u.pos()) < DB.dist(best.pos(), u.pos()):
				best = x
		return best
	var tgt = null
	var mode = "entrada"
	if not enemies.is_empty() and (allies.is_empty() or randf() < 0.55):
		tgt = near.call(enemies)
		mode = "provoca"
	elif not allies.is_empty() and randf() < 0.8:
		tgt = near.call(allies)
		mode = "aliado"
	var l1 = _line(mode if tgt != null else "entrada", u, tgt)
	if l1 == "":
		return
	_say(u.uid, l1, 0.6, "prov" if mode == "provoca" else "fala")
	if tgt != null:
		var l2 = _pick(dlg.get("resp_inimigo" if mode == "provoca" else "resp_aliado", {}).get(_fac_of(tgt), []))
		if l2 != "":
			_say(tgt.uid, l2, 2.6, "prov" if mode == "provoca" else "fala")


func _banter_death(uid: int) -> void:
	if dlg.is_empty() or game == null:
		return
	var dead: Variant = game.by_uid(uid)
	if dead == null or dead.barrier:
		return
	var foes = game.field().filter(func(x): return x.owner != dead.owner and not x.barrier and x.st == "field")
	var friends = game.field().filter(func(x): return x.owner == dead.owner and not x.barrier and x.st == "field" and x != dead)
	if not foes.is_empty() and randf() < 0.5:
		var f = foes[randi() % foes.size()]
		_say(f.uid, _line("vitoria", f), 0.9, "prov")
	elif not friends.is_empty() and randf() < 0.45:
		var a = friends[randi() % friends.size()]
		_say(a.uid, _line("lamento", a), 0.9, "triste")


func _say(uid: int, text: String, delay: float = 0.0, mood: String = "fala") -> void:
	if text == "" or not w.has("bubbles"):
		return
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if game == null or not w.has("bubbles") or not board.unit_nodes.has(uid):
		return
	var u: Variant = game.by_uid(uid)
	if u == null:
		return
	_talk_voice(u, text, mood)
	# um balão por personagem
	for b in bubbles:
		if b["uid"] == uid and is_instance_valid(b["node"]):
			b["node"].queue_free()
	var col = _unit_color(uid)
	var p = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	# balão de HQ: branco, contorno de tinta grosso e sombra dura
	sb.bg_color = Color("#fffdf2")
	sb.border_color = Color(0.05, 0.0, 0.1)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.shadow_color = col.darkened(0.2)
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(5, 5)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 7
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v = _vbox(p, 1)
	var nl = _label(v, DB.cards[u.cid]["name"].to_upper(), 11, col.darkened(0.35))
	if font_btn != null:
		nl.add_theme_font_override("font", font_btn)
	nl.add_theme_constant_override("outline_size", 0)
	var tl = _label(v, text, 15, Color("#160a26"))
	tl.add_theme_constant_override("outline_size", 0)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size = Vector2(min(260, 9 * text.length() + 20), 0)
	w["bubbles"].add_child(p)
	p.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	tw.tween_interval(2.0 + text.length() * 0.035)
	tw.tween_property(p, "modulate:a", 0.0, 0.35)
	tw.tween_callback(p.queue_free)
	bubbles.append({"uid": uid, "node": p})
	if sfx != null:
		sfx.play("clique", -12.0, 1.3, 0.2)


# proteção de desempenho: se os primeiros segundos rodarem lentos, desliga o filtro HQ e baixa a resolução 3D
var perf_t: float = 0.0
var perf_n: int = 0
var perf_done: bool = false


func _perf_guard(delta: float) -> void:
	if perf_done:
		return
	perf_t += delta
	perf_n += 1
	if perf_t < 1.5:
		perf_n = 0 if perf_t < 1.0 else perf_n
		return
	if perf_t >= 5.0:
		perf_done = true
		var fps = perf_n / max(0.01, perf_t - 1.0)
		if fps < 28.0:
			if rgb_on and rgb_rect != null:
				rgb_rect.visible = false
				rgb_on = false
			if render_q > 0.75:
				render_q = 0.75
				get_viewport().scaling_3d_scale = render_q
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			print("desempenho baixo (%.0f fps): filtro HQ desligado e resolução 3D reduzida" % fps)


func _process(_delta: float) -> void:
	# a câmera da máscara acompanha a câmera do jogo
	if rgb_mask != null:
		var on = rgb_on and rgb_rect != null and rgb_rect.visible and board != null and board.cam != null
		rgb_mask.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
		if on:
			var vs = get_viewport().get_visible_rect().size
			var sz = Vector2i(int(vs.x * 0.5), int(vs.y * 0.5))
			if rgb_mask.size != sz and sz.x > 8 and sz.y > 8:
				rgb_mask.size = sz
			var bc: Camera3D = board.cam
			rgb_mask_cam.global_transform = bc.global_transform
			rgb_mask_cam.fov = bc.fov
			rgb_mask_cam.projection = bc.projection
			rgb_mask_cam.size = bc.size
			rgb_mask_cam.near = bc.near
			rgb_mask_cam.far = bc.far
			rgb_mask_cam.current = true
	_perf_guard(_delta)
	if stage == "select":
		_update_tags()
	if game != null and board.visible:
		_fit_rosters()
		if w.has("ask") and is_instance_valid(w["ask"]) and w["ask"].visible:
			var kk = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
			w["ask_sb"].border_color = Color("#ffab40").lerp(Color("#fff2c0"), kk)
			w["ask_sb"].shadow_color = Color(1.0, 0.6, 0.15, 0.2 + 0.3 * kk)
		if w.has("end") and is_instance_valid(w["end"]):
			var eb: Button = w["end"]
			if eb.get_meta("pulse", false) and not eb.disabled:
				var k = 1.0 + 0.28 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 220.0))
				eb.modulate = Color(k, k, k)
			else:
				eb.modulate = Color.WHITE
		_tick_clock(_delta)
		_apply_title()
		_update_plates(_delta)
		_tremor_omen(_delta)
		vfx.cam_k = _fx_scale()
	if bubbles.is_empty():
		return
	var keep = []
	for b in bubbles:
		var p = b["node"]
		if not is_instance_valid(p):
			continue
		if not board.unit_nodes.has(b["uid"]):
			p.queue_free()
			continue
		var wp = board.unit_nodes[b["uid"]]["node"].position + Vector3(0, board.unit_nodes[b["uid"]].get("top", 1.75) + 2.0, 0)
		if board.cam.is_position_behind(wp):
			p.visible = false
		else:
			p.visible = true
			var sp = board.cam.unproject_position(wp)
			p.position = sp - Vector2(p.size.x / 2.0, p.size.y)
		keep.append(b)
	bubbles = keep


# capturas automáticas para conferir o visual: godot -- --shots=/pasta
func _shots(dir: String) -> void:
	autotest = true
	var shot = func(n: String):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir + "/" + n + ".png")
	await get_tree().create_timer(2.0).timeout
	await shot.call("01_menu")
	_on_play()
	await get_tree().create_timer(2.6).timeout
	await shot.call("02a_planetas")
	_choose_planet("tarhut")
	await get_tree().create_timer(2.2).timeout
	_army_random()
	await get_tree().create_timer(0.6).timeout
	await shot.call("02_exercito")
	autotest = false
	_army_go()
	await get_tree().create_timer(2.0).timeout
	await shot.call("02b_mergulho")
	while game == null:
		await get_tree().process_frame
	game.cpu = [false, true]
	await get_tree().create_timer(0.5).timeout
	await shot.call("02c_chegada")
	await get_tree().create_timer(3.0).timeout
	await shot.call("03_batalha")
	# cartas: passa o mouse na primeira e conversa entre personagens
	game.start_activation(game.field().filter(func(x): return x.owner == 0)[0])
	refresh()
	await get_tree().create_timer(0.3).timeout
	var c0 = w["hand"].get_child(0)
	_card_hover_set(game.P[0]["hand"][0], c0, true)
	var mine = game.field().filter(func(x): return x.owner == 0 and not x.barrier)
	last_banter_ms = -100000
	_banter(mine[0].uid)
	await get_tree().create_timer(3.4).timeout
	await shot.call("07_cartas_dialogo")
	_card_hover_set(game.P[0]["hand"][0], c0, false)
	board.cam_dist = 7.0
	await get_tree().create_timer(0.6).timeout
	await shot.call("04_zoom_perto")
	board.cam_dist = 140.0
	await get_tree().create_timer(0.6).timeout
	await shot.call("05_zoom_longe")
	board.cam_dist = 30.0
	board.cam_pitch = 0.5
	await get_tree().create_timer(0.6).timeout
	await shot.call("06_horizonte")
	get_tree().quit()


# ================= modo online =================
func _opp() -> String:
	return "Oponente" if online else "CPU"


func _my_army() -> Dictionary:
	return {"fac": setup_cfg["fac"], "cmd": _cur_cmd(), "mix": mix, "picks": army_picks.duplicate(), "start": army_start.duplicate()}


func _online_panel() -> void:
	if stage != "army":
		return
	var filled = false
	if army_picks.size() != 5 or army_start.size() != 2:
		# exército incompleto: completa sozinho para não travar o botão
		_army_random()
		filled = true
	if w.has("online") and is_instance_valid(w["online"]):
		w["online"].queue_free()
	sfx.play("clique", -8.0)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	w["online"] = dim
	var cc = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _flat(Color(0.03, 0.05, 0.11, 0.97), C_DEPLOY, 2, 12, 22))
	cc.add_child(p)
	var v = _vbox(p, 12)
	v.custom_minimum_size = Vector2(min(520, get_viewport().get_visible_rect().size.x - 40), 0)
	_label(v, "JOGAR ONLINE", 30, C_GOLD)
	var info = _label(v, ("Seu exército estava incompleto: completei com tropas sorteadas (dá para cancelar e trocar). " if filled else "") + "Um jogador cria a sala e passa o código; o outro entra com ele. O mapa é o planeta de quem criou a sala.", 14, C_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hb = _hbox(v, 8)
	var bh = _cbtn(hb, "Criar sala", C_GOLD, _online_host, true)
	_primary(bh)
	bh.custom_minimum_size = Vector2(0, 44)
	bh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var jh = _hbox(v, 8)
	var le = LineEdit.new()
	le.placeholder_text = "código da sala" if net.web else "IP de quem criou (ex.: 192.168.0.10)"
	le.custom_minimum_size = Vector2(0, 44)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.add_theme_font_size_override("font_size", 20)
	jh.add_child(le)
	var bj = _cbtn(jh, "Entrar", C_DEPLOY, func(): _online_join(le.text))
	bj.custom_minimum_size = Vector2(110, 44)
	le.text_submitted.connect(func(t): _online_join(t))
	if net.web and _is_touch():
		# celular: abre a caixa de texto do navegador, que sempre mostra o teclado
		le.focus_entered.connect(func():
			le.release_focus()
			var tx = net.ask_text("Código da sala (6 letras):")
			if tx.strip_edges() != "":
				le.text = tx.strip_edges().to_upper()
				_online_join(le.text))
	var codel = _label(v, "", 44, C_DEPLOY.lightened(0.3))
	codel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	codel.visible = false
	w["online_code"] = codel
	var cp = _cbtn(v, "Copiar código", C_HUD, func():
		net.copy_text(net.code)
		_online_set("Código copiado: %s. Mande para o outro jogador e deixe esta janela aberta." % net.code, C_DEPLOY.lightened(0.3)))
	cp.custom_minimum_size = Vector2(0, 34)
	cp.visible = false
	w["online_copy"] = cp
	var st = _label(v, "", 15, C_TXT)
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w["online_status"] = st
	var bc = _cbtn(v, "Cancelar", C_HUD, _online_cancel)
	bc.custom_minimum_size = Vector2(0, 38)


func _online_set(text: String, col: Color = C_TXT) -> void:
	if w.has("online_status") and is_instance_valid(w["online_status"]):
		w["online_status"].text = text
		w["online_status"].add_theme_color_override("font_color", col)


func _online_host() -> void:
	net.host()
	if w.has("online_code") and is_instance_valid(w["online_code"]):
		w["online_code"].text = net.code
		w["online_code"].visible = true
		w["online_copy"].visible = true
	_online_set("Criando a sala...")


func _online_join(c: String) -> void:
	if c.strip_edges() == "":
		_online_set("Digite o código da sala.", Color("#ffb070"))
		return
	net.join(c)
	_online_set("Procurando a sala...")


func _online_cancel() -> void:
	net.close()
	if w.has("online") and is_instance_valid(w["online"]):
		w["online"].queue_free()
	w.erase("online")


func _net_status(text: String) -> void:
	_online_set(text)


func _net_connected() -> void:
	_online_set("Conectado! Preparando a partida...", C_DEPLOY.lightened(0.3))
	if net.role == "guest":
		net.send({"t": "hello", "army": _my_army()})


func _net_msg(d: Dictionary) -> void:
	match d.get("t", ""):
		"hello":
			if net.role != "host" or stage != "army":
				return
			# quem criou a sala monta a partida: mapa, semente do sorteio e os dois exércitos
			DB.set_map(setup_cfg["map"])
			var sides = []
			var armies = [_my_army(), d["army"]]
			for p in range(2):
				var a = armies[p]
				var spots = DB.entry[p]
				sides.append({"fac": a["fac"], "cmd": a["cmd"], "mix": a["mix"], "picks": a["picks"], "start": [{"id": a["start"][0], "h": spots[0]}, {"id": a["start"][1], "h": spots[spots.size() - 1]}]})
			var sd = randi()
			net.send({"t": "start", "seed": sd, "map": setup_cfg["map"], "sides": sides})
			_online_begin(sides, sd, setup_cfg["map"], 0)
		"start":
			if net.role != "guest":
				return
			_online_begin(d["sides"], int(d["seed"]), d["map"], 1)
		"cmd":
			net_queue.append(d["c"])
			_net_pump()
		"ans":
			opp_thinking = false
			if game != null and stage == "battle" and online:
				game.ans_buf.append(d["v"])
				game.remote_ans.emit()
				refresh()
			else:
				net_pre_ans.append(d["v"])
		"bye":
			_net_closed("O oponente saiu da partida.")


func _online_begin(sides: Array, sd: int, map_id: String, who: int) -> void:
	online = true
	net_queue = []
	net_pre_ans = []
	me = who
	net_seed = sd
	setup_cfg["map"] = map_id
	planet_id = _planet_of_map(map_id)
	if w.has("online") and is_instance_valid(w["online"]):
		w["online"].queue_free()
	w.erase("online")
	stage = "dive"
	sfx.play("confirmar", -6.0)
	await _ui_fade(0.0, 0.4)
	sfx.play("vfx_portal", -6.0)
	sfx.stop_loop("musica_galaxia", 2.5)
	_fac_music("")
	galaxy.set_mode("dive", planet_id)
	await get_tree().create_timer(1.15).timeout
	await _fade(1.0, 0.55, galaxy.data(planet_id).get("dive", Color("#e0b070")))
	intro = true
	_start_match(sides)


# repete, em ordem, as jogadas que chegaram do outro aparelho
func _net_pump() -> void:
	if not online or game == null or net_busy or busy or running or net_queue.is_empty():
		return
	net_busy = true
	while not net_queue.is_empty() and game != null and online:
		var c = net_queue.pop_front()
		busy = true
		refresh()
		await game.exec_cmd(c)
		busy = false
		refresh()
		if game == null or game.winner != Game.NONE:
			break
	net_busy = false
	if game != null:
		await after()


func _net_closed(reason: String) -> void:
	if stage == "army" or stage == "dive":
		_online_set(reason, Color("#ff8a6a"))
		return
	if not online:
		return
	online = false
	net.close()
	if game != null and game.winner == Game.NONE and stage == "battle":
		banner("CONEXÃO PERDIDA", reason)
		var p = _panel(ui)
		_place(p, Control.PRESET_CENTER)
		var v = _vbox(p, 12)
		_label(v, "Conexão perdida", 40, C_GOLD)
		_label(v, reason, 18)
		_button(v, "Voltar ao menu", _show_menu)


func _game_over() -> void:
	if autotest:
		print("AUTOTESTE FIM: vencedor=%d round=%d eventos=%d" % [game.winner, game.round_no, game.logs.size()])
		for l in game.logs:
			if "usou" in l["text"]:
				print("  [r%d p%d] %s" % [l["round"], l["p"], l["text"]])
		get_tree().quit()
		return
	if w.has("over"):
		return
	var win = game.winner
	var title = "Empate" if win == Game.DRAW else ("Vitória!" if win == me else "Derrota")
	var reason = ""
	if not game.final_score.is_empty():
		var f = game.final_score
		var tt = f.get("t", [0, 0])
		reason = "Fim do round 10. Soma da vida dos personagens: %d x %d." % [tt[0], tt[1]]
	elif game.flagged != Game.NONE:
		reason = "Tempo esgotado: %s ficou sem tempo." % ("você" if game.flagged == me else _opp())
	elif win == Game.DRAW:
		reason = "Os dois comandantes caíram juntos."
	else:
		reason = "%s foi derrotado no round %d." % [DB.cards[game.commander(1 - win).cid]["name"], game.round_no]
	var p = _panel(ui)
	_place(p, Control.PRESET_CENTER)
	var v = _vbox(p, 12)
	_label(v, title, 56, C_GOLD)
	_label(v, reason, 18)
	var hb = _hbox(v, 10)
	if not online:
		_button(hb, "Revanche", func(): _start_match(last_sides))
		_button(hb, "Novos exércitos", _to_army)
	_button(hb, "Menu", _show_menu)
	_button(hb, "Ver o tabuleiro", func(): p.queue_free())
	w["over"] = p


func _is_touch() -> bool:
	if OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	return DisplayServer.is_touchscreen_available() and OS.has_feature("mobile")


# voz do personagem junto com o balão: "fala" (amigável), "prov" (provocação), "triste" (lamento)
# tom e velocidade de cada facção para a voz do aparelho (líderes)
const LEAD_VOICE = {
	"KRI": [0.75, 1.05], "WAC": [0.9, 0.95], "ZUK": [1.25, 1.15], "ABY": [0.6, 0.85],
	"TER": [0.7, 0.9], "LIT": [1.5, 1.0], "FAU": [1.1, 1.1],
}


func _leader_speak(u, text: String, mood: String) -> void:
	if not voice_on or text == "" or DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH) == false:
		return
	var vs = DisplayServer.tts_get_voices_for_language("pt")
	if vs.is_empty():
		vs = DisplayServer.tts_get_voices_for_language("pt-BR")
	if vs.is_empty():
		return
	var cfg = LEAD_VOICE.get(_fac_of(u), [1.0, 1.0])
	var pitch = float(cfg[0]) * (0.85 if mood == "triste" else (1.1 if mood == "prov" else 1.0))
	var vid = vs[int(abs(String(u.cid).hash())) % vs.size()]
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, vid, int(clamp(float(vol.get("Vozes", 90.0)), 0.0, 100.0)), clamp(pitch, 0.0, 2.0), clamp(float(cfg[1]), 0.1, 10.0))


func _talk_voice(u, text: String, mood: String) -> void:
	if sfx == null:
		return
	if u.is_cmd and voice_on:
		_leader_speak(u, text, mood)
		return
	var n = "v_%s_%s" % [u.cid, "prov" if mood == "prov" else "fala"]
	var pitch = 0.84 if mood == "triste" else randf_range(0.96, 1.05)
	var vol = 2.0 if mood == "prov" else 0.0
	sfx.play(n, vol, pitch, 0.0)
	# frases longas: o personagem continua falando
	if text.length() > 55:
		sfx.play_later(n, 0.78 / pitch, vol - 2.0, pitch * 0.94)


# ================= placas de vida (estilo da HUD) =================
func _make_plate(u) -> Dictionary:
	var col = C_YOU if u.owner == me else C_CPU
	var border = C_GOLD if u.is_cmd else col
	var W = 132.0
	var H = 42.0
	# placa de HQ: fundo no tom escuro do lado, contorno de tinta e sombra dura na cor do lado (impressão deslocada)
	var p = Panel.new()
	p.size = Vector2(W, H)
	var sb = StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.78)
	sb.border_color = Color("#0a0410")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(2)
	sb.shadow_color = (C_GOLD if u.is_cmd else col).darkened(0.1)
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(4, 4)
	sb.skew = Vector2(-0.12, 0)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w["plates"].add_child(p)
	var strip = ColorRect.new()
	strip.color = border
	strip.position = Vector2(0, 0)
	strip.size = Vector2(6, H)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(strip)
	var nl = Label.new()
	nl.text = "Barreira" if u.barrier else (("★ " if u.is_cmd else "") + _short(u.cid))
	nl.add_theme_font_size_override("font_size", 12)
	if font_btn != null:
		nl.add_theme_font_override("font", font_btn)
	nl.add_theme_color_override("font_color", Color.WHITE)
	nl.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.1))
	nl.add_theme_constant_override("outline_size", 4)
	nl.position = Vector2(10, 1)
	nl.size = Vector2(W - 44, 18)
	nl.clip_text = true
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(nl)
	var hl = Label.new()
	hl.add_theme_font_size_override("font_size", 21)
	if font_title != null:
		hl.add_theme_font_override("font", font_title)
	hl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hl.add_theme_constant_override("outline_size", 6)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hl.position = Vector2(W - 42, -4)
	hl.size = Vector2(34, 22)
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(hl)
	var bar = Control.new()
	bar.position = Vector2(10, 23)
	bar.size = Vector2(W - 16, 11)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(bar)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.size = bar.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bg)
	var ghost = ColorRect.new()
	ghost.color = Color(1, 0.95, 0.85, 0.95)
	ghost.size = Vector2(bar.size.x, bar.size.y)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(ghost)
	var fill = ColorRect.new()
	fill.size = Vector2(bar.size.x, bar.size.y)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(fill)
	for i in range(1, u.maxhp):
		var t = ColorRect.new()
		t.color = Color(0.02, 0.03, 0.07, 0.9)
		t.position = Vector2(bar.size.x * i / u.maxhp - 1.0, 0)
		t.size = Vector2(2, bar.size.y)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(t)
	var fl = Label.new()
	fl.add_theme_font_size_override("font_size", 11)
	fl.add_theme_color_override("font_color", Color("#ffcf6a"))
	fl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	fl.add_theme_constant_override("outline_size", 4)
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fl.position = Vector2(0, -18)
	fl.size = Vector2(W, 16)
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.visible = false
	p.add_child(fl)
	return {"panel": p, "hp": hl, "fill": fill, "ghost": ghost, "flags": fl, "bw": bar.size.x, "shown": float(u.hp), "ghost_v": float(u.hp), "last": u.hp, "flash": 0.0}


func _update_plates(delta: float) -> void:
	if not w.has("plates") or not is_instance_valid(w["plates"]):
		return
	# as placas de vida no campo foram removidas: a vida aparece no painel da esquerda
	for k in plates.keys():
		if is_instance_valid(plates[k]["panel"]):
			plates[k]["panel"].visible = false
	if true:
		return
	var seen = {}
	var sc = clamp(40.0 / max(board.cam_dist, 1.0), 0.7, 1.15)   # de longe as barras encolhem e não se amontoam
	for uid in board.unit_nodes.keys():
		var u: Variant = game.by_uid(uid)
		if u == null or u.crystal != "":
			continue
		seen[uid] = true
		if not plates.has(uid) or not is_instance_valid(plates[uid]["panel"]):
			plates[uid] = _make_plate(u)
		var pl = plates[uid]
		var d = board.unit_nodes[uid]
		# a barra de vida fica colada na cabeça do personagem
		var wp = d["node"].position + Vector3(0, d.get("top", 1.75) * d["node"].scale.y * 0.92, 0)
		var p: Panel = pl["panel"]
		if board.cam.is_position_behind(wp) or d["node"].scale.y < 0.3:
			p.visible = false
			continue
		p.visible = true
		# vida: a barra desce suave e um rastro claro mostra o dano levado
		if u.hp < pl["last"]:
			pl["flash"] = 1.0
		pl["last"] = u.hp
		pl["shown"] = lerp(pl["shown"], float(u.hp), min(1.0, delta * 10.0))
		if pl["ghost_v"] > pl["shown"]:
			pl["ghost_v"] = max(pl["shown"], pl["ghost_v"] - delta * 2.5)
		else:
			pl["ghost_v"] = pl["shown"]
		var frac = clamp(pl["shown"] / max(1.0, float(u.maxhp)), 0.0, 1.0)
		pl["fill"].size.x = pl["bw"] * frac
		pl["ghost"].size.x = pl["bw"] * clamp(pl["ghost_v"] / max(1.0, float(u.maxhp)), 0.0, 1.0)
		# barra na cor do lado; só vira amarelo e vermelho quando a vida cai
		var side_c = (C_YOU if u.owner == me else C_CPU).lightened(0.15)
		var hc = side_c if frac > 0.6 else (Color("#ffcf3a") if frac > 0.34 else Color("#ff3b3b"))
		pl["flash"] = max(0.0, pl["flash"] - delta * 3.0)
		var fcol = hc.lerp(Color.WHITE, pl["flash"] * 0.8)
		if pl["fill"].color != fcol:
			pl["fill"].color = fcol
		var hpt = str(u.hp)
		if pl["hp"].text != hpt:
			pl["hp"].text = hpt
			pl["hp"].add_theme_color_override("font_color", hc.lightened(0.25))
		elif pl.get("hc", Color.BLACK) != hc:
			pl["hp"].add_theme_color_override("font_color", hc.lightened(0.25))
		pl["hc"] = hc
		var fl = []
		if u.eq != "":
			fl.append(u.eq.to_upper())
		if game.rooted(u):
			fl.append("PRESO")
		elif game.slowed(u):
			fl.append("LENTO")
		if game.silenced(u):
			fl.append("SEM HAB.")
		if game.has_fx(u, "mark"):
			fl.append("ALVO")
		var flt = " · ".join(fl)
		if pl["flags"].text != flt:
			pl["flags"].text = flt
		var flv = not fl.is_empty()
		if pl["flags"].visible != flv:
			pl["flags"].visible = flv
		var shake = Vector2(sin(Time.get_ticks_msec() * 0.09) * 3.0 * pl["flash"], 0)
		p.scale = Vector2.ONE * sc * (1.0 + pl["flash"] * 0.12)
		p.pivot_offset = Vector2(p.size.x * 0.5, p.size.y)
		var spos = board.cam.unproject_position(wp)
		p.position = spos - Vector2(p.size.x * 0.5, p.size.y) + shake
		# quem está agindo fica por cima
		p.modulate = Color(1, 1, 1, 1.0)
	for uid in plates.keys():
		if not seen.has(uid):
			if is_instance_valid(plates[uid]["panel"]):
				plates[uid]["panel"].queue_free()
			plates.erase(uid)


# ================= tamanho da interface (celular / tablet / PC) =================
func _load_prefs() -> void:
	var cf = ConfigFile.new()
	if cf.load("user://prefs.cfg") == OK:
		ui_pref = str(cf.get_value("ui", "scale", "auto"))
		fast_mode = bool(cf.get_value("ui", "fast", false))
		voice_on = bool(cf.get_value("ui", "voice", true))
		rgb_on = bool(cf.get_value("video", "rgb1", true))
		for b in vol.keys():
			vol[b] = float(cf.get_value("som", b, vol[b]))
		res_pref = str(cf.get_value("video", "res", res_pref))
		fullscreen = bool(cf.get_value("video", "full", false))
		render_q = float(cf.get_value("video", "q", 1.0))


func _save_prefs() -> void:
	var cf = ConfigFile.new()
	cf.set_value("ui", "scale", ui_pref)
	cf.set_value("ui", "fast", fast_mode)
	cf.set_value("ui", "voice", voice_on)
	for b in vol.keys():
		cf.set_value("som", b, vol[b])
	cf.set_value("video", "res", res_pref)
	cf.set_value("video", "full", fullscreen)
	cf.set_value("video", "q", render_q)
	cf.set_value("video", "rgb1", rgb_on)
	cf.save("user://prefs.cfg")


func _auto_scale() -> float:
	# tamanho real da tela em "pixels de navegador": celular deitado tem ~360-430 de altura
	var win = get_window()
	var dpr = max(1.0, DisplayServer.screen_get_scale())
	var short = min(float(win.size.x), float(win.size.y)) / dpr
	var want_h = clamp(short * 1.45, 560.0, 900.0)
	return clamp(900.0 / want_h, 1.0, 1.75)


func _apply_ui_scale() -> void:
	var f = _auto_scale() if ui_pref == "auto" else float(ui_pref) / 100.0
	if abs(get_tree().root.content_scale_factor - f) > 0.01:
		get_tree().root.content_scale_factor = f
	var was = compact
	compact = get_viewport().get_visible_rect().size.y < 720.0
	if was != compact and stage == "battle" and game != null:
		_build_hud()
		refresh()


func _cycle_ui_scale(rebuild: bool = true) -> void:
	var opts = ["auto", "100", "125", "150", "175"]
	ui_pref = opts[(opts.find(ui_pref) + 1) % opts.size()]
	_save_prefs()
	_apply_ui_scale()
	if rebuild:
		_show_menu()


func _ui_scale_label() -> String:
	return "Interface: " + ("automática" if ui_pref == "auto" else ui_pref + "%")


func _toggle_cpu() -> void:
	cpu_open = not cpu_open
	if w.has("party1_panel"):
		w["party1_panel"].visible = cpu_open or not compact


# ================= mão inicial: cartas grandes no centro =================
func _show_mull(ids: Array) -> void:
	if w.has("mull") and is_instance_valid(w["mull"]):
		return
	if w.has("hand"):
		w["hand"].visible = false
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(root)
	w["mull"] = root
	var dim = ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var col = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	var tl = _label(col, "SUA MÃO INICIAL", 26, C_GOLD)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	var vh = get_viewport().get_visible_rect().size.y
	var k = clamp((vh - 260.0) / 172.0, 1.0, 1.8)
	for id in ids:
		var holder = Control.new()
		var base = Vector2(118, 150) if compact else Vector2(128, 172)
		holder.custom_minimum_size = base * k
		holder.tooltip_text = "%s (%s)\n%s" % [DB.tactics[id]["name"], DB.tactics[id]["type"], DB.tactics[id]["text"]]
		holder.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(holder)
		var card = _make_card(id)
		card.modulate = Color.WHITE
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for c in card.get_children():
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.scale = Vector2(k, k)
		holder.add_child(card)
		# entra deslizando de baixo
		holder.modulate.a = 0.0
		var tw = holder.create_tween()
		tw.tween_interval(0.08 * ids.find(id))
		tw.tween_property(holder, "modulate:a", 1.0, 0.25)
	var br = HBoxContainer.new()
	br.alignment = BoxContainer.ALIGNMENT_CENTER
	br.add_theme_constant_override("separation", 18)
	br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(br)
	var b1 = _cbtn(br, "MANTER A MÃO", C_HUD, func(): _answer(false))
	b1.custom_minimum_size = Vector2(230, 54)
	var b2 = _cbtn(br, "TROCAR A MÃO", C_GOLD, func(): _answer(true))
	_primary(b2)
	b2.custom_minimum_size = Vector2(230, 54)


func _hide_mull() -> void:
	if w.has("hand") and is_instance_valid(w["hand"]):
		w["hand"].visible = true
	if w.has("mull"):
		if is_instance_valid(w["mull"]):
			w["mull"].queue_free()
		w.erase("mull")


# ================= verme gigante =================
var omen_t: float = 0.0


# enquanto há casas marcadas: a areia ronca, levanta poeira e o chão treme de leve
func _tremor_omen(delta: float) -> void:
	if game.tremors.is_empty():
		return
	omen_t -= delta
	if omen_t > 0.0:
		return
	omen_t = randf_range(2.2, 3.6)
	sfx.play("verme_rumor", -9.0, randf_range(0.55, 0.75), 0.1)
	board.shake = max(board.shake, 0.18)
	for h in game.tremors:
		vfx.dust_burst(_hex_pos(h, 0.0), false)


func _on_worm_roar(pos: Vector3) -> void:
	board.shake = 1.4
	sfx.play("verme_ataque", 4.0, 0.62, 0.05)
	sfx.play_later("verme_ataque", 0.12, 0.0, 0.48)
	sfx.play("verme_rumor", 2.0, 0.5)
	vfx.dust_burst(pos, true)
	vfx.flip("sonic", pos + Vector3(0, 8.0, 0), 6.0, 0.9, Color("#ffcf9a"))
	vfx.flip("ring", pos, 7.0, 0.8, Color("#ff7a3a"), true)
	_flash_screen(Color(0.6, 0.02, 0.0, 0.35), 0.6)


func _on_worm_bite(pos: Vector3) -> void:
	board.shake = max(board.shake, 1.0)
	sfx.play("explosao", 0.0, 0.6)
	vfx.dust_burst(pos, true)
	vfx.flip("boom", pos, 5.0, 0.8, Color(1, 0.8, 0.6))
	vfx.flip("rock", pos, 4.0, 0.7)


func _flash_screen(col: Color, dur: float) -> void:
	var r = ColorRect.new()
	r.color = col
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(r)
	var tw = r.create_tween()
	tw.tween_property(r, "color:a", 0.0, dur)
	tw.tween_callback(r.queue_free)


# ================= entrada dos exércitos =================
const FAC_ENTRY = {"FAU": "entrada_fau", "ABY": "entrada_aby", "KRI": "entrada_kri", "WAC": "entrada_wac", "ZUK": "entrada_zuk", "LIT": "entrada_lit", "TER": "entrada_ter"}
var skip_entry: bool = false


func _map_music() -> void:
	if game == null:
		return
	if game.map_id == "tarhut":
		sfx.loop("musica_deserto", -9.0, 3.0)
	elif game.map_id == "abnara":
		sfx.loop("musica_abnara", -8.0, 3.0)
	elif game.map_id == "goraida":
		sfx.loop("musica_goraida", -8.0, 3.0)
	else:
		sfx.loop("musica_valak", -7.0, 3.0)


func _wait(sec: float) -> void:
	var t = 0.0
	while t < sec and not skip_entry:
		await get_tree().process_frame
		t += get_process_delta_time()


# cada exército chega ao campo com a sua música-tema: primeiro o seu, depois o da CPU
func _entrance() -> void:
	skip_entry = false
	busy = true
	for u in game.field():
		board.hidden_uids[u.uid] = true
	# esconde a HUD (fica só a camada da cena)
	for c in ui.get_children():
		if c == w.get("bubbles") or c == w.get("plates"):
			continue
		c.set_meta("was_vis", c.visible)
		c.visible = false
	var layer = Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(layer)
	var skip = _cbtn(layer, "Pular  ▶", C_HUD, func(): skip_entry = true)
	skip.custom_minimum_size = Vector2(150, 44)
	_place(skip, Control.PRESET_BOTTOM_RIGHT, 18)
	if ui.modulate.a < 1.0:
		_ui_fade(1.0, 0.6)
	await _wait(1.6)
	for p in [0, 1]:
		if skip_entry:
			break
		await _entrance_side(p, layer)
	for uid in board.hidden_uids.keys():
		var u: Variant = game.by_uid(uid)
		if u != null:
			vfx.summon_fx(_hex_pos(u.pos(), 0.0), _unit_color(uid))
	board.hidden_uids.clear()
	layer.queue_free()
	for c in ui.get_children():
		if c.has_meta("was_vis"):
			c.visible = c.get_meta("was_vis")
			c.remove_meta("was_vis")
	board.cam_speed = 3.0
	board.fit_camera(false)
	_later(2.0, func(): board.cam_speed = 8.0)
	_map_music()
	refresh()


func _entrance_side(p: int, layer: Control) -> void:
	var fac = game.P[p]["fac"]
	var fcol = Color(DB.factions[fac]["color"])
	var ec = DB.entry_c[p]
	var ew = board.world_xz(ec)
	var tgt = Vector3(ew.x, 0.6, ew.y)
	var to_c = Vector2(-ew.x, -ew.y).normalized()
	board.cam_speed = 2.2
	board.cam_goal = {"yaw": atan2(to_c.x, to_c.y), "pitch": 0.45, "dist": 10.5, "target": tgt}
	sfx.play(FAC_ENTRY.get(fac, ""), -1.0, 1.0, 0.0)
	# cartão da facção: retrato do comandante, nome e quem é
	var card = PanelContainer.new()
	# faixa de HQ: inclinada, fundo no tom escuro da facção, contorno de tinta e sombra dura na cor da facção
	var fb = StyleBoxFlat.new()
	fb.bg_color = fcol.darkened(0.72)
	fb.border_color = Color("#0a0410")
	fb.set_border_width_all(4)
	fb.set_corner_radius_all(2)
	fb.shadow_color = fcol
	fb.shadow_size = 1
	fb.shadow_offset = Vector2(9, 8)
	fb.skew = Vector2(-0.14, 0)
	fb.set_content_margin_all(14)
	fb.content_margin_left = 30
	fb.content_margin_right = 34
	card.add_theme_stylebox_override("panel", fb)
	layer.add_child(card)
	var h = _hbox(card, 14)
	var cid = game.P[p].get("cmd", DB.factions[fac]["cmd"])
	if DB.portraits.has(cid):
		h.add_child(_tex_rect(DB.portraits[cid], Vector2(110, 110)))
	var v = _vbox(h, 2)
	_label(v, "VOCÊ" if p == me else "ADVERSÁRIO", 13, C_YOU if p == me else C_CPU)
	var fn = _label(v, "EXÉRCITO MISTO" if game.P[p].get("mix", false) else DB.factions[fac]["name"].to_upper(), 40, fcol.lightened(0.35))
	if font_title != null:
		fn.add_theme_font_override("font", font_title)
	fn.add_theme_constant_override("outline_size", 10)
	_label(v, "Comandante: %s · chega no round 4" % DB.cards[cid]["name"], 15, C_DIM)
	card.position = Vector2(-700, 70) if p == me else Vector2(get_viewport().get_visible_rect().size.x + 100, 70)
	var goal_x = 40.0 if p == me else get_viewport().get_visible_rect().size.x - 40.0
	await get_tree().process_frame
	if p == 1:
		goal_x -= card.size.x
	var tw = card.create_tween()
	tw.tween_property(card, "position:x", goal_x, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(1.6)
	# as peças chegam uma a uma (portal + queda) e falam ao entrar
	var units = game.field().filter(func(x): return x.owner == p and not x.barrier)
	for u in units:
		if skip_entry:
			break
		board.hidden_uids.erase(u.uid)
		var hp = _hex_pos(u.pos(), 0.0)
		vfx.flip("portal", hp, 2.6, 0.7, fcol.lightened(0.4), true)
		vfx.summon_fx(hp, fcol)
		vfx.dust_burst(hp, true)
		board.shake = max(board.shake, 0.3)
		sfx.play("invocar", -4.0)
		_voice(u.uid, "atk", -1.0, 0.2)
		var line = _line("entrada", u)
		if line != "":
			_say(u.uid, line, 0.5, "fala")
		await _wait(1.7)
	await _wait(1.3)
	var tw2 = card.create_tween()
	tw2.tween_property(card, "modulate:a", 0.0, 0.4)
	tw2.tween_callback(card.queue_free)

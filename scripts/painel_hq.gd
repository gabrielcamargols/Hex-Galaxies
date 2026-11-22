extends PanelContainer
class_name PainelHQ
## Moldura da HUD no estilo "balão inclinado": corpo escuro em paralelogramo, contorno fino,
## sombra dura e duas quinas com faixa em degradê (acento). Opcional: rabicho serrilhado à
## esquerda (balão de fala) apontando para quem fala.
## O desenho é todo feito aqui (_draw); o stylebox só guarda as margens do conteúdo.

const INCL := 0.16          # quanto o paralelogramo inclina (fração da altura)
const SOMBRA := Vector2(5, 5)

var acento_a: Color = Color("#27ddf4")   # começo do degradê das quinas
var acento_b: Color = Color("#3d5bff")   # fim do degradê
var fundo: Color = Color(0.07, 0.05, 0.12, 0.94)
var contorno: Color = Color(1, 1, 1, 0.92)
var cauda: bool = false      # rabicho de balão de fala (lado esquerdo)
var quinas: bool = true      # faixas de acento


func _init() -> void:
	var sb = StyleBoxEmpty.new()
	sb.content_margin_left = 28   # folga para a lateral inclinada
	sb.content_margin_right = 28
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	add_theme_stylebox_override("panel", sb)
	resized.connect(queue_redraw)


func margens(h: float, v: float) -> void:
	var sb = get_theme_stylebox("panel")
	if not sb is StyleBoxEmpty:
		return
	sb.content_margin_left = h + 8.0 + (14.0 if cauda else 0.0)
	sb.content_margin_right = h
	sb.content_margin_top = v
	sb.content_margin_bottom = v


func cores(a: Color, b: Color) -> void:
	acento_a = a
	acento_b = b
	queue_redraw()


func _forma(ofs: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var w = size.x
	var h = size.y
	var k = min(h * INCL, 18.0)
	var x0 = 14.0 if cauda else 0.0
	var p = PackedVector2Array([Vector2(x0 + k, 0), Vector2(w, 0), Vector2(w - k, h), Vector2(x0, h)])
	if cauda:
		# rabicho serrilhado saindo da lateral esquerda, perto do meio
		var my = h * 0.55
		var pts = PackedVector2Array([p[0], p[1], p[2], p[3]])
		var ex = x0 + k * (1.0 - my / h)
		pts = PackedVector2Array([p[0], p[1], p[2], p[3],
			Vector2(ex - 1, my + 8), Vector2(0, my + 2), Vector2(ex - 6, my - 3), Vector2(4, my - 12), Vector2(ex + 2, my - 8)])
		p = pts
	for i in p.size():
		p[i] += ofs
	return p


func _draw() -> void:
	if size.x < 4 or size.y < 4 or not get_theme_stylebox("panel") is StyleBoxEmpty:
		return   # quem trocou o stylebox desenha do seu jeito
	var w = size.x
	var h = size.y
	var k = min(h * INCL, 18.0)
	var x0 = 14.0 if cauda else 0.0
	# sombra dura
	draw_colored_polygon(_forma(SOMBRA), Color(0, 0, 0, 0.75))
	# corpo
	var f = _forma()
	draw_colored_polygon(f, fundo)
	# contorno fino
	var fl = PackedVector2Array(f)
	fl.append(f[0])
	draw_polyline(fl, contorno, 2.0, true)
	if not quinas:
		return
	# quina de cima à esquerda: faixa em degradê descendo pela lateral inclinada e seguindo pelo topo
	var t = 7.0
	var lt = min(96.0, w * 0.35)
	var lv = min(h * 0.6, 54.0)
	var a0 = Vector2(x0 + k, 0)
	var dir_l = (Vector2(x0, h) - a0).normalized()
	var p_top = PackedVector2Array([a0 + Vector2(lt, 0), a0, a0 + dir_l * lv, a0 + dir_l * lv + Vector2(t, 0), a0 + Vector2(t, t), a0 + Vector2(lt, t)])
	draw_polygon(p_top, PackedColorArray([acento_b, acento_a, acento_b, acento_b, acento_a, acento_b]))
	# quina de baixo à direita
	var b0 = Vector2(w - k, h)
	var dir_r = (Vector2(w, 0) - b0).normalized()
	var p_bot = PackedVector2Array([b0 - Vector2(lt, 0), b0, b0 + dir_r * lv, b0 + dir_r * lv - Vector2(t, 0), b0 - Vector2(t, t), b0 - Vector2(lt, t)])
	draw_polygon(p_bot, PackedColorArray([acento_b, acento_a, acento_b, acento_b, acento_a, acento_b]))
	# lasca branca (o "brilho" da ponta, como no balão de referência)
	draw_colored_polygon(PackedVector2Array([Vector2(w - 26, 3), Vector2(w - 4, 3), Vector2(w - 4 - k * 0.5, 12), Vector2(w - 34, 12)]), Color(1, 1, 1, 0.85))

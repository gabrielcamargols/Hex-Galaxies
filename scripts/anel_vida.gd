extends Control
class_name AnelVida
## Medidor circular de vida em volta do retrato (como o medidor redondo da referência):
## trilho escuro, arco em degradê (verde > amarelo > vermelho conforme a vida cai),
## ponta branca brilhando e o número no selo de baixo.

var retrato: Texture2D
var vida: int = 0
var vida_max: int = 1
var cor_lado: Color = Color("#3d8bff")


func _init() -> void:
	custom_minimum_size = Vector2(84, 92)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func mostra(tex: Texture2D, hp: int, maxhp: int, lado: Color) -> void:
	retrato = tex
	vida = max(0, hp)
	vida_max = max(1, maxhp)
	cor_lado = lado
	queue_redraw()


func _cor(f: float) -> Color:
	if f > 0.6:
		return Color("#5cff7a")
	if f > 0.3:
		return Color("#ffd23a")
	return Color("#ff4a5a")


func _draw() -> void:
	var c = Vector2(size.x / 2.0, 40.0)
	var r = 34.0
	# sombra dura e trilho
	draw_circle(c + Vector2(3, 3), r + 6, Color(0, 0, 0, 0.7))
	draw_circle(c, r + 6, Color("#120a1e"))
	draw_arc(c, r, 0, TAU, 64, Color(1, 1, 1, 0.12), 7.0, true)
	# retrato recortado no círculo (polígono com UV)
	if retrato != null:
		var pts = PackedVector2Array()
		var uvs = PackedVector2Array()
		var rr = r - 6.0
		for i in 40:
			var a = TAU * i / 40.0
			var d = Vector2(cos(a), sin(a))
			pts.append(c + d * rr)
			uvs.append(Vector2(0.5, 0.42) + d * 0.5)
		draw_colored_polygon(pts, cor_lado.darkened(0.6))
		draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, retrato)
	# arco de vida: começa em cima e gira no sentido horário
	var f = clamp(float(vida) / float(vida_max), 0.0, 1.0)
	var a0 = -PI / 2.0
	var a1 = a0 + TAU * f
	if f > 0.0:
		var col = _cor(f)
		var n = max(4, int(48 * f))
		for i in n:
			var t0 = a0 + (a1 - a0) * i / n
			var t1 = a0 + (a1 - a0) * (i + 1) / n
			var k = float(i) / n
			draw_arc(c, r, t0, t1 + 0.01, 3, col.darkened(0.35).lerp(col.lightened(0.2), k), 7.0, true)
		var tip = c + Vector2(cos(a1), sin(a1)) * r
		draw_circle(tip, 5.0, Color(1, 1, 1, 0.95))
	# selo com o número
	var s = Rect2(Vector2(size.x / 2.0 - 26, 72), Vector2(52, 20))
	var pol = PackedVector2Array([s.position + Vector2(6, 0), s.position + Vector2(s.size.x, 0), s.end - Vector2(6, 0), s.position + Vector2(0, s.size.y)])
	draw_colored_polygon(pol, Color("#120a1e"))
	var pl = PackedVector2Array(pol)
	pl.append(pol[0])
	draw_polyline(pl, _cor(f), 2.0, true)
	var fnt = get_theme_default_font()
	var txt = "%d/%d" % [vida, vida_max]
	var tw = fnt.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(fnt, Vector2(size.x / 2.0 - tw / 2.0, 87), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

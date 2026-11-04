extends Node
## Conexão online entre dois aparelhos.
## - Navegador: PeerJS (servidor público gratuito só para os dois se encontrarem; depois a
##   conexão é direta entre os aparelhos). Sala = código de 6 letras.
## - PC / Android instalado: TCP direto na rede local. Sala = IP de quem criou.
## - Teste local no navegador: ?net=local na URL usa BroadcastChannel entre abas.
## As mensagens são Dictionaries convertidos com var_to_str (aceita Vector2i, null etc.).

signal connected           # o outro jogador entrou
signal message(d)          # chegou uma mensagem
signal closed(reason)      # conexão caiu ou não deu certo
signal status(text)        # andamento ("Sala criada", "Conectando"...)

const PORT = 47120
const PEERJS = "https://unpkg.com/peerjs@1.5.4/dist/peerjs.min.js"
const LETTERS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var role := ""             # "host" ou "guest"
var code := ""
var is_open := false
var web := false
# nativo
var server: TCPServer = null
var tcp: StreamPeerTCP = null
var pps: PacketPeerStream = null


func _ready() -> void:
	web = OS.has_feature("web")
	if web:
		JavaScriptBridge.eval(_JS, true)


func new_code() -> String:
	var c = ""
	for i in range(6):
		c += LETTERS[randi() % LETTERS.length()]
	return c


func host() -> void:
	close()
	role = "host"
	if web:
		code = new_code()
		JavaScriptBridge.eval("window.hexNet.host(%s)" % JSON.stringify(code), true)
	else:
		server = TCPServer.new()
		var err = server.listen(PORT)
		if err != OK:
			closed.emit("Não foi possível abrir a sala (porta %d ocupada)." % PORT)
			return
		code = _local_ip()
		status.emit("Sala criada. Peça para o outro jogador entrar com: %s" % code)


func join(c: String) -> void:
	close()
	role = "guest"
	code = c.strip_edges().to_upper()
	if web:
		JavaScriptBridge.eval("window.hexNet.join(%s)" % JSON.stringify(code), true)
	else:
		tcp = StreamPeerTCP.new()
		var err = tcp.connect_to_host(c.strip_edges(), PORT)
		if err != OK:
			closed.emit("Endereço inválido.")
			return
		status.emit("Conectando a %s..." % c)


func send(d: Dictionary) -> void:
	if not is_open:
		return
	var s = var_to_str(d)
	if web:
		JavaScriptBridge.eval("window.hexNet.send(%s)" % JSON.stringify(s), true)
	elif pps != null:
		pps.put_packet(s.to_utf8_buffer())


func close() -> void:
	is_open = false
	role = ""
	if web:
		JavaScriptBridge.eval("window.hexNet && window.hexNet.close()", true)
	if tcp != null:
		tcp.disconnect_from_host()
	tcp = null
	pps = null
	if server != null:
		server.stop()
	server = null


func _local_ip() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			return a
	return "127.0.0.1"


func _got(s: String) -> void:
	var v = str_to_var(s)
	if v is Dictionary:
		message.emit(v)


func _process(_dt: float) -> void:
	if web:
		var raw = JavaScriptBridge.eval("window.hexNet ? window.hexNet.poll() : '[]'", true)
		if raw == null or str(raw) == "[]":
			return
		var evs = JSON.parse_string(str(raw))
		if evs == null:
			return
		for e in evs:
			match e["k"]:
				"status":
					status.emit(e["v"])
				"open":
					is_open = true
					connected.emit()
				"msg":
					_got(e["v"])
				"close":
					if is_open or role != "":
						is_open = false
						closed.emit(e["v"])
		return
	# nativo
	if server != null and tcp == null and server.is_connection_available():
		tcp = server.take_connection()
		pps = PacketPeerStream.new()
		pps.stream_peer = tcp
		is_open = true
		connected.emit()
	if tcp == null:
		return
	tcp.poll()
	var st = tcp.get_status()
	if st == StreamPeerTCP.STATUS_CONNECTED and pps == null:
		pps = PacketPeerStream.new()
		pps.stream_peer = tcp
		is_open = true
		connected.emit()
	elif st == StreamPeerTCP.STATUS_ERROR or (st == StreamPeerTCP.STATUS_NONE and is_open):
		var was = is_open
		close()
		closed.emit("O outro jogador saiu." if was else "Não foi possível conectar.")
		return
	if pps != null:
		while pps.get_available_packet_count() > 0:
			_got(pps.get_packet().get_string_from_utf8())


const _JS = """
(function(){
if (window.hexNet) return;
var N = {inbox: [], peer: null, conn: null, bc: null};
function push(k, v){ N.inbox.push({k: k, v: v}); }
N.poll = function(){ var s = JSON.stringify(N.inbox); N.inbox = []; return s; };
var local = /[?&]net=local/.test(location.search);
function load(cb){
  if (local || window.Peer) { cb(); return; }
  var s = document.createElement('script');
  s.src = '""" + PEERJS + """';
  s.onload = cb;
  s.onerror = function(){ push('close', 'Sem acesso ao servidor de salas. Verifique a internet.'); };
  document.head.appendChild(s);
}
function wire(c){
  N.conn = c;
  c.on('open', function(){ push('open', ''); });
  c.on('data', function(d){ push('msg', String(d)); });
  c.on('close', function(){ push('close', 'O outro jogador saiu.'); });
  c.on('error', function(e){ push('close', 'Erro na conexão: ' + e); });
}
function bcWire(code, role){
  N.bc = new BroadcastChannel('hexgal-' + code);
  N.bc.onmessage = function(ev){
    var m = ev.data;
    if (m.k === 'hello' && role === 'host') { N.bc.postMessage({k: 'welcome'}); push('open', ''); }
    else if (m.k === 'welcome' && role === 'guest') { push('open', ''); }
    else if (m.k === 'msg' && m.from !== role) { push('msg', m.v); }
    else if (m.k === 'bye' && m.from !== role) { push('close', 'O outro jogador saiu.'); }
  };
  N.role = role;
  N.conn = {send: function(s){ N.bc.postMessage({k: 'msg', v: s, from: role}); }, close: function(){ N.bc.postMessage({k: 'bye', from: role}); }};
}
N.host = function(code){
  load(function(){
    if (local) { bcWire(code, 'host'); push('status', 'Sala ' + code + ' criada. Aguardando o outro jogador...'); return; }
    N.peer = new Peer('hexgal-' + code.toLowerCase());
    N.peer.on('open', function(){ push('status', 'Sala ' + code + ' criada. Aguardando o outro jogador...'); });
    N.peer.on('connection', function(c){ if (N.conn) { c.close(); return; } wire(c); });
    N.peer.on('error', function(e){ push('close', e.type === 'unavailable-id' ? 'Esse código já está em uso. Crie outra sala.' : 'Erro no servidor de salas: ' + e.type); });
  });
};
N.join = function(code){
  load(function(){
    if (local) { bcWire(code, 'guest'); N.bc.postMessage({k: 'hello'}); push('status', 'Procurando a sala ' + code + '...'); return; }
    N.peer = new Peer();
    N.peer.on('open', function(){
      push('status', 'Procurando a sala ' + code + '...');
      wire(N.peer.connect('hexgal-' + code.toLowerCase(), {reliable: true}));
    });
    N.peer.on('error', function(e){ push('close', e.type === 'peer-unavailable' ? 'Sala ' + code + ' não encontrada. Confira o código.' : 'Erro no servidor de salas: ' + e.type); });
  });
};
N.send = function(s){ if (N.conn) N.conn.send(s); };
N.close = function(){
  try { if (N.conn) N.conn.close(); } catch(e) {}
  try { if (N.peer) N.peer.destroy(); } catch(e) {}
  try { if (N.bc) N.bc.close(); } catch(e) {}
  N.conn = null; N.peer = null; N.bc = null;
};
window.hexNet = N;
})();
"""

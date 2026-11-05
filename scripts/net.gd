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


# celular no navegador: caixa de texto do próprio navegador (sempre abre o teclado)
func ask_text(t: String) -> String:
	if not web:
		return ""
	return str(JavaScriptBridge.eval("window.hexNet.ask(%s)" % JSON.stringify(t), true))


func copy_text(t: String) -> void:
	if web:
		JavaScriptBridge.eval("window.hexNet.copy(%s)" % JSON.stringify(t), true)
	else:
		DisplayServer.clipboard_set(t)


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
var N = {inbox: [], peer: null, conn: null, bc: null, timer: null};
function push(k, v){ N.inbox.push({k: k, v: v}); try { console.log('HEXNET ' + k + ' ' + v); } catch(e) {} }
// servidores que ajudam a conexão a atravessar roteadores e a rede do celular
var ICE = {iceServers: [
  {urls: 'stun:stun.l.google.com:19302'},
  {urls: 'stun:stun1.l.google.com:19302'},
  {urls: 'stun:global.stun.twilio.com:3478'},
  {urls: ['turn:eu-0.turn.peerjs.com:3478', 'turn:us-0.turn.peerjs.com:3478'], username: 'peerjs', credential: 'peerjsp'}
], sdpSemantics: 'unified-plan'};
function erro(t){
  var m = {
    'peer-unavailable': 'Sala não encontrada. Confira o código (e se quem criou ainda está com a janela aberta).',
    'unavailable-id': 'Esse código já está em uso. Crie outra sala.',
    'network': 'Sem conexão com o servidor de salas. Verifique a internet.',
    'server-error': 'O servidor de salas não respondeu. Tente de novo em instantes.',
    'socket-error': 'Sem conexão com o servidor de salas. Verifique a internet.',
    'socket-closed': 'A conexão com o servidor de salas caiu.',
    'browser-incompatible': 'Este navegador não permite jogar online. Tente o Chrome atualizado.',
    'webrtc': 'A conexão direta entre os aparelhos falhou. Tente outra rede (Wi-Fi/4G).'
  };
  return m[t] || ('Erro na conexão: ' + t);
}
function armTimeout(){
  clearTimeout(N.timer);
  N.timer = setTimeout(function(){
    if (N.conn && N.conn.open) return;
    push('close', 'Não foi possível conectar com o outro aparelho em 25 segundos. As redes podem estar bloqueando a conexão direta: tentem os dois no Wi-Fi, ou um no Wi-Fi e outro no 4G, e criem uma sala nova.');
  }, 25000);
}
N.poll = function(){ var s = JSON.stringify(N.inbox); N.inbox = []; return s; };
var local = /[?&]net=local/.test(location.search);
function load(cb){
  if (local || window.Peer) { cb(); return; }
  var s = document.createElement('script');
  s.src = '""" + PEERJS + """';
  s.onload = cb;
  s.onerror = function(){ push('close', 'Não foi possível carregar o sistema online. Verifique a internet ou desative o bloqueador de anúncios para este site.'); };
  document.head.appendChild(s);
}
function wire(c){
  N.conn = c;
  c.on('open', function(){ clearTimeout(N.timer); push('open', ''); });
  c.on('data', function(d){ push('msg', String(d)); });
  c.on('close', function(){ push('close', 'O outro jogador saiu.'); });
  c.on('error', function(e){ push('close', erro(e && e.type ? e.type : String(e))); });
  if (c.peerConnection) {
    c.peerConnection.addEventListener('iceconnectionstatechange', function(){
      var st = c.peerConnection.iceConnectionState;
      if (st === 'failed') push('close', erro('webrtc'));
    });
  }
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
    N.peer = new Peer('hexgal-' + code.toLowerCase(), {config: ICE, debug: 1});
    N.peer.on('open', function(){ push('status', 'Sala ' + code + ' criada. Passe o código para o outro jogador e deixe esta janela aberta.'); });
    N.peer.on('connection', function(c){ if (N.conn) { c.close(); return; } push('status', 'O outro jogador chegou. Conectando...'); armTimeout(); wire(c); });
    N.peer.on('error', function(e){ push('close', erro(e.type)); });
    N.peer.on('disconnected', function(){ if (!N.conn) { try { N.peer.reconnect(); } catch(e) {} } });
  });
};
N.join = function(code){
  load(function(){
    if (local) { bcWire(code, 'guest'); N.bc.postMessage({k: 'hello'}); push('status', 'Procurando a sala ' + code + '...'); return; }
    N.peer = new Peer({config: ICE, debug: 1});
    N.peer.on('open', function(){
      push('status', 'Conectando à sala ' + code + '...');
      armTimeout();
      wire(N.peer.connect('hexgal-' + code.toLowerCase(), {reliable: true}));
    });
    N.peer.on('error', function(e){ push('close', erro(e.type)); });
  });
};
N.send = function(s){ if (N.conn) N.conn.send(s); };
N.ask = function(t){ var v = window.prompt(t, ''); return v === null ? '' : String(v); };
N.copy = function(t){ try { navigator.clipboard.writeText(t); return true; } catch(e) { return false; } };
N.close = function(){
  clearTimeout(N.timer);
  try { if (N.conn) N.conn.close(); } catch(e) {}
  try { if (N.peer) N.peer.destroy(); } catch(e) {}
  try { if (N.bc) N.bc.close(); } catch(e) {}
  N.conn = null; N.peer = null; N.bc = null;
};
window.hexNet = N;
})();
"""

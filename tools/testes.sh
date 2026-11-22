#!/usr/bin/env bash
# Roda os testes de regra sem tela. Sai com erro se algum teste falhar, der erro de script ou não terminar.
# Uso: tools/testes.sh [caminho do godot]
G=${1:-./godot}
SUITES="abyssais carrinho disputa faurianos krieg valakianos zukunft"
ruim=0
for t in $SUITES; do
  out=$(timeout 300 "$G" --headless --path . -- --teste=$t 2>&1)
  fim=$(echo "$out" | grep -o 'TESTE FIM falhas=[0-9]*' | tail -1)
  erros=$(echo "$out" | grep -c 'SCRIPT ERROR\|Parse Error')
  if [ "$fim" != "TESTE FIM falhas=0" ] || [ "$erros" != "0" ]; then
    echo "FALHOU  $t  (${fim:-sem fim}, erros de script: $erros)"
    echo "$out" | grep -E 'FALHA|SCRIPT ERROR|Parse Error|at: ' | head -20
    ruim=1
  else
    echo "ok      $t"
  fi
done
# uma partida inteira CPU x CPU tem que chegar ao fim sem erro
out=$(timeout 600 "$G" --headless --path . -- --autotest fac=KRI cpu=WAC map=posto nivel=2 2>&1)
if echo "$out" | grep -q 'AUTOTESTE FIM' && ! echo "$out" | grep -q 'SCRIPT ERROR'; then
  echo "ok      partida CPU x CPU"
else
  echo "FALHOU  partida CPU x CPU"; echo "$out" | grep -E 'SCRIPT ERROR|at: ' | head -10; ruim=1
fi
# online de verdade: dois processos pela rede local, com uma queda no meio; o estado final tem que bater
L1=$(mktemp); L2=$(mktemp)
PAPEL=host QUEDA=guest_r3 timeout 900 "$G" --headless --path . -- --teste=online > "$L1" 2>&1 &
sleep 2
PAPEL=guest QUEDA=guest_r3 timeout 900 "$G" --headless --path . -- --teste=online > "$L2" 2>&1
wait
f1=$(grep -o 'ONLINE FIM host .*' "$L1" | awk '{print $4}')
f2=$(grep -o 'ONLINE FIM guest .*' "$L2" | awk '{print $4}')
if [ -n "$f1" ] && [ "$f1" = "$f2" ] && grep -q 'NET VOLTOU' "$L2" && ! grep -q 'SCRIPT ERROR' "$L1" "$L2"; then
  echo "ok      online (queda e volta, estado igual nos dois: $f1)"
else
  echo "FALHOU  online (host=$f1 guest=$f2)"; grep -hE 'SCRIPT ERROR|at: |NET ' "$L1" "$L2" | head -10; ruim=1
fi
rm -f "$L1" "$L2"
exit $ruim

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
exit $ruim

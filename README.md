# Hex Galaxies

Estratégia por turnos em hexágonos (2.5D), feito em Godot 4.7 (modo Compatibilidade).

- **Jogar no navegador:** a cada envio para `main`, o GitHub monta o jogo e publica no GitHub Pages (aba *Actions* mostra o andamento; o link aparece em *Settings → Pages*).
- **Abrir no Godot:** baixe/clone o repositório e abra a pasta no Godot 4.7.
- **Ferramentas** (pasta `tools/`, Python): `vfxgen.py` (efeitos), `soundgen.py` (vozes e sons), `skygen.py` (céu), `uigen.py` (molduras e cartas), `music.py`, `synth.py`.
- **Teste automático:** `godot --headless --path . -- --autotest fac=ABY cpu=FAU map=tarhut`
- **Prints automáticos:** `godot --path . -- --shots=/pasta`

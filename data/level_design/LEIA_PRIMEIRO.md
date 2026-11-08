# HEX GALAXIES — Planta tática dos mapas ABNARA (217) e GOR'AIDA (331)

**Versão:** 1.0 (proposta de level design para playtest) — 08/11/2026.

## Hierarquia de referência

1. **Regras atuais**: `Hex Galaxies — Regras do jogo.pdf` enviado pelo criador. Em conflito, esse PDF prevalece.
2. **Coordenadas e terrenos**: `HEX_GALAXIES_MAPAS_217_331_LEVEL_DESIGN.json` é a fonte de verdade das 548 casas.
3. **Plantas funcionais**: `ABNARA_terrenos.png` e `GORAIDA_terrenos.png` representam as categorias de terreno e os pontos numerados de núcleo.
4. **Rotas e mecânicas**: `ABNARA_rotas.png` e `GORAIDA_rotas.png` expõem caminhos prioritários e células candidatas a eventos.
5. **Conceitos artísticos anteriores**: referência de **estilo**, **não** de distribuição literal de hexes. Não trocar a distribuição do JSON pelos objetos mostrados nas concepts.

## Escala e topologia

| Mapa | Casas | Geometria | Rotas | Pontos candidatos a núcleo | Bases |
|---|---:|---|---:|---:|---:|
| Abnara | **217** | hexágono regular raio 8 | 3 | 5 | esquerda/direita |
| Gor'Aida | **331** | hexágono regular raio 10 | 4 | 7 | esquerda/direita |

O universo usa Tarhut com **381** casas e Valak com **127** casas totais, das quais 7 compõem o buraco central da Garra (120 casas de chão). Não alterar esses dois totais.

Coordenadas axiais `q, r`, com `s=-q-r` e `max(|q|,|r|,|s|)<=raio`. Orientação **pointy-top**, linhas horizontais, bases opostas. Conversão para arte em unidades de raio: `x = sqrt(3)*(q-r)/2`, `y = 1.5*(q+r)`. Espelhamento esquerda/direita: `(q,r)->(r,q)`. Cada casa CSV/JSON possui id, terreno, altura, acessibilidade, candidatura a núcleo, setor de eventos e rota(s) principal(is).

## Regras do jogo preservadas

- Objetivo: derrotar o Comandante; entra no **round 4**. Partida termina no round 10 e usa o desempate por vida do Comandante, depois aliados.
- Ativação alternada de uma peça. Cada ativação tem 2 ações; cada tipo no máximo uma vez. Tática: 1 carta gratuita por ativação. Entrar uma peça da reserva custa 1 ação.
- Núcleos: rounds **2, 4, 6, 8**, duração 2 rounds, anúncio do próximo local.
- Vantagem/desvantagem de altura, linha de tiro e abrigo conforme PDF. **Visibilidade total**, sem ocultação/fog-of-war.
- **S**: áreas ambientalmente seguras perto das bases, **não** áreas de entrada imediata. Aplicar o crescimento legal de área de reserva definido no PDF: rounds 1-3 alcance 1 da base, rounds 4-6 alcance 2 etc, dentro da própria metade.
- **B**: âncora visual de entrada do Comandante no round 4, não obstáculo nem portal mágico.

## Abnara — selva viva

Legenda: `T` trilha aberta; `M` mata densa passável (interfere na linha de tiro, não na visibilidade dos personagens); `R` raiz maciça bloqueadora/destrutível; `W` correnteza passável; `P` ponte vegetal; `U` ruína alta bloqueadora; `C` planta predadora; `S` solo de implantação seguro; `B` âncora do Comandante.

Exatamente: T72, M40, R24, W20, P7, U14, C10, S28, B2 = **217**.

Três macro-rotas horizontais: selva superior, rio central, ruínas inferiores. Rio atravessa o eixo norte-sul, criando gargalos e travessias. Setores dinâmicos em células T próximas a raízes e fora dos eixos de travessia.

**Proposta para teste**: pulsos de raízes nos rounds 3, 6, 9, com aviso nos rounds 2, 5, 8; escolher um setor por seed e entre 1-2 pares espelhados de casas por pulso, somente se não quebrar conectividade. Correnteza move 1 casa ao fim da rodada no sentido marcado (até 2 em pulso especial). Plantas acordadas ameaçam casas adjacentes por 2 dano. Custos, HP e duração de raízes devem ser calibrados em playtest.

## Gor'Aida — gelo instável

Legenda: `N` neve firme; `L` gelo liso; `F` gelo frágil; `X` fenda aberta; `H` parede glacial; `A` corredor de avalanche; `S` solo inicial seguro; `B` âncora do Comandante.

Exatamente: N100, L80, F49, X20, H16, A14, S50, B2 = **331**.

Quatro rotas horizontais, conectadas por passagens diagonais acessíveis: planalto norte, gelo rápido norte, gelo rápido sul, flanco sul. Gelo liso funciona como via rápida, fendas/parede moldam ângulos de ataque, avalanches mudam posicionamento.

**Proposta para teste**: rachaduras nos rounds 3, 6, 9 (avisos 2, 5, 8) e avalanches nos rounds 4, 7, 10 (avisos 3, 6, 9). Variação de setores selecionada por seed, mas a posição do evento deve ser apresentada claramente com **um round completo de aviso**. Gelo liso concede 1 deslize adicional se legal; gelo frágil tem fases intacto/rachado/rompido; avalanche pode causar 2 dano e empurrar 1 casa. Essas magnitudes são propostas, não oficiais.

## Objetivos de diversão e validação

1. Os primeiros confrontos importantes devem ocorrer até cerca do round 3, sem jogadores passando a abertura só caminhando.
2. O Comandante consegue entrar no round 4 e apoiar mais de uma rota; ao menos uma saída segura para ambos os lados.
3. O núcleo motiva disputa entre rotas sem tornar o centro único caminho de vitória.
4. Nenhum sorteio pode eliminar a conectividade entre bases, bloquear TODOS os cruzamentos, atuar em B/S sem aviso ou criar morte inevitável por terreno.
5. O layout inicial passou: contagem, simetria, conectividade terrestre, rotas e núcleos acessíveis. O arquivo `VALIDACAO_AUTOMATICA.json` registra 120 cenários simples de evento por mapa sem corte de conectividade. Essa validação **não substitui** testes com peças, habilidades e movimento real na Godot.

## Importação para Godot

Leia o JSON por `maps.ABNARA.cells` ou `maps.GORAIDA.cells`. `terrain` identifica o terreno base; efeitos temporários de crescimento/rachadura devem ser guardados em **camada dinâmica separada**, sem apagar o terreno original. `height_level` é a camada de altura (0-2). `flow_to` aponta um destino adjacente para efeitos de correnteza/avalanche quando disponível; `null` significa ausência de destino predefinido. Números em `core_candidate` indicam posições possíveis de núcleo, não núcleos simultâneos. `event_candidate_sector` identifica a área possível de evento, não seu acionamento permanente. `lane_spines` dá a ordem da macro-rota para QA.

**Atenção**: os mapas de Abnara e Gor'Aida foram ampliados em relação aos layouts antigos de 127 hexágonos. Não reutilizar contagens nem coordenadas da versão antiga; o PDF de regras atual prevalece em todas as regras globais.

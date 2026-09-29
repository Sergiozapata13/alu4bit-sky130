# ALU 4-bit mejorada — Proyecto de portafolio

Flujo: Xschem (opcional, para editar visualmente) + ngspice + PDK Sky130.
Ver el documento de investigación previa para contexto completo.

## Estado actual

- [x] Investigación previa (acceso a herramienta, topologías, metodología de caracterización)
- [x] Especificación: ALU 8 operaciones, S[2:0]
- [x] Full adder 28T — netlist SPICE + testbench de verificación funcional y delay/potencia
      (verificado contra los modelos reales de Sky130)
- [x] Full subtractor (derivado del full adder: A + B' + Bin')
- [x] Comparador de magnitud 4 bits (XNOR + prioridad, estilo cascada 7485)
- [x] Array multiplier 4x4 (arquitectura completa 4x4→8 bits, no truncada)
- [x] Compuertas lógicas AND/OR/XOR de 4 bits
- [x] Mux de selección 8 vías (S[2:0])
- [x] Integración top-level (`alu_4bit_top.spice`, 8 operaciones seleccionables)
- [x] Caracterización de delay y potencia — ver tabla abajo
- [x] Camino crítico identificado y documentado (multiplicador, ruta A3→P5)
- [x] Análisis de esquinas de proceso (tt/ff/ss) en los 6 bloques
- [ ] (Opcional) Wallace tree + comparación contra array multiplier

Ver `schematics/README.md` y `sim/README.md` para el detalle de cada
archivo del proyecto.

## Instalación del entorno (Linux/WSL)

```bash
# 1. ngspice con soporte Sky130
sudo apt install -y ngspice   # o compilar con --enable-sky130-pdk si tu paquete no lo trae

# 2. PDK Sky130 vía ciel (más simple que compilar open_pdks manualmente)
pip install --user ciel
ciel enable --pdk sky130

# 3. Ubicar la ruta de los modelos SPICE instalados
find ~ -path "*sky130A/libs.tech/ngspice*" 2>/dev/null
# Exportar esa ruta (ajustar tb_full_adder.spice si difiere del placeholder $::SKY130A_MODELS)
export SKY130A_MODELS=/ruta/que/te/imprimio/find/sky130.lib.spice
```

## Correr las simulaciones

Todos los comandos se corren desde la raíz del repo, entrando primero a
`sim/`. Modo batch (`-b`): ngspice corre todo el `.control...endc` y termina
solo, sin dejar ninguna ventana ni prompt interactivo pendiente.

### Un bloque a la vez

```bash
cd sim
ngspice -b tb_full_adder.spice
```

### Los 6 testbenches, uno detrás de otro

```bash
cd sim
ngspice -b tb_full_adder.spice
ngspice -b tb_full_subtractor.spice
ngspice -b tb_comparator_4bit.spice
ngspice -b tb_logic_ops_4bit.spice
ngspice -b tb_multiplier_4x4.spice
ngspice -b tb_alu_4bit.spice
```

### Ver solo las métricas (delay y potencia), sin el resto del log de ngspice

Cada testbench imprime, además de las mediciones, el voltaje inicial de
cada nodo interno y estadísticas de memoria — bastante ruido si solo se
quieren los números. Filtrando por las variables de `.meas`:

```bash
cd sim
for tb in tb_full_adder tb_full_subtractor tb_comparator_4bit \
          tb_logic_ops_4bit tb_multiplier_4x4 tb_alu_4bit; do
    echo "=== $tb ==="
    ngspice -b "$tb.spice" 2>&1 | grep -E "tpd_|avg_power"
done
```

(`tpd_*` solo existe en `tb_full_adder` y `tb_full_subtractor` — los demás
bloques no miden delay de propagación explícito, solo potencia y
verificación funcional; ver la nota al final de la sección de
caracterización.)

### Ver el resultado funcional completo de la ALU (las 12 operaciones)

```bash
cd sim
ngspice -b tb_alu_4bit.spice 2>&1 | grep -E "avg_power|r[0-7]_|cout_|bout_|gt_|lt_|eq_"
```

Cada salida (`r7_0_add`, `cout_0_add`, etc.) se imprime en voltios, no en
1/0 — un valor por debajo de ~0.45V (VDD/4) se lee como "0" lógico y uno
por encima de ~1.35V (3·VDD/4) como "1"; ver la tabla de la sección
"Análisis detallado" más abajo para la conversión completa a binario.

### Regenerar las waveforms (PNG) después de simular

Cada testbench genera `.ps` en `docs/waveforms/` vía `hardcopy`. Para
convertirlos a `.png` visibles en GitHub:

```bash
cd scripts
./convert_waveforms.sh
```

Ver `sim/README.md` para el detalle de qué mide y qué genera cada
testbench, y `docs/waveforms/README.md` para el resultado ya convertido.

## Caracterización (delay y potencia)

Métricas obtenidas corriendo cada testbench (`ngspice -b tb_X.spice`) contra
los modelos reales de Sky130 (esquina `tt`, VDD=1.8V, CLOAD=10fF en todas las
salidas). Delay = tiempo de propagación, cruce 50% VDD (`.meas ... TRIG/TARG`).
Potencia = potencia dinámica promedio sobre toda la ventana simulada
(`.meas ... AVG PAR('-i(VDD)*VDD_VAL')`). Comandos para reproducir estos
números en `sim/README.md`.

### Delay de propagación (todos los bloques)

| Transición medida | Delay |
|---|---|
| full adder: A→Sum (0→1) | 130.3 ps |
| full adder: A→Sum (1→0) | 186.5 ps |
| full adder: A→Cout (0→1) | 121.7 ps |
| full adder: A→Sum (1→0, segunda transición) | 131.5 ps |
| full adder: A→Cout (1→0) | 123.5 ps |
| full subtractor: A→Diff (0→1) | 201.0 ps |
| full subtractor: A→Diff (1→0) | 144.4 ps |
| comparador: A3→LT (RISE) | 400.0 ps |
| comparador: A3→EQ (FALL) | 120.7 ps |
| comparador: A3→GT (RISE) | 403.5 ps |
| comparador: A3→LT (FALL) | 393.4 ps |
| comparador: B3→EQ (RISE) | 466.9 ps |
| comparador: A3→LT (RISE, 2da transición) | 390.6 ps |
| comparador: A3→GT (RISE, 2da transición) | 411.5 ps |
| lógica: A1→AND1 (FALL) | 92.2 ps |
| lógica: A1→OR1 (FALL) | 145.4 ps |
| lógica: A0→AND0 (RISE) | 128.4 ps |
| lógica: A0→OR0 (RISE) | 100.9 ps |
| multiplicador: A0→P7 (RISE) | 546.9 ps |
| multiplicador: A0→P0 (RISE) | 173.7 ps |
| multiplicador: A1→P7 (FALL) | 564.4 ps |
| multiplicador: A1→P1 (RISE) | 231.9 ps |
| multiplicador: A3→P5 (RISE) | **697.4 ps (peor caso del proyecto)** |
| multiplicador: A3→P1 (FALL) | 239.2 ps |
| multiplicador: B0→P2 (RISE) | 378.7 ps |
| multiplicador: B0→P0 (FALL) | 151.0 ps |
| ALU top-level: S0→R3 (FALL) | 254.8 ps |
| ALU top-level: S0→R1 (RISE) | 356.9 ps |
| ALU top-level: S0→R4 (FALL) | 159.1 ps |
| ALU top-level: S0→R2 (RISE) | 282.6 ps |
| ALU top-level: S0→R2 (FALL) | 158.2 ps |
| ALU top-level: S0→R3 (RISE) | 561.9 ps |

Todas las transiciones se eligieron verificando primero en Python, bit a
bit contra la tabla de verdad de cada bloque, que el borde entre dos casos
de prueba consecutivos moviera un único bit de entrada de forma limpia
(sin superponerse con otro cambio simultáneo) y que produjera una
respuesta medible en la salida — evitando así medir un "delay" ambiguo
donde varias señales cambian a la vez. Comandos para reproducir en
`sim/README.md`.

Resumen por bloque (peor caso observado):

| Bloque | Peor-caso delay |
|---|---|
| Full adder | 186.5 ps |
| Full subtractor | 201.0 ps |
| Comparador de magnitud | 466.9 ps |
| Lógica AND+OR+XOR | 145.4 ps |
| Multiplicador array | **697.4 ps** |
| ALU top-level (S→R) | 561.9 ps |

El multiplicador array tiene el peor delay de todos los bloques — coherente
con que su carry-chain interna (9 half/full adders encadenados) es la ruta
combinacional más larga del proyecto, y es el principal candidato a
optimizar (ver "Posible siguiente paso: Wallace tree" más abajo). El delay
S→R de la ALU top-level (561.9 ps) incluye el mux de selección de 8
entradas más la lógica del bloque activo en cada caso — es la medida más
cercana a un "delay end-to-end" de la ALU completa.

### Potencia dinámica promedio, energía y corriente, por bloque

| Bloque | Ancho | Potencia promedio | Corriente promedio (I=P/VDD) | Energía total en la ventana | Ventana simulada |
|---|---|---|---|---|---|
| Full adder (1 bit) | 1 bit | 1.365 µW | 0.758 µA | 174.7 fJ | 128 ns |
| Full subtractor (1 bit) | 1 bit | 2.383 µW | 1.324 µA | 305.1 fJ | 128 ns |
| Comparador de magnitud | 4 bits | 8.497 µW | 4.721 µA | 1223.6 fJ | 144 ns |
| Lógica AND+OR+XOR (conjunto) | 4 bits ×3 | 3.539 µW | 1.966 µA | 113.3 fJ | 32 ns |
| Multiplicador array | 4×4→8 bits | 24.35 µW | 13.53 µA | 3895.5 fJ | 160 ns |
| **ALU top-level (12 operaciones)** | 4 bits | **27.39 µW** | **15.22 µA** | **5259.4 fJ** | 192 ns |

La ALU completa consume en promedio **438.3 fJ por operación** (energía
total / 12 operaciones de 16ns cada una) — una cifra más útil que la
potencia sola para comparar contra otras arquitecturas, porque no depende
de cuánto dure la simulación.

### Producto delay-potencia (PDP), todos los bloques

El PDP combina ambas métricas en una sola cifra: cuánta energía se gasta en
cada conmutación de la salida (menor es mejor — un diseño puede ser rápido
gastando mucha energía, o eficiente siendo lento, y el PDP normaliza esa
compensación).

| Bloque | Peor-caso delay | Potencia promedio | PDP |
|---|---|---|---|
| Full adder | 186.5 ps (A→Sum, 1→0) | 1.365 µW | 254.5 aJ |
| Full subtractor | 201.0 ps (A→Diff, 0→1) | 2.383 µW | 479.1 aJ |
| Comparador de magnitud | 466.9 ps (B3→EQ, RISE) | 8.497 µW | 3967.2 aJ |
| Lógica AND+OR+XOR | 145.4 ps (A1→OR1, FALL) | 3.539 µW | 514.6 aJ |
| Multiplicador array | 697.4 ps (A3→P5, RISE) | 24.35 µW | **16981.7 aJ** |
| ALU top-level (S→R) | 561.9 ps (S0→R3, RISE) | 27.39 µW | 15390.4 aJ |

El full subtractor tiene ~1.9× el PDP del full adder — coherente con que
reutiliza el mismo full adder pero le agrega dos inversores en la entrada
(para B' y Bin'), lo que añade tanto capacitancia (más potencia) como un
paso lógico extra en la ruta crítica (más delay) sin cambiar la topología
central.

El multiplicador array tiene, por un margen amplio, el peor PDP del
proyecto (~33× el del full adder) — combina el mayor delay (carry-chain de
9 half/full adders) con la mayor potencia (más transistores conmutando por
ciclo), así que es donde más impacto tendría una optimización (ver Wallace
tree abajo). El PDP de la ALU top-level es comparable al del multiplicador
porque, aunque su potencia individual es apenas mayor, su delay de S→R es
menor que el peor caso puramente interno del multiplicador (el mux de
salida no añade tanta ruta combinacional adicional).

Notas de interpretación:
- La potencia de la ALU top-level (27.39 µW) es menor que la suma directa de
  sus bloques porque solo un bloque está "activo" en cada operación del
  testbench (S[2:0] selecciona una operación a la vez) — los demás
  conmutan sus entradas pero no impulsan la salida seleccionada.
- El multiplicador domina el consumo entre los bloques individuales: tiene
  ~9 full/half adders internos conmutando por cada cambio de A o B,
  frente a 1 en el full adder o 4 en paralelo (sin acarreo) en los bloques
  lógicos.
- Estos números son con `CLOAD=10fF` fijo en todas las salidas — sirven para
  comparar bloques entre sí, no como estimación de potencia en un diseño
  con fanout/rutas reales.

## Análisis detallado: verificación funcional de la ALU (12/12 casos)

Resultado de correr `tb_alu_4bit.spice` contra el PDK real de Sky130 (ver
comando en la sección anterior). Cada salida se muestrea en voltios en el
centro de su ventana de 16ns; se decodifica a "1" lógico si supera 0.9V
(VDD/2) y a "0" si está por debajo — casi todos los "0" reales caen muy por
debajo de ese umbral (entre nanovoltios y unos pocos µV de ruido de fuga,
nunca cerca de la zona de decisión), así que la lectura no es ambigua en
ningún caso.

| # | S | Operación | A | B | Result[7:0] obtenido | Decimal | Cout | Bout | GT | LT | EQ | Esperado |
|---|-----|-----------|----|----|---|---|---|---|---|---|---|---|
| 0 | 000 | ADD | 6 | 3 | `00001001` | 9 | 0 | 0 | 0 | 0 | 0 | 6+3=9 ✅ |
| 1 | 001 | SUB | 6 | 3 | `00000011` | 3 | 0 | 0 | 0 | 0 | 0 | 6−3=3 ✅ |
| 2 | 010 | MUL | 6 | 3 | `00010010` | 18 | 0 | 0 | 0 | 0 | 0 | 6×3=18 ✅ |
| 3 | 011 | CMP | 6 | 3 | — | — | 0 | 0 | **1** | 0 | 0 | 6>3 ✅ |
| 4 | 011 | CMP | 3 | 3 | — | — | 0 | 0 | 0 | 0 | **1** | 3=3 ✅ |
| 5 | 011 | CMP | 2 | 9 | — | — | 0 | 0 | 0 | **1** | 0 | 2<9 ✅ |
| 6 | 100 | AND | 12 | 10 | `00001000` | 8 | 0 | 0 | 0 | 0 | 0 | 1100∧1010=1000 ✅ |
| 7 | 101 | OR | 12 | 10 | `00001110` | 14 | 0 | 0 | 0 | 0 | 0 | 1100∨1010=1110 ✅ |
| 8 | 110 | XOR | 12 | 10 | `00000110` | 6 | 0 | 0 | 0 | 0 | 0 | 1100⊕1010=0110 ✅ |
| 9 | 111 | reservado | 6 | 3 | `00000000` | 0 | 0 | 0 | 0 | 0 | 0 | todo en 0 ✅ |
| 10 | 000 | ADD (overflow) | 15 | 2 | `00000001` | 1 | **1** | 0 | 0 | 0 | 0 | 15+2=17→1 con acarreo ✅ |
| 11 | 001 | SUB (underflow) | 3 | 6 | `00001101` | 13 | 0 | **1** | 0 | 0 | 0 | 3−6=−3→13 con préstamo (compl. a 2) ✅ |

**12/12 casos correctos.** Puntos destacables del análisis:

- **Casos 3, 4 y 5 no tienen `Result` significativo** porque, según la
  tabla de operaciones de `alu_4bit_top.spice`, CMP fuerza `Result=00000000`
  y expresa su resultado únicamente en las banderas GT/LT/EQ — así se
  comportó en los tres casos, incluyendo el caso 4 (decisión en EQ, no en
  el MSB) y el caso 5 (decisión en un bit intermedio, A=0010 vs B=1001,
  donde el bit 3 ya distingue).
- **Caso 10 (overflow de ADD)**: 15+2=17 no entra en 4 bits, así que el
  resultado correcto de `Sum[3:0]` es `0001` (17 mod 16 = 1) con `Cout=1`
  señalizando el acarreo — exactamente lo que se midió.
- **Caso 11 (underflow de SUB)**: 3−6=−3, que en complemento a 2 de 4 bits
  es `1101` (16−3=13), con `Bout=1` señalizando el préstamo — también
  coincide.
- **Ruido en nodos "cero"**: valores como `gt_10_add_ovf = -3.63e-07` V
  (negativo, del orden de cientos de nanovoltios) aparecen porque el
  solver de ngspice puede converger con un residual pequeño en nodos que no
  están siendo forzados activamente en ese instante — no reflejan un error
  de lógica, dado que están ~6 órdenes de magnitud por debajo de la zona de
  decisión (0.9V).
- **Costo de simular el top-level**: la ALU completa (todos los bloques en
  paralelo + los muxes de selección) tiene 3922 filas de datos por paso de
  tiempo, frente a 168–1524 en los bloques individuales, y tarda ~45s de
  análisis (~103s reales) contra <1.5s en los bloques sueltos — la mayor
  parte del costo computacional del proyecto está en este único testbench.

## Notas de diseño

- **Sizing de transistores**: los valores W/L en el netlist (0.42µ/0.84µ, L=0.15µ) son un
  punto de partida típico para sky130A a tamaño mínimo. En la Fase 4 (caracterización) se
  ajustan si el delay o el consumo no son razonables — es normal iterar aquí.
- **Cload constante**: la capacitancia de carga (`CLOAD=10f` en el testbench) debe mantenerse
  igual en todos los bloques de la ALU para que la comparación entre arquitecturas
  (por ejemplo array multiplier vs. Wallace tree) sea válida.
- **Ruta de modelos**: cada testbench tiene su propia línea `.lib "..." tt` apuntando a la
  instalación local del PDK (ciel) — ajustarla a la ruta real en tu máquina si difiere,
  buscándola con `find ~/.ciel -path "*sky130A/libs.tech/ngspice*"`.

## Análisis de esquinas de proceso (corner analysis)

Los modelos Sky130 vienen con distintas "esquinas" (corners) que modelan la
variación de fabricación normal entre chips: `tt` (typical-typical, el que
se usó en toda la caracterización de arriba), `ff` (fast-fast, transistores
más rápidos de lo típico) y `ss` (slow-slow, más lentos de lo típico). Un
diseño real tiene que funcionar correctamente en todo ese rango, no solo en
`tt` — por eso se re-corrieron los 6 testbenches en `ff` y `ss` (VDD=1.8V,
TEMP=27°C fijos, solo cambia la esquina de los transistores) usando
`scripts/run_corner.sh`, que sustituye el nombre de esquina en la línea
`.lib` de una copia temporal del testbench sin tocar el archivo original.

### Peor-caso delay por esquina

| Bloque | tt | ff | ss | ff vs tt | ss vs tt | ss/ff |
|---|---|---|---|---|---|---|
| Full adder | 186.5 ps | 139.0 ps | 275.7 ps | −25.5% | +47.8% | 1.98× |
| Full subtractor | 201.0 ps | 148.7 ps | 297.0 ps | −26.0% | +47.8% | 2.00× |
| Comparador 4-bit | 466.9 ps | 341.0 ps | 675.0 ps | −27.0% | +44.6% | 1.98× |
| Lógica AND+OR+XOR | 145.4 ps | 112.8 ps | 196.2 ps | −22.4% | +34.9% | 1.74× |
| Multiplicador array | 697.4 ps | 494.3 ps | **1070.4 ps** | −29.1% | +53.5% | 2.17× |
| ALU top-level (S→R) | 561.9 ps | 383.6 ps | 851.2 ps | −31.7% | +51.5% | 2.22× |

### Potencia dinámica promedio por esquina

| Bloque | tt | ff | ss | ff vs tt | ss vs tt |
|---|---|---|---|---|---|
| Full adder | 1.365 µW | 1.542 µW | 1.332 µW | +13.0% | −2.4% |
| Full subtractor | 2.383 µW | 2.594 µW | 2.373 µW | +8.9% | −0.4% |
| Comparador 4-bit | 8.497 µW | 9.796 µW | 8.391 µW | +15.3% | −1.2% |
| Lógica AND+OR+XOR | 3.539 µW | 4.139 µW | 3.488 µW | +17.0% | −1.4% |
| Multiplicador array | 24.35 µW | 28.85 µW | 23.14 µW | +18.5% | −5.0% |
| ALU top-level | 27.39 µW | 36.68 µW | 26.91 µW | +33.9% | −1.8% |

Interpretación:

- El patrón es el esperado para cualquier proceso CMOS: en `ff` los
  transistores conmutan más rápido (menor delay) pero también más "fuerte"
  (más corriente, más potencia dinámica); en `ss` es al revés — más lentos
  pero con algo menos de potencia.
- El ratio `ss`/`ff` en delay se mantiene entre 1.74× y 2.22× en todos los
  bloques, consistente con la variación típica documentada para Sky130A
  entre sus esquinas extremas.
- El **multiplicador en la esquina `ss` pasa de 697 ps a 1070 ps** —el
  único bloque que supera 1 ns de peor-caso delay en cualquier esquina—,
  lo que confirma otra vez que es el elemento que más limita la frecuencia
  máxima de la ALU: si se quisiera definir un reloj para este diseño, el
  período mínimo tendría que basarse en el peor caso (`ss`), no en `tt`,
  para garantizar que funcione en todos los chips fabricados.
- La ALU top-level en `ss` (851.2 ps) queda por debajo del multiplicador
  aislado en `ss` (1070.4 ps) por la misma razón que en `tt`: la transición
  S→R medida no necesariamente ejercita la ruta interna más larga del
  multiplicador (A3→P5 vía `pp03`, ver sección de camino crítico).
- Estos resultados usan solo `tt`/`ff`/`ss` (las esquinas "simétricas"); no
  se corrieron las esquinas mixtas `sf`/`fs` (un tipo de transistor rápido
  y el otro lento), que son más relevantes para el skew NMOS-vs-PMOS en
  diseños sensibles al balance de la red pull-up/pull-down.

Comandos para reproducir (ver también `scripts/README.md`):

```bash
cd sim
../scripts/run_corner.sh tb_full_adder.spice ff | grep -E "tpd_|avg_power"
../scripts/run_corner.sh tb_full_adder.spice ss | grep -E "tpd_|avg_power"
# ... repetir con cada tb_*.spice
```

## Camino crítico de la ALU

El delay de propagación más alto medido en todo el proyecto (697.4 ps,
`A3→P5`, ver tabla de arriba) ocurre en el multiplicador array. Se trazó a
mano la topología de `multiplier_4x4` (ver diagrama de suma en cascada en
`schematics/multiplier_4x4.spice`) para identificar exactamente qué ruta
combinacional produce ese resultado.

`A3` alimenta 4 productos parciales distintos (`pp03`, `pp13`, `pp23`,
`pp33`), cada uno entrando en un punto distinto de la malla de sumadores:

| Entrada de A3 | Ruta hasta la salida | Celdas sumadoras atravesadas |
|---|---|---|
| `pp03` → `fa1_2` → `fa2_1` → `ha3_0` → `fa3_1` → `fa3_2` → **P5** | 5 |
| `pp13` → `fa1_3` → `fa2_3` → `fa3_3` → **P7** | 3 |
| `pp23` → `fa2_3` → `fa3_3` → **P7** | 2 |
| `pp33` → `fa3_3` → **P6**/**P7** | 1 |

Contra la intuición de que el bit más significativo (`P7`) sería el más
lento, la ruta más larga es la que llega a **P5** vía `pp03`: al entrar en
la primera fila de sumadores (columna 3 de 4), la señal tiene que
propagarse en diagonal por 5 celdas completas (mezclando tanto la suma
como el acarreo de cada etapa) antes de llegar a la salida, mientras que
las rutas que entran más tarde en la malla (`pp13`, `pp23`, `pp33`) le
"ganan terreno" porque ya arrancan más cerca del final de la cadena. Esto
es una consecuencia estructural de la arquitectura *array multiplier*: la
profundidad combinacional no crece monótonamente con el peso del bit de
salida, sino con cuántas etapas de suma diagonal tiene que atravesar cada
producto parcial según en qué fila entra.

Esto confirma que el **camino crítico de la ALU completa pasa por el
multiplicador**, específicamente por esta ruta de 5 sumadores en cascada.
El delay medido de la ALU top-level (S→R, 561.9 ps peor caso, ver tabla de
arriba) es menor que el del multiplicador aislado (697.4 ps) porque las
transiciones S→R que se midieron no necesariamente ejercitan esta ruta
específica del multiplicador — el delay real "MUL activo, peor caso de A/B"
dentro de la ALU sería, en el peor caso, similar o ligeramente mayor a los
697.4 ps aislados (por el mux de salida adicional), pero no se aisló esa
combinación exacta de A/B en el testbench actual de la ALU.

## Posible siguiente paso: Wallace tree

Único ítem pendiente del roadmap original: implementar el multiplicador 4x4
como árbol de Wallace (en vez de array multiplier) y comparar delay/potencia
entre ambas arquitecturas con el mismo `CLOAD`. Un Wallace tree reduce la
profundidad combinacional comprimiendo los productos parciales en paralelo
(con sumadores 3:2) en vez de propagarlos en cascada diagonal fila por
fila — la mejora esperada es justamente en la ruta identificada arriba
(5 celdas en cascada), que debería bajar a O(log n) etapas en vez de O(n).
No es necesario para que la ALU esté completa — el array multiplier ya es
funcional y está integrado en el top-level.

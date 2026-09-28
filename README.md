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

### Delay de propagación (full adder / full subtractor)

| Transición medida | Delay |
|---|---|
| full adder: A→Sum (0→1) | 130.3 ps |
| full adder: A→Sum (1→0) | 186.5 ps |
| full adder: A→Cout (0→1) | 121.7 ps |
| full adder: A→Sum (1→0, segunda transición) | 131.5 ps |
| full adder: A→Cout (1→0) | 123.5 ps |
| full subtractor: A→Diff (0→1) | 201.0 ps |
| full subtractor: A→Diff (1→0) | 144.4 ps |

Los demás testbenches (comparator, logic ops, multiplier, ALU top-level) no
miden delay de propagación explícito — solo verificación funcional
(muestreo de cada salida en el centro de su ventana) y potencia.

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

### Producto delay-potencia (PDP), full adder y full subtractor

El PDP combina ambas métricas en una sola cifra: cuánta energía se gasta en
cada conmutación de la salida (menor es mejor — un diseño puede ser rápido
gastando mucha energía, o eficiente siendo lento, y el PDP normaliza esa
compensación).

| Bloque | Peor-caso delay | Potencia promedio | PDP |
|---|---|---|---|
| Full adder | 186.5 ps (A→Sum, 1→0) | 1.365 µW | 254.5 aJ |
| Full subtractor | 201.0 ps (A→Diff, 0→1) | 2.383 µW | 479.1 aJ |

El full subtractor tiene ~1.9× el PDP del full adder — coherente con que
reutiliza el mismo full adder pero le agrega dos inversores en la entrada
(para B' y Bin'), lo que añade tanto capacitancia (más potencia) como un
paso lógico extra en la ruta crítica (más delay) sin cambiar la topología
central.

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

## Posible siguiente paso: Wallace tree

Único ítem pendiente del roadmap original: implementar el multiplicador 4x4
como árbol de Wallace (en vez de array multiplier) y comparar delay/potencia
entre ambas arquitecturas con el mismo `CLOAD`. No es necesario para que la
ALU esté completa — el array multiplier ya es funcional y está integrado
en el top-level.

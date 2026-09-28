# Sim (testbenches)

Testbenches de ngspice que instancian cada bloque de `../schematics/` contra
los modelos reales de Sky130 (`.lib ... tt`, esquina típica), con estímulos
digitales PWL (transición rápida de 0.1ns, sostenidos el resto de la
ventana) y carga capacitiva fija `CLOAD=10f` en todas las salidas, para que
las comparaciones de delay/potencia entre bloques sean válidas.

Todos los estímulos se generan con un patrón de "contador binario" (cada
bit cambia con un período distinto) armado con un script Python, no a mano
— evita el error de dejar puntos PWL separados por muchos ns sin una
transición rápida entre ellos, que produce rampas triangulares en vez de
señales digitales limpias (bug real que apareció y se corrigió en una
versión anterior de `tb_full_adder.spice`).

## Cómo correr un testbench

```bash
cd sim
ngspice -b tb_full_adder.spice     # modo batch: corre todo y termina solo
```

Modo batch (`-b`) es el recomendado para generar las waveforms (`hardcopy`
sigue funcionando igual); en modo interactivo (`ngspice tb_x.spice`, sin
`-b`) además se abre la ventana gráfica de `plot`, pero hay que escribir
`quit` manualmente al terminar. Ver `../scripts/README.md` para el paso
siguiente (convertir los `.ps` generados a `.png`).

**Antes de correr cualquier testbench**, ajustar la ruta del `.lib` de
Sky130 (línea con `.lib "/home/segio/.ciel/..."`) a donde esté instalado el
PDK en tu máquina — buscarla con:
```bash
find ~/.ciel -path "*sky130A/libs.tech/ngspice*"
```

## Archivos

### `tb_full_adder.spice`
DUT: `full_adder_28t` (instancia única, 1 bit).
Estímulo tipo contador binario: A cambia cada 16ns, B cada 32ns, Cin cada
64ns (8 combinaciones, 128ns totales). Mide:
- `tpd_a_sum_r` / `tpd_a_sum_f` / `tpd_a_sum_r2`: delay A→Sum (cruce 50% VDD)
  en las tres transiciones de A que sí producen una respuesta en Sum.
- `tpd_a_cout_r` / `tpd_a_cout_f`: delay A→Cout.
- `avg_power`: potencia dinámica promedio sobre los 128ns.
- Muestreo de `sum`/`cout` en el centro de cada una de las 8 ventanas
  (chequeo de glitch: deben quedar cerca de 0V o 1.8V).

Genera: `full_adder_28t.ps` (A, B, Cin, Sum, Cout).

### `tb_full_subtractor.spice`
DUT: `full_subtractor` (instancia única, 1 bit).
Mismo patrón de contador binario que el full adder, con (A, B, Bin) en vez
de (A, B, Cin). Mide:
- `tpd_a_diff_r` / `tpd_a_diff_f`: delay A→Diff.
- `avg_power`.
- Muestreo de `diff`/`bout` en el centro de las 8 ventanas.

Genera: `full_subtractor.ps` (A, B, Bin, Diff, Bout).

### `tb_comparator_4bit.spice`
DUT: `comparator_4bit` (4 bits).
9 casos de prueba (16ns cada uno, 144ns totales) cubriendo: iguales en
ambos extremos, diferencias extremas, iguales en el medio, y decisión
tomada en el MSB vs. en un bit intermedio (no el LSB) — el caso más
exigente para la lógica de propagación en cascada. Mide `gt_N`/`lt_N`/`eq_N`
en cada ventana y `avg_power`.

Genera dos waveforms (divididas porque ngspice-42 limita `plot`/`hardcopy`
a 8 vectores por línea):
- `comparator_4bit_inputs.ps` (A[3:0], B[3:0])
- `comparator_4bit_outputs.ps` (GT, LT, EQ — entre comillas dobles, ver
  nota abajo)

### `tb_logic_ops_4bit.spice`
DUT: `and4_sk130`, `or4_sk130`, `xor4_sk130` (las 3 instanciadas en
paralelo sobre las mismas entradas A[3:0]/B[3:0]).
2 combinaciones (16ns cada una, 32ns totales): A=1010/B=0110 y
A=0101/B=1001. Mide las 4 salidas de cada bloque en cada combinación y
`avg_power` conjunta de los 3 bloques.

Genera: `logic_ops_inputs.ps`, `logic_ops_and.ps`, `logic_ops_or.ps`,
`logic_ops_xor.ps`.

### `tb_multiplier_4x4.spice`
DUT: `multiplier_4x4` (4×4 → 8 bits).
8 casos de prueba (20ns cada uno, 160ns totales) generados con Python,
cubriendo límites (0×0, 15×15), identidad (1×15, 15×1) y casos generales
con varios acarreos (7×7, 9×6, 12×11, 3×5). Mide `p0_N`...`p7_N` en cada
ventana y `avg_power`.

Genera: `multiplier_4x4_inputs.ps`, `multiplier_4x4_p_high.ps` (P7-P4),
`multiplier_4x4_p_low.ps` (P3-P0).

### `tb_alu_4bit.spice`
DUT: `alu_4bit` (top-level completo, incluye `alu_primitives.spice` +
`alu_4bit_top.spice` — **no** los schematics de bloques individuales, para
no duplicar subcircuitos).
12 casos de prueba (16ns cada uno, 192ns totales), uno por cada operación
`S[2:0]` (000-111) más dos casos extra de acarreo/préstamo:

| # | S | Operación | A | B | Resultado esperado |
|---|-----|-------------|----|----|----------------------------------|
| 0 | 000 | ADD | 6 | 3 | Result=00001001, Cout=0 |
| 1 | 001 | SUB | 6 | 3 | Result=00000011, Bout=0 |
| 2 | 010 | MUL | 6 | 3 | Result=00010010 |
| 3 | 011 | CMP (GT) | 6 | 3 | GT=1, LT=0, EQ=0 |
| 4 | 011 | CMP (EQ) | 3 | 3 | GT=0, LT=0, EQ=1 |
| 5 | 011 | CMP (LT) | 2 | 9 | GT=0, LT=1, EQ=0 |
| 6 | 100 | AND | 12 | 10 | Result=00001000 |
| 7 | 101 | OR | 12 | 10 | Result=00001110 |
| 8 | 110 | XOR | 12 | 10 | Result=00000110 |
| 9 | 111 | reservado | 6 | 3 | Result=00000000, banderas=0 |
| 10 | 000 | ADD (overflow) | 15 | 2 | Result=00000001, Cout=1 |
| 11 | 001 | SUB (underflow) | 3 | 6 | Result=00001101, Bout=1 |

Verificado primero end-to-end con modelos genéricos de nivel 1 (12/12 slots
correctos) antes de correr contra el PDK real. Mide `avg_power` y cada
salida (`r0`-`r7`, `cout`, `bout`, `gt`, `lt`, `eq`) en el centro de cada
una de las 12 ventanas.

Genera tres waveforms: `alu_4bit_result.ps` (R7-R0), `alu_4bit_flags.ps`
(Cout, Bout, GT, LT, EQ), `alu_4bit_select.ps` (S2, S1, S0).

## Limitaciones de ngspice-42 (por qué los plots están divididos)

1. **Máximo 8 vectores por línea** en `plot`/`hardcopy` (límite de ancho
   heredado del backend PostScript). Un `plot` con más de 8 señales deja el
   graficador en estado inválido y hace fallar el `hardcopy` siguiente,
   incluso si ese `hardcopy` tiene pocas señales — por eso ambos comandos
   se dividen en grupos de ≤8 en todos los testbenches.
2. **`gt`, `lt`, `eq` son palabras reservadas** del parser de expresiones
   de ngspice (operadores `>`, `<`, `=`). `v(gt)`/`v(lt)`/`v(eq)` funcionan
   sin problema dentro de `.meas`, pero `plot`/`hardcopy` los interpretan
   como el operador y fallan con `PPerror: syntax error in line segment`.
   Se resuelve pasando cada señal entre comillas dobles (`"v(gt)"`), que
   fuerza al parser a tratarla como texto literal.

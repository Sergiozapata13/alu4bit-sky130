# Schematics (netlists SPICE)

Este directorio contiene los netlists a nivel de transistor (CMOS estático
complementario, tecnología Sky130) de cada bloque de la ALU, más el
top-level que los integra. No hay ningún generador automático de netlists
aquí: cada `.spice` está escrito y verificado a mano, con la lógica booleana
de cada bloque validada primero en Python (tabla de verdad completa) antes
de traducirla a transistores.

Todas las celdas usan los mismos dispositivos base de Sky130A a tamaño
mínimo: `sky130_fd_pr__nfet_01v8` (L=0.15µ, W=0.42µ) y
`sky130_fd_pr__pfet_01v8` (L=0.15µ, W=0.84µ, ancho doble para compensar la
menor movilidad de huecos).

## Jerarquía de `.include`

Varios archivos comparten subcircuitos (`xor2_sk130`, `and2_sk130`,
`inv_sk130`, etc.), así que se incluyen entre sí en cadena para no duplicar
definiciones (ngspice no permite dos `.subckt` con el mismo nombre, ni con
contenido idéntico):

```
full_adder_28t.spice          (base: inv_sk130, xor2_sk130, full_adder_28t)
  └─ comparator_4bit.spice    (.include full_adder_28t.spice)
       ├─ full_subtractor.spice     (.include full_adder_28t.spice)
       ├─ logic_ops_4bit.spice      (.include comparator_4bit.spice)
       └─ multiplier_4x4.spice      (.include comparator_4bit.spice)

alu_primitives.spice           (consolida TODO sin duplicados)
  └─ alu_4bit_top.spice        (.include alu_primitives.spice)
```

**Regla importante:** los testbenches de bloques individuales (`tb_full_adder.spice`,
`tb_comparator_4bit.spice`, etc.) incluyen su propio archivo de schematic
directamente. El testbench de la ALU completa (`tb_alu_4bit.spice`) en
cambio incluye `alu_primitives.spice` + `alu_4bit_top.spice` — **nunca**
mezcla ambos estilos en la misma simulación, porque duplicaría subcircuitos.

## Archivos

### `full_adder_28t.spice`
Full adder de 1 bit, CMOS estático (~28 transistores). Define también
`inv_sk130` (inversor básico) y `xor2_sk130`, el subcircuito XOR más
reutilizado de todo el proyecto.

- **`inv_sk130`**: inversor CMOS de 2 transistores.
- **`xor2_sk130`**: XOR de 2 entradas por transmission-gate (~8T). B y B'
  actúan como selectores de un mux 2:1 que pasa A o A' hacia la salida —
  nunca hay dos redes compitiendo por el mismo nodo de salida (ver la nota
  de rediseño en el archivo: una primera versión con red AOI de 12T sufría
  glitches por skew entre ramas al simular contra el PDK real).
- **`full_adder_28t`**: `Sum = A⊕B⊕Cin` con dos `xor2_sk130` en cascada;
  `Cout` con una red AOI22 pull-down/pull-up dual (verificada en Python)
  + inversor de salida.

### `comparator_4bit.spice`
Comparador de magnitud de 4 bits, estilo cascada tipo 7485 (MSB→LSB).
Incluye `full_adder_28t.spice` (reutiliza `inv_sk130`/`xor2_sk130`).

- **`xnor2_sk130`**: XNOR por transmission-gate (misma técnica que
  `xor2_sk130`, intercambiando qué dato pasa cada TG).
- **`and2_sk130`**: AND de 2 entradas (NAND + inversor).
- **`and2_inv_b_sk130`** / **`and2_inv_a_sk130`**: `A·B'` y `A'·B`
  respectivamente, usados para las señales locales `gt_i`/`lt_i` de cada bit.
- **`prop_or_and_sk130`**: celda de propagación `out = in_prop + (eq_in·local)`
  — implementa la regla de que la decisión de un bit más significativo se
  propaga sin cambios, y solo si los bits más significativos fueron
  iguales puede el bit actual decidir GT/LT.
- **`cmp_bit`**: celda de comparación de 1 bit; encadena `GT_in/LT_in/EQ_in`
  del bit más significativo hacia `GT_out/LT_out/EQ_out`.
- **`comparator_4bit`**: encadena 4 `cmp_bit` de MSB a LSB, con constantes
  iniciales `GT=0, LT=0, EQ=1` atadas a vss/vdd.

La fórmula de la cascada fue verificada contra las 256 combinaciones
posibles de A,B en Python antes de escribir el netlist.

### `full_subtractor.spice`
Full subtractor derivado del full adder: `A − B − Bin = A + B' + Bin'`
(complemento a 2). Incluye `full_adder_28t.spice`.

- **`full_subtractor`**: invierte B y Bin con dos inversores locales, los
  alimenta a una instancia de `full_adder_28t`, y re-invierte el `Cout` del
  adder para obtener `Bout` real (`Sum` del adder = `Diff`, directo, sin
  inversión adicional).

Nota de diseño documentada en el archivo: invertir *solo* B (sin invertir
también Bin) da el resultado complementado en las 8 combinaciones — ese fue
el primer intento y falló por completo.

### `logic_ops_4bit.spice`
Compuertas lógicas bit a bit de 4 bits: AND, OR, XOR (sin acarreo). Incluye
`comparator_4bit.spice` (que a su vez trae `and2_sk130`/`xor2_sk130`
transitivamente).

- **`or2_sk130`**: OR de 2 entradas (NOR + inversor), la única celda nueva
  de este archivo.
- **`and4_sk130`** / **`or4_sk130`** / **`xor4_sk130`**: aplican la celda
  de 1 bit a cada par `A[3:0]`/`B[3:0]` en paralelo.

### `multiplier_4x4.spice`
Array multiplier 4×4 → 8 bits (arquitectura completa, a diferencia del
2×2 truncado del post de LinkedIn de referencia del proyecto). Incluye
`comparator_4bit.spice`.

- **`half_adder_sk130`**: `S = A⊕B`, `C = A·B`.
- **16 productos parciales** `pp[j][i] = A_i · B_j` (uno por `and2_sk130`).
- **3 etapas de suma** (half adder en la primera columna de cada fila,
  full adder en el resto), con acarreo propagándose en diagonal hacia la
  fila siguiente — ver el diagrama ASCII dentro del archivo para el mapeo
  exacto de pesos por columna.
- **`inv_buf_sk130`**: buffer no-inversor (2 inversores en cascada) usado
  en las 8 salidas `P[7:0]` para dar drive extra.

La arquitectura de suma se verificó exhaustivamente en Python (256
combinaciones) antes de escribir el netlist: una primera versión tenía un
error de alineamiento de acarreos entre etapas que fallaba en 24/256 casos.

### `alu_primitives.spice`
Archivo de consolidación: reúne **sin duplicados** todos los subcircuitos
de los 5 archivos anteriores. Existe porque `alu_4bit_top.spice` necesita
todos los bloques a la vez, y no puede incluir cada `.spice` por separado
(cada uno arrastra su propia cadena de `.include`, lo que duplicaría
subcircuitos compartidos). Es el único archivo, junto con
`alu_4bit_top.spice`, que debe incluirse en el testbench de la ALU completa.

### `alu_4bit_top.spice`
Integración top-level. Incluye únicamente `alu_primitives.spice`.

- **`mux2_sk130`**: mux 2:1 por transmission-gate (misma técnica que
  `xor2_sk130`/`xnor2_sk130`).
- **`mux8_sk130`**: árbol de 7 `mux2_sk130` en 3 niveles (S0 controla el
  primer nivel, S1 el segundo, S2 el final) — selecciona 1 de 8 entradas.
- **`alu_4bit`**: instancia en paralelo los 6 bloques funcionales (ADD,
  SUB, MUL, CMP, AND, OR, XOR — 7 en total) y selecciona `Result[7:0]` y
  las banderas (`Cout`, `Bout`, `GT`, `LT`, `EQ`) con un `mux8_sk130` por
  bit, según `S[2:0]`. Tabla de operaciones completa en el encabezado del
  archivo.

**Nota de nombres de nodo:** la cadena de acarreo interna de SUB usa
`bw0/bw1/bw2` ("borrow"), no `b0/b1/b2` — ngspice no distingue mayúsculas de
minúsculas en nombres de nodo, así que `b0` habría colisionado
silenciosamente con el puerto de entrada `B0` de la propia ALU (mismo nodo
para ngspice), corrompiendo la resta. Este bug real se detectó porque el
full subtractor aislado daba el resultado correcto pero la integración
completa no.

# Formas de onda (waveforms)

Este directorio contiene las graficas de simulacion (SVG) generadas
directamente por ngspice via el comando `hardcopy` dentro de cada
testbench en `sim/`. Se regeneran corriendo el testbench correspondiente
contra el PDK real de Sky130:

```bash
cd sim
ngspice tb_full_adder.spice
```

No se editan a mano ni se suben capturas de pantalla: cada imagen es
reproducible con el comando de arriba, para que cualquiera que clone
el repo pueda regenerar exactamente la misma grafica.

NOTA: `hardcopy` en ngspice-42 falla con "PPerror: syntax error in line
segment" si se le pasan mas de 8 vectores en una sola linea (limite de
ancho de linea heredado del backend PostScript de ngspice). Por eso
varios testbenches generan varias graficas mas cortas en vez de una
sola con todas las señales.

| Archivo                          | Generado por                | Contenido                                |
|-----------------------------------|-------------------------------|--------------------------------------------|
| full_adder_28t.svg                | tb_full_adder.spice           | A, B, Cin, Sum, Cout (8 combinaciones)      |
| comparator_4bit_inputs.svg        | tb_comparator_4bit.spice      | A[3:0], B[3:0]                              |
| comparator_4bit_outputs.svg       | tb_comparator_4bit.spice      | GT, LT, EQ                                  |
| full_subtractor.svg               | tb_full_subtractor.spice      | A, B, Bin, Diff, Bout                       |
| logic_ops_inputs.svg              | tb_logic_ops_4bit.spice       | A[3:0], B[3:0]                              |
| logic_ops_and.svg                 | tb_logic_ops_4bit.spice       | Y[3:0] (AND)                                |
| logic_ops_or.svg                  | tb_logic_ops_4bit.spice       | Y[3:0] (OR)                                 |
| logic_ops_xor.svg                 | tb_logic_ops_4bit.spice       | Y[3:0] (XOR)                                |
| multiplier_4x4_inputs.svg         | tb_multiplier_4x4.spice       | A[3:0], B[3:0]                              |
| multiplier_4x4_p_high.svg         | tb_multiplier_4x4.spice       | P[7:4]                                      |
| multiplier_4x4_p_low.svg          | tb_multiplier_4x4.spice       | P[3:0]                                      |
| alu_4bit_result.svg               | tb_alu_4bit.spice              | Result[7:0] de la ALU top-level (12 casos)  |
| alu_4bit_flags.svg                | tb_alu_4bit.spice              | Cout, Bout, GT, LT, EQ de la ALU top-level  |
| alu_4bit_select.svg               | tb_alu_4bit.spice              | S[2:0], el selector de operacion            |

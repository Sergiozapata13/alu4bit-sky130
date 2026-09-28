# Formas de onda (waveforms)

Este directorio contiene las graficas de simulacion (PNG) generadas
directamente desde ngspice contra el PDK real de Sky130. Se regeneran
en dos pasos: correr el testbench (genera archivos `.ps`), y despues
convertirlos a PNG con el script incluido.

```bash
cd sim
ngspice -b tb_full_adder.spice
cd ../scripts
./convert_waveforms.sh
```

No se editan a mano ni se suben capturas de pantalla: cada imagen es
reproducible con los comandos de arriba, para que cualquiera que clone
el repo pueda regenerar exactamente la misma grafica.

NOTA 1: a pesar del nombre, el comando `hardcopy` de ngspice-42 genera
PostScript (EPS) puro, no SVG real -- por eso se usa `.ps` como
extension de salida y se convierte a PNG (con ghostscript) para que se
pueda previsualizar en el navegador y en GitHub. `convert_waveforms.sh`
hace esa conversion automaticamente; requiere `ghostscript` instalado
(`sudo apt install ghostscript`).

NOTA 2: `hardcopy`/`plot` en ngspice-42 fallan con "PPerror: syntax
error in line segment" en dos casos: (a) mas de 8 vectores en una sola
linea (limite de ancho heredado del backend PostScript), y (b) cuando
el nombre de un nodo coincide con una palabra reservada del parser de
expresiones -- especificamente `gt`, `lt`, `eq` (operadores >,<,=).
Por eso varios testbenches dividen las graficas en grupos mas cortos,
y las señales GT/LT/EQ se pasan entre comillas dobles ("v(gt)") para
forzar al parser a tratarlas como texto literal.

| Archivo                          | Generado por                | Contenido                                |
|-----------------------------------|-------------------------------|--------------------------------------------|
| full_adder_28t.png                | tb_full_adder.spice           | A, B, Cin, Sum, Cout (8 combinaciones)      |
| comparator_4bit_inputs.png        | tb_comparator_4bit.spice      | A[3:0], B[3:0]                              |
| comparator_4bit_outputs.png       | tb_comparator_4bit.spice      | GT, LT, EQ                                  |
| full_subtractor.png               | tb_full_subtractor.spice      | A, B, Bin, Diff, Bout                       |
| logic_ops_inputs.png              | tb_logic_ops_4bit.spice       | A[3:0], B[3:0]                              |
| logic_ops_and.png                 | tb_logic_ops_4bit.spice       | Y[3:0] (AND)                                |
| logic_ops_or.png                  | tb_logic_ops_4bit.spice       | Y[3:0] (OR)                                 |
| logic_ops_xor.png                 | tb_logic_ops_4bit.spice       | Y[3:0] (XOR)                                |
| multiplier_4x4_inputs.png         | tb_multiplier_4x4.spice       | A[3:0], B[3:0]                              |
| multiplier_4x4_p_high.png         | tb_multiplier_4x4.spice       | P[7:4]                                      |
| multiplier_4x4_p_low.png          | tb_multiplier_4x4.spice       | P[3:0]                                      |
| alu_4bit_result.png               | tb_alu_4bit.spice              | Result[7:0] de la ALU top-level (12 casos)  |
| alu_4bit_flags.png                | tb_alu_4bit.spice              | Cout, Bout, GT, LT, EQ de la ALU top-level  |
| alu_4bit_select.png               | tb_alu_4bit.spice              | S[2:0], el selector de operacion            |

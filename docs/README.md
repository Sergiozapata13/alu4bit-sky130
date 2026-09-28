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

Ver `../schematics/README.md` y `../sim/README.md` para el detalle de cada
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

```bash
cd sim
ngspice -b tb_full_adder.spice     # modo batch: corre y termina solo
```

Cada testbench (uno por bloque, más `tb_alu_4bit.spice` para el top-level)
corre la simulación transitoria, imprime en consola las mediciones de
`.meas` (delay de propagación y/o potencia dinámica promedio, según el
bloque) y genera archivos `.ps` en `docs/waveforms/` vía `hardcopy`. Para
convertirlos a `.png` visibles en GitHub:

```bash
cd ../scripts
./convert_waveforms.sh
```

Ver `../sim/README.md` para el detalle de qué mide y qué genera cada
testbench, y `waveforms/README.md` para el resultado ya convertido.

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

### Potencia dinámica promedio, por bloque

| Bloque | Ancho | Potencia promedio | Ventana simulada |
|---|---|---|---|
| Full adder (1 bit) | 1 bit | 1.365 µW | 128 ns |
| Full subtractor (1 bit) | 1 bit | 2.383 µW | 128 ns |
| Comparador de magnitud | 4 bits | 8.497 µW | 144 ns |
| Lógica AND+OR+XOR (conjunto) | 4 bits ×3 | 3.539 µW | 32 ns |
| Multiplicador array | 4×4→8 bits | 24.35 µW | 160 ns |
| **ALU top-level (12 operaciones)** | 4 bits | **27.39 µW** | 192 ns |

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

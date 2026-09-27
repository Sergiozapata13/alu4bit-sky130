# ALU 4-bit mejorada — Proyecto de portafolio

Flujo: Xschem (opcional, para editar visualmente) + ngspice + PDK Sky130.
Ver el documento de investigación previa para contexto completo.

## Estado actual

- [x] Investigación previa (acceso a herramienta, topologías, metodología de caracterización)
- [x] Especificación: ALU 8 operaciones, S[2:0]
- [x] Full adder 28T — netlist SPICE + testbench de verificación funcional y delay/potencia
      (topología verificada con modelos genéricos nivel-1: las 8 combinaciones de A/B/Cin
      dan Sum y Cout correctos; pendiente re-confirmar con los modelos reales de Sky130
      una vez instalado el PDK)
- [ ] Full subtractor (derivado del full adder: A + B' + 1)
- [ ] Comparador de magnitud 4 bits (XNOR + prioridad)
- [ ] Array multiplier 4x4
- [ ] Compuertas lógicas AND/OR/XOR de 4 bits
- [ ] Mux de selección 8 vías (S[2:0])
- [ ] Integración top-level
- [ ] Caracterización completa (delay, potencia, PDP) por operación
- [ ] (Opcional) Wallace tree + comparación contra array multiplier

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

## Correr la simulación del full adder

```bash
cd sim
ngspice tb_full_adder.spice
```

Esto corre la simulación transitoria, grafica las formas de onda (A, B, Cin, Sum, Cout)
y en la consola imprime:
- `tpd_a_sum_r` / `tpd_a_sum_f`: delay de propagación A→Sum (subida/bajada), cruce 50% VDD
- `tpd_a_cout_r` / `tpd_a_cout_f`: delay de propagación A→Cout
- `avg_power`: potencia dinámica promedio sobre la ventana simulada

## Notas de diseño

- **Sizing de transistores**: los valores W/L en el netlist (0.42µ/0.84µ, L=0.15µ) son un
  punto de partida típico para sky130A a tamaño mínimo. En la Fase 4 (caracterización) se
  ajustan si el delay o el consumo no son razonables — es normal iterar aquí.
- **Cload constante**: la capacitancia de carga (`CLOAD=10f` en el testbench) debe mantenerse
  igual en todos los bloques de la ALU para que la comparación entre arquitecturas
  (por ejemplo array multiplier vs. Wallace tree) sea válida.
- **Ruta de modelos**: ajustar `$::SKY130A_MODELS` en `tb_full_adder.spice` a la ruta real
  una vez instalado el PDK — varía según el método de instalación (ciel vs. open_pdks manual).

## Siguiente bloque: Full Subtractor

Se deriva directamente del full adder invirtiendo B antes de sumar (A + B' + Cin'),
técnica estándar en ALUs reales para compartir hardware entre suma y resta. Se construirá
como un wrapper sobre `full_adder_28t` con un inversor en la entrada B y ajuste de Cin.

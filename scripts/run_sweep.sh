#!/usr/bin/env bash
# ============================================================
# run_sweep.sh -- corre un testbench SPICE con un VDD y/o una
# temperatura distintos a los nominales, sin tener que mantener un
# archivo duplicado por cada combinacion.
#
# Uso:
#   ./run_sweep.sh <testbench.spice> [VDD] [TEMP]
#
# VDD y TEMP son opcionales -- si se omiten, se usa el valor nominal
# del testbench (VDD_VAL=1.8, TEMP=27 implicito de ngspice).
#
# Ejemplos:
#   ./run_sweep.sh tb_full_adder.spice 1.62          # VDD -10%, temp nominal
#   ./run_sweep.sh tb_full_adder.spice 1.98          # VDD +10%, temp nominal
#   ./run_sweep.sh tb_full_adder.spice "" 0          # VDD nominal, 0 C
#   ./run_sweep.sh tb_full_adder.spice "" 85         # VDD nominal, 85 C
#   ./run_sweep.sh tb_full_adder.spice 1.62 85       # ambos combinados
#
# Funciona sobre una copia temporal del testbench (el original en el
# repo nunca se modifica):
#   - VDD: reemplaza la linea ".param VDD_VAL=<numero>" por el valor
#     pedido. Como todas las fuentes PWL y los .meas ya usan
#     {VDD_VAL} / {VDD_VAL/2} en vez de un numero fijo, cambiar este
#     unico .param reescala automaticamente estimulos y umbrales de
#     medicion sin tocar el resto del netlist.
#   - TEMP: agrega una linea ".temp <numero>" justo antes de ".end"
#     (ngspice usa 27C por defecto si no hay ninguna .temp).
# ============================================================
set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 3 ]; then
    echo "Uso: $0 <testbench.spice> [VDD] [TEMP]" >&2
    exit 1
fi

TB="$1"
VDD_OVERRIDE="${2:-}"
TEMP_OVERRIDE="${3:-}"

if [ ! -f "$TB" ]; then
    echo "Error: no se encuentra el archivo '$TB'" >&2
    exit 1
fi

if [ -z "$VDD_OVERRIDE" ] && [ -z "$TEMP_OVERRIDE" ]; then
    echo "Error: hay que dar al menos VDD o TEMP (si ninguno cambia, correr ngspice directo)" >&2
    exit 1
fi

TMPFILE=$(mktemp --suffix=.spice)
trap 'rm -f "$TMPFILE"' EXIT

cp "$TB" "$TMPFILE"

if [ -n "$VDD_OVERRIDE" ]; then
    sed -i -E 's/^(\.param[[:space:]]+VDD_VAL=)[0-9.eE+-]+([[:space:]]*)$/\1'"$VDD_OVERRIDE"'\2/' "$TMPFILE"
    if ! grep -qE "^\.param[[:space:]]+VDD_VAL=$VDD_OVERRIDE" "$TMPFILE"; then
        echo "Error: no se pudo reemplazar VDD_VAL en '$TB' -- revisar formato de la linea .param" >&2
        exit 1
    fi
fi

if [ -n "$TEMP_OVERRIDE" ]; then
    # Inserta ".temp <valor>" justo antes de la linea ".end" final
    sed -i "s/^\.end\$/.temp ${TEMP_OVERRIDE}\n.end/" "$TMPFILE"
    if ! grep -qE "^\.temp[[:space:]]+${TEMP_OVERRIDE}\$" "$TMPFILE"; then
        echo "Error: no se pudo insertar .temp en '$TB' -- revisar que termine en una linea '.end'" >&2
        exit 1
    fi
fi

echo "=== Corriendo $TB con VDD=${VDD_OVERRIDE:-nominal} TEMP=${TEMP_OVERRIDE:-27 (nominal)} ==="
ngspice -b "$TMPFILE" 2>&1

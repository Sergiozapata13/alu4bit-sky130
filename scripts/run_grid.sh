#!/usr/bin/env bash
# ============================================================
# run_grid.sh -- corre TODOS los testbenches del proyecto contra un
# grid completo de VDD x TEMPERATURA (3x3 = 9 combinaciones), y junta
# los resultados de avg_power y cada tpd_* en un unico CSV.
#
# Uso (desde la carpeta sim/):
#   ../scripts/run_grid.sh
#
# Genera: grid_results.csv en el directorio actual, con columnas:
#   testbench,vdd,temp,measurement,value
#
# Requiere run_sweep.sh en la misma carpeta scripts/ (reutiliza su
# logica de sustitucion de VDD_VAL y .temp via sed).
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_CSV="grid_results.csv"

TESTBENCHES=(
    tb_full_adder.spice
    tb_full_subtractor.spice
    tb_comparator_4bit.spice
    tb_logic_ops_4bit.spice
    tb_multiplier_4x4.spice
    tb_alu_4bit.spice
)

VDDS=(1.62 1.8 1.98)
TEMPS=(0 27 85)

echo "testbench,vdd,temp,measurement,value" > "$OUT_CSV"

total=$(( ${#TESTBENCHES[@]} * ${#VDDS[@]} * ${#TEMPS[@]} ))
count=0

for tb in "${TESTBENCHES[@]}"; do
    for vdd in "${VDDS[@]}"; do
        for temp in "${TEMPS[@]}"; do
            count=$((count+1))
            echo "[$count/$total] $tb  VDD=$vdd  TEMP=$temp" >&2

            # temp=27 es el nominal de ngspice: si tambien vdd=1.8, no
            # hace falta pasar overrides (corre el archivo tal cual)
            if [ "$vdd" = "1.8" ] && [ "$temp" = "27" ]; then
                RAW=$(ngspice -b "$tb" 2>&1)
            elif [ "$temp" = "27" ]; then
                RAW=$("$SCRIPT_DIR/run_sweep.sh" "$tb" "$vdd" 2>&1)
            elif [ "$vdd" = "1.8" ]; then
                RAW=$("$SCRIPT_DIR/run_sweep.sh" "$tb" "" "$temp" 2>&1)
            else
                RAW=$("$SCRIPT_DIR/run_sweep.sh" "$tb" "$vdd" "$temp" 2>&1)
            fi

            # Extrae solo la PRIMERA ocurrencia de cada medicion (el
            # bloque de .control corre el analisis dos veces en modo
            # batch, la segunda es identica -- nos quedamos con la
            # primera aparicion de cada nombre de variable)
            echo "$RAW" | grep -E "^(tpd_|avg_power)" | \
                awk -v tb="$tb" -v vdd="$vdd" -v temp="$temp" '
                {
                    name=$1
                    val=$3
                    if (!(name in seen)) {
                        seen[name]=1
                        print tb "," vdd "," temp "," name "," val
                    }
                }' >> "$OUT_CSV"
        done
    done
done

echo "" >&2
echo "Listo. Resultados en: $OUT_CSV" >&2
echo "Total de filas: $(($(wc -l < "$OUT_CSV") - 1))" >&2

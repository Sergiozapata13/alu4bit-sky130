#!/usr/bin/env bash
# ============================================================
# run_corner.sh -- corre un testbench SPICE con una esquina de
# proceso distinta, sin tener que mantener un archivo duplicado
# por cada corner.
#
# Uso:
#   ./run_corner.sh <testbench.spice> <corner>
#
# Ejemplo:
#   ./run_corner.sh tb_full_adder.spice ff
#   ./run_corner.sh tb_multiplier_4x4.spice ss
#
# Funciona reemplazando, en una copia temporal del testbench, el
# ultimo argumento de la linea ".lib "<ruta>" tt" por el corner
# pedido (tt/ff/ss/sf/fs), y corriendo ngspice sobre esa copia.
# El archivo original en el repo NUNCA se modifica.
# ============================================================
set -euo pipefail

if [ $# -ne 2 ]; then
    echo "Uso: $0 <testbench.spice> <corner: tt|ff|ss|sf|fs>" >&2
    exit 1
fi

TB="$1"
CORNER="$2"

case "$CORNER" in
    tt|ff|ss|sf|fs) ;;
    *)
        echo "Error: corner '$CORNER' no reconocido (usar tt, ff, ss, sf o fs)" >&2
        exit 1
        ;;
esac

if [ ! -f "$TB" ]; then
    echo "Error: no se encuentra el archivo '$TB'" >&2
    exit 1
fi

TMPFILE=$(mktemp --suffix=.spice)
trap 'rm -f "$TMPFILE"' EXIT

# Reemplaza SOLO el nombre de corner al final de la linea .lib
# (busca la linea que empieza con .lib " y termina en tt/ff/ss/sf/fs,
# y le cambia el ultimo token).
sed -E 's/^(\.lib[[:space:]]+"[^"]+"[[:space:]]+)(tt|ff|ss|sf|fs)[[:space:]]*$/\1'"$CORNER"'/' \
    "$TB" > "$TMPFILE"

# Verificacion: confirmar que el reemplazo si ocurrio (si no hay
# ninguna linea .lib con ese patron, algo esta mal en el testbench)
if ! grep -qE "^\.lib[[:space:]]+\"[^\"]+\"[[:space:]]+$CORNER[[:space:]]*$" "$TMPFILE"; then
    echo "Error: no se pudo reemplazar la linea .lib en '$TB' -- revisar formato" >&2
    exit 1
fi

echo "=== Corriendo $TB con esquina de proceso: $CORNER ==="
ngspice -b "$TMPFILE" 2>&1

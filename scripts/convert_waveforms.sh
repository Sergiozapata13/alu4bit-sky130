#!/bin/bash
# ============================================================
# Convierte las graficas de forma de onda (PostScript, generadas por
# el comando 'hardcopy' de ngspice) a PNG, para que se puedan ver en
# el navegador y se previsualicen en GitHub.
#
# IMPORTANTE: a pesar de que en versiones anteriores de los testbenches
# se les puso extension .svg, 'hardcopy' de ngspice-42 genera
# PostScript puro (EPS), no SVG real -- por eso no se veian ni en el
# navegador ni en GitHub. Los testbenches ahora generan .ps
# directamente; este script los convierte a .png.
#
# Requiere ghostscript (el paquete 'gs') o ImageMagick con ghostscript
# como backend. Si no lo tenes instalado:
#   sudo apt install ghostscript
#
# Uso: correr los testbenches primero (para generar los .ps en
# docs/waveforms/), y despues este script desde la carpeta scripts/:
#   cd scripts
#   ./convert_waveforms.sh
# ============================================================

set -e

WAVEFORMS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../docs/waveforms" && pwd)"

if ! command -v gs >/dev/null 2>&1; then
    echo "ERROR: ghostscript (comando 'gs') no esta instalado."
    echo "Instalalo con: sudo apt install ghostscript"
    exit 1
fi

echo "Convirtiendo archivos .ps en $WAVEFORMS_DIR ..."
count=0
for ps_file in "$WAVEFORMS_DIR"/*.ps; do
    [ -e "$ps_file" ] || continue
    png_file="${ps_file%.ps}.png"
    echo "  $(basename "$ps_file") -> $(basename "$png_file")"
    gs -q -dSAFER -dBATCH -dNOPAUSE -sDEVICE=png16m -r150 \
       -sOutputFile="$png_file" "$ps_file"
    count=$((count + 1))
done

echo "Listo: $count archivo(s) convertido(s)."
echo "Los .ps originales se mantienen; si preferis no subirlos al repo,"
echo "borralos con: rm $WAVEFORMS_DIR/*.ps"

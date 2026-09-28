# Scripts

Utilidades de soporte para el proyecto: convertir las waveforms de
simulación a un formato visible en GitHub, e instalar el PDK Sky130 desde
tarballs ya descargados (evita el streaming de red inestable de `ciel`).

## `convert_waveforms.sh`

Convierte los `.ps` generados por el comando `hardcopy` de ngspice (ver
`../sim/README.md`) a `.png`, usando ghostscript.

**Por qué existe:** a pesar de que versiones anteriores de los testbenches
usaban `.svg` como extensión de salida, el comando `hardcopy` de ngspice-42
genera PostScript (EPS) puro, no SVG real — por eso esos archivos no se
veían ni en el navegador ni en GitHub. Los testbenches ahora generan `.ps`
directamente y este script los convierte a `.png` real, que sí se
previsualiza en cualquier lado.

**Requiere** ghostscript instalado (`sudo apt install ghostscript`).

**Uso:**
```bash
# 1. Correr los testbenches primero (genera los .ps en docs/waveforms/)
cd sim
ngspice -b tb_full_adder.spice
# ... (o los otros testbenches)

# 2. Convertir todos los .ps encontrados a .png
cd ../scripts
./convert_waveforms.sh
```

Recorre `docs/waveforms/*.ps`, y por cada uno corre:
```bash
gs -q -dSAFER -dBATCH -dNOPAUSE -sDEVICE=png16m -r150 -sOutputFile="X.png" "X.ps"
```
(resolución 150 dpi). Los `.ps` originales no se borran — se ignoran vía
`.gitignore` para no subirlos al repo, pero quedan localmente por si hace
falta reconvertir sin volver a correr ngspice. Para borrarlos:
```bash
rm ../docs/waveforms/*.ps
```

## `install_pdk_from_local.py`

Instala el PDK Sky130 en la estructura de directorios que espera `ciel`,
a partir de tarballs `.tar.zst` ya descargados localmente — evita que
`ciel enable` intente el streaming de red interno, que se corta con
conexiones inestables.

Replica exactamente la lógica de extracción de `ciel/manage.py`
(`enable_or_build`): descomprime cada `.tar.zst` con `zstandard` y extrae
el tar resultante directo a la carpeta de versión
(`~/.ciel/ciel/sky130/versions/<hash>/`).

**Requiere** el paquete Python `zstandard` (`pip install zstandard`).

**Uso:**
```bash
python3 install_pdk_from_local.py <ruta_a_tarballs_descargados> <hash_de_version>

# Ejemplo:
python3 install_pdk_from_local.py ~/pdk-downloads 1689ac3f2dc763876eaf967227c7dfe831b031ae
```

Después de instalar, activar la versión con:
```bash
ciel enable --pdk-family sky130 <hash_de_version>
```

Esta es la ruta alternativa a la instalación estándar (`ciel enable --pdk
sky130`, documentada en `../docs/README.md`); usarla solo si esa
instalación estándar falla por problemas de red.

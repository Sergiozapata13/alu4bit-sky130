# Scripts

Utilidades de soporte para el proyecto: convertir las waveforms de
simulación a un formato visible en GitHub, instalar el PDK Sky130 desde
tarballs ya descargados (evita el streaming de red inestable de `ciel`), y
correr un testbench contra una esquina de proceso distinta sin duplicar
archivos.

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

## `run_corner.sh`

Corre un testbench contra una esquina de proceso (`tt`/`ff`/`ss`/`sf`/`fs`)
distinta a la que tiene escrita en su línea `.lib`, sin tener que mantener
un archivo duplicado por cada esquina.

**Por qué existe:** ngspice no soporta sustitución de texto arbitraria
(tipo `{VARIABLE}`) dentro de la ruta o el nombre de sección de una
directiva `.lib` — solo evalúa expresiones numéricas ahí. La alternativa
más simple y auditable, sin agregar lógica condicional dentro de cada
netlist, es generar una copia temporal del testbench con el nombre de
esquina reemplazado por `sed`, correr ngspice sobre esa copia, y borrarla
al terminar. El archivo original en el repo nunca se modifica.

**Uso:**
```bash
cd sim
../scripts/run_corner.sh tb_full_adder.spice ff
../scripts/run_corner.sh tb_multiplier_4x4.spice ss
```

Ver la sección "Análisis de esquinas de proceso" en el `README.md`
principal para los resultados obtenidos en `ff` y `ss` sobre los 6
testbenches del proyecto.

## `run_sweep.sh`

Corre un testbench con un VDD y/o una temperatura distintos a los
nominales (1.8V / 27°C), sin mantener un archivo duplicado por cada
combinación.

**Por qué existe:** igual que con las esquinas de proceso, la forma más
simple y auditable de variar VDD/TEMP sin lógica condicional dentro de
cada netlist es generar una copia temporal del testbench, sustituir la
línea `.param VDD_VAL=...` y/o insertar una directiva `.temp` antes del
`.end` con `sed`, correr ngspice sobre esa copia, y borrarla al
terminar. El archivo original nunca se modifica.

**Uso:**
```bash
cd sim
../scripts/run_sweep.sh tb_full_adder.spice 1.62        # solo VDD
../scripts/run_sweep.sh tb_full_adder.spice "" 85        # solo TEMP
../scripts/run_sweep.sh tb_full_adder.spice 1.98 0       # ambos
```

Es la base sobre la que se construye `run_grid.sh` (abajo).

## `run_grid.sh`

Corre los 6 testbenches del proyecto contra un grid factorial completo
de VDD × temperatura (3×3 = 9 combinaciones por bloque, 54 corridas en
total), y junta todas las mediciones (`avg_power` y cada `tpd_*`) en un
único CSV.

**Por qué existe:** un barrido simple (variar VDD sola, luego TEMP sola,
mantiniendo la otra en su valor nominal) no puede revelar una
interacción entre ambas variables — solo un grid cruzado, donde se
prueban las 9 combinaciones de `{1.62V, 1.8V, 1.98V} × {0°C, 27°C,
85°C}`, permite ver eso. Ver la sección "Barrido de VDD y temperatura
(grid completo)" en el `README.md` principal, donde este grid reveló una
interacción no lineal de potencia en la ALU top-level que no aparece en
ningún bloque individual.

**Uso:**
```bash
cd sim
../scripts/run_grid.sh
```

Genera `grid_results.csv` en el directorio actual (formato:
`testbench,vdd,temp,measurement,value`), reutilizando `run_sweep.sh`
internamente para cada combinación que no sea la nominal (1.8V/27°C, que
corre directo).

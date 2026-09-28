#!/usr/bin/env python3
"""
Instala el PDK Sky130 en la estructura que espera ciel, usando tarballs
ya descargados localmente (evita el streaming de red que ciel hace
internamente, el cual se corta con conexiones inestables).

Replica exactamente la logica de extraccion de ciel/manage.py (funcion
enable_or_build, lineas ~219-233): descomprime cada .tar.zst con zstandard
y extrae el tar resultante directo a la carpeta de version.

Uso:
    python3 install_pdk_from_local.py <ruta_downloads> <hash_version>

Ejemplo:
    python3 install_pdk_from_local.py ~/pdk-downloads 1689ac3f2dc763876eaf967227c7dfe831b031ae
"""
import sys
import tarfile
from pathlib import Path

try:
    import zstandard as zstd
except ImportError:
    print("ERROR: falta el paquete 'zstandard'. Instalar con: pip install zstandard")
    sys.exit(1)


def main():
    if len(sys.argv) != 3:
        print(f"Uso: {sys.argv[0]} <ruta_downloads> <hash_version>")
        sys.exit(1)

    downloads_dir = Path(sys.argv[1]).expanduser()
    version_hash = sys.argv[2]

    # Mismo pdk_root por defecto que usa ciel (ver ciel enable --help)
    pdk_root = Path.home() / ".ciel"
    version_directory = pdk_root / "ciel" / "sky130" / "versions" / version_hash

    tarballs = sorted(downloads_dir.glob("*.tar.zst"))
    if not tarballs:
        print(f"ERROR: no se encontraron archivos .tar.zst en {downloads_dir}")
        sys.exit(1)

    print(f"Instalando {len(tarballs)} tarballs en: {version_directory}")
    version_directory.mkdir(parents=True, exist_ok=True)

    for tarball_path in tarballs:
        print(f"  Extrayendo {tarball_path.name} ...")
        try:
            dctx = zstd.ZstdDecompressor()
            with open(tarball_path, "rb") as fh:
                stream = dctx.stream_reader(fh)
                with tarfile.open(fileobj=stream, mode="r|") as tf:
                    for member in tf:
                        if member.isdir():
                            continue
                        final_path = version_directory / member.name
                        final_path.parent.mkdir(parents=True, exist_ok=True)
                        io = tf.extractfile(member)
                        if io is None:
                            print(f"    AVISO: no se pudo leer {member.name}, saltando")
                            continue
                        with open(final_path, "wb") as out:
                            out.write(io.read())
        except Exception as e:
            print(f"    ERROR extrayendo {tarball_path.name}: {e}")
            sys.exit(1)

    print()
    print("Instalacion completa.")
    print(f"Version instalada en: {version_directory}")
    print()
    print("Siguiente paso: activarla con ciel enable (ya no debe descargar nada):")
    print(f"  ciel enable --pdk-family sky130 {version_hash}")


if __name__ == "__main__":
    main()

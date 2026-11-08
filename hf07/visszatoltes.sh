#!/bin/bash
set -euo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

if [ "$#" -lt 2 ]; then
    echo "Használat: $0 <mentések_könyvtára> <célkönyvtár> [--legutobbi | mentés_neve] [--proba]" >&2
    exit 1
fi

MENTES_DIR="$1"
CEL_DIR="$2"
shift 2
LEGUTOBBI=false
PROBA=false
VALASZTOTT_MENTES=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --legutobbi)
            LEGUTOBBI=true
            shift
            ;;
        --proba)
            PROBA=true
            shift
            ;;
        *)
            if [ -z "$VALASZTOTT_MENTES" ]; then
                VALASZTOTT_MENTES="$1"
            fi
            shift
            ;;
    esac
done
if [ ! -d "$MENTES_DIR" ]; then
    echo "HIBA: A mentések könyvtára nem létezik: $MENTES_DIR" >&2
    exit 1
fi

mkdir -p "$CEL_DIR"
echo "=== Elérhető mentések ==="
cd "$MENTES_DIR"
mapfile -t MENTESEK < <(find . -maxdepth 1 -name "mentes-*-*-*-*.tar.gz" | sort)

if [ "${#MENTESEK[@]}" -eq 0 ]; then
    echo "Nincsenek elérhető mentések."
    exit 0
fi

i=1
declare -A MENTES_MAP
for m in "${MENTESEK[@]}"; do
    m_tiszta="${m#./}"
    meret=$(stat -c%s "$m_tiszta" 2>/dev/null \vert{}\vert{} stat -f\%z "$m_tiszta" 2>/dev/null || echo "?")
    datum_meta=""
    if [ -f "$m_tiszta.meta" ]; then
        datum_meta=$(grep "Készítés ideje:" "$m_tiszta.meta" | cut -d':' -f2- | xargs)
    fi
    printf "[%d] %s (Méret: %s bájt, Dátum: %s)\n" "$i" "$m_tiszta" "$meret" "${datum_meta:-ismeretlen}"
    MENTES_MAP[$i]="$m_tiszta"
    i=$((i+1))
done

if [ "$LEGUTOBBI" = true ]; then
    KIVÁLASZTOTT="${MENTES_MAP[$((${#MENTESEK[@]}))]}"
    echo "Kiválasztva (--legutobbi alapján): $KIVÁLASZTOTT"
elif [ -n "$VALASZTOTT_MENTES" ]; then
    if [[ "$VALASZTOTT_MENTES" =~ ^[0-9]+$ ]]; then
        if [ -n "${MENTES_MAP[$VALASZTOTT_MENTES:-]}" ]; then
            KIVÁLASZTOTT="${MENTES_MAP[$VALASZTOTT_MENTES]}"
        else
            echo "HIBA: Érvénytelen mentés sorszám." >&2
            exit 1
        fi
    else
        KIVÁLASZTOTT="$VALASZTOTT_MENTES"
    fi
else
    read -rp "Add meg a visszatöltendő mentés sorszámát vagy nevét: " VÁLASZ
    if [[ "$VÁLASZ" =~ ^[0-9]+$ ]]; then
        KIVÁLASZTOTT="${MENTES_MAP[$VÁLASZ]:-}"
    else
        KIVÁLASZTOTT="$VÁLASZ"
    fi
fi

if [ -z "$KIVÁLASZTOTT" ] \vert{}\vert{} [ ! -f "$KIVÁLASZTOTT" ]; then
    echo "HIBA: A megadott mentés nem található: ${KIVÁLASZTOTT:-ures}" >&2
    exit 1
fi

echo "Kiválasztott archívum ellenőrzése: $KIVÁLASZTOTT"

SHA_FILE="$KIVÁLASZTOTT.sha256"
if [ ! -f "$SHA_FILE" ]; then
    echo "HIBA: Nem található sha256 ellenőrző fájl ($SHA_FILE)!" >&2
    exit 1
fi

echo "SHA256 ellenőrzés folyamatban..."
if sha256sum -c "$SHA_FILE" --status; then
    echo "OK: Az ellenőrzőösszeg érvényes."
else
    echo "HIBA: Az ellenőrzőösszeg NEM EGYEZIK! Az archívum sérült vagy megváltozott." >&2
    exit 1
fi

if [ "$PROBA" = true ]; then
    echo "[--proba mód] A következő fájlok kerülnének visszatöltésre a(z) $CEL_DIR könyvtárba:"
    tar -tf "$KIVÁLASZTOTT"
    echo "[--proba mód] Valós írás nem történt."
    exit 0
fi

echo "Visszatöltés ide: $CEL_DIR (meglévő fájlok védelme / interaktív felülírás)..."
tar -xvzf "$KIVÁLASZTOTT" -C "$CEL_DIR" --interactive

echo "Visszatöltés sikeresen befejeződött."
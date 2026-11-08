#!/bin/bash
set -euo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

if [ "$#" -lt 2 ]; then
    echo "Használat: $0 <forráskönyvtár> <célkönyvtár> [retenció_szám]" >&2
    exit 1
fi

FORRAS="$1"
CEL="$2"
RETENCIO="${3:-7}"

mkdir -p "$CEL"
LOG_FILE="$CEL/mentes.log"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" \vert{} tee -a "$LOG_FILE"
}

log "Mentés script elindult. Forrás: $FORRAS, Cél: $CEL, Retenció: $RETENCIO"

if [ ! -d "$FORRAS" ]; then
    log "HIBA: A forráskönyvtár nem létezik: $FORRAS"
    exit 1
fi

LOCK_FILE="$CEL/mentes.lock"
exec 200> "$LOCK_FILE"
if ! flock -n 200; then
    log "HIBA: Már fut egy mentési folyamat. Kilépés."
    exit 1
fi

DATUM=$(date +%Y-%m-%d-%H%M)
ARCHIV_NEV="mentes-$DATUM.tar.gz"
ARCHIV_UT="$CEL/$ARCHIV_NEV"
SHA_UT="$ARCHIV_UT.sha256"
META_UT="$ARCHIV_UT.meta"

log "Archívum készítése: $ARCHIV_UT"

if tar -czf "$ARCHIV_UT" -C "$(dirname "$FORRAS")" "$(basename "$FORRAS")"; then
    log "Archívum sikeresen létrehozva."
else
    log "HIBA: Hiba történt a tar archívum készítése közben."
    exit 1
fi

sha256sum "$ARCHIV_UT" > "$SHA_UT"
log "SHA256 ellenőrzőösszeg generálva: $(cat "$SHA_UT")"

MEKKORA=$(stat -c%s "$ARCHIV_UT" 2>/dev/null \vert{}\vert{} stat -f\%z "$ARCHIV_UT" 2>/dev/null || echo "ismeretlen")
FAJLOK_SZAMA=$(tar -tzf "$ARCHIV_UT" | wc -l)
MIKOR=$(date '+%Y-%m-%d %H:%M:%S')

cat << EOF > "$META_UT"
Készítés ideje: $MIKOR
Méret bájtban: $MEKKORA
Fájlok száma: $FAJLOK_SZAMA
Forrás: $FORRAS
EOF
log "Metafájl létrehozva: $META_UT"

log "Retenció ellenőrzése (határ: $RETENCIO darab)..."
cd "$CEL"
mapfile -t MENTESEK < <(find . -maxdepth 1 -name "mentes-*-*-*-*.tar.gz" | sort)

darab=${#MENTESEK[@]}
log "Jelenlegi mentések száma a célkönyvtárban: $darab"

if [ "$darab" -gt "$RETENCIO" ]; then
    torlendo_db=$((darab - RETENCIO))
    log "$torlendo_db darab régi mentés törlése..."
    for ((i=0; i<torlendo_db; i++)); do
        regi="${MENTESEK[$i]}"
        regi_tiszta="${regi#./}"
        log "Törlésre kerül: $regi_tiszta (és a hozzá tartozó sha256 / meta fájlok)"
        rm -f "$regi_tiszta" "$regi_tiszta.sha256" "$regi_tiszta.meta"
    done
fi
log "Mentési folyamat sikeresen befejeződött."
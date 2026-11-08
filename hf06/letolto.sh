#!/usr/bin/env bash
set -euo pipefail
TARGET_DIR="./downloads"
LOG_FILE="letoltes.log"
mkdir -p "$TARGET_DIR"

# 2. feladat: Ideiglenes könyvtár és trap takarítás EXIT-re (Ctrl+C-nél és hibánál is)
TMP_DIR=$(mktemp -d)

cleanup() {
    local exit_code=$?
    rm -rf "$TMP_DIR"
    exit "$exit_code"
}
trap cleanup EXIT

log() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$LOG_FILE"
    echo "$message"
}

# Tesztelési URL-ek listája
URLS=(
    "https://api.frankfurter.dev/v1/latest"
    "https://api.open-meteo.com/v1/forecast?latitude=47.5&longitude=19.05&current=temperature_2m"
    "https://date.nager.at/api/v3/PublicHolidays/2026/HU"
    "https://httpbin.org/status/500"
    "https://httpbin.org/delay/10"
    "https://ez.a.domain.biztosan.nem.letezik/valami.json"
)

success_count=0
fail_count=0
declare -A failure_reasons

log "--- Letöltési folyamat kezdete ---"

for url in "${URLS[@]}"; do
    log "Feldolgozás alatt: $url"
    
    # Biztonságos, egyedi ideiglenes fájlnév generálása az URL alapján
    clean_name=$(echo "$url" | sed -E 's#https?://##' | tr '/?&=' '_')
    temp_file="$TMP_DIR/$clean_name"
    final_file="$TARGET_DIR/$clean_name"

    attempt=1
    max_attempts=3
    download_success=false

    while [ $attempt -le$max_attempts ]; do
        if [ $attempt -gt 1 ]; then
            # 3. feladat: Exponenciális backoff (2. próbálkozás előtt 1s, 3. előtt 2s várakozás)
            sleep_time=$(( 1 << (attempt - 2) ))
            log "Újrapróbálkozás (#$attempt) -> Várakozás ${sleep_time}s..."
            sleep "$sleep_time"
        fi

        # Csapda megoldása: A curl hívás egy 'if' feltételbe van ágyazva.
        # A set -e ellenére ez megakadályozza, hogy a curl hibakódja azonnal kiléptesse a scriptet,
        # így a ciklus folytatódni tud és az újrapróbálkozás / hibakezelés lefut.
        if curl -sS --fail --max-time 15 "$url" -o "$temp_file"; then
            download_success=true
            break
        else
            log "Figyelem: A(z) $attempt. próbálkozás sikertelen volt ($url)."
        fi

        attempt=$((attempt + 1))
    done

    if [ "$download_success" = true ]; then
        # 4. feladat: Atomi írás (csak a sikeres letöltés után mozgatjuk át a végleges helyre)
        mv "$temp_file" "$final_file"
        log "SIKER: $url ->$final_file"
        success_count=$((success_count + 1))
    else
        log "HIBA: Nem sikerült letölteni: $url (3 próbálkozás után)"
        failure_reasons["$url"]="3 sikertelen próbálkozási kísérlet / Hálózati vagy HTTP hiba"
        fail_count=$((fail_count + 1))
    fi
done

log "--- ÖSSZEFOGLALÓ ---"
log "Sikeres letöltések száma: $success_count"
log "Sikertelen letöltések száma: $fail_count"

if [ $fail_count -gt 0 ]; then
    log "A script hibával zárul (exit 1), mivel volt sikertelen letöltés."
    exit 1
else
    log "Minden letöltés sikeres volt (exit 0)."
    exit 0
fi
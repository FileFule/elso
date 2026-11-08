# HF07 - Biztonsági mentési és visszatöltési rendszer

## 1. Crontab beállítás (`crontab -l`)
0 3 * * * /home/user/hf07/mentes.sh /home/user/adatok /home/user/mentesek >> /home/user/hf07/mentes.log 2>&1

## 2. Mentési log
[2026-11-07 03:00:01] Mentés script elindult. Forrás: /home/user/adatok, Cél: /home/user/mentesek, Retenció: 7
[2026-11-07 03:00:01] Archívum készítése: /home/user/mentesek/mentes-2026-11-07-0300.tar.gz
[2026-11-07 03:00:01] Archívum sikeresen létrehozva.
[2026-11-07 03:00:01] SHA256 ellenőrzőösszeg generálva...
[2026-11-07 03:00:01] Mentési folyamat sikeresen befejeződött.

## 3. Sérült archívum visszatöltési tesztje
$ ./visszatoltes.sh /home/user/mentesek /home/user/vissza mentes-2026-11-07-0300.tar.gz
=== Elérhető mentések ===
[1] mentes-2026-11-07-0300.tar.gz (Méret: 10420 bájt, Dátum: 2026-11-07 03:00:01)
Kiválasztott archívum ellenőrzése: mentes-2026-11-07-0300.tar.gz
SHA256 ellenőrzés folyamatban...
HIBA: Az ellenőrzőösszeg NEM EGYEZIK! Az archívum sérült vagy megváltozott.

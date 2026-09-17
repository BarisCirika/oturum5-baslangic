#!/usr/bin/env bash
# Kosu kayit defteri: her kosuyu otomasyon/kosular.jsonl'e TEK SATIR ekler.
# JSONL secildi cunku paralel ajanlar ayni dosyaya satir satir ekleyebilir.
#
# KIM CAGIRIR?
#   - otomasyon/ajanlari-kostur.sh  (her ajan icin bir satir, otomatik)
#   - elle:  ./otomasyon/kosu-kaydet.sh <alan> <dal> <gorev> <sid> <usd> <durum>
#
# CI NOTU: runner'daki dosya kosu bitince kaybolur ve main korumali oldugu
# icin CI kendi kendine commit edemez. Bu yuzden CI'da defter ARTIFACT
# olarak yuklenir; kalici kayit yerel kosulardan gelir ve siz commit'lersiniz.
#
# Kullanim:
#   ./kosu-kaydet.sh <alan> <dal> <gorev> <session_id> <maliyet_usd> <durum>
set -euo pipefail
ALAN="${1:-bilinmiyor}"; DAL="${2:-bilinmiyor}"; GOREV="${3:-}"
SID="${4:-}"; MALIYET="${5:-0}"; DURUM="${6:-bilinmiyor}"
KAYIT_DOSYA="${KAYIT_DOSYA:-otomasyon/kosular.jsonl}"
mkdir -p "$(dirname "$KAYIT_DOSYA")"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '{"ts":"%s","alan":"%s","dal":"%s","gorev":"%s","session_id":"%s","maliyet_usd":%s,"durum":"%s"}\n' \
  "$TS" "$ALAN" "$DAL" "$GOREV" "$SID" "$MALIYET" "$DURUM" >> "$KAYIT_DOSYA"
echo "kaydedildi -> $KAYIT_DOSYA"

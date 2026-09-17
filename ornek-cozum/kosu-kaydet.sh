#!/usr/bin/env bash
# H1 - Kosu kayit defteri: her kosuyu otomasyon/kosular.jsonl'e TEK SATIR ekler.
# JSONL secildi cunku paralel ajanlar ayni dosyaya satir satir ekleyebilir.
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

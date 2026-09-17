#!/usr/bin/env bash
# T2 - Unattended kosu sablonu. Her yeni otomasyon BUNUN kopyasidir.
# Neden her satir burada:
#   timeout          -> asili kalirsa BASARISIZ olsun, sessiz beklemesin
#   GIT_TERMINAL_PROMPT=0 -> git kimlik sorusu yerine HATA (bekleme yok)
#   tavanlar         -> sonsuz dongu ve fatura patlamasina karsi
#   dar arac listesi -> en az ayricalik (denetim ajani yazmaz)
#   json cikti       -> makine-okur; durum kontrol edilebilir
#   kayit satiri     -> "hangi ajan yapti?" sorusu cevaplanabilsin (H1)
set -uo pipefail

GOREV="${1:-Bu klasordeki .py dosyalarini ozetle}"
ALAN="${ALAN:-yerel}"
DAL="${DAL:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo yok)}"
SURE="${SURE:-600}"          # saniye
MAX_TURN="${MAX_TURN:-8}"
BUTCE="${BUTCE:-0.50}"       # USD
ARACLAR="${ARACLAR:-Read,Grep,Glob}"
CIKTI="${CIKTI:-otomasyon/son-kosu.json}"

export GIT_TERMINAL_PROMPT=0
mkdir -p "$(dirname "$CIKTI")"

if command -v claude >/dev/null 2>&1; then
  echo "[sablon] A YOLU: headless claude -p"
  timeout "$SURE" claude -p "$GOREV" \
    --output-format json \
    --allowedTools "$ARACLAR" \
    --max-turns "$MAX_TURN" \
    --max-budget-usd "$BUTCE" > "$CIKTI"
  KOD=$?
  SID="$(python3 -c "import json,sys;print(json.load(open('$CIKTI')).get('session_id',''))" 2>/dev/null || echo '')"
  MALIYET="$(python3 -c "import json,sys;print(json.load(open('$CIKTI')).get('total_cost_usd',0))" 2>/dev/null || echo 0)"
else
  echo "[sablon] B YOLU: claude CLI yok -> ajan.py (Agent SDK/MOCK)"
  AJAN_JSON=1 timeout "$SURE" python3 ajan.py | tee "$CIKTI.log" | tail -1 > "$CIKTI"
  KOD=${PIPESTATUS[1]:-$?}
  SID="yerel-$(date +%s)"
  MALIYET=0
fi

# --- DOGRULAMA KAPISI: cikis kodu 0 olsa bile SONUCUN ICERIGINE bak ---
DURUM="tamam"
if [ "${KOD:-1}" -ne 0 ]; then DURUM="hata"; fi
if grep -qi '"durum"[[:space:]]*:[[:space:]]*"yarim"' "$CIKTI" 2>/dev/null; then DURUM="yarim"; fi

./ornek-cozum/kosu-kaydet.sh "$ALAN" "$DAL" "$GOREV" "$SID" "$MALIYET" "$DURUM" || true
echo "[sablon] durum=$DURUM cikis=$KOD cikti=$CIKTI"
[ "$DURUM" = "tamam" ] || exit 1

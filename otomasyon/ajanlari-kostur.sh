#!/usr/bin/env bash
# ============================================================================
# ajanlari-kostur.sh — COK AJANLI model denetimi (varsayilan MOCK)
#
# Her ajan otomasyon/ajanlar/<ad>.txt dosyasindaki ROL ile kosar, KENDI
# session id'siyle, kendi kapsaminda. Ajanlar birbirinin isine karismaz:
#   guvenlik    -> OWASP gozuyle
#   kalite      -> muhakeme gerektiren mantik/hata yonetimi
#   tutarlilik  -> dokuman ile kod arasindaki celiski
#
# NEDEN COK AJAN? Tek genis istem her seferinde ayni birkac bulguyu
# tekrarlar ve kapsami dagilir. Dar rolu olan ajan daha derin bakar;
# ayrica her ajanin MALIYETI ayri olcculur, pahali olan kapatilabilir.
#
# MOD:
#   MOCK (varsayilan) -> model CAGRILMAZ, kosacak komut yazilir, maliyet 0
#   GERCEK            -> claude --bare ile PARALEL kosar, PARA HARCAR
#
# Kullanim:
#   DENETIM_MOD=MOCK ./otomasyon/ajanlari-kostur.sh kapsam.txt rapor.md maliyet.json
# ============================================================================
set -euo pipefail

kapsam="${1:-kapsam.txt}"
rapor="${2:-rapor.md}"
maliyet="${3:-maliyet.json}"
mod="${DENETIM_MOD:-MOCK}"
kosu="${GITHUB_RUN_ID:-yerel-$$}"
ajan_dizin="otomasyon/ajanlar"

# --- MALIYET VE SURE FRENLERI ---------------------------------------------
# Uc katman:
#   1) AJAN_BUTCE      : her ajan icin sert dolar tavani (CLI kendi keser)
#   2) AJAN_SURE       : her ajan icin saniye tavani (takilirsa oldurulur)
#   3) TOPLAM_BUTCE    : ajanlarin TOPLAMI bunu asarsa kosu kirmizi yanar
# Ucu de repo degiskeniyle (vars) ezilebilir; degerler MUHAFAZAKAR secildi.
ajan_butce="${AJAN_BUTCE:-0.50}"       # USD / ajan
ajan_sure="${AJAN_SURE:-300}"          # saniye / ajan
toplam_butce="${TOPLAM_BUTCE:-1.50}"   # USD / kosu (3 ajan x 0.50)
ajan_tur="${AJAN_TUR:-12}"             # max tur / ajan

# Linux runner'da python3, Windows'ta python: ikisini de kabul et.
PY_BIN="$(command -v python3 || command -v python)"
[ -n "$PY_BIN" ] || { echo "python bulunamadi" >&2; exit 1; }

# Her ajana KOSU + AD'dan turetilen sabit bir oturum id'si: ayni kosu
# tekrar denenirse ayni id kullanilir, log'da izi surulebilir.
oturum_id() {
  "$PY_BIN" -c "import uuid,sys;print(uuid.uuid5(uuid.NAMESPACE_URL, 'denetim/'+sys.argv[1]+'/'+sys.argv[2]))" "$kosu" "$1"
}

ajanlar=()
for p in "$ajan_dizin"/*.txt; do
  [ -e "$p" ] || continue
  ajanlar+=("$(basename "$p" .txt)")
done
if [ ${#ajanlar[@]} -eq 0 ]; then
  echo "ajan bulunamadi: $ajan_dizin/*.txt" >&2
  exit 1
fi
echo "mod=$mod | ajan sayisi=${#ajanlar[@]} | ajanlar: ${ajanlar[*]}"

# --- GERCEK mod: ajanlari PARALEL baslat -----------------------------------
if [ "$mod" = "GERCEK" ]; then
  : "${ANTHROPIC_API_KEY:?GERCEK mod istendi ama ANTHROPIC_API_KEY yok}"
  for ad in "${ajanlar[@]}"; do
    sid="$(oturum_id "$ad")"
    echo "$sid" > "ham-$ad.sid"
    # --bare: CI'da OAuth/keychain/hook yoktur, kimlik yalniz anahtardan.
    # --permission-mode plan + allowedTools: ajan yazamaz, yalniz okur.
    # timeout: CLI kendi butcesini asmadan once ASILI kalirsa bile keser.
    timeout --signal=TERM --kill-after=30 "$ajan_sure" \
      claude --bare -p "$(cat "$ajan_dizin/$ad.txt")" \
        --session-id "$sid" \
        --output-format json \
        --allowedTools "Read,Grep,Glob" \
        --max-budget-usd "$ajan_butce" \
        --max-turns "$ajan_tur" \
        --permission-mode plan \
        > "ham-$ad.json" 2> "ham-$ad.err" &
  done
  wait || true          # bir ajan catlarsa digerlerinin raporu yine yazilsin
fi

# --- Raporu ve maliyet ozetini uret ---------------------------------------
set +e
AJAN_BUTCE="$ajan_butce" AJAN_SURE="$ajan_sure" TOPLAM_BUTCE="$toplam_butce" \
AJAN_TUR="$ajan_tur" \
"$PY_BIN" - "$rapor" "$maliyet" "$mod" "$kosu" "${ajanlar[@]}" <<'PY'
import json, os, pathlib, sys

rapor, maliyet, mod, kosu = sys.argv[1:5]
ajanlar = sys.argv[5:]
butce = float(os.environ["AJAN_BUTCE"])
sure = os.environ["AJAN_SURE"]
tur = os.environ["AJAN_TUR"]
toplam_butce = float(os.environ["TOPLAM_BUTCE"])
dizin = pathlib.Path("otomasyon/ajanlar")

bolum = ["", "## Model ajanlari (" + mod + ")", ""]
kayit, toplam = [], 0.0

for ad in ajanlar:
    sid_dosya = pathlib.Path(f"ham-{ad}.sid")
    sid = sid_dosya.read_text().strip() if sid_dosya.exists() else "-"
    ham = pathlib.Path(f"ham-{ad}.json")
    usd, metin = 0.0, ""

    if mod == "GERCEK" and ham.exists() and ham.stat().st_size:
        try:
            d = json.loads(ham.read_text(encoding="utf-8"))
            metin = (d.get("result") or "").strip()
            usd = float(d.get("total_cost_usd") or 0)
        except json.JSONDecodeError:
            metin = "_Ajan cikti uretemedi (JSON cozulemedi)._"
    elif mod == "GERCEK":
        hata = pathlib.Path(f"ham-{ad}.err")
        ayrinti = hata.read_text(encoding="utf-8")[:300] if hata.exists() else ""
        metin = f"_Ajan kosmadi._ `{ayrinti.strip()}`"
    else:
        # MOCK: model cagrilmaz; kosacak komut gosterilir.
        metin = ("_MOCK: model cagrilmadi._ Gercek modda kosacak komut:\n\n"
                 "```bash\n"
                 f"timeout {sure} claude --bare "
                 f"-p \"$(cat otomasyon/ajanlar/{ad}.txt)\" \\\n"
                 "  --session-id <kosu+ajan'dan turetilir> \\\n"
                 "  --output-format json --allowedTools \"Read,Grep,Glob\" \\\n"
                 f"  --max-budget-usd {butce} --max-turns {tur} "
                 "--permission-mode plan\n"
                 "```")

    toplam += usd
    kayit.append({"ajan": ad, "oturum": sid, "maliyet_usd": round(usd, 6),
                  "mod": mod})
    bolum += [f"### Ajan: {ad}", "", metin, ""]

# Sabah brifinginin okuyacagi MAKINE OKUR satirlar. Rapor PR yorumu ya da
# issue olarak gorundugu icin maliyet oradan toplanabiliyor; ayri bir
# veritabani ya da depoya commit gerekmiyor.
bolum += ["| Ajan | Oturum | Maliyet (USD) |", "|---|---|---|"]
for k in kayit:
    bolum.append(f"| {k['ajan']} | `{k['oturum'][:8]}` | {k['maliyet_usd']} |")
asti = toplam > toplam_butce
bolum += ["",
          f"**Toplam model maliyeti: {round(toplam, 6)} USD** ({mod} mod)", "",
          f"_Frenler: ajan basi {butce} USD ve {sure} sn tavani, "
          f"{tur} tur; kosu tavani {toplam_butce} USD._"]
if asti:
    bolum += ["", f"> **BUTCE ASILDI**: {round(toplam, 6)} USD > "
                  f"{toplam_butce} USD. Kosu kirmizi yanar."]
bolum += [""]
for k in kayit:
    bolum.append(f"<!-- maliyet ajan={k['ajan']} mod={mod} "
                 f"usd={k['maliyet_usd']} oturum={k['oturum']} kosu={kosu} -->")

with open(rapor, "a", encoding="utf-8") as f:
    f.write("\n".join(bolum) + "\n")

pathlib.Path(maliyet).write_text(json.dumps(
    {"mod": mod, "kosu": kosu, "toplam_usd": round(toplam, 6),
     "toplam_butce": toplam_butce, "butce_asildi": asti,
     "ajanlar": kayit}, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps({"mod": mod, "toplam_usd": round(toplam, 6),
                  "ajan_sayisi": len(kayit), "butce_asildi": asti},
                 ensure_ascii=False))
# Butce asildiysa cikis kodu 3: cagiran taraf kosuyu KIRMIZI yakar.
sys.exit(3 if asti else 0)
PY
py_kod=$?
set -e

# --- KOSU KAYIT DEFTERI ----------------------------------------------------
# Her ajan icin otomasyon/kosular.jsonl'e TEK SATIR. Defter, maliyet.json'dan
# beslenir; boylece MOCK kosular da (0 USD) kayda girer ve "ne zaman ne
# kostu" sorusu sonradan cevaplanabilir.
dal="${GITHUB_REF_NAME:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo bilinmiyor)}"
durum="tamam"; [ "$py_kod" -eq 3 ] && durum="butce-asimi"
[ "$py_kod" -eq 0 ] || [ "$py_kod" -eq 3 ] || durum="hata"

"$PY_BIN" - "$maliyet" <<'PY2' | tr -d '
' | while IFS=$'	' read -r ajan sid usd; do
import json, sys
# Windows'ta stdout metin kipinde \n -> \r\n cevirir ve bu \r defterdeki
# JSON degerinin icine sizar. Satir sonunu burada sabitliyoruz; CI'daki
# Linux runner'da zaten sorun yoktu, hatayi yerel kosuda yakaladik.
sys.stdout.reconfigure(newline="\n")
d = json.load(open(sys.argv[1], encoding="utf-8"))
for a in d.get("ajanlar", []):
    print("	".join([a["ajan"], a.get("oturum") or "-", str(a["maliyet_usd"])]))
PY2
  bash otomasyon/kosu-kaydet.sh "$ajan" "$dal" "denetim/$mod" "$sid" "$usd" "$durum" >/dev/null
done

echo "defter: $(wc -l < "${KAYIT_DOSYA:-otomasyon/kosular.jsonl}") satir"
exit "$py_kod"

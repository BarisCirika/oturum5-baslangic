#!/usr/bin/env python3
# ============================================================================
# denetim_mock.py — MOCK denetim (SIFIR API MALIYETI)
#
# Neden var? Ders 12'de otomasyon HATTINI ucdan uca calistirmak istiyoruz
# ama gercek model cagrisi para harcar. Bu script ayni boru hattini
# doldurur: dosyalari tarar, bulgulari risk etiketiyle raporlar, PR
# yorumu icin markdown ve pipeline icin JSON ozet uretir.
#
# Onemli ders: bu script DETERMINISTIK kontroller yapar (kural tabanli).
# Gercek model tarafi ise MUHAKEME ekler. Uretimde ikisi birlikte kullanilir:
#   deterministik kontrol -> KAPI (bloklar)
#   model                 -> DANISMAN (yorumlar, onceliklendirir)
#
# Kullanim:
#   python otomasyon/denetim_mock.py kapsam.txt rapor.md sonuc.json
#   (kapsam.txt: her satirda bir dosya yolu)
# ============================================================================
import json
import os
import re
import sys

# --- Kural seti: (etiket, etki, regex, aciklama) ---------------------------
KURALLAR = [
    ("SIR", "yuksek",
     r"(?i)(api[_-]?key|secret|token|password)\s*[=:]\s*['\"][A-Za-z0-9_\-]{12,}",
     "Koda gomulu sir/anahtar izi"),
    ("SIR", "yuksek",
     r"sk-[A-Za-z0-9\-]{20,}",
     "Anahtar bicimli dize (sk-...)"),
    ("KOD-CALISTIRMA", "yuksek",
     r"\b(eval|exec)\s*\(",
     "Dinamik kod calistirma (injection yuzeyi)"),
    ("KABUK", "yuksek",
     r"shell\s*=\s*True",
     "Kabuk uzerinden komut calistirma"),
    ("SESSIZ-HATA", "orta",
     r"except\s*:\s*(pass|$)",
     "Yakalanip yutulan hata (bare except)"),
    ("SQL", "yuksek",
     r"(?i)(select|insert|update|delete)\s+.*\+\s*(str\(|.*%s|.*\{)",
     "String birlestirmeyle SQL kurulmasi (injection)"),
    ("HTTP", "orta",
     r"http://(?!localhost|127\.0\.0\.1)",
     "Sifrelenmemis http adresi"),
    ("TODO", "dusuk",
     r"(?i)\b(todo|fixme|hack)\b",
     "Tamamlanmamis is notu"),
]

# --- SEO/kalite kurallari (HTML dosyalari icin) ----------------------------
def seo_bulgulari(yol, icerik):
    b = []
    if not re.search(r"(?i)<title>.{3,}</title>", icerik):
        b.append(("SEO", "orta", 1, "title etiketi yok ya da bos"))
    if not re.search(r"(?i)<meta\s+name=['\"]description['\"]", icerik):
        b.append(("SEO", "orta", 1, "meta description yok"))
    h1 = len(re.findall(r"(?i)<h1[\s>]", icerik))
    if h1 == 0:
        b.append(("SEO", "orta", 1, "h1 basligi yok"))
    elif h1 > 1:
        b.append(("SEO", "dusuk", 1, f"{h1} adet h1 var (tek olmali)"))
    for m in re.finditer(r"(?i)<img(?![^>]*\balt=)[^>]*>", icerik):
        satir = icerik[:m.start()].count("\n") + 1
        b.append(("SEO", "dusuk", satir, "img etiketinde alt metni yok"))
    return b


def dosyayi_denetle(yol):
    try:
        icerik = open(yol, encoding="utf-8", errors="replace").read()
    except Exception as e:
        return [("OKUMA", "dusuk", 1, f"okunamadi: {e}")]

    bulgular = []
    for etiket, etki, desen, aciklama in KURALLAR:
        for m in re.finditer(desen, icerik):
            satir = icerik[:m.start()].count("\n") + 1
            bulgular.append((etiket, etki, satir, aciklama))
    if yol.lower().endswith((".html", ".htm")):
        bulgular += seo_bulgulari(yol, icerik)
    return bulgular


ETKI_SIRA = {"yuksek": 0, "orta": 1, "dusuk": 2}


def main():
    kapsam_dosya = sys.argv[1] if len(sys.argv) > 1 else "kapsam.txt"
    rapor_dosya = sys.argv[2] if len(sys.argv) > 2 else "rapor.md"
    json_dosya = sys.argv[3] if len(sys.argv) > 3 else "sonuc.json"

    if os.path.exists(kapsam_dosya):
        yollar = [s.strip() for s in open(kapsam_dosya, encoding="utf-8")
                  if s.strip() and os.path.isfile(s.strip())]
    else:
        yollar = []

    tum = []
    for yol in yollar:
        for etiket, etki, satir, aciklama in dosyayi_denetle(yol):
            tum.append({"dosya": yol, "satir": satir, "etiket": etiket,
                        "etki": etki, "aciklama": aciklama})

    tum.sort(key=lambda b: (ETKI_SIRA.get(b["etki"], 3), b["dosya"], b["satir"]))
    sayim = {e: sum(1 for b in tum if b["etki"] == e)
             for e in ("yuksek", "orta", "dusuk")}

    # --- markdown rapor (PR yorumu icin) ---
    L = ["## Otomatik denetim raporu (MOCK mod - sifir API maliyeti)", ""]
    L.append(f"Taranan dosya: **{len(yollar)}** | Bulgu: "
             f"**{len(tum)}** (yuksek {sayim['yuksek']}, "
             f"orta {sayim['orta']}, dusuk {sayim['dusuk']})")
    L.append("")
    if not tum:
        L.append("Bulgu yok - kapsam temiz gorunuyor.")
    else:
        L.append("| Etki | Dosya:satir | Etiket | Bulgu |")
        L.append("|---|---|---|---|")
        for b in tum[:50]:
            L.append(f"| {b['etki']} | `{b['dosya']}:{b['satir']}` | "
                     f"{b['etiket']} | {b['aciklama']} |")
        if len(tum) > 50:
            L.append(f"\n_...ve {len(tum) - 50} bulgu daha._")
        L.append("")
        L.append("### Once neyi duzelt")
        for b in tum[:3]:
            L.append(f"1. `{b['dosya']}:{b['satir']}` - {b['aciklama']}")
    L.append("")
    L.append("> Bu rapor DETERMINISTIK kurallarla uretildi (kapi gorevi). "
             "Muhakeme gerektiren inceleme icin model tabanli denetim "
             "eklenebilir (danisman gorevi).")
    open(rapor_dosya, "w", encoding="utf-8").write("\n".join(L) + "\n")

    # --- JSON ozet (pipeline dogrulama kapisi icin) ---
    ozet = {"durum": "tamam", "mod": "MOCK", "taranan": len(yollar),
            "bulgu_sayisi": len(tum), "yuksek": sayim["yuksek"],
            "orta": sayim["orta"], "dusuk": sayim["dusuk"]}
    open(json_dosya, "w", encoding="utf-8").write(
        json.dumps(ozet, ensure_ascii=False) + "\n")
    print(json.dumps(ozet, ensure_ascii=False))

    # Yuksek etkili bulgu varsa kosuyu KIRMIZI yap (kapi davranisi)
    sys.exit(1 if sayim["yuksek"] else 0)


if __name__ == "__main__":
    main()

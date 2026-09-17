#!/usr/bin/env python3
# ============================================================================
# ajan.py — Ders 9'un ajanı (Ders 12'nin B YOLU için hazır sürüm)
#
# Bir klasördeki .py dosyalarını özetleyen ajan + guardrail'ler.
#
# İKİ MOD — ders içeriği ikisinde de BİREBİR AYNI:
#   MOCK  (varsayılan) : model çağrısı yerel taklitle yapılır.
#                        Anahtar, internet, ücret GEREKMEZ. Guardrail'ler
#                        gerçektir.
#   GERCEK             : claude-agent-sdk ile gerçek model çağrısı.
#                        Console API anahtarı gerekir (Pro/Max aboneliği
#                        Agent SDK için GEÇERLİ DEĞİLDİR).
#
# Çalıştırma:
#   python ajan.py                     -> MOCK
#   AJAN_MOD=GERCEK python ajan.py     -> gerçek model
#
# Neden MOCK yeterli? Bu dersin öğrettiği şey guardrail mimarisidir:
# dosya tavanı, bütçe (çağrı) sayacı, tur limiti, yetki kısıtı, yarım-iş
# raporu. Hiçbiri modelin zekâsına bağlı değildir.
# ============================================================================
import glob
import json
import os
import re
import sys
import time

MOD = os.environ.get("AJAN_MOD", "MOCK").upper()

# --------------------------------------------------------- GUARDRAIL'LER ----
# Hepsi ajanin DISINDA, onu cagiran dongude: ajani ikna etmiyoruz, kusatiyoruz.
MAX_DOSYA = int(os.environ.get("MAX_DOSYA", "10"))   # dosya tavani
MAX_CAGRI = int(os.environ.get("MAX_CAGRI", "10"))   # butce: en fazla N cagri
MAX_TUR = int(os.environ.get("MAX_TUR", "5"))        # ajan basina tur limiti

sayac = {"cagri": 0, "islenen": 0, "atlanan": 0}


def log(*parcalar):
    print("[" + time.strftime("%H:%M:%S") + "]", *parcalar, flush=True)


# ------------------------------------------------------------ MOCK MODEL ----
def mock_ozet(yol: str, icerik: str) -> str:
    """Model cagrisinin yerel taklidi: dosyayi gercekten OKUR ve kaba bir
    ozet uretir. Amac zeka degil, boru hattini gercekci doldurmak."""
    satir = icerik.count("\n") + 1
    fonk = re.findall(r"^\s*def\s+(\w+)", icerik, re.M)
    sinif = re.findall(r"^\s*class\s+(\w+)", icerik, re.M)
    d = re.search(r'"""(.+?)"""', icerik, re.S)
    ipucu = d.group(1).strip().split("\n")[0][:60] if d else ""
    p = [f"{os.path.basename(yol)}: {satir} satir"]
    if sinif:
        p.append(f"{len(sinif)} sinif ({', '.join(sinif[:3])})")
    if fonk:
        p.append(f"{len(fonk)} fonksiyon ({', '.join(fonk[:3])})")
    if ipucu:
        p.append(f'amac: "{ipucu}"')
    time.sleep(0.1)  # gercek cagri gecikmesini taklit et
    return " - ".join(p) + "."


# ----------------------------------------------------------- GERCEK MODEL ---
def gercek_ozet(yol: str, icerik: str) -> str:
    """claude-agent-sdk ile gercek ajan cagrisi. En az ayricalik: yalniz
    Read ve Glob (ozetleyen ajan YAZAMAZ)."""
    import asyncio

    from claude_agent_sdk import ClaudeAgentOptions, query  # type: ignore

    async def calistir():
        secenekler = ClaudeAgentOptions(
            system_prompt=(
                "Kod ozetleyicisin. Verilen dosya icin TEK CUMLELIK, Turkce "
                "ozet yaz; dosya adiyla basla. Kod onerisi yapma."
            ),
            allowed_tools=["Read", "Glob"],  # yazma yetkisi YOK
            max_turns=MAX_TUR,               # tur limiti = guardrail
        )
        parcalar = []
        async for mesaj in query(prompt=f"Bu dosyayi ozetle: {yol}",
                                 options=secenekler):
            metin = getattr(mesaj, "text", None) or getattr(mesaj, "result", None)
            if metin:
                parcalar.append(str(metin))
        return " ".join(parcalar).strip() or "(bos yanit)"

    return asyncio.run(calistir())


def ozetle(yol: str, icerik: str) -> str:
    return gercek_ozet(yol, icerik) if MOD == "GERCEK" else mock_ozet(yol, icerik)


# ------------------------------------------------------------- ANA DONGU ----
def main():
    log(f"MOD = {MOD}" + ("  (anahtar gerekmez)" if MOD == "MOCK" else ""))
    if MOD == "GERCEK" and not os.environ.get("ANTHROPIC_API_KEY"):
        print("HATA: GERCEK mod icin ANTHROPIC_API_KEY gerekir "
              "(Console API anahtari; Pro/Max aboneligi SDK'da gecerli degil).")
        print("MOCK ile devam etmek icin: python ajan.py")
        sys.exit(1)

    dosyalar = sorted(glob.glob("*.py"))
    log(f"{len(dosyalar)} dosya bulundu")
    ozetler = []

    for yol in dosyalar:
        # --- guardrail 1: dosya tavani ---
        if sayac["islenen"] >= MAX_DOSYA:
            sayac["atlanan"] = len(dosyalar) - sayac["islenen"]
            log(f"GUARDRAIL dosya-tavani: {MAX_DOSYA} dosyada durdum, "
                f"{sayac['atlanan']} dosya ISLENMEDI")
            break
        # --- guardrail 2: butce (cagri sayisi) ---
        if sayac["cagri"] >= MAX_CAGRI:
            sayac["atlanan"] = len(dosyalar) - sayac["islenen"]
            log(f"GUARDRAIL butce: {MAX_CAGRI} cagri tavanina ulasildi, "
                f"{sayac['atlanan']} dosya ISLENMEDI")
            break

        try:
            icerik = open(yol, encoding="utf-8").read()
        except Exception as e:  # okunamayan dosya isi bitirmez
            log(f"ATLANDI {yol}: {e}")
            continue

        sayac["cagri"] += 1
        ozet = ozetle(yol, icerik)
        sayac["islenen"] += 1
        ozetler.append(ozet)
        log(f"cagri #{sayac['cagri']} - {yol} - {len(ozet)} karakter")

    # --- guardrail 3: yarim is SESSIZ bitmez, RAPORLANIR ---
    print("\n" + "=" * 60 + "\nOZETLER\n" + "=" * 60)
    for o in ozetler:
        print("-", o)
    print("=" * 60)
    tam = sayac["atlanan"] == 0
    durum = "TAMAMLANDI" if tam else "YARIM KALDI"
    print(f"RAPOR: {sayac['islenen']} dosya islendi, {sayac['cagri']} cagri, "
          f"{sayac['atlanan']} atlandi -> {durum}")
    if not tam:
        print("NEDEN: guardrail tavanina takildi (yukaridaki GUARDRAIL satiri).")

    # --- makine-okur ozet: pipeline ve kayit defteri icin (H1/T2) ---
    if os.environ.get("AJAN_JSON") == "1":
        print(json.dumps({
            "durum": "tamam" if tam else "yarim",
            "islenen": sayac["islenen"],
            "cagri": sayac["cagri"],
            "atlanan": sayac["atlanan"],
            "mod": MOD,
        }, ensure_ascii=False))

    # yarim is = basarisiz cikis (otomasyonda sessiz gecmesin)
    sys.exit(0 if tam else 2)


if __name__ == "__main__":
    main()

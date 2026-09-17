# YER HARİTASI — Hangi Ayar Nerede?

> Bu dosya, "timeout koy", "kilit ekle", "iptal et" gibi müdahalelerin
> **tam yerini** söyler. Ders sırasında ve sonrasında ilk bakılacak yer.
> Dört ayrı yer var: **proje dosyaları** (Claude'a yazdırılır) ·
> **GitHub web arayüzü** · **Anthropic Console** · **Claude Code uygulaması**.
>
> **Altın kural:** dosya tabanlı olan her şeyi Claude'a yazdır (diff'i oku,
> onayla); tarayıcı adımlarını (secret, izinler, anahtar iptali) **elle** yap.

---

## 1. Dosya ağacı

```
<proje kökü>/                         ← Claude Code'u BURADA aç
├── .claude/
│   ├── settings.json                 İZİN DOSYASI (permissions.deny/ask,
│   │                                 hooks, defaultMode)
│   ├── settings.local.json           makineye/worktree'ye özel ayar
│   ├── alan.txt                      ALAN KİLİDİ: izinli klasör öneki
│   └── hooks/
│       └── alan_kilidi.py            ALAN KİLİDİ HOOK'U (exit 2 ile keser)
├── .github/
│   └── workflows/
│       └── denetim.yml               WORKFLOW — CI hattı (çalışan kopya!)
├── otomasyon/
│   ├── denetim_mock.py               MOCK DENETİM (deterministik kurallar)
│   ├── kosular.jsonl                 KAYIT DEFTERİ (koşu başına bir satır)
│   ├── kabul-kriteri.md              KABUL KRİTERİ (Best-of-N için)
│   └── son-kosu.json                 son koşunun çıktısı (git'e girmez)
├── ornek-cozum/                      REFERANSLAR (kopyalamak için değil,
│   │                                 karşılaştırmak için)
│   ├── sablon-kosu.sh                ŞABLON: SURE, MAX_TURN, BUTCE, ARACLAR
│   ├── kosu-kaydet.sh                kayıt defterine satır ekler
│   ├── alan_kilidi.py                alan kilidi hook'unun referansı
│   └── denetim.yml                   workflow'un referansı (CI bunu GÖRMEZ)
├── ajan.py                           Ders 9'un ajanı (MOCK/GERCEK)
├── envanter.py · savas.py · kayit.py örnek kaynak dosyalar
├── .gitignore                        sır ve üretilen dosya dışlama
└── .env.example                      (yalnız gerçek mod; derste kullanılmaz)
```

> **En sık karışan nokta:** workflow'un **iki kopyası** var. CI yalnız
> `.github/workflows/denetim.yml`'yi görür; `ornek-cozum/denetim.yml`
> referanstır. Referansı düzenleyip "neden çalışmıyor?" demeyin.

---

## 2. Kısaltma sözlüğü

| Kısaltma | Tam yol | İçinde ne var |
|---|---|---|
| **şablon** | `ornek-cozum/sablon-kosu.sh` | `SURE` (timeout), `MAX_TURN`, `BUTCE`, `ARACLAR`, `GIT_TERMINAL_PROMPT=0`, `DURUM` kontrolü, kayıt çağrısı |
| **workflow** | `.github/workflows/denetim.yml` | `timeout-minutes`, `concurrency`, `permissions`, "Kapsami belirle", denetim adımı, "Sonucu dogrula", yorum/issue adımları, `on: schedule` |
| **kayıt defteri** | `otomasyon/kosular.jsonl` | ts, alan, dal, görev, session_id, maliyet_usd, durum |
| **izin dosyası** | `.claude/settings.json` | `permissions.deny/ask`, `hooks`, `defaultMode` |
| **alan kilidi** | `.claude/alan.txt` + `.claude/hooks/alan_kilidi.py` + `.claude/settings.local.json` | izinli klasör öneki, engelleme hook'u, hook bağlantısı (her worktree'de AYRI) |
| **MOCK denetim** | `otomasyon/denetim_mock.py` | kural seti: gömülü sır, `shell=True`, bare except, SQL birleştirme, `http://`, SEO |

---

## 3. Ayarı nerede değiştiririm?

### A) Proje dosyaları (Claude'a yazdır)

| Ne yapmak istiyorum | Tam yer |
|---|---|
| CI koşusuna süre sınırı | `.github/workflows/denetim.yml` → `timeout-minutes:` |
| Yerel koşuya süre sınırı | `ornek-cozum/sablon-kosu.sh` → `SURE` |
| Tur / bütçe tavanı | `ornek-cozum/sablon-kosu.sh` → `MAX_TURN`, `BUTCE` (CI'da `claude -p` satırındaki `--max-turns`, `--max-budget-usd`) |
| Araç yüzeyini daraltmak | `ornek-cozum/sablon-kosu.sh` → `ARACLAR` (`--allowedTools`) |
| Git'in kimlik sorusunu susturmak | Şablonda `export GIT_TERMINAL_PROMPT=0`; CI'da adımın `env:` bloğu |
| Kapsamı daraltmak (yalnız değişen dosyalar) | `.github/workflows/denetim.yml` → **"Kapsami belirle"** adımı (`git diff --name-only`) |
| Doğrulama kapısı (yeşil ışık gerçeği söylesin) | Workflow → **"Sonucu dogrula"** adımı; yerelde şablonun `DURUM` kontrolü |
| Denetim kurallarını değiştirmek/eklemek | `otomasyon/denetim_mock.py` → `KURALLAR` listesi |
| Yıkıcı komutu kesmek (deny/ask) | `.claude/settings.json` → `permissions` |
| Paralel ajanların birbirini ezmesini engellemek | Her worktree'de `.claude/alan.txt` + `.claude/hooks/alan_kilidi.py` + `.claude/settings.local.json` |
| Koşuları kayda geçirmek | `otomasyon/kosular.jsonl` (şablonun sonundaki `kosu-kaydet.sh` çağrısı) |
| Best-of-N kabul kriteri | `otomasyon/kabul-kriteri.md` |
| Aynı dalda iki koşuyu engellemek | Workflow → dosyanın üstündeki `concurrency:` |
| Gece koşusu eklemek | Workflow → `on: schedule: cron` (**UTC!**) |
| Sonucu bir yere yazdırmak | Workflow → `actions/github-script` adımları (PR yorumu / issue) + `if: failure()` adımı |
| Sır dosyalarını depodan uzak tutmak | `.gitignore` (+ `.claude/hooks/` altındaki `.env` koruma hook'u) |
| Worktree açmak / temizlemek | Dosya değil, komut: Claude'a Bash → `git worktree add / list / remove / prune`, `git branch -D` |

### B) GitHub web arayüzü (elle)

| Ne yapmak istiyorum | Tam yol |
|---|---|
| Actions'ı açmak | Depo → **Settings → Actions → General → Actions permissions** |
| `403: Resource not accessible` hatası | Aynı ekran → **Workflow permissions** ("Read and write") **veya** workflow'da `permissions:` bloğu (tercih edilen) |
| Secret eklemek | Depo → **Settings → Secrets and variables → Actions → Secrets → New repository secret** |
| Variable eklemek (`DENETIM_MOD`) | Aynı ekranın **Variables** sekmesi |
| Koşuyu elle tetiklemek | Depo → **Actions** → workflow → **Run workflow** |
| Koşu log'unu silmek (sızma sonrası) | Depo → **Actions** → ilgili run → sağ üst **…** → Delete workflow run |
| Dakika kotası / faturayı görmek | Hesap → **Settings → Billing** |

### C) Anthropic Console (elle)

| Ne yapmak istiyorum | Tam yol |
|---|---|
| **Anahtarı iptal etmek (sızma anında İLK İŞ)** | **console.anthropic.com → API keys** → ilgili anahtar → iptal/sil |
| Yeni anahtar oluşturmak | Aynı ekran → **Create key** |
| Kullanımı / limitleri görmek | Console → **Usage / Billing** |

### D) Claude Code uygulaması

| Ne yapmak istiyorum | Nerede |
|---|---|
| İzin modunu değiştirmek (auto dahil) | **Shift+Tab** ile mod döngüsü (kalıcı: `.claude/settings.json` → `defaultMode`) |
| Hook/izin değişikliğini etkinleştirmek | **Yeni sohbet** (yapılandırma oturum başında okunur) |
| MCP durumu / bağlam maliyeti / model | `/mcp` · `/context` · `/model` |
| Auto Mode yanlış pozitifini bildirmek | `/feedback` |

---

## 4. Arıza → nerede düzeltirim? (hızlı tablo)

| Arıza | Nerede düzeltirim |
|---|---|
| Koşu sessizce asılı kaldı | Şablon → `SURE`; workflow → `timeout-minutes`; şablon → `GIT_TERMINAL_PROMPT=0` |
| "Yeşil" ama iş yapılmamış | Workflow → "Sonucu dogrula" adımı; şablon → `DURUM` kontrolü |
| İki makinede farklı davranış | `claude -p` satırında `--bare`; workflow'da sürüm pinleme + "Surumleri logla" |
| Fatura/maliyet | Şablon → `MAX_TURN`, `BUTCE`; workflow → "Kapsami belirle"; `otomasyon/kosular.jsonl` ile izleme |
| Ajan yetkisiz yere uzandı | Şablon → `ARACLAR`; `.claude/settings.json` → `permissions.deny`; alan kilidi hook'u |
| Paralel ajanlar birbirini ezdi | `git worktree`; her worktree'de `.claude/alan.txt`; workflow → `concurrency:` |
| Üç çıktı var, karar yok | `otomasyon/kabul-kriteri.md` (koşudan ÖNCE) + test/lint eleme kapısı |
| Gece koşusu kimseye ulaşmadı | Workflow → `actions/github-script` (issue/yorum) + `if: failure()` adımı |
| **Anahtar sızdı** | **Console → API keys → iptal** (ilk iş) → yeni anahtar → GitHub Secrets güncelle → Actions'ta log sil → `.gitignore`/hook ile önle |
| Auto Mode sürekli blokluyor | Uygulamada **Shift+Tab** ile mod; kapsamı daralt; `.claude/settings.json` → `permissions` ile allow/deny ilan et; `/feedback` |

---

## 5. Hatırlatmalar

- **Hook/izin değişikliğinden sonra yeni sohbet** — yapılandırma oturum
  başında okunur.
- **Cron UTC'dir** — "03:00" senin saatin olmayabilir.
- **Fork'tan gelen PR'larda secret verilmez** ve token read-only olur:
  test PR'ını kendi deponuzdaki bir daldan açın.
- **İki ayrı fatura:** GitHub dakikaları (kota + harcama limiti otomatik
  duvar) ve model kullanımı (duvar YOK — fren senin bayraklarında).
- **Derste gerçek model koşusu yapılmıyor:** `denetim.yml` MOCK modda
  çalışır, API anahtarı gerekmez.

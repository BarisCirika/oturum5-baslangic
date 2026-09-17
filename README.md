# Otomasyon Başlangıç Projesi (Ders 12)

Bu klasör, Ders 12'nin (Otomasyon, Multi-Agent Orkestrasyon ve Production)
**hazır zeminidir.** Amaç: kimse dosya aramakla, kod kopyalamakla zaman
kaybetmesin — dersin konusu otomasyon, dosya avı değil.

## Hızlı başlangıç (anahtar gerekmez)

Claude Code'u bu klasörde aç ve şunu söyle:
```
Bash ile "python ajan.py" çalıştır ve çıktıyı göster.
```
Beklenen: dört dosyanın özeti + sonda
`RAPOR: 4 dosya islendi, 4 cagri, 0 atlandi -> TAMAMLANDI`

Guardrail'i tetiklemek için:
```
Bash ile "MAX_DOSYA=2 python ajan.py" çalıştır; son 4 satırı göster.
```
Beklenen: `YARIM KALDI` + `NEDEN: guardrail tavanina takildi`

---

## Önce buraya bak: YER-HARITASI.md

**Hangi ayar nerede yapılır?** sorusunun cevabı `YER-HARITASI.md`
dosyasında: dosya ağacı, kısaltma sözlüğü (şablon / workflow / kayıt
defteri / izin dosyası / alan kilidi), "şunu nerede değiştiririm" tabloları
(proje dosyaları · GitHub arayüzü · Anthropic Console · Claude Code
uygulaması) ve **arıza → nerede düzeltirim** hızlı tablosu.

Ders sırasında "timeout'u nereye koyacağım?", "secret nereye eklenir?",
"anahtar sızdı, ilk ne yapılır?" gibi sorularda ilk bakılacak yer orası.

## Klasörde ne var?

```
ajan.py                 Ders 9'un ajanı — MOCK + GERCEK mod, guardrail'ler,
                        yarım-iş raporu, JSON özet (AJAN_JSON=1)
envanter.py             Ajanın özetleyeceği örnek kaynak dosyalar
savas.py                (bilerek küçük ve okunur tutuldu)
kayit.py
YER-HARITASI.md         Hangi ayar nerede yapılır (İLK BAKILACAK YER)
otomasyon/kosular.jsonl Koşu kayıt defteri (başta boş)
otomasyon/kabul-kriteri.md  Best-of-N için kriter şablonu (koşudan ÖNCE
                        doldurulur)
.claude/alan.txt        Alan kilidi için izinli klasör öneki (örnek: docs/)
.env.example            Yalnız GERCEK mod için
ornek-cozum/            REFERANS ÇÖZÜMLER — önce kendin yazdır, sonra bak
  kosu-kaydet.sh        H1: kayıt defterine tek satır JSON ekler
  sablon-kosu.sh        T2: unattended koşu şablonu (timeout + tavanlar +
                        doğrulama kapısı + kayıt)
  alan_kilidi.py        H2: PreToolUse hook — alan dışına ve ortak
                        dosyalara yazmayı exit 2 ile keser
  denetim.yml           A7: PR'da otomatik denetim + gece issue'su
                        (VARSAYILAN: MOCK — sıfır API maliyeti)
otomasyon/denetim_mock.py  Deterministik denetim (gömülü sır, shell=True,
                        bare except, SQL birleştirme, http, TODO + HTML
                        SEO kontrolleri). CI'da bunu koşuyoruz.
```

## İki mod

| Mod | Komut | Gereken |
|---|---|---|
| **MOCK** (varsayılan) | `python ajan.py` | Hiçbir şey |
| **GERCEK** | `AJAN_MOD=GERCEK python ajan.py` | `claude-agent-sdk` + **Console API anahtarı** |

> Agent SDK'nın gerçek modu Console'dan alınmış bir API anahtarı ister;
> **Pro/Max aboneliği SDK için geçerli değildir** (Anthropic politikası).
> Bu yüzden dersin varsayılanı MOCK: kimse dışarıda kalmaz.

**MOCK neden yeterli?** Bu dersin konusu modelin zekâsı değil, **guardrail
mimarisi**: dosya tavanı, bütçe (çağrı) sayacı, tur limiti, yetki kısıtı,
yarım-iş raporu. Hiçbiri modele bağlı değil — hepsi sayaç ve metin
üzerinde çalışıyor.

## ornek-cozum/ kuralı

Bu klasördekiler **kopyalamak için değil, karşılaştırmak için.** Ders
akışı şöyle: H1/H2/T2/A7 promptlarıyla **kendin yazdırırsın**, sonra buraya
bakıp farkı görürsün. Kopyalayıp geçmek dersin amacını öldürür — çünkü
öğrenilen şey dosyanın içeriği değil, o dosyayı **neden öyle yazdığın.**

## Ayarlanabilir guardrail'ler (ortam değişkeniyle)

| Değişken | Varsayılan | Ne yapar |
|---|---|---|
| `MAX_DOSYA` | 10 | En fazla kaç dosya işlenir |
| `MAX_CAGRI` | 10 | Bütçe: en fazla kaç model çağrısı |
| `MAX_TUR` | 5 | Ajan başına tur limiti (GERCEK modda SDK'ya geçer) |
| `AJAN_JSON` | — | `1` ise sonda makine-okur JSON özet basar |
| `AJAN_MOD` | MOCK | `GERCEK` ile gerçek modele bağlanır |

## Şablonu (T2) denemek

```
Bash ile "ALAN=is-a bash ornek-cozum/sablon-kosu.sh 'ozet cikar'"
çalıştır; sonra otomasyon/kosular.jsonl'in son satırını göster.
```
Şablon `claude` komutunu bulursa **A yolundan** (headless CLI), bulamazsa
**B yolundan** (ajan.py) koşar — ikisinde de sonuca bakar, kayıt satırını
yazar, durum `tamam` değilse **hata ile çıkar.**

## Alan kilidini (H2) denemek

```
Bash ile şunu çalıştırıp çıkış kodunu raporla:
echo '{"tool_name":"Write","tool_input":{"file_path":"src/x.js"}}' | python ornek-cozum/alan_kilidi.py
```
Beklenen: engel mesajı (stderr) + **çıkış kodu 2**. `docs/` altındaki bir
yol denenirse çıkış kodu 0 olur — çünkü `.claude/alan.txt` `docs/` diyor.

## Gerçek koşu YAPMIYORUZ — neden ve nasıl?

CI'daki denetim gerçek model çağrısı yapsaydı **para harcardı.** Bu yüzden
`denetim.yml` varsayılan olarak **MOCK** modda çalışır:
`otomasyon/denetim_mock.py` deterministik kurallarla tarar, raporu üretir,
PR yorumu yazılır. **Hat uçtan uca gerçekten çalışır** (PR → runner →
denetim → yorum); yalnız "beyin" model değil, kural setidir. GitHub
dakikaları kota içinde ücretsizdir.

Gerçek modu denemek isteyen: depoya `DENETIM_MOD=GERCEK` **variable**'ı ve
`ANTHROPIC_API_KEY` **secret**'ı ekler — kendi bütçesiyle. Workflow bu iki
yolu ayrı adımlarda taşır, kod aynı kalır.

**Ders notu (önemli ayrım):** MOCK adımı **deterministik** kontrol yapar →
**kapı** görevi (bloklar; yüksek etkili bulguda koşu kırmızı yanar).
Model tabanlı denetim **muhakeme** ekler → **danışman** görevi (yorumlar,
önceliklendirir). Üretimde ikisi birlikte kullanılır: bloklamayı
deterministik kontrollere bırak, modeli danışman yap.

## MOCK denetimi yerel dene

```
Bash ile şunu çalıştır ve rapor.md'yi göster:
git ls-files > kapsam.txt && python3 otomasyon/denetim_mock.py kapsam.txt rapor.md sonuc.json
```
Beklenen: bulgu tablosu + "Önce neyi düzelt" listesi + JSON özet.

## Notlar

- Bu proje **git deposu değil**; Ders 12'nin worktree bölümü için Claude'a
  `git init` yaptırıp bir GitHub deposuna bağlayabilirsin (ön koşul föyü).
- `denetim.yml` çalışmadan önce depoya **`ANTHROPIC_API_KEY` secret'ı**
  eklenmeli (GitHub → Settings → Secrets and variables → Actions).
- Runner dakikaları GitHub'a, model kullanımı Anthropic API anahtarına
  faturalanır — **iki ayrı kalem**; `--max-budget-usd` yalnız ikincisini
  keser.

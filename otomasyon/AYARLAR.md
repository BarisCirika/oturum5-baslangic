# CI ayarlari (repo degiskenleri ve secret'lar)

Bu dosya, workflow'larin okudugu **butun** ayarlari tek yerde toplar.
Hicbirini girmezseniz sistem MOCK modda, sifir maliyetle calisir —
varsayilanlar bilerek muhafazakar secildi.

Ayarlarin girildigi yer:
**Settings → Secrets and variables → Actions**
Orada iki sekme var: **Variables** (aciktan gorunur) ve **Secrets**
(bir daha okunamaz, yalniz degistirilir).

---

## 1. Degiskenler (Variables sekmesi)

| Ad | Varsayilan | Ne ise yarar |
|---|---|---|
| `DENETIM_MOD` | `MOCK` | `GERCEK` yazarsaniz model ajanlari gercekten kosar ve **para harcar**. Baska her deger MOCK sayilir. |
| `AJAN_BUTCE` | `0.50` | Ajan basina dolar tavani (`--max-budget-usd`). CLI bu tavana varinca kendi durur. |
| `AJAN_SURE` | `300` | Ajan basina saniye tavani. Ajan asili kalirsa `timeout` oldurur. |
| `AJAN_TUR` | `12` | Ajan basina en fazla tur sayisi (`--max-turns`). |
| `TOPLAM_BUTCE` | `1.50` | Bir kosudaki ajanlarin TOPLAM tavani. Asilirsa rapor yine yazilir ama **kosu kirmizi yanar**. |

Uc ajan var (`guvenlik`, `kalite`, `tutarlilik`), yani varsayilan tavan
3 x 0.50 = 1.50 USD ile hizali. Ajan eklerseniz `TOPLAM_BUTCE` degerini
de buyutun, yoksa her kosu butce asimiyla kirmizi yanar.

### Arayuzden girmek

Settings → Secrets and variables → Actions → **Variables** sekmesi →
**New repository variable** → Name / Value → **Add variable**.

### Komut satirindan girmek

```bash
gh variable set DENETIM_MOD --body "GERCEK"
gh variable set AJAN_BUTCE --body "0.25"
gh variable set TOPLAM_BUTCE --body "0.75"
gh variable list
```

Geri almak (MOCK moda donmek):

```bash
gh variable set DENETIM_MOD --body "MOCK"
# ya da degiskeni tamamen silmek:
gh variable delete DENETIM_MOD
```

---

## 2. Secret'lar (Secrets sekmesi)

| Ad | Zorunlu mu | Ne ise yarar |
|---|---|---|
| `ANTHROPIC_API_KEY` | Yalniz `DENETIM_MOD=GERCEK` icin | Console API anahtari. **Abonelik ise yaramaz**: CI'da `claude --bare` kullaniyoruz ve bare mod OAuth ile keychain'i hic okumaz, kimligi yalniz bu anahtardan alir. |

```bash
gh secret set ANTHROPIC_API_KEY        # degeri sorar, ekranda gorunmez
gh secret list
```

`GITHUB_TOKEN` diye bir sey GIRMEYIN: her kosuya otomatik verilir,
kosu bitince gecersizlesir. Yetkisi her workflow'un basindaki
`permissions:` blogunda ilan edilir.

---

## 3. Iki kapi birden gerekir

Gercek mod kosmasi icin **ikisi de** gerekir:

1. `vars.DENETIM_MOD == 'GERCEK'`
2. `secrets.ANTHROPIC_API_KEY` tanimli

Sadece biri varsa model adimi ya hic kosmaz ya da net bir hatayla durur —
sessizce gecmez. MOCK modda her PR'a dusen yorumda bu iki kapinin
durumu tablo olarak gorunur.

---

## 4. Maliyeti nerede gorursunuz

- **Her kosuda:** PR yorumu / issue icinde "Model ajanlari" bolumu,
  ajan basina maliyet tablosu ve toplam.
- **Her sabah:** sabah brifingi issue'sunda "Maliyet" bolumu — son 24
  saatin model maliyeti, ajan kirilimi, ayri oturum sayisi, CI kosu
  sayisi ve suresi.
- **Ham veri:** raporlarin sonundaki makine-okur satirlar:
  `<!-- maliyet ajan=... mod=... usd=... oturum=... kosu=... -->`
  Sabah brifingi bu satirlari toplar; ayri bir veritabani yoktur.

---

## 5. Guvenli deneme onerisi

Gercek modu ilk kez acarken tavanlari dusurun, bir kosu deneyin,
maliyeti gorun, sonra kalici degeri secin:

```bash
gh variable set AJAN_BUTCE --body "0.10"
gh variable set TOPLAM_BUTCE --body "0.30"
gh variable set DENETIM_MOD --body "GERCEK"
gh workflow run denetim.yml --ref main     # elle tek kosu
# maliyeti gordukten sonra:
gh variable set DENETIM_MOD --body "MOCK"
```

---

## 6. Kosu kayit defteri

`otomasyon/kosular.jsonl` — ajan basina TEK satir, JSONL:

```json
{"ts":"...","alan":"guvenlik","dal":"main","gorev":"denetim/MOCK","session_id":"-","maliyet_usd":0.0,"durum":"tamam"}
```

| Alan | Anlami |
|---|---|
| `alan` | Hangi ajan (guvenlik / kalite / tutarlilik) |
| `gorev` | `denetim/MOCK` ya da `denetim/GERCEK` |
| `session_id` | Ajanin oturum kimligi (GERCEK modda dolu) |
| `maliyet_usd` | O ajanin maliyeti |
| `durum` | `tamam`, `butce-asimi` ya da `hata` |

- **Yerelde:** `bash otomasyon/ajanlari-kostur.sh ...` her kosuda defteri
  otomatik besler; commit'lemek size kalir.
- **CI'da:** main korumali oldugu icin kosu kendi kendine commit EDEMEZ.
  Defter, kosu sayfasinda **artifact** olarak saklanir (14 gun) ve son 5
  satiri kosu ozetine yazilir.
- Baska bir dosyaya yazmak icin: `KAYIT_DOSYA=baska.jsonl`.

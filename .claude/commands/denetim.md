---
description: Commit/PR öncesi repo dosyalarını deterministik kurallarla (gömülü sır, dinamik kod çalıştırma, kabuk çağrısı, yutulan hata, SQL birleştirme, şifresiz http, tamamlanmamış iş notu, HTML SEO) tarar ve raporu özetler. "Denetim yap", "güvenlik taraması", "PR'a hazır mı" gibi durumlarda kullan.
argument-hint: "[dosya veya klasör yolu — boşsa tüm git dosyaları]"
allowed-tools: Bash(git ls-files:*), Bash(git status:*), Bash(python otomasyon/denetim_mock.py:*), Bash(python3 otomasyon/denetim_mock.py:*), Read, Grep
---

# MOCK denetim

Kapsam argümanı: `$ARGUMENTS` (boşsa tüm repo).

## 1. Denetimi çalıştır

Bash ile, proje kökünde:

- Argüman **boşsa**: `git ls-files > kapsam.txt`
- Argüman **varsa**: `git ls-files -- $ARGUMENTS > kapsam.txt`

Sonra:

```
python3 otomasyon/denetim_mock.py kapsam.txt rapor.md sonuc.json
```

`python3` bulunamazsa (Windows) aynı komutu `python` ile çalıştır.

**Çıkış kodu:** `1` = yüksek etkili bulgu var (kapı KIRMIZI), `0` = temiz. `1` bir çökme DEĞİLDİR; başka bir kod veya traceback gelirse hatayı olduğu gibi raporla ve dur.

## 2. Sonuçları oku

`sonuc.json` ve `rapor.md` dosyalarını oku. Yüksek ve orta etkili her bulgu için işaretlenen satırı (±2 satır) Read ile aç ve **gerçek sorun mu, yanlış alarm mı** karar ver. Tipik yanlış alarmlar: kuralı *anlatan* dokümantasyon, denetim betiğinin kendi regex tanımları, yorum satırları.

## 3. Türkçe özet ver

Sırasıyla:

1. **Kapı durumu:** KIRMIZI / YEŞİL, taranan dosya sayısı, bulgu sayıları (yüksek/orta/düşük).
2. **Bulgu tablosu:** etki · `dosya:satır` (tıklanabilir link) · etiket · gerçek mi / yanlış alarm mı (tek cümle gerekçe).
3. **Önce neyi düzelt:** raporun ilk 3 maddesi. Bunların yanlış alarm olanlarını belirt, varsa asıl düzeltilmesi gereken gerçek bulguları öne çıkar.
4. **Kapsam notu:** `git ls-files` commit edilmemiş (untracked) dosyaları taramaz; bu tür dosya varsa (`git status --short` ile bak) adlarını söyle.

Kod veya dosya DEĞİŞTİRME; yalnızca raporla. `rapor.md`, `sonuc.json` ve `kapsam.txt` çıktı dosyalarıdır, olduğu gibi bırak.

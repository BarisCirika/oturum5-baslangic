"""Oyun kaydini dosyaya yazma/okuma."""
import json

def kaydet(yol, veri):
    with open(yol, "w", encoding="utf-8") as f:
        json.dump(veri, f, ensure_ascii=False)

def yukle(yol):
    with open(yol, encoding="utf-8") as f:
        return json.load(f)

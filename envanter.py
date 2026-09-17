"""Envanter yonetimi icin basit yardimcilar."""
class Envanter:
    def __init__(self):
        self.esyalar = []
    def ekle(self, ad):
        self.esyalar.append(ad)
    def cikar(self, ad):
        if ad in self.esyalar:
            self.esyalar.remove(ad)
    def say(self):
        return len(self.esyalar)

"""Oyuncu can ve hasar hesaplamalari."""
def hasar_ver(can, miktar):
    return max(0, can - miktar)

def iyilestir(can, miktar, tavan=100):
    return min(tavan, can + miktar)

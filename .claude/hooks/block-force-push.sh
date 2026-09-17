#!/usr/bin/env bash
# PreToolUse hook (Bash): force push ve hard reset komutlarini engeller.
# Claude Code, arac girdisini JSON olarak stdin'den gonderir.
# exit 2 = komutu engelle; stderr mesaji Claude'a iletilir.

input="$(cat)"

# Komutu parcalara ayir: JSON'daki "command":" baslangici, kacisli \n,
# ve ; & | ayiricilari yeni satir olur. Boylece yalnizca KOMUT olarak
# baslayan parcalar kontrol edilir; commit mesaji gibi metinler degil.
parcalar="$(printf '%s' "$input" \
  | sed -e 's/"command"[[:space:]]*:[[:space:]]*"/\n/g' -e 's/\\n/\n/g' -e 's/[;&|()]/\n/g' \
  | sed -e 's/^[[:space:]]*//')"

# git push --force / --force-with-lease / -f (ör. -uf) / +refspec
if printf '%s\n' "$parcalar" | grep -Eq '^git[[:space:]]+([^[:space:]"]+[[:space:]]+)*push([[:space:]]+[^[:space:]"]+)*[[:space:]]+(--force(-with-lease)?|-[a-zA-Z]*f[a-zA-Z]*|\+[^[:space:]"]+)([[:space:]"=]|$)'; then
  echo "ENGELLENDI: 'git push --force' ve turevleri bu projede yasak. Normal 'git push' kullanin." >&2
  exit 2
fi

# git reset --hard
if printf '%s\n' "$parcalar" | grep -Eq '^git[[:space:]]+([^[:space:]"]+[[:space:]]+)*reset([[:space:]]+[^[:space:]"]+)*[[:space:]]+--hard([[:space:]"]|$)'; then
  echo "ENGELLENDI: 'git reset --hard' bu projede yasak. 'git stash' veya 'git reset --soft' kullanin." >&2
  exit 2
fi

exit 0

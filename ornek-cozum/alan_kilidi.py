#!/usr/bin/env python3
"""H2 - Alan kilidi (PreToolUse hook).

Bu worktree'nin .claude/alan.txt dosyasinda yazan klasor onegi disina
yazmayi ENGELLER (exit 2). Paralel ajanlarin birbirini ezmesini RICA ile
degil KURAL ile onler.

settings icinde matcher "Edit|Write" ile baglanir.
"""
import json
import os
import sys

d = json.load(sys.stdin)
yol = (d.get("tool_input", {}) or {}).get("file_path", "") or ""

# Her zaman korunan ortak dosyalar (tek sahipli / kilit dosyalari)
ORTAK = ["package.json", "package-lock.json", "personas.json", "yarn.lock"]
if any(os.path.basename(yol) == x for x in ORTAK):
    print(f"Ortak dosyaya paralel yazma engellendi: {yol}", file=sys.stderr)
    sys.exit(2)

alan_dosya = os.path.join(".claude", "alan.txt")
if os.path.exists(alan_dosya):
    alan = open(alan_dosya, encoding="utf-8").read().strip()
    if alan and yol and (alan not in yol):
        print(f"Alan disina yazma engellendi: {yol} (izinli alan: {alan})",
              file=sys.stderr)
        sys.exit(2)

sys.exit(0)

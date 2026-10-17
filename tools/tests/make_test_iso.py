#!/usr/bin/env python3
"""Build tiny synthetic XDVDFS images for tools/tests/xiso_selftest.ps1 (no game data involved).

  make_test_iso.py <outdir>
Writes ok.iso, ok_xgd3.iso (partition at 0x2080000), truncated.iso, evil.iso, notiso.iso.
"""
import os
import struct
import sys

SECTOR = 2048
MAGIC = b"MICROSOFT*XBOX*MEDIA"


def node_table(entries):
    """entries: [(name, start_sector, length, is_dir)] -> directory table bytes (list-shaped tree)."""
    raw = []
    for name, start, length, is_dir in entries:
        nb = name.encode("latin-1")
        size = (14 + len(nb) + 3) & ~3
        raw.append((nb, start, length, 0x10 if is_dir else 0x20, size))
    offs, o = [], 0
    for r in raw:
        offs.append(o)
        o += r[4]
    out = bytearray()
    for i, (nb, start, length, attr, size) in enumerate(raw):
        right = offs[i + 1] // 4 if i + 1 < len(raw) else 0
        out += struct.pack("<HHIIBB", 0, right, start, length, attr, len(nb)) + nb
        out += b"\xff" * (size - 14 - len(nb))
    out += b"\xff" * (-len(out) % SECTOR)
    return bytes(out)


def build(path, base=0, files=None, evil=False, truncate=False):
    files = files or {"default.xex": b"X" * 5000, "data/a.bin": b"A" * 3000, "data/sub/b.bin": b"B" * 100}
    sectors = {}
    nxt = 34 + 8  # leave room for the volume descriptor and directory tables
    layout = {}

    def alloc(nbytes):
        nonlocal nxt
        s = nxt
        nxt += max(1, -(-nbytes // SECTOR))
        return s

    # directory tree
    tree = {}
    for p, data in files.items():
        parts = p.split("/")
        d = tree
        for part in parts[:-1]:
            d = d.setdefault(part, {})
        d[parts[-1]] = data

    blobs = {}

    def emit(d):
        entries = []
        for name in sorted(d):
            v = d[name]
            if isinstance(v, dict):
                s, l = emit(v)
                entries.append((name, s, l, True))
            else:
                s = alloc(len(v))
                blobs[s] = v
                entries.append((name, s, len(v), False))
        if evil:
            entries.insert(0, ("..", 0, 0, True))
        table = node_table(entries)
        s = alloc(len(table))
        blobs[s] = table
        return s, len(table)

    rs, rl = emit(tree)
    total = base + nxt * SECTOR
    img = bytearray(total)
    img[base + 32 * SECTOR: base + 32 * SECTOR + 28] = MAGIC + struct.pack("<II", rs, rl)
    for s, data in blobs.items():
        img[base + s * SECTOR: base + s * SECTOR + len(data)] = data
    if truncate:
        img = img[: base + (nxt - 3) * SECTOR]
    with open(path, "wb") as f:
        f.write(img)


out = sys.argv[1]
os.makedirs(out, exist_ok=True)
build(os.path.join(out, "ok.iso"))
build(os.path.join(out, "ok_xgd3.iso"), base=0x2080000)
build(os.path.join(out, "truncated.iso"), truncate=True)
build(os.path.join(out, "evil.iso"), evil=True)
open(os.path.join(out, "notiso.iso"), "wb").write(b"hello" * 100000)
print("wrote test images to", out)

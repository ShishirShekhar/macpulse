#!/usr/bin/env python3
"""Packs an Apple .iconset directory of PNGs into a valid .icns file.

Fallback for environments (such as sandboxes or stripped CI runners) where
iconutil is restricted or cannot reach AppleIconServicesAgent.
"""

import os
import struct
import sys

TAG_MAP = [
    ("icon_16x16.png", b"ic04"),
    ("icon_16x16@2x.png", b"ic11"),
    ("icon_32x32.png", b"ic05"),
    ("icon_32x32@2x.png", b"ic12"),
    ("icon_128x128.png", b"ic07"),
    ("icon_128x128@2x.png", b"ic13"),
    ("icon_256x256.png", b"ic08"),
    ("icon_256x256@2x.png", b"ic14"),
    ("icon_512x512.png", b"ic09"),
    ("icon_512x512@2x.png", b"ic10"),
]


def pack(iconset_dir: str, output_icns: str) -> None:
    chunks = []
    for filename, tag in TAG_MAP:
        path = os.path.join(iconset_dir, filename)
        if os.path.exists(path):
            with open(path, "rb") as f:
                data = f.read()
            chunk_len = len(data) + 8
            chunks.append(tag + struct.pack(">I", chunk_len) + data)
    body = b"".join(chunks)
    total_len = len(body) + 8
    with open(output_icns, "wb") as f:
        f.write(b"icns" + struct.pack(">I", total_len) + body)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: pack-icns.py <iconset_dir> <output.icns>", file=sys.stderr)
        sys.exit(1)
    pack(sys.argv[1], sys.argv[2])

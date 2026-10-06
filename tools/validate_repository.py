#!/usr/bin/env python3
"""Validate source and runtime asset integrity without third-party dependencies."""

import argparse
import ast
from collections import Counter
import json
import os
from pathlib import Path
import re
import struct
import sys
import xml.etree.ElementTree as ET
import zlib

SKIP_DIRS = {".git", ".vs", ".idea", "build", "vcpkg", "vcpkg_installed", "__pycache__",
             ".vcpkg-binary-cache", ".cache", "_backup_original", "generated", "node_modules"}
TEXT_SUFFIXES = {".lua", ".cpp", ".h", ".hpp", ".c", ".py", ".sh", ".bat", ".ps1",
                 ".yml", ".yaml", ".json", ".otmod", ".otui", ".otml", ".props", ".vcxproj",
                 ".cmake", ".txt", ".ini", ".md", ".xml", ".gradle", ".proto", ".php"}


def validate_png(path):
    """Check chunk boundaries/CRCs, including IEND, without decoding or changing pixels."""
    with Path(path).open("rb") as stream:
        if stream.read(8) != b"\x89PNG\r\n\x1a\n":
            raise ValueError("invalid PNG signature")
        first, has_pixels = True, False
        while True:
            header = stream.read(8)
            if len(header) != 8:
                raise ValueError("truncated PNG chunk header or missing IEND")
            length, kind = struct.unpack("!I4s", header)
            if first and (kind != b"IHDR" or length != 13):
                raise ValueError("missing or invalid IHDR")
            first = False
            crc = zlib.crc32(kind)
            remaining = length
            while remaining:
                block = stream.read(min(remaining, 65536))
                if not block:
                    raise ValueError("truncated PNG chunk data")
                crc = zlib.crc32(block, crc)
                remaining -= len(block)
            expected = stream.read(4)
            if len(expected) != 4 or struct.unpack("!I", expected)[0] != crc:
                raise ValueError("invalid PNG chunk checksum")
            has_pixels = has_pixels or kind == b"IDAT"
            if kind == b"IEND":
                if length != 0 or not has_pixels:
                    raise ValueError("invalid IEND or missing image data")
                return


def validate_tree(root):
    root = Path(root).resolve()
    counts, errors = Counter(), []
    if not root.is_dir():
        return counts, [f"Repository directory does not exist: {root}"]
    for directory, subdirs, names in os.walk(root):
        subdirs[:] = sorted(d for d in subdirs if d not in SKIP_DIRS and not d.startswith("cmake-build"))
        for name in sorted(names):
            path = Path(directory) / name
            relative = path.relative_to(root).as_posix()
            suffix = path.suffix.lower()
            try:
                if suffix == ".png":
                    counts["PNG"] += 1
                    validate_png(path)
                if suffix not in TEXT_SUFFIXES:
                    continue
                counts["UTF-8 text"] += 1
                text = path.read_bytes().decode("utf-8-sig")
                if re.search(r"^(?:<<<<<<< |>>>>>>> )", text, re.MULTILINE):
                    raise ValueError("unresolved merge conflict")
                if suffix == ".json":
                    counts["JSON"] += 1
                    document = json.loads(text)
                    if name == "catalog-sound.json":
                        for entry in document:
                            if entry.get("type") == "sounds" and not (path.parent / entry["file"]).is_file():
                                raise ValueError("missing soundbank referenced by catalog: " + entry["file"])
                elif suffix == ".py":
                    counts["Python"] += 1
                    ast.parse(text, filename=relative)
                elif suffix in {".xml", ".props", ".vcxproj"}:
                    counts["XML/MSBuild"] += 1
                    tree = ET.fromstring(text)
                    if suffix == ".vcxproj":
                        for element in tree.iter():
                            if element.tag.rsplit("}", 1)[-1] not in {"ClCompile", "ClInclude", "ResourceCompile"}:
                                continue
                            ref = element.get("Include", "")
                            if ref and not any(marker in ref for marker in ("$(", "%(", "*")):
                                if not (path.parent / ref.replace("\\", "/")).is_file():
                                    raise ValueError("missing project reference: " + ref)
                if relative == "src/framework/config.h":
                    match = re.search(r'^#define ENCRYPTION_PASSWORD\s+(.+)$', text, re.MULTILINE)
                    if not match or match.group(1).strip() != '""':
                        raise ValueError("public source must not contain an asset encryption password")
            except (OSError, ValueError, SyntaxError, ET.ParseError, KeyError, TypeError) as exc:
                errors.append(f"{relative}: {exc}")
    return counts, errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    counts, errors = validate_tree(args.root)
    for error in errors:
        print(error, file=sys.stderr)
    print(", ".join(f"{count} {kind}" for kind, count in sorted(counts.items())))
    print(f"Integrity checks: {len(errors)} error(s)")
    return bool(errors)


if __name__ == "__main__":
    sys.exit(main())

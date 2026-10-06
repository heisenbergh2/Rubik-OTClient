#!/usr/bin/env python3
"""Pack OTC modules/mods/data into a single assets.pak (ZIP) for embedding in exe.

Usage:
    python build_pak.py                       # plain pak, no encryption
    python build_pak.py --password P --header H   # encrypt each file inside

Outputs:
    assets.pak beside this script, or the path given by --output (stored ZIP).

When --password and --header are provided, every file is prefixed with HEADER
and XChaCha20-Poly1305-encrypted with the OTC algorithm (matches ResourceManager::
encrypt / decrypt in src/framework/core/resourcemanager.cpp). The C++ side
reads the HEADER at runtime in readFileContents() and decrypts on the fly.

For end-to-end protection, PASSWORD/HEADER in this script MUST match the
ENCRYPTION_PASSWORD / ENCRYPTION_HEADER #defines in src/framework/config.h
and ENABLE_ENCRYPTION must be set to 1 in that file.
"""
import argparse
import os
import zipfile
import time
import hashlib
import subprocess
import tempfile
import shutil
from pathlib import Path

# LuaJIT used to bytecode-compile .lua before encryption (bytecode protection).
LUAJIT_COMPILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "luajit_compile.lua")


def find_luajit(explicit=None):
    """Use the manifest install location, with explicit/PATH fallbacks."""
    if explicit:
        candidate = shutil.which(explicit)
        if candidate:
            return candidate
        if os.path.isfile(explicit):
            return os.path.abspath(explicit)
        raise ValueError(f"LuaJIT executable not found: {explicit}")
    for prefix in (Path(REPO) / "vcpkg_installed", Path(REPO) / "vc18/vcpkg_installed"):
        for triplet in ("x64-windows-static", "x64-windows"):
            candidate = prefix / triplet / "tools/luajit/luajit.exe"
            if candidate.is_file():
                return str(candidate)
    candidate = shutil.which("luajit")
    if candidate:
        return candidate
    raise ValueError("Encrypted Lua packing requires LuaJIT; pass --luajit PATH.")


def lua_to_bytecode(src_bytes: bytes, chunkname: str, luajit: str) -> bytes:
    """Compile Lua source -> LuaJIT bytecode (via string.dump), keeping the module path
    as the chunk name so in-game tracebacks stay readable."""
    with tempfile.TemporaryDirectory() as td:
        src = os.path.join(td, "in.lua")
        out = os.path.join(td, "out.bc")
        with open(src, "wb") as fh:
            fh.write(src_bytes)
        r = subprocess.run([luajit, LUAJIT_COMPILE, src, out, chunkname],
                           capture_output=True)
        if r.returncode != 0 or not os.path.isfile(out):
            raise RuntimeError(f"luajit compile failed for {chunkname}: {r.stderr.decode(errors='replace')[:300]}")
        with open(out, "rb") as fh:
            return fh.read()

REPO = os.path.dirname(os.path.abspath(__file__))
OUT  = os.path.join(REPO, "assets.pak")

# Roots we want to include. Each entry is a path relative to REPO that gets walked.
INCLUDE_DIRS = [
    "modules",
    "mods",
    "data/cursors",
    "data/fonts",
    "data/images",
    "data/json",
    "data/locales",
    "data/particles",
    "data/resources",
    # SPIR-V bytecode for the Vulkan renderer. The client loads it at runtime via
    # ResourceManager, so without this entry releases with an embedded pak would have
    # Vulkan without shaders (the renderer then degrades to just clearing the screen).
    # Vulkan shader sources are filtered by path; OpenGL shader sources stay included.
    "data/shaders",
    "data/styles",
]

# Single files at the data root we want too.
INCLUDE_FILES = [
    "data/setup.otml",
]

# File patterns / paths to skip while walking.
# Archives (.rar/.zip/.7z) and graphic sources (.psd) are the artist's working material:
# the client never reads them, and they sit in the same directories as the finished .png,
# so without this filter they ended up in the pak and needlessly bloated the exe.
SKIP_NAME_PREFIXES = (".", "__")            # hidden + python cache
SKIP_NAME_SUFFIXES = (".pdb", ".exp", ".lib", ".log", ".bak", ".swp", ".tmp",
                      ".rar", ".zip", ".7z", ".pak", ".psd",   # archives + PSD sources
                      ".bat")
SKIP_NAMES        = {"Thumbs.db", ".DS_Store", ".gitkeep", ".gitignore"}
# Directories skipped entirely: _backup_original holds copies of the original,
# uncompressed graphics and must NOT end up in the pak.
SKIP_DIRS         = {"_backup_original"}

# NOTE: .vert/.frag must NOT be in SKIP_NAME_SUFFIXES. Vulkan reads the compiled .spv, so it is
# tempting to filter out the GLSL sources - but the same extensions are used by OpenGL shaders in
# modules (game_shaders, game_exaltationforge - 26 files), which the client loads as TEXT
# at runtime. A global rule would cut them out of the pak and the effects would stop working.
# So we filter out the Vulkan shader sources selectively, by path.
SKIP_PATH_PREFIXES = ("data/shaders/vulkan/",)


def should_skip(name: str) -> bool:
    if name in SKIP_NAMES:
        return True
    for p in SKIP_NAME_PREFIXES:
        if name.startswith(p):
            return True
    for s in SKIP_NAME_SUFFIXES:
        if name.lower().endswith(s):
            return True
    return False


def walk_files(root_dir: str):
    for dp, dn, fn in os.walk(root_dir):
        # prune skipped subdirs in-place so os.walk doesn't descend into them
        dn[:] = sorted(d for d in dn if d not in SKIP_DIRS and not should_skip(d))
        for f in sorted(fn):
            if should_skip(f):
                continue

            full = os.path.join(dp, f)

            # selective filtering of Vulkan shader sources (see the comment at SKIP_PATH_PREFIXES):
            # only compiled .spv go into the pak, but the GLSL of other modules must stay
            rel = full.replace("\\", "/")
            if any(pref in rel for pref in SKIP_PATH_PREFIXES) and not f.endswith(".spv"):
                continue

            yield full


def encrypt_otc(data: bytes, password: str) -> bytes:
    """XChaCha20-Poly1305 (24-byte nonce) — matches ResourceManager::decrypt in
    src/framework/core/resourcemanager.cpp. Key = BLAKE2b-256(password). Returns
    [24B nonce][ciphertext][16B Poly1305 tag]; the ENCRYPTION_HEADER magic is
    prepended by add()."""
    if not password:
        return data
    try:
        from Crypto.Cipher import ChaCha20_Poly1305
    except ImportError as exc:
        raise RuntimeError("Encrypted packing requires PyCryptodome: pip install pycryptodome") from exc
    key = hashlib.blake2b(password.encode("utf-8"), digest_size=32).digest()
    nonce = os.urandom(24)  # 24 bytes -> XChaCha20
    ct, tag = ChaCha20_Poly1305.new(key=key, nonce=nonce).encrypt_and_digest(data)
    return nonce + ct + tag


def build_archive(repo=REPO, output=OUT, password="", header="", luajit=None):
    """Stream plain files and publish only a complete archive, preserving older builds on failure."""
    if bool(password) != bool(header):
        raise ValueError("--password and --header must be provided together (or neither)")
    repo = Path(repo).resolve()
    output = Path(output).resolve()
    for inc in INCLUDE_DIRS:
        if not (repo / inc).is_dir():
            raise FileNotFoundError(f"Required asset directory is missing: {inc}")
    for inc in INCLUDE_FILES:
        if not (repo / inc).is_file():
            raise FileNotFoundError(f"Required asset file is missing: {inc}")

    encrypt = bool(password)
    if encrypt:
        luajit = find_luajit(luajit)
        # Check the optional cipher before opening the output archive.
        encrypt_otc(b"", password)

    output.parent.mkdir(parents=True, exist_ok=True)
    total_files = total_bytes = 0
    header_bytes = header.encode("utf-8") if encrypt else b""
    encrypt_skip_exts = {".rar", ".ogg", ".xml", ".dll", ".exe", ".log", ".otb"}

    # Keep the temporary file beside the destination for an atomic os.replace.
    with tempfile.NamedTemporaryFile(prefix=".assets-", suffix=".tmp", dir=output.parent, delete=False) as pending:
        temporary = pending.name
    try:
        # Stored entries avoid per-file decompression when PhysFS reads the package.
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_STORED) as zf:
            def add(src):
                nonlocal total_files, total_bytes
                src = Path(src)
                arcname = src.relative_to(repo).as_posix()
                total_bytes += src.stat().st_size
                if encrypt and src.suffix.lower() not in encrypt_skip_exts:
                    data = src.read_bytes()
                    if src.suffix.lower() == ".lua":
                        data = lua_to_bytecode(data, arcname, luajit)
                    zf.writestr(arcname, header_bytes + encrypt_otc(data, password))
                else:
                    # ZipFile.write copies in chunks instead of buffering an entire image.
                    zf.write(src, arcname)
                total_files += 1

            for inc in INCLUDE_DIRS:
                for full in walk_files(repo / inc):
                    add(full)
            for inc in INCLUDE_FILES:
                add(repo / inc)
        os.replace(temporary, output)
    finally:
        if os.path.exists(temporary):
            os.remove(temporary)
    return total_files, total_bytes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--password", default="", help="Password matching the private ENCRYPTION_PASSWORD definition")
    parser.add_argument("--header", default="", help="Marker matching ENCRYPTION_HEADER")
    parser.add_argument("--luajit", help="LuaJIT executable for encrypted Lua files")
    parser.add_argument("--output", default=OUT, help="Destination PAK (default: assets.pak beside this script)")
    args = parser.parse_args()
    start = time.time()
    try:
        total_files, total_bytes = build_archive(output=args.output, password=args.password, header=args.header, luajit=args.luajit)
    except (OSError, ValueError, RuntimeError) as exc:
        parser.exit(1, f"ERROR: {exc}\n")

    pak_size = os.path.getsize(args.output)
    elapsed  = time.time() - start

    label = "encrypted" if args.password else "plain"
    print(f"Built {args.output} ({label})")
    print(f"  {total_files} files, {total_bytes/1024/1024:.1f} MB content -> {pak_size/1024/1024:.1f} MB pak (stored)")
    print(f"  {elapsed:.1f}s")
    if args.password:
        print(f"  REMEMBER: set the same values in src/framework/config.h and ENABLE_ENCRYPTION=1")


if __name__ == "__main__":
    main()

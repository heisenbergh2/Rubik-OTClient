"""Regression coverage for publication checks and interrupted package builds."""

import importlib.util
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile
import zlib

ROOT = Path(__file__).resolve().parents[2]


def load_tool(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


packer = load_tool("build_pak", ROOT / "build_pak.py")
validator = load_tool("validate_repository", ROOT / "tools/validate_repository.py")


def chunk(kind, data):
    return struct.pack("!I", len(data)) + kind + data + struct.pack("!I", zlib.crc32(kind + data))


class IntegrityTests(unittest.TestCase):
    def test_png_rejects_truncation_and_corrupted_pixels(self):
        ihdr = chunk(b"IHDR", struct.pack("!2I5B", 1, 1, 8, 6, 0, 0, 0))
        image = chunk(b"IDAT", zlib.compress(b"\0\xff\0\0\xff"))
        prefix = b"\x89PNG\r\n\x1a\n" + ihdr + image
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "pixel.png"
            path.write_bytes(prefix + chunk(b"IEND", b""))
            validator.validate_png(path)
            path.write_bytes(prefix + b"\0\0\0\0")
            with self.assertRaisesRegex(ValueError, "missing IEND"):
                validator.validate_png(path)
            broken = bytearray(prefix + chunk(b"IEND", b""))
            broken[len(ihdr) + 16] ^= 1
            path.write_bytes(broken)
            with self.assertRaisesRegex(ValueError, "checksum"):
                validator.validate_png(path)

    def test_missing_soundbank_and_non_utf8_json_are_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "catalog-sound.json").write_text(json.dumps([{"type": "sounds", "file": "missing.dat"}]), encoding="utf-8")
            (root / "notes.json").write_bytes(b'{"note":"a\xe7ao"}')
            _, errors = validator.validate_tree(root)
            self.assertEqual(len(errors), 2)
            self.assertTrue(any("missing soundbank" in error for error in errors))
            (root / "missing.dat").write_bytes(b"soundbank")
            (root / "notes.json").write_text('{"note":"a\u00e7\u00e3o"}', encoding="utf-8")
            self.assertEqual(validator.validate_tree(root)[1], [])


class PackerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for directory in packer.INCLUDE_DIRS:
            (self.root / directory).mkdir(parents=True, exist_ok=True)
        self.write("data/setup.otml", b"game\n")
        self.output = self.root / "assets.pak"

    def write(self, relative, contents):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(contents)

    def test_plain_archive_needs_no_crypto_and_preserves_runtime_resources(self):
        expected = {
            "modules/example/main.lua": b"return 1530\n",
            "modules/example/effect.frag": b"OpenGL shader",
            "data/resources/tasks/background.png": b"image fixture",
            "data/shaders/vulkan/effect.spv": b"SPIR-V fixture",
            "data/setup.otml": b"game\n",
        }
        for name, contents in expected.items():
            self.write(name, contents)
        self.write("data/images/_backup_original/large.png", b"backup")
        self.write("data/images/source.PSD", b"editable source")
        self.write("data/shaders/vulkan/effect.vert", b"build-time source")
        with patch.dict(sys.modules, {"Crypto": None}):
            files, size = packer.build_archive(self.root, self.output)
        self.assertEqual(files, len(expected))
        self.assertEqual(size, sum(map(len, expected.values())))
        with zipfile.ZipFile(self.output) as archive:
            self.assertIsNone(archive.testzip())
            self.assertEqual(set(archive.namelist()), set(expected))
            for name, contents in expected.items():
                self.assertEqual(archive.read(name), contents)

    def test_failed_write_preserves_previous_package_and_cleans_temporary_file(self):
        self.output.write_bytes(b"previous working package")
        with patch.object(zipfile.ZipFile, "write", side_effect=OSError("disk full")):
            with self.assertRaisesRegex(OSError, "disk full"):
                packer.build_archive(self.root, self.output)
        self.assertEqual(self.output.read_bytes(), b"previous working package")
        self.assertEqual(list(self.root.glob(".assets-*.tmp")), [])

    def test_missing_required_assets_do_not_replace_previous_package(self):
        self.output.write_bytes(b"previous working package")
        (self.root / "data/setup.otml").unlink()
        with self.assertRaises(FileNotFoundError):
            packer.build_archive(self.root, self.output)
        self.assertEqual(self.output.read_bytes(), b"previous working package")

    def test_incomplete_encryption_arguments_do_not_create_output(self):
        with self.assertRaisesRegex(ValueError, "provided together"):
            packer.build_archive(self.root, self.output, password="test only")
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()

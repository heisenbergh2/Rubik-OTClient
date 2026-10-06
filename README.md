# RubikOTC

A game client for the RubikOTC server (protocol 15.30) with a set of
in-house features:

- **Custom Vulkan renderer** - atlas-batched sprite pipeline: one 2D-array atlas,
  content-hash deduplication, chunked storage for oversized textures, and a
  MAILBOX-first presentation mode (uncapped FPS without tearing). The client can
  start in pure-Vulkan mode without ever creating an OpenGL context.
- **Memory-optimized asset lifecycle** - lazy module UI construction, batched GL
  texture deletion, pixel-copy garbage collection with disk reload on first draw,
  heap trimming after the appearances parse, and live memory diagnostics
  (`[mem]` / `[boot]` / `[gc]` log lines).
- **Protocol 15.30 support** with protobuf appearances and per-version asset
  directories (`data/things/1530/`).

## Game assets (`data/things`)

The client assets (sprites/appearances) are **not** part of this repository -
`data/things/` is gitignored because of its size. Download the content here:

**[data/things - Google Drive](https://drive.google.com/file/d/1pKOYzTEn9D6dOEB4FDd3gZQt7CyRQ9F1/view?usp=drive_link)**

Extract it into `data/things/` so you end up with:

- `data/things/1530/` - protocol 15.30 assets (protobuf appearances,
  `catalog-content.json`, sprite sheets) plus the `satellite/` tiles used by the
  Cyclopedia Map in Surface View.
- `data/things/1530_mapview/` - a second tile set for the Cyclopedia Map's
  "Map View" toggle (classic minimap palette with building outlines, generated
  by `tools/build_mapview_tiles.py`). Both folders are required.

## Building (Windows)

The `vc18` solution requires Visual Studio 2026 with the **v145 C++ toolset**,
the Windows SDK, and vcpkg with `VCPKG_ROOT` set. Run these commands in the x64
Native Tools command prompt.
Dependencies are restored from the pinned baseline in `vcpkg.json`.

```
msbuild vc18\otclient.sln /m /p:Configuration=DirectX /p:Platform=x64 /p:VcpkgManifestFeatures=directx
```

The executable is produced as `RubikOTC.exe` in the repository root.
Select the renderer with `renderBackend = vulkan` or `gl` in `config.ini`
(also available in-game under Options -> Graphics).

For the CMake build, the `windows-release` preset uses Ninja and the MSVC
environment selected by the command prompt. CI uses Visual Studio 2022 for
this route; it does not build the `vc18` solution with v143.

```
cmake --preset windows-release
cmake --build --preset windows-release
ctest --test-dir build/windows-release --output-on-failure
```

This produces `otclient.exe` in the repository root. Release builds keep
matching `.pdb` debugging symbols separate; executables and symbols are
ignored by Git. The default renderer is OpenGL. Vulkan is experimental;
measure frame times and memory on the target hardware before changing it.

## Runtime files and validation

The included soundbank is `data/sounds/1530/`. Incomplete legacy soundbanks
are not part of the distribution. Other client versions require their own
complete versioned soundbank and game assets.

Before publishing, run the dependency-free integrity checks and packer tests:

```
python tools/validate_repository.py
python -B -m unittest discover -s tests/python -p "test_*.py"
```

The integrity check validates PNG structure and checksums, UTF-8 text, JSON,
Python syntax, XML/MSBuild files, and sound catalog references. CI also runs
the Lua tests. These checks do not replace building the client and testing
login, rendering, combat, audio, and reconnecting against the 15.30 server.

`python build_pak.py` builds the UI asset package with Python's standard
library. It streams files into an uncompressed ZIP to limit build-time RAM
usage and replaces an existing package only after a successful build. Use
`--output PATH` to write elsewhere. Game sprites and versioned soundbanks
remain external. Embedding is disabled in `resources.rc` by default, so
building a PAK alone does not create a standalone executable.

Asset encryption is disabled, and the public source contains no asset
password. Optional encrypted packing additionally requires PyCryptodome,
LuaJIT (`--luajit PATH` or the project's vcpkg installation), and matching
private compiler definitions. Backups, PSD sources, private configuration,
executables, and debug symbols should remain outside the Git commit.

## Building (Linux / Docker / Android)

The upstream CMake build is preserved - see `CMakeLists.txt`, `Dockerfile`
and the scripts in the repository root. The Vulkan renderer is currently
Windows-only; other platforms use the OpenGL path.

## License

Licensed under the MIT License.

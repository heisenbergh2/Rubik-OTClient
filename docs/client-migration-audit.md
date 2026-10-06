# Client migration audit — 2026-09-06

Primary repository: JV-071/RubikOTC, starting at `bd3c3fd`.
Reference snapshots: RubikOTC `cc9298b0`, OpenTibiaBR/otclient `dd5641492`,
and nyxos-otc `c53683f`. Preserve RubikOTC's module behavior and UI fixes when
porting individual changes. This is an initial, scoped audit, not a claim that
every historical difference between the four repositories has been reviewed.

| Candidate | Evidence and decision |
| --- | --- |
| OpenTibiaBR OTUI editor | Imported `modules/dev_otui` from `9bfac7719`; added missing work-directory write binding, upstream parser self-tests and CRLF checks |
| RubikOTC Lua access optimization (`c4f9a814`) | Already present: `prefixedKey`, thread-local string storage, and `toObjectPtr` in RubikOTC's Lua interface |
| RubikOTC map walking buffer optimization (`799238db`) | Already present: `std::vector<Tile*> walkingTiles` outside the floor loop, with next-cache-entry occlusion lookup |
| Nyxos pending audio cancellation (`0007b22`) | Equivalent protection already exists: RubikOTC checks `m_playing` before calling `play()` in `setSoundFile`; do not port the other fork's implementation just to make it identical |
| OpenTibiaBR OpenAL effect initialization (`8f55d8898`) | RubikOTC already initializes `m_effectSlot` and `m_effectId` to zero; the rest of the OpenAL changes still needs separate review |
| Browser overlays | Imported six missing physfs/protobuf patch files and exempted browser patches from the blanket Git ignore |
| Android old CMake failure | Stop forcing vcpkg to use Gradle's CMake; cache native binaries, LuaJIT and Gradle separately |
| Linux / macOS / browser compilation | Added isolated target caches and artifact packaging; first successful builds and device/browser validation remain required |
| RubikOTC Cocoa/Metal | Deferred: RubikOTC uses X11/OpenGL on macOS and has its own modern GL pipeline; porting Metal requires platform/renderer parity testing, not just copying a workflow |
| Nyxos aimed spells | Deferred: protocol/server capability change, not a generic performance improvement; review compatibility before changing RubikOTC's speech packets |

## Validation and remaining work

The OTUI editor headless tests exercise parsing, structural edits, selection
identity checks, and byte-preserving round trips. They do not exercise a real
window, filesystem mounts, save permissions or rendering. A rebuilt executable
must pass the manual editor checklist below before declaring runtime integration
complete:

1. Open with Ctrl+Alt+U before and after login.
2. Preview an existing RubikOTC screen and a style-only file.
3. Edit a disposable loose `.otui`, save, inspect the `.bak`, and reload.
4. Verify edits preserve neighbouring widgets and RubikOTC's visual sizing.
5. Close/reload the module and check for lingering input grabs or watch events.

Performance comparisons must use the same machine, renderer, resolution, scene,
asset set and FPS cap. Record frame times (including slow frames), CPU, memory
and loading times before claiming a measured gain. No FPS improvement is claimed
from this initial audit: the first two hot-path optimizations were already present.

Follow-up review should cover the remaining renderer/profiler changes from
RubikOTC, OpenTibiaBR's rendering/login fixes and Nyxos's module/drag fixes in
small independently verifiable changes. Keep source commits and author credits
with each imported change, and propose upstream contributions only after validation.

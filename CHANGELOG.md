# Changelog

All notable changes to **BridgeZX** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project uses semantic versioning.

## [0.5.2] - 2026-06-20

This is the public repository catch-up release. The GitHub repo had only the early AY/bit-bang era code published; this release updates it to the current BridgeZX architecture used by the active local project.

### Major Server Changes
- Replaced the old monolithic `wifi.asm` / AY UART server with the current modular Z80 server tree:
  - `boot.asm` startup and IM2 timing setup.
  - `modules/net.asm` transfer state machine and ESP AT handling.
  - `modules/display.asm` rendering and progress UI.
  - `modules/ui.asm` user-facing status screens.
  - `modules/crc.asm` CRC-16/CCITT verification.
  - `modules/esxdos.asm` file, directory, free-space and cleanup helpers.
  - `drivers/divmmc.asm` active divMMC / ZX-Uno UART driver.
- Renamed the release server command from the legacy `bridgezx` naming to the current `brgzx` DOT command.
- Added a real `server/Makefile` with `make all`, `make dot`, and `make clean` targets.
- Added current server release binaries:
  - `server/brgzx`
  - `server/brgzx.bin`
- Preserved the BASIC loader path with updated `BRIDGEZX.BAS` for the raw binary build.
- Removed obsolete files that no longer describe the active hardware path:
  - `server/drivers/ay.asm`
  - `server/modules/wifi.asm`
  - `server/version.asm`

### Protocol And Transfer Flow
- Updated the transfer path to the current LAIN/SnapZX-compatible framing used by the client and server.
- Added robust multi-file batch handling over one TCP connection instead of forcing a reconnect per file.
- Added per-file CRC-16 verification with explicit server ACK before the client advances the queue.
- Kept the 2 MB per-file safety limit and SD free-space validation.
- Hardened parser behavior around malformed `+IPD` lengths and corrupted incoming headers.
- Hardened ESP command/response flow around `CIPSEND`, prompt detection, ACK payload send, and restart after errors.

### Server Reliability And Hardware Hardening
- Fixed the invalid-length parser path so it unwinds the stack correctly instead of leaking a pushed register pair.
- Bounded IP-address copying during server IP discovery so malformed AT responses cannot overflow the fixed `ipAddr` buffer.
- Made IP discovery require the closing quote before accepting the parsed address.
- Bounded the UART startup flush so continuous RX noise or a chatty ESP cannot hang startup forever.
- Updated the active UART read path with the smaller status test used by the newer driver style.
- Removed a redundant branch in the ACK prompt wait path.
- Kept all fixed RAM buffers below esxDOS-sensitive boundaries and preserved DOT size assertions.

### Client Architecture
- Replaced the old `client/code/` layout with the current flat PowerShell module layout:
  - `BRIDGEZX.ps1`
  - `BridgeZX.Config.ps1`
  - `BridgeZX.Files.ps1`
  - `BridgeZX.Network.ps1`
  - `BridgeZX.Resources.ps1`
  - `BridgeZX.State.ps1`
  - `BridgeZX.UI.ps1`
  - `BridgeZX.Utils.ps1`
- Updated `client/build.ps1` so it bundles the current module layout into `BridgeZX_FINAL.ps1` and validates syntax.
- Updated embedded resources and icon handling for the current UI.
- Added `client/CHANGELOG.md` from the active client line.

### Client Features Since The Old Public Release
- Multi-file queue with drag and drop.
- Folder drag and drop.
- Queue reorder support.
- Filename collision handling for 8.3 target names.
- Connection auto-probe with ready/not-ready status.
- Monitoring pause so the ESP/server can be freed for other tools.
- Overall batch progress weighted by payload size.
- ETA and transfer speed display.
- Windows taskbar progress and error state.
- Title-bar progress percentage.
- Completion notification sound.
- Dark owner-drawn UI with clearer queue states.
- Last IP, IP history, last directory, and window position persistence.

### Client Reliability
- The client now advances the queue only after a real server ACK.
- ACK handling now accumulates split TCP reads, so `O` and `K` arriving separately no longer causes a false timeout.
- ACK handling scans all received bytes for `0x06`, not just the first byte.
- Queue size is rejected early when it exceeds the protocol limit of 255 files.
- Pending connection probes are cancelled before a transfer starts, avoiding probe/transfer contention on the ESP server socket.
- Cancel during the final success grace window no longer turns a completed transfer into a cosmetic cancel.
- Config loading now tolerates older `config.json` files under `Set-StrictMode`.
- Post-send ACK timeout is reduced from 120 seconds to 15 seconds, so server-side rejects fail quickly instead of making the UI wait two minutes.

### Documentation And Release Packaging
- Rewrote `README.md` for the current `brgzx` workflow, divMMC/ZX-Uno UART path, and v0.5.x client.
- Rewrote `READMEsp.md` with the same current installation/build instructions in Spanish.
- Rewrote `client/README.md` with the current build/run commands.
- Added `.gitignore` entries for generated build output and local EXE artifacts.
- Published GitHub release assets for the current server and bundled client.

### Verification
- `make all` in `server/`: 0 errors, 0 warnings.
- `powershell -ExecutionPolicy Bypass -File .\client\build.ps1`: `Sintaxis OK`.

## [0.5.1] - 2026-04-15

### Performance
- Removed the client-side artificial send cap and let TCP backpressure set the effective rate.
- Increased transfer chunk size for better throughput on the ESP link.
- Reduced progress/statistics update overhead so transfer code spends less time repainting UI.

### Fixed
- Corrected the optimized CRC path after throughput tuning.
- Unified cleanup on CRC failure, including file deletion and consistent user prompt flow.
- Ignored non-active socket traffic during transfers to avoid cross-stream corruption.

### Server
- Applied safe ASM size reductions under the DOT size limit.

## [0.5.0] - 2026-03-30

### Added
- Overall batch progress.
- ETA based on full queue throughput.
- Windows taskbar progress.
- Title-bar progress.
- Monitoring pause.
- Folder drag and drop.
- Drag-to-reorder queue support.
- Completion sound.

### UI
- Larger file-list font.
- Owner-drawn queue states for sent/current/pending files.
- Reduced flicker in progress and status areas.
- Updated about dialog text for the current hardware support.

### Fixed
- Fixed GDI resource leaks in paint handlers.
- Cleared taskbar progress on exit to avoid stale Explorer state.
- Allowed sending while monitoring is paused.

## [0.4.0] - 2026-03-28

### Added
- Dark themed Windows client.
- Multi-file batch transfer.
- LAIN V2 protocol support.
- Connection auto-probe with visible status indicator.
- Keyboard shortcuts.
- Queue management and remembered window state.
- Per-file 2 MB safety limit.

## [0.1.0] - 2025-12-23

### Added
- Initial public BridgeZX release with esxDOS server, Windows client, CRC-16 verification, direct SD writes, and visual transfer feedback.

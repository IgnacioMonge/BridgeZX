# Changelog

All notable changes to **BridgeZX** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project uses semantic versioning.

## [0.5.2] - 2026-06-20

### Fixed
- Server length parser now unwinds the stack correctly on invalid `+IPD` lengths.
- Server IP discovery now bounds the copied IP string and requires the closing quote.
- UART startup flush now has a byte limit, avoiding a hard lock on noisy RX lines.
- Client ACK handling now accumulates split TCP reads and scans all received bytes for `0x06`.
- Client rejects queues over 255 files before transfer, matching the 1-byte protocol fields.
- Client cancels pending connection probes before starting a transfer.
- Client ignores cancel during the final success grace window.
- Client config loading is safe with older `config.json` files under `StrictMode`.

### Changed
- Removed the obsolete AY UART driver from the server tree.
- Updated the active UART read path with the smaller status test used by the newer driver style.
- Reduced post-send ACK timeout from 120 seconds to 15 seconds.
- Updated docs for the current `brgzx` DOT command, divMMC/ZX-Uno UART path, and v0.5.x client.

## [0.5.1] - 2026-04-15

### Performance
- Removed the client-side send cap and increased transfer chunk size so TCP backpressure sets the effective rate.
- Throttled server/client progress updates to keep more time available for payload reception.

### Fixed
- Corrected the optimized CRC path after throughput tuning.
- Unified cleanup on CRC failure, including file deletion and consistent user prompt flow.
- Ignored non-active socket traffic during transfers to avoid cross-stream corruption.

### Server
- Applied safe ASM size reductions under the DOT size limit.

## [0.5.0] - 2026-03-30

### Added
- Overall batch progress, ETA, taskbar progress, title-bar progress, monitoring pause, folder drag/drop, drag-to-reorder, and completion sound.

### Fixed
- GDI resource leaks in the Windows UI.
- Explorer taskbar progress cleanup on exit.
- Send workflow while monitoring is paused.

## [0.4.0] - 2026-03-28

### Added
- Dark themed Windows client, multi-file batch transfer, LAIN V2 protocol, connection auto-probe, keyboard shortcuts, queue management, remembered window state, and per-file 2 MB limit.

## [0.1.0] - 2025-12-23

### Added
- Initial public BridgeZX release with esxDOS server, Windows client, CRC-16 verification, direct SD writes, and visual transfer feedback.

\# Changelog



All notable changes to the \*\*BridgeZX\*\* project will be documented in this file.



The format is based on \[Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to \[Semantic Versioning](https://semver.org/spec/v2.0.0.html).



\## \[0.1.0] - 2025-12-23

\### 🚀 Initial Release: "The Matrix Bridge"



Welcome to the first public release of \*\*BridgeZX\*\*. This version connects the modern PC world with the classic ZX Spectrum hardware via Wi-Fi, emphasizing stability, ease of use, and visual feedback.



\### 🖥️ Server (ZX Spectrum / Z80)



\#### Added

\- \*\*Dot Command Support (`.bridgezx`)\*\*: Fully integrated into esxDOS. Launch the server directly from BASIC without loading binary blobs manually.

\- \*\*Universal Architecture\*\*: A single codebase (`dot.asm`) now compiles correctly for both `.dot` command mode (address `$2000`) and standard `.bin` mode (address `$8000`).

\- \*\*"The Matrix" Visual Feedback\*\*: The border now flashes with binary noise during data transfer, providing immediate hardware-level feedback that data is flowing.

\- \*\*Smart UI\*\*:

&nbsp;   - \*\*Custom Screen Wiper\*\*: Implemented a raw memory wipe routine (`LDIR` based) that aggressively clears old BASIC listings and attribute artifacts before the UI loads. No more "ghost text" behind the interface.

&nbsp;   - \*\*Progress Bar\*\*: Real-time visualization of the transfer progress.

&nbsp;   - \*\*Traffic Light Status\*\*: Blue (Standby), Green (Receiving/Success), Red (Error).

\- \*\*CRC-16 Verification\*\*: Every packet is checksum-verified. Corrupted transfers are rejected instantly to protect your SD card filesystem.

\- \*\*Safety Limits\*\*: 

&nbsp;   - Automatic check for free disk space via esxDOS syscalls.

&nbsp;   - Hard limit of 2MB per file to prevent memory/storage overflows.



\#### Fixed

\- \*\*The "Infinite Loop" Crash\*\*: Fixed a critical bug where restarting the server after a transfer would hang the system. Implemented a proper Stack Pointer (`SP`) reset at the start of the `recv` loop.

\- \*\*Keyboard Handling\*\*: Replaced the `HALT` instruction in the `WaitKey` routine with an active polling loop to prevent esxDOS from freezing in command mode.

\- \*\*UART Initialization\*\*: Removed conditional compilation (`IFDEF AY`) that was causing the UART to remain silent on some boot configurations. Hardware is now initialized unconditionally.

\- \*\*Screen Artifacts\*\*: Fixed vertical attribute lines appearing during initialization by forcing attribute memory clearing before channel opening.



\### 💻 Client (Windows / PowerShell)



\#### Added

\- \*\*Standalone Executable\*\*: The client is now compiled into a single `.exe` file with zero external dependencies. No need to install Python or run raw scripts.

\- \*\*Embedded Resources\*\*: Application icon and logo are now Base64-encoded and embedded directly into the executable.

\- \*\*Multi-File Queue\*\*: 

&nbsp;   - Support for \*\*Drag \& Drop\*\* files directly into the window.

&nbsp;   - Queue management (Add, Remove, Clear) to send entire game collections in one go.

\- \*\*Smart Auto-Discovery\*\*: The client proactively probes the Spectrum IP.

&nbsp;   - \*\*Grey\*\*: Initializing/Invalid IP.

&nbsp;   - \*\*Yellow\*\*: Port closed / Spectrum unreachable.

&nbsp;   - \*\*Blue\*\*: Port open, but Server not ready (handshake pending).

&nbsp;   - \*\*Green\*\*: Ready to transfer.

\- \*\*Collision Handling\*\*: Automatically renames files (e.g., `GAME.TAP` -> `GAME\_1.TAP`) if a file with the same name already exists in the queue.



\#### Fixed

\- \*\*PS2EXE Pathing Issue\*\*: Fixed a critical crash on startup where `$PSScriptRoot` and `$MyInvocation` returned null values in the compiled EXE context. The build script now injects a runtime environment fix.

\- \*\*Assembly Loading Order\*\*: Resolved a race condition where `Get-AppIcon` attempted to run before `System.Drawing` was loaded into memory.



---

\*Happy Retro-Coding!\*


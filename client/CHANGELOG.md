# BridgeZX Client Changelog

## v0.5.1 (2026-04-15)

### Performance
- **Higher transfer throughput**: removed the client-side send cap, reduced timer granularity, and increased transfer chunk size to better saturate the ESP link
- **Lower UI overhead during transfer**: server-side stats refresh and progress-bar updates are now throttled so the Z80 spends less time repainting and more time consuming payload

### Reliability
- **CRC path fixed after throughput tuning**: corrected the optimized CRC lookup path so completed transfers no longer fail validation spuriously
- **Unified abort cleanup on CRC failure**: CRC errors now reuse the same cleanup path as manual aborts, including file deletion, screen cleanup and consistent "Press any key" flow
- **Safer multi-connection handling**: non-active socket traffic is ignored during a transfer to avoid cross-stream corruption on the ESP side

### Server
- **Smaller DOT binary**: applied safe ASM size reductions in the server transfer path and esxDOS helpers, recovering headroom under the `.dot` size limit

## v0.5.0 (2026-03-30)

### New features
- **Overall batch progress**: progress bar now shows cumulative queue progress weighted by file size, not just current file
- **ETA**: estimated time remaining shown in status bar based on overall transfer speed
- **Taskbar progress**: Windows taskbar button shows green progress bar during transfer (ITaskbarList3 COM API), indeterminate pulse during connect, red on error
- **Title bar progress**: window title shows "BridgeZX 45%" during transfer
- **Monitoring pause**: click the connection indicator to toggle monitoring on/off — stops all TCP probes to the Spectrum, freeing the WiFi module for other apps (SpectalkZX, etc.)
- **Auto-resume**: dropping files or clicking Add while paused automatically resumes monitoring
- **Folder drag & drop**: drag a folder to recursively add all files inside
- **Drag-to-reorder**: drag items within the file list to reorder (4px threshold to avoid accidental drags)
- **Sound notification**: subtle system sound (Asterisk) on successful transfer completion

### UI improvements
- **Larger file list font**: Consolas 9 → Consolas 10
- **Owner-drawn file list** with dark-theme colors:
  - Sent files: green text with ✓ prefix
  - Current file: cyan background, white text
  - Pending files: dimmed text
  - Selection: custom cyan highlight (replaces unreadable system blue)
- **Eliminated flickering**:
  - Double-buffered: status label, status panel, progress bar
  - Update-Statistics throttled to 200ms (was 50ms per tick), only redraws on text change
  - Pre-rendered mosaic header to Bitmap (was 350 GDI brush create/dispose per paint)
- **Connection status cleanup**: transfer summary only shown in status bar, not duplicated in connection area
- **About dialog updated**: description reflects all UART drivers (AY / divMMC / ZX-Uno), copyright 2025-2026

### Bug fixes
- **Fixed GDI resource leak (OutOfMemoryException)**: 5+ Paint handlers were creating Pen/Font/Brush objects per repaint without Dispose. Now uses pre-created shared GDI objects (PenBorder, PenDisabled, FontTitle, FontSub, FontAbout, BrushAccent, BrushDisTxt)
- **Fixed explorer.exe crash**: taskbar progress is now explicitly cleared in FormClosing to prevent orphaned COM state
- **Send works while paused**: monitoring pause doesn't block transfers (Start-SendWorkflow does its own handshake)

## v0.4.0 (2026-03-28)

### Features
- Dark theme UI with Spectrum-colored mosaic header
- Multi-file batch transfer with LAIN V2 protocol
- Connection auto-probe with status indicator
- Keyboard shortcuts (Del, Ctrl+O, Ctrl+Shift+Del)
- Queue reordering (Up/Down buttons, context menu)
- Drag & drop file adding with visual feedback
- Double-click to remove from queue
- Tooltips with full file paths
- Remember last directory + window position
- Auto-clear queue after successful send
- Taskbar flash on completion
- Per-file 2MB size limit
- Single-instance guard
- Custom progress bar (gradient cyan→green)
- Connecting animation (sliding block)
- Transfer summary on completion

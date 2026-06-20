    device ZXSPECTRUM48

    IFDEF DOT
        org #2000
    ELSE
        org #8000          ; 32768 (FAST RAM)
    ENDIF

text
    jp start

    include "modules/display.asm"
    include "boot.asm"
    include "modules/ui.asm"
    include "modules/net.asm"
    include "modules/crc.asm"
    include "modules/util.asm"
    include "modules/esxdos.asm"
    include "drivers/divmmc.asm"

; Uninit RAM buffers (#7E80-#7F8F) — see modules (net/ui/esxdos/display)
; Main receive buffer lives above the stack and below IM2 work RAM.
; Max chunk 14336 = #3800, so #C000-#F7FF stays clear of IM2 (#FC00+).
MAX_CHUNK = #3800
buffer = #C000

; Stack top for reset on abort (below receive buffer)
stack_top = #BFFE

    ASSERT stack_top < buffer, "Stack overlaps receive buffer!"
    ASSERT buffer + MAX_CHUNK <= #FC00, "Receive buffer overlaps IM2 area!"
    ASSERT EsxDOS.dir_buffer + EsxDOS.DIR_BUFFER_SIZE <= Display.glyph_buf, "dir_buffer overlaps #7F00 scratch!"
    ASSERT $ <= buffer, "Code overlaps receive buffer! Current: ", $

    IFDEF DOT
        ASSERT $ <= #3C00, "DOT command exceeds #3C00 limit! Current: ", $
        savebin "brgzx", text, $ - text
    ELSE
        savebin "brgzx.bin", text, $ - text
    ENDIF

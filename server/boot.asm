; ============================================
; BOOT — Entry point and visual banner
; Ported from NetManZX
; ============================================

msg_banner:
    db "BridgeZX v1.1 - File Server", 0
msg_copyright:
    db "(C) M. Ignacio Monge Garcia 2026", 0

start:
    ld sp, stack_top

    ; ========================================
    ; LIMPIEZA DE HANDLES COLGADOS
    ; Cierra handles 0-15 para evitar "Wrong file type"
    ; tras salir con NMI/reset DURANTE una transferencia
    ; ========================================
    ld b, 16
.close_handles:
    push bc
    ld a, b
    dec a               ; Handle 0-15
    rst #08
    db #9B              ; ESX_FCLOSE (ignoramos errores)
    pop bc
    djnz .close_handles

    call Display.clrscr
    call Wifi.setup_im2

    ; Double-height banner: rows 0-1
    setLineColor 0, Display.ATTR_BANNER_TOP
    setLineColor 1, Display.ATTR_BANNER_BOT
    gotoXY 0, 0
    printMsg msg_banner
    call Display.stretchRows01
    call drawBadge
    call drawSeparator

    call Display.drawStatusSeparator

    ; Copyright on rows 3-4 in DH (BRIGHT top, no BRIGHT bottom)
    ld a, 3 : ld c, #47 : call Display.setDhAttrPair
    call Display.dhOn
    gotoXY 0, 3
    printMsg msg_copyright
    call Display.dhOff

    ; Init messages in DH on rows 5-6 (each overwrites the previous)
    call showInitMsg
    db "Initializing UART...", 0
    call Uart.init

    call showInitMsg
    db "Initializing Wi-Fi...", 0
    call Wifi.init

    ; Record wait_row (one row below the green IP separator line)
    ld a, (Display.coords+1)
    inc a
    ld (Wifi.wait_row), a

    ei
    jp Wifi.recv

; ============================================
; Badge + separator (ported from NetManZX)
; ============================================

; SpectalkZX-style badge: dithered triangle with color transitions
; Row 0 (top): 4 cells at bytes 28-31 (staggered)
; Row 1 (bot): 5 cells at bytes 27-31 (full)
badge_pattern:
    db #00, #01, #03, #07, #0F, #1F, #3F, #7F

drawBadge:
    ; Pixels: row 0, 4 cells at bytes 28-31
    ld hl, #401C            ; Row 0, scanline 0, byte 28
    ld c, 4
    call .drawCells
    ; Pixels: row 1, 5 cells at bytes 27-31
    ld hl, #403B            ; Row 1, scanline 0, byte 27
    ld c, 5
    call .drawCells
    ; Attributes row 0 (top): 4 cells BRIGHT
    ld hl, #581C            ; Row 0, cell 28
    ld (hl), 01000010b      ; P=black I=red BRIGHT
    inc hl
    ld (hl), 01010110b      ; P=red I=yellow BRIGHT
    inc hl
    ld (hl), 01110100b      ; P=yellow I=green BRIGHT
    inc hl
    ld (hl), 01100001b      ; P=green I=blue BRIGHT
    ; Attributes row 1 (bot): 5 cells BRIGHT
    ld hl, #583B            ; Row 1, cell 27
    ld (hl), 01000010b      ; P=black I=red BRIGHT
    inc hl
    ld (hl), 01010110b      ; P=red I=yellow BRIGHT
    inc hl
    ld (hl), 01110100b      ; P=yellow I=green BRIGHT
    inc hl
    ld (hl), 01100001b      ; P=green I=blue BRIGHT
    inc hl
    ld (hl), 01001000b      ; P=blue I=black BRIGHT
    ret

; Draw triangular dither pattern in C consecutive cells
; Input: HL = screen address (scanline 0), C = number of cells
.drawCells:
    ld de, badge_pattern
    ld b, 8
.scanLoop:
    push bc
    push hl
    ld a, (de)
    ld b, c                 ; B = number of cells
.byteLoop:
    ld (hl), a
    inc l
    djnz .byteLoop
    pop hl
    inc h                   ; next scanline
    inc de
    pop bc
    djnz .scanLoop
    ret

; Show init message in DH on rows 6-7, clearing previous
; String follows the CALL inline (null-terminated)
showInitMsg:
    pop hl                      ; HL = return address = start of string
    ; Clear rows 6-7
    push hl
    ld a, 6 : call Wifi.clearRowA
    ld a, 7 : call Wifi.clearRowA
    ; Set attrs for DH
    ld a, 6 : ld c, #47 : call Display.setDhAttrPair
    ; Print in DH mode
    call Display.dhOn
    gotoXY 0, 6
    pop hl                      ; HL = string
    call Display.putStr         ; print DH text, HL advances past null
    call Display.dhOff
    jp (hl)                     ; "return" to address after the string

; White 1px separator line below banner (row 2, scanline 0)
drawSeparator:
    ld a, 2
    ld e, 0
    jp Display.draw_hline_only

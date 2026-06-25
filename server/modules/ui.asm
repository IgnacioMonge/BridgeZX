    module Wifi

; =============================================================================
; CONSTANTES Y HELPERS DE COLOR
; =============================================================================
; setInk - set INK color. A = color (0-7). inkWhite = shortcut for A=7
inkWhite:
    ld a, 7
setInk:
    ld c, a
    ld a, (Display.currentAttr)
    and #F8
    or c
    ld (Display.currentAttr), a
    ret

; =============================================================================
; HELPERS DE IMPRESIÓN
; =============================================================================
; putCR - print carriage return
putCR:
    ld a, 13
    jp Display.putC

putSpace:
    ld a, ' '
    jp Display.putC

setWaitOffsetPos:
    ld d, a
    ld a, (wait_row)
    add a, d
    ld d, a
    ld e, 0
    jp Display.setPos

setWaitOffsetDhAttr:
    ld d, a
    ld a, (wait_row)
    add a, d
    jp Display.setDhAttrPair

; clearLine42 - Print 42 spaces
clearLine42:
    ld b, 42
.clr: push bc : call putSpace : pop bc : djnz .clr
    ret

; clearRowA - Set col=0 + clear 42-col row. Input: A = row
clearRowA:
    ld (Display.coords+1), a
    xor a : ld (Display.coords), a
    jr clearLine42

; DrawSeparatorLine - Dibuja línea de 1px a lo ancho de toda la pantalla
DrawSeparatorLine:
    ; If column > 0, force CR to avoid overwriting text
    ld hl, Display.coords
    ld a, (hl) : or a : jr z, .draw_start
    xor a : ld (hl), a : inc hl : inc (hl)
.draw_start:
    ld a, (Display.coords+1)
    ; Set row attr to current color
    push af
    ld a, (Display.currentAttr) : ld c, a
    pop af : push af
    call Display.setAttr
    ; Draw 1px line using existing routine (scanline 4)
    pop af
    ld e, 4
    call Display.draw_hline_only
    ; Advance cursor: col=0, row+1
    ld hl, Display.coords
    xor a : ld (hl), a : inc hl : inc (hl)
    ret

; =============================================================================
; STATUS BAR
; =============================================================================
ATTR_STATUS_NEUTRAL = #47
ATTR_STATUS_OK      = #44
ATTR_STATUS_FAIL    = #42

msg_status_waiting:  db "Waiting...", 0
msg_status_xfer:     db "Receiving...", 0
msg_status_ok:       db "Complete", 0
msg_status_fail:     db "Aborted", 0

showStatusFail:
    ld hl, msg_status_fail
    ld c, ATTR_STATUS_FAIL
    jp Display.showStatus

showStatusOk:
    ld hl, msg_status_ok
    ld c, ATTR_STATUS_OK
    jp Display.showStatus

; =============================================================================
; BARRA DE PROGRESO (Estilo [|||||     ])
; =============================================================================
BAR_BLOCKS = 40
BAR_STEP_BASE = #0666         ; floor(65536 / 40)

DrawEmptyBar:
    ld a, 2 : call setWaitOffsetPos
    ld a, '[' : call Display.putC
    ld b, 40
.empty_loop:
    push bc
    call putSpace
    pop bc
    djnz .empty_loop
    ld a, ']' : call Display.putC
    ; Sync to frame, then attrs + stretch atomically
    ei : halt : di
    call setBarAttrs
    ld a, (wait_row) : add a, 2
    jp Display.stretchRow

ClearProgressBar:
    ld a, 2 : call setWaitOffsetPos
    call clearLine42
    ld a, 3 : call setWaitOffsetPos
    jp clearLine42

; Set bar row attributes: top=yellow no BRIGHT, bottom=yellow BRIGHT
setBarAttrs:
    ld a, (wait_row)
    add a, 2
    push af
    ld c, #46 : call Display.setAttr
    pop af : inc a
    ld c, #06 : jp Display.setAttr

; =============================================================================
; BARRA DE PROGRESO (NORMALIZACIÓN ITERATIVA + DIBUJADO INCREMENTAL)
; =============================================================================
UpdateProgressBar:
    ; 1. Cargar valores 32 bits en variables temporales
    ld hl, (total_size_lo) : ld (calc_total_lo), hl
    ld hl, (total_size_hi) : ld (calc_total_hi), hl
    ld hl, (done_lo) : ld (calc_done_lo), hl
    ld hl, (done_hi) : ld (calc_done_hi), hl

    ; 2. Normalización
.normalize_loop:
    ld hl, (calc_total_hi)
    ld a, h : or l : jr nz, .do_shift
    ld hl, (calc_total_lo)
    ld a, h : cp 6 : jr c, .calc_now

.do_shift:
    ld hl, calc_total_hi + 1 : call ShiftRightOnce32
    ld hl, calc_done_hi + 1  : call ShiftRightOnce32
    jr .normalize_loop

.calc_now:
    ld bc, (calc_total_lo)
    ld hl, (calc_done_lo)
    ld a, b : or c : ret z

    ; (Done * 40) / Total
    ld d, h : ld e, l
    add hl, hl : add hl, hl : add hl, hl
    push hl
    add hl, hl : add hl, hl
    pop de : add hl, de

    call Div16
    ld a, l : cp 41 : jr c, .limit_ok
    ld a, 40
.limit_ok:

    ; Incremental: only draw new blocks (delta)
    ld hl, last_bar_blocks
    ld c, (hl)          ; C = blocks already drawn
    cp c
    ret z               ; No change

    ld (hl), a           ; Save new count
    sub c                ; A = number of new blocks
    ret z
    ld b, a              ; B = delta count

    ; First new column = old_count + 1
    ld a, c : inc a

.draw_delta:
    push af : push bc

    ; Top row (wait_row+3) — pixels only, no attrs
    ld (Display.coords), a
    ld a, (wait_row) : add a, 2 : ld (Display.coords+1), a
    ld a, 127 : call Display.drawCharPixelsOnly

    pop bc : pop af : push af : push bc

    ; Bottom row (wait_row+4) — pixels only, no attrs
    ld a, (wait_row) : add a, 3 : ld (Display.coords+1), a
    ld a, 127 : call Display.drawCharPixelsOnly

    pop bc : pop af
    inc a
    djnz .draw_delta
    ret

InitProgressGate:
    xor a
    ld (last_bar_blocks), a
    ld bc, (total_size_hi)
    push bc
    ld h, a : ld l, a
.ipg_qbase:
    ld a, b : or c : jr z, .ipg_qdone
    ld de, BAR_STEP_BASE
    add hl, de
    dec bc
    jr .ipg_qbase
.ipg_qdone:
    ld (bar_step), hl
    pop bc
    ld hl, (total_size_lo)
    ld a, 16
    ld de, (total_size_hi)
.ipg_sum:
    add hl, de
    jr nc, .ipg_no_carry
    ld b, 1
.ipg_no_carry:
    dec a
    jr nz, .ipg_sum
    ld a, b
    or a
    jr z, .ipg_div
    push hl
    ld hl, (bar_step)
    ld de, BAR_STEP_BASE
    add hl, de
    ld (bar_step), hl
    pop hl
    ld de, 16
    add hl, de
.ipg_div:
    ld a, h
    or a
    jr nz, .ipg_sub
    ld a, l
    cp BAR_BLOCKS
    jr c, .ipg_round
.ipg_sub:
    ld de, BAR_BLOCKS
    or a
    sbc hl, de
    push hl
    ld hl, (bar_step)
    inc hl
    ld (bar_step), hl
    pop hl
    jr .ipg_div
.ipg_round:
    ld a, h
    or l
    ld hl, (bar_step)
    jr z, .ipg_store
    inc hl
.ipg_store:
    ld a, h : or l : jr nz, .ipg_keep
    inc hl
.ipg_keep:
    ld (bar_step), hl
    ld (bar_countdown), hl
    ret

MaybeUpdateProgressBar:
    ld hl, (bar_countdown)
    or a
    sbc hl, bc
    ld (bar_countdown), hl
    ret nc
    call UpdateProgressBar
    ld hl, (bar_countdown)
    ld de, (bar_step)
.mup_add:
    add hl, de
    ld (bar_countdown), hl
    ld a, d
    bit 7, a
    ret nz
    bit 7, h
    jr nz, .mup_add
    ret

; =============================================================================
; TRANSFER INFO (Done% / KB/s / ETA)
; =============================================================================
INFOLINE_ROW = 18
INFO_TICK_STEP = 50           ; refresh KB/s + ETA about once per second

MaybeUpdateTransferInfo:
    call ReadIm2Ticks
    ld de, (last_info_ticks)
    push hl
    or a
    sbc hl, de
    ld a, h
    or a
    jr nz, .muti_update
    ld a, l
    cp INFO_TICK_STEP
    jr c, .muti_skip
.muti_update:
    pop hl
    ld (last_info_ticks), hl
    jr UpdateTransferInfo
.muti_skip:
    pop hl
    ret

; DrawInfoBarLabels - paint fixed labels "Done:   %      KB/s  ETA:     "
; Called once at transfer start. Values updated by UpdateTransferInfo.
; Layout (42 cols): col4=Done: col16=KB/s col27=ETA:
DrawInfoBarLabels:
    ld a, INFOLINE_ROW : ld c, #45 : call Display.setDhAttrPair
    call Display.dhOn
    ld a, 5 : call setInk
    gotoXY 4, INFOLINE_ROW
    printMsg msg_ti_done            ; "Done:"
    gotoXY 20, INFOLINE_ROW
    printMsg msg_ti_kbs             ; "KB/s"
    gotoXY 28, INFOLINE_ROW
    printMsg msg_ti_eta             ; "ETA:"
    call Display.dhOff
    jp inkWhite

; UpdateTransferInfo - update values at fixed positions
UpdateTransferInfo:
    ld bc, (calc_total_lo)
    ld a, b : or c : ret z
    ld hl, (calc_done_lo)
    ; Normalize for *100
.ti_norm:
    ld a, b : or a : jr z, .ti_normed
    srl b : rr c : srl h : rr l
    jr .ti_norm
.ti_normed:
    push bc
    ld d, h : ld e, l
    add hl, hl : add hl, hl
    push hl
    add hl, hl : add hl, hl : add hl, hl
    push hl : add hl, hl
    pop de : add hl, de
    pop de : add hl, de
    pop bc
    call Div16
    ld a, l : cp 101 : jr c, .ti_ok
    ld a, 100
.ti_ok:
    ld (.ti_pct), a
    ; Enable DH + cyan
    call Display.dhOn
    ld a, 5 : call setInk
    ; --- Done:XXX% at col 9 ---
    gotoXY 9, INFOLINE_ROW
    ld a, 0
.ti_pct = $ - 1
    call PrintByteDec
    ld a, '%' : call Display.putC
    ; Pad to col 14 (covers 100% case)
    call putSpace
    ; --- Speed at col 16 ---
    call ReadIm2Ticks
    ld de, (xfer_start_frames)
    or a : sbc hl, de
    ld a, h : or a : jr nz, .ti_have_time
    ld a, l : cp 50 : jp c, .ti_noEta
.ti_have_time:
    push hl                          ; [stack: ticks]
    gotoXY 16, INFOLINE_ROW
    ld hl, (done_lo) : ld de, (done_hi)
    ld b, 10 : call ShiftRightN_32
    ld (.saved_kb), hl
    push hl
    add hl, hl : add hl, hl : add hl, hl
    push hl : add hl, hl
    pop de : add hl, de
    pop de : add hl, de              ; *25
    pop bc : push bc                 ; peek ticks
    srl b : rr c
    call Div16                       ; HL=int, DE=rem
    push bc : push de
    call PrintU16Dec
    ld a, '.' : call Display.putC
    pop hl
    add hl, hl : ld d, h : ld e, l
    add hl, hl : add hl, hl : add hl, de
    pop bc : call Div16
    call PrintU16Dec
    ; --- ETA at col 32 ---
    pop hl                           ; ticks
    ld bc, 50 : call Div16           ; HL = elapsed_secs
    ld a, h : or l : jr z, .ti_noEta
    push hl
    ld hl, (total_size_lo) : ld de, (total_size_hi)
    ld b, 10 : call ShiftRightN_32
    ld de, 0
.saved_kb = $ - 2
    or a : sbc hl, de
    pop de
    ld b, d : ld c, e
    ld a, h : or l : jr z, .ti_noEta
    ld a, b : or c : jr z, .ti_noEta
.eta_norm:
    ld a, h : or b : jr z, .eta_calc
    srl h : rr l
    srl b : rr c
    jr .eta_norm
.eta_calc:
    ld d, h : ld e, l
    ld hl, 0
    ld a, c : or a : jr z, .ti_noEta
.eta_mul:
    add hl, de : dec a : jr nz, .eta_mul
    ld bc, (.saved_kb)
    ld a, b : or c : jr z, .ti_noEta
    call Div16                       ; HL = eta_seconds
    push hl
    gotoXY 32, INFOLINE_ROW
    pop hl
    ld bc, 60 : call Div16
    push de
    ld a, l : call PrintByteDec
    ld a, 'm' : call Display.putC
    pop de
    ld a, e : call PrintByteDec
    ld a, 's' : call Display.putC
    call putSpace                    ; clear trailing char
.ti_noEta:
    call inkWhite
    jp Display.dhOff

msg_ti_done: db "Done:", 0
msg_ti_kbs:  db "KB/s", 0
msg_ti_eta:  db "ETA:", 0
msg_ti_kb:   db " KB", 0
msg_ti_mb:   db " MB", 0

; =============================================================================
; TECLADO
; =============================================================================
WaitKey:
    ei
.wk_wait_release:
    ; Esperar a que no haya teclas pulsadas
    xor a
    in a, (#fe)         ; Leer todas las filas (A=0 selecciona todas)
    or #E0              ; Ignorar bits 5-7 (no son teclado)
    inc a               ; Si era #FF (nada pulsado), ahora es 0
    jr nz, .wk_wait_release

.wk_wait_press:
    xor a
    in a, (#fe)
    or #E0
    inc a
    jr z, .wk_wait_press  ; Esperar hasta que se pulse algo

    ; Debounce
    ld b, 10
.wk_debounce:
    halt
    djnz .wk_debounce
    ret

; showPressKey - centered yellow DH on rows 19-20
showPressKey:
    ld a, 6 : call setInk
    ld a, 19 : ld c, #46 : call Display.setDhAttrPair
    call Display.dhOn
    gotoXY 14, 19
    ld hl, msg_press_key : call Display.putStr
    call Display.dhOff
    jp inkWhite

msg_press_key: db "Press any key", 0

; =============================================================================
; UI RESET + TEXTOS COMUNES
; =============================================================================
Wifi_UiResetToWaiting:
    ld a, (wait_row) : cp 8 : jr nc, .row_ok : ld a, 8
.row_ok:
    ld d, a
    call inkWhite

    ; Clear pixels + attributes from wait_row to row 20
.clear_loop:
    ld a, d
    cp 21
    jr nc, .done

    push de
    ld c, #47 : call Display.setAttr
    pop de
    push de
    ld e, 0 : call Display.findAddr
    ex de, hl
    call Display.clearRow
    pop de

    inc d
    jr .clear_loop

.done:
    ld hl, msg_status_waiting : ld c, ATTR_STATUS_NEUTRAL : jp Display.showStatus

msg_listening: db "Listening: ", 0
msg_port_txt:  db ":6144", 0
msg_filename:  db "File: ", 0
msg_files_xferd: db " file(s) done", 0
msg_total_txt: db "Total: ", 0

; =============================================================================
; Variables de UI (las de recv_zero_start viven en net.asm — LDIR las pone a 0)
; =============================================================================
calc_total_lo: dw 0
calc_total_hi: dw 0
calc_done_lo:  dw 0
calc_done_hi:  dw 0
xfer_start_frames: dw 0
fname_end_pos: dw 0

    endmodule

    module Wifi

; =============================================================================
; IMPRESIÓN DECIMAL / HEX
; =============================================================================
PrintU32Dec:
    ld (dec_val_lo), hl
    ld (dec_val_hi), de
    xor a
    ld (dec_printed), a
    ld hl, .pow10_table
    ld b, 6
.pu_loop:
    push bc
    ld e, (hl) : inc hl
    ld d, (hl) : inc hl
    ld c, (hl) : inc hl
    ld b, (hl) : inc hl
    push hl
    call DigitSubPrint
    pop hl
    pop bc
    djnz .pu_loop
    ld de, 1
    ld b, d : ld c, d
    jr DigitSubPrintLast
.pow10_table:
    dw #4240, #000F    ; 1,000,000
    dw #86A0, #0001    ; 100,000
    dw #2710, #0000    ; 10,000
    dw #03E8, #0000    ; 1,000
    dw #0064, #0000    ; 100
    dw #000A, #0000    ; 10

PrintByteDec:
    ld l, a : ld h, 0 : jr PrintU16Dec

PrintU16Dec:
    xor a : ld d, a : ld e, a : jr PrintU32Dec

DigitSubPrint:
    xor a
.dsp_loop:
    ld hl, (dec_val_hi) : or a : sbc hl, bc : jr c, .dsp_done : jr nz, .dsp_ge
    ld hl, (dec_val_lo) : or a : sbc hl, de : jr c, .dsp_done
.dsp_ge:
    ld hl, (dec_val_lo) : or a : sbc hl, de : ld (dec_val_lo), hl
    ld hl, (dec_val_hi) : sbc hl, bc : ld (dec_val_hi), hl
    inc a : jr .dsp_loop
.dsp_done:
    ld d, a : ld a, (dec_printed) : or a : jr nz, .dsp_print
    ld a, d : or a : ret z
.dsp_print:
    ld a, 1 : ld (dec_printed), a : ld a, d : add a, '0' : jp Display.putC

DigitSubPrintLast:
    call DigitSubPrint
    ld a, (dec_printed) : or a : ret nz
    ld a, '0' : jp Display.putC

; =============================================================================
; ARITMÉTICA 16/32 BITS
; =============================================================================
; División 16 bits: HL / BC -> HL (Cociente en HL, Resto en DE)
Div16:
    ld de, 0
    ld a, 16
.div_loop:
    add hl, hl
    ex de, hl
    adc hl, hl

    or a
    sbc hl, bc
    jr nc, .div_sub_ok

    add hl, bc
    ex de, hl
    jr .div_next

.div_sub_ok:
    ex de, hl
    inc l

.div_next:
    dec a
    jr nz, .div_loop
    ret

; Shift right 32 bits (DEHL) B veces
ShiftRightN_32:
.srn_loop:
    ld a, b
    or a
    ret z
    srl d
    rr  e
    rr  h
    rr  l
    dec b
    jr .srn_loop

; Shift right 32 bits 1 vez. HL apunta al byte más alto+1.
ShiftRightOnce32:
    srl (hl) : dec hl       ; Byte 3
    rr (hl)  : dec hl       ; Byte 2
    rr (hl)  : dec hl       ; Byte 1
    rr (hl)                 ; Byte 0
    ret

; =============================================================================
; ACUMULADOR DE BYTES DE SESIÓN (32 bits)
; =============================================================================
AddSessionBytes:
    ; Suma HL:DE a session_bytes (32 bits)
    ld bc, (session_bytes_lo)
    add hl, bc
    ld (session_bytes_lo), hl
    ex de, hl
    ld bc, (session_bytes_hi)
    adc hl, bc
    ld (session_bytes_hi), hl
    ret

PrintSessionStats:
    ld hl, (session_bytes_lo) : ld de, (session_bytes_hi)
    call PrintU32Dec
    call putSpace
    ld hl, msg_bytes : jp Display.putStr

msg_bytes: db "Bytes", 0

session_bytes_lo: dw 0
session_bytes_hi: dw 0

; =============================================================================
; BEEPS
; =============================================================================
BeepError:
    ld hl, #0300 : ld de, #0100 : jr BeepTone

BeepSuccess:
    ld hl, #0100 : ld de, #0030 : call BeepTone
    ld hl, #0080
.pause1:
    dec hl : ld a, h : or l : jr nz, .pause1
    ld hl, #0100 : ld de, #0020 : jr BeepTone

BeepTone:
    push bc : di
.beep_loop:
    xor a : out (#fe), a : ld b, e
.delay1:
    djnz .delay1
    ld a, #10 : out (#fe), a : ld b, e
.delay2:
    djnz .delay2
    dec hl : ld a, h : or l : jr nz, .beep_loop
    ei : pop bc : ret

; =============================================================================
; Variables en RAM no inicializada (#7F80+)
; =============================================================================
dec_printed  = #7F80   ; 1 byte
dec_val_lo   = #7F82   ; 2 bytes
dec_val_hi   = #7F84   ; 2 bytes

    endmodule

    module Wifi

; =============================================================================
; CRC-16-CCITT bitwise update (smaller than table lookup)
; Input: HL = buffer ptr, BC = byte count
; State: (crc_cur) updated
; =============================================================================
CrcUpdateBuf:
    ld de, (crc_cur)
.loop_main:
    ld a, b : or c : jr z, .save_and_exit
    ld a, (hl)
    inc hl
    dec bc
    xor d                       ; crc ^= byte << 8
    ld d, a
    push hl
    push bc
    ld b, 8
.bit_loop:
    sla e
    rl d
    jr nc, .no_xor
    ld a, d : xor #10 : ld d, a
    ld a, e : xor #21 : ld e, a
.no_xor:
    djnz .bit_loop
    pop bc
    pop hl
    jr .loop_main
.save_and_exit:
    ld (crc_cur), de
    ret


; Verifica si el CRC calculado coincide con el esperado
; Salida: Carry Set (C=1) si ERROR. Carry Clear (C=0) si OK.
CrcVerify:
    ld hl, (crc_cur)
    ld de, (expected_crc)
    or a
    sbc hl, de
    ret z           ; Si Z=1 (son iguales), retorna con C=0 (OK)

    scf             ; Si no son iguales, fuerza Carry=1
    ret             ; Retorna con C=1 (Error)


PrintCrcOverwriteOk:
    ld a, 4
    ld de, msg_crc_ok_spc
    jr PrintCrcOverwrite

PrintCrcOverwriteBad:
    ld a, 2
    ld de, msg_crc_bad_spc

PrintCrcOverwrite:
    call setInk
    ld hl, (fname_end_pos) : ld (Display.coords), hl
    ex de, hl
    call Display.putStrDH
    jp inkWhite

msg_crc_ok_spc: db "OK", 0
msg_crc_bad_spc: db "FAIL", 0

; Variables en RAM no inicializada
expected_crc = #7F86   ; 2 bytes
crc_cur      = #7F88   ; 2 bytes

    endmodule

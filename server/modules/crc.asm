    module Wifi

; =============================================================================
; CRC-16-CCITT BYTE LOOKUP (uses shadow registers for tight inner loop)
; Input: HL = buffer ptr, BC = byte count
; State: (crc_cur) updated
; =============================================================================
CrcUpdateBuf:
    exx
    ld de, (crc_cur)
.loop_main:
    exx
    ld a, b : or c : jr z, .save_and_exit
    ld a, (hl)
    inc hl
    dec bc
    exx
    xor d                       ; (crc>>8) ^ byte
    ld l, a
    ld h, 0
    add hl, hl                  ; index * 2
    ld bc, crc_byte_table
    add hl, bc
    ld c, e                     ; save crc low
    ld e, (hl)
    inc hl
    ld a, (hl)
    xor c                       ; combine with shifted crc low
    ld d, a
    jr .loop_main
.save_and_exit:
    exx
    ld (crc_cur), de
    exx
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

; CRC-16-CCITT byte table (256 entries × 2 bytes = 512 bytes)
crc_byte_table:
    dw #0000, #1021, #2042, #3063, #4084, #50A5, #60C6, #70E7
    dw #8108, #9129, #A14A, #B16B, #C18C, #D1AD, #E1CE, #F1EF
    dw #1231, #0210, #3273, #2252, #52B5, #4294, #72F7, #62D6
    dw #9339, #8318, #B37B, #A35A, #D3BD, #C39C, #F3FF, #E3DE
    dw #2462, #3443, #0420, #1401, #64E6, #74C7, #44A4, #5485
    dw #A56A, #B54B, #8528, #9509, #E5EE, #F5CF, #C5AC, #D58D
    dw #3653, #2672, #1611, #0630, #76D7, #66F6, #5695, #46B4
    dw #B75B, #A77A, #9719, #8738, #F7DF, #E7FE, #D79D, #C7BC
    dw #48C4, #58E5, #6886, #78A7, #0840, #1861, #2802, #3823
    dw #C9CC, #D9ED, #E98E, #F9AF, #8948, #9969, #A90A, #B92B
    dw #5AF5, #4AD4, #7AB7, #6A96, #1A71, #0A50, #3A33, #2A12
    dw #DBFD, #CBDC, #FBBF, #EB9E, #9B79, #8B58, #BB3B, #AB1A
    dw #6CA6, #7C87, #4CE4, #5CC5, #2C22, #3C03, #0C60, #1C41
    dw #EDAE, #FD8F, #CDEC, #DDCD, #AD2A, #BD0B, #8D68, #9D49
    dw #7E97, #6EB6, #5ED5, #4EF4, #3E13, #2E32, #1E51, #0E70
    dw #FF9F, #EFBE, #DFDD, #CFFC, #BF1B, #AF3A, #9F59, #8F78
    dw #9188, #81A9, #B1CA, #A1EB, #D10C, #C12D, #F14E, #E16F
    dw #1080, #00A1, #30C2, #20E3, #5004, #4025, #7046, #6067
    dw #83B9, #9398, #A3FB, #B3DA, #C33D, #D31C, #E37F, #F35E
    dw #02B1, #1290, #22F3, #32D2, #4235, #5214, #6277, #7256
    dw #B5EA, #A5CB, #95A8, #8589, #F56E, #E54F, #D52C, #C50D
    dw #34E2, #24C3, #14A0, #0481, #7466, #6447, #5424, #4405
    dw #A7DB, #B7FA, #8799, #97B8, #E75F, #F77E, #C71D, #D73C
    dw #26D3, #36F2, #0691, #16B0, #6657, #7676, #4615, #5634
    dw #D94C, #C96D, #F90E, #E92F, #99C8, #89E9, #B98A, #A9AB
    dw #5844, #4865, #7806, #6827, #18C0, #08E1, #3882, #28A3
    dw #CB7D, #DB5C, #EB3F, #FB1E, #8BF9, #9BD8, #ABBB, #BB9A
    dw #4A75, #5A54, #6A37, #7A16, #0AF1, #1AD0, #2AB3, #3A92
    dw #FD2E, #ED0F, #DD6C, #CD4D, #BDAA, #AD8B, #9DE8, #8DC9
    dw #7C26, #6C07, #5C64, #4C45, #3CA2, #2C83, #1CE0, #0CC1
    dw #EF1F, #FF3E, #CF5D, #DF7C, #AF9B, #BFBA, #8FD9, #9FF8
    dw #6E17, #7E36, #4E55, #5E74, #2E93, #3EB2, #0ED1, #1EF0

; Variables en RAM no inicializada
expected_crc = #7F86   ; 2 bytes
crc_cur      = #7F88   ; 2 bytes

    endmodule

    module Display

putStr:
    ld a, (hl) : and a : ret z
    push hl
    rst #10
    pop hl
    inc hl
    jr putStr

; Set print position using ROM control code AT.
; In: D=row (0..23), E=col (0..31)
setPos:
    ld a, 22 : rst #10
    ld a, d  : rst #10
    ld a, e  : rst #10
    ret

; Define UDGs for UI elements
; Uses system variable UDG at 23675.
; Define UDGs for UI elements
initBarChars:
    ld hl, (23675)      ; UDG base address

    ; UDG 'A' (CHR$144): ESTILO BATERÍA (Barra centrada)
    ld b, 8
    ld a, #3C           ; 00111100 (Deja hueco a los lados)
.aLoop:
    ld (hl), a
    inc hl
    djnz .aLoop

    ; UDG 'B' (CHR$145): Left Bracket [
    ld a, #1C : ld (hl), a : inc hl 
    ld a, #10 : ld (hl), a : inc hl 
    ld (hl), a : inc hl             
    ld (hl), a : inc hl             
    ld (hl), a : inc hl             
    ld (hl), a : inc hl             
    ld (hl), a : inc hl             
    ld a, #1C : ld (hl), a : inc hl 

    ; UDG 'C' (CHR$146): Right Bracket ]
    ld a, #38 : ld (hl), a : inc hl 
    ld a, #08 : ld (hl), a : inc hl 
    ld (hl), a : inc hl             
    ld (hl), a : inc hl             
    ld (hl), a : inc hl             
    ld (hl), a : inc hl             
    ld (hl), a : inc hl             
    ld a, #38 : ld (hl), a : inc hl 

    ; UDG 'D' (CHR$147): Thin horizontal line
    xor a           
    ld (hl), a : inc hl
    ld (hl), a : inc hl
    ld (hl), a : inc hl
    ld a, #FF       
    ld (hl), a : inc hl
    ld (hl), a : inc hl
    xor a           
    ld (hl), a : inc hl
    ld (hl), a : inc hl
    ld (hl), a : inc hl

    ret

    endmodule

    macro printMsg ptr
    ld hl, ptr : call Display.putStr
    endm
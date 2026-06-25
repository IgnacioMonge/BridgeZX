    module Display

; ============================================
; 6px custom font display engine (42 columns)
; Ported from NetManZX
; No ROM usage — all direct VRAM writes
; ============================================

; Color attribute constants for banner
ATTR_BANNER_TOP  = 01000111b  ; White on black, BRIGHT (top)
ATTR_BANNER_BOT  = 00000111b  ; White on black, no BRIGHT (bottom)

; Current ink attribute for character rendering
; Updated by INK control codes in putStr
currentAttr: db #47          ; Default: bright white on black

; Cursor position: low=col(0-41), high=row(0-23)
coords: dw 0
dh_mode: db 0               ; 0=normal, 1=double-height rendering

; ============================================
; setAttr - Set attribute for entire row
; Input: A = row (0-23), C = attribute byte
; Destroys: AF, BC, DE, HL
; ============================================
setAttr:
    rrca
    rrca
    rrca
    ld l, a
    and 31
    or #58
    ld h, a
    ld a, l
    and 252
    ld l, a
    ld de, hl
    inc de
    ld a, c : ld (hl), a
    ld bc, #1f
    ldir
    ret

; ============================================
; setDhAttrPair - Set DH attribute on row A and row A+1
; Input: A = top row, C = attribute byte (with BRIGHT bit 6 set)
;        Top row gets attr as-is, bottom row gets bit 6 cleared (no BRIGHT)
; Destroys: AF, BC, DE, HL
; ============================================
setDhAttrPair:
    push af
    push bc
    call setAttr
    pop bc
    pop af
    inc a
    res 6, c
    jr setAttr

; ============================================
; setPos - Set cursor position
; Input: D = row (0-23), E = col (0-41)
; ============================================
setPos:
    ld a, e
    ld (coords), a
    ld a, d
    ld (coords+1), a
    ret

; ============================================
; putStr - Print zero-terminated string
; Handles INK control code (16,n) for compatibility with wifi.asm messages
; Input: HL = pointer to zero-terminated string
; ============================================
putStr:
    ld a, (hl) : inc hl : and a : ret z
    cp 32 : jr nc, .isChar       ; >= 32 = printable
    cp 13 : jr z, .isChar
    cp 16 : jr z, .handleINK
    jr putStr                    ; unsupported controls: ignore byte
.isChar:
    push hl
    call putC
    pop hl : jr putStr
.handleINK:
    ld a, (hl) : inc hl
    and 7
    ld b, a
    ld a, (currentAttr)
    and #F8
    or b
    ld (currentAttr), a
    jr putStr

; ============================================
; putC - Print single character with cursor tracking
; Input: A = character (ASCII 32-127 or 13=CR)
; ============================================
putC:
    cp 13 : jr z, .cr
    cp 32 : ret c
    ld c, a
    ld a, (dh_mode) : or a : ld a, c
    jr nz, .dh
    call drawCharPixelsOnly
    call setCharAttr
.advance:
    ld hl, coords
    inc (hl)
    ld a, (hl) : cp 42 : jr nc, .cr
    ret
.dh:
    push af
    call drawCharDH_Top
    ld hl, coords+1 : inc (hl)
    pop af
    call drawCharDH_Bot
    ld hl, coords+1 : dec (hl)
    jr .advance
.cr:
    ld hl, coords
    xor a : ld (hl), a
    inc hl : inc (hl)
    ret

; ============================================
; setCharAttr - Set attribute for current character cell
; Uses currentAttr, reads position from coords
; ============================================
setCharAttr:
    ; Use precalculated byte column and pixel offset from drawC
    ld a, 0
.col = $ - 1              ; byte column (set by drawC)
    ld b, a
    ld a, (coords+1)
    rrca : rrca : rrca
    ld l, a
    and 31
    or #58
    ld h, a
    ld a, l
    and #E0
    or b
    ld l, a
    ld a, (currentAttr)
    ld (hl), a

    ld c, a                ; save currentAttr in C
    ld a, 0
.byteCol = $ - 1          ; pixel offset (set by drawC)
    bit 2, a
    ret z
    inc l
    ld (hl), c             ; Write second cell with currentAttr
    ret

; ============================================
; drawC - Render 6px character to screen memory
; Input: A = ASCII code
; Uses decompressChar (on-the-fly, like NetManZX)
; ============================================
drawC:
    call decompressChar         ; A = char, returns DE = glyph_buf

drawGlyph:
    push de                     ; save font data ptr
    ld hl, 0
.coords = $ - 2
    ld b, l
    call calc                   ; L = byte col, A = pixel offset
    ld (.rot), a
    ld (setCharAttr.byteCol), a ; save pixel offset for setCharAttr
    ld a, l
    ld (setCharAttr.col), a     ; save byte column for setCharAttr
    ld a, (.rot)
    ld d, h : ld e, l
    call findAddr
    push de                     ; save screen address
; Mask table lookup (replaces rotation loop — from NetManZX)
    ld a, 0
.rot = $ - 1
    ld c, a : ld b, 0
    ld hl, .maskTable
    add hl, bc
    ld a, (hl) : ld (.mask2), a
    inc hl
    ld a, (hl) : ld (.mask1), a
; Shift dispatch
    ld a, c
    add a, a : add a, a         ; ×4 = bytes to skip
    ld c, a
    ld a, .shift0 - .shiftJr - 2
    sub c
    ld (.shiftJr + 1), a
    pop ix                      ; IX = screen addr
    pop de                      ; DE = glyph_buf
    ld b, 8
.printIt:
    ld a, (de)
    ld h, a
    ld l, 0
.shiftJr:
    jr .shift0
.shift6:
    srl h : rr l
    srl h : rr l
.shift4:
    srl h : rr l
    srl h : rr l
.shift2:
    srl h : rr l
    srl h : rr l
.shift0:
    ld a, (ix + 1)
    and #0F
.mask1 = $ - 1
    or l
    ld (ix + 1), a
    ld a, (ix)
    and #FC
.mask2 = $ - 1
    or h
    ld (ix), a
    inc ixh
    inc de
    djnz .printIt
    ret

.maskTable:
    db #03, #FF             ; shift 0
    db #C0, #FF             ; shift 2
    db #F0, #3F             ; shift 4
    db #FC, #0F             ; shift 6

; ============================================
; calc - Calculate byte column and pixel offset
; Input: B = column (0-41)
; Output: L = byte column, A = pixel offset (0,2,4,6)
; ============================================
calc:
    ld a, b
    add a, a        ; A = B * 2
    add a, b        ; A = B * 3
    ld l, a
    srl l
    srl l           ; L = (B*3)/4 = byte column
    and 3           ; A = (B*3)%4
    add a, a        ; A = ((B*3)%4)*2 = pixel offset
    ret

; ============================================
; findAddr - Convert row/col to screen address
; Input: D = row, E = byte column
; Output: DE = screen address
; ============================================
findAddr:
    ld a, d
    and 7
    rrca
    rrca
    rrca
    or e
    ld e, a
    ld a, d
    and 24
    or #40
    ld d, a
    ret

; ============================================
; decompressChar - Decompress packed font character
; Input: A = ASCII code (32-127)
; Output: DE = glyph_buf (8 bytes)
; Destroys: AF, BC, DE, HL
; ============================================
decompressChar:
    sub 32
    cp 96
    jr c, .valid
    xor a
.valid:
    ld c, a
    ld l, a
    ld h, 0
    add hl, hl
    add hl, hl
    ld de, font_packed
    add hl, de
    ld de, glyph_buf
    push bc
    ld b, 4
.unpack:
    ld a, (hl)
    push hl
    ld c, a
    ld hl, font_lut
    ld a, c
    rrca : rrca : rrca : rrca
    and #0F
    add a, l : ld l, a
    ld a, (hl)
    ld (de), a
    inc de
    ld a, c
    and #0F
    ld l, low font_lut
    add a, l : ld l, a
    ld a, (hl)
    ld (de), a
    inc de
    pop hl
    inc hl
    djnz .unpack
    pop bc
    ld hl, font_exceptions
.excScan:
    ld a, (hl)
    cp #FF
    jr z, .excDone
    cp c
    jr z, .excMatch
    jr nc, .excDone
    inc hl : inc hl : inc hl
    jr .excScan
.excMatch:
    inc hl
    ld a, (hl)
    inc hl
    ld b, (hl)
    inc hl
    push hl
    ld l, a : ld h, high glyph_buf
    ld (hl), b
    pop hl
    jr .excScan
.excDone:
    ld de, glyph_buf
    ret

glyph_buf = #7F00      ; 8 bytes — uninit RAM

; ============================================
; Font data (from NetManZX)
; ============================================
font_lut:
    ASSERT low font_lut <= #F0, "font_lut crosses page"
    db #00, #0C, #10, #18, #1C, #28, #30, #36, #38, #3C, #4C, #54, #60, #6C, #78, #7C

font_packed:
    db #00, #00, #00, #00  ; ' '
    db #33, #33, #30, #30  ; '!'
    db #DD, #00, #00, #00  ; '"'
    db #55, #F5, #F5, #50  ; '#'
    db #39, #C8, #1E, #60  ; '$'
    db #0D, #13, #36, #70  ; '%'
    db #8D, #87, #DD, #70  ; '&'
    db #33, #00, #00, #00  ; '''
    db #13, #66, #63, #10  ; '('
    db #C6, #33, #36, #C0  ; ')'
    db #02, #B8, #B2, #00  ; '*'
    db #02, #2F, #22, #00  ; '+'
    db #00, #00, #00, #36  ; ','
    db #00, #0F, #00, #00  ; '-'
    db #00, #00, #00, #30  ; '.'
    db #11, #33, #36, #60  ; '/'
    db #8D, #DF, #DD, #80  ; '0'
    db #38, #33, #33, #30  ; '1'
    db #8D, #13, #6C, #F0  ; '2'
    db #8D, #13, #1D, #80  ; '3'
    db #14, #9D, #F1, #10  ; '4'
    db #FC, #E1, #1D, #80  ; '5'
    db #8C, #CE, #DD, #80  ; '6'
    db #F1, #33, #36, #60  ; '7'
    db #8D, #D8, #DD, #80  ; '8'
    db #8D, #D9, #13, #60  ; '9'
    db #00, #30, #00, #30  ; ':'
    db #00, #30, #00, #36  ; ';'
    db #01, #36, #63, #10  ; '<'
    db #00, #F0, #F0, #00  ; '='
    db #0C, #63, #36, #C0  ; '>'
    db #8D, #13, #60, #60  ; '?'
    db #30, #AB, #BA, #03  ; '@'
    db #28, #DF, #DD, #D0  ; 'A'
    db #ED, #DE, #DD, #E0  ; 'B'
    db #8D, #CC, #CD, #80  ; 'C'
    db #ED, #DD, #DD, #E0  ; 'D'
    db #FC, #CE, #CC, #F0  ; 'E'
    db #FC, #CE, #CC, #C0  ; 'F'
    db #8D, #CD, #DD, #90  ; 'G'
    db #DD, #DF, #DD, #D0  ; 'H'
    db #93, #33, #33, #90  ; 'I'
    db #11, #11, #1D, #80  ; 'J'
    db #DD, #DE, #DD, #D0  ; 'K'
    db #CC, #CC, #CC, #F0  ; 'L'
    db #0D, #FF, #DD, #D0  ; 'M'
    db #AD, #FF, #FD, #00  ; 'N'
    db #8D, #DD, #DD, #80  ; 'O'
    db #ED, #DE, #CC, #C0  ; 'P'
    db #8D, #DD, #DD, #81  ; 'Q'
    db #ED, #DE, #DD, #D0  ; 'R'
    db #8D, #C8, #1D, #80  ; 'S'
    db #93, #33, #33, #30  ; 'T'
    db #DD, #DD, #DD, #80  ; 'U'
    db #DD, #DD, #D8, #20  ; 'V'
    db #DD, #DF, #FD, #00  ; 'W'
    db #DD, #D8, #DD, #D0  ; 'X'
    db #DD, #D8, #66, #60  ; 'Y'
    db #F1, #36, #CC, #F0  ; 'Z'
    db #86, #66, #66, #68  ; '[' (full height: body on scan6, cap on scan7)
    db #66, #33, #31, #10  ; '\'
    db #83, #33, #33, #38  ; ']' (full height: body on scan6, cap on scan7)
    db #28, #D0, #00, #00  ; '^'
    db #00, #00, #00, #00  ; '_'
    db #63, #00, #00, #00  ; '`'
    db #00, #81, #9D, #90  ; 'a'
    db #CC, #ED, #DD, #E0  ; 'b'
    db #00, #8D, #CD, #80  ; 'c'
    db #11, #9D, #DD, #90  ; 'd'
    db #00, #8D, #FC, #80  ; 'e'
    db #46, #F6, #66, #60  ; 'f'
    db #00, #9D, #D9, #1E  ; 'g'
    db #CC, #ED, #DD, #D0  ; 'h'
    db #30, #83, #33, #30  ; 'i'
    db #30, #33, #33, #30  ; 'j'
    db #CC, #DD, #ED, #D0  ; 'k'
    db #66, #66, #66, #30  ; 'l'
    db #00, #0F, #FD, #D0  ; 'm'
    db #00, #ED, #DD, #D0  ; 'n'
    db #00, #8D, #DD, #80  ; 'o'
    db #00, #ED, #DD, #EC  ; 'p'
    db #00, #9D, #DD, #91  ; 'q'
    db #00, #D0, #CC, #C0  ; 'r'
    db #00, #9C, #81, #E0  ; 's'
    db #26, #F6, #66, #40  ; 't'
    db #00, #DD, #DD, #90  ; 'u'
    db #00, #DD, #D8, #20  ; 'v'
    db #00, #DD, #FD, #00  ; 'w'
    db #00, #DD, #8D, #D0  ; 'x'
    db #00, #DD, #D8, #6C  ; 'y'
    db #00, #F3, #6C, #F0  ; 'z'
    db #36, #6C, #66, #30  ; '{'
    db #33, #33, #33, #30  ; '|'
    db #63, #31, #33, #60  ; '}'
    db #0B, #00, #00, #00  ; '~'
    db #FF, #FF, #FF, #FF  ; DEL (127) -> solid block

font_exceptions:
    db 32, 1, #24  ; '@' scanline 1
    db 32, 6, #20  ; '@' scanline 6
    db 45, 0, #44  ; 'M' scanline 0
    db 46, 6, #64  ; 'N' scanline 6
    db 55, 6, #44  ; 'W' scanline 6
    db 63, 7, #7E  ; '_' scanline 7
    db 74, 7, #70  ; 'j' scanline 7
    db 77, 2, #68  ; 'm' scanline 2
    db 82, 3, #70  ; 'r' scanline 3
    db 87, 6, #44  ; 'w' scanline 6
    db #FF          ; end of table

; ============================================
; clrscr - Clear entire screen + set attributes + border
; ============================================
clrscr:
    xor a
    out (#fe), a
    ld (23624), a           ; BORDCR = 0

    ; Clear pixels
    ld hl, #4000
    ld de, #4001
    ld bc, #17ff
    ld (hl), a
    ldir

    ; Set all attributes to bright white on black
    ld a, #47
    ld hl, #5800
    ld de, #5801
    ld bc, 768-1
    ld (hl), a
    ldir

    ; System vars
    xor a
    ld (23659), a           ; DF_SZ = full screen
    ld a, #47
    ld (23693), a           ; ATTR_P
    ld (23695), a           ; ATTR_T

    ; Reset cursor
    ld hl, 0
    ld (coords), hl
    ret

; ============================================
; stretchRows01 - Stretch row 0 to double-height across rows 0-1
; Must be called AFTER rendering text/graphics in row 0
; Each scanline is duplicated: top 4 -> row 0, bottom 4 -> row 1
; ============================================
stretchRows01:
    ld hl, #4700        ; src: row0 scanline 7
    ld de, #4720        ; dst: row1 scanline 7
    call stretchFour
    ld hl, #4300        ; src: row0 scanline 3
    ld de, #4700        ; dst: row0 scanline 7
    jr stretchFour

; stretchFour disables interrupts internally — safe from any caller
stretchFour:
    di
    ld b, 4
.sloop:
    push bc
    push hl
    push de
    ld bc, 32
    ldir
    pop de
    pop hl
    push hl
    dec d
    push de
    ld bc, 32
    ldir
    pop de
    pop hl
    dec h
    dec d
    pop bc
    djnz .sloop
    ei
    ret

; ============================================
; draw_hline_only - 1px line, pixels only, no attribute change
; Input: A = row (0-23), E = scanline (0-7)
; ============================================
draw_hline_only:
    ld c, a
    and #18
    ld h, a
    ld a, c
    and #07
    rrca
    rrca
    rrca
    ld l, a
    ld a, h
    or #40
    add a, e
    ld h, a
    ld a, #FF
    ld b, 32
.fill:
    ld (hl), a
    inc l
    djnz .fill
    ret

; ============================================
; stretchRow - Stretch row A to double-height across rows A and A+1
; Input: A = base row (0-22)
; Destroys: AF, BC, DE, HL
; ============================================
stretchRow:
    push af
    ld d, a : ld e, 0
    call findAddr               ; DE = row A, scan 0
    pop af
    push de                     ; save rowA base
    inc a : ld d, a : ld e, 0
    call findAddr               ; DE = row A+1, scan 0
    ld a, d : or 7 : ld d, a   ; DE = row A+1, scan 7
    pop hl                      ; HL = row A, scan 0
    push hl                     ; save rowA base
    ld a, h : or 7 : ld h, a   ; HL = row A, scan 7
    push hl                     ; save rowA scan 7
    call stretchFour
    pop de                      ; DE = row A, scan 7
    pop hl                      ; HL = row A, scan 0
    ld a, h : or 3 : ld h, a   ; HL = row A, scan 3
    jr stretchFour

; ============================================
; drawCharDH_Top - Render upper half of char as double-height, pixels only
; Input: A = ASCII code, coords set by caller
; ============================================
drawCharDH_Top:
    call decompressChar
    ld hl, glyph_buf+3
    jr drawCharDH_Do

; ============================================
; drawCharDH_Bot - Render lower half of char as double-height, pixels only
; Input: A = ASCII code, coords set by caller
; ============================================
drawCharDH_Bot:
    call decompressChar
    ; Copy buf[4-7] to buf[0-3] first to avoid overlap
    ld hl, glyph_buf+4
    ld de, glyph_buf
    ld bc, 4
    ldir
    ld hl, glyph_buf+3          ; now expand from buf[0-3]

drawCharDH_Do:
    ld de, glyph_buf+7
    ld b, 4
.loop:
    ld a, (hl)
    ld (de), a
    dec de
    ld (de), a
    dec de
    dec hl
    djnz .loop
    ld hl, (coords)
    ld (drawGlyph.coords), hl
    ld de, glyph_buf
    jp drawGlyph

; ============================================
; drawCharPixelsOnly - Render character pixels without touching attrs
; Input: A = ASCII code, coords set by caller
; ============================================
drawCharPixelsOnly:
    ld hl, (coords) : ld (drawGlyph.coords), hl
    jp drawC

; ============================================
; putStrDH - Print zero-terminated string in double-height
; Uses current row for TOP and row+1 for BOTTOM, pixels only
; Input: HL = pointer to zero-terminated string
; ============================================
putStrDH:
    ld a, (hl)
    inc hl
    and a
    ret z
    cp 13
    jr z, .cr
    cp 32
    jr c, putStrDH
    push hl
    push af
    call drawCharDH_Top
    ld hl, currentAttr
    set 6, (hl)                   ; BRIGHT on for top row
    call setCharAttr              ; top row attr (with BRIGHT)
    ld hl, currentAttr
    res 6, (hl)                   ; BRIGHT off for bottom row
    ld hl, coords+1
    inc (hl)
    pop af
    call drawCharDH_Bot
    call setCharAttr              ; bottom row attr (no BRIGHT)
    ld hl, coords
    inc (hl)
    ld a, (hl)
    cp 42
    jr c, .restoreRow
    xor a
    ld (hl), a
    inc hl
    inc (hl)
    pop hl
    jr putStrDH
.restoreRow:
    inc hl
    dec (hl)
    pop hl
    jr putStrDH
.cr:
    xor a : ld (coords), a
    ld a, (coords+1) : add a, 2 : ld (coords+1), a
    jr putStrDH

; ============================================
; showStatus - Display centered double-height status on rows 22-23
; Input: HL = pointer to null-terminated string
;        C = attribute byte for both rows
; Destroys: AF, BC, DE, HL
; ============================================
last_status_ptr: dw 0

showStatus:
    ; Skip redraw if same status string
    ld a, (last_status_ptr) : cp l : jr nz, .ss_changed
    ld a, (last_status_ptr+1) : cp h : jr nz, .ss_changed
    ret                             ; same string, don't redraw
.ss_changed:
    ld (last_status_ptr), hl
    ; 1. Calculate string length and center (before HALT)
    push bc
    push hl
    ld b, 0
.strlen:
    ld a, (hl) : or a : jr z, .gotLen
    inc hl : inc b : jr .strlen
.gotLen:
    ld a, 42 : sub b : srl a
    ld (.ss_col), a
    pop hl
    pop bc
    ; 2. Sync to frame, then do ALL VRAM work with interrupts disabled
    ei : halt : di
    ; Clear row 22
    push hl : push bc
    ld hl, #50C0
    call clearRow
    pop bc : pop hl
    ; Print text centered
    push bc
    ld a, 0
.ss_col = $ - 1
    ld (coords), a
    ld a, 22 : ld (coords+1), a
    call putStr
    ; Set attributes
    pop bc
    push bc
    ld a, c : or #40 : ld c, a
    ld a, 22 : call setAttr
    pop bc
    ld a, c : and #BF : ld c, a
    ld a, 23 : call setAttr
    ; Stretch
    ld hl, #57C0
    ld de, #57E0
    call stretchFour
    ld hl, #53C0
    ld de, #57C0
    jp stretchFour

clearRow:
    ld b, 8
.crScan:
    push hl : push bc
    ld b, 32 : xor a
.crByte:
    ld (hl), a : inc l : djnz .crByte
    pop bc : pop hl
    inc h : djnz .crScan
    ret

; ============================================
; drawStatusSeparator - 1px white line in row 21
; ============================================
drawStatusSeparator:
    ld a, 21 : ld e, 3
    jp draw_hline_only

; ============================================
; dhOn / dhOff - toggle Display.dh_mode
; ============================================
dhOn:
    ld a, 1
    ld (dh_mode), a
    ret

dhOff:
    xor a
    ld (dh_mode), a
    ret

    endmodule

; ============================================
; Macros (outside module, available to all files)
; ============================================
    macro printMsg ptr
    ld hl, ptr : call Display.putStr
    endm

    macro gotoXY x, y
    ld hl, x | (y << 8)
    ld (Display.coords), hl
    endm

    macro setLineColor line, color
    ld a, line : ld c, color
    call Display.setAttr
    endm

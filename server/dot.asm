    device ZXSPECTRUM48

    IFDEF DOT
        org #2000
    ELSE
        org #8000          ; 32768 (FAST RAM)
    ENDIF

text
    jp start
ver:
    db "BridgeZX Server v0.1"
    db 13
    db "(C) 2025 M. Ignacio Monge Garcia", 13
    db "(C) 2022 Alex Nihirash (LAIN)   ", 0

    include "modules/display.asm"
    include "modules/wifi.asm"
    include "modules/esxdos.asm"
    include "drivers/ay.asm"


start:
    ld sp, stack_top   ;
    ; Screen style: BORDER/PAPER black, default INK white (robust: set ATTR_P/ATTR_T then CLS).
    call ScreenInit
    ld d,0
    ld e,0
    call Display.setPos
    call Display.initBarChars

    ; Header (white text)
    printMsg msg_hdr_white
    printMsg ver
    ; Yellow solid line separator
    printMsg msg_hdr_yellow
    printMsg msg_line
    printMsg msg_hdr_white

    ; UART driver is platform-specific

    printMsg msg_uart
    call Uart.init

    printMsg msg_wifi
    call Wifi.init
    
 

    ; Record the line where the "Waiting..." status is printed so it can be
    ; overwritten when the transfer actually starts.
    ld a, 24
    ld b, a
    ld a, (23689)
    ld c, a
    ld a, b
    sub c
    ld (Wifi.wait_row), a

    ; Only show the waiting message once UART/Wi-Fi are initialized
    printMsg msg_boot
    ei
    jp Wifi.recv

; Ready message separator (small ASCII '-'), full width (32 cols)
msg_ready_line db "--------------------------------", 13, 0


msg_boot db "Waiting for files...", 13, 0
msg_uart db "Initializing UART...", 13, 0
msg_wifi db "Initializing Wi-Fi module...", 13, 0
msg_ink_green_dot db 16, 4, 0
msg_ink_white_dot db 16, 7, 0

; Screen/control sequences
msg_hdr_yellow   db 16, 6, 0
msg_hdr_white    db 16, 7, 0

; 32-column full-width separator (thin line using UDG 'D' = CHR$147)
msg_line db 147,147,147,147,147,147,147,147,147,147,147,147,147,147,147,147
         db 147,147,147,147,147,147,147,147,147,147,147,147,147,147,147,147
         db 13, 13, 0

; ----------------------------
; Helpers
; ----------------------------

ScreenInit:
    ; 1. Borrado de píxeles (Fondo Negro)
    ld hl, #4000        ; Inicio de memoria de pantalla
    ld de, #4001
    ld bc, 6144-1       ; Área de píxeles
    ld (hl), 0          ; 0 = Negro (píxel apagado)
    ldir                ; Este borra el listado BASIC

    ; 2. Borrado de Atributos (Color Fijo)
    ld a, #47           ; Valor: 01000111 (Bright 1, Paper 0, Ink 7)
    ld hl, #5800        ; Forzamos HL al inicio de atributos
    ld de, #5801
    ld bc, 768-1        ; Área de atributos (32x24)
    ld (hl), a          ; Cargamos el blanco/negro
    ldir                ; Esto elimina las líneas verticales

    ; 3. Sincronizar Variables del Sistema
    xor a
    ld (23624), a       ; BORDCR (Borde negro)
    out (#fe), a        ; Aplicar borde físico
    ld (23659), a       ; DF_SZ (Pantalla completa)
    ld a, #47
    ld (23693), a       ; ATTR_P
    ld (23695), a       ; ATTR_T

    ; 4. Abrir canal solo si no es comando .dot
    IFNDEF DOT
        ld a, 2
        call #1601      ; Abrir canal 2 (S) para BASIC
    ENDIF
    ret

buffer = #C000

; Stack top for reset on abort (just below buffer area)
stack_top = #BFFE

    IFDEF DOT
        savebin "bridgezx", text, $ - text
    ELSE
        savebin "bridgezx.bin", text, $ - text
    ENDIF
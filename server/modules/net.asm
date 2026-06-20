    module Wifi

; =============================================================================
; IM2 TIMER — 50Hz tick counter independent of ROM/FRAMES
; Vector table at #FE00-#FF00, ISR at #FCFC, counter at #FC00
; =============================================================================
IM2_TABLE  = #FE00            ; 257-byte vector table (#FE00-#FF00)
IM2_VECTOR = #FC              ; table filled with #FC → ISR at #FCFC
IM2_ISR    = #FCFC            ; 12-byte ISR (#FCFC-#FD07)
IM2_TICKS  = #FC00            ; 16-bit tick counter

setup_im2:
    di
    ; Fill 257-byte vector table at #FE00-#FF00 with #FC
    ld hl, IM2_TABLE
    ld (hl), IM2_VECTOR
    ld de, IM2_TABLE + 1
    ld bc, 256
    ldir
    ; Copy ISR to #FCFC (12 bytes)
    ld hl, .isr_data
    ld de, IM2_ISR
    ld bc, .isr_end - .isr_data
    ldir
    ; Zero tick counter
    ld hl, 0
    ld (IM2_TICKS), hl
    ; Activate IM2
    ld a, high IM2_TABLE
    ld i, a
    im 2
    ei
    ret

.isr_data:
    db #E5                  ; push hl
    db #2A, low IM2_TICKS, high IM2_TICKS  ; ld hl, (IM2_TICKS)
    db #23                  ; inc hl
    db #22, low IM2_TICKS, high IM2_TICKS  ; ld (IM2_TICKS), hl
    db #E1                  ; pop hl
    db #FB                  ; ei
    db #ED, #4D             ; reti
.isr_end:

; Stable read of IM2 tick counter without changing interrupt state
ReadIm2Ticks:
.retry:
    ld hl, (IM2_TICKS)
    ld de, (IM2_TICKS)
    ld a, h : cp d : jr nz, .retry
    ld a, l : cp e : jr nz, .retry
    ret

; =============================================================================
; INICIALIZACIÓN CON FAST PATH
; =============================================================================
init:
    ld a, (wait_row)
    or a
    jr nz, .row_ok
    ld a, 8
    ld (wait_row), a
.row_ok:

    ; 1. Salir modo datos (por si estaba en modo transparente)
    ld hl, .escape : call espSendZ
    jr .escDone
.escape: db "+++", 0
.escDone:
    ld b, 60              ; 1.2 segundos de espera
.wait_exit:
    halt
    djnz .wait_exit

    ; 2. Drenar cualquier basura con más tiempo
    call .drain_long

    ; 3. Intentar comunicación simple (sin AT+RST que requiere esperar WiFi)
    ld c, 3               ; 3 intentos
.retry_at:
    push bc
    call flushUartQuick
    ld hl, msg_at_cmd : call espSendAtCmdZ
    call checkOkErrTimeout
    pop bc
    jr nc, .esp_ok        ; ESP respondió OK

    ; Esperar y reintentar
    ld b, 25
.retry_wait:
    halt
    djnz .retry_wait
    dec c
    jr nz, .retry_at

    ; Último intento: reset completo
    jr .try_full_reset

.esp_ok:
    ; 4. Configurar
    ld hl, cmd_list_basic : call SendCmdListCheck
    jr c, .try_full_reset
    call closeAllConnections
    ld hl, msg_at_server_off : call espSendAtCmdZ : call checkOkErrTimeout
    call flushUartQuick
    ld hl, msg_at_server_on : call espSendAtCmdZ : call checkOkErr
    jr c, .try_full_reset
    call getMyIp
    jr c, .try_full_reset
    jp showListeningInfo

.try_full_reset:
    ; Reset completo con timeout largo basado en HALTs
    call .drain_long
    ld hl, msg_at_rst : call espSendAtCmdZ

    ; Esperar hasta 5 segundos por "ready"
    ld de, 250            ; 250 * 20ms = 5 segundos
.wait_ready:
    halt
    push de
    ld c, 'y' : call .findChar
    pop de
    jr c, .got_ready
    dec de
    ld a, d : or e
    jr nz, .wait_ready
    jr .err               ; Timeout total

.got_ready:
    ; Esperar hasta 10 segundos más por "GOT IP"
    ld de, 500
.wait_gotip:
    halt
    push de
    ld c, 'P' : call .findChar
    pop de
    jr c, .ready_ok
    dec de
    ld a, d : or e
    jr nz, .wait_gotip
    jr .err

.ready_ok:
    call .drain_long
    ld hl, cmd_list_full : call SendCmdListCheck
    jr c, .err
    call getMyIp
    jr c, .err
    jp showListeningInfo

; Buscar 'y' de "ready" - retorna C=1 si encontrado
; .findChar - Search for char C in UART stream (50 reads max)
; Input: C = char to find. Output: CF=1 if found
.findChar:
    ld b, 50
.fc_loop:
    push bc
    call @Uart.uartRead
    pop bc
    jr nc, .fc_next
    cp c
    jr z, .fc_found
.fc_next:
    djnz .fc_loop
    or a : ret
.fc_found:
    scf : ret

; Drenar buffer con múltiples pasadas
.drain_long:
    ld d, 20              ; 20 rondas
.dl_outer:
    ld b, 100
.dl_loop:
    push bc
    call @Uart.uartRead
    pop bc
    djnz .dl_loop
    dec d
    jr nz, .dl_outer
    ret

.err:
    ; Clear init message rows
    ld a, 6 : call clearRowA
    ld a, 7 : call clearRowA
    ; Show error in red DH on rows 6-7
    ld a, 2 : call setInk
    ld a, 6 : ld c, #42 : call Display.setDhAttrPair
    gotoXY 0, 6
    call Display.dhOn
    ld hl, .err_msg
    call Display.putStr
    call Display.dhOff
    ; Wait for key, then retry init from scratch
    call showPressKey
    call WaitKey
    ; Clear error rows and Press-key rows before retry
    ld a, 6  : call clearRowA
    ld a, 7  : call clearRowA
    ld a, 19 : call clearRowA
    ld a, 20 : call clearRowA
    jp Wifi.init

.err_msg: db "ESP error", 0

showListeningInfo:
    ; Clear init message rows before overwriting
    ld a, 6 : call clearRowA
    gotoXY 0, 6
    ld a, 4 : call setInk

    call DrawSeparatorLine    ; Línea superior de 1px

    ; Print IP info on current row, then stretch to double-height
    ld a, (Display.coords+1)
    push af                           ; save text row number
    ld hl, msg_listening
    call Display.putStr
    ld hl, ipAddr
    call Display.putStr
    printMsg msg_port_txt
    ; Stretch text row to double-height
    pop af
    push af
    call Display.stretchRow
    ; Set attrs: top = green BRIGHT, bottom = green no BRIGHT
    pop af
    push af
    ld c, #44 : call Display.setDhAttrPair
    pop af
    add a, 2                          ; skip past both rows of double-height
    ld (Display.coords+1), a
    xor a : ld (Display.coords), a    ; col 0

    call DrawSeparatorLine    ; Línea inferior de 1px
    jp inkWhite

; =============================================================================
; Cerrar enlaces TCP heredados antes de abrir el servidor BridgeZX.
; Un arranque limpio importa tras usar otros TAPs que dejan el ESP con sockets
; vivos en otro protocolo/puerto.
; =============================================================================
closeAllConnections:
    ld a, '5'
    call .close_one
    ld a, '0'
.loop:
    push af
    call .close_one
    pop af
    inc a
    cp '5'
    jr nz, .loop
    ret
.close_one:
    ld (msg_at_close_id + 10), a
    ld hl, msg_at_close_id : call espSendAtCmdZ
    call drainOK
    jr flushUartQuick

; =============================================================================
; COMUNICACIÓN AT
; =============================================================================
readByteShortTimeout:
    ld b, 100
.loop:
    push bc
    call @Uart.uartRead
    pop bc
    ret c
    djnz .loop
    or a
    ret

flushUartQuick:
    ld b, 10
.loop:
    push bc
    call @Uart.uartRead
    pop bc
    ret nc
    djnz .loop
    ret

checkOkErrTimeout:
    ld c, 200
.loop:
    call readByteShortTimeout : jr nc, .timeout
    cp 'O' : jr z, .okStart
    cp 'E' : jr z, .errStart
    cp 'L' : jr z, .errStart    ; consume FAIL through final L before error
    dec c : jr nz, .loop
.timeout:
    scf : ret
.okStart:
    call readByteShortTimeout : jr nc, .timeout : cp 'K' : jr nz, .loop
    or a : ret
.errStart:
    scf : ret

; =============================================================================
; RUTINA DE LECTURA CON TIMEOUT (CON EFECTO VISUAL)
; =============================================================================
readByteTimeout:
    ld hl, 3000

.rbt_loop:
    push hl
    call @Uart.uartRead
    pop hl

    ret c                   ; C=1: ¡Dato recibido!

.skip_effect:
    dec hl
    ld a, h
    or l
    jr nz, .rbt_loop        ; Si HL != 0, seguimos escuchando

    or a                    ; Timeout real (C=0)
    ret

; =============================================================================
; BUCLE DE RECEPCIÓN (BRIDGEZX MAIN LOOP)
; =============================================================================
recv:
    ; --- REINICIO DE VARIABLES DE ESTADO ---
    di
    ld sp, stack_top

    ; Zero-fill all recv state variables in one shot
    ld hl, recv_zero_start
    ld de, recv_zero_start + 1
    ld (hl), 0
    ld bc, recv_zero_end - recv_zero_start - 1
    ldir
    ld a, '0'
    ld (socket_id), a

    ; Limpiar pantalla y poner "Waiting..."
    ei
    call Wifi_UiResetToWaiting

; --- ETIQUETA NECESARIA PARA REINICIOS SIN BORRAR PANTALLA ---
recv_no_ui:
    ld a, (wait_row) : or a : jr nz, .wait_ok : ld a, 8 : ld (wait_row), a
.wait_ok:
    jr .waitIPD

; -----------------------------------------------------------------------------
; Bucle de espera SIMPLE
; -----------------------------------------------------------------------------
.waitIPD:
.waitIPD_loop:
    ; Elegir timeout según estado: rápido en espera, largo en transferencia
    ld a, (file_opened)
    or a
    jr nz, .waitIPD_slow        ; Transferencia activa -> timeout largo

    ; Modo espera: polling with small delay to reduce VRAM interference
    call @Uart.uartRead
    jr c, .waitIPD_gotByte
    ld b, 20
.waitIPD_delay:
    djnz .waitIPD_delay
    jr .waitIPD_loop

.waitIPD_slow:
    ; Transferencia activa: timeout largo para detectar pérdida
    call Wifi.readByteTimeout
    jr c, .waitIPD_gotByte

    ; Timeout real durante transferencia -> error
    jp Wifi_PayloadTimeoutAbort

.waitIPD_gotByte:
    cp '+' : jr z, .waitIPD_gotPlus
    cp 'C' : jp z, .maybeClosed

    jr .waitIPD_loop

.waitIPD_gotPlus:
    ; Match "IPD," after the '+'
    ld hl, .seq_ipd : call matchSeq : jr nz, .waitIPD_loop
    jr .readSock
.seq_ipd: db "IPD,", 0

.readSock:
    call readByteShortTimeout : jr nc, .waitIPD
    cp ',' : jr z, .sockDone
    cp '0' : jr c, .readSock
    cp '9'+1 : jr nc, .readSock
    ld (socket_id), a : jr .readSock
.sockDone:
    ld hl,0
.cil1:
    push hl
    call readByteShortTimeout : jr nc, .lenParseTimeout
    pop hl
    cp ':' : jr z, .storeAvail
    cp '0' : jr c, .lenParseInvalid
    cp '9'+1 : jr nc, .lenParseInvalid
    sub '0'
    ld c,l : ld b,h
    add hl,hl : add hl,hl : add hl,bc : add hl,hl
    ld c,a : ld b,0
    add hl,bc
    jr .cil1

.lenParseTimeout:
    pop hl : jr .waitIPD
.lenParseInvalid:
    pop hl : jr .waitIPD
.storeAvail:
    ld (data_avail), hl

.chunkLoop:
    ld hl, (data_avail)
    ld a, h : or l : jp nz, .haveData  ; JP usado por seguridad (distancia)

    ; --- FIN DE FICHERO DETECTADO ---
    ld a, (xfer_done) : or a : jp z, .waitIPD

    ; 1. Validar CRC
    call CrcVerify
    jp c, .crc_fail

    ; --- ÉXITO (CRC OK) ---
    call PrintCrcOverwriteOk
    call putCR
    call EsxDOS.closeOnly
    jp c, Wifi_ProtoAbort
    xor a
    ld (file_opened), a
    call ClearProgressBar

    ; 3. Feedback final
    call showStatusOk
    call BeepSuccess

    ; 4. ACK INMEDIATO (El cliente PC se libera y pone verde)
    call sendAck

    ; Acumular bytes a la estadística de sesión
    ld hl, (total_size_lo) : ld de, (total_size_hi)
    call AddSessionBytes

    ; --- LÓGICA DE FIN DE LOTE ---
    ld a, (batch_curr)
    ld b, a
    ld a, (batch_total)
    cp b
    jr z, .batch_complete  ; Si Actual == Total, fin del trabajo

    ; Si faltan, seguimos al siguiente
    jp recv

.batch_complete:
    ; Mostrar Resumen
    call Wifi_UiResetToWaiting
    call showStatusOk

    ; "N file(s) transferred" — double-height
    xor a : call setWaitOffsetPos
    xor a : ld c, #47 : call setWaitOffsetDhAttr
    call Display.dhOn
    call inkWhite
    ld a, (batch_total) : call PrintByteDec
    printMsg msg_files_xferd

    ; "Total: X Bytes" — double-height (next 2 rows)
    ld a, 2 : call setWaitOffsetPos
    ld a, 2 : ld c, #47 : call setWaitOffsetDhAttr
    ld hl, msg_total_txt : call Display.putStr
    call PrintSessionStats
    call Display.dhOff

    call showPressKey

    ; Resetear contadores de sesión
    ld hl, 0
    ld (session_bytes_lo), hl
    ld (session_bytes_hi), hl

    call WaitKey
    jp recv

.crc_fail:
    ; --- FALLO (CRC ERROR) ---
    call showStatusFail
    call PrintCrcOverwriteBad
    call putCR
    call BeepError
    call EsxDOS.closeOnly

    ; Mensaje de borrado
    printMsg msg_deleting
    call inkWhite
    ld hl, EsxDOS.filename
    call Display.putStr
    call putCR

    call EsxDOS.deleteFile
    call inkWhite

    ; [CAMBIO OPCIÓN B] ELIMINADO 'call sendAck'
    ; Al no enviar ACK, el PC esperará y dará Timeout, deteniendo la cola.

    ; 2. Pausa obligatoria para ver el error
    ; 3. Reinicio
    jp pressKeyThenRecv

.haveData:
    ld de, 8192
    or a : sbc hl, de : jr c, .useRemaining
    ld (data_avail), hl
    ld hl, 8192
    jr .readChunk
.useRemaining:
    ld hl, (data_avail)
    ld de, 0
    ld (data_avail), de

; =====================================================================
; TIGHT RECV LOOP - Inline UART polling, zero stack overhead per byte
; Registers during loop:
;   DE = destination pointer (buffer)
;   HL = bytes remaining to read
;   BC = alternates between ZXUNO_ADDR and ZXUNO_REG
; Timeout: 16-bit counter in memory, decremented on each idle poll.
;   At ~3.5MHz each idle iteration ≈ 40 T-states → 65535 × 40 ≈ 750ms.
;   Reset after each successful byte.
; =====================================================================
.readChunk:
    push hl                     ; Save chunk size for consumeChunk later
    ld de, buffer

    IFDEF FAST_UART
    ; === ZX-Uno/divTIesus optimized inline UART polling ===
    ; C stays #3B throughout, only B toggles between #FC (addr) and #FD (data)
    ld c, #3B
    jr .fast_recv_reset_timeout

.fast_recv_abort:
    pop bc
    jp Wifi_PayloadTimeoutAbort

.fast_recv_reset_timeout:
    ld a, #FF
    ld (fast_recv_timeout), a
    ld (fast_recv_timeout+1), a

    ; Select STAT register: B=#FC, write STAT_REG, then B=#FD to read
    ld b, #FC
    ld a, @Uart.UART_STAT_REG
    out (c), a
    inc b                       ; B=#FD

.fast_recv_poll:
    in a, (c)
    and @Uart.UART_BYTE_RECEIVED
    jr nz, .fast_recv_got_byte

    ld a, (fast_recv_timeout)
    sub 1
    ld (fast_recv_timeout), a
    jr nc, .fast_recv_poll
    ld a, (fast_recv_timeout+1)
    sub 1
    ld (fast_recv_timeout+1), a
    jr nc, .fast_recv_poll
    jr .fast_recv_abort

.fast_recv_got_byte:
    ; Select DATA register and read: B=#FC, write DATA_REG, B=#FD, read
    dec b                       ; B=#FC
    ld a, @Uart.UART_DATA_REG
    out (c), a
    inc b                       ; B=#FD
    in a, (c)

    ld (de), a
    inc de
    dec hl
    ld a, h
    or l
    jr z, .fast_recv_done

    jr .fast_recv_reset_timeout

    ELSE
    ; === Generic recv loop (portable, any UART driver) ===
    jr .gen_recv_reset

.gen_recv_abort:
    pop bc
    jp Wifi_PayloadTimeoutAbort

.gen_recv_reset:
    ld a, #FF
    ld (fast_recv_timeout), a
    ld (fast_recv_timeout+1), a

.gen_recv_poll:
    push de
    push hl
    call @Uart.uartRead
    pop hl
    pop de
    jr c, .gen_recv_got_byte

    ld a, (fast_recv_timeout)
    sub 1
    ld (fast_recv_timeout), a
    jr nc, .gen_recv_poll
    ld a, (fast_recv_timeout+1)
    sub 1
    ld (fast_recv_timeout+1), a
    jr nc, .gen_recv_poll
    jr .gen_recv_abort

.gen_recv_got_byte:
    ld (de), a
    inc de
    dec hl
    ld a, h
    or l
    jr z, .fast_recv_done

    jr .gen_recv_reset

    ENDIF

.fast_recv_done:
    pop bc
    call consumeChunk
    jp .chunkLoop

.maybeClosed:
    ; Match "LOSED" after the 'C'
    ld hl, .seq_closed : call matchSeq : jp nz, .waitIPD
    jr .closedConfirmed
.seq_closed: db "LOSED", 0

.closedConfirmed:
    ld a, (xfer_done) : or a : jr z, .closed_continue

    ; Closed after done -> OK, save and loop
    call EsxDOS.closeOnly
    jp c, Wifi_ProtoAbort
    xor a
    ld (file_opened), a
    call showStatusOk
    jp pressKeyThenRecv

.closed_continue:
    ld a, (hdr_pos) : or a : jp nz, Wifi_ClosedAbort
    ld a, (hdr_phase) : or a : jp nz, Wifi_ClosedAbort
    ld a, (fn_pos) : or a : jp nz, Wifi_ClosedAbort
    ld a, (name_pos) : or a : jp nz, Wifi_ClosedAbort
    ld a, (file_opened) : or a : jp nz, Wifi_ClosedAbort
    jp .waitIPD

; =============================================================================
; RUTINAS DE ABORTO (UNIFICADAS)
; =============================================================================

; Entrada unificada para abortos.
; Flujo: reset SP, beep, cerrar/borrar archivo si abierto,
;        reset ESP, flush, esperar tecla, reiniciar.
generic_abort:
    ld sp, stack_top
    call Display.dhOff
    call showStatusFail
    call BeepError

    ; Clear info line: pixels AND attrs
    ld a, INFOLINE_ROW : ld c, #47 : call Display.setAttr
    ld a, INFOLINE_ROW+1 : ld c, #47 : call Display.setAttr
    ld d, INFOLINE_ROW : call clearRowD
    ld d, INFOLINE_ROW+1 : call clearRowD

    ; "Deleting: FILENAME" below progress bar in red DH
    ld a, (file_opened)
    or a : jr z, .ga_no_file
    call EsxDOS.closeOnly
    ld a, 2 : call setInk
    ld a, 5 : call setWaitOffsetPos
    ld a, 5 : ld c, #42 : call setWaitOffsetDhAttr
    call Display.dhOn
    printMsg msg_deleting
    ld hl, EsxDOS.filename
    call Display.putStr
    call Display.dhOff
    call EsxDOS.deleteFile
    xor a
    ld (file_opened), a
.ga_no_file:
    ; Reset ESP y flush
    call Wifi_ResetESP
    call Wifi_FlushSilence
    ; Clear deleting message area before showing Press any key
    ld a, 5 : call setWaitOffsetPos
    call clearLine42
    ld a, 6 : call setWaitOffsetPos
    call clearLine42
    ; Esperar tecla
    jp pressKeyThenRecv

; --- Entry points for abort ---

Wifi_ClosedAbort:
Wifi_ProtoAbort:
Wifi_PayloadTimeoutAbort:
    jp generic_abort

pressKeyThenRecv:
    call showPressKey
    call WaitKey
    jp recv

clearRowD:
    ld e, 0
    call Display.setPos
    jp clearLine42

; =============================================================================
; RUTINA GENÉRICA DE ACUMULACIÓN DE FASE
; Entrada:
;   B = expected length, C = current position
;   DE = destination buffer base address
;   HL = pointer to position variable in memory
; Modifica: buf_ptr, chunk_work, la variable de posición
; Salida: Z=1 si fase completa, Z=0 si faltan datos (ret al caller)
; =============================================================================
accumulate_phase:
    ; Calcular bytes restantes = expected - current
    ld a, b
    sub c                   ; A = bytes needed
    ret z                   ; Ya completo (Z=1)
    ld (tmp_take), a        ; default take = needed

    push bc                 ; B=expected, C=current
    push hl                 ; pos var pointer

    ; Destination = dest_buf + current
    ld h, d
    ld l, e
    ld b, 0
    add hl, bc
    ex de, hl

    ; take = min(chunk_work, needed)
    ld bc, (chunk_work)
    ld a, b : or a : jr nz, .ap_take_need  ; chunk_work > 255, take = needed
    ld a, (tmp_take)
    cp c
    jr c, .ap_take_need                    ; needed < chunk_work
    ld a, c                                ; chunk_work <= needed
    ld (tmp_take), a
.ap_take_need:

    ; Source = buf_ptr, count = tmp_take
    ld hl, (buf_ptr)
    ld b, 0
    ld a, (tmp_take)
    ld c, a
    push bc
    ldir
    ld (buf_ptr), hl

    ; Update position: pos += take
    pop bc                  ; C=take
    pop hl
    pop de                  ; D=expected, E=old pos
    ld a, c
    add a, e
    ld (hl), a
    cp d
    push af

    ; Update chunk_work -= take
    ld e, c
    ld bc, (chunk_work)
    ld a, c : sub e : ld c, a
    ld a, b : sbc a, 0 : ld b, a
    ld (chunk_work), bc

    pop af                  ; Z=1 if pos == expected
    ret

; =============================================================================
; LÓGICA DE FASES
; =============================================================================
consumeChunk:
    ld hl, buffer
    ld (buf_ptr), hl
    ld (chunk_work), bc
    ld a, (xfer_done) : or a : ret nz
.loop:
    ld bc, (chunk_work)
    ld a, b : or c : ret z
    ld a, (hdr_phase)
    or a : jr z, .phase0
    dec a : jr z, .phase1
    dec a : jr z, .phase2
    dec a : jp z, .phase3
    jp .payload

.phase0: ; HEADER (10 bytes -> hdr_buf)
    ld a, (hdr_pos)
    ld c, a
    ld b, 10
    ld de, hdr_buf
    ld hl, hdr_pos
    call accumulate_phase
    ret nz                  ; Faltan datos, volver a esperar chunk
    ; Fase completa
    call validateHeader : jp c, Wifi_ProtoAbort
    ld hl, (xfer_rem_lo) : ld (total_size_lo), hl
    ld hl, (xfer_rem_hi) : ld (total_size_hi), hl
    ld a, 1 : ld (hdr_phase), a : jr .loop

.phase1: ; FN MARKER (2 bytes -> fn_buf)
    ld a, (fn_pos)
    ld c, a
    ld b, 2
    ld de, fn_buf
    ld hl, fn_pos
    call accumulate_phase
    ret nz
    ld a, (fn_buf) : cp 'F' : jp nz, .badFn
    ld a, (fn_buf+1) : cp 'N' : jp nz, .badFn
    ld a, 2 : ld (hdr_phase), a : jr .loop

.phase2: ; META (3 bytes -> hdr_buf reutilizado)
    ld a, (meta_pos)
    ld c, a
    ld b, 3
    ld de, hdr_buf
    ld hl, meta_pos
    call accumulate_phase
    ret nz
    ; Extraer y validar valores
    ld a, (hdr_buf)    : ld (batch_curr), a
    or a : jp z, Wifi_ProtoAbort                    ; batch_curr must be >= 1
    ld b, a
    ld a, (hdr_buf+1)  : ld (batch_total), a
    or a : jp z, Wifi_ProtoAbort                    ; batch_total must be >= 1
    cp b : jp c, Wifi_ProtoAbort                    ; batch_total must be >= batch_curr
    ld a, (hdr_buf+2)  : ld (name_len), a
    cp 1 : jp c, .badNameLen
    cp 13 : jp nc, .badNameLen
    xor a : ld (name_pos), a
    ld a, 3 : ld (hdr_phase), a : jp .loop

.phase3: ; FILENAME (name_len bytes -> fname_buf)
    ld a, (name_pos)
    ld c, a
    ld a, (name_len)
    ld b, a
    ld de, fname_buf
    ld hl, name_pos
    call accumulate_phase
    ret nz

.p3_done:
    ld a, (name_len) : add a, low fname_buf : ld l, a : ld h, high fname_buf
    xor a : ld (hl), a
    ld a, (probe_mode) : or a : jr z, .p3_normal
    call sendAck : jp recv

.p3_normal:
    call inkWhite

    ; 1. Clear and print filename in double-height
    xor a : call setWaitOffsetPos
    call clearLine42
    xor a : call setWaitOffsetPos

    printMsg msg_filename
    ld a, 4 : call setInk
    ld hl, fname_buf : call Display.putStr

    ; File size in KB or MB
    call inkWhite
    call putSpace
    ld a, '/' : call Display.putC
    call putSpace
    ld hl, (total_size_lo) : ld de, (total_size_hi)
    ld a, d : or a : jr nz, .fn_mb
    ld a, e : cp #10 : jr nc, .fn_mb
    ld b, 10 : call ShiftRightN_32
    call PrintU16Dec
    printMsg msg_ti_kb
    jr .fn_size_done
.fn_mb:
    ld b, 20 : call ShiftRightN_32
    call PrintU16Dec
    printMsg msg_ti_mb
.fn_size_done:

    ; Batch count if > 1
    ld a, (batch_total) : cp 2 : jr c, .skip_batch_cnt
    call putSpace
    ld a, '(' : call Display.putC
    ld a, (batch_curr) : call PrintByteDec
    ld a, '/' : call Display.putC
    ld a, (batch_total) : call PrintByteDec
    ld a, ')' : call Display.putC
.skip_batch_cnt:
    ; Space separator before CRC result
    call putSpace
    ; Save cursor position for CRC text later
    ld hl, (Display.coords) : ld (fname_end_pos), hl
    ; Stretch filename to double-height
    ld a, (wait_row)
    call Display.stretchRow
    xor a : ld c, #47 : call setWaitOffsetDhAttr
    call inkWhite

    ; --- 1. COMPROBACIÓN DE LÍMITE ABSOLUTO (2MB) ---
    ld de, (xfer_rem_hi)        ; Cargamos parte alta del tamaño
    call EsxDOS.checkFileSizeLimit
    jr c, .err_size_limit       ; Si Carry=1, saltamos a error de tamaño

    ; --- 2. COMPROBACIÓN DE ESPACIO EN DISCO ---
    ld hl, (xfer_rem_lo)
    ld de, (xfer_rem_hi)
    call EsxDOS.checkDiskSpace

    cp 1
    jr z, .err_disk_full    ; A=1 -> Disk Full

    ; Si llegamos aquí, todo está bien. Saltamos a space_ok
    call DrawEmptyBar
    call DrawInfoBarLabels
    ld hl, msg_status_xfer : ld c, ATTR_STATUS_NEUTRAL : call Display.showStatus
    jr .space_ok

; --- MANEJADORES DE ERROR ---

.err_size_limit:
    printMsg msg_err_size
    jr .diskAbort

.err_disk_full:
    printMsg msg_err_full
    jr .diskAbort

.diskAbort:
    call showStatusFail
    call BeepError

    ; Sin ACK: el PC debe detener la cola igual que en un fallo de CRC.
    ; Primero limpieza de buffer y UI para evitar lag tras la tecla
    call Wifi_FlushSilence
    call Wifi_UiResetToWaiting

    ; 3. Mensaje de pausa (BLANCO) y espera de tecla
    call inkWhite
    jp pressKeyThenRecv       ; full reset, not recv_no_ui

.space_ok:
    call EsxDOS.setFilenameFromWifi
    call EsxDOS.prepareFile : jp c, .fileCreateFail
    ld a, 1 : ld (file_opened), a
    ; Capture start tick AFTER file open, just before payload
    call ReadIm2Ticks : ld (xfer_start_frames), hl
    ld (last_info_ticks), hl
    call InitProgressGate

    ; Fase 4: Payload
    ld a, 4 : ld (hdr_phase), a
    jp .loop

.payload:
    ld bc, (chunk_work)
    ld hl, (xfer_rem_hi) : ld a, h : or l : jr nz, .lenReady
    ld hl, (xfer_rem_lo) : push hl : or a : sbc hl, bc : pop hl
    jr nc, .lenReady
    ld b, h : ld c, l

.lenReady:
    ld a, b : or c : jr z, .mark_done

    ; --- CHECK DISCARD MODE ---
    ld a, (discard_mode)
    or a
    jr nz, .discard_only

    ; Modo normal: CRC + escribir
    ld hl, (buf_ptr) : push hl : push bc
    call CrcUpdateBuf
    pop bc : pop hl
    call EsxDOS.writeChunkPtr
    jp c, .fatal
    jr .update_counters

.discard_only:
    ; Solo actualizar contadores, no escribir ni CRC

.update_counters:
    push bc : call addDoneBC : pop bc
    ld hl, (buf_ptr) : add hl, bc : ld (buf_ptr), hl
    ; subRemBC inlined
    ld hl, (xfer_rem_lo) : or a : sbc hl, bc : ld (xfer_rem_lo), hl
    ld hl, (xfer_rem_hi) : jr nc, .no_rem_borrow : dec hl
.no_rem_borrow:
    ld (xfer_rem_hi), hl

    ; Skip progress bar en modo discard
    ld a, (discard_mode)
    or a
    jr nz, .skip_progress

    push hl : push de : push bc
    call MaybeUpdateProgressBar
    call MaybeUpdateTransferInfo
    pop bc : pop de : pop hl

.skip_progress:
    ld hl, (xfer_rem_lo) : ld a, h : or l : ret nz
    ld hl, (xfer_rem_hi) : ld a, h : or l : ret nz

.mark_done:
    ; Si estamos en discard mode, mostrar error y reiniciar
    ld a, (discard_mode)
    or a
    jr nz, .discard_complete

    call UpdateProgressBar
    call UpdateTransferInfo

    ; writeData inlined
    ld a, (xfer_done) : or a : jr nz, .skipWD
    ld a, 1 : ld (xfer_done), a
.skipWD:
    ld bc, 0 : ld (chunk_work), bc : ret

.discard_complete:
    ; Cerrar conexión (cliente verá timeout)
    call Wifi_ResetESP
    call Wifi_FlushSilence
    call BeepError

    printMsg msg_protected_error
    jp pressKeyThenRecv

.badFn:
    printMsg msg_badfn : jp Wifi_ProtoAbort

.badNameLen:
    printMsg msg_badnamelen : jp Wifi_ProtoAbort

.fileCreateFail:
    ; Verificar si es error de directorio protegido (A=2)
    cp 2
    jr nz, .generic_create_error

    ; --- DIRECTORIO PROTEGIDO ---
    ; 1. Marcar que estamos en modo descarte
    ld a, 1
    ld (discard_mode), a

    ; 2. Seguir recibiendo datos pero sin escribir
    ;    Reutilizamos el loop de payload pero sin llamar a writeChunkPtr
    ld a, 4 : ld (hdr_phase), a     ; Fase payload
    jp .loop

.generic_create_error:
    printMsg msg_file_create_fail
    ld hl, EsxDOS.filename : call Display.putStr
    call putCR
    jp Wifi_ProtoAbort

.fatal:
    jp Wifi_ProtoAbort


; =============================================================================
; VALIDACIÓN DE HEADER
; =============================================================================
validateHeader:
    ld hl, (hdr_buf)
    ld de, 'L' | ('A' << 8)
    or a : sbc hl, de : jr nz, .badHdr
    ld hl, (hdr_buf+2)
    ld de, 'I' | ('N' << 8)
    or a : sbc hl, de : jr nz, .badHdr
    ld hl, (hdr_buf+4) : ld (xfer_rem_lo), hl
    ld hl, (hdr_buf+6) : ld (xfer_rem_hi), hl
    ld hl, (hdr_buf+8) : ld (expected_crc), hl
    ld hl, #FFFF : ld (crc_cur), hl
    ld hl, (xfer_rem_hi) : ld a, h : or l : jr nz, .notProbe
    ld hl, (xfer_rem_lo) : ld a, h : or l : jr nz, .notProbe
    ld a, 1 : ld (probe_mode), a : ret
.notProbe:
    ; BRIDGEZX: SIN CHEQUEO DE TAMAÑO - CONFIAMOS EN ESXDOS
    xor a : ld (probe_mode), a
    ld l, a : ld h, a : ld (done_lo), hl : ld (done_hi), hl
    ret

.badHdr:
    printMsg msg_badhdr : scf : ret

addDoneBC:
    ld hl, (done_lo) : add hl, bc : ld (done_lo), hl
    ld hl, (done_hi) : jr nc, .no_done_carry : inc hl
.no_done_carry:
    ld (done_hi), hl
    ret

sendAck:
    ld a, (socket_id) : ld (ack_cipsend_id), a
    ld hl, ack_cipsend : call espSendAtCmdZ
    ld bc, 50                 ; Muy corto: ~50 intentos/bytes
.waitPrompt:
    push bc
    call @Uart.uartRead : pop bc : jr nc, .dec
    cp '>' : jr z, .sendPayload
    cp 'E' : ret z            ; ERROR -> salir inmediatamente
    cp 'l' : ret z            ; "link is not" -> salir
    cp '+' : ret z            ; +IPD llegando -> salir, no consumir más
.dec:
    dec bc : ld a, b : or c : jr nz, .waitPrompt
    ret                       ; timeout -> salir
.sendPayload:
    ld hl, ack_payload : jp espSendCmdZ

ack_cipsend: db "+CIPSEND="
ack_cipsend_id: db '0', ",4", 0
ack_payload: db "OK", 0

; =============================================================================
; GET IP (CIFSR)
; =============================================================================
msg_at_cifsr: db "+CIFSR", 0
getMyIp:
    ld hl, msg_at_cifsr : call espSendAtCmdZ
    ld b, 50
.loop:
    push bc
    call Wifi.readByteTimeout
    pop bc
    jr nc, .timeout_err
    cp 'P' : jr z, .infoStart
    djnz .loop
    jr .timeout_err             ; Si agota reintentos sin 'P'
.infoStart:
    push bc : call Wifi.readByteTimeout : pop bc
    jr nc, .timeout_err : cp ',' : jr nz, .loop
    push bc : call Wifi.readByteTimeout : pop bc
    jr nc, .timeout_err : cp '"' : jr nz, .loop
    ld hl, ipAddr
    ld b, 15
.copyIpLoop:
    push hl
    push bc
    call Wifi.readByteTimeout
    pop bc
    pop hl
    jr nc, .timeout_err
    cp '"' : jr z, .finish
    ld (hl), a : inc hl
    djnz .copyIpLoop
    push hl
    call Wifi.readByteTimeout
    pop hl
    jr nc, .timeout_err
    cp '"' : jr nz, .timeout_err
.finish:
    xor a : ld (hl), a : call checkOkErr
    jr c, .timeout_err
    ; Reject empty IP and "0.x.x.x" (no valid ESP IP starts with "0.")
    ld a, (ipAddr) : and a : jr z, .err
    cp '0' : jr nz, .valid
    ld a, (ipAddr+1) : cp '.' : jr z, .err
.valid:
    or a
    ret
.timeout_err:
.err:
    scf
    ret

; =============================================================================
; HELPERS AT/UART
; =============================================================================
espSendZ:
    ld a, (hl) : and a : ret z : call @Uart.write : inc hl : jr espSendZ

; espSendAtCmdZ - Send "AT" + null-terminated string + CRLF
espSendAtCmdZ:
    push hl
    ld hl, at_prefix
    call espSendZ
    pop hl
    ; fall through
; espSendCmdZ - Send null-terminated string + CRLF
espSendCmdZ:
    call espSendZ
    ld hl, .crlf
    jr espSendZ
.crlf: db 13, 10, 0
at_prefix: db "AT", 0

; matchSeq - Match incoming UART bytes against null-terminated string
; Input: HL = pattern (null-terminated)
; Output: ZF=1 if matched, ZF=0 if mismatch or timeout
; Destroys: AF, HL
matchSeq:
    ld a, (hl) : or a : ret z    ; end of pattern = match (ZF=1)
    push hl
    ld c, a
    call readByteShortTimeout
    pop hl
    jr c, .ms_got
    or 1 : ret                    ; timeout → force NZ
.ms_got:
    cp c : ret nz                 ; mismatch → ZF=0
    inc hl : jr matchSeq

checkOkErr:
    call Wifi.readByteTimeout
    jr nc, .timeout_err

    cp 'O' : jr z, .okStart
    cp 'E' : jr z, .errStart
    cp 'F' : jr z, .failStart
    jr checkOkErr

.timeout_err:
    scf
    ret

.okStart:
    call Wifi.readByteTimeout : jr nc, .timeout_err : cp 'K' : jr nz, checkOkErr
    jr .flushToLF

.errStart:
    call Wifi.readByteTimeout : jr nc, .timeout_err : cp 'R' : jr nz, checkOkErr
    call Wifi.readByteTimeout : jr nc, .timeout_err : cp 'R' : jr nz, checkOkErr
    call Wifi.readByteTimeout : jr nc, .timeout_err : cp 'O' : jr nz, checkOkErr
    call Wifi.readByteTimeout : jr nc, .timeout_err : cp 'R' : jr nz, checkOkErr
    jr .flushErr

.failStart:
    call Wifi.readByteTimeout : jr nc, .timeout_err : cp 'A' : jr nz, checkOkErr
    call Wifi.readByteTimeout : jr nc, .timeout_err : cp 'I' : jr nz, checkOkErr
    call Wifi.readByteTimeout : jr nc, .timeout_err : cp 'L' : jr nz, checkOkErr
    jr .flushErr

.flushErr:
    call .flushToLF : scf : ret

.flushToLF:
    call Wifi.readByteTimeout
    ret nc
    cp 10 : jr nz, .flushToLF : ret

; =============================================================================
; Vaciado del buffer UART hasta SILENCIO REAL
; Espera hasta que no lleguen datos por ~100ms (5 HALTs)
; =============================================================================
Wifi_FlushSilence:
    ei
    ld d, 5               ; Necesitamos 5 HALTs sin datos para confirmar silencio

.flush_outer:
    ld bc, 500            ; Máx 500 lecturas por ronda
.flush_inner:
    push bc
    push de
    call @Uart.uartRead
    pop de
    pop bc
    jr nc, .no_data_now

    ; Hay dato - reiniciar contador de silencio
    ld d, 5
    dec bc
    ld a, b : or c
    jr nz, .flush_inner
    jr .flush_outer       ; Límite alcanzado, otra ronda

.no_data_now:
    halt
    dec d
    jr nz, .flush_outer   ; Seguir hasta 5 HALTs sin datos

    ; Silencio confirmado
    ret

; =============================================================================
; Reset completo del ESP para garantizar estado limpio
; =============================================================================
Wifi_ResetESP:
    ; 1. Enviar AT+RST
    ld hl, msg_at_rst
    call Wifi.espSendAtCmdZ

    ; 2. Esperar "ready" (máx 5 segundos = 250 HALTs)
    ld de, 250
.wait_ready:
    halt
    push de

    ; Buscar 'y' de "ready" en cada HALT
    ld b, 30
.check_loop:
    push bc
    call @Uart.uartRead
    pop bc
    jr nc, .no_char
    cp 'y'
    jr z, .got_ready
.no_char:
    djnz .check_loop

    pop de
    dec de
    ld a, d : or e
    jr nz, .wait_ready

    ; Timeout - continuar de todos modos
    jr .configure

.got_ready:
    pop de

    ; 3. Esperar un poco más para estabilizar
    ld b, 50          ; 1 segundo
.stabilize:
    halt
    djnz .stabilize

.configure:
    ; 4. Drenar todo
    call Wifi_FlushSilence

    ; 5. Configurar de nuevo
    ld hl, cmd_list_full : call SendCmdListDrain

    ; 6. Flush final para garantizar canal limpio
    jp Wifi_FlushSilence

; =============================================================================
; AT COMMAND STRINGS + TABLES
; =============================================================================
; AT-prefixed strings: "AT" sent by espSendAtCmdZ helper, only tail stored here
msg_at_rst: db "+RST", 0
msg_ate0: db "E0", 0
msg_cipmux: db "+CIPMUX=1", 0
msg_at_server_on: db "+CIPSERVER=1,6144", 0
msg_at_server_off: db "+CIPSERVER=0", 0
msg_at_cipdinfo: db "+CIPDINFO=0", 0
msg_at_cmd = msg_ate0 + 2
msg_at_close_id: db "+CIPCLOSE=0", 0

; Command list tables
cmd_list_basic:
    dw msg_ate0, msg_at_cipdinfo, msg_cipmux, 0
cmd_list_full:
    dw msg_ate0, msg_at_cipdinfo, msg_cipmux, msg_at_server_on, 0

; SendCmdListCheck - send AT commands from table, check OK/ERR after each
; Input: HL = pointer to word table (null-terminated)
; Output: C=1 if any command failed
SendCmdListCheck:
.loop:
    ld e, (hl) : inc hl
    ld d, (hl) : inc hl
    ld a, d : or e : ret z       ; end of list, C=0 (success)
    push hl
    ex de, hl
    call espSendAtCmdZ
    call checkOkErr
    pop hl
    jr nc, .loop                  ; OK → next command
    ret                           ; C=1 (error)

; SendCmdListDrain - send AT commands from table, drain OK after each
; Input: HL = pointer to word table (null-terminated)
SendCmdListDrain:
.loop:
    ld e, (hl) : inc hl
    ld d, (hl) : inc hl
    ld a, d : or e : ret z
    push hl
    ex de, hl
    call espSendAtCmdZ
    call drainOK
    pop hl
    jr .loop

drainOK:
    ld bc, 200
.loop:
    push bc
    call @Uart.uartRead
    pop bc
    jr nc, .no
    cp 'K' : ret z
.no:
    dec bc
    ld a, b : or c
    jr nz, .loop
    ret

; =============================================================================
; MENSAJES DE ERROR DE PROTOCOLO / DISCO
; =============================================================================
msg_badhdr: db 13, "Bad header", 13, 0
msg_badfn:  db 13, "Bad FN", 13, 0
msg_badnamelen: db 13, "Bad name", 13, 0
msg_file_create_fail:  db 13, "Err: ", 0
msg_deleting: db "Deleting: ", 0
msg_err_full: db 13, 16, 2, "SD full", 13, 0
msg_err_size: db 13, 16, 2, "File >2MB", 13, 0
msg_protected_error: db 13, "Protected dir", 13, 0

; =============================================================================
; VARIABLES Y BUFFERS
; =============================================================================

; --- Variables cleared to 0 on each recv (contiguous block for fast init) ---
; IMPORTANTE: recv borra este bloque con LDIR. No insertar variables no-zero aquí.
recv_zero_start:
discard_mode: db 0
hdr_phase: db 0
hdr_pos: db 0
fn_pos: db 0
meta_pos: db 0
name_pos: db 0
name_len: db 0
file_opened: db 0
xfer_done: db 0
probe_mode: db 0
last_bar_blocks: db 0
last_info_ticks: dw 0
bar_step: dw 0
bar_countdown: dw 0
xfer_rem_lo: dw 0
xfer_rem_hi: dw 0
done_lo: dw 0
done_hi: dw 0
buf_ptr: dw 0
data_avail: dw 0
chunk_work: dw 0
recv_zero_end:

; --- Variables NOT cleared on recv ---
batch_curr: db 0
batch_total: db 0
socket_id: db '0'
wait_row: db 0

; --- Buffers en RAM no inicializada (#7F00+, siempre se escriben antes de leer) ---
hdr_buf   = #7F08      ; 10 bytes
fn_buf    = #7F12      ; 2 bytes
fname_buf = #7F14      ; 13 bytes
ipAddr    = #7F21      ; 16 bytes

; --- Variables en RAM no inicializada (#7F80+) ---
tmp_take          = #7F81   ; 1 byte (scratch de accumulate_phase)
total_size_lo     = #7F8A   ; 2 bytes
total_size_hi     = #7F8C   ; 2 bytes
fast_recv_timeout = #7F8E   ; 2 bytes

    endmodule

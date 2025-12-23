; =============================================================================
; DEFINICIÓN DE MACROS
; =============================================================================
    MACRO EspSend _txt
    ld hl, .txtB
    ld e, .txtE - .txtB
    call Wifi.espSend
    jr .txtE
.txtB: db _txt
.txtE:
    ENDM

    MACRO EspCmd _txt
    ld hl, .txtB
    ld e, .txtE - .txtB
    call Wifi.espSend
    jr .txtE
.txtB: db _txt, 13, 10
.txtE:
    ENDM

    MACRO EspCmdOkErr _txt
    EspCmd _txt
    call Wifi.checkOkErr
    ENDM

    module Wifi

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

    ; 1. Salir modo datos
    EspSend "+++"
    ld b, 20
.wait_exit:
    halt
    djnz .wait_exit

    ; 2. FAST PATH: Verificar si ESP ya está listo
    call probeESP
    jp c, .need_full_reset
    call checkHasIP
    jp c, .need_full_reset
    call checkServerStatus
    jr c, .start_server
    
    ; ESP ya configurado - solo obtener IP y salir
    call getMyIp
    call showListeningInfo
    ret

.start_server:
    ; Tiene IP pero servidor no activo
    EspCmdOkErr "ATE0"
    jp c, .err
    EspCmdOkErr "AT+CIPDINFO=0"
    jp c, .err
    EspCmdOkErr "AT+CIPMUX=1"
    jp c, .err
    EspCmdOkErr "AT+CIPSERVER=1,6144"
    jp c, .err
    call getMyIp
    call showListeningInfo
    ret

.need_full_reset:
    call fullReset
    jp c, .err
    EspCmdOkErr "ATE0"
    jp c, .err
    EspCmdOkErr "AT+CIPDINFO=0"
    jp c, .err
    EspCmdOkErr "AT+CIPMUX=1"
    jp c, .err
    EspCmdOkErr "AT+CIPSERVER=1,6144"
    jp c, .err
    call getMyIp
    call showListeningInfo
    ret

.err:
    ld hl, .err_msg
    call Display.putStr
    di
    halt

.err_msg: db 13, "ESP error! Halted!", 0

; --- VISUALIZACIÓN DE IP (VERDE Y ENMARCADA) ---
showListeningInfo:
    printMsg msg_ink_green
    printMsg msg_separator
    ld hl, msg_listening
    call Display.putStr
    ld hl, ipAddr
    call Display.putStr
    printMsg msg_port_txt
    printMsg msg_separator
    printMsg msg_ink_white
    ret

; =============================================================================
; FAST PATH: DETECCIÓN DE ESTADO
; =============================================================================

probeESP:
    call flushUartQuick
    EspCmd "AT"
    call checkOkErrTimeout
    ret

checkHasIP:
    call flushUartQuick
    EspCmd "AT+CIFSR"
.loop:
    call readByteShortTimeout
    jr nc, .no_ip
    cp 'S'
    jr nz, .check_ok
    call readByteShortTimeout : jr nc, .no_ip : cp 'T' : jr nz, .loop
    call readByteShortTimeout : jr nc, .no_ip : cp 'A' : jr nz, .loop
    call readByteShortTimeout : jr nc, .no_ip : cp 'I' : jr nz, .loop
    call readByteShortTimeout : jr nc, .no_ip : cp 'P' : jr nz, .loop
    call readByteShortTimeout : jr nc, .no_ip : cp ',' : jr nz, .loop
    call readByteShortTimeout : jr nc, .no_ip : cp '"' : jr nz, .loop
    call readByteShortTimeout : jr nc, .no_ip : cp '0' : jr z, .check_zero_ip
    call flushToOK
    or a
    ret
.check_zero_ip:
    call readByteShortTimeout : jr nc, .no_ip : cp '.' : jr nz, .has_ip
    call flushToOK
    scf
    ret
.has_ip:
    call flushToOK
    or a
    ret
.check_ok:
    cp 'O'
    jr nz, .loop
.no_ip:
    scf
    ret

checkServerStatus:
    call flushUartQuick
    EspCmd "AT+CIPSTATUS"
    call flushToOK
    call flushUartQuick
    EspCmd "AT+CIPMUX?"
.mux_loop:
    call readByteShortTimeout : jr nc, .no_server : cp ':' : jr nz, .mux_loop
    call readByteShortTimeout : jr nc, .no_server : cp '1' : jr nz, .no_server
    call flushToOK
    or a
    ret
.no_server:
    call flushToOK
    scf
    ret

; =============================================================================
; COMUNICACIÓN AT
; =============================================================================

fullReset:
    EspCmd "AT+RST"
.wait_ready:
    call Wifi.readByteTimeout : jr nc, .timeout : cp 'y' : jr nz, .wait_ready
.wait_gotip:
    call Wifi.readByteTimeout : jr nc, .timeout : cp 'P' : jr nz, .wait_gotip
    or a
    ret
.timeout:
    scf
    ret

readByteShortTimeout:
    ld b, 100
.loop:
    push bc
    call @Uart.uartRead
    pop bc
    jr c, .got
    djnz .loop
    or a
    ret
.got:
    scf
    ret

flushUartQuick:
    ld b, 10
.loop:
    push bc
    call @Uart.uartRead 
    pop bc
    jr nc, .done 
    djnz .loop
.done:
    ret

flushToOK:
    call readByteShortTimeout : ret nc : cp 'O' : jr nz, flushToOK
    call readByteShortTimeout : ret nc : cp 'K' : jr nz, flushToOK
    ret

checkOkErrTimeout:
    ld c, 0
.loop:
    call readByteShortTimeout : jr nc, .timeout
    cp 'O' : jr z, .okStart
    cp 'E' : jr z, .errStart
    inc c : ld a, c : cp 200 : jr c, .loop
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
    
    jr c, .rbt_got          ; C=1: ¡Dato recibido!

    ; --- GESTIÓN VISUAL "LATIDO" ---
    ld a, (visual_feedback_enabled)
    or a
    jr z, .skip_effect
    
    ld a, l
    or a
    jr nz, .skip_effect
    
    bit 0, h
    jr z, .flash_black
    
    ld a, 1  ; Azul por defecto
    out (#fe), a
    jr .skip_effect

.flash_black:
    xor a
    out (#fe), a            

.skip_effect:
    dec hl
    ld a, h
    or l
    jr nz, .rbt_loop        ; Si HL != 0, seguimos escuchando

    or a                    ; Timeout real (C=0)
    ret      

.rbt_got:
    ld e, a         ; Guardamos byte recibido
    
    ld a, (visual_feedback_enabled)
    dec a           ; Si es 1 (Espera), pasa a 0
    jr z, .set_blue
    
    ; --- MODO TRANSFERENCIA: RUIDO AZUL ---
    ld a, r         
    and 1           ; 0=Negro o 1=Azul
    out (#fe), a    
    
    ld a, e         ; Restauramos A
    scf 
    ret

.set_blue:
    ld a, 1         ; Azul fijo
    out (#fe), a
    ld a, e
    scf
    ret


; =============================================================================
; BUCLE DE RECEPCIÓN (BRIDGEZX MAIN LOOP)
; =============================================================================
recv:
    ; --- REINICIO DE VARIABLES DE ESTADO ---
    di
    ld sp, stack_top
    ei
    xor a
    ld (discard_mode), a
    ld (hdr_phase), a
    ld (hdr_pos), a
    ld (fn_pos), a
    ld (meta_pos), a
    ld (name_pos), a
    ld (name_len), a
    ld (wrote_flag), a
    ld (file_opened), a
    ld (bar_ready), a
    ld (bar_row), a
    ld (xfer_done), a
    ld (probe_mode), a
    ld a, '0'
    ld (socket_id), a
    ld hl, 0
    ld (xfer_rem_lo), hl
    ld (xfer_rem_hi), hl
    ld (done_lo), hl
    ld (done_hi), hl
    ld (buf_ptr), hl
    
    ; ESTADO 1: ESPERA (AZUL)
    ld a, 1
    ld (visual_feedback_enabled), a
    
    ; Limpiar pantalla y poner "Waiting..."
    call Wifi_UiResetToWaiting

; --- ETIQUETA NECESARIA PARA REINICIOS SIN BORRAR PANTALLA ---
recv_no_ui:
    ld a, (wait_row) : or a : jr nz, .wait_ok : ld a, 8 : ld (wait_row), a
.wait_ok:
    ld a, 1 : out (#fe), a
    jp .waitIPD

.rxTimeout:
    jp Wifi_PayloadTimeoutAbort

; -----------------------------------------------------------------------------
; Bucle de espera SIMPLE
; -----------------------------------------------------------------------------
.waitIPD:
.waitIPD_loop:
    call Wifi.readByteTimeout
    jp c, .waitIPD_gotByte      

    ; Timeout real detectado
    ld a, (file_opened)
    or a
    jp nz, Wifi_PayloadTimeoutAbort 

    jp .waitIPD_loop    

.waitIPD_gotByte:
    cp '+' : jp z, .waitIPD_gotPlus
    cp 'C' : jp z, .maybeClosed
    
    jp .waitIPD_loop

.waitIPD_gotPlus:
    ld bc, #A000   
    
    push bc
    call Wifi.readByteTimeout : pop bc : jp nc, .waitIPD_loop : cp 'I' : jp nz, .waitIPD_loop
    push bc
    call Wifi.readByteTimeout : pop bc : jp nc, .waitIPD_loop : cp 'P' : jp nz, .waitIPD_loop
    push bc
    call Wifi.readByteTimeout : pop bc : jp nc, .waitIPD_loop : cp 'D' : jp nz, .waitIPD_loop
    push bc
    call Wifi.readByteTimeout : pop bc : jp nc, .waitIPD_loop : cp ',' : jp nz, .waitIPD_loop

.readSock:
    call Wifi.readByteTimeout : jp nc, .waitIPD
    cp ',' : jr z, .sockDone
    cp '0' : jr c, .readSock
    cp '9'+1 : jr nc, .readSock
    ld (socket_id), a : jr .readSock
.sockDone:
    ld hl,0
.cil1:
    push hl
    call Wifi.readByteTimeout : jr nc, .lenParseTimeout
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
    pop hl : jp .waitIPD
.lenParseInvalid:
    jp .waitIPD
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
    printMsg msg_newline
    call EsxDOS.closeOnly
    call ClearProgressBar

    ; 3. Feedback final
    printMsg msg_ink_green
    printMsg msg_saved_ok
    printMsg msg_ink_white
    call BeepSuccess
    
    ; 4. ACK INMEDIATO (El cliente PC se libera y pone verde)
    call sendAck
    
    ; Acumular bytes a la estadística de sesión (Rutina auxiliar abajo)
    ld hl, (total_size_lo) : ld de, (total_size_hi)
    call AddSessionBytes

    ; --- LÓGICA DE FIN DE LOTE ---
    ld a, (batch_curr)
    ld b, a
    ld a, (batch_total)
    cp b
    jp z, .batch_complete  ; Si Actual == Total, fin del trabajo

    ; Si faltan, seguimos al siguiente
    jp recv 

.batch_complete:
    ; Mostrar Resumen
    call Wifi_UiResetToWaiting ; Limpia pantalla
    ; [FIX ESTÉTICO] Forzar posición del cursor (Fila 10, Col 0)
    ld d, 10
    ld e, 0
    call Display.setPos

    printMsg msg_ink_green
    ld hl, msg_done_txt : call Display.putStr ; "Transfer completed"
    printMsg msg_newline
    printMsg msg_ink_white
    ld hl, msg_total_txt : call Display.putStr ; "Total received: "
    
    ; Imprimir Total Bytes Sesión (Usa tu PrintSmartSize o PrintU32Dec)
    call PrintSessionStats 
    
    printMsg msg_newline
    printMsg msg_newline
    printMsg msg_press_key
    
    ; Resetear contadores de sesión
    xor a
    ld (session_bytes_lo), a : ld (session_bytes_lo+1), a
    ld (session_bytes_hi), a : ld (session_bytes_hi+1), a
    
    call WaitKey
    jp recv

.crc_fail:
    ; --- FALLO (CRC ERROR) ---
    call PrintCrcOverwriteBad
    printMsg msg_newline
    call BeepError
    call EsxDOS.closeOnly
    
    ; Mensaje de borrado
    printMsg msg_deleting       
    printMsg msg_ink_white      
    ld hl, EsxDOS.filename
    call Display.putStr
    printMsg msg_newline
    
    call EsxDOS.deleteFile
    printMsg msg_ink_white
    
    ; [CAMBIO OPCIÓN B] ELIMINADO 'call sendAck'
    ; Al no enviar ACK, el PC esperará y dará Timeout, deteniendo la cola.
    
    ; 2. Pausa obligatoria para ver el error
    printMsg msg_press_key
    call WaitKey

    ; 3. Reinicio
    jp recv

.haveData:
    ld de, 2048 
    or a : sbc hl, de : jr c, .useRemaining
    ld (data_avail), hl
    ld hl, 2048 
    jr .readChunk
.useRemaining:
    ld hl, (data_avail)
    ld de, 0
    ld (data_avail), de

.readChunk:
    push hl
    ld de, buffer
    ld bc, #A800
.loadPacket_loop:
    push bc : push hl : push de
    call Wifi.readByteTimeout
    jr nc, .loadPacket_timeout
    pop de : pop hl : pop bc
    ld (de), a : inc de : dec hl
    ld a, h : or l : jr nz, .loadPacket_loop
    pop bc
    call consumeChunk
    jp .chunkLoop

.loadPacket_timeout:
    pop de : pop hl : pop bc
    dec bc
    ld a, b : or c : jr nz, .loadPacket_loop
    pop bc
    jp .rxTimeout

.maybeClosed:
    call Wifi.readByteTimeout : jp nc, .waitIPD : cp 'L' : jp nz, .waitIPD
    call Wifi.readByteTimeout : jp nc, .waitIPD : cp 'O' : jp nz, .waitIPD
    call Wifi.readByteTimeout : jp nc, .waitIPD : cp 'S' : jp nz, .waitIPD
    call Wifi.readByteTimeout : jp nc, .waitIPD : cp 'E' : jp nz, .waitIPD
    call Wifi.readByteTimeout : jp nc, .waitIPD : cp 'D' : jp nz, .waitIPD
    ld a, (xfer_done) : or a : jr z, .closed_continue
    
    ; Closed after done -> OK, save and loop
    call EsxDOS.closeOnly
    printMsg msg_saved_ok
    printMsg msg_press_key
    call WaitKey
    jp recv

.closed_continue:
    ld a, (hdr_pos) : or a : jp nz, .closed_abort
    ld a, (hdr_phase) : or a : jp nz, .closed_abort
    ld a, (fn_pos) : or a : jp nz, .closed_abort
    ld a, (name_pos) : or a : jp nz, .closed_abort
    ld a, (file_opened) : or a : jp nz, .closed_abort
    jp .waitIPD

; =============================================================================
; RUTINAS DE ABORTO
; =============================================================================
.closed_abort:
    ld sp, stack_top
    xor a
    ld (visual_feedback_enabled), a
    out (#fe), a
    call BeepError
    ld d, 14 : ld e, 0 : call Display.setPos

    ; --- MODIFICACIÓN INICIO ---
    printMsg msg_ink_red        ; <--- 1. Poner ROJO
    printMsg msg_conn_closed    ; Imprime el mensaje
    ; ---------------------------

    ld a, (file_opened)
    or a : jr z, .no_close
    call EsxDOS.closeOnly

    printMsg msg_deleting       ; (Seguirá en rojo porque no lo hemos cambiado)
    ld hl, EsxDOS.filename
    call Display.putStr
    printMsg msg_newline

    call EsxDOS.deleteFile
    xor a
    ld (file_opened), a
.no_close:
    call Wifi_CloseConn0
    call Wifi_FlushSilence

    ; --- MODIFICACIÓN FIN ---
    printMsg msg_ink_white      ; <--- 2. Restaurar BLANCO antes de pedir tecla
    printMsg msg_press_key
    ; ------------------------

    call WaitKey
    jp recv

Wifi_ProtoAbort:
    ld sp, stack_top
    xor a
    ld (visual_feedback_enabled), a
    out (#fe), a
    call BeepError
    ld d, 14 : ld e, 0 : call Display.setPos  
    ; [ELIMINADO] printMsg msg_badhdr (Evita mensajes duplicados)
    ld a, (file_opened)
    or a : jr z, .no_file
    call EsxDOS.closeOnly
    printMsg msg_deleting
    ld hl, EsxDOS.filename
    call Display.putStr
    printMsg msg_newline
    call EsxDOS.deleteFile
    xor a
    ld (file_opened), a
.no_file:
    ; Primero cerramos la conexión y limpiamos el buffer serie
    call Wifi_CloseConn0
    call Wifi_FlushSilence
    ; Ahora pedimos la tecla sin lag posterior
    printMsg msg_press_key
    call WaitKey
    jp recv

Wifi_PayloadTimeoutAbort:
    ld sp, stack_top
    xor a
    ld (visual_feedback_enabled), a
    out (#fe), a
    call BeepError
    ld d, 14 : ld e, 0 : call Display.setPos

    ; --- MODIFICACIÓN INICIO ---
    printMsg msg_ink_white
    printMsg msg_connection_lost  ; Imprime el mensaje
    ; ---------------------------

    ld a, (file_opened)
    or a : jr z, .no_close
    call EsxDOS.closeOnly

    printMsg msg_deleting         ; (Sigue en rojo)
    ld hl, EsxDOS.filename
    call Display.putStr
    printMsg msg_newline

    call EsxDOS.deleteFile
    xor a
    ld (file_opened), a
.no_close:
    
    ; --- MODIFICACIÓN FIN ---
    printMsg msg_ink_white        ; <--- 2. Restaurar BLANCO
    printMsg msg_press_key
    ; ------------------------

    call WaitKey
    call Wifi_CloseConn0
    call Wifi_FlushSilence
    jp recv

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
    or a : jp z, .phase0
    cp 1 : jp z, .phase1
    cp 2 : jp z, .phase2
    cp 3 : jp z, .phase3
    jp .payload

.phase0: ; HEADER
    ld a, (hdr_pos) : cp 10 : jp nc, .p0_done
    ld e, a : ld a, 10 : sub e : ld e, a
    ld bc, (chunk_work)
    ld a, b : or a : jp nz, .p0_take_need
    ld a, c : cp e : jp c, .p0_take_chunk
.p0_take_need:
    ld a, e
.p0_take_chunk:
    ld (tmp_take), a
    ld a, (hdr_pos) : ld l, a : ld h, 0
    ld de, hdr_buf : add hl, de : ex de, hl
    ld hl, (buf_ptr) : ld b, 0 : ld a, (tmp_take) : ld c, a : ldir
    ld a, (hdr_pos) : ld d, a : ld a, (tmp_take) : add a, d : ld (hdr_pos), a
    ld bc, (chunk_work)
    ld a, (tmp_take) : ld e, a : ld a, c : sub e : ld c, a
    ld a, b : sbc a, 0 : ld b, a : ld (chunk_work), bc
    ld hl, (buf_ptr) : ld a, (tmp_take) : ld e, a : ld d, 0 : add hl, de : ld (buf_ptr), hl
.p0_check:
    ld a, (hdr_pos) : cp 10 : ret nz
.p0_done:
    call validateHeader : jp c, Wifi_ProtoAbort
    ld hl, (xfer_rem_lo) : ld (total_size_lo), hl
    ld hl, (xfer_rem_hi) : ld (total_size_hi), hl
    ld a, 1 : ld (hdr_phase), a : jp .loop

.phase1: ; FN MARKER
    ld a, (fn_pos) : cp 2 : jp nc, .p1_done
    ld e, a : ld a, 2 : sub e : ld e, a
    ld bc, (chunk_work)
    ld a, b : or a : jp nz, .p1_take_need
    ld a, c : cp e : jp c, .p1_take_chunk
.p1_take_need:
    ld a, e
.p1_take_chunk:
    ld (tmp_take), a
    ld a, (fn_pos) : ld l, a : ld h, 0
    ld de, fn_buf : add hl, de : ex de, hl
    ld hl, (buf_ptr) : ld b, 0 : ld a, (tmp_take) : ld c, a : ldir
    ld a, (fn_pos) : ld d, a : ld a, (tmp_take) : add a, d : ld (fn_pos), a
    ld bc, (chunk_work)
    ld a, (tmp_take) : ld e, a : ld a, c : sub e : ld c, a
    ld a, b : sbc a, 0 : ld b, a : ld (chunk_work), bc
    ld hl, (buf_ptr) : ld a, (tmp_take) : ld e, a : ld d, 0 : add hl, de : ld (buf_ptr), hl
.p1_check:
    ld a, (fn_pos) : cp 2 : ret nz
.p1_done:
    ld a, (fn_buf) : cp 'F' : jp nz, .badFn
    ld a, (fn_buf+1) : cp 'N' : jp nz, .badFn
    ld a, 2 : ld (hdr_phase), a : jp .loop

.phase2: ; META (Idx, Total, NameLen) - 3 BYTES
    ld a, (meta_pos) : cp 3 : jp nc, .p2_done  ; Esperamos 3 bytes
    ld e, a : ld a, 3 : sub e : ld e, a
    ld bc, (chunk_work)
    ld a, b : or a : jp nz, .p2_take_need
    ld a, c : cp e : jp c, .p2_take_chunk
.p2_take_need:
    ld a, e
.p2_take_chunk:
    ld (tmp_take), a
    ; Usamos meta_buf (asegúrate de definirlo al final o usar hdr_buf reutilizado)
    ; Para no complicarte, reutilizaremos hdr_buf que ya no se usa en esta fase:
    ld a, (meta_pos) : ld l, a : ld h, 0
    ld de, hdr_buf : add hl, de : ex de, hl   ; Guardamos en hdr_buf temporalmente
    ld hl, (buf_ptr) : ld b, 0 : ld a, (tmp_take) : ld c, a : ldir
    ld a, (meta_pos) : ld d, a : ld a, (tmp_take) : add a, d : ld (meta_pos), a
    ld bc, (chunk_work)
    ld a, (tmp_take) : ld e, a : ld a, c : sub e : ld c, a
    ld a, b : sbc a, 0 : ld b, a : ld (chunk_work), bc
    ld hl, (buf_ptr) : ld a, (tmp_take) : ld e, a : ld d, 0 : add hl, de : ld (buf_ptr), hl
.p2_check:
    ld a, (meta_pos) : cp 3 : ret nz
.p2_done:
    ; Extraer valores del buffer temporal (hdr_buf)
    ld a, (hdr_buf)    : ld (batch_curr), a
    ld a, (hdr_buf+1)  : ld (batch_total), a
    ld a, (hdr_buf+2)  : ld (name_len), a

    ; Validar NameLen (igual que antes)
    ld a, (name_len) : cp 1 : jp c, .badNameLen
    cp 13 : jp nc, .badNameLen
    xor a : ld (name_pos), a
    ld a, 3 : ld (hdr_phase), a : jp .loop

.phase3: ; FILENAME
    ld a, (name_len) : ld e, a : ld a, (name_pos) : ld d, a : ld a, e : sub d : ld e, a : jp z, .p3_done
    ld bc, (chunk_work)
    ld a, b : or a : jp nz, .p3_take_rem
    ld a, c : cp e : jp c, .p3_take_chunk
.p3_take_rem:
    ld a, e
.p3_take_chunk:
    ld (tmp_take), a
    ld a, (name_pos) : ld l, a : ld h, 0
    ld de, fname_buf : add hl, de : ex de, hl
    ld hl, (buf_ptr) : ld b, 0 : ld a, (tmp_take) : ld c, a : ldir
    ld a, (name_pos) : ld d, a : ld a, (tmp_take) : add a, d : ld (name_pos), a
    ld bc, (chunk_work)
    ld a, (tmp_take) : ld e, a : ld a, c : sub e : ld c, a
    ld a, b : sbc a, 0 : ld b, a : ld (chunk_work), bc
    ld hl, (buf_ptr) : ld a, (tmp_take) : ld e, a : ld d, 0 : add hl, de : ld (buf_ptr), hl
.p3_check:
    ld a, (name_pos) : ld b, a : ld a, (name_len) : cp b : ret nz

.p3_done:
    ld a, (name_len) : ld l, a : ld h, 0
    ld de, fname_buf : add hl, de : xor a : ld (hl), a
    ld a, (probe_mode) : or a : jr z, .p3_normal
    call sendAck : jp recv

.p3_normal:
    printMsg msg_ink_white
    
    ; 1. Limpiar línea anterior
    ld a, (wait_row) : ld d, a : ld e, 0 : call Display.setPos
    printMsg msg_clear32
    
    ; 2. Reposicionar e imprimir info
    ld a, (wait_row) : ld d, a : ld e, 0 : call Display.setPos
    
    printMsg msg_filename       
    printMsg msg_ink_red        
    ld hl, fname_buf : call Display.putStr 
    ; --- INICIO BLOQUE NUEVO ---
    ld a, (batch_total)
    cp 1
    jr z, .skip_batch_cnt ; Si total es 1 o 0, no mostramos nada
    
    printMsg msg_ink_white ; Volvemos a blanco
    ld a, ' ' : rst 16
    ld a, '(' : rst 16
    ld a, (batch_curr) : call PrintByteDec  ; Rutina auxiliar (ver abajo)
    ld a, '/' : rst 16
    ld a, (batch_total) : call PrintByteDec
    ld a, ')' : rst 16

.skip_batch_cnt:
    printMsg msg_newline
    
    printMsg msg_ink_white      
    printMsg msg_size           
    
    printMsg msg_ink_red        
    ld hl, (xfer_rem_lo) : ld de, (xfer_rem_hi) : call PrintU32Dec
    
    printMsg msg_ink_white      
    printMsg msg_bytes          
    
    call PrintApproxSize
    ; --- 1. COMPROBACIÓN DE LÍMITE ABSOLUTO (2MB) ---
    ld de, (xfer_rem_hi)        ; Cargamos parte alta del tamaño
    call EsxDOS.checkFileSizeLimit
    jp c, .err_size_limit       ; Si Carry=1, saltamos a error de tamaño
    
    ; --- 2. COMPROBACIÓN DE ESPACIO EN DISCO ---
    ld hl, (xfer_rem_lo)
    ld de, (xfer_rem_hi)
    call EsxDOS.checkDiskSpace
    
    cp 1
    jp z, .err_disk_full    ; A=1 -> Disk Full
    
    ; Si llegamos aquí, todo está bien. Saltamos a space_ok
    call DrawEmptyBar
    jp .space_ok

; --- MANEJADORES DE ERROR ---

.err_size_limit:
    printMsg msg_newline
    printMsg msg_ink_red
    printMsg msg_err_size       ; "Error: File > 2MB"
    jp .diskAbort

.err_disk_full:
    printMsg msg_newline        
    printMsg msg_ink_red
    printMsg msg_err_full       
    jp .diskAbort

.diskAbort:
    call BeepError
    
    ; 1. ACK al PC
    call sendAck
    
    ; 2. Primero limpieza de buffer y UI para evitar lag tras la tecla
    call Wifi_FlushSilence 
    call Wifi_UiResetToWaiting
    
    ; 3. Mensaje de pausa (BLANCO) y espera de tecla
    printMsg msg_ink_white
    printMsg msg_press_key
    call WaitKey
    jp recv_no_ui

.space_ok:
    call EsxDOS.setFilenameFromWifi
    call EsxDOS.prepareFile : jp c, .fileCreateFail
    ld a, 1 : ld (file_opened), a
    
    ; Fase 4: Payload
    ld a, 4 : ld (hdr_phase), a 
    ld a, 2 : ld (visual_feedback_enabled), a
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
    call subRemBC
    
    ; Skip progress bar en modo discard
    ld a, (discard_mode)
    or a
    jr nz, .skip_progress
    
    push hl : push de : push bc
    call UpdateProgressBar
    pop bc : pop de : pop hl
    
.skip_progress:
    ld hl, (xfer_rem_lo) : ld a, h : or l : ret nz
    ld hl, (xfer_rem_hi) : ld a, h : or l : ret nz

.mark_done:
    ; Si estamos en discard mode, mostrar error y reiniciar
    ld a, (discard_mode)
    or a
    jr nz, .discard_complete
    
    call writeData
    ld bc, 0 : ld (chunk_work), bc : ret

.discard_complete:
    ; Cerrar conexión (cliente verá timeout)
    call Wifi_CloseConn0
    call Wifi_FlushSilence
    call BeepError
    
    printMsg msg_ink_red
    printMsg msg_protected_error
    printMsg msg_ink_white
    printMsg msg_press_key
    call WaitKey
    jp recv

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
    ld a, 2 : ld (visual_feedback_enabled), a
    jp .loop

.generic_create_error:
    printMsg msg_file_create_fail
    ld hl, EsxDOS.filename : call Display.putStr
    printMsg msg_newline
    jp Wifi_ProtoAbort

.fatal:
    jp Wifi_ProtoAbort

writeData:
    ld a, (xfer_done) : or a : ret nz
    ld a, b : or c : ret z
    ld a, 1 : ld (xfer_done), a
    ; Eliminada llamada a progressFillEnd
    ret

subRemBC:
    ld hl, (xfer_rem_lo) : or a : sbc hl, bc : ld (xfer_rem_lo), hl
    ld hl, (xfer_rem_hi) : ld de, 0 : sbc hl, de : ld (xfer_rem_hi), hl
    ret

; =============================================================================
; UTILIDADES
; =============================================================================
; =============================================================================
; UTILIDADES (CRC MEJORADO Y OPTIMIZADO)
; =============================================================================

; Calcula CRC-16-CCITT (Poly 0x1021) del buffer apuntado por HL con longitud BC
; Entrada: HL=Buffer, BC=Longitud
; Salida: Actualiza variable (crc_cur).
CrcUpdateBuf:
    ld de, (crc_cur)        ; Carga el CRC acumulado actual
.loop_main:
    ld a, b
    or c
    jr z, .save_and_exit

    ; Efecto visual (Rayas Verdes)
    ld a, r
    and 4                   ; Bit 2 = Verde
    out (#fe), a

    ld a, (hl)              ; Carga byte del buffer
    inc hl
    xor d                   ; XOR con la parte alta del CRC
    ld d, a
    
    push bc                 ; Guardamos contador bytes principal
    ld b, 8                 ; Usamos B para el bucle de 8 bits
.loop_bits:
    sla e
    rl d                    ; Shift DE a la izquierda
    jr nc, .skip_xor        ; Si no sale bit 1, saltar XOR

    ld a, e
    xor #21                 ; XOR Poly Low (0x21)
    ld e, a
    ld a, d
    xor #10                 ; XOR Poly High (0x10)
    ld d, a
.skip_xor:
    djnz .loop_bits         ; Siguiente bit
    pop bc                  ; Recuperamos contador bytes principal
    
    dec bc
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

validateHeader:
    ld hl, hdr_buf
    ld a, (hl) : cp 'L' : jp nz, .badHdr : inc hl
    ld a, (hl) : cp 'A' : jp nz, .badHdr : inc hl
    ld a, (hl) : cp 'I' : jp nz, .badHdr : inc hl
    ld a, (hl) : cp 'N' : jp nz, .badHdr
    ld a, (hdr_buf+4) : ld l, a : ld a, (hdr_buf+5) : ld h, a : ld (xfer_rem_lo), hl
    ld a, (hdr_buf+6) : ld l, a : ld a, (hdr_buf+7) : ld h, a : ld (xfer_rem_hi), hl
    ld a, (hdr_buf+8) : ld l, a : ld a, (hdr_buf+9) : ld h, a : ld (expected_crc), hl
    ld hl, #FFFF : ld (crc_cur), hl
    xor a : ld (crc_bad), a
    ld hl, (xfer_rem_hi) : ld a, h : or l : jr nz, .notProbe
    ld hl, (xfer_rem_lo) : ld a, h : or l : jr nz, .notProbe
    ld a, 1 : ld (probe_mode), a : ret
.notProbe:
    ; BRIDGEZX: SIN CHEQUEO DE TAMAÑO - CONFIAMOS EN ESXDOS
    xor a : ld (probe_mode), a
    ld hl, 0 : ld (done_lo), hl : ld (done_hi), hl
    ret

.badHdr:
    printMsg msg_badhdr : scf : ret

addDoneBC:
    ld hl, (done_lo) : add hl, bc : ld (done_lo), hl
    ld hl, (done_hi) : ld de, 0 : adc hl, de : ld (done_hi), hl
    ret

sendAck:
    ld a, (socket_id) : ld (ack_cipsend_id), a
    ld hl, ack_cipsend : call espSendZ
    ld bc, 200
.waitPrompt:
    push bc
    call @Uart.uartRead : pop bc : jr nc, .dec
    cp '>' : jr z, .sendPayload
    cp 'E' : jr z, .abort
    cp 'L' : jr z, .abort
    cp 'C' : jr z, .abort
    jr .waitPrompt
.dec:
    dec bc : ld a, b : or c : jr nz, .waitPrompt
.abort:
    ret
.sendPayload:
    ld hl, ack_payload : call espSendZ
    ret

ack_cipsend: db "AT+CIPSEND="
ack_cipsend_id: db '0', ",4", 13, 10, 0
ack_payload: db "OK", 13, 10, 0

getMyIp:
    EspCmd "AT+CIFSR"
    ld b, 50
.loop:
    push bc
    call Wifi.readByteTimeout
    pop bc
    jp nc, .timeout_err
    cp 'P' : jr z, .infoStart
    djnz .loop
    jr .timeout_err             ; Si agota reintentos sin 'P'
.infoStart:
    call Wifi.readByteTimeout : jr nc, .timeout_err : cp ',' : jr nz, .loop
    call Wifi.readByteTimeout : jr nc, .timeout_err : cp '"' : jr nz, .loop
    ld hl, ipAddr
.copyIpLoop:
    push hl
    call Wifi.readByteTimeout
    pop hl
    jr nc, .timeout_err
    cp '"' : jr z, .finish
    ld (hl), a : inc hl : jr .copyIpLoop
.finish:
    xor a : ld (hl), a : call checkOkErr
    ld hl, ipAddr : ld de, justZeros
.checkZero:
    ld a, (hl) : and a : jr z, .err
    ld b, a : ld a, (de) : cp b : ret nz
    inc hl : inc de : jr .checkZero
.timeout_err:
.err:
    ld hl, .err_connect : call Display.putStr : jr $
.err_connect: db "Use Network Manager and connect to Wifi", 13, "System halted", 0

espSend:
    ld a, (hl) : push hl, de : call @Uart.write : pop de, hl : inc hl : dec e : jr nz, espSend : ret

espSendZ:
    ld a, (hl) : and a : ret z : push hl : call @Uart.write : pop hl : inc hl : jr espSendZ

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
    call Wifi.readByteTimeout : jr nc, .timeout_err : cp 13 : jr nz, checkOkErr
    call .flushToLF : or a : ret
    
.errStart:
    call Wifi.readByteTimeout : jr nc, .timeout_err : cp 'R' : jr nz, checkOkErr 
    call Wifi.readByteTimeout : jr nc, .timeout_err : cp 'R' : jr nz, checkOkErr
    call Wifi.readByteTimeout : jr nc, .timeout_err : cp 'O' : jr nz, checkOkErr 
    call Wifi.readByteTimeout : jr nc, .timeout_err : cp 'R' : jr nz, checkOkErr
    call .flushToLF : scf : ret 
    
.failStart:
    call Wifi.readByteTimeout : jr nc, .timeout_err : cp 'A' : jr nz, checkOkErr 
    call Wifi.readByteTimeout : jr nc, .timeout_err : cp 'I' : jr nz, checkOkErr
    call Wifi.readByteTimeout : jr nc, .timeout_err : cp 'L' : jr nz, checkOkErr 
    call .flushToLF : scf : ret

.flushToLF:
    call Wifi.readByteTimeout
    ret nc
    cp 10 : jr nz, .flushToLF : ret

BeepError:
    ld hl, #0300 : ld de, #0100 : call BeepTone : ret

BeepSuccess:
    ld hl, #0100 : ld de, #0030 : call BeepTone
    ld hl, #0080
.pause1:
    dec hl : ld a, h : or l : jr nz, .pause1
    ld hl, #0100 : ld de, #0020 : call BeepTone : ret

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

PrintU32Dec:
    ; Print 32-bit unsigned value in HL:DE as decimal (supports up to at least 9,999,999)
    ; Store value
    ld (dec_val_lo), hl 
    ld (dec_val_hi), de 
    xor a 
    ld (dec_printed), a

    ; 1,000,000 (0x000F4240)
    ld de, #4240       ; low word
    ld bc, #000F       ; high word
    call DigitSubPrint

    ; 100,000 (0x000186A0)
    ld de, #86A0       ; low word
    ld bc, #0001       ; high word
    call DigitSubPrint

    ; 10,000
    ld de, #2710
    ld bc, #0000
    call DigitSubPrint

    ; 1,000
    ld de, #03E8
    ld bc, #0000
    call DigitSubPrint

    ; 100
    ld de, #0064
    ld bc, #0000
    call DigitSubPrint

    ; 10
    ld de, #000A
    ld bc, #0000
    call DigitSubPrint

    ; 1 (last digit, must print at least one digit)
    ld de, #0001
    ld bc, #0000
    call DigitSubPrintLast
    ret
DF_CC          equ 23684        
approx_cursor: dw 0             
approx_posn:   dw 0

PrintApproxSize:
    ; 1. Guardar direccion memoria (DF_CC) y coordenadas sistema (S_POSN)
    ld hl, (DF_CC)
    ld (approx_cursor), hl
    ld hl, (23688)      ; Variable del sistema S_POSN
    ld (approx_posn), hl

    ; Si < 1KB, no hacemos nada
    ld hl, (xfer_rem_lo)
    ld de, (xfer_rem_hi)
    ld a, d : or e : jr nz, .pas_do
    ld a, h : cp 4 : ret c

.pas_do:
    ; Decidir KB vs MB
    ld a, d : or a : jr nz, .pas_mb
    ld a, e : cp 0x10 : jr nc, .pas_mb

    ; --- KB ---
    ld hl, (xfer_rem_lo) : ld de, (xfer_rem_hi)
    ld b, 10 : call ShiftRightN_32

    ; Imprimir " (" + HL + " KB)"  [SIN TILDE ~]
    ld a, ' ' : rst 16
    ld a, '(' : rst 16
    ld de, 0 : call PrintU32Dec 
    ld hl, msg_kb_suffix : call Display.putStr
    ret

.pas_mb:
    ; --- MB ---
    ld hl, (xfer_rem_lo) : ld de, (xfer_rem_hi)
    ld b, 20 : call ShiftRightN_32

    ; Imprimir " (" + HL + " MB)" [SIN TILDE ~]
    ld a, ' ' : rst 16
    ld a, '(' : rst 16
    ld de, 0 : call PrintU32Dec
    ld hl, msg_mb_suffix : call Display.putStr
    ret
; =============================================================================
; BARRA DE PROGRESO (Estilo [|||||     ])
; =============================================================================
DrawEmptyBar:
    ; Situar cursor 2 líneas bajo el mensaje de espera
    ld a, (wait_row) : add a, 2 : ld d, a : ld e, 0
    call Display.setPos
    
    ld a, 145 : rst 16  ; UDG 'B' (Corchete Izquierdo Gráfico)
    ld b, 30            ; Ancho de la barra
.empty_loop:
    ld a, ' ' : rst 16
    djnz .empty_loop
    ld a, 146 : rst 16  ; UDG 'C' (Corchete Derecho Gráfico)
    ret

ClearProgressBar:
    ld a, (wait_row) : add a, 2 : ld d, a : ld e, 0
    call Display.setPos
    ld hl, msg_clear32
    call Display.putStr
    ret

UpdateProgressBar:
    ; Seleccionamos modo según tamaño (Total en BC, Restante en DE)
    ld hl, (total_size_hi)
    ld a, h : or l
    jr z, .calc_small

    ; --- MODO GRANDE (>64KB) ---
    ld bc, (total_size_hi)
    ld de, (xfer_rem_hi)
    jr .calc_start

.calc_small:
    ; --- MODO PEQUEÑO (<64KB) ---
    ld bc, (total_size_lo)
    ld de, (xfer_rem_lo)

.calc_start:
    ; Si Total=0, salir
    ld a, b : or c : ret z

    ; 1. Calcular TRANSFERIDO = Total - Restante
    ld h, b : ld l, c
    or a : sbc hl, de
    push hl
    
    ; 2. Calcular "PASO" = Total / 32
    ld h, b : ld l, c
    srl h : rr l
    srl h : rr l
    srl h : rr l
    srl h : rr l
    srl h : rr l 
    
    ; Si paso es 0, forzamos 1
    ld a, h : or l : jr nz, .step_ok
    inc hl
.step_ok:
    ld b, h : ld c, l
    
    ; 3. Calcular BLOQUES = Transferido / Paso
    pop hl 
    call Div16 
    
    ; 4. Limitar a 30 bloques
    ld a, l
    cp 30 : jr c, .limit_ok
    ld a, 30
.limit_ok:
    or a : ret z

    ; 5. DIBUJAR LOS BLOQUES
    ld b, a         ; B = Número de bloques
    
    push bc
    ld a, (wait_row) : add a, 2 : ld d, a : ld e, 1
    call Display.setPos
    pop bc
    
    ; --- CAMBIO DE COLOR: INK 6 (AMARILLO) ---
    ld a, 16 : rst 16
    ld a, 6  : rst 16
    ; -----------------------------------------
    
.draw_loop:
    ld a, 144       ; UDG 'A' (Estilo batería)
    rst 16
    djnz .draw_loop

    ; --- RESTAURAR COLOR: INK 7 (BLANCO) ---
    ld a, 16 : rst 16
    ld a, 7  : rst 16
    ; ---------------------------------------
    ret

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

PrintCrcOverwriteOk:
    ; Restaurar coordenadas y memoria para evitar salto de linea
    ld hl, (approx_posn) : ld (23688), hl  ; Restaurar S_POSN
    ld hl, (approx_cursor) : ld (DF_CC), hl ; Restaurar DF_CC
    
    printMsg msg_ink_green
    printMsg msg_crc_ok_txt
    printMsg msg_ink_white
    
    ; Borrar restos de forma segura (recargando A cada vez)
    ld a, ' ' : rst 16
    ld a, ' ' : rst 16
    ld a, ' ' : rst 16
    ret

PrintCrcOverwriteBad:
    ; Restaurar coordenadas y memoria
    ld hl, (approx_posn) : ld (23688), hl
    ld hl, (approx_cursor) : ld (DF_CC), hl
    
    printMsg msg_ink_red_flash
    printMsg msg_crc_bad_txt
    printMsg msg_ink_white
    
    ; Borrar restos de forma segura
    ld a, ' ' : rst 16
    ld a, ' ' : rst 16
    ld a, ' ' : rst 16
    ret

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
    ld a, 1 : ld (dec_printed), a : ld a, d : add a, '0' : rst #10 : ret

DigitSubPrintLast:
    call DigitSubPrint
    ld a, (dec_printed) : or a : ret nz
    ld a, '0' : rst #10 : ld a, 1 : ld (dec_printed), a : ret

WaitErrorReset:
    call Wifi_CloseConn0
    call Wifi_FlushSilence
    call Wifi_UiResetToWaiting
    ret 

Wifi_FlushSilence:
    push af : push bc : push de
    ld de, 30000          
.flush_loop:
    ld a, d : or e : jr z, .timeout
    dec de
    call @Uart.uartRead    
    jr nc, .check_end     
    jr .flush_loop        
.check_end:
    pop de : pop bc : pop af : ret
.timeout:
    pop de : pop bc : pop af : ret
    
Wifi_CloseConn0:
    push hl : push de 
    ld hl, msg_at_close0
    ld e, 15
    call Wifi.espSend
    pop de : pop hl
    ret

msg_at_close0: db "AT+CIPCLOSE=0", 13, 10

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

; --- LIMPIEZA VISUAL AL REINICIAR ---
Wifi_UiResetToWaiting:
    push af : push bc : push de : push hl
    ld a, (wait_row) : cp 8 : jr nc, .row_ok : ld a, 8
.row_ok:
    ld d, a : ld e, 0
    printMsg msg_ink_white

    push de
    call Display.setPos
    ld hl, msg_waiting_local
    call Display.putStr
    pop de

    inc d
.clear_loop:
    ld a, d
    cp 23 
    jr nc, .done
    
    push de
    call Display.setPos
    ld hl, msg_clear32 
    call Display.putStr
    pop de
    
    inc d
    jr .clear_loop

.done:
    pop hl : pop de : pop bc : pop af : ret

; --- Rutinas Auxiliares ---
PrintByteDec:
    ld l, a : ld h, 0 : ld de, 0 : jp PrintU32Dec

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
    ; Aquí puedes llamar a tu rutina que decide si pintar MB/KB/B
    ; O simplemente PrintU32Dec + " Bytes"
    call PrintU32Dec
    ld hl, msg_bytes : call Display.putStr
    ret

; =============================================================================
; VARIABLES Y BUFFERS
; =============================================================================

hdr_phase: db 0
hdr_pos: db 0
fn_pos: db 0
meta_pos: db 0      ; <--- NUEVA (Contador para leer los 3 bytes de metadatos)
batch_curr: db 0    ; <--- NUEVA (Fichero actual)
batch_total: db 0   ; <--- NUEVA (Total ficheros)
name_len: db 0
name_pos: db 0
wrote_flag: db 0
file_opened: db 0
xfer_done: db 0
probe_mode: db 0
socket_id: db '0'
visual_feedback_enabled: db 0
bar_ready: db 0
bar_row: db 0
wait_row: db 0
session_bytes_lo: dw 0       ; 2 bytes
session_bytes_hi: dw 0       ; 2 bytes (contiguo)
dec_printed: db 0
tmp_take: db 0
crc_bad: db 0
dec_val_lo: dw 0
dec_val_hi: dw 0
done_lo: dw 0
done_hi: dw 0
expected_crc: dw 0
crc_cur: dw 0
buf_ptr: dw 0
chunk_work: dw 0
xfer_rem_lo: dw 0
xfer_rem_hi: dw 0
total_size_lo: dw 0
total_size_hi: dw 0
data_avail: dw 0
discard_mode: db 0

hdr_buf: ds 10
fn_buf: ds 2
fname_buf: ds 13
ipAddr: db "000.000.000.000", 0
justZeros: db "0.0.0.0", 0

new_line_only: db 13, 0
msg_badhdr: db 13, "Invalid LAIN header", 13, 0
msg_badlen: db 13, "Invalid length", 13, 0
msg_ink_red: db 16, 2, 0
msg_ink_green: db 16, 4, 0
msg_ink_white: db 16, 7, 0
msg_ink_red_flash: db 16, 2, 18, 1, 0

; --- NUEVOS TEXTOS (INGLÉS) ---
msg_listening: db "Listening on: ", 0 ; Sin salto para encajar
msg_separator: db "--------------------------------", 13, 0
msg_port_txt:  db ":6144", 13, 0
msg_filename:  db "Filename: ", 0
msg_size:      db "Size:     ", 0
msg_bytes:     db " Bytes", 0
msg_approx:    db " (~", 0
msg_kb_suffix: db " KB)", 0
msg_mb_suffix: db " MB)", 0
msg_saved_ok:  db "Transfer successful.", 13, "File saved.", 13, 0
msg_press_key: db 13, "Press any key to restart...", 13, 0
msg_crc_ok_txt:  db " (CRC OK)", 0
msg_crc_bad_txt: db " (Wrong CRC)", 0
msg_done_txt: db "Transfer completed.", 13, 0
msg_total_txt: db "Total received: ", 0

; Errores y varios
msg_badfn:  db 13, "Invalid FN marker", 13, 0
msg_badnamelen: db 13, "Invalid filename length", 13, 0
msg_conn_closed: db 13, "Connection closed", 0
msg_crc_bad_del: db 13, "CRC Error! Deleted.", 0
msg_ipd_inconsistent: db 13, "Protocol error (IPD length)", 13, 0
msg_file_create_fail:  db 13, "ERROR: cannot create ", 0
msg_file_create_fail2: db 13, "System halted", 13, 0
msg_deleting: db 13, "Deleting: ", 0
msg_newline: db 13, 0
msg_clear32: db "                                ", 0
msg_waiting_local: db "Waiting for files...            ", 13, 0
msg_resetting_now: db "Resetting connection...", 13, 0
msg_connection_lost: db 13, "Connection lost...", 13, 0
msg_err_full: db "Error: Not enough space in SD", 13, 0
msg_err_sys:  db "Error: SD Card I/O Error", 13, 0
msg_err_size: db " Error: File too large (>2MB)", 13, 0
msg_protected_error: db 13, "Error: Saving in protected dir", 13, 0
    endmodule
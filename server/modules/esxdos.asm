    module EsxDOS

ESX_GETSETDRV = #89
ESX_FOPEN = #9A
ESX_FCLOSE = #9B
ESX_FSYNC = #9C
ESX_FWRITE = #9E
ESX_GETFREE = #B1
ESX_UNLINK = #AD
ESX_GETCD = #A8             ; Obtener directorio actual

FMODE_CREATE = #0E

; ====================================================================
; Verificar si estamos en un directorio protegido
; Salida: Carry=1 si protegido (no escribir), Carry=0 si OK
; ====================================================================
checkProtectedDir:
    ; Obtener directorio actual en buffer temporal
    ld hl, dir_buffer
    push hl : pop ix
    ld a, '*'
    rst #8 : db ESX_GETCD
    jr c, .not_protected        ; Si falla, permitir (no bloquear)
    
    ; 3. Comparar con directorios protegidos
    ; El path viene como "/BIN", "/SYS", etc.
    ; /BIN no protegido para permitir auto-actualización vía BridgeZX
    
    ld hl, dir_buffer
    ld a, (hl)
    cp '/'                      ; Debe empezar con /
    jr nz, .not_protected
    inc hl
    
    ; Verificar /SYS  
    ld de, prot_sys
    call .cmpDir
    jr z, .is_protected
    
    ; Verificar /TMP  
    ld hl, dir_buffer + 1
    ld de, prot_tmp
    call .cmpDir
    jr z, .is_protected
    
.not_protected:
    or a                        ; Carry = 0 (OK)
    ret
    
.is_protected:
    scf                         ; Carry = 1 (Protegido)
    ret

; Compara directorio (case-insensitive)
; HL = string actual (después de /), DE = string esperado (ej: "BIN")
; Z=1 si coincide el directorio
.cmpDir:
    push hl
.cmp_loop:
    ld a, (de)
    or a
    jr z, .cmp_end_pattern      ; Fin del patrón
    
    ld c, a                     ; Guardar char esperado
    ld a, (hl)
    and #DF                     ; Force uppercase (a-z -> A-Z)
    cp c
    jr nz, .cmp_fail            ; No coincide
    
    inc hl
    inc de
    jr .cmp_loop
    
.cmp_end_pattern:
    ; Patrón terminó, verificar que dir también termine o sea subdir
    ld a, (hl)
    or a                        ; Fin de string = match exacto
    jr z, .cmp_match
    cp '/'                      ; Subdirectorio = también protegido
    jr z, .cmp_match
    
.cmp_fail:
    pop hl
    or 1                        ; Z = 0 (no coincide)
    ret

.cmp_match:
    pop hl
    xor a                       ; Z = 1 (coincide)
    ret

; Patrones de directorios protegidos (MAYÚSCULAS)
prot_sys: db "SYS", 0
prot_tmp: db "TMP", 0

; Buffer para directorio actual.
; esxDOS paths can be 127 bytes plus NUL; keep this below #7F00 scratch RAM.
DIR_BUFFER_SIZE = 128
dir_buffer = #7E80

; ====================================================================
; Build filename from Wifi.fname_buf (ASCIIZ)
; ====================================================================
setFilenameFromWifi:
    ld de, filename
    ld hl, Wifi.fname_buf
    ld b, 12
    ld c, 1                  
.sf_loop:
    ld a, (hl)
    or a
    jr z, .sf_done
    cp 32 : jr c, .sf_ctrl      ; control chars < 32 → underscore
    jr nz, .sf_filter
    ld a, c : or a : ld a, 32 : jr z, .sf_filter
.sf_ctrl:
    ld a, '_'
.sf_filter:
    cp 127 : jr z, .sf_ctrl     ; DEL → underscore
    push hl : push bc
    ld hl, .forbidden : ld b, a
.sf_chk:
    ld a, (hl) : or a : jr z, .sf_ok
    cp b : jr z, .sf_bad
    inc hl : jr .sf_chk
.sf_bad:
    ld b, '_'
.sf_ok:
    ld a, b : pop bc : pop hl
    jr .sf_store
.forbidden: db '/', '\', '*', '?', '<', '>', '|', '"', ':', 0
.sf_store:
    ld (de), a
    inc de : inc hl : xor a : ld c, a
    djnz .sf_loop
.sf_done:
    xor a : ld (de), a
    ret

deleteFile:
    xor a
    rst #8 : db ESX_GETSETDRV
    ld hl, filename
    push hl : pop ix            ; esxDOS quirk: some calls require HL=path AND IX=path
    rst #8 : db ESX_UNLINK
    ret

; ====================================================================
; Preparar archivo para escritura (con protección de directorios)
; ====================================================================
prepareFile:
    ; --- Verificar directorio protegido ---
    call checkProtectedDir
    jr nc, .dir_ok
    
    ; Directorio protegido - retornar código 2, sin mensaje
    ld a, 2
    scf
    ret
    
.dir_ok:
    xor a
    rst #8 : db ESX_GETSETDRV
    jr nc, .drv_ok
    push af
    printMsg msg_drv_err
    pop af
    call PrintHexA
    jr .err_done
.drv_ok:
    ld hl, filename
    push hl : pop ix            ; esxDOS FOPEN here requires HL=path + IX=path
    ld b, FMODE_CREATE
    rst #8 : db ESX_FOPEN
    jr c, .err

    ld (fhandle), a
    ret
.err:
    push af
    printMsg msg_fopen_err
    pop af
    call PrintHexA
    printMsg msg_fopen_file
    ld hl, filename
    call Display.putStr
.err_done:
    call @Wifi.putCR
    scf
    ret

writeChunkPtr:
    ld a, (fhandle)
    ld ix, hl
    push bc
    rst #8 : db ESX_FWRITE
    pop de
    jr c, .fwrite_err_ptr
    ld a, b
    cp d
    jr nz, .partial_write
    ld a, c
    cp e
    jr nz, .partial_write

    or a
    ret

.partial_write:
    ld a, #FF
.fwrite_err_ptr:
    push af
    printMsg msg_fwrite
    pop af
    call PrintHexA
    call @Wifi.putCR
    or a
    scf
    ret

closeOnly:
    ld a, (fhandle)
    cp 255              ; ¿Handle inválido?
    ret z               ; Si es 255, no hay nada que cerrar

    rst #8 : db ESX_FSYNC
    jr c, .fsync_err
    ld a, (fhandle)
    rst #8 : db ESX_FCLOSE
    jr c, .finish_error
    ld a, 255
    ld (fhandle), a
    or a
    ret

.fsync_err:
    push af
    ld a, (fhandle)
    rst #8 : db ESX_FCLOSE
    pop af

.finish_error:
    scf
    push af
    ld a, 255
    ld (fhandle), a
    pop af
    ret

;; ====================================================================
; Comprobación de espacio en disco
; ====================================================================
checkDiskSpace:
    ld a, '*'
    rst #8 : db ESX_GETFREE 
    jr c, .skip_check

    ld a, b
    or c
    jr nz, .space_ok

    ld a, d
    or a
    jr nz, .space_ok
    
    ld a, e
    cp 10            
    jr c, .disk_full

.space_ok:
.skip_check:
    xor a
    ret

.disk_full:
    ld a, 1
    ret

; ====================================================================
; Comprobar límite de tamaño (2 MB)
; ====================================================================
checkFileSizeLimit:
    ld a, d
    or a
    jr nz, .too_big
    
    ld a, e
    cp #20
    jr nc, .too_big
    
    or a
    ret

.too_big:
    scf
    ret


PrintHexA:
    push af : rrca : rrca : rrca : rrca : call .Nib : pop af : jr .Nib
.Nib:
    and #0F : add a, '0' : cp '9'+1 : jr c, .out : add a, 7
.out:
    jp Display.putC

msg_fwrite db "FW err A=", 0
msg_drv_err db "Drv err A=", 0
msg_fopen_err db "FO err A=", 0
msg_fopen_file db 13, "F:", 0
fhandle db 255          ; 255 = sin handle abierto
filename = #7F71       ; 13 bytes — uninit RAM

    endmodule

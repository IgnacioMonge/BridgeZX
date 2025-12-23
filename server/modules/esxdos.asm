    module EsxDOS

ESX_GETSETDRV = #89
ESX_FOPEN = #9A
ESX_FCLOSE = #9B
ESX_FSYNC = #9C
ESX_FWRITE = #9E
ESX_GETFREE = #9F
ESX_UNLINK = #AD
ESX_GETCD = #A8             ; Obtener directorio actual

FMODE_CREATE = #0E

; ====================================================================
; Verificar si estamos en un directorio protegido
; Salida: Carry=1 si protegido (no escribir), Carry=0 si OK
; ====================================================================
checkProtectedDir:
    ; 1. Obtener unidad actual
    xor a
    rst #8 : db ESX_GETSETDRV
    ret c                       ; Si falla, permitir (no bloquear)
    
    ; 2. Obtener directorio actual en buffer temporal
    ld hl, dir_buffer
    rst #8 : db ESX_GETCD
    ret c                       ; Si falla, permitir
    
    ; 3. Comparar con directorios protegidos
    ; El path viene como "/BIN", "/SYS", etc.
    
    ld hl, dir_buffer
    ld a, (hl)
    cp '/'                      ; Debe empezar con /
    jr nz, .not_protected
    inc hl
    
    ; Verificar /BIN
    ld de, prot_bin
    call .cmpDir
    jr z, .is_protected
    
    ; Verificar /SYS  
    ld hl, dir_buffer + 1
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
    
    ; Convertir a mayúscula si es minúscula
    cp 'a'
    jr c, .no_upper
    cp 'z'+1
    jr nc, .no_upper
    sub 32                      ; a-z -> A-Z
.no_upper:
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
prot_bin: db "BIN", 0
prot_sys: db "SYS", 0
prot_tmp: db "TMP", 0

; Buffer para directorio actual
dir_buffer: ds 64

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
    cp 32 : jr nz, .sf_filter
    ld a, c : or a : ld a, 32 : jr z, .sf_filter
    ld a, '_'
.sf_filter:
    cp 47 : jr z, .sf_us
    cp 92 : jr z, .sf_us
    cp 42 : jr z, .sf_us
    cp 63 : jr z, .sf_us
    cp 60 : jr z, .sf_us
    cp 62 : jr z, .sf_us
    cp 124 : jr z, .sf_us
    cp 34 : jr z, .sf_us
    jr .sf_store
.sf_us:
    ld a, '_'
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
    ld ix, filename
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
    ld a, 13 : rst #10
    scf
    ret
.drv_ok:
    ld hl, filename
    ld ix, filename
    ld b, FMODE_CREATE
    rst #8 : db ESX_FOPEN
    jp c, .err

    ld (fhandle), a
    xor a
    ld (total_written), a
    ld (total_written+1), a
    ld (total_written+2), a
    ld (total_written+3), a
    ret
.err:
    push af
    printMsg msg_fopen_err
    pop af
    call PrintHexA
    printMsg msg_fopen_file
    ld hl, filename
    ld ix, filename
    call Display.putStr
    ld a, 13 : rst #10
    scf
    ret

writeChunkPtr:
    ld a, (fhandle)
    ld ix, hl
    push bc
    rst #8 : db ESX_FWRITE
    pop bc
    jr c, .fwrite_err_ptr

    ld hl, total_written
    ld a, (hl) : add a, c : ld (hl), a
    inc hl
    ld a, (hl) : adc a, b : ld (hl), a
    inc hl
    ld a, (hl) : adc a, 0 : ld (hl), a
    inc hl
    ld a, (hl) : adc a, 0 : ld (hl), a
    or a
    ret

.fwrite_err_ptr:
    push af
    printMsg msg_fwrite
    pop af
    call PrintHexA
    ld a, 13 : rst #10
    or a
    scf
    ret

closeOnly:
    ld a, (fhandle)
    rst #8 : db ESX_FSYNC
    ld a, (fhandle)
    rst #8 : db ESX_FCLOSE
    ret

;; ====================================================================
; Comprobación de espacio en disco
; ====================================================================
checkDiskSpace:
    xor a
    rst #8 : db ESX_GETSETDRV
    jr c, .skip_check
    
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
    push af : rrca : rrca : rrca : rrca : call .Nib : pop af : call .Nib : ret
.Nib:
    and #0F : add a, '0' : cp '9'+1 : jr c, .out : add a, 7
.out:
    rst #10 : ret

msg_fwrite db "FWRITE error A=", 0
msg_fsync  db "FSYNC error A=", 0
msg_fclose db "FCLOSE error A=", 0
msg_drv_err db "Drive error A=", 0
msg_fopen_err db "FOPEN error A=", 0
msg_fopen_file db 13, "File: ", 0
msg_protected_dir db 13, "ERROR: Protected dir (BIN/SYS/TMP)", 13, 0
total_written db 0,0,0,0
fhandle db 0
filename ds 13
    ds 12
    db 0

    endmodule

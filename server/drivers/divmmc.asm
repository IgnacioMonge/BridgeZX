    DEFINE FAST_UART

    module Uart
;;
;; divmmc.asm - UART driver for divMMC / divTIesus (unified)
;; Ported from SpectalkZX optimized driver (divmmc_uart.asm)
;;
;; Both devices share the ZX-Uno compatible UART register interface.
;; Hardware UART at 115200 baud — no DI/EI needed.
;;

; ZX-Uno compatible register interface
UART_DATA_REG     = #C6
UART_STAT_REG     = #C7
UART_BYTE_RECEIVED = #80
UART_BYTE_SENDING  = #40
ZXUNO_ADDR        = #FC3B
ZXUNO_REG         = #FD3B

; State variables
_is_recv     db 0


; =============================================================================
; INIT - Initialize UART, flush buffers
; =============================================================================
init:
    xor a
    ld (_is_recv), a

    ; Prime status register read
    ld bc, ZXUNO_ADDR
    ld a, UART_STAT_REG
    out (c), a
    inc b                       ; FC3B -> FD3B
    in a, (c)

    ; Prime data register read
    dec b                       ; FD3B -> FC3B
    ld a, UART_DATA_REG
    out (c), a
    inc b                       ; FC3B -> FD3B
    in a, (c)

    ; Wait + drain (10 frames)
    ld b, 10
.init_wait:
    push bc
    call uartRead
    pop bc
    halt
    djnz .init_wait

    ; Flush remaining bytes until silence or a bounded noisy-line cutoff
    ld de, 1000
.flush:
    push de
    call uartRead
    pop de
    ret nc
    dec de
    ld a, d
    or e
    jr nz, .flush
    ret


; =============================================================================
; WRITE - Send byte in A
; =============================================================================
write:
    push bc
    push af

    ; Check if a byte arrived while we're about to send
    ld bc, ZXUNO_ADDR
    ld a, UART_STAT_REG
    out (c), a
    inc b                       ; FC3B -> FD3B
    in a, (c)
    and UART_BYTE_RECEIVED
    jr z, .check_tx

    ld a, 1
    ld (_is_recv), a

.check_tx:
.wait_tx:
    in a, (c)
    and UART_BYTE_SENDING
    jr nz, .wait_tx

    ; Select data register and send
    dec b                       ; FD3B -> FC3B
    ld a, UART_DATA_REG
    out (c), a
    inc b                       ; FC3B -> FD3B

    pop af
    out (c), a

    pop bc
    ret


; =============================================================================
; UARTREAD - Read byte if available
; Returns: CF=1, A=byte if data available; CF=0 if no data
; =============================================================================
uartRead:
    ld a, (_is_recv)
    or a
    jr nz, .do_read

    ; Check hardware
    ld bc, ZXUNO_ADDR
    ld a, UART_STAT_REG
    out (c), a
    inc b                       ; FC3B -> FD3B
    in a, (c)
    add a, a                    ; bit 7 -> CF
    ret nc

.do_read:
    ld bc, ZXUNO_ADDR
    ld a, UART_DATA_REG
    out (c), a
    xor a
    ld (_is_recv), a
    inc b                       ; FC3B -> FD3B
    in a, (c)

    ; Return data
    scf                         ; CF=1 (data)
    ret

    endmodule

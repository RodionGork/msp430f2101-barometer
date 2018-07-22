; for MSP430F2101

.include "msp430x2xx.inc"

.entry_point start

BAUD_RATE equ 9600

CALDCO_1MHZ equ 10FEh
CALBC1_1MHZ equ 10FFh
RAM_START equ 200h
RAM_SIZE equ 128

PIN_SDA equ 1   ; on port 2
PIN_SCL equ 0   ; on port 2

.org 0F800h
start:
    mov.w #WDTPW|WDTHOLD, &WDTCTL
    mov.w #(RAM_START + RAM_SIZE), SP
    mov.b &CALBC1_1MHZ, &BCSCTL1
    mov.b &CALDCO_1MHZ, &DCOCTL
    mov.b #3, &P1DIR
    mov.b #0, &P2REN
    mov.b #0, &P2DIR
    mov.b #0, &P2OUT

    call #RESET_SENSOR

repeat:
    mov.b #21h, r9
    mov.b #1, r8
    call #I2C_SEND
    wait_complete:
    mov.b #21h, r8
    call #I2C_RECEIVE
    bit.b #1, r8
    jnz wait_complete
    
    call #pressure
    mov.b #' ', r8
    call #UART_SEND
    mov.w #1000, r8
    call #DELAY
    call #temperature
    mov.b #13, r8
    call #UART_SEND
    mov.b #10, r8
    call #UART_SEND
    mov.w #4000, r8
    call #DELAY
    jmp repeat

pressure:
    mov.b #2Ah, r8
    call #I2C_RECEIVE
    mov.b r8, r10
    swpb r10
    mov.b #29h, r8
    call #I2C_RECEIVE
    bic.w #0FF00h, r8
    add.w r8, r10
    mov.w r10, r8
    sub.w #14932, r10
    rla.w r10
    rla.w r10
    rla.w r10
    rla.w r10
    mov.w #341, r9
    call #DIVIDE_AND_PRINT
    ret

temperature:
    mov.b #2Ch, r8
    call #I2C_RECEIVE
    mov.b r8, r10
    swpb r10
    mov.b #2Bh, r8
    call #I2C_RECEIVE
    bic.w #0FF00h, r8
    add.w r8, r10
    mov.w r10, r8
    add.w #20400, r10
    mov.w #480, r9
    call #DIVIDE_AND_PRINT
    ret

DIVIDE_AND_PRINT:
    call #DIVIDE_SUB
    call #TO_DECIMAL
    push r8
    mov r9, r8
    call #BLINK_DECIMAL
    call #UART_SEND_H1
    pop r8
    call #BLINK_DECIMAL
    call #UART_SEND_H1
    ret

;========
; indicates value from R8
; by blinks on P1.0
; long blink is 5, short is 1
; two long means 0, not 10
BLINK_DECIMAL:
    push r8
    push r9
    cmp.b #0, r8
    jne blink_decimal_nz
    mov.w #1000, r9
    call #BLINK_MS
    add.b #5, r8
    blink_decimal_nz:
    cmp.b #5, r8
    jlo blink_decimal_ones
    mov.w #1000, r9
    call #BLINK_MS
    sub.b #5, r8
    blink_decimal_ones:
    cmp.b #0, r8
    jeq blink_decimal_stop
    mov.w #300, r9
    call #BLINK_MS
    dec.b r8
    jmp blink_decimal_ones
    blink_decimal_stop:
    mov.w #800, r8
    call #DELAY
    pop r9
    pop r8
    ret

;=========================
; blinks on P1.0 for R9 ms
BLINK_MS:
    push r8
    mov r9, r8
    bis.b #1, &P1OUT
    call #DELAY
    bic.b #1, &P1OUT
    mov #200, r8
    call #DELAY
    pop r8
    ret

;===============
; r8 = r10 / r9
DIVIDE_SUB:
    push r10
    mov.w #0, r8
    divide_rep:
    inc.w r8
    sub.w r9, r10
    jc divide_rep
    pop r10
    ret

;========================
; r8 -> r9:r8 (both 0..9)
TO_DECIMAL:
    mov.w #0, r9
    to_decimal_0:
    cmp #0, r8
    jeq to_decimal_1
    dec r8
    clrc
    dadd #1, r9
    jmp to_decimal_0
    to_decimal_1:
    mov.b r9, r8
    bic.b #0F0h, r8
    rra.b r9
    rra.b r9
    rra.b r9
    rra.b r9
    ret

;============
RESET_SENSOR:
    mov.w #100, r8
    call #DELAY
    call #I2C_STOP
    mov.b #20, r8
    reset_sensor_i2c:
    call #I2C_SCL_LO
    call #I2C_SCL_HI
    dec r8
    jnz reset_sensor_i2c
    call #I2C_START
    call #I2C_STOP
    mov.b #20h, r9
    mov.b #00h, r8
    call #I2C_SEND
    mov.b #20h, r9
    mov.b #80h, r8
    call #I2C_SEND
    ret

;========
; r9 - addr, r8 - data
I2C_SEND:
    push r8
    call #I2C_START
    mov  #(5Ch * 2), r8
    call #I2C_WRITE_BYTE
    mov r9, r8
    call #I2C_WRITE_BYTE
    pop r8
    call #I2C_WRITE_BYTE
    call #I2C_STOP
    ret

;=========
; r8 - addr
I2C_RECEIVE:
    push r8
    call #I2C_START
    mov  #(5Ch * 2), r8
    call #I2C_WRITE_BYTE
    pop r8
    call #I2C_WRITE_BYTE
    call #I2C_START
    mov  #(5Ch * 2 + 1), r8
    call #I2C_WRITE_BYTE
    call #I2C_READ_BYTE
    call #I2C_STOP
    ret

;======
I2C_WRITE_BYTE:
    push r9
    mov.b #8, r9
    i2c_write_rep:
    bit.b #80h, r8
    jz i2c_write_0
    call #I2C_SDA_HI
    jmp i2c_write_bit
    i2c_write_0:
    call #I2C_SDA_LO
    i2c_write_bit:
    call #I2C_SCL_HI
    call #I2C_SCL_LO
    rla.w r8
    dec r9
    jnz i2c_write_rep
    call #I2C_SDA_HI
    call #I2C_SCL_HI
    mov.b &P2IN, r8
    and.b #(1 << PIN_SDA), r8
    call #I2C_SCL_LO
    pop r9
    ret

;======
I2C_READ_BYTE:
    push r9
    mov.b #9, r9
    mov.w #0, r8
    call #I2C_SDA_HI
    i2c_read_rep:
    call #I2C_SCL_HI
    rla.w r8
    bit.b #(1 << PIN_SDA), &P2IN
    jz i2c_read_0
    bis.w #1, r8
    i2c_read_0:
    call #I2C_SCL_LO
    dec r9
    jnz i2c_read_rep
    rrc.w r8
    pop r9
    ret

;=========
I2C_START:
    call #I2C_SCL_HI
    call #I2C_SDA_LO
    call #I2C_SCL_LO
    ret

I2C_STOP:
    call #I2C_SCL_LO
    call #I2C_SDA_LO
    call #I2C_SCL_HI
    call #I2C_SDA_HI
    ret

;=================================
; scl and sda pin control routines
I2C_SCL_LO:
    bis.b #(1 << PIN_SCL), &P2DIR
    call #I2C_DELAY
    ret
I2C_SCL_HI:
    bic.b #(1 << PIN_SCL), &P2DIR
    call #I2C_DELAY
    ret
I2C_SDA_LO:
    bis.b #(1 << PIN_SDA), &P2DIR
    call #I2C_DELAY
    ret
I2C_SDA_HI:
    bic.b #(1 << PIN_SDA), &P2DIR
    call #I2C_DELAY
    ret
I2C_DELAY:
    push r8
    mov.w #10, r8
    i2c_delay_repeat:
    dec r8
    jnz i2c_delay_repeat
    pop r8
    ret

;=======================
; sends hex char from r8
UART_SEND_H1:
    push r8
    bic.b #0F0h, r8
    add.b #'0', r8
    cmp.b #('9' + 1), r8
    jn uart_send_h_dec
    add.b #('A'-'0'-10), r8
    uart_send_h_dec:
    call #UART_SEND
    pop r8
    ret

;========================
; sends character from r8
UART_SEND:
    push r8
    mov.w #(1000000 / BAUD_RATE - 1), &TACCR0
    mov.w #210h, &TACTL
    bic.w #0FE00h, r8
    bis.w #100h, r8
    rla.w r8

    uart_send_rep:
    bit.b #1, &TACCTL0
    jz uart_send_rep
    mov.b #0, &TACCTL0

    bit.w #1, r8
    jz uart_send_0
    bis.b #2, &P1OUT
    jmp uart_send_ok
    uart_send_0:
    bic.b #2, &P1OUT

    uart_send_ok:
    rra.w r8
    jnz uart_send_rep

    mov.w #0, &TACTL
    pop r8
    ret

;============================
; delay for (R8) milliseconds
DELAY:
    push r8
    push r9
    delay_rep0:
    mov.w #358, r9
    delay_rep:
    dec.w r9
    jnz delay_rep
    dec.w r8
    jnz delay_rep0
    pop r9
    pop r8
    ret    

.org 0FFFEh
  dw start

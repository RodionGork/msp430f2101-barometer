; for MSP430F2101

.include "msp430x2xx.inc"

.entry_point start

RAM_START equ 200h
RAM_SIZE equ 128

I2C_ADDR_PRESSURE equ 5Dh
I2C_ADDR_HUMIDITY equ 5Ch
INFO_MEM_START equ 1000h
PRESSURE_CALIBRATION equ (INFO_MEM_START + 0)
TEMPERATURE_CALIBRATION equ (INFO_MEM_START + 2)

PIN_SDA equ 1   ; on port 2
PIN_SCL equ 0   ; on port 2

.org 0F800h
start:
    mov.w #WDTPW|WDTHOLD, &WDTCTL
    mov.w #(RAM_START + RAM_SIZE), SP
    mov.b #0, &P1REN
    mov.b #0, &P1DIR
    mov.b #0, &P2REN
    mov.b #0, &P2DIR
    mov.b #0, &P2OUT

repeat:
    call #RESET_SENSOR
    
    call #PRESSURE
    mov.w #1000, r8
    call #DELAY
    call #TEMPERATURE
    mov.w #1000, r8
    call #DELAY
    
    call #POWER_DOWN
    
    jmp repeat

POWER_DOWN:
    mov.b #I2C_ADDR_PRESSURE, r13
    mov.b #20h, r9
    mov.b #00h, r8
    call #I2C_SEND
    mov.b #0, &P1DIR
    mov.b #0, &P1REN
    mov.b #0, &P2DIR
    mov.b #0, &P2REN
    bis.b #1000b, &P2DIR
    bic.b #1000b, &P2OUT
    bis.b #0FFh, &P1DIR
    mov.b #7Fh, &P1OUT
    mov.b #0F0h, sr
    ret

PRESSURE:
    mov.b #I2C_ADDR_PRESSURE, r13
    ;start measurement
    mov.b #21h, r9
    mov.b #1, r8
    call #I2C_SEND
    wait_complete:
    mov.b #21h, r8
    call #I2C_RECEIVE
    bit.b #1, r8
    jnz wait_complete
    ;receive results
    mov.b #2Ah, r8
    call #I2C_RECEIVE
    mov.b r8, r10
    swpb r10
    mov.b #29h, r8
    call #I2C_RECEIVE
    bic.w #0FF00h, r8
    add.w r8, r10
    add.w &PRESSURE_CALIBRATION, r10
    sub.w #14932, r10
    rla.w r10
    rla.w r10
    rla.w r10
    rla.w r10
    mov.w #341, r9
    call #DIVIDE_AND_PRINT
    ret

TEMPERATURE:
    mov.b #I2C_ADDR_PRESSURE, r13
    mov.b #2Ch, r8
    call #I2C_RECEIVE
    mov.b r8, r10
    swpb r10
    mov.b #2Bh, r8
    call #I2C_RECEIVE
    bic.w #0FF00h, r8
    add.w r8, r10
    add.w &(TEMPERATURE_CALIBRATION), r10
    add.w #20400, r10
    bit.w #8000h, r10
    jz temp_positive
    push r10
    mov.w #1010h, r9
    mov.w #150, r10
    call #SHOW_DIGITS
    pop r10
    inv.w r10
    temp_positive:
    mov.w #480, r9
    call #DIVIDE_AND_PRINT
    ret

HUMIDITY:
    mov.b #I2C_ADDR_HUMIDITY, r13
    mov.b #0, r8
    call #I2C_RECEIVE
    call #DECIMIZE_AND_PRINT
    mov.b #200, r8
    call #DELAY
    mov.b #1, r8
    call #I2C_RECEIVE
    call #DECIMIZE_AND_PRINT
    mov.b #200, r8
    call #DELAY
    mov.b #2, r8
    call #I2C_RECEIVE
    call #DECIMIZE_AND_PRINT
    mov.b #200, r8
    call #DELAY
    mov.b #3, r8
    call #I2C_RECEIVE
    call #DECIMIZE_AND_PRINT
    ret

TEMPERATURE2:
    mov.b #I2C_ADDR_HUMIDITY, r13
    mov.b #2, r8
    call #I2C_RECEIVE
    call #DECIMIZE_AND_PRINT
    ret

DIVIDE_AND_PRINT:
    call #DIVIDE_SUB
DECIMIZE_AND_PRINT:
    call #TO_DECIMAL
    and.w #0FFh, r9
    and.w #0FFh, r8
    swpb r9
    add.w r8, r9
    
    mov.w #200, r10
    call #SHOW_DIGITS
    ret

;======================
; digits in r9, count in r10 (milliseconds)
SHOW_DIGITS:
    push r8
    push r10
    push r11
    show_digits_0:
    mov.b r9, r11
    add.w #digits, r11
    mov.b #7Fh, P1DIR
    mov.b @r11, &P1OUT
    bis.b #1000b, P2DIR
    bis.b #1000b, P2OUT
    mov.b #2, r8
    call #DELAY
    bic.b #1000b, P2DIR
    swpb r9
    mov.b r9, r11
    add.w #digits, r11
    mov.b @r11, &P1OUT
    bis.b #10000000b, &P1DIR
    bis.b #10000000b, &P1OUT
    mov.b #2, r8
    call #DELAY
    mov.b #0, &P1DIR
    swpb r9
    dec.w r10
    jnz show_digits_0
    pop r11
    pop r10
    pop r8
    ret

;====================
; Hex value in r8 (low), count in r10 (millis)
SHOW_HEX:
    push r8
    push r9
    mov.b r8, r9
    and.b #0F0h, r9
    add.w r9, r9
    add.w r9, r9
    add.w r9, r9
    add.w r9, r9
    and.b #0Fh, r8
    add.w r8, r9
    call #SHOW_DIGITS
    pop r9
    pop r8
    ret

digits:
    db ~7Eh, ~60h, ~5Bh, ~6Bh, ~65h, ~2Fh, ~3Fh, ~62h
    db ~7Fh, ~6Fh, ~77h, ~3Dh, ~1Eh, ~79h, ~1Fh, ~17h
    db ~01h, ~00h ; minus sign

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
    mov.b #I2C_ADDR_PRESSURE, r13
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
    mov.b  r13, r8
    rla.b r8
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
    mov.b  r13, r8
    rla.b r8
    call #I2C_WRITE_BYTE
    pop r8
    call #I2C_WRITE_BYTE
    call #I2C_START
    mov.b  r13, r8
    rla.b r8
    inc.b r8
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

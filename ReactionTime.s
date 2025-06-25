;------------------------------------------------------------------------------
; Purpose: Reaction time meter system using random delays and LED output
;------------------------------------------------------------------------------
        THUMB                       ; Use Thumb instruction set
        AREA    My_code, CODE, READONLY
        EXPORT  __MAIN              ; Export entry label
        ENTRY

__MAIN                              ; Entry point (required by startup file)

;------------------------------------------------------------------------------
; Section 1: Initialize GPIO and turn off all LEDs
;------------------------------------------------------------------------------
        LDR     R10, =LED_BASE_ADR   ; R10 holds base GPIO address (0x2009C000)

        MOV     R3, #0xB0000000      ; Clear Port 1 LEDs (bits 28-30)
        STR     R3, [R10, #0x20]     ; Write to Port 1 (offset 0x20)

        MOV     R3, #0x0000007C      ; Clear Port 2 LEDs (bits 2–6)
        STR     R3, [R10, #0x40]     ; Write to Port 2 (offset 0x40)

        MOV     R11, #0xABCD         ; Seed for pseudo-random number generator (must be non-zero)

;------------------------------------------------------------------------------
; Section 2: Main reflex loop
;------------------------------------------------------------------------------
loop
        BL      RandomNum           ; Generate scaled random number (R11 updated)
        MOV     R5, R11             ; Copy scaled value to R5 (delay duration)
        BL      DELAY               ; Delay for random time (2–10s)

        MOV     R3, #0x90000000     ; Turn ON LED P1.29
        STR     R3, [R10, #0x20]    ; Activate LED

        BL      POLL                ; Wait until push-button (INT0) is pressed
        BL      REFLEX              ; Display 32-bit counter value (reaction time)
        B       loop                ; Repeat forever

;------------------------------------------------------------------------------
; DISPLAY_NUM: Display 8-bit value in R1 across 8 LEDs
;------------------------------------------------------------------------------
DISPLAY_NUM
        STMFD   R13!, {R1, R2, R14} ; Save registers

        ; Output to Port 2 (bits 2–6)
        LSL     R2, R1, #27
        RBIT    R2, R2
        LSL     R2, #2
        EOR     R2, R2, #0x0000007C
        STR     R2, [R10, #0x40]

        ; Output to Port 1 (bits 28–30)
        LSR     R2, R1, #6
        LSL     R2, #30
        RBIT    R2, R2
        MOV     R4, R1
        LSL     R4, #26
        LSR     R4, #31
        LSL     R4, #3
        ORR     R2, R4
        LSL     R2, #28
        EOR     R2, #0xB0000000
        STR     R2, [R10, #0x20]

exitDISPLAY_NUM
        LDMFD   R13!, {R1, R2, R15} ; Restore and return

;------------------------------------------------------------------------------
; RandomNum: Pseudo-random number generator (16-bit LFSR)
; Output: Scaled result in R11 (between 20,000 and 100,000)
;------------------------------------------------------------------------------
RandomNum
        STMFD   R13!, {R1, R2, R3, R14}

        ; LFSR feedback taps
        AND     R1, R11, #0x8000
        AND     R2, R11, #0x2000
        LSL     R2, #2
        EOR     R3, R1, R2
        AND     R1, R11, #0x1000
        LSL     R1, #3
        EOR     R3, R3, R1
        AND     R1, R11, #0x0400
        LSL     R1, #5
        EOR     R3, R3, R1
        LSR     R3, #15
        LSL     R11, #1
        ORR     R11, R11, R3

        ; Scale result to [20000, 100000]
        MOV     R2, #9
        SDIV    R1, R11, R2
        MUL     R1, R2
        SUB     R11, R1
        MOV     R2, #2
        ADD     R11, R2
        MOV     R2, #10000
        MUL     R11, R2

        LDMFD   R13!, {R1, R2, R3, R15}

;------------------------------------------------------------------------------
; DELAY: Software delay of 0.1 ms * R5 times
;------------------------------------------------------------------------------
DELAY
        STMFD   R13!, {R2, R14}
MultipleDelay
        MOV     R0, #0x85           ; Inner loop count (0x85 = 133 cycles)
Delay_1
        TEQ     R5, #0
        SUBS    R0, #1
        BGT     Delay_1
        SUBS    R5, #1
        BGT     MultipleDelay
exitDelay
        LDMFD   R13!, {R2, R15}

;------------------------------------------------------------------------------
; POLL: Wait until push-button INT0 is pressed; counts reaction time in R8
;------------------------------------------------------------------------------
POLL
        STMFD   R13!, {R1, R2, R3, R14}
        MOV     R8, #0
POLL_loop
        MOV     R5, #1
        BL      DELAY
        ADD     R8, #1
        LDR     R6, [R10, #0x54]    ; Read INT0 pin
        LSL     R6, #21
        LSR     R6, #31
        CMP     R6, #0
        BNE     POLL_loop
exitPOLL
        LDMFD   R13!, {R1, R2, R3, R15}

;------------------------------------------------------------------------------
; COUNTER: Count from 0 to 255 and display each on LEDs
;------------------------------------------------------------------------------
COUNTER
        STMFD   R13!, {R1, R2, R3, R14}
        MOV     R3, #0xB0000000
        STR     R3, [R10, #0x20]
        MOV     R3, #0x0000007C
        STR     R3, [R10, #0x40]
        MOV     R1, #0
INCREMENT
        MOV     R5, #1000           ; 100ms delay
        BL      DELAY
        ADD     R1, #1
        BL      DISPLAY_NUM
        CMP     R1, #0xFF
        BLT     INCREMENT
exitCOUNTER
        LDMFD   R13!, {R1, R2, R3, R15}

;------------------------------------------------------------------------------
; REFLEX: Display 32-bit reaction count value in 4 bytes across LEDs
;------------------------------------------------------------------------------
REFLEX
        STMFD   R13!, {R1, R2, R3, R14}
        MOV     R7, #4
        MOV     R9, R8
REFLEX_loop
        LSL     R1, R9, #24
        LSR     R1, #24
        BL      DISPLAY_NUM
        LSR     R9, #8
        MOV     R5, #20000          ; 2s delay
        BL      DELAY
        SUBS    R7, #1
        BNE     REFLEX_loop

        ; Clear LEDs
        MOV     R3, #0xB0000000
        STR     R3, [R10, #0x20]
        MOV     R3, #0x0000007C
        STR     R3, [R10, #0x40]
        MOV     R5, #50000          ; 5s delay
        BL      DELAY
        B       REFLEX
exitREFLEX
        LDMFD   R13!, {R1, R2, R3, R15}

;------------------------------------------------------------------------------
; Constants and addresses
;------------------------------------------------------------------------------
LED_BASE_ADR   EQU     0x2009C000    ; GPIO base address for LED control
PINSEL3        EQU     0x4002C00C    ; Pin select register for P1[31:16]
PINSEL4        EQU     0x4002C010    ; Pin select register for P2[15:0]

        ALIGN
        END
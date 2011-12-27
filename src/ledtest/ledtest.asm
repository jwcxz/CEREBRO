; vim: ts=4 sw=4 fdm=marker
;-------------------------------------------------------------------------------
; C E R E B R O
; J. Colosimo
; 6.115 Final Project
;
; LED Panel Serial Output Test
; test file that outputs a color pattern to the LED panel
;-------------------------------------------------------------------------------


;-------------------------------------------------------------------------------
; CONSTANTS
;-------------------------------------------------------------------------------
V_addr_led equ 0FE20h
V_addr_led_thr equ (V_addr_led + 00h)   ; transmitter buffer reg (dlab = 0)
V_addr_led_ier equ (V_addr_led + 01h)   ; interrupt enable reg (dlab = 0)
V_addr_led_dll equ (V_addr_led + 00h)   ; divisor latch (lsb) (dlab = 1)
V_addr_led_dlm equ (V_addr_led + 01h)   ; divisor latch (msb) (dlab = 1)
V_addr_led_lcr equ (V_addr_led + 03h)   ; line control reg
V_addr_led_lsr equ (V_addr_led + 05h)   ; line status reg

;-------------------------------------------------------------------------------
; INCLUDES
;-------------------------------------------------------------------------------

org 00h
ljmp main

;-------------------------------------------------------------------------------
; INTERRUPTS
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; MAIN LOOP
;-------------------------------------------------------------------------------
org 0100h
main:
    lcall F_init_led

    L_main_loop: 
        mov DPTR, #V_addr_led_thr

        mov A, #0aah
        movx @DPTR, A

            Lwait0:
                movx A, @DPTR
                jnz A, Lwait0

        mov A, #0252d
        movx @DPTR, A

            Lwait1:
                movx A, @DPTR
                jnz A, Lwait1

        mov A, #080d
        movx @DPTR, A

            Lwait2:
                movx A, @DPTR
                jnz A, Lwait2

        mov A, #010d
        movx @DPTR, A

            Lwait3:
                movx A, @DPTR
                jnz A, Lwait3

        mov A, #040d
        movx @DPTR, A
        
        mov R0, #0h
        mov R1, #0h
        LwaitA:
            LwaitB:
                ;djnz R0, LwaitB
            djnz R1, LwaitA

        sjmp L_main_loop

;-------------------------------------------------------------------------------
; FUNCTIONS
;-------------------------------------------------------------------------------
F_init_led:     ; initialize LED Panel UART {{{
    ; set line control register
    ;   0b10011011
    ;   set-dlab no-break stick-parity even-parity
    ;   parity-enable 1-stop-bit 8-bit-words[2]
    mov A, #09Bh
    mov DPTR, #V_addr_led_lcr
    movx @DPTR, A

    ; set divisor
    ;   1.8432e6/16/38400 = 3
    mov A, #03h
    mov DPTR, #V_addr_led_dll
    movx @DPTR, A
    mov A, #000h
    mov DPTR, #V_addr_led_dlm
    movx @DPTR, A

    ; clear divisor latch
    mov A, #01Bh
    mov DPTR, #V_addr_led_lcr
    movx @DPTR, A

    ; disable interrupts
    ;mov A, #000h
    ;mov DPTR, #V_addr_led_ier
    ;movx @DPTR, A

    ret
    ; }}}

; --- --- ---
; vim: et ts=4 sw=4 fdm=marker

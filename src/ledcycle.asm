; vim: ts=4 sw=4 fdm=marker
;-------------------------------------------------------------------------------
; C E R E B R O
; J. Colosimo
; 6.115 Final Project
;
; LED Panel Color Shifting Test
; shows a hue shifting output on the LED panel
;-------------------------------------------------------------------------------


;-------------------------------------------------------------------------------
; CONSTANTS
;-------------------------------------------------------------------------------
Va_led equ 0FE20h
Va_led_thr equ (Va_led + 00h)   ; transmitter buffer reg (dlab = 0)
Va_led_ier equ (Va_led + 01h)   ; interrupt enable reg (dlab = 0)
Va_led_dll equ (Va_led + 00h)   ; divisor latch (lsb) (dlab = 1)
Va_led_dlm equ (Va_led + 01h)   ; divisor latch (msb) (dlab = 1)
Va_led_lcr equ (Va_led + 03h)   ; line control reg
Va_led_lsr equ (Va_led + 05h)   ; line status reg

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
    lcall F_lp_initled

    mov R3, #020h
    mov R4, #0FFh
    mov R5, #030h

    L_main_loop: 
        ; set stuff manually {{{
        ;mov A, #0aah
        ;lcall F_lp_sendbyte

        ;mov A, #0252d
        ;lcall F_lp_sendbyte

        ;mov A, #080d
        ;lcall F_lp_sendbyte

        ;mov A, #010d
        ;lcall F_lp_sendbyte

        ;mov A, #040d
        ;lcall F_lp_sendbyte
        ; }}}
        
        mov A, R3
        mov R0, A

        mov A, R4
        mov R1, A

        mov A, R5
        mov R2, A

        lcall F_cu_hsv2rgb
        lcall F_lp_setwholepanel

        ;mov A, R3
        ;add A, #05h
        ;mov R3, A
        inc R3

        ; -- pause and loop --
        mov R6, #0h
        mov R7, #0h
        LwaitA:
            LwaitB:
                ;djnz R6, LwaitB
            djnz R7, LwaitA

        ljmp L_main_loop

;-------------------------------------------------------------------------------
; FUNCTIONS
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; INCLUDES
;-------------------------------------------------------------------------------
#include colutils.asm
#include ledpanel.asm

; --- --- ---
; vim: et ts=4 sw=4 fdm=marker

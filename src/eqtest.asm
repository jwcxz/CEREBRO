; vim: ts=4 sw=4 fdm=marker
;-------------------------------------------------------------------------------
; C E R E B R O
; J. Colosimo
; 6.115 Final Project
;
; equalizer test
; tests the functionality of the equalizer board by scanning through the values
; and printing out the results.
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; CONSTANTS
;-------------------------------------------------------------------------------
Va_eqb_mux equ P1
Va_eqb_adc equ 0FE10h

org 00h
ljmp main

;-------------------------------------------------------------------------------
; MAIN LOOP
;-------------------------------------------------------------------------------
org 0100h
main:
    lcall F_sc_initserial
    setb EA
    mov DPTR, #Va_eqb_adc   ; set DPTR to the ADC
    
    L_main_loop:
    mov Va_eqb_mux, #0F0h   ; set first mux address
    mov R0, #08d            ; counter
    F_eq_scan_loop:
        ; read value
        mov  DPTR, #Va_eqb_adc
        movx @DPTR, A   ; initiate conversion
        ; wait until conversion is done
        F_eq_scan_loop_wait: jb P3.3, F_eq_scan_loop_wait 
        movx A, @DPTR   ; read result

        lcall F_sc_prthex
        
        mov A, #' '
        lcall F_sc_tx

        inc Va_eqb_mux  ; go to next address on the mux
        djnz R0, F_eq_scan_loop

    lcall F_sc_crlf
    mov R0, #0d
    L_wait: djnz R0, L_wait
    mov R0, #0d
    L_wait2: djnz R0, L_wait2
    sjmp L_main_loop

;-------------------------------------------------------------------------------
; INCLUDES
;-------------------------------------------------------------------------------
#include sercom.asm

; vim: ts=4 sw=4 fdm=marker
;-------------------------------------------------------------------------------
; C E R E B R O
; J. Colosimo
; 6.115 Final Project
;
; EQUALIZER BOARD CONTROLLER
; prefix: eq
; enables scanning the equalizer and reading its values into a buffer
;-------------------------------------------------------------------------------


;-------------------------------------------------------------------------------
; NEEDED VALUES
;-------------------------------------------------------------------------------
; Va_eqb_mux, Va_eqb_adc, Vm_eqb_val

;-------------------------------------------------------------------------------
; CONSTANTS
;-------------------------------------------------------------------------------

F_eq_scan:      ; scan through equalizer {{{
    ; --- accounting ---
    ; R0 : pointer to buffer
    ; R1 : counter

    ; save A, B, and registers {{{
    push acc
    push B
    push DPH
    push DPL
    push 00h    ; R0
    push 01h    ; R1
    push 02h    ; R2
    ; }}}

    mov DPTR, #Va_eqb_adc   ; set DPTR to the ADC
    mov Va_eqb_mux, #0F0h   ; set first mux address
    mov R0, #Vm_eqb_vals    ; initialize to buffer start
    mov R1, #08h            ; counter
    F_eq_scan_loop:
        ; read value
        mov  DPTR, #Va_eqb_adc
        movx @DPTR, A   ; initiate conversion
        ; wait until conversion is done
        F_eq_scan_loop_wait: jb P3.3, F_eq_scan_loop_wait 
        movx A, @DPTR   ; read result

        mov @R0, A      ; set buffer value
        inc R0          ; increment pointer
        inc Va_eqb_mux  ; go to next address on the mux

        mov R2, #0h
        F_eq_scan_loop_wait2: djnz R2, F_eq_scan_loop_wait2

        djnz R1, F_eq_scan_loop

    F_eq_scan_done:
        ; restore A, B, and registers {{{
        pop 02h ; R2
        pop 01h ; R1
        pop 00h ; R0
        pop DPL
        pop DPH
        pop B
        pop acc
        ; }}}

        ret
    ; }}}

F_eq_initeqb:   ; set up equalizer board {{{
    mov Va_eqb_mux, #0F0h
    ret
    ; }}}

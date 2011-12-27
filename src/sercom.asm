; vim: ts=4 sw=4 fdm=marker
;-------------------------------------------------------------------------------
; C E R E B R O
; J. Colosimo
; 6.115 Final Project
;
; SERIAL COMMUNICATIONS LIBRARY
; prefix: sc
; provides functions for communicating with a computer over serial
; some stuff taken from minmon
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; FUNCTIONS
;-------------------------------------------------------------------------------
F_sc_initserial:      ; initialize serial communication {{{
    mov  TMOD, #020h    ; sw-controlled gate, timer mode, 8-bit ar timer 1
    setb TR1
    ;mov  TH1, #0FFh     ; TH1 = 256 - 2x11.0592e6/384/57600 = 255 with PCON on
    ;orl  PCON, #080h    ; set PCON on
    mov TH1, #0FDh
    mov  SCON, #050h    ; enable 8-bit UART, REN on
    
    ret
    ; }}}

F_sc_tx:
    clr TI          ; clear the receiver interrupt so we can send data
    mov SBUF, A     ; push the last character we had stored (and stripped) out
                    ; to the serial buffer
    F_sc_tx_loop:
        jnb TI, F_sc_tx_loop   ; wait for the transmitter to finish
    ret
    ; }}}

F_sc_crlf:          ; send a CR, LF over serial {{{
    mov A, #010d    ; issue CR
    lcall F_sc_tx   ; send over serial
    mov A, #013d    ; issue LF
    lcall F_sc_tx   ; send that over serial too
    ret
    ; }}}

F_sc_prthex:
   push acc
   lcall F_sc_binasc        ; convert acc to ascii
   lcall F_sc_tx            ; print first ascii hex digit
   mov   a,  r2             ; get second ascii hex digit
   lcall F_sc_tx            ; print it
   pop acc
   ret

F_sc_binasc:
    mov   r2, a            ; save in r2
    anl   a,  #0fh         ; convert least sig digit.
    add   a,  #0f6h        ; adjust it
    jnc   F_sc_binasc_noadj1 ; if a-f then readjust
    add   a,  #07h
    F_sc_binasc_noadj1:
        add   a,  #3ah         ; make ascii
        xch   a,  r2           ; put result in reg 2
        swap  a                ; convert most sig digit
        anl   a,  #0fh         ; look at least sig half of acc
        add   a,  #0f6h        ; adjust it
        jnc   F_sc_binasc_noadj2    ; if a-f then re-adjust
        add   a,  #07h
    F_sc_binasc_noadj2:
        add   a,  #3ah         ; make ascii
        ret

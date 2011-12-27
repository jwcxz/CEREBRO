;-------------------------------------------------------------------------------
; C E R E B R O
; J. Colosimo
; 6.115 Final Project
;
; eegtest.asm 
;
; test file that directly forwards data from the EEG chip to the serial port
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; CONSTANTS
;-------------------------------------------------------------------------------
V_addr_eeg equ 0FE00h
V_addr_eeg_rxb equ (V_addr_eeg + 00h)   ; receiver buffer reg (dlab = 0)
V_addr_eeg_ier equ (V_addr_eeg + 01h)   ; interrupt enable reg (dlab = 0)
V_addr_eeg_dll equ (V_addr_eeg + 00h)   ; divisor latch (lsb) (dlab = 1)
V_addr_eeg_dlm equ (V_addr_eeg + 01h)   ; divisor latch (msb) (dlab = 1)
V_addr_eeg_lcr equ (V_addr_eeg + 03h)   ; line control reg
V_addr_eeg_lsr equ (V_addr_eeg + 05h)   ; line status reg

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
    lcall F_init_serial
    lcall F_init_eeg

    ; test
    ;Lloop:
    ;    mov A, #'T'
    ;    lcall F_ser_tx
    ;    sjmp Lloop

    L_main_loop: 
        mov DPTR, #V_addr_eeg_lsr   ; check line status reg
        movx A, @DPTR
        anl A, #01h                 ; bit 0 is data ready
        jz L_main_loop

        mov DPTR, #V_addr_eeg_rxb   ; read byte
        movx A, @DPTR
        lcall F_ser_tx              ; send it over serial

        sjmp L_main_loop

;-------------------------------------------------------------------------------
; FUNCTIONS
;-------------------------------------------------------------------------------
F_init_eeg:     ; initialize EEG UART {{{
    ; set line control register
    ;   0b10000011
    ;   set-dlab no-break stick-parity odd-parity
    ;   no-parity 1-stop-bit 8-bit-words[2]
    mov A, #083h
    mov DPTR, #V_addr_eeg_lcr
    movx @DPTR, A

    ; set divisor
    ;   1.842e6/16/9600 ~= 12
    mov A, #0Ch
    mov DPTR, #V_addr_eeg_dll
    movx @DPTR, A
    mov A, #000h
    mov DPTR, #V_addr_eeg_dlm
    movx @DPTR, A

    ; clear divisor latch
    mov A, #003h
    mov DPTR, #V_addr_eeg_lcr
    movx @DPTR, A

    ; set interrupts
    ;   disable all for now, but eventually switch to using 1 since that will
    ;   enable the interrupt on received data available
    mov A, #000h    ; TODO: change to #001h
    mov DPTR, #V_addr_eeg_ier
    movx @DPTR, A

    ; setb EX0
    ; setb EA

    ret
    ; }}}

F_init_serial:      ; initialize serial communication {{{
    mov  TMOD, #020h    ; sw-controlled gate, timer mode, 8-bit ar timer 1
    setb TR1
    ;mov  TH1, #0FFh     ; TH1 = 256 - 2x11.0592e6/384/57600 = 255 with PCON on
    ;orl  PCON, #080h    ; set PCON on
    mov TH1, #0FDh
    mov  SCON, #050h    ; enable 8-bit UART, REN on
    
    ret
    ; }}}

F_ser_tx:           ; send a character over serial {{{
    clr TI          ; clear the receiver interrupt so we can send data
    mov SBUF, A     ; push the last character we had stored (and stripped) out
                    ; to the serial buffer
    L_ser_tx_loop:
        jnb TI, L_ser_tx_loop   ; wait for the transmitter to finish
    ret
    ; }}}

F_ser_crlf:         ; send a CR, LF over serial {{{
    mov A, #010d    ; issue CR
    lcall F_ser_tx  ; send over serial
    mov A, #013d    ; issue LF
    lcall F_ser_tx  ; send that over serial too
    ret
    ; }}}

; --- --- ---
; vim: et ts=4 sw=4 fdm=marker

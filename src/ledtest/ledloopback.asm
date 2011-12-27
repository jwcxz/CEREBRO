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
    lcall F_init_led
    lcall F_init_eeg
    lcall F_init_serial

    L_main_loop: 
        mov DPTR, #V_addr_led_thr
        mov A, #'a'
        movx @DPTR, A
        
        Lwait:
            mov DPTR, #V_addr_eeg_lsr   ; check line status reg
            movx A, @DPTR
            anl A, #01h                 ; bit 0 is data ready
            jz Lwait

            mov DPTR, #V_addr_eeg_rxb   ; read byte
            movx A, @DPTR
            lcall F_ser_tx              ; send it over serial

        ; pause
        Lwait1:
            Lwait2:
                ;djnz R0, Lwait2
            djnz R1, Lwait1

        sjmp L_main_loop

;-------------------------------------------------------------------------------
; FUNCTIONS
;-------------------------------------------------------------------------------
F_init_led:     ; initialize LED Panel UART {{{
    ; set line control register
    ;   0b10011011
    ;   set-dlab no-break stick-parity even-parity
    ;   parity-enable 1-stop-bit 8-bit-words[2]
    mov A, #083h
    mov DPTR, #V_addr_led_lcr
    movx @DPTR, A

    ; set divisor
    ;   2e6/16/38400 ~= 3, but with a 7% error rate -- maybe too high
    ;mov A, #03h
    mov A, #03h
    mov DPTR, #V_addr_led_dll
    movx @DPTR, A
    mov A, #000h
    mov DPTR, #V_addr_led_dlm
    movx @DPTR, A

    ; clear divisor latch
    mov A, #003h
    mov DPTR, #V_addr_led_lcr
    movx @DPTR, A

    ; disable interrupts
    ;mov A, #000h
    ;mov DPTR, #V_addr_led_ier
    ;movx @DPTR, A

    ret
    ; }}}

F_init_eeg:     ; initialize EEG UART {{{
    ; set line control register
    ;   0b10000011
    ;   set-dlab no-break stick-parity odd-parity
    ;   no-parity 1-stop-bit 8-bit-words[2]
    mov A, #083h
    mov DPTR, #V_addr_eeg_lcr
    movx @DPTR, A

    ; set divisor
    ;   2e6/16/9600 ~= 13
    mov A, #03h
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

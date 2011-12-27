; vim: ts=4 sw=4 fdm=marker
;-------------------------------------------------------------------------------
; C E R E B R O
; J. Colosimo
; 6.115 Final Project
;
; EEG Payload Capture Test
; Gets payload, does basic processing, prints to serial
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; CONSTANTS
;-------------------------------------------------------------------------------
Va_eeg equ 0FE00h
Va_eeg_rxb equ (Va_eeg + 00h)   ; receiver buffer reg (dlab = 0)
Va_eeg_ier equ (Va_eeg + 01h)   ; interrupt enable reg (dlab = 0)
Va_eeg_dll equ (Va_eeg + 00h)   ; divisor latch (lsb) (dlab = 1)
Va_eeg_dlm equ (Va_eeg + 01h)   ; divisor latch (msb) (dlab = 1)
Va_eeg_lcr equ (Va_eeg + 03h)   ; line control reg
Va_eeg_lsr equ (Va_eeg + 05h)   ; line status reg

Vm_eeg_pptr_d equ 050h  ; 0x50 -> 0x50+32=0x6F
Vm_eeg_smst   equ 030h
Vm_eeg_plen   equ 031h
Vm_eeg_pptr   equ 032h
Vm_eeg_csum   equ 033h
Vm_eeg_sgnl   equ 034h
Vm_eeg_dlta   equ 038h  ; 0x38 -> 0x38+23=0x4F
Vm_eeg_attn   equ 035h
Vm_eeg_mdtn   equ 036h
Vm_eeg_drdy   equ 037h
Vm_eeg_csum_got equ 072h

;Vm_eeg_iptr   equ 070h
;Vm_eeg_optr   equ 071h

org 00h
ljmp main

;-------------------------------------------------------------------------------
; INTERRUPTS
;-------------------------------------------------------------------------------
org 03h
    ljmp F_ec_int
;   implementation of a circular buffer
;    TODO: add buffer counter
;    push acc
;    push dph
;    push dpl
;    push 00h ; R0
;
;    mov R0, #Vm_eeg_iptr
;    mov A, @R0              ; get iptr
;    mov R0, A               ; R0 <- iptr
;
;    mov DPTR, #Va_eeg_rxb
;    movx A, @DPTR           ; get byte from serial
;
;    mov @R0, A              ; store byte to @iptr
;
;    inc R0                  ; increment pointer
;    cjne R0, #Vm_eeg_buf+064d, IE0_end  ; if we hit the end of the buffer...
;        mov R0, #Vm_eeg_buf ; then wrap
;
;    IE0_end:
;        mov A, R0
;        mov R0, #Vm_eeg_iptr
;        mov @R0, A
;        pop 00h ; R0
;        pop dpl
;        pop dph
;        pop acc
;
;    reti

;-------------------------------------------------------------------------------
; MAIN LOOP
;-------------------------------------------------------------------------------
org 0100h
main:
    lcall F_sc_initserial
    lcall F_ec_initeeg
    setb EA

    mov R0, #Vm_eeg_drdy
    mov @R0, #00h

    L_main_loop: 
        mov R0, #Vm_eeg_drdy
        mov A, @R0
        jz L_main_loop   ; is value ready?

        ; print some crap
        mov R0, #Vm_eeg_sgnl    ; signal quality
        mov A, @R0
        lcall F_sc_prthex

            mov A, #' '
            lcall F_sc_tx

        mov R0, #Vm_eeg_attn    ; attention
        mov A, @R0
        lcall F_sc_prthex

            mov A, #' '
            lcall F_sc_tx

        mov R0, #Vm_eeg_mdtn    ; meditation
        mov A, @R0
        lcall F_sc_prthex

            mov A, #' '
            lcall F_sc_tx

        mov R0, #Vm_eeg_dlta    ; FFT values values
        mov R1, #024d
        L_main_loop_fft:
            mov A, #' '
            lcall F_sc_tx
            mov A, @R0
            inc R0
            lcall F_sc_prthex
            djnz R1, L_main_loop_fft

        lcall F_sc_crlf

        ; reset drdy
        mov R0, #Vm_eeg_drdy
        mov @R0, #00h

        sjmp L_main_loop

;-------------------------------------------------------------------------------
; FUNCTIONS
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; INCLUDES
;-------------------------------------------------------------------------------
#include eegctrl.asm
#include sercom.asm

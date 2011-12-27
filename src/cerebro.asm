; vim: ts=4 sw=4 fdm=marker
;-------------------------------------------------------------------------------
; C E R E B R O
; J. Colosimo
; 6.115 Final Project
;
; CEREBRO
; main file
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; CONSTANTS
;-------------------------------------------------------------------------------
; ADDRESSES {{{
; EEG UART addresses
    Va_eeg equ 0FE00h
    Va_eeg_rxb equ (Va_eeg + 00h)   ; receiver buffer reg (dlab = 0)
    Va_eeg_ier equ (Va_eeg + 01h)   ; interrupt enable reg (dlab = 0)
    Va_eeg_dll equ (Va_eeg + 00h)   ; divisor latch (lsb) (dlab = 1)
    Va_eeg_dlm equ (Va_eeg + 01h)   ; divisor latch (msb) (dlab = 1)
    Va_eeg_lcr equ (Va_eeg + 03h)   ; line control reg
    Va_eeg_lsr equ (Va_eeg + 05h)   ; line status reg
; LED panel UART addresses
    Va_led equ 0FE20h
    Va_led_thr equ (Va_led + 00h)   ; transmitter buffer reg (dlab = 0)
    Va_led_ier equ (Va_led + 01h)   ; interrupt enable reg (dlab = 0)
    Va_led_dll equ (Va_led + 00h)   ; divisor latch (lsb) (dlab = 1)
    Va_led_dlm equ (Va_led + 01h)   ; divisor latch (msb) (dlab = 1)
    Va_led_lcr equ (Va_led + 03h)   ; line control reg
    Va_led_lsr equ (Va_led + 05h)   ; line status reg
; Equalizer board addresses
    Va_eqb_mux equ P1
    Va_eqb_adc equ 0FE10h
; }}}

; MEMORY {{{
; packet processing
    Vm_eeg_pptr_d equ 050h  ; packet pointer default address 0x50 -> 0x50+32=0x6F
    Vm_eeg_smst   equ 030h  ; current state machine state
    Vm_eeg_plen   equ 031h  ; packet length
    Vm_eeg_pptr   equ 032h  ; packet pointer
    Vm_eeg_csum   equ 033h  ; running checksum
; payload values
    Vm_eeg_sgnl   equ 034h      ; signal quality
    Vm_eeg_attn   equ 035h      ; attention
    Vm_eeg_mdtn   equ 036h      ; meditation
    Vm_eeg_drdy   equ 037h      ; data ready for processing
    Vm_eeg_dlta   equ 038h      ; delta (start of fft values) 0x38 -> 0x38+23=0x4F
        Vm_eeg_thta equ Vm_eeg_dlta+03d     ;   theta
        Vm_eeg_lalp equ Vm_eeg_dlta+06d     ;   low alpha
        Vm_eeg_halp equ Vm_eeg_dlta+09d     ;   high alpha
        Vm_eeg_lbet equ Vm_eeg_dlta+012d    ;   low beta
        Vm_eeg_hbet equ Vm_eeg_dlta+015d    ;   high beta
        Vm_eeg_lgam equ Vm_eeg_dlta+018d    ;   low gamma
        Vm_eeg_mgam equ Vm_eeg_dlta+021d    ;   mid gamma
    Vm_eeg_csum_got equ 070h    ; received checksum (for debugging)

    Vm_eeg_attn_lst equ 07Dh    ; previous attention value
    Vm_eeg_mdtn_lst equ 07Eh    ; previous meditation value

; equalizer board container memory
    Vm_eqb_vals equ 0B0h            ; 0xB0 -> 0xB7

; LED panel output buffer (used by F_lp_setpixels)
    Vm_led_rgbargs equ 071h                 ; 0x71 -> 0x71+12=0x7C
    Vm_led_rgbarg0 equ (Vm_led_rgbargs)     ; pixel 0
    Vm_led_rgbarg1 equ (Vm_led_rgbargs+3)   ; pixel 1
    Vm_led_rgbarg2 equ (Vm_led_rgbargs+6)   ; pixel 2
    Vm_led_rgbarg3 equ (Vm_led_rgbargs+9)   ; pixel 3

; transition system input buffer
    Vm_led_argbuf equ 081h                  ; 0x81 -> 0x81+12=0x8C
    Vm_led_argbuf0 equ (Vm_led_argbuf)      ; pixel 0
    Vm_led_argbuf1 equ (Vm_led_argbuf+3)    ; pixel 1
    Vm_led_argbuf2 equ (Vm_led_argbuf+6)    ; pixel 2
    Vm_led_argbuf3 equ (Vm_led_argbuf+9)    ; pixel 3

; transition system internal buffers
    Vm_led_rgbargs_cur equ 090h     ; pointer to current RGB arg buffer
    Vm_led_xfade equ 0A0h           ; crossfader value
    Vm_led_rgbargsA equ 091h        ; buffer A 0x91 -> 0x91+12=0x9C
    Vm_led_rgbargsB equ 0A1h        ; buffer B 0xA1 -> 0xA1+12=0xAC

; ewma values
    Vm_ewma_p0hue equ 0C0h
    Vm_ewma_p0val equ (Vm_ewma_p0hue+1)
    Vm_ewma_p1hue equ (Vm_ewma_p0hue+2)
    Vm_ewma_p1val equ (Vm_ewma_p0hue+3)
    Vm_ewma_p2hue equ (Vm_ewma_p0hue+4)
    Vm_ewma_p2val equ (Vm_ewma_p0hue+5)
    Vm_ewma_p3hue equ (Vm_ewma_p0hue+6)
    Vm_ewma_p3val equ (Vm_ewma_p0hue+7)
; }}}

org 00h
ljmp main

;-------------------------------------------------------------------------------
; INTERRUPTS
;-------------------------------------------------------------------------------
org 03h
    ljmp F_ec_int

org 0Bh
    ljmp F_th_int

;-------------------------------------------------------------------------------
; MAIN LOOP
;-------------------------------------------------------------------------------
org 0100h
main:
    lcall F_sc_initserial
    lcall F_ec_initeeg
    lcall F_eq_initeqb
    lcall F_lp_initled
    lcall F_th_inittimer
    setb EA

    ; set data ready off
    mov R0, #Vm_eeg_drdy
    mov @R0, #00h

    ; initialize first buffer to B (so that it switches to A on first data
    ; loading)
    mov R0, #Vm_led_rgbargs_cur
    mov @R0, #Vm_led_rgbargsB

    ; initialize LED buffer memory
    mov R0, #Vm_led_argbuf
    mov R1, #012d
    L_main_initinbuf:
        mov @R0, #0h
        inc R0
        djnz R1, L_main_initinbuf

    mov R0, #Vm_led_rgbargsA
    mov R1, #012d
    L_main_initAbuf:
        mov @R0, #0h
        inc R0
        djnz R1, L_main_initAbuf

    mov R0, #Vm_led_rgbargsB
    mov R1, #012d
    L_main_initBbuf:
        mov @R0, #0h
        inc R0
        djnz R1, L_main_initBbuf

    mov R0, #Vm_ewma_p0hue
    mov R1, #08d
    L_main_initewmabuf:
        mov @R0, #0h
        inc R0
        djnz R1, L_main_initewmabuf

    L_main_loop: 
        ; packets happen at roughly 1-second intervals
        mov R0, #Vm_eeg_drdy
        mov A, @R0
        jz L_main_loop   ; if data isn't ready yet, don't process anything

        ; read equalizer board values
        lcall F_eq_scan

        ; convert the second value to something between 1 and 4 for the
        ; transition speed
        mov R0, #Vm_eqb_vals+1
        mov A, @R0
        mov B, #064d
        div AB
        inc A       ; A ranges from 1 - 4
        inc A       ; A ranges from 2 - 5
        inc A       ; A ranges from 3 - 6
        mov @R0, A

        ; convert the 3rd value to something between 0 and for the algo
        ; selection
        mov R0, #Vm_eqb_vals+2
        mov A, @R0
        mov B, #064d
        div AB
        mov @R0, A

        ; print retrieved data to serial
        lcall F_dbg_prtdata

        ; process data -> RGB args color
        lcall F_sp_process

        ; copy buffer to free transition buffer
        lcall F_th_copy

        ; initiate transition
        lcall F_th_start

        ; update last values, but only if signal quality is good
        mov R0, #Vm_eeg_sgnl
        mov A, @R0
        jnz L_main_loop_skiplst

        mov R0, #Vm_eeg_attn
        mov A, @R0
        mov R0, #Vm_eeg_attn_lst
        mov @R0, A

        mov R0, #Vm_eeg_mdtn
        mov A, @R0
        mov R0, #Vm_eeg_mdtn_lst
        mov @R0, A
        ;------

        L_main_loop_skiplst:
        ; reset drdy
        mov R0, #Vm_eeg_drdy
        mov @R0, #00h

        sjmp L_main_loop

;-------------------------------------------------------------------------------
; FUNCTIONS
;-------------------------------------------------------------------------------
F_dbg_prtdata:  ; print out EEG data {{{
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

    lcall F_sc_crlf
    mov A, #' '
    lcall F_sc_tx

    mov R0, #Vm_eqb_vals    ; equalizer
    mov R1, #08d
    F_dbg_prtdata_eqb:
        mov A, @R0
        inc R0
        lcall F_sc_prthex
        mov A, #' '
        lcall F_sc_tx
        djnz R1, F_dbg_prtdata_eqb

    lcall F_sc_crlf

    mov R0, #Vm_eeg_dlta    ; FFT values
    mov R1, #024d
    F_dbg_prtdata_fft:
        mov A, #' '
        lcall F_sc_tx
        mov A, @R0
        inc R0
        lcall F_sc_prthex
        djnz R1, F_dbg_prtdata_fft

    lcall F_sc_crlf
    lcall F_sc_crlf

    ret
    ; }}}

;-------------------------------------------------------------------------------
; INCLUDES
;-------------------------------------------------------------------------------
#include eegctrl.asm
#include eqboard.asm
#include sigproc.asm
#include sercom.asm
#include colutils.asm
#include ledpanel.asm
#include trans.asm

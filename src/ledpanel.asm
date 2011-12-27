; vim: ts=4 sw=4 fdm=marker
;-------------------------------------------------------------------------------
; C E R E B R O
; J. Colosimo
; 6.115 Final Project
;
; LED PANEL UTILITIES
; prefix: lp
; functions for assembling and sending packets for the LED panel
;-------------------------------------------------------------------------------


;-------------------------------------------------------------------------------
; NEEDED VALUES
;-------------------------------------------------------------------------------
; UART:  Va_led_dll, Va_led_dlm, Va_led_ier, Va_led_lcr, Va_led_lsr, Va_led_thr
; Vm_led_rgbargs - base address for LED panel arguments

;-------------------------------------------------------------------------------
; CONSTANTS
;-------------------------------------------------------------------------------
V_lp_lpid equ 05h

V_lp_x_sync equ 0AAh
V_lp_x_fpanl equ 0252d
V_lp_x_fdisp equ 0247d

;-------------------------------------------------------------------------------
; FUNCTIONS
;-------------------------------------------------------------------------------
F_lp_setwholepanel:     ; set all 4 pixels to same color {{{
    ; args: R0:red, R1:grn, R2:blu
    ; --- accounting --- {{{
    ; R0 : red
    ; R1 : grn
    ; R2 : blu
    ; }}}

    ; save A, B, and registers {{{
    push acc
    ; }}}

    mov A, #V_lp_x_sync
    lcall F_lp_sendbyte     ; [sync]

    mov A, #V_lp_x_fpanl
    lcall F_lp_sendbyte     ; [fpanl]

    mov A, R0
    lcall F_lp_sendbyte     ; red

    mov A, R1
    lcall F_lp_sendbyte     ; green

    mov A, R2
    lcall F_lp_sendbyte     ; blue

    F_lp_setwholepanel_end:
        ; restore A, B, and registers {{{
        pop acc
        ; }}}

        ret
    ; }}}

F_lp_setpixels:         ; set each pixel individually {{{
    ; --- accounting --- {{{
    ; R0 : rgb array pointer
    ; R1 : gain correction
    ; R2 : arg counter
    ; }}}

    ; save A, B, and registers {{{
    push acc
    push 00h    ; R0
    push 01h    ; R1
    push 02h    ; R2
    ; }}}

    mov A, #V_lp_x_sync
    lcall F_lp_sendbyte     ; [sync]

    mov A, #V_lp_x_fdisp
    lcall F_lp_sendbyte     ; [fdisp]

    mov R1, #Vm_eqb_vals
    mov A, @R1
    mov R1, A

    mov R0, #Vm_led_rgbargs
    mov R2, #012d   ; 12 arguments
    F_lp_setpixels_argloop:
        mov A, @R0

        mov B, R1   ; apply gain correction
        mul AB
        mov A, B

        lcall F_lp_sendbyte
        inc R0
        djnz R2, F_lp_setpixels_argloop

    F_lp_setpixels_end:
        ; restore A, B, and registers {{{
        pop 02h ; R2
        pop 01h ; R1
        pop 00h ; R0
        pop acc
        ; }}}

       ret
    ; }}}

F_lp_initled:           ; initialize LED Panel UART {{{
    push acc

    ; set line control register
    ;   0b10011011
    ;   set-dlab no-break stick-parity even-parity
    ;   parity-enable 1-stop-bit 8-bit-words[2]
    mov A, #09Bh
    mov DPTR, #Va_led_lcr
    movx @DPTR, A

    ; set divisor
    ;   1.8432e6/16/38400 = 3
    mov A, #03h
    mov DPTR, #Va_led_dll
    movx @DPTR, A
    mov A, #000h
    mov DPTR, #Va_led_dlm
    movx @DPTR, A

    ; clear divisor latch
    mov A, #01Bh
    mov DPTR, #Va_led_lcr
    movx @DPTR, A

    ; disable interrupts
    ;mov A, #000h
    ;mov DPTR, #Va_led_ier
    ;movx @DPTR, A

    pop acc
    ret
    ; }}}

F_lp_sendbyte:          ; send a byte to the LED Panel UART {{{
    ; args: A:byte
    ; send byte to 16C450

    push 0h ; R0
    push DPH
    push DPL

    mov DPTR, #Va_led_thr
    movx @DPTR, A

    mov R0, #0h
    ; wait until it has been tranmitted
    F_lp_sendbyte_wait:
        ;movx A, @DPTR
        ;jnz F_lp_sendbyte_wait
        djnz R0, F_lp_sendbyte_wait

    pop DPL
    pop DPH
    pop 0h  ; R0
    ret
    ; }}}

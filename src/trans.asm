; vim: ts=4 sw=4 fdm=marker
;-------------------------------------------------------------------------------
; C E R E B R O
; J. Colosimo
; 6.115 Final Project
;
; TRANSITION HANDLER
; prefix: th
; handles transitions between two buffers
;-------------------------------------------------------------------------------

    
;-------------------------------------------------------------------------------
; CONSTANTS
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; FUNCTIONS
;-------------------------------------------------------------------------------
F_th_copy:  ; copy LED information to the free transition buffer {{{
    ; --- accounting ---
    ; R0 : buffer pointer
    ; R1 : LED args pointer
    ; R2 : loop counter

    ; save A, B, and registers {{{
    push acc
    push B
    push 00h    ; R0
    push 01h    ; R1
    push 02h    ; R2
    ; }}}

    mov R0, #Vm_led_rgbargs_cur
    mov A, @R0
    cjne A, #Vm_led_rgbargsB, F_th_copy_setB

    F_th_copy_setA:
        mov @R0, #Vm_led_rgbargsA
        ljmp F_th_copy_do

    F_th_copy_setB:
        mov @R0, #Vm_led_rgbargsB
        ljmp F_th_copy_do

    F_th_copy_do:
        mov A, @R0
        mov R0, A               ; R0 has address of current buffer
        mov R1, #Vm_led_argbuf  ; R1 has address of LED args
        mov R2, #012d
        F_th_copy_do_loop:
            mov A, @R1
            mov @R0, A
            inc R0
            inc R1
            djnz R2, F_th_copy_do_loop

    F_th_copy_done:
        ; restore A, B, and registers {{{
        pop 02h ; R2
        pop 01h ; R1
        pop 00h ; R0
        pop B
        pop acc
        ; }}}

        ret
    ; }}}

F_th_start: ; initiate transition {{{
    ; save registers {{{
    push 00h ; R0
    ; }}}

    ; reset crossfade
    mov R0, #Vm_led_xfade
    mov @R0, #0h
    
    ; enable timer
    setb TR0

    ; restore registers {{{
    pop 00h ; R0
    ; }}}

    ret
    ; }}}

F_th_int:   ; interrupt handler
    ; --- accounting ---
    ; R0 : start transition pointer
    ; R1 : end transition pointer
    ; R2 : LED rgb pointer
    ; R3 : crossfade value
    ; R4 : loop counter
    ; R5 : temp value storage
    ; R6 : transition speed

    ; save A, B, and registers {{{
    push acc
    push B
    push 00h    ; R0
    push 01h    ; R1
    push 02h    ; R2
    push 03h    ; R3
    push 04h    ; R4
    push 05h    ; R5
    push 06h    ; R6
    ; }}}

    ; get some values from memory
    mov R0, #Vm_led_xfade
    mov A, @R0
    mov R3, A

    mov R0, #Vm_led_rgbargs_cur
    mov A, @R0
    cjne A, #Vm_led_rgbargsB, F_th_int_Bstarts

    F_th_int_Astarts:
        mov R0, #Vm_led_rgbargsA
        mov R1, #Vm_led_rgbargsB
        ljmp F_th_int_do
    F_th_int_Bstarts:
        mov R0, #Vm_led_rgbargsB
        mov R1, #Vm_led_rgbargsA
        ljmp F_th_int_do

    F_th_int_do:
        mov R2, #Vm_led_rgbargs
        mov R4, #012d
        F_th_int_do_loop:
            mov A, #0FFh
            clr C
            subb A, R3
            mov B, A    ; B = 255-xfade
            mov A, @R0  ; A = start value
            mul AB      ; A*B
            mov R5, B   ; R5 holds result

            mov A, @R1  ; A = end value
            mov B, R3   ; B = xfade
            mul AB      ; A*B
            mov A, B    ; A holds result
            add A, R5   ; sum the two values
            mov B, A    ; store to B
            
            mov A, R2   ; A has output pointer
            xch A, R0   ; R0 now has output pointer
                        ; A has start pointer
            mov @R0, B  ; store output
            xch A, R0   ; A has output pointer
                        ; R0 has start pointer
            mov R2, A   ; R2 has output pointer

            inc R0      ; go to next start addr
            inc R1      ; go to next end addr
            inc R2      ; go to next output addr

            djnz R4, F_th_int_do_loop

    F_th_int_done:
        ; set panel
        lcall F_lp_setpixels
        ; increment xfade and store it to memory
        ; get increment amount
        mov R0, #Vm_eqb_vals+1
        mov A, @R0
        add A, R3
        ;mov A, R3
        mov R0, #Vm_led_xfade
        mov @R0, A
        ; if the result was 0, then the crossfader is done
        ; so stop the transition interrupt
        ; jnz F_th_int_done_skipstop
        jnc F_th_int_done_skipstop

        F_th_int_done_stop:
            mov @R0, #0FFh  ; set the crossfade to 255 so we stay at the last
                            ; color
            clr TR0         ; disable interrupt

        F_th_int_done_skipstop:
        ; restore A, B, and registers {{{
        pop 06h ; R6
        pop 05h ; R5
        pop 04h ; R4
        pop 03h ; R3
        pop 02h ; R2
        pop 01h ; R1
        pop 00h ; R0
        pop B
        pop acc
        ; }}}

        reti
    ; }}}

F_th_inittimer:
    mov TMOD, #022h
    mov TH0, #0128d
    setb ET0
    ret

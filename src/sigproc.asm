; vim: ts=4 sw=4 fdm=marker
;-------------------------------------------------------------------------------
; C E R E B R O
; J. Colosimo
; 6.115 Final Project
;
; SIGNAL PROCESSOR
; prefix: sp
; algorithms for signal processing
; NOTE: the output is in the Vm_led_argbuf buffer
;-------------------------------------------------------------------------------


;-------------------------------------------------------------------------------
; NEEDED VALUES
;-------------------------------------------------------------------------------
; Vm_eeg_sgnl, Vm_eeg_dlta, Vm_eeg_attn, Vm_eeg_mdtn
; Vm_led_argbuf

;-------------------------------------------------------------------------------
; CONSTANTS
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; FUNCTIONS
;-------------------------------------------------------------------------------
F_sp_process:   ; main signal processing function {{{
    ; --- accounting ---
    ; R0 : 
    ; R1 : 
    ; R2 : 
    ; R3 : 
    ; R4 : 
    ; R5 : 
    ; R6 : 
    ; R7 : 

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
    push 07h    ; R7
    ; }}}

    ; check the signal quality
    ; don't proceed unless the signal quality is perfect
    ; and otherwise, show a display based on signal quality
    ljmp F_sp_process_sigokay

    mov R0, #Vm_eeg_sgnl
    mov A, @R0
    jz F_sp_process_sigokay

    F_sp_process_sigbad:
        ; check to make sure that we don't have attention and meditation values
        ; before declaring the signal bad (we don't want to keep going back to
        ; bad signal mode if we can help it)
        mov R1, #Vm_eeg_attn
        mov A, @R1
        jnz F_sp_process_sigokay
        mov R1, #Vm_eeg_mdtn
        mov A, @R1
        jnz F_sp_process_sigokay
        
        ; okay, both of those values were 0, so the signal was bad
        lcall F_sp_sigbad
        ljmp F_sp_process_done

    F_sp_process_sigokay:
        lcall F_sp_sigokay
        ljmp F_sp_process_done

    F_sp_process_done:
        ; restore A, B, and registers {{{
        pop 07h ; R7
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

        ret
    ; }}}

F_sp_sigbad:    ; display bar if signal is bad {{{
    ; --- accounting ---
    ; R0 : signal quality
    ; R1 : rgb pointer
    ; R2 : counter

    ; no register storage and restoration needed since it's only called by
    ; F_sp_process

    mov R0, #Vm_eeg_sgnl
    mov A, @R0
    jz F_sp_sigbad_sensokay_end
    mov R0, A

    ; if the signal value is 200, then the sensors aren't touching the skin
    cjne A, #0200d, F_sp_sigbad_sensokay

    F_sp_sigbad_sensbad:
        ; if the sensors are bad, set the whole panel red
        mov R0, #Vm_led_argbuf
        mov R1, #012d
        F_sp_sigbad_sensbad_loop:
            mov @R0, #0h
            inc R0
            djnz R1, F_sp_sigbad_sensbad_loop

        mov R0, #Vm_led_argbuf
        mov @R0, #030h
        mov R0, #Vm_led_argbuf+3
        mov @R0, #030h
        mov R0, #Vm_led_argbuf+6
        mov @R0, #030h
        mov R0, #Vm_led_argbuf+9
        mov @R0, #030h
        ret

    F_sp_sigbad_sensokay:
        mov B, #020d    ; in practice, the signal quality varies between 0 and
                        ; 80, so divide among 4 pixels evenly
        div AB

        mov R2, B   ; temp
        mov B, A
        clr C
        mov A, #04d
        subb A, B   ; 4 - quotient gives signal quality low -> high
        mov R1, A   ; temp

        mov B, R2
        mov A, #020d
        clr C
        subb A, B   ; 20 - remainder gives sig quality remainder
        mov B, #04d
        mul AB      ; scale up

        mov B, A    ; B has remainder 0->79
        mov A, R1   ; A has quotient  0->4

        ; clear memory
        mov R2, #012d
        mov R1, #Vm_led_argbuf
        F_sp_sigbad_sensokay_memclear:
            mov @R1, #0h
            inc R1
            djnz R2, F_sp_sigbad_sensokay_memclear

        ; set panel
        F_sp_sigbad_sensokay_p0:
            mov R1, #Vm_led_argbuf+01d
            mov @R1, B
            cjne A, #00d, F_sp_sigbad_sensokay_p1
            ljmp F_sp_sigbad_sensokay_end

        F_sp_sigbad_sensokay_p1:
            mov R1, #Vm_led_argbuf+01d
            mov @R1, #080d
            mov R1, #Vm_led_argbuf+04d
            mov @R1, B
            cjne A, #01d, F_sp_sigbad_sensokay_p2
            ljmp F_sp_sigbad_sensokay_end

        F_sp_sigbad_sensokay_p2:
            mov R1, #Vm_led_argbuf+04d
            mov @R1, #080d
            mov R1, #Vm_led_argbuf+07d
            mov @R1, B
            cjne A, #02d, F_sp_sigbad_sensokay_p3
            ljmp F_sp_sigbad_sensokay_end

        F_sp_sigbad_sensokay_p3:
            mov R1, #Vm_led_argbuf+07d
            mov @R1, #080d
            mov R1, #Vm_led_argbuf+010d
            mov @R1, B
            cjne A, #03d, F_sp_sigbad_sensokay_p3
            ljmp F_sp_sigbad_sensokay_end

        F_sp_sigbad_sensokay_p4:
            mov R1, #Vm_led_argbuf+010d
            mov @R1, #080d
            ljmp F_sp_sigbad_sensokay_end

        F_sp_sigbad_sensokay_end:
            ret
    ; }}}

F_sp_sigokay:   ; signal processor {{{
    mov R0, #Vm_eqb_vals+2
    mov A, @R0

    F_sp_sigokay_check3:
        cjne A, #03h, F_sp_sigokay_check2
        lcall F_sp_algo3
        ljmp F_sp_sigokay_done

    F_sp_sigokay_check2:
        cjne A, #02h, F_sp_sigokay_check1
        lcall F_sp_algo2
        ljmp F_sp_sigokay_done

    F_sp_sigokay_check1:
        cjne A, #01h, F_sp_sigokay_check0
        lcall F_sp_algo1
        ljmp F_sp_sigokay_done

    F_sp_sigokay_check0:
        lcall F_sp_sigbad
        ljmp F_sp_sigokay_done

    F_sp_sigokay_done:
        ret
    ; }}}

F_sp_algo1: ; {{{
    mov R0, #Vm_eeg_sgnl
    mov A, @R0
    jnz F_sp_algo1_done

    ; set attention color {{{
    ; set attention hue
    ; we want it to vary from red -> green, which is about 0->85
    ; attention varies from 0->100 -- close enough
    mov B, #085d    ; 120/360x255 = 85
    mov R0, #Vm_eeg_attn
    mov A, @R0
    mov R3, A       ; R0 temporarily in R3
    ; set attention saturation
    mov R1, #0FFh
    ; set attention value
    ; take the delta, which is typically on the order of 10 and scale it
    mov R0, #Vm_eeg_attn
    mov A, @R0
    mov R0, #Vm_eeg_attn_lst
    mov B, @R0
    clr C
    subb A, B
    jnb OV, F_sp_sigokay_skipattncpl
        cpl A
        inc A
    F_sp_sigokay_skipattncpl:
    mov B, #04d
    mul AB
    mov R2, A

    mov A, R3
    mov R0, A       ; restore R0
    lcall F_cu_hsv2rgb      ; HSV -> RGB
    mov A, R0
    mov R3, A       ; R3 <- R0

    mov A, R3
    mov R0, #Vm_led_argbuf0
    mov @R0, A
    mov R0, #Vm_led_argbuf1
    mov @R0, A

    mov A, R1
    mov R0, #Vm_led_argbuf0+1
    mov @R0, A
    mov R0, #Vm_led_argbuf1+1
    mov @R0, A

    mov A, R2
    mov R0, #Vm_led_argbuf0+2
    mov @R0, A
    mov R0, #Vm_led_argbuf1+2
    mov @R0, A
    ;----------------------------------- }}}

    ; set meditation color {{{
    ; set meditation hue
    ; we want it to vary from cyan -> purple, which is about 0+128->85+128
    mov B, #085d    ; 120/360x255 = 85
    mov R0, #Vm_eeg_mdtn
    mov A, @R0
    add A, #080h    ; add 
    mov R3, A
    ; set meditation saturation
    mov R1, #0FFh
    ; set meditation value
    mov R0, #Vm_eeg_mdtn
    mov A, @R0
    mov R0, #Vm_eeg_mdtn_lst
    mov B, @R0
    clr C
    subb A, B
    jnb OV, F_sp_sigokay_skipmdtncpl
        cpl A
        inc A
    F_sp_sigokay_skipmdtncpl:
    mov B, #04d
    mul AB
    mov R2, A

    mov A, R3
    mov R0, A       ; restore R0
    lcall F_cu_hsv2rgb      ; HSV -> RGB
    mov A, R0
    mov R3, A       ; R3 <- R0

    mov A, R3
    mov R0, #Vm_led_argbuf2
    mov @R0, A
    mov R0, #Vm_led_argbuf3
    mov @R0, A

    mov A, R1
    mov R0, #Vm_led_argbuf2+1
    mov @R0, A
    mov R0, #Vm_led_argbuf3+1
    mov @R0, A

    mov A, R2
    mov R0, #Vm_led_argbuf2+2
    mov @R0, A
    mov R0, #Vm_led_argbuf3+2
    mov @R0, A
    ;----------------------------------- }}}

    F_sp_algo1_done:
    ret
    ; }}}

F_sp_algo2: ; {{{
    ; pixel 0
    mov R1, #0FFh           ; full saturation
    mov R0, #Vm_eeg_thta+1  ; 2nd byte of theta
    mov A, @R0
    clr C
    rrc A
    mov R2, A
    mov R0, #000d           ; red
    lcall F_cu_hsv2rgb

    mov A, R0   ; set red
    mov R0, #Vm_led_argbuf0
    mov @R0, A
    mov A, R1   ; set green
    inc R0
    mov @R0, A
    mov A, R2   ; set blue
    inc R0
    mov @R0, A
    ; ---

    ; pixel 1
    mov R1, #0FFh           ; full saturation
    mov R0, #Vm_eeg_lalp+1  ; 2nd byte of low alpha
    mov A, @R0
    clr C
    rrc A
    mov R2, A
    mov R0, #064d           ; green
    lcall F_cu_hsv2rgb

    mov A, R0   ; set red
    mov R0, #Vm_led_argbuf1
    mov @R0, A
    mov A, R1   ; set green
    inc R0
    mov @R0, A
    mov A, R2   ; set blue
    inc R0
    mov @R0, A
    ; ---

    ; pixel 2
    mov R1, #0FFh           ; full saturation
    mov R0, #Vm_eeg_lbet+1  ; 2nd byte of low beta
    mov A, @R0
    clr C
    rrc A
    mov R2, A
    mov R0, #0128d          ; blue
    lcall F_cu_hsv2rgb

    mov A, R0   ; set red
    mov R0, #Vm_led_argbuf2
    mov @R0, A
    mov A, R1   ; set green
    inc R0
    mov @R0, A
    mov A, R2   ; set blue
    inc R0
    mov @R0, A
    ; ---

    ; pixel 3
    mov R1, #0FFh           ; full saturation
    mov R0, #Vm_eeg_lgam+1  ; 2nd byte of low gamma
    mov A, @R0
    clr C
    rrc A
    mov R2, A
    mov R0, #0196d          ; purple
    lcall F_cu_hsv2rgb

    mov A, R0   ; set red
    mov R0, #Vm_led_argbuf3
    mov @R0, A
    mov A, R1   ; set green
    inc R0
    mov @R0, A
    mov A, R2   ; set blue
    inc R0
    mov @R0, A
    ; ---

    F_sp_algo2_done:
        ret
    ; }}}

F_sp_algo3:
    ; pixel 0 {{{
        ; hue
        mov R0, #Vm_eeg_dlta    ; !
        mov A, @R0
        mov R1, A
        mov R0, #Vm_eeg_thta+1  ; !
        mov A, @R0
        clr C
        subb A, R1              ; lowfreq - highfreq
        jc F_sp_algo3_p0morelft ; ! if lowfreq > highfreq, shift hue left

        F_sp_algo3_p0morergt:   ; !
            mov R7, #042d       ; !
            ljmp F_sp_algo3_p0hue ; !
        F_sp_algo3_p0morelft:   ; !
            mov R7, #0d         ; !
            ljmp F_sp_algo3_p0hue ; !

        F_sp_algo3_p0hue:       ; !
            mov R1, #Vm_eqb_vals+3
            mov B, @R1              ; B = ewma
            mov A, #0FFh
            clr C
            subb A, B               ; A = 1-ewma

            mov R0, #Vm_ewma_p0hue  ; !
            mov B, @R0              ; B = oldhue
            mul AB
            mov R3, B               ; R3 = (1-ewma)*oldhue

            mov B, @R1              ; B = ewma
            mov A, R7               ; R7 is newhue
            mul AB                  ; B = (ewma)*newhue
            mov A, R3
            add A, B
            mov R3, A               ; R3 = ewma*newhue + (1-ewma)*oldhue

        ; value
        V_sp_algo3_p0val:       ; !
            mov R1, #Vm_eqb_vals+4
            mov B, @R1              ; B = ewma
            mov A, #0FFh
            clr C
            subb A, B               ; A = 1-ewma

            mov R0, #Vm_ewma_p0val  ; !
            mov B, @R0              ; B = oldval
            mul AB
            mov R4, B               ; R4 = (1-ewma)*oldval

            mov R0, #Vm_eeg_dlta    ; !
            mov A, @R0
            clr C
            rrc A
            mov B, A
            mov R0, #Vm_eeg_thta+1  ; !
            mov A, @R0
            clr C
            rrc A
            add A, B                ; A = newval (average)
            mov B, @R1              ; B = ewma
            mul AB
            mov A, R4
            add A, B
            mov R4, A               ; R4 = ewma*newval + (1-ewma)*oldval

        ; update old values
        mov R0, #Vm_ewma_p0hue      ; !
        mov A, R3
        mov @R0, A
        mov R0, #Vm_ewma_p0val      ; !
        mov A, R4
        mov @R0, A

        ; set everything
        mov A, R3
        mov R0, A
        mov R1, #0FFh
        mov A, R4
        mov R2, A

        lcall F_cu_hsv2rgb

        mov A, R0   ; set red
        mov R0, #Vm_led_argbuf0     ; !
        mov @R0, A
        mov A, R1   ; set green
        inc R0
        mov @R0, A
        mov A, R2   ; set blue
        inc R0
        mov @R0, A
    ; }}}

    ; pixel 1 {{{
        ; hue
        mov R0, #Vm_eeg_lalp+1  ; !
        mov A, @R0
        mov R1, A
        mov R0, #Vm_eeg_halp+1  ; !
        mov A, @R0
        clr C
        subb A, R1              ; lowfreq - highfreq
        jc F_sp_algo3_p1morelft ; ! if lowfreq > highfreq, shift hue left

        F_sp_algo3_p1morergt:   ; !
            mov R7, #084d       ; !
            ljmp F_sp_algo3_p1hue ; !
        F_sp_algo3_p1morelft:   ; !
            mov R7, #042d       ; !
            ljmp F_sp_algo3_p1hue ; !

        F_sp_algo3_p1hue:       ; !
            mov R1, #Vm_eqb_vals+3
            mov B, @R1              ; B = ewma
            mov A, #0FFh
            clr C
            subb A, B               ; A = 1-ewma
            mov R0, #Vm_ewma_p1hue  ; !
            mov B, @R0              ; B = oldhue
            mul AB
            mov R3, B               ; R3 = (1-ewma)*oldhue

            mov B, @R1              ; B = ewma
            mov A, R7               ; R7 is newhue
            mul AB                  ; B = (ewma)*newhue
            mov A, R3
            add A, B
            mov R3, A               ; R3 = ewma*newhue + (1-ewma)*oldhue

        ; value
        V_sp_algo3_p1val:       ; !
            mov R1, #Vm_eqb_vals+5  ; !
            mov B, @R1              ; B = ewma
            mov A, #0FFh
            clr C
            subb A, B               ; A = 1-ewma

            mov R0, #Vm_ewma_p1val  ; !
            mov B, @R0              ; B = oldval
            mul AB
            mov R4, B               ; R4 = (1-ewma)*oldval

            mov R0, #Vm_eeg_lalp+1  ; !
            mov A, @R0
            clr C
            rrc A
            mov B, A
            mov R0, #Vm_eeg_halp+1  ; !
            mov A, @R0
            clr C
            rrc A
            add A, B                ; A = newval (average)
            mov B, @R1              ; B = ewma
            mul AB
            mov A, R4
            add A, B
            mov R4, A               ; R4 = ewma*newval + (1-ewma)*oldval

        ; update old values
        mov R0, #Vm_ewma_p1hue      ; !
        mov A, R3
        mov @R0, A
        mov R0, #Vm_ewma_p1val      ; !
        mov A, R4
        mov @R0, A

        ; set everything
        mov A, R3
        mov R0, A
        mov R1, #0FFh
        mov A, R4
        mov R2, A

        lcall F_cu_hsv2rgb

        mov A, R0   ; set red
        mov R0, #Vm_led_argbuf1     ; !
        mov @R0, A
        mov A, R1   ; set green
        inc R0
        mov @R0, A
        mov A, R2   ; set blue
        inc R0
        mov @R0, A
    ; }}}

    ; pixel 2 {{{
        ; hue
        mov R0, #Vm_eeg_lbet+1  ; !
        mov A, @R0
        mov R1, A
        mov R0, #Vm_eeg_hbet+1  ; !
        mov A, @R0
        clr C
        subb A, R1              ; lowfreq - highfreq
        jc F_sp_algo3_p2morelft ; ! if lowfreq > highfreq, shift hue left

        F_sp_algo3_p2morergt:   ; !
            mov R7, #0126d      ; !
            ljmp F_sp_algo3_p2hue ; !
        F_sp_algo3_p2morelft:   ; !
            mov R7, #084d       ; !
            ljmp F_sp_algo3_p2hue ; !

        F_sp_algo3_p2hue:       ; !
            mov R1, #Vm_eqb_vals+3
            mov B, @R1              ; B = ewma
            mov A, #0FFh
            clr C
            subb A, B               ; A = 1-ewma
            mov R0, #Vm_ewma_p2hue  ; !
            mov B, @R0              ; B = oldhue
            mul AB
            mov R3, B               ; R3 = (1-ewma)*oldhue

            mov B, @R1              ; B = ewma
            mov A, R7               ; R7 is newhue
            mul AB                  ; B = (ewma)*newhue
            mov A, R3
            add A, B
            mov R3, A               ; R3 = ewma*newhue + (1-ewma)*oldhue

        ; value
        V_sp_algo3_p2val:       ; !
            mov R1, #Vm_eqb_vals+6  ; !
            mov B, @R1              ; B = ewma
            mov A, #0FFh
            clr C
            subb A, B               ; A = 1-ewma

            mov R0, #Vm_ewma_p2val  ; !
            mov B, @R0              ; B = oldval
            mul AB
            mov R4, B               ; R4 = (1-ewma)*oldval

            mov R0, #Vm_eeg_lbet+1  ; !
            mov A, @R0
            clr C
            rrc A
            mov B, A
            mov R0, #Vm_eeg_hbet+1  ; !
            mov A, @R0
            clr C
            rrc A
            add A, B                ; A = newval (average)
            mov B, @R1              ; B = ewma
            mul AB
            mov A, R4
            add A, B
            mov R4, A               ; R4 = ewma*newval + (1-ewma)*oldval

        ; update old values
        mov R0, #Vm_ewma_p2hue      ; !
        mov A, R3
        mov @R0, A
        mov R0, #Vm_ewma_p2val      ; !
        mov A, R4
        mov @R0, A

        ; set everything
        mov A, R3
        mov R0, A
        mov R1, #0FFh
        mov A, R4
        mov R2, A

        lcall F_cu_hsv2rgb

        mov A, R0   ; set red
        mov R0, #Vm_led_argbuf2     ; !
        mov @R0, A
        mov A, R1   ; set green
        inc R0
        mov @R0, A
        mov A, R2   ; set blue
        inc R0
        mov @R0, A
    ; }}}

    ; pixel 3 {{{
        ; hue
        mov R0, #Vm_eeg_lgam+1  ; !
        mov @R0, A
        mov R1, A
        mov R0, #Vm_eeg_mgam+1  ; !
        mov @R0, A
        clr C
        rlc A
        clr C
        subb A, R1              ; lowfreq - highfreq
        jc F_sp_algo3_p3morelft ; ! if lowfreq > highfreq, shift hue left

        F_sp_algo3_p3morergt:   ; !
            mov R7, #0168d      ; !
            ljmp F_sp_algo3_p3hue ; !
        F_sp_algo3_p3morelft:   ; !
            mov R7, #0126d      ; !
            ljmp F_sp_algo3_p3hue ; !

        F_sp_algo3_p3hue:       ; !
            mov R1, #Vm_eqb_vals+3
            mov B, @R1              ; B = ewma
            mov A, #0FFh
            clr C
            subb A, B               ; A = 1-ewma

            mov R0, #Vm_ewma_p3hue  ; !
            mov B, @R0              ; B = oldhue
            mul AB
            mov R3, B               ; R3 = (1-ewma)*oldhue
            mov A, B

            mov B, @R1              ; B = ewma
            mov A, R7               ; R7 is newhue
            mul AB                  ; B = (ewma)*newhue
            mov A, R3
            add A, B
            mov R3, A               ; R3 = ewma*newhue + (1-ewma)*oldhue

        ; value
        V_sp_algo3_p3val:       ; !
            mov R1, #Vm_eqb_vals+7  ; !
            mov B, @R1              ; B = ewma
            mov A, #0FFh
            clr C
            subb A, B               ; A = 1-ewma

            mov R0, #Vm_ewma_p3val  ; !
            mov B, @R0              ; B = oldval
            mul AB
            mov R4, B               ; R4 = (1-ewma)*oldval

            mov R0, #Vm_eeg_lgam+1  ; !
            mov A, @R0
            clr C
            rrc A
            mov B, A
            mov R0, #Vm_eeg_mgam+1  ; !
            mov A, @R0
            clr C
            rrc A
            add A, B                ; A = newval (average)
            mov B, @R1              ; B = ewma
            mul AB
            mov A, R4
            add A, B
            mov R4, A               ; R4 = ewma*newval + (1-ewma)*oldval

        ; update old values
        mov R0, #Vm_ewma_p3hue      ; !
        mov A, R3
        mov @R0, A
        mov R0, #Vm_ewma_p3val      ; !
        mov A, R4
        mov @R0, A

        ; set everything
        mov A, R3
        mov R0, A
        mov R1, #0FFh
        mov A, R4
        mov R2, A

        lcall F_cu_hsv2rgb

        mov A, R0   ; set red
        mov R0, #Vm_led_argbuf3     ; !
        mov @R0, A
        mov A, R1   ; set green
        inc R0
        mov @R0, A
        mov A, R2   ; set blue
        inc R0
        mov @R0, A
    ; }}}

    F_sp_algo3_done:
        ret

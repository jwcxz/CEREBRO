; vim: ts=4 sw=4 fdm=marker
;-------------------------------------------------------------------------------
; C E R E B R O
; J. Colosimo
; 6.115 Final Project
;
; COLOR UTILITIES
; prefix: cu
; algorithms for processing color information
;-------------------------------------------------------------------------------


;-------------------------------------------------------------------------------
; CONSTANTS
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; FUNCTIONS
;-------------------------------------------------------------------------------
F_cu_hsv2rgb:   ; converts hsv values into rgb {{{
    ; args: R0:hue, R1:sat, R2:val
    ; out : R0:red, R1:grn, R2:blu
    ; --- accounting --- {{{
    ; R0 : hue -> red
    ; R1 : sat -> grn
    ; R2 : val -> blu
    ; 
    ; R3 : h*
    ; R4 : f
    ; R5 : p
    ; R6 : q
    ; R7 : t
    ; }}}

    ; save A, B, and registers {{{
    push acc
    push B
    push 03h    ; R3
    push 04h    ; R4
    push 05h    ; R5
    push 06h    ; R6
    push 07h    ; R7
    ; }}}

    ; notes:
    ;   - hue ranges from 0 -> 255 and wraps around
    ;     that means that each increment in value corresponds to a shift in
    ;     360/255 = 1.412 degrees
    ;   - sat and val both range from 0 -> 255
    ;   - this is not a very accurate calculation -- you need more bits of
    ;     precision to get an accurate calculation.  However, it's very close
    ;     (running a simple program that cycles through hues proved this) and
    ;     therefore fine for this application.

    ; first, we want h*, the hex hue chunk of a value
    ;   60 / (360/255) = 42.5, so each hexagonal hue chunk is roughly spaced
    ;   42.5 vals away. okay, so that's a bit annoying, but we can make some
    ;   spaced at 42 and others at 43 as follows:
    ;   |   42  |   43  |   42  |   43  |   42  |   43  |
    ;   |   0   |   1   |   2   |   3   |   4   |   5   |
    ;   |  0: 41| 42: 84| 85:126|127:169|170:211|212:255|

    mov A, R0
    mov B, #042d
    div AB
    
    cjne A, #06d, F_cu_hsv2rgb_continue
        mov R3, 0
        mov R4, 0
        sjmp F_cu_hsv2rgb_skip
    F_cu_hsv2rgb_continue:
        ; the quotient is the unfair h*
        mov R3, A
        ; the remainder is called "f"
        mov R4, B

    F_cu_hsv2rgb_skip:
    ; now to even things out a bit, look at unfair h* and f
    
    ; next compute p = v * ( 1 - s )
    mov A, #0FFh
    clr C
    subb A, R1      ; A = 255 - s
    mov B, R2       ; B = val
    mul AB          ; p = val * (255 - s)
    mov R5, B       ; p = top byte (range shift 256*256 -> 256)

    ; and q = v * ( 1 - f*s )
    mov A, R4       ; A = f
    mov B, R1       ; B = s
    mul AB          ; compute f*s   (range 0->255*41)
    ;-------------  TODO: subroutine-ify
    ; now we need a range shift from 0->255*41 to 0->255
    ; we do this by multiplying the value by 255/42 = 6 and taking the top byte
    push 00h ; R0
    push 01h ; R1

    mov R0, B       ; save high byte of multiplication
    mov B, #06d
    mul AB          ; multiply low byte
    mov R1, B       ; we only care about high byte of that result
    mov A, R0
    mov B, #06d
    mul AB          ; multiply previous high byte by 6
    add A, R1       ; add low byte of the result to the high byte of the previous result

    pop 01h ; R1
    pop 00h ; R0
    ;-------------
    mov B, A        ; move quotient to B
    mov A, #0FFh
    clr C
    subb A, B       ; A = 255 - f*s
    mov B, R2       ; B = val
    mul AB          ; q = val * (255 - f*s)
    mov R6, B       ; q = top byte

    ; and finally t = v * ( 1 - ( 1 - f ) * s )
    mov A, #042d
    clr C
    subb A, R4      ; A = 42 - f
    mov B, R1       ; B = sat
    mul AB          ; AB = (42-f)*s
    ;-------------  TODO: subroutine-ify
    ; now we need a range shift from 0->255*41 to 0->255
    ; we do this by multiplying the value by 255/42 = 6 and taking the top byte
    push 00h ; R0
    push 01h ; R1

    mov R0, B       ; save high byte of multiplication
    mov B, #06d
    mul AB          ; multiply low byte
    mov R1, B       ; we only care about high byte of that result
    mov A, R0
    mov B, #06d
    mul AB          ; multiply previous high byte by 6
    add A, R1       ; add low byte of the result to the high byte of the previous result

    pop 01h ; R1
    pop 00h ; R0
    ;-------------
    mov B, A        ; move quotient to B
    mov A, #0FFh
    clr C
    subb A, B       ; A = 255 - (42-f)*s
    mov B, R2       ; B = val
    mul AB          ; t = val * (255 - (42-f)*s)
    mov R7, B       ; t = top byte

    ; lastly, figure out how to set rgb based on the value of h*:
    F_cu_hsv2rgb_h0:    ; rgb = vtp
        cjne R3, #00h, F_cu_hsv2rgb_h1
        mov A, R2       ; v
        mov R0, A
        mov A, R7       ; t
        mov R1, A
        mov A, R5       ; p
        mov R2, A
        ljmp F_cu_hsv2rgb_end

    F_cu_hsv2rgb_h1:    ; rgb = qvp
        cjne R3, #01h, F_cu_hsv2rgb_h2
        mov A, R6       ; q
        mov R0, A
        mov A, R2       ; v
        mov R1, A
        mov A, R5       ; p
        mov R2, A
        ljmp F_cu_hsv2rgb_end

    F_cu_hsv2rgb_h2:    ; rgb = pvt
        cjne R3, #02h, F_cu_hsv2rgb_h3
        mov A, R5       ; p
        mov R0, A
        mov A, R2       ; v
        mov R1, A
        mov A, R7       ; t
        mov R2, A
        ljmp F_cu_hsv2rgb_end

    F_cu_hsv2rgb_h3:    ; rgb = pqv
        cjne R3, #03h, F_cu_hsv2rgb_h4
        mov A, R5       ; p
        mov R0, A
        mov A, R6       ; q
        mov R1, A
        mov A, R2       ; v
        mov R2, A
        ljmp F_cu_hsv2rgb_end

    F_cu_hsv2rgb_h4:    ; rgb = tpv
        cjne R3, #04h, F_cu_hsv2rgb_h5
        mov A, R7       ; t
        mov R0, A
        mov A, R5       ; p
        mov R1, A
        mov A, R2       ; v
        mov R2, A
        ljmp F_cu_hsv2rgb_end

    F_cu_hsv2rgb_h5:    ; rgb = vpq
        mov A, R2       ; v
        mov R0, A
        mov A, R5       ; p
        mov R1, A
        mov A, R6       ; q
        mov R2, A
        ljmp F_cu_hsv2rgb_end

    F_cu_hsv2rgb_end:
        ; restore A, B, and registers {{{
        pop 07h     ; R7
        pop 06h     ; R6
        pop 05h     ; R5
        pop 04h     ; R4
        pop 03h     ; R3
        pop B
        pop acc
        ; }}}

        ret
    ; }}}

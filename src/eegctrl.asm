; vim: ts=4 sw=4 fdm=marker
;-------------------------------------------------------------------------------
; C E R E B R O
; J. Colosimo
; 6.115 Final Project
;
; EEG PACKET CAPTURE LIBRARY
; prefix: ec
; reads packet data from 16C450 and stores signal strength, the 8 EEG values,
; and the attention and meditation eSense values
;-------------------------------------------------------------------------------


;-------------------------------------------------------------------------------
; NEEDED VALUES
;-------------------------------------------------------------------------------
; UART:  Va_eeg_dll, Va_eeg_dlm, Va_eeg_ier, Va_eeg_lcr, Va_eeg_lsr, Va_eeg_rxb
; Vm_eeg_pptr_d - base address for payload storage
; Vm_eeg_smst   - address of memory to store state machine state
; Vm_eeg_plen   - address of memory to store packet length
; Vm_eeg_pptr   - address of memory to store payload pointer
; Vm_eeg_csum   - address of memory to store current checksum calculation
; Vm_eeg_sgnl   - address of memory to store signal value
; Vm_eeg_dlta   - address of memory to store first delta byte (start of 24-bytes
;                 of FFT values)
; Vm_eeg_attn   - address of memory to store attention value
; Vm_eeg_mdtn   - address of memory to store meditation value

;-------------------------------------------------------------------------------
; CONSTANTS
;-------------------------------------------------------------------------------
V_ec_st_sync1 equ 00h
V_ec_st_sync2 equ 01h
V_ec_st_plnth equ 02h
V_ec_st_payld equ 03h
V_ec_st_chksm equ 04h

V_ec_val_sync equ 0AAh

;-------------------------------------------------------------------------------
; FUNCTIONS
;-------------------------------------------------------------------------------
F_ec_int:   ; interrupt handler {{{
    ; --- accounting ---
    ; R0 : current state    <-> mem
    ; R1 : captured byte    <-> mem
    ; R2 : packet length    <-> mem
    ; R3 : running checksum <-> mem
    ; R4 : packet buffer pointer <-> mem

    ; save A, B, and registers {{{
    push acc
    push B
    push DPH
    push DPL
    push 00h    ; R0
    push 01h    ; R1
    push 02h    ; R2
    push 03h    ; R3
    push 04h    ; R4
    ; }}}

    ; get memory values {{{
    ; note: these are all indirect memory accesses, so the extra memory (80-FF)
    ; can be used, too
    mov R1, #Vm_eeg_smst
    mov A, @R1
    mov R0, A

    mov R1, #Vm_eeg_plen
    mov A, @R1
    mov R2, A

    mov R1, #Vm_eeg_csum
    mov A, @R1
    mov R3, A

    mov R1, #Vm_eeg_pptr
    mov A, @R1
    mov R4, A
    ; }}}

    ; this interrupt is called when we have heard something on the UART
    ; interrupt port

    F_ec_int_getbyte:
        ; check line status reg to make sure we have a byte
        ;mov DPTR, #Va_eeg_lsr
        ;movx A, @DPTR
        ;anl A, #01h         ; bit 0 is data ready
        ;jz F_ec_int_end

        ; reading receiver buffer clears the interrupt, so do that
        mov DPTR, #Va_eeg_rxb
        movx A, @DPTR
        mov R1, A

    F_ec_int_updatesm:
        ; run one step of the state machine with the new byte

        F_ec_int_us_sync1:
            cjne R0, #V_ec_st_sync1, F_ec_int_us_sync2      ; state == sync1 ?

            cjne R1, #V_ec_val_sync, F_ec_int_us_sync1_nosync ; received sync byte?
                ; reset state machine counters
                mov R3, #0h             ; reset running checksum to 0
                mov R4, #Vm_eeg_pptr_d  ; set packet pointer to starting address
                mov R2, #0h             ; invalidate packet length (FIXME: not necessary)

                ; new state -> sync2
                mov R0, #V_ec_st_sync2
                ljmp F_ec_int_us_sync1_done

            F_ec_int_us_sync1_nosync:
                mov R0, #V_ec_st_sync1  ; if no sync received, reset state machine

            F_ec_int_us_sync1_done:
                ljmp F_ec_int_us_done

        F_ec_int_us_sync2:
            cjne R0, #V_ec_st_sync2, F_ec_int_us_plnth      ; state == sync2 ?

            cjne R1, #V_ec_val_sync, F_ec_int_us_sync2_nosync ; received sync byte?
                ; new state -> plnth
                mov R0, #V_ec_st_plnth
                ljmp F_ec_int_us_sync2_done

            F_ec_int_us_sync2_nosync:
                mov R0, #V_ec_st_sync1  ; if no sync received, reset state machine

            F_ec_int_us_sync2_done:
                ljmp F_ec_int_us_done

        F_ec_int_us_plnth:
            cjne R0, #V_ec_st_plnth, F_ec_int_us_payld      ; state == plnth ?

            ; TODO: check packet size here?
            ; packets can concievably be up to 160 bytes long, but I've never
            ; seen anything other than 32-byte packets

            mov A, R1   ; save packet length
            add A, #01h
            mov R2, A

            ; new state -> payld
            mov R0, #V_ec_st_payld  

            F_ec_int_us_plnth_done:
                ljmp F_ec_int_us_done

        F_ec_int_us_payld:
            cjne R0, #V_ec_st_payld, F_ec_int_us_chksm      ; state == payld ?

            ; if we haven't hit the end of the packet length yet... save
            ; current byte, increment memory pointer, and add to
            ; checksum
            ; otherwise, new state is chksm

            djnz R2, F_ec_int_us_payld_save

            F_ec_int_us_payld_completed:
                ;mov R0, #V_ec_st_chksm  ; if not, move to checksum stage
                ;ljmp F_ec_int_us_payld_done
                ; if not, jump to checksumming
                mov R0, #V_ec_st_chksm  ; FIXME: not necessary
                ljmp F_ec_int_us_chksm

            F_ec_int_us_payld_save:
                mov B, R1       ; B <- R1
                mov A, R4
                mov R1, A       ; R1 = R4
                mov @R1, B      ; save current byte
                mov R1, B       ; R1 <- B

                inc R4          ; increment pointer
                mov A, R3
                add A, R1       ; add to checksum
                mov R3, A

            F_ec_int_us_payld_done:
                ljmp F_ec_int_us_done

        F_ec_int_us_chksm:
            ; TODO cjne with error condition (state machine reset?)
            ; cjne R0, #V_ec_st_chksm, F_ec_int_us_error    ; state == chksm ?

            ; check to see that we have a valid checksum
            mov A, R3
            cpl A
            mov R3, A   ; save checksum back

            ; FIXME: for debugging
            ;mov R3, A   ; save checksum back
            ;mov R0, #Vm_eeg_csum_got
            ;mov B, R1
            ;mov @R0, B

            ; new state -> sync1
            mov R0, #V_ec_st_sync1

            ; hack: use R1 = 01h
            cjne A, 01h, F_ec_int_us_chksm_bad

            F_ec_int_us_chksm_good:
                ; the checksum was good, so we can now do one of two options:
                ;   1. process the payload right now and extract data from it
                ;   2. send a signal for the main loop to process the payload

                ; try processing the payload here
                lcall F_ec_pld
                mov R1, #Vm_eeg_drdy
                mov @R1, #01h           ; data is now ready

                ljmp F_ec_int_us_done

            F_ec_int_us_chksm_bad:
                ; the checksum was bad, so don't do anything
                ; TODO: turn this into some kind of error condition (spit out
                ;       something on serial?)
                mov A, #'B'
                lcall F_sc_tx

                ljmp F_ec_int_us_done

    F_ec_int_us_done:

    F_ec_int_end:
        ; set memory values {{{
        mov R1, #Vm_eeg_smst
        mov A, R0
        mov @R1, A

        mov R1, #Vm_eeg_plen
        mov A, R2
        mov @R1, A

        mov R1, #Vm_eeg_csum
        mov A, R3
        mov @R1, A

        mov R1, #Vm_eeg_pptr
        mov A, R4
        mov @R1, A
        ; }}}

        ; restore A, B, and registers {{{
        pop 04h ; R4
        pop 03h ; R3
        pop 02h ; R2
        pop 01h ; R1
        pop 00h ; R0
        pop DPL
        pop DPH
        pop B
        pop acc
        ; }}}

        reti
    ; }}}

F_ec_initeeg:   ; initialize EEG UART {{{
    ; reset state machine
    push 00h ; R0
    mov R0, #Vm_eeg_smst
    mov @R0, #V_ec_st_sync1
    pop 00h ; R0

    ; set line control register
    ;   0b10000011
    ;   set-dlab no-break stick-parity odd-parity
    ;   no-parity 1-stop-bit 8-bit-words[2]
    mov A, #083h
    mov DPTR, #Va_eeg_lcr
    movx @DPTR, A

    ; set divisor
    ;   1.842e6/16/9600 ~= 12
    mov A, #0Ch
    mov DPTR, #Va_eeg_dll
    movx @DPTR, A
    mov A, #000h
    mov DPTR, #Va_eeg_dlm
    movx @DPTR, A

    ; clear divisor latch
    mov A, #003h
    mov DPTR, #Va_eeg_lcr
    movx @DPTR, A

    ; set interrupts
    ;   enable the interrupt on received data available
    mov A, #001h
    mov DPTR, #Va_eeg_ier
    movx @DPTR, A

    setb EX0
    setb P3.2
    setb PX0    ; set high priority on the external interrupt
    ;setb IT0
    ; FIXME: don't forget to set EA

    ret
    ; }}}

F_ec_pld:   ; process payload {{{
    ; --- accounting ---
    ; R0 : current state    <- 0x
    ; R1 : captured byte    <- 0x
    ; R2 : packet length
    ; R3 : running checksum
    ; R4 : packet buffer pointer

    ; save A, B, and registers {{{
    push acc
    push B
    push 00h    ; R0
    push 01h    ; R1
    push 02h    ; R2
    ; }}}

    ; this is cheating a bit -- I'm not following the proper payload processing
    ; guidelines because the mindset always outputs packets in the same form

    mov R0, #Vm_eeg_pptr_d+001d     ; signal quality
    mov R1, #Vm_eeg_sgnl
    mov A, @R0
    mov @R1, A

    mov R0, #Vm_eeg_pptr_d+029d     ; attention
    mov R1, #Vm_eeg_attn
    mov A, @R0
    mov @R1, A

    mov R0, #Vm_eeg_pptr_d+031d     ; meditation
    mov R1, #Vm_eeg_mdtn
    mov A, @R0
    mov @R1, A

    ; FFT values
    ; to capture these, make a memory block starting at Vm_eeg_dlta
    ; each value is 3 bytes long
    ; there are 8 values => 24 bytes
    ; delta, theta, loalpha, hialpha, lobeta, hibeta, logamma, mdgamma
    mov R0, #Vm_eeg_pptr_d+004d
    mov R1, #Vm_eeg_dlta
    mov R2, #024d
    F_ec_pld_fftloop:
        mov A, @R0
        mov @R1, A
        inc R0
        inc R1
        djnz R2, F_ec_pld_fftloop

    F_ec_pld_done:
        ; restore A, B, and registers {{{
        pop 02h ; R2
        pop 01h ; R1
        pop 00h ; R0
        pop B
        pop acc
        ; }}}

        ret
    ; }}}

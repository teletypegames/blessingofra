; -----------------------------------------------------------
; win.asm - the escape screen: big ESCAPED with the gold
; wash; fire returns to the main menu
; -----------------------------------------------------------

win_init:
    jsr clear_screen

    +prbig 3, 6, YELLOW, txt_escaped, 7

    +prtext 11, 15, WHITE, txt_welldone, txt_welldonee-txt_welldone
    +prtext 13, 10, LGREY, txt_beaten, txt_beatene-txt_beaten

    lda #0
    sta washphase
    +setupd win_update
    rts

win_update:
    ; the gold wash rolls down the big letters (rows 3-7)
    inc washphase
    lda #0
    sta rtmp2
wu_row:
    lda #3
    clc
    adc rtmp2
    tax
    jsr row_ptr
    lda washphase
    lsr
    clc
    adc rtmp2
    and #15
    tax
    lda washtbl,x
    sta rtmp
    ldy #32              ; the letters span columns 6-32
wu_col:
    lda (scrlo),y
    cmp #$a0
    bne wu_skip
    lda rtmp
    sta (collo),y
wu_skip:
    dey
    cpy #5
    bne wu_col
    inc rtmp2
    lda rtmp2
    cmp #5
    bne wu_row

    ; blink the prompt
    lda framectr
    and #32
    bne wu_hide
    +prtext 20, 14, YELLOW, txt_firemenu, txt_firemenue-txt_firemenu
    jmp wu_input
wu_hide:
    +prtext 20, 14, YELLOW, txt_blank, txt_firemenue-txt_firemenu
wu_input:
    jsr start_edge
    beq wu_stay
    jmp menu_init        ; a win leads back to the main screen
wu_stay:
    rts

; ---- win texts ----
txt_escaped:  !scr "escaped"
txt_welldone: !scr "well done!"
txt_welldonee:
txt_beaten:   !scr "you beat labyrintwo"
txt_beatene:
txt_firemenu: !scr "fire = menu"
txt_firemenue:

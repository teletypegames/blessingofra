; -----------------------------------------------------------
; options.asm - optional extras, toggled with fire:
;   worker gun    - player 1 shoots with fire; a hit enemy
;                   respawns elsewhere after a pause
;   spin cooldown - ra needs a recharge between two spins,
;                   shown on the status row
;   start level   - which level a fresh run begins on (1-8)
; the settings live here and survive between levels
; -----------------------------------------------------------

OPT_ITEMS = 4

options_init:
    jsr clear_screen

    +prbig 1, 6, WHITE, txt_options, 7

    +prtext 21, 6, LGREY, txt_oh1, txt_oh1e-txt_oh1
    +prtext 22, 4, LGREY, txt_oh2, txt_oh2e-txt_oh2
    +prtext 23, 5, LGREY, txt_oh3, txt_oh3e-txt_oh3

    lda #0
    sta optsel
    +setupd options_update
    rts

options_update:
    ; joystick / w-s steps the cursor (edge detected)
    jsr read_joy
    lda joyb
    and #3
    beq ou_udrel
    lda udheld
    bne ou_udend
    lda #1
    sta udheld
    lda joyb
    and #1               ; up
    beq ou_down
    lda optsel
    beq ou_udend
    dec optsel
    lda #SFX_CURSOR
    jsr sfx_play
    jmp ou_udend
ou_down:
    lda optsel
    cmp #OPT_ITEMS-1
    beq ou_udend
    inc optsel
    lda #SFX_CURSOR
    jsr sfx_play
    jmp ou_udend
ou_udrel:
    lda #0
    sta udheld
ou_udend:

    ; the three lines, the picked one in yellow
    ldx #0
oo_items:
    txa
    pha
    jsr draw_oitem
    pla
    tax
    inx
    cpx #OPT_ITEMS
    bne oo_items

    ; the current values next to the three settings
    ldx opt_shoot
    lda #10
    jsr put_oval
    ldx opt_cool
    lda #13
    jsr put_oval
    lda opt_level        ; the start level as a digit
    ora #$30
    sta SCREEN+16*40+24
    lda #LGREEN
    sta COLRAM+16*40+24

    ; blinking '>' cursor in front of the picked line
    lda #$20
    sta SCREEN+10*40+7
    sta SCREEN+13*40+7
    sta SCREEN+16*40+7
    sta SCREEN+19*40+7
    lda framectr
    and #16
    bne ou_fire
    ldx optsel
    lda ocur_lo,x
    sta scrlo
    lda ocur_hi,x
    sta scrhi
    ldy #0
    lda #62              ; '>'
    sta (scrlo),y
    lda scrhi
    clc
    adc #$d4             ; same cell in color RAM
    sta scrhi
    lda #YELLOW
    sta (scrlo),y

ou_fire:
    ; fire toggles the picked setting / leaves on back
    jsr start_edge
    beq ou_done
    lda optsel
    cmp #3
    beq ou_back
    cmp #2
    beq ou_tlevel
    cmp #1
    beq ou_tcool
    lda opt_shoot
    eor #1
    sta opt_shoot
    jmp ou_tsfx
ou_tcool:
    lda opt_cool
    eor #1
    sta opt_cool
    jmp ou_tsfx
ou_tlevel:
    ldx opt_level        ; cycle 1-8, wrapping back to 1
    inx
    cpx #MZMAX-MZMIN+2
    bne ou_tlst
    ldx #1
ou_tlst:
    stx opt_level
ou_tsfx:
    lda #SFX_SELECT
    jsr sfx_play
ou_done:
    rts
ou_back:
    lda #SFX_SELECT
    jsr sfx_play
    +fadeto menu_init

; ---- draw option line X, yellow when it is the picked one ----
draw_oitem:
    lda oitem_lo,x
    sta txtlo
    lda oitem_hi,x
    sta txthi
    lda oitem_row,x
    sta prow
    lda #9
    sta pcol
    lda oitem_len,x
    sta plen
    lda #WHITE
    cpx optsel
    bne do_store
    lda #YELLOW
do_store:
    sta pcolor
    jmp print_text

; ---- print the on/off value: X = 0/1, A = screen row ----
put_oval:
    sta prow
    lda ovtx_lo,x
    sta txtlo
    lda ovtx_hi,x
    sta txthi
    lda ovcol,x
    sta pcolor
    lda #24
    sta pcol
    lda #3
    sta plen
    jmp print_text

; ---- option tables ----
oitem_lo:  !byte <txt_ogun, <txt_ocool, <txt_olev, <txt_oback
oitem_hi:  !byte >txt_ogun, >txt_ocool, >txt_olev, >txt_oback
oitem_len: !byte 10, 13, 11, 4
oitem_row: !byte 10, 13, 16, 19
ocur_lo:                 ; cursor cells: column 7 of those rows
    !byte <(SCREEN+10*40+7), <(SCREEN+13*40+7)
    !byte <(SCREEN+16*40+7), <(SCREEN+19*40+7)
ocur_hi:
    !byte >(SCREEN+10*40+7), >(SCREEN+13*40+7)
    !byte >(SCREEN+16*40+7), >(SCREEN+19*40+7)
ovtx_lo:   !byte <txt_off, <txt_on
ovtx_hi:   !byte >txt_off, >txt_on
ovcol:     !byte LGREY, LGREEN

; ---- option texts ----
txt_ogun:  !scr "worker gun"
txt_ocool: !scr "spin cooldown"
txt_olev:  !scr "start level"
txt_oback: !scr "back"
txt_on:    !scr "on "
txt_off:   !scr "off"
txt_oh1:   !scr "gun: p1 fire shoots a bullet"
txt_oh1e:
txt_oh2:   !scr "cooldown: spins need a recharge"
txt_oh2e:
txt_oh3:   !scr "start: a fresh run's first level"
txt_oh3e:

; ---- the settings themselves (session-wide) ----
!ifdef FORCEOPTS {       ; test builds start with both turned on
opt_shoot: !byte 1
opt_cool:  !byte 1
} else {
opt_shoot: !byte 0       ; 0 = classic game, 1 = the worker shoots
opt_cool:  !byte 0       ; 1 = spins need a recharge
}
opt_level: !byte 1       ; a fresh run's first level: 1-8
optsel:    !byte 0       ; picked line: 0-3

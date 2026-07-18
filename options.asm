; -----------------------------------------------------------
; options.asm - optional extras, toggled with fire:
;   runner gun    - player 1 shoots with fire; a hit enemy
;                   respawns elsewhere after a pause
;   spin cooldown - the wall spinner needs a recharge between
;                   two spins, shown on the status row
; the settings live here and survive between rounds
; -----------------------------------------------------------

OPT_ITEMS = 3

options_init:
    jsr clear_screen

    +prbig 1, 6, WHITE, txt_options, 7

    +prtext 19, 6, LGREY, txt_oh1, txt_oh1e-txt_oh1
    +prtext 20, 4, LGREY, txt_oh2, txt_oh2e-txt_oh2

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

    ; the current values next to the two settings
    ldx opt_shoot
    lda #10
    jsr put_oval
    ldx opt_cool
    lda #13
    jsr put_oval

    ; blinking '>' cursor in front of the picked line
    lda #$20
    sta SCREEN+10*40+7
    sta SCREEN+13*40+7
    sta SCREEN+16*40+7
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
    cmp #2
    beq ou_back
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
ou_tsfx:
    lda #SFX_SELECT
    jsr sfx_play
ou_done:
    rts
ou_back:
    lda #SFX_SELECT
    jsr sfx_play
    jmp menu_init

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
oitem_lo:  !byte <txt_ogun, <txt_ocool, <txt_oback
oitem_hi:  !byte >txt_ogun, >txt_ocool, >txt_oback
oitem_len: !byte 10, 13, 4
oitem_row: !byte 10, 13, 16
ocur_lo:                 ; cursor cells: column 7 of those rows
    !byte <(SCREEN+10*40+7), <(SCREEN+13*40+7), <(SCREEN+16*40+7)
ocur_hi:
    !byte >(SCREEN+10*40+7), >(SCREEN+13*40+7), >(SCREEN+16*40+7)
ovtx_lo:   !byte <txt_off, <txt_on
ovtx_hi:   !byte >txt_off, >txt_on
ovcol:     !byte LGREY, LGREEN

; ---- option texts ----
txt_ogun:  !scr "runner gun"
txt_ocool: !scr "spin cooldown"
txt_oback: !scr "back"
txt_on:    !scr "on "
txt_off:   !scr "off"
txt_oh1:   !scr "gun: p1 fire shoots a bullet"
txt_oh1e:
txt_oh2:   !scr "cooldown: spins need a recharge"
txt_oh2e:

; ---- the settings themselves (session-wide) ----
!ifdef FORCEOPTS {       ; test builds start with both turned on
opt_shoot: !byte 1
opt_cool:  !byte 1
} else {
opt_shoot: !byte 0       ; 0 = classic game, 1 = the runner shoots
opt_cool:  !byte 0       ; 1 = spins need a recharge
}
optsel:    !byte 0       ; picked line: 0-2

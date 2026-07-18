; -----------------------------------------------------------
; menu.asm - full-screen menu card: big LABYRINTH title with
; the gold wash, and a four-item menu: play / rules /
; controls / credits (joystick or w/s up/down + fire, space
; or return)
; -----------------------------------------------------------

MENU_ITEMS = 4

menu_init:
    jsr clear_screen

    +prbig 2, 2, YELLOW, txt_title, 9
    +prtext 9, 13, LGREY, txt_ttgname, 14

    lda #0
    sta menusel
    sta washphase

    +setupd menu_update
    rts

menu_update:
    ; gold wash rolling down the big title (rows 2-6)
    inc washphase
    lda #0
    sta g8row
mw_row:
    lda #2
    clc
    adc g8row
    tax
    jsr row_ptr
    lda washphase
    lsr
    clc
    adc g8row
    and #15
    tax
    lda washtbl,x
    sta rtmp
    ldy #37              ; the title spans columns 2-36
mw_col:
    lda (scrlo),y
    cmp #$a0             ; only touch the letter blocks
    bne mw_skip
    lda rtmp
    sta (collo),y
mw_skip:
    dey
    cpy #1
    bne mw_col
    inc g8row
    lda g8row
    cmp #5
    bne mw_row

    ; joystick up/down steps the cursor (edge detected)
    jsr read_joy
    lda joyb
    and #3
    beq mu_udrel
    lda udheld
    bne mu_udend
    lda #1
    sta udheld
    lda joyb
    and #1               ; up
    beq mu_down
    lda menusel
    beq mu_udend
    dec menusel
    lda #SFX_CURSOR
    jsr sfx_play
    jmp mu_udend
mu_down:
    lda menusel
    cmp #MENU_ITEMS-1
    beq mu_udend
    inc menusel
    lda #SFX_CURSOR
    jsr sfx_play
    jmp mu_udend
mu_udrel:
    lda #0
    sta udheld
mu_udend:

    ; footer: both control lines always visible
    +prtext 21, 8, LGREY, txt_info, txt_infoe-txt_info
    +prtext 22, 5, LGREY, txt_info2, txt_info2e-txt_info2

    ; the menu items: the picked line is yellow
    ldx #0
mm_items:
    txa
    pha
    jsr draw_mitem
    pla
    tax
    inx
    cpx #MENU_ITEMS
    bne mm_items

    ; blinking '>' cursor in front of the picked line
    lda #$20
    sta SCREEN+12*40+15
    sta SCREEN+14*40+15
    sta SCREEN+16*40+15
    sta SCREEN+18*40+15
    lda framectr
    and #16
    bne mu_start
    ldx menusel
    lda mcur_lo,x
    sta scrlo
    lda mcur_hi,x
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

mu_start:
    ; fire or space opens the picked line
    jsr start_edge
    beq mu_done
    lda #SFX_SELECT
    jsr sfx_play
    lda menusel
    beq mg_play
    cmp #1
    beq mg_rules
    cmp #2
    beq mg_controls
    jmp credits_init     ; each init's rts returns to the main loop
mg_play:
    jmp play_init
mg_rules:
    jmp rules_init
mg_controls:
    jmp controls_init
mu_done:
    rts

; ---- draw menu item X, yellow when it is the picked one ----
draw_mitem:
    lda mitem_lo,x
    sta txtlo
    lda mitem_hi,x
    sta txthi
    lda mitem_row,x
    sta prow
    lda #17
    sta pcol
    lda mitem_len,x
    sta plen
    lda #WHITE
    cpx menusel
    bne dm_store
    lda #YELLOW
dm_store:
    sta pcolor
    jmp print_text

; ---- menu tables ----
mitem_lo:  !byte <txt_play, <txt_rules, <txt_controls, <txt_credits
mitem_hi:  !byte >txt_play, >txt_rules, >txt_controls, >txt_credits
mitem_len: !byte 4, 5, 8, 7
mitem_row: !byte 12, 14, 16, 18
mcur_lo:                 ; cursor cells: column 15 of those rows
    !byte <(SCREEN+12*40+15), <(SCREEN+14*40+15)
    !byte <(SCREEN+16*40+15), <(SCREEN+18*40+15)
mcur_hi:
    !byte >(SCREEN+12*40+15), >(SCREEN+14*40+15)
    !byte >(SCREEN+16*40+15), >(SCREEN+18*40+15)

; ---- menu texts ----
txt_play:    !scr "play"
txt_rules:   !scr "rules"
txt_credits: !scr "credits"
txt_info:    !scr "p1: joy2 / wasd - runner"
txt_infoe:
txt_info2:   !scr "p2: joy1 / ijkl - wall spinner"
txt_info2e:

; ---- menu variables ----
menusel:   !byte 0       ; picked line: 0-2
udheld:    !byte 0       ; joystick up/down edge detection state

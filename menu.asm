; -----------------------------------------------------------
; menu.asm - full-screen menu card: big LABYRINTWO title in
; two colors (gold wash on LABYRIN, cool blue shimmer on
; TWO), and a five-item menu: play / options / rules /
; controls / credits (joystick or w/s up/down + fire, space
; or return)
; -----------------------------------------------------------

MENU_ITEMS = 5

menu_init:
    jsr clear_screen

    ; a dark maze weaves behind the whole card
    lda #DGREY
    sta latwcol
    sta latpcol
    jsr draw_lattice
    jsr gen_init
    jsr gen_maze_full

    ; a clean panel for the menu itself (rows 9-22, cols 4-35)
    ldx #9
mi_panel:
    stx ptmp
    jsr row_ptr
    ldy #35
mi_pcol:
    lda #$20
    sta (scrlo),y
    lda #BLACK
    sta (collo),y
    dey
    cpy #3
    bne mi_pcol
    ldx ptmp
    inx
    cpx #23
    bne mi_panel

    +prbig 2, 0, YELLOW, txt_t1, 7
    +prbig 2, 28, CYAN, txt_t2, 3
    +prtext 9, 13, LGREY, txt_ttgname, 14

    lda #0
    sta menusel
    sta washphase

    +setupd menu_update
    rts

menu_update:
    ; the title rows 2-6: gold wash on LABYRIN (columns 0-26),
    ; cool blue shimmer on TWO (columns 27-38)
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
    ldy #26
mw_col:
    lda (scrlo),y
    cmp #$a0             ; only touch the letter blocks
    bne mw_skip
    lda rtmp
    sta (collo),y
mw_skip:
    dey
    bpl mw_col
    lda washphase
    lsr
    clc
    adc g8row
    and #7
    tax
    lda cooltbl,x
    sta rtmp
    ldy #38
mw_col2:
    lda (scrlo),y
    cmp #$a0
    bne mw_skip2
    lda rtmp
    sta (collo),y
mw_skip2:
    dey
    cpy #26
    bne mw_col2
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
    sta SCREEN+11*40+15
    sta SCREEN+13*40+15
    sta SCREEN+15*40+15
    sta SCREEN+17*40+15
    sta SCREEN+19*40+15
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
    beq mg_options
    cmp #2
    beq mg_rules
    cmp #3
    beq mg_controls
    +fadeto credits_init ; every screen change fades to black
mg_play:
    +fadeto play_init
mg_options:
    +fadeto options_init
mg_rules:
    +fadeto rules_init
mg_controls:
    +fadeto controls_init
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
mitem_lo:
    !byte <txt_play, <txt_options, <txt_rules
    !byte <txt_controls, <txt_credits
mitem_hi:
    !byte >txt_play, >txt_options, >txt_rules
    !byte >txt_controls, >txt_credits
mitem_len: !byte 4, 7, 5, 8, 7
mitem_row: !byte 11, 13, 15, 17, 19
mcur_lo:                 ; cursor cells: column 15 of those rows
    !byte <(SCREEN+11*40+15), <(SCREEN+13*40+15)
    !byte <(SCREEN+15*40+15), <(SCREEN+17*40+15)
    !byte <(SCREEN+19*40+15)
mcur_hi:
    !byte >(SCREEN+11*40+15), >(SCREEN+13*40+15)
    !byte >(SCREEN+15*40+15), >(SCREEN+17*40+15)
    !byte >(SCREEN+19*40+15)

cooltbl:                 ; blue-cyan-white shimmer for the TWO
    !byte $06, $0e, $03, $01, $01, $03, $0e, $06

; ---- menu texts ----
txt_play:    !scr "play"
txt_options: !scr "options"
txt_rules:   !scr "rules"
txt_credits: !scr "credits"
txt_info:    !scr "p1: joy2 / wasd - runner"
txt_infoe:
txt_info2:   !scr "p2: joy1 / ijkl - wall spinner"
txt_info2e:

; ---- menu variables ----
menusel:   !byte 0       ; picked line: 0-2
udheld:    !byte 0       ; joystick up/down edge detection state

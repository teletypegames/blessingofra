; -----------------------------------------------------------
; controls.asm - who steers what: joystick and keyboard
; mappings for both players, one static card; fire returns
; -----------------------------------------------------------

controls_init:
    jsr clear_screen

    +prbig 1, 4, WHITE, txt_controls, 8

    +prtext  8,  9, LGREEN, txt_c1, txt_c1e-txt_c1
    +prtext 10,  6, WHITE,  txt_c2, txt_c2e-txt_c2
    +prtext 11,  6, LGREY,  txt_c2b, txt_c2be-txt_c2b

    +prtext 13,  6, LBLUE,  txt_c3, txt_c3e-txt_c3
    +prtext 15,  6, WHITE,  txt_c4, txt_c4e-txt_c4
    +prtext 17, 10, WHITE,  txt_c5, txt_c5e-txt_c5

    +prtext 20,  5, LGREY,  txt_c6, txt_c6e-txt_c6

    +setupd controls_update
    rts

controls_update:
    ; blink the return prompt
    lda framectr
    and #32
    bne co_hide
    +prtext 22, 13, YELLOW, txt_return, 13
    jmp co_input
co_hide:
    +prtext 22, 13, YELLOW, txt_blank, 13
co_input:
    jsr start_edge
    beq co_stay
    +fadeto menu_init
co_stay:
    rts

; ---- controls texts ----
txt_controls: !scr "controls"
txt_c1: !scr "player 1 - the runner"
txt_c1e:
txt_c2: !scr "move: joystick 2 or w a s d"
txt_c2e:
txt_c2b: !scr "gun: fire or space, if enabled"
txt_c2be:
txt_c3: !scr "player 2 - the wall spinner"
txt_c3e:
txt_c4: !scr "move: joystick 1 or i j k l"
txt_c4e:
txt_c5: !scr "spin: fire or return"
txt_c5e:
txt_c6: !scr "menus: fire, space or return"
txt_c6e:

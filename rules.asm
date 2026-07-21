; -----------------------------------------------------------
; rules.asm - how to play, one static card; fire returns
; -----------------------------------------------------------

rules_init:
    jsr clear_screen

    +prbig 1, 10, WHITE, txt_rules, 5

    +prtext  8,  9, LGREEN, txt_r1, txt_r1e-txt_r1
    +prtext  9,  8, WHITE,  txt_r2, txt_r2e-txt_r2
    +prtext 10,  7, WHITE,  txt_r3, txt_r3e-txt_r3

    +prtext 12,  9, LBLUE,  txt_r4, txt_r4e-txt_r4
    +prtext 13,  6, WHITE,  txt_r5, txt_r5e-txt_r5
    +prtext 14,  6, WHITE,  txt_r6, txt_r6e-txt_r6
    +prtext 15,  7, WHITE,  txt_r7, txt_r7e-txt_r7

    +prtext 17,  7, LRED,   txt_r8, txt_r8e-txt_r8

    +setupd rules_update
    rts

rules_update:
    ; blink the return prompt
    lda framectr
    and #32
    bne ru_hide
    +prtext 21, 13, YELLOW, txt_return, 13
    jmp ru_input
ru_hide:
    +prtext 21, 13, YELLOW, txt_blank, 13
ru_input:
    jsr start_edge
    beq ru_stay
    +fadeto menu_init
ru_stay:
    rts

; ---- rules texts ----
txt_r1: !scr "player 1 - joystick 2"
txt_r1e:
txt_r2: !scr "run the maze and escape"
txt_r2e:
txt_r3: !scr "through the green diamond."
txt_r3e:
txt_r4: !scr "player 2 - joystick 1"
txt_r4e:
txt_r5: !scr "ride the corners of the walls;"
txt_r5e:
txt_r6: !scr "fire spins the four wall pieces"
txt_r6e:
txt_r7: !scr "around the cursor by 90 degrees."
txt_r7e:
txt_r8: !scr "avoid the colored enemies!"
txt_r8e:

; -----------------------------------------------------------
; main.asm - LABYRINTWO for the C64
;   two-player maze duel: player 1 runs the corridors toward
;   the green exit portal while dodging the roaming colored
;   enemies; player 2 rides the wall corners with a cursor
;   and fire spins the four wall pieces around it by 90
;   degrees, reshaping the maze under the runner's feet
;
; Files:
;   defs.asm    - constants, zero page, macros
;   intro.asm   - TTG boot logo (ported from rabbitc64)
;   menu.asm    - main menu over a dark maze backdrop
;   options.asm - optional extras: runner gun, spin cooldown
;   rules.asm   - how to play
;   controls.asm- joystick + keyboard mappings
;   credits.asm - the crew (content from rabbitc64, new look)
;   play.asm    - maze generation + the game itself
;   win.asm     - escape screen, returns to the menu
;   over.asm    - game over screen with retry
;   common.asm  - shared routines, input, RNG, texts
;   sound.asm   - single-voice SFX driver
;   gfx.asm     - RAM charset, sprite engine, fades
;
; Build: acme -f cbm -o labyrintwo.prg main.asm
; -----------------------------------------------------------

* = $0801

; ---- BASIC stub: 10 SYS 2064 ----
; so after LOAD"*",8,1 it's enough to type RUN
!byte $0c, $08          ; address of next line
!byte $0a, $00          ; line number: 10
!byte $9e               ; SYS token
!byte $20, $32, $30, $36, $34   ; " 2064"
!byte $00               ; end of line
!byte $00, $00          ; end of program

* = $0810                ; = 2064 in decimal

!src "defs.asm"

start:
    sei                  ; no KERNAL IRQ - raster polling must not jitter
    lda #BLACK
    sta BORDER
    sta BG
    lda #0
    sta SPR_EN           ; the actors arrive with the game screen
    sta framectr
    sta fheld
    jsr gfx_init         ; RAM charset + VIC + sprite registers
    jsr sfx_init

!ifdef AUTOPLAY {        ; test builds boot straight into one state
    jsr play_init
} else {
!ifdef AUTORULES {
    jsr rules_init
} else {
!ifdef AUTOCONTROLS {
    jsr controls_init
} else {
!ifdef AUTOOPTIONS {
    jsr options_init
} else {
!ifdef AUTOCREDITS {
    jsr credits_init
} else {
!ifdef AUTOWIN {
    jsr win_init
} else {
!ifdef AUTOLOSE {
    jsr lose_init
} else {
    jsr intro_init       ; TTG logo, then the menu
}
}
}
}
}
}
}

; ============================================================
; main loop - one state update per PAL frame, synced to the
; raster beam in the lower border; the loop also paints the
; border (event flashes decay back to the screen's base
; color) and, when a screen asks for one, lays a background
; band behind the status row with two more raster waits
; ============================================================
main:
    jsr wait_frame       ; raster line RAS_SYNC, once a frame
    lda bflash           ; border: flash, else the base color
    beq mb_base
    dec bflash
    lda bcolor
    jmp mb_border
mb_base:
    lda borbase
mb_border:
    sta BORDER
    inc framectr
    jsr rand8            ; stir the RNG once per frame
    jsr sfx_update       ; advance the sound effect
    lda statbg           ; $ff = no band: update right away
    bmi mb_update
mb_w1:
    bit SCRCTL           ; the beam reaches line 256...
    bpl mb_w1
mb_w2:
    bit SCRCTL           ; ...and wraps to line 0
    bmi mb_w2
mb_w3:
    lda RASTER
    cmp #49              ; still in the border above the window
    bcc mb_w3
    lda statbg
    sta BG
mb_w4:
    lda RASTER
    cmp #59              ; the switch back hides behind row 1's
    bcc mb_w4            ; wall tops (their top line is solid)
    lda #BLACK
    sta BG
mb_update:
    jsr call_update
    jmp main

call_update:
    jmp (updvec)         ; each update runs exactly one frame, ends with rts

; ---- wait for raster line RAS_SYNC (leave it first, so a
; fast update cannot run twice in the same frame) ----
wait_frame:
    lda RASTER
    cmp #RAS_SYNC
    beq wait_frame
wf_hit:
    lda RASTER
    cmp #RAS_SYNC
    bne wf_hit
    rts

; ============================================================
; the states and everything they share
; ============================================================
!src "intro.asm"
!src "menu.asm"
!src "options.asm"
!src "rules.asm"
!src "controls.asm"
!src "credits.asm"
!src "play.asm"
!src "win.asm"
!src "over.asm"
!src "common.asm"
!src "sound.asm"
!src "gfx.asm"

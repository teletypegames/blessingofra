; -----------------------------------------------------------
; play.asm - the game: a fresh maze carves itself on screen
; every round (recursive backtracker, a few steps a frame),
; player 1 (joystick 2) runs the corridors toward the exit
; portal, player 2 (joystick 1) rides the wall corners and
; fire spins the four wall pieces around the cursor by 90
; degrees; the roaming enemies end the round on touch
;
; the walls, posts and the portal are chars (the screen stays
; the wall data structure), but every actor - runner, cursor,
; bullet, enemies - is a hardware sprite gliding between the
; cells; actor collisions are grid coordinate checks
;
; optional extras (see options.asm):
;   opt_shoot - player 1's fire shoots a bullet in the last
;               direction faced; a hit enemy respawns on a
;               random cell after RESPAWN_TIME frames
;   opt_cool  - a spin starts a COOL_TIME recharge, shown as
;               a draining 1/8-step bar on the status row
;
; screen layout: status on row 0 (over the colored raster
; band), the 39x23 maze lattice on rows 1-23, hints on row 24
; -----------------------------------------------------------

play_init:
    jsr clear_screen
    +prtext 0, 0, WHITE, txt_t1, 7
    +prtext 0, 7, CYAN, txt_t2, 3
    +prtext 0, 34, LGREY, txt_goal, txt_goale-txt_goal
    +prtext 24, 6, DGREY, txt_hint, txt_hinte-txt_hint

    lda #COL_WALL
    sta latwcol
    lda #COL_POST
    sta latpcol
    jsr draw_lattice
    jsr gen_init

    lda #0               ; the actors arrive when the maze is done
    sta SPR_EN
    lda #STATCOL         ; the status row gets its color band
    sta statbg
    +setupd play_build
    rts

; ---- the maze carves itself, BUILD_STEPS steps a frame ----
play_build:
    lda #BUILD_STEPS
    sta ptmp
pb_loop:
    jsr gm_step
    bcs play_start
    dec ptmp
    bne pb_loop
    rts

; ---- the maze is done: exit, actors, sprites, input ----
play_start:
    ; the exit: a portal in the right border wall
ps_exit:
    jsr rand8
    and #$0f
    cmp #MAZE_CH
    bcs ps_exit
    asl                  ; cell row -> screen row
    clc
    adc #2
    sta exrow
    tax
    jsr row_ptr
    ldy #38
    lda #CH_EXIT
    sta (scrlo),y
    lda #COL_EXIT
    sta (collo),y

    ; the runner starts in the top-left cell, facing right
    lda #1
    sta px
    sta fdx
    lda #2
    sta py
    lda #0
    sta fdy
    lda px
    sta tgc
    lda py
    sta tgr
    jsr set_target
    ldx #SP_RUN
    jsr spr_jump

    ; the corner cursor starts on the center post
    lda #18
    sta kx
    lda #11
    sta ky
    lda #COL_HILITE
    jsr mark_slots
    lda kx
    sta tgc
    lda ky
    sta tgr
    jsr set_target
    ldx #SP_CUR
    jsr spr_jump

    lda #WHITE
    sta SPRCOL+SP_RUN
    sta SPRCOL+SP_CUR
    lda #YELLOW
    sta SPRCOL+SP_SHOT

    jsr spawn_enemies

    ; input state: fire still held from the previous screen
    ; must be released before it can spin or shoot
    lda #0
    sta rheld
    sta cheld
    sta endflag
    sta s_on
    sta sx
    sta sy
    sta cool
    sta rotflash
    sta tframe           ; the clock starts when the maze is done
    sta tsec
    sta tmin
    lda #1
    sta cfheld
    sta rfheld
    +setupd play_update
    jmp upd_sprites      ; positions, shapes and enables now

; ============================================================
; maze generation - recursive backtracker over the 19x11
; cells; the screen itself is the wall data structure
; ============================================================

; fill rows 1-23 of the lattice: brick walls in latwcol, the
; pivot posts (even col, odd row) in latpcol
draw_lattice:
    ldx #1
dl_fill:
    stx ptmp
    jsr row_ptr
    ldy #38
dl_col:
    lda #CH_WALL
    sta (scrlo),y
    lda latwcol
    sta (collo),y
    dey
    bpl dl_col
    ldx ptmp
    inx
    cpx #24
    bne dl_fill
    ldx #1               ; post rows 1, 3, ... 23
dl_prow:
    stx ptmp
    jsr row_ptr
    ldy #38              ; post columns 38, 36, ... 0
dl_pcol:
    lda #CH_POST
    sta (scrlo),y
    lda latpcol
    sta (collo),y
    dey
    dey
    bpl dl_pcol
    ldx ptmp
    inx
    inx
    cpx #25
    bcc dl_prow
    rts

; reset the generator: nothing visited, start on cell (0,0)
gen_init:
    ldx #0
    lda #0
gi_clr:
    sta visited,x
    inx
    cpx #NCELLS
    bne gi_clr
    lda #0
    sta gcx
    sta gcy
    sta gsp
    jsr gv_mark
    jmp carve_cell

; one generator step: carve toward a random unvisited
; neighbor, or back up one; C set when the maze is finished
gm_step:
    ; collect the unvisited neighbor directions
    lda #0
    sta gn
    ldx #0
gm_scan:
    stx gtd
    lda gcx
    clc
    adc dxtab,x
    sta gnx
    cmp #MAZE_CW         ; unsigned: -1 wraps to $ff and fails too
    bcs gm_next
    ldx gtd
    lda gcy
    clc
    adc dytab,x
    sta gny
    cmp #MAZE_CH
    bcs gm_next
    ldx gny
    lda mul19,x
    clc
    adc gnx
    tax
    lda visited,x
    bne gm_next
    ldx gn
    lda gtd
    sta gdlist,x
    inc gn
gm_next:
    ldx gtd
    inx
    cpx #4
    bne gm_scan
    lda gn
    beq gm_pop
    ; pick a random one of them
gm_pick:
    jsr rand8
    and #3
    cmp gn
    bcs gm_pick
    tax
    lda gdlist,x
    sta gtd
    ; push the current cell, open the wall, step through it
    ldx gsp
    lda gcx
    sta stackx,x
    lda gcy
    sta stacky,x
    inc gsp
    jsr carve_wall
    ldx gtd
    lda gcx
    clc
    adc dxtab,x
    sta gcx
    ldx gtd
    lda gcy
    clc
    adc dytab,x
    sta gcy
    jsr gv_mark
    jsr carve_cell
    clc
    rts
gm_pop:
    ; dead end: back up; empty stack = the maze is done
    lda gsp
    beq gm_done
    dec gsp
    ldx gsp
    lda stackx,x
    sta gcx
    lda stacky,x
    sta gcy
    clc
    rts
gm_done:
    sec
    rts

gen_maze_full:           ; the menu backdrop wants it all at once
    jsr gm_step
    bcc gen_maze_full
    rts

gv_mark:                 ; visited[gcy * 19 + gcx] = 1
    ldx gcy
    lda mul19,x
    clc
    adc gcx
    tax
    lda #1
    sta visited,x
    rts

carve_cell:              ; open the cell (2*gcx+1, 2*gcy+2)
    lda gcy
    asl
    clc
    adc #2
    tax
    jsr row_ptr
    lda gcx
    asl
    clc
    adc #1
    tay
    lda #CH_FLOOR
    sta (scrlo),y
    lda #BLACK
    sta (collo),y
    rts

carve_wall:              ; open the wall slot toward direction gtd
    ldx gtd
    lda gcy
    asl
    clc
    adc #2
    clc
    adc dytab,x
    tax
    jsr row_ptr
    ldx gtd
    lda gcx
    asl
    clc
    adc #1
    clc
    adc dxtab,x
    tay
    lda #CH_FLOOR
    sta (scrlo),y
    lda #BLACK
    sta (collo),y
    rts

dxtab: !byte 0, 0, $ff, 1        ; up, down, left, right
dytab: !byte $ff, 1, 0, 0
mul19: !byte 0, 19, 38, 57, 76, 95, 114, 133, 152, 171, 190

; ---- enemies: random colors, random right-half cells ----
spawn_enemies:
    lda #0
    sta ei
sn_all:
    jsr spawn_one
    inc ei
    lda ei
    cmp #NENEMIES
    bne sn_all
    rts

spawn_one:               ; place enemy ei on a random free cell
sn_rx:
    jsr rand8
    and #$0f
    cmp #MAZE_CH
    bcs sn_rx
    clc
    adc #MAZE_CW-MAZE_CH ; cell column 8-18: away from the start
    asl
    clc
    adc #1
    sta ttx              ; candidate screen column
sn_ry:
    jsr rand8
    and #$0f
    cmp #MAZE_CH
    bcs sn_ry
    asl
    clc
    adc #2
    sta tty              ; candidate screen row
    ldx tty
    jsr row_ptr
    ldy ttx
    lda (scrlo),y
    cmp #CH_FLOOR        ; only a carved cell will do...
    bne sn_rx
    lda ttx              ; ...without the runner on it...
    cmp px
    bne sn_free
    lda tty
    cmp py
    beq sn_rx
sn_free:
    jsr enemy_at         ; ...or another live enemy
    bcs sn_rx
    ldx ei
    lda ttx
    sta ex,x
    lda tty
    sta ey,x
    jsr rand8
    and #7
    tay
    lda ecoltab,y
    sta ecol,x
    sta SPRCOL+SP_EN,x
    jsr rand8
    and #3
    sta edir,x
    lda #0
    sta edead,x
    lda ttx              ; the sprite pops in on the cell
    sta tgc
    lda tty
    sta tgr
    jsr set_target
    lda ei
    clc
    adc #SP_EN
    tax
    jmp spr_jump

ecoltab:                 ; anything but the white runner / grey walls
    !byte RED, CYAN, PURPLE, YELLOW, ORANGE, LRED, LBLUE, BLUE

; ============================================================
; one frame of play
; ============================================================
play_update:
    inc tframe           ; the round clock: 50 frames = one second
    lda tframe
    cmp #50
    bne pu_clock
    lda #0
    sta tframe
    inc tsec
    lda tsec
    cmp #60
    bne pu_clock
    lda #0
    sta tsec
    inc tmin
    lda tmin
    cmp #100             ; the clock pegs at 99:59
    bne pu_clock
    lda #99
    sta tmin
pu_clock:
    lda cool             ; the spin recharge ticks down
    beq pu_nocool
    dec cool
pu_nocool:
    jsr upd_runner
    lda endflag
    bne pu_end
    jsr upd_shot
    jsr upd_enemies
    lda endflag
    bne pu_end
    jsr upd_cursor
    jsr upd_flash
    jsr upd_status
    jsr upd_clock
    jmp upd_sprites
pu_end:
    cmp #1
    beq pu_win
    lda #SFX_LOSE
    jsr sfx_play
    +fadeto lose_init
pu_win:
    lda #SFX_WIN
    jsr sfx_play
    +fadeto win_init

; ---- player 1: walk the corridors, one cell per step ----
upd_runner:
    jsr read_joy
    and #$0f
    sta rdir
    bne ur_held
    lda #0
    sta rheld
    rts
ur_held:
    lda rheld
    beq ur_first
    dec rtimer
    beq ur_rep
    rts
ur_rep:
    lda #REP_PERIOD
    sta rtimer
    jmp ur_move
ur_first:
    lda #1
    sta rheld
    lda #REP_HOLD
    sta rtimer
ur_move:
    ; decode the direction; it also becomes the gun's facing
    ldx px
    ldy py
    lda rdir
    lsr
    bcs ur_up
    lsr
    bcs ur_down
    lsr
    bcs ur_left
    inx                  ; right
    lda #1
    sta fdx
    lda #0
    sta fdy
    jmp ur_try
ur_up:
    dey
    lda #0
    sta fdx
    lda #$ff
    sta fdy
    jmp ur_try
ur_down:
    iny
    lda #0
    sta fdx
    lda #1
    sta fdy
    jmp ur_try
ur_left:
    dex
    lda #$ff
    sta fdx
    lda #0
    sta fdy
ur_try:
    stx ttx
    sty tty
    ldx tty
    jsr row_ptr
    ldy ttx
    lda (scrlo),y
    cmp #CH_EXIT
    beq ur_win
    cmp #CH_FLOOR
    bne ur_stop          ; a wall or a post: blocked
    jsr enemy_at         ; walking into an enemy still hurts
    bcs ur_dead
    lda ttx
    sta px
    lda tty
    sta py
ur_stop:
    rts
ur_win:
    lda #1
    sta endflag
    rts
ur_dead:
    lda #2
    sta endflag
    rts

; ---- the optional gun: one straight-flying bullet sprite ----
upd_shot:
    lda s_on
    beq sh_spawn
    lda sx               ; one step along its heading
    clc
    adc sdx
    sta ttx
    lda sy
    clc
    adc sdy
    sta tty
    ldx tty
    jsr row_ptr
    ldy ttx
    lda (scrlo),y
    cmp #CH_FLOOR
    beq sh_open
    lda #0               ; a wall (or the portal) stops it
    sta s_on
    jmp sh_spawn
sh_open:
    jsr enemy_at
    bcc sh_fly
    jsr kill_idx         ; X = the victim
    lda #0
    sta s_on
    jmp sh_spawn
sh_fly:
    lda ttx
    sta sx
    lda tty
    sta sy
sh_spawn:
    lda opt_shoot        ; fire spawns a bullet (edge detected)
    beq sh_done
    lda joyb             ; read_joy ran in upd_runner this frame
    and #JOY_FIRE
    beq sh_frel
    lda rfheld
    bne sh_done
    lda #1
    sta rfheld
    lda s_on
    bne sh_done          ; one bullet at a time
    lda px
    sta sx
    lda py
    sta sy
    lda fdx
    sta sdx
    lda fdy
    sta sdy
    lda #1
    sta s_on
    lda #SFX_SHOT
    jmp sfx_play
sh_frel:
    lda #0
    sta rfheld
sh_done:
    rts

; ---- enemy X was hit: it starts its respawn timer ----
kill_idx:
    lda #RESPAWN_TIME
    sta edead,x
    lda #4               ; white border blip
    sta bflash
    lda #WHITE
    sta bcolor
    lda #SFX_HIT
    jmp sfx_play

; ---- is a live enemy standing on (ttx, tty)?
; returns C set + its index in X when one is ----
enemy_at:
    ldx #0
ea_loop:
    lda edead,x
    bne ea_next
    lda ex,x
    cmp ttx
    bne ea_next
    lda ey,x
    cmp tty
    bne ea_next
    sec
    rts
ea_next:
    inx
    cpx #NENEMIES
    bne ea_loop
    clc
    rts

; ---- player 2: the corner cursor + the wall spin ----
upd_cursor:
    jsr read_joy2
    sta j2bits
    and #$0f
    sta cdir
    bne uc_held
    lda #0
    sta cheld
    jmp uc_fire
uc_held:
    lda cheld
    beq uc_first
    dec ctimer
    beq uc_rep
    jmp uc_fire
uc_rep:
    lda #CREP_PERIOD
    sta ctimer
    jmp uc_move
uc_first:
    lda #1
    sta cheld
    lda #CREP_HOLD
    sta ctimer
uc_move:
    ldx kx
    ldy ky
    lda cdir
    lsr
    bcs uc_up
    lsr
    bcs uc_down
    lsr
    bcs uc_left
    cpx #36              ; right: interior posts end at column 36
    bcs uc_fire
    inx
    inx
    jmp uc_go
uc_up:
    cpy #4               ; top interior post row is 3
    bcc uc_fire
    dey
    dey
    jmp uc_go
uc_down:
    cpy #21              ; bottom interior post row is 21
    bcs uc_fire
    iny
    iny
    jmp uc_go
uc_left:
    cpx #3               ; left interior post column is 2
    bcc uc_fire
    dex
    dex
uc_go:
    stx ttx
    sty tty
    lda #COL_WALL        ; the old corner's walls lose the highlight
    jsr mark_slots
    lda #0               ; a spin flash does not follow the cursor
    sta rotflash
    lda ttx
    sta kx
    lda tty
    sta ky
    lda #COL_HILITE      ; show the walls a spin here would move
    jsr mark_slots
    lda #SFX_CURSOR
    jsr sfx_play
uc_fire:
    lda j2bits
    and #JOY_FIRE
    beq uc_frel
    lda cfheld
    bne uc_done
    lda #1
    sta cfheld
    jmp do_rotate        ; its rts returns to play_update's caller
uc_frel:
    lda #0
    sta cfheld
uc_done:
    rts

; ---- spin the four wall slots around post (kx, ky) by 90
; degrees clockwise; denied while anyone stands in them or
; while the optional cooldown is still recharging ----
do_rotate:
    lda opt_cool
    beq dr_ready
    lda cool
    beq dr_ready
dr_deny:
    jmp rot_deny         ; still recharging / a slot is taken
dr_ready:
    lda kx               ; nobody may stand in the four slots
    sta ttx
    ldx ky
    dex
    stx tty
    jsr slot_occ
    bcs dr_deny
    ldx ky
    inx
    stx tty
    jsr slot_occ
    bcs dr_deny
    lda ky
    sta tty
    ldx kx
    dex
    stx ttx
    jsr slot_occ
    bcs dr_deny
    ldx kx
    inx
    stx ttx
    jsr slot_occ
    bcs dr_deny
    ldx ky               ; gather the four slot chars
    dex
    jsr row_ptr
    ldy kx
    lda (scrlo),y
    sta nch
    ldx ky
    inx
    jsr row_ptr
    ldy kx
    lda (scrlo),y
    sta sch
    ldx ky
    jsr row_ptr
    ldy kx
    dey
    lda (scrlo),y
    sta wch
    iny
    iny
    lda (scrlo),y
    sta ech
    ; clockwise: north<-west, east<-north, south<-east, west<-south
    ldx ky
    dex
    jsr row_ptr
    ldy kx
    lda wch
    jsr put_slot
    ldx ky
    inx
    jsr row_ptr
    ldy kx
    lda ech
    jsr put_slot
    ldx ky
    jsr row_ptr
    ldy kx
    dey
    lda sch
    jsr put_slot
    iny
    iny
    lda nch
    jsr put_slot
    lda #10              ; the moved pieces flash white
    sta rotflash
    lda opt_cool         ; the spin starts the recharge
    beq dr_nocool
    lda #COOL_TIME
    sta cool
dr_nocool:
    lda #SFX_ROTATE
    jmp sfx_play
rot_deny:
    lda #6               ; red border blip on a denied spin
    sta bflash
    lda #RED
    sta bcolor
    lda #SFX_DENY
    jmp sfx_play

slot_occ:                ; C set when someone stands on (ttx, tty)
    lda px
    cmp ttx
    bne so_norun
    lda py
    cmp tty
    beq so_yes
so_norun:
    jsr enemy_at
    bcs so_yes
    lda s_on
    beq so_no
    lda sx
    cmp ttx
    bne so_no
    lda sy
    cmp tty
    beq so_yes
so_no:
    clc
    rts
so_yes:
    sec
    rts

put_slot:                ; write char A at (scrlo),y + matching color
    sta (scrlo),y
    cmp #CH_WALL
    beq ps_wall
    lda #BLACK
    sta (collo),y
    rts
ps_wall:
    lda #COL_WALL
    sta (collo),y
    rts

; ---- paint the four slots around the cursor post with the
; color in A - only wall blocks change, so the highlight marks
; exactly the pieces a spin would move (floors stay black) ----
mark_slots:
    sta hlcol
    ldx ky               ; north
    dex
    jsr row_ptr
    ldy kx
    jsr mark_one
    ldx ky               ; south
    inx
    jsr row_ptr
    ldy kx
    jsr mark_one
    ldx ky               ; west
    jsr row_ptr
    ldy kx
    dey
    jsr mark_one
    iny                  ; east: falls through to mark it
    iny
mark_one:
    lda (scrlo),y
    cmp #CH_WALL
    bne mo_skip
    lda hlcol
    sta (collo),y
mo_skip:
    rts

; ---- the enemies: staggered random walkers ----
upd_enemies:
    lda #0
    sta ei
ue_loop:
    ldx ei
    lda edead,x
    beq ue_alive
    dec edead,x          ; shot down: waiting to respawn
    bne ue_next
    jsr spawn_one        ; the timer ran out: back on a fresh cell
    jmp ue_next
ue_alive:
    lda framectr
    clc
    adc estag,x
    and #7               ; each enemy steps every 8th frame
    bne ue_next
    jsr enemy_step
    lda endflag
    bne ue_out
ue_next:
    inc ei
    lda ei
    cmp #NENEMIES
    bne ue_loop
ue_out:
    rts

estag: !byte 0, 2, 4, 6

enemy_step:
    jsr rand8            ; 1 in 4: wander off in a new direction
    and #3
    beq es_newdir
    ldx ei
    lda edir,x
    jsr etry_dir
    bcc es_done
es_newdir:
    lda #8
    sta etries
es_pick:
    jsr rand8
    and #3
    jsr etry_dir
    bcc es_done
    dec etries           ; walled in on all sides: sit this one out
    bne es_pick
es_done:
    rts

etry_dir:                ; A = direction; C clear when it moved (or won)
    sta etd
    tax
    ldy ei
    lda ex,y
    clc
    adc dxtab,x
    sta ttx
    lda ey,y
    clc
    adc dytab,x
    sta tty
    lda px               ; onto the runner: the round is over
    cmp ttx
    bne en_norun
    lda py
    cmp tty
    bne en_norun
    lda #2
    sta endflag
    clc
    rts
en_norun:
    ldx tty              ; anything but open floor blocks it
    jsr row_ptr
    ldy ttx
    lda (scrlo),y
    cmp #CH_FLOOR
    beq en_open
    sec
    rts
en_open:
    jsr enemy_at         ; another enemy blocks it
    bcc en_nofoe
    sec
    rts
en_nofoe:
    lda s_on             ; walking into the bullet hurts too
    beq en_move
    lda sx
    cmp ttx
    bne en_move
    lda sy
    cmp tty
    bne en_move
    lda #0
    sta s_on
    ldx ei
    jsr kill_idx
    clc
    rts
en_move:
    ldx ei
    lda ttx
    sta ex,x
    lda tty
    sta ey,x
    lda etd
    sta edir,x
    clc
    rts

; ---- per-frame flashes: the portal spins and blinks, the
; freshly spun walls flash white, the cursor shows the
; recharge state on its own color ----
upd_flash:
    jsr upd_portal       ; cycle the portal glyph
    ldx exrow
    jsr row_ptr
    ldy #38
    lda framectr
    and #8
    bne uf_exw
    lda #COL_EXIT
    jmp uf_exset
uf_exw:
    lda #WHITE
uf_exset:
    sta (collo),y
    lda rotflash         ; the spun walls flash, then re-highlight
    beq uf_norf
    dec rotflash
    bne uf_white
    lda #COL_HILITE
    jmp uf_mark
uf_white:
    lda #WHITE
uf_mark:
    jsr mark_slots
uf_norf:
    lda opt_cool         ; the cursor dims red while recharging
    beq uf_hot
    lda cool
    beq uf_hot
    lda #RED
    jmp uf_cset
uf_hot:
    lda #WHITE
uf_cset:
    sta SPRCOL+SP_CUR
    rts

; ---- status row: the spin recharge readout (cooldown option)
; "wait" + a bar draining pixel by pixel, "ready" after ----
upd_status:
    lda opt_cool
    bne us_show
    rts
us_show:
    lda cool
    beq us_ready
    +prtext 0, 17, LRED, txt_wait, 4
    lda cool             ; pixels left: cool / 2 = 0-80
    lsr
    sta ptmp
    ldx #0
us_bar:
    lda ptmp
    beq us_empty
    cmp #8
    bcc us_part
    sec                  ; a full cell, and onward
    sbc #8
    sta ptmp
    lda #$a0
    jmp us_put
us_part:
    clc                  ; 1-7 pixels: one of the bar chars
    adc #CH_BAR-1
    ldy #0
    sty ptmp
    jmp us_put
us_empty:
    lda #$20
us_put:
    sta SCREEN+23,x      ; bar cells: row 0, columns 23-32
    lda #LRED
    sta COLRAM+23,x
    inx
    cpx #10
    bne us_bar
    rts
us_ready:
    +prtext 0, 17, LGREEN, txt_ready, 5
    lda #$20             ; clear the bar area
    ldx #9
us_clr:
    sta SCREEN+23,x
    dex
    bpl us_clr
    rts

; ---- the round clock, live on the status row ----
upd_clock:
    lda tmin
    jsr two_digits
    stx SCREEN+11        ; clock cells: row 0, columns 11-15
    sta SCREEN+12
    lda #$3a             ; ':'
    sta SCREEN+13
    lda tsec
    jsr two_digits
    stx SCREEN+14
    sta SCREEN+15
    ldx #4
ucl_col:
    lda #LGREY
    sta COLRAM+11,x
    dex
    bpl ucl_col
    rts

; ---- drive the eight sprites from the grid state ----
upd_sprites:
    lda framectr
    lsr
    lsr
    lsr
    sta frame8
    ; the runner glides 2 pixels a frame
    lda px
    sta tgc
    lda py
    sta tgr
    jsr set_target
    lda #2
    sta gspd
    ldx #SP_RUN
    jsr spr_glide
    ; the cursor glides 4 (its step is two cells)
    lda kx
    sta tgc
    lda ky
    sta tgr
    jsr set_target
    lda #4
    sta gspd
    ldx #SP_CUR
    jsr spr_glide
    ; the bullet snaps cell to cell
    lda sx
    sta tgc
    lda sy
    sta tgr
    jsr set_target
    ldx #SP_SHOT
    jsr spr_jump
    ; the enemies glide 1
    lda #1
    sta gspd
    ldx #0
us_en:
    stx ptmp
    lda ex,x
    sta tgc
    lda ey,x
    sta tgr
    jsr set_target
    lda ptmp
    clc
    adc #SP_EN
    tax
    jsr spr_glide
    ldx ptmp
    inx
    cpx #NENEMIES
    bne us_en
    ; shapes: the runner bobs, each enemy waves on its own beat
    lda frame8
    and #1
    clc
    adc #SPR_RUN
    sta SPRPTR+SP_RUN
    lda #SPR_CUR
    sta SPRPTR+SP_CUR
    lda #SPR_SHOT
    sta SPRPTR+SP_SHOT
    ldx #0
us_shape:
    txa
    clc
    adc frame8
    and #1
    sta rtmp
    lda #SPR_ENA         ; enemies 0-1 are ghosts, 2-3 crawlers
    cpx #2
    bcc us_seta
    lda #SPR_ENB
us_seta:
    clc
    adc rtmp
    sta SPRPTR+SP_EN,x
    inx
    cpx #NENEMIES
    bne us_shape
    ; enable: runner + cursor + the bullet and the live enemies
    lda #%00000011
    ldy s_on
    beq us_nosht
    ora #%00000100
us_nosht:
    sta rtmp
    ldx #0
us_alive:
    lda edead,x
    bne us_dead
    lda rtmp
    ora ebit,x
    sta rtmp
us_dead:
    inx
    cpx #NENEMIES
    bne us_alive
    lda rtmp
    sta SPR_EN
    jmp spr_commit

ebit: !byte 8, 16, 32, 64

; ---- play texts ----
txt_goal:  !scr "exit "
           !byte CH_EXIT
txt_goale:
txt_hint:  !scr "p1: joy2/wasd   p2: joy1/ijkl"
txt_hinte:
txt_wait:  !scr "wait"
txt_ready: !scr "ready"

; ---- play variables ----
px:      !byte 0         ; runner position (screen col / row)
py:      !byte 0
fdx:     !byte 0         ; runner facing: the gun aims this way
fdy:     !byte 0
kx:      !byte 0         ; corner cursor position (post col / row)
ky:      !byte 0
exrow:   !byte 0         ; screen row of the exit portal
endflag: !byte 0         ; 0 = playing, 1 = escaped, 2 = caught
cool:    !byte 0         ; spin recharge frames left (cooldown option)
rotflash:!byte 0         ; frames the freshly spun walls stay white
s_on:    !byte 0         ; bullet in flight?
sx:      !byte 0         ; bullet position and heading
sy:      !byte 0
sdx:     !byte 0
sdy:     !byte 0
rheld:   !byte 0         ; runner direction repeat state
rtimer:  !byte 0
rdir:    !byte 0
rfheld:  !byte 0         ; runner fire edge detection state
cheld:   !byte 0         ; cursor direction repeat state
ctimer:  !byte 0
cdir:    !byte 0
cfheld:  !byte 0         ; cursor fire edge detection state
j2bits:  !byte 0
ptmp:    !byte 0         ; scratch
ttx:     !byte 0         ; move target (col / row)
tty:     !byte 0
nch:     !byte 0         ; the four slot chars around the cursor
ech:     !byte 0
sch:     !byte 0
wch:     !byte 0
hlcol:   !byte 0         ; mark_slots color parameter
latwcol: !byte 0         ; draw_lattice colors: walls, posts
latpcol: !byte 0
tframe:  !byte 0         ; round clock: frame, second, minute
tsec:    !byte 0
tmin:    !byte 0
frame8:  !byte 0         ; framectr / 8: the animation beat
ei:      !byte 0         ; enemy loop index
etries:  !byte 0
etd:     !byte 0
gcx:     !byte 0         ; maze generator state
gcy:     !byte 0
gsp:     !byte 0
gn:      !byte 0
gtd:     !byte 0
gnx:     !byte 0
gny:     !byte 0
gdlist:  !fill 4, 0
ex:      !fill NENEMIES, 0   ; enemy positions, headings, colors
ey:      !fill NENEMIES, 0
edir:    !fill NENEMIES, 0
ecol:    !fill NENEMIES, 0
edead:   !fill NENEMIES, 0   ; respawn countdown, 0 = alive

; ---- maze generator buffers ----
visited: !fill NCELLS, 0
stackx:  !fill NCELLS, 0
stacky:  !fill NCELLS, 0

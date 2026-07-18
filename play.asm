; -----------------------------------------------------------
; play.asm - the game: a fresh maze is carved with a
; recursive backtracker every round, player 1 (joystick 2)
; runs the corridors toward the exit diamond, player 2
; (joystick 1) rides the wall corners and fire spins the
; four wall pieces around the cursor by 90 degrees; the
; roaming colored enemies end the round on touch
;
; screen layout: status on row 0, the 39x23 maze lattice on
; rows 1-23 (cells = odd col / even row, posts = even col /
; odd row, wall slots = the rest), a hint line on row 24
; -----------------------------------------------------------

play_init:
    jsr clear_screen
    +prtext 0, 0, WHITE, txt_title, 9
    +prtext 0, 28, LGREY, txt_goal, txt_goale-txt_goal
    +prtext 24, 6, DGREY, txt_hint, txt_hinte-txt_hint

    ; fill the whole lattice with wall blocks
    ldx #1
pi_fillrow:
    stx ptmp
    jsr row_ptr
    ldy #38
pi_fillcol:
    lda #CH_WALL
    sta (scrlo),y
    lda #COL_WALL
    sta (collo),y
    dey
    bpl pi_fillcol
    ldx ptmp
    inx
    cpx #24
    bne pi_fillrow

    ; the pivot posts get their own darker shade
    ldx #1               ; post rows 1, 3, ... 23
pi_postrow:
    stx ptmp
    jsr row_ptr
    ldy #38              ; post columns 38, 36, ... 0
pi_postcol:
    lda #COL_POST
    sta (collo),y
    dey
    dey
    bpl pi_postcol
    ldx ptmp
    inx
    inx
    cpx #25
    bcc pi_postrow

    ; carve the maze
    ldx #0
    lda #0
pi_clrv:
    sta visited,x
    inx
    cpx #NCELLS
    bne pi_clrv
    jsr gen_maze

    ; the exit: a green diamond in the right border wall
pi_exit:
    jsr rand8
    and #$0f
    cmp #MAZE_CH
    bcs pi_exit
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

    ; the runner starts in the top-left cell
    lda #1
    sta px
    lda #2
    sta py
    jsr draw_player

    ; the corner cursor starts on the center post
    lda #18
    sta kx
    lda #11
    sta ky

    jsr spawn_enemies

    ; input state: a fire still held from the previous screen
    ; must be released before it can spin walls
    lda #0
    sta rheld
    sta cheld
    sta endflag
    lda #1
    sta cfheld
    +setupd play_update
    rts

; ============================================================
; maze generation - recursive backtracker over the 19x11
; cells; the screen itself is the wall data structure
; ============================================================
gen_maze:
    lda #0
    sta gcx
    sta gcy
    sta gsp
    jsr gv_mark
    jsr carve_cell
gm_loop:
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
    jmp gm_loop
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
    jmp gm_loop
gm_done:
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
sn_loop:
sn_rx:
    jsr rand8
    and #$0f
    cmp #MAZE_CH
    bcs sn_rx
    clc
    adc #MAZE_CW-MAZE_CH ; cell column 8-18: away from the runner
    asl
    clc
    adc #1
    sta gnx              ; candidate screen column
sn_ry:
    jsr rand8
    and #$0f
    cmp #MAZE_CH
    bcs sn_ry
    asl
    clc
    adc #2
    sta gny              ; candidate screen row
    ldx gny
    jsr row_ptr
    ldy gnx
    lda (scrlo),y
    cmp #CH_FLOOR        ; only an empty cell will do
    bne sn_rx
    lda #CH_ENEMY
    sta (scrlo),y
    jsr rand8
    and #7
    tax
    lda ecoltab,x
    sta (collo),y
    ldx ei
    sta ecol,x
    lda gnx
    sta ex,x
    lda gny
    sta ey,x
    jsr rand8
    and #3
    sta edir,x
    inc ei
    lda ei
    cmp #NENEMIES
    bne sn_loop
    rts

ecoltab:                 ; anything but the white runner / grey walls
    !byte RED, CYAN, PURPLE, YELLOW, ORANGE, LRED, LBLUE, BLUE

; ============================================================
; one frame of play
; ============================================================
play_update:
    jsr upd_runner
    lda endflag
    bne pu_end
    jsr upd_enemies
    lda endflag
    bne pu_end
    jsr upd_cursor
    jsr upd_flash
    rts
pu_end:
    cmp #1
    beq pu_win
    lda #SFX_LOSE
    jsr sfx_play
    jmp lose_init        ; its rts returns to the main loop
pu_win:
    lda #SFX_WIN
    jsr sfx_play
    jmp win_init

; ---- player 1: walk the corridors, one char per step ----
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
    jmp ur_try
ur_up:
    dey
    jmp ur_try
ur_down:
    iny
    jmp ur_try
ur_left:
    dex
ur_try:
    stx ttx
    sty tty
    ldx tty
    jsr row_ptr
    ldy ttx
    lda (scrlo),y
    cmp #CH_FLOOR
    beq ur_go
    cmp #CH_EXIT
    beq ur_win
    cmp #CH_ENEMY
    beq ur_dead
    rts                  ; a wall: blocked
ur_go:
    ldx py
    jsr row_ptr
    ldy px
    lda #CH_FLOOR
    sta (scrlo),y
    lda #BLACK
    sta (collo),y
    lda ttx
    sta px
    lda tty
    sta py
    jmp draw_player
ur_win:
    lda #1
    sta endflag
    rts
ur_dead:
    lda #2
    sta endflag
    rts

draw_player:
    ldx py
    jsr row_ptr
    ldy px
    lda #CH_PLAYER
    sta (scrlo),y
    lda #WHITE
    sta (collo),y
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
    ldx ky               ; the old post gets its color back
    jsr row_ptr
    ldy kx
    lda #COL_POST
    sta (collo),y
    lda ttx
    sta kx
    lda tty
    sta ky
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
; degrees clockwise; denied while anyone stands in them ----
do_rotate:
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
    ; every slot must be plain wall or floor
    lda nch
    jsr rot_ok
    bcs rot_deny
    lda sch
    jsr rot_ok
    bcs rot_deny
    lda wch
    jsr rot_ok
    bcs rot_deny
    lda ech
    jsr rot_ok
    bcs rot_deny
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
    lda #SFX_ROTATE
    jmp sfx_play
rot_deny:
    lda #SFX_DENY
    jmp sfx_play

rot_ok:                  ; C clear when A is spinnable (wall or floor)
    cmp #CH_WALL
    beq ro_yes
    cmp #CH_FLOOR
    beq ro_yes
    sec
    rts
ro_yes:
    clc
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

; ---- the enemies: staggered random walkers ----
upd_enemies:
    lda #0
    sta ei
ue_loop:
    ldx ei
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
    ldx tty
    jsr row_ptr
    ldy ttx
    lda (scrlo),y
    cmp #CH_FLOOR
    beq ed_move
    cmp #CH_PLAYER
    beq ed_kill
    sec                  ; wall, exit or another enemy: blocked
    rts
ed_kill:
    lda #2
    sta endflag
    clc
    rts
ed_move:
    ldx ei
    lda ey,x
    sta gny              ; old position
    lda ex,x
    sta gnx
    lda ttx
    sta ex,x
    lda tty
    sta ey,x
    lda etd
    sta edir,x
    ldx gny              ; erase the old cell
    jsr row_ptr
    ldy gnx
    lda #CH_FLOOR
    sta (scrlo),y
    lda #BLACK
    sta (collo),y
    ldx tty              ; draw at the new one
    jsr row_ptr
    ldy ttx
    lda #CH_ENEMY
    sta (scrlo),y
    ldx ei
    lda ecol,x
    sta (collo),y
    clc
    rts

; ---- per-frame flashes: the exit blinks, the cursor pulses ----
upd_flash:
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
    ldx ky
    jsr row_ptr
    ldy kx
    lda framectr
    and #4
    bne uf_cred
    lda #YELLOW
    jmp uf_cset
uf_cred:
    lda #RED
uf_cset:
    sta (collo),y
    rts

; ---- play texts ----
txt_goal: !scr "reach the "
          !byte CH_EXIT
txt_goale:
txt_hint: !scr "p1: joy2/wasd   p2: joy1/ijkl"
txt_hinte:

; ---- play variables ----
px:      !byte 0         ; runner position (screen col / row)
py:      !byte 0
kx:      !byte 0         ; corner cursor position (post col / row)
ky:      !byte 0
exrow:   !byte 0         ; screen row of the exit diamond
endflag: !byte 0         ; 0 = playing, 1 = escaped, 2 = caught
rheld:   !byte 0         ; runner direction repeat state
rtimer:  !byte 0
rdir:    !byte 0
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

; ---- maze generator buffers ----
visited: !fill NCELLS, 0
stackx:  !fill NCELLS, 0
stacky:  !fill NCELLS, 0

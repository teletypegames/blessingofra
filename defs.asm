; -----------------------------------------------------------
; defs.asm - hardware registers, constants, zero page, macros
; included first by main.asm
; -----------------------------------------------------------

; ---- hardware registers ----
RASTER  = $d012          ; current raster line
BORDER  = $d020          ; border color register
BG      = $d021          ; background color register
SCREEN  = $0400          ; screen RAM (40x25 chars)
COLRAM  = $d800          ; color RAM
SPR_EN  = $d015          ; sprite enable bits (parked at 0)
CIA1_PA = $dc00          ; CIA1 port A: keyboard columns / joystick 2
CIA1_PB = $dc01          ; CIA1 port B: keyboard rows / joystick 1
CIA1_TA = $dc04          ; CIA1 timer A low byte: free-running entropy

; ---- SID registers (single-voice SFX driver) ----
SID_V1FL = $d400         ; voice 1 frequency low
SID_V1FH = $d401         ; voice 1 frequency high
SID_V1PL = $d402         ; voice 1 pulse width low
SID_V1PH = $d403         ; voice 1 pulse width high
SID_V1CR = $d404         ; voice 1 control (waveform + gate)
SID_V1AD = $d405         ; voice 1 attack/decay
SID_V1SR = $d406         ; voice 1 sustain/release
SID_VOL  = $d418         ; filter mode + master volume

; ---- SFX IDs ----
SFX_CURSOR = 0           ; corner cursor step: click
SFX_SELECT = 1           ; menu fire: rising tone
SFX_ROTATE = 2           ; wall spin: noise whoosh
SFX_DENY   = 3           ; blocked spin: low buzz
SFX_WIN    = 4           ; escape: rising jingle
SFX_LOSE   = 5           ; caught: descending sweep
SFX_SHOT   = 6           ; gun fired: short high tick
SFX_HIT    = 7           ; enemy hit: noise burst
NSFX       = 8

; ---- colors ----
BLACK   = 0
WHITE   = 1
RED     = 2
CYAN    = 3
PURPLE  = 4
GREEN   = 5
BLUE    = 6
YELLOW  = 7
ORANGE  = 8
BROWN   = 9
LRED    = 10
DGREY   = 11
MGREY   = 12
LGREEN  = 13
LBLUE   = 14
LGREY   = 15

; ---- joystick bits (after read_joy / read_joy2, active high) ----
JOY_UP    = 1
JOY_DOWN  = 2
JOY_LEFT  = 4
JOY_RIGHT = 8
JOY_FIRE  = 16

; ---- the maze ----
; 19x11 cells on a 39x23 char lattice (screen rows 1-23):
;   cell  = odd column,  even row  (walkable)
;   post  = even column, odd row   (pivot, always solid)
;   slot  = the rest: wall pieces that spin around the posts
; wall thickness therefore equals corridor width: one cell
MAZE_CW  = 19            ; cells across
MAZE_CH  = 11            ; cells down
NCELLS   = MAZE_CW * MAZE_CH
NENEMIES = 4

CH_WALL   = $a0          ; inverse space: solid wall block
CH_FLOOR  = $20          ; space: corridor
CH_EXIT   = $5a          ; diamond: the goal
CH_PLAYER = $51          ; filled ball: the runner
CH_ENEMY  = $57          ; open circle: an enemy
CH_SHOT   = $2a          ; asterisk: the runner's bullet

COL_WALL = MGREY         ; spinnable wall pieces
COL_POST = DGREY         ; fixed pivot posts
COL_EXIT = LGREEN        ; the exit diamond

; ---- game timing ----
REP_HOLD    = 10         ; runner: frames before a held dir repeats
REP_PERIOD  = 5          ; runner: frames between repeat steps
CREP_HOLD   = 12         ; cursor: same, a touch slower
CREP_PERIOD = 7
COOL_TIME   = 160        ; spin cooldown option: recharge frames
RESPAWN_TIME = 150       ; gun option: frames until a hit enemy returns
RAS_SYNC    = 251        ; raster line polled for the frame sync

; ---- zero page pointers (same slots as rabbitc64) ----
txtlo  = $f5             ; text pointer for the print routines (2 bytes)
txthi  = $f6
updvec = $f9             ; state update vector (2 bytes)
scrlo  = $fb
scrhi  = $fc
collo  = $fd
colhi  = $fe

; ---- helper macros: print a normal / big text line ----
!macro prtext .row, .col, .color, .txt, .len {
    lda #<.txt
    sta txtlo
    lda #>.txt
    sta txthi
    lda #.row
    sta prow
    lda #.col
    sta pcol
    lda #.color
    sta pcolor
    lda #.len
    sta plen
    jsr print_text
}

!macro prbig .row, .col, .color, .txt, .len {
    lda #<.txt
    sta txtlo
    lda #>.txt
    sta txthi
    lda #.row
    sta bigrow
    lda #.col
    sta bigcol
    lda #.color
    sta bigcolor
    lda #.len
    sta biglen
    jsr draw_big
}

; ---- set the state update vector ----
!macro setupd .addr {
    lda #<.addr
    sta updvec
    lda #>.addr
    sta updvec+1
}

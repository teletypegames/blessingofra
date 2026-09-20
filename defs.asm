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
SCRCTL  = $d011          ; control 1: raster msb, y-scroll
SPR_EN  = $d015          ; sprite enable bits
SPRX0   = $d000          ; sprite 0 x (x/y pairs go up from here)
SPRY0   = $d001          ; sprite 0 y
SPRMSB  = $d010          ; 9th x position bit of each sprite
SPRDBLY = $d017          ; sprite y expand
VMCSB   = $d018          ; memory setup: screen + charset base
SPRPRI  = $d01b          ; sprite/background priority
SPRMCEN = $d01c          ; sprite multicolor enable
SPRDBLX = $d01d          ; sprite x expand
SPRCOL  = $d027          ; sprite colors, 8 registers
CPUPORT = $01            ; 6510 port: ROM/RAM banking
CIA1_PA = $dc00          ; CIA1 port A: keyboard columns / joystick 2
CIA1_PB = $dc01          ; CIA1 port B: keyboard rows / joystick 1
CIA1_TA = $dc04          ; CIA1 timer A low byte: free-running entropy

CHARSET = $3800          ; RAM charset: ROM font + the custom tiles
SPRPTR  = SCREEN + $3f8  ; sprite shape pointers

; ---- SID registers ----
; voice 1 belongs to the SFX driver, voices 2 and 3 to the
; music player, which reaches their registers as SID+n,y
; (y = 7 for voice 2, 14 for voice 3)
SID      = $d400         ; the chip's base
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
SFX_SHOT   = 6           ; gun / scorpion sting: short high tick
SFX_HIT    = 7           ; enemy hit: noise burst
NSFX       = 8

; ---- music IDs ----
MUS_TITLE = 0            ; the title song: intro, menu, story
MUS_GAME  = 1            ; the drum groove under the levels
MUS_WIN   = 2            ; the escape song
MUS_LOSE  = 3            ; the game over dirge

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
; a lattice of (2*cells+1) chars per side, centered on rows
; 1-23; local coordinates inside the lattice:
;   cell  = odd column,  odd row   (walkable)
;   post  = even column, even row  (pivot, always solid)
;   slot  = the rest: wall pieces that spin around the posts
; wall thickness therefore equals corridor width: one cell
; the levels are squares, one cell bigger each level: MZMIN
; up to MZMAX (11x11 cells = 23x23 chars, the tallest square
; the screen fits); the menu backdrop uses the full lattice
MZMIN    = 4             ; level 1: 4x4 cells
MZMAX    = 11            ; level 8: 11x11 cells
MAZE_CW  = 19            ; the largest lattice: the menu backdrop
MAZE_CH  = 11
NCELLS   = MAZE_CW * MAZE_CH
NENEMIES = 4             ; enemy sprite slots (a level uses 1-4)

; ---- characters (the custom tiles live in the RAM charset) ----
CH_WALL   = $e0          ; sandstone block: spinnable wall piece
CH_POST   = $e1          ; bolted plate: fixed pivot post
CH_EXIT   = $e2          ; the portal out (4 animated glyph frames)
CH_FLOOR  = $20          ; space: corridor
CH_BAR    = $e3          ; 7 chars: a bar cell 1-7 pixels full
CH_RELIC  = $31          ; the relics wear their order: '1'-'9'
NRELIC    = 9            ; most relics on a level (level 8)

; ---- the actors are hardware sprites ----
SP_RUN   = 0             ; player 1, the worker
SP_CUR   = 1             ; player 2, ra's cursor
SP_SHOT  = 2             ; the optional bullet
SP_EN    = 3             ; the enemies ride sprites 3-6
SP_STING = 7             ; the scorpions' venom sting

; ---- desert palette ----
COL_WALL = ORANGE        ; sandstone wall pieces
COL_POST = BROWN         ; fixed pivot posts
COL_EXIT = LGREEN        ; the exit portal
COL_HILITE = YELLOW      ; walls the cursor's spin would move
COL_SCARAB = CYAN        ; the scarabs
COL_SCORP  = LRED        ; the scorpions
COL_STING  = PURPLE      ; the venom sting
COL_RELIC  = LBLUE       ; the numbered relics (relic order option)
STATCOL  = BROWN         ; background band behind the status row

; ---- game timing ----
REP_HOLD    = 10         ; runner: frames before a held dir repeats
REP_PERIOD  = 5          ; runner: frames between repeat steps
CREP_HOLD   = 12         ; cursor: same, a touch slower
CREP_PERIOD = 7
COOL_TIME   = 160        ; spin cooldown option: recharge frames
RESPAWN_TIME = 150       ; gun option: frames until a hit enemy returns
RAS_SYNC    = 251        ; raster line polled for the frame sync
BUILD_STEPS = 8          ; maze carve animation: generator steps a frame

; ---- zero page pointers (same slots as rabbitc64) ----
txtlo  = $f5             ; text pointer for the print routines (2 bytes)
txthi  = $f6
musptr = $f7             ; music player pattern pointer (2 bytes)
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

; ---- leave the current screen: fade to black, then run the
; init routine of the next one ----
!macro fadeto .addr {
    lda #<.addr
    sta fadevec
    lda #>.addr
    sta fadevec+1
    jmp fade_start
}

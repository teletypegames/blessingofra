; -----------------------------------------------------------
; gfx.asm - the graphics layer:
;   - the ROM font is copied into RAM and a handful of custom
;     tiles are stamped over it (sandstone wall, pivot post,
;     the animated exit portal, the 1/8-step cooldown bar)
;   - a small sprite engine: every actor lives on the char
;     grid, its sprite glides toward the cell a few pixels a
;     frame (the worker bobs, the enemies wave)
;   - fade to black: the transition between two screens
; -----------------------------------------------------------

; ---- one-time setup: font to RAM, custom tiles, VIC ----
gfx_init:
    lda #$33             ; char ROM in at $d000 (I/O out briefly)
    sta CPUPORT
    lda #$d0
    sta txthi
    lda #>CHARSET
    sta scrhi
    lda #0
    sta txtlo
    sta scrlo
    ldx #8               ; 2 KB: the full uppercase set
gc_page:
    ldy #0
gc_byte:
    lda (txtlo),y
    sta (scrlo),y
    iny
    bne gc_byte
    inc txthi
    inc scrhi
    dex
    bne gc_page
    lda #$37             ; I/O back in
    sta CPUPORT
    ; the brick wall + the pivot post (two consecutive codes)
    ldx #15
gc_tiles:
    lda tile_gfx,x
    sta CHARSET+CH_WALL*8,x
    dex
    bpl gc_tiles
    ; the portal starts on frame 0
    ldx #7
gc_portal:
    lda portal_gfx,x
    sta CHARSET+CH_EXIT*8,x
    dex
    bpl gc_portal
    ; the seven bar cells: 1-7 pixels filled from the left
    ldx #0
    ldy #0
gc_bar:
    lda barmask,x
    sta rtmp
    lda #8
    sta rtmp2
gc_bar8:
    lda rtmp
    sta CHARSET+CH_BAR*8,y
    iny
    dec rtmp2
    bne gc_bar8
    inx
    cpx #7
    bne gc_bar
    ; VIC: screen at $0400, charset at $3800
    lda #$1e
    sta VMCSB
    ; sprites: hires, unexpanded, in front of the chars
    lda #0
    sta SPRDBLY
    sta SPRDBLX
    sta SPRMCEN
    sta SPRPRI
    sta SPRMSB
    rts

; ---- cycle the portal glyph: 4 frames, one every 8 frames;
; rewriting the definition animates every portal on screen ----
upd_portal:
    lda framectr
    and #7
    bne up_done
    lda framectr
    and #$18             ; (frame index) * 8 = data offset
    tay
    ldx #0
up_copy:
    lda portal_gfx,y
    sta CHARSET+CH_EXIT*8,x
    iny
    inx
    cpx #8
    bne up_copy
up_done:
    rts

; ============================================================
; sprite engine
; ============================================================

; grid cell (tgc, tgr) -> pixel target tgxl/tgxh, tgy
set_target:
    lda #0
    sta tgxh
    lda tgc
    asl
    rol tgxh
    asl
    rol tgxh
    asl
    rol tgxh
    clc
    adc #24              ; first visible pixel column
    sta tgxl
    bcc st_y
    inc tgxh
st_y:
    lda tgr
    asl
    asl
    asl
    clc
    adc #50              ; first visible raster line
    sta tgy
    rts

; sprite X snaps straight onto the target
spr_jump:
    lda tgxl
    sta sprxl,x
    lda tgxh
    sta sprxh,x
    lda tgy
    sta spry,x
    rts

; sprite X slides gspd pixels per axis toward the target; the
; actors re-target every frame, so the distance always fits in
; a signed byte and a step never overshoots
spr_glide:
    lda tgxl
    sec
    sbc sprxl,x
    sta dtmp
    lda tgxh
    sbc sprxh,x          ; the high byte only carries the sign
    lda dtmp
    beq sg_y
    bmi sg_left
    cmp gspd             ; rightward: step = min(distance, speed)
    bcc sg_rgo
    lda gspd
sg_rgo:
    clc
    adc sprxl,x
    sta sprxl,x
    bcc sg_y
    inc sprxh,x
    jmp sg_y
sg_left:
    eor #$ff             ; leftward: the same on the distance
    clc
    adc #1
    cmp gspd
    bcc sg_lgo
    lda gspd
sg_lgo:
    sta dtmp
    lda sprxl,x
    sec
    sbc dtmp
    sta sprxl,x
    bcs sg_y
    dec sprxh,x
sg_y:
    lda tgy
    sec
    sbc spry,x
    beq sg_done
    bmi sg_up
    cmp gspd
    bcc sg_dgo
    lda gspd
sg_dgo:
    clc
    adc spry,x
    sta spry,x
    rts
sg_up:
    eor #$ff
    clc
    adc #1
    cmp gspd
    bcc sg_ugo
    lda gspd
sg_ugo:
    sta dtmp
    lda spry,x
    sec
    sbc dtmp
    sta spry,x
sg_done:
    rts

; push all eight sprite positions + the x msb bits to the VIC
spr_commit:
    lda #0
    sta dtmp
    ldx #7
sc_loop:
    lda sprxh,x
    beq sc_low
    lda dtmp
    ora sprbit,x
    sta dtmp
sc_low:
    txa
    asl
    tay
    lda sprxl,x
    sta SPRX0,y
    lda spry,x
    sta SPRY0,y
    dex
    bpl sc_loop
    lda dtmp
    sta SPRMSB
    rts

sprbit: !byte 1, 2, 4, 8, 16, 32, 64, 128

; ============================================================
; fade to black - six passes walk every color RAM cell (and
; the sprite colors) down the luminance chains, half a screen
; per frame; then control jumps to the init routine the
; +fadeto macro left in fadevec
; ============================================================
fade_start:
    lda #$ff
    sta statbg           ; no status band while fading
    lda #0
    sta bflash
    sta borbase
    sta fadecnt
    sta fadehalf
    +setupd fade_update
    rts

fade_update:
    lda fadehalf         ; half the color RAM per frame
    eor #1
    sta fadehalf
    bne fu_hi
    ldx #0
fu_lo:
    lda COLRAM,x
    and #15
    tay
    lda fadetbl,y
    sta COLRAM,x
    lda COLRAM+$100,x
    and #15
    tay
    lda fadetbl,y
    sta COLRAM+$100,x
    inx
    bne fu_lo
    rts
fu_hi:
    ldx #0
fu_hi2:
    lda COLRAM+$200,x
    and #15
    tay
    lda fadetbl,y
    sta COLRAM+$200,x
    lda COLRAM+$2e8,x
    and #15
    tay
    lda fadetbl,y
    sta COLRAM+$2e8,x
    inx
    bne fu_hi2
    ldx #7               ; the sprites sink with the screen
fu_spr:
    lda SPRCOL,x
    and #15
    tay
    lda fadetbl,y
    sta SPRCOL,x
    dex
    bpl fu_spr
    inc fadecnt
    lda fadecnt
    cmp #6               ; the longest chain is black after 5
    bne fu_stay
    lda #0
    sta SPR_EN
    jmp (fadevec)        ; its rts returns to the main loop
fu_stay:
    rts

fadetbl:                 ; each color, one step darker
    !byte $00, $0f, $09, $0c, $0b, $0b, $00, $08
    !byte $02, $00, $02, $00, $0b, $05, $06, $0c

; ---- the custom tiles ----
tile_gfx:                ; CH_WALL: sandstone blocks, dark mortar
    !byte %11111111
    !byte %11110111
    !byte %11110111
    !byte %00000000
    !byte %11111111
    !byte %01111111
    !byte %01111111
    !byte %00000000
                         ; CH_POST: a bolted plate
    !byte %11111111
    !byte %10000001
    !byte %10111101
    !byte %10100101
    !byte %10100101
    !byte %10111101
    !byte %10000001
    !byte %11111111

portal_gfx:              ; CH_EXIT frame 0: closed
    !byte %00000000
    !byte %00011000
    !byte %00111100
    !byte %01100110
    !byte %01100110
    !byte %00111100
    !byte %00011000
    !byte %00000000
                         ; frame 1: opening
    !byte %00011000
    !byte %00111100
    !byte %01100110
    !byte %11000011
    !byte %11000011
    !byte %01100110
    !byte %00111100
    !byte %00011000
                         ; frame 2: wide open, sparkling
    !byte %00111100
    !byte %01100110
    !byte %11011011
    !byte %10111101
    !byte %10111101
    !byte %11011011
    !byte %01100110
    !byte %00111100
                         ; frame 3: closing again
    !byte %00011000
    !byte %00111100
    !byte %01100110
    !byte %11000011
    !byte %11000011
    !byte %01100110
    !byte %00111100
    !byte %00011000

barmask:                 ; bar cell fills, 1-7 pixels
    !byte $80, $c0, $e0, $f0, $f8, $fc, $fe

; ---- graphics layer variables ----
sprxl:    !fill 8, 0     ; sprite pixel positions (x low/high, y)
sprxh:    !fill 8, 0
spry:     !fill 8, 0
tgc:      !byte 0        ; set_target input: grid column / row
tgr:      !byte 0
tgxl:     !byte 0        ; set_target output: pixel target
tgxh:     !byte 0
tgy:      !byte 0
gspd:     !byte 0        ; spr_glide: pixels per frame
dtmp:     !byte 0        ; scratch
statbg:   !byte $ff      ; status band color, $ff = no band
bflash:   !byte 0        ; border flash: frames left + color
bcolor:   !byte 0
borbase:  !byte 0        ; steady border color of the screen
fadevec:  !byte 0, 0     ; where fade_update jumps when done
fadecnt:  !byte 0        ; fade passes completed
fadehalf: !byte 0        ; which color RAM half is next

!if (fadevec & 255) = 255 { !error "fadevec must not straddle a page" }

; ---- sprite shapes: 8x8 art in the top-left of each block ----
!align 63, 0
spr_run0:                ; the runner: a bright-eyed ball...
    !byte %00111100, 0, 0
    !byte %01111110, 0, 0
    !byte %11011011, 0, 0
    !byte %11111111, 0, 0
    !byte %11111111, 0, 0
    !byte %11111111, 0, 0
    !byte %01111110, 0, 0
    !byte %00111100, 0, 0
    !fill 40, 0
spr_run1:                ; ...that bobs as it goes
    !byte %00000000, 0, 0
    !byte %00111100, 0, 0
    !byte %01111110, 0, 0
    !byte %11011011, 0, 0
    !byte %11111111, 0, 0
    !byte %11111111, 0, 0
    !byte %01111110, 0, 0
    !byte %00111100, 0, 0
    !fill 40, 0
spr_shot0:               ; the bullet
    !byte %00000000, 0, 0
    !byte %00000000, 0, 0
    !byte %00011000, 0, 0
    !byte %00111100, 0, 0
    !byte %00111100, 0, 0
    !byte %00011000, 0, 0
    !byte %00000000, 0, 0
    !byte %00000000, 0, 0
    !fill 40, 0
spr_cur0:                ; the corner cursor: four brackets
    !byte %11100111, 0, 0
    !byte %10000001, 0, 0
    !byte %10000001, 0, 0
    !byte %00000000, 0, 0
    !byte %00000000, 0, 0
    !byte %10000001, 0, 0
    !byte %10000001, 0, 0
    !byte %11100111, 0, 0
    !fill 40, 0
spr_sting0:              ; the scorpion's venom sting: a drop
    !byte %00000000, 0, 0
    !byte %00011000, 0, 0
    !byte %00111100, 0, 0
    !byte %01111110, 0, 0
    !byte %00111100, 0, 0
    !byte %00011000, 0, 0
    !byte %00000000, 0, 0
    !byte %00000000, 0, 0
    !fill 40, 0
spr_ena0:                ; even enemies: a scarab, legs out...
    !byte %00100100, 0, 0
    !byte %10111101, 0, 0
    !byte %01111110, 0, 0
    !byte %11011011, 0, 0
    !byte %11011011, 0, 0
    !byte %01111110, 0, 0
    !byte %10111101, 0, 0
    !byte %00100100, 0, 0
    !fill 40, 0
spr_ena1:                ; ...and tucked as it scuttles
    !byte %00100100, 0, 0
    !byte %00111100, 0, 0
    !byte %11111111, 0, 0
    !byte %01011010, 0, 0
    !byte %01011010, 0, 0
    !byte %11111111, 0, 0
    !byte %00111100, 0, 0
    !byte %00100100, 0, 0
    !fill 40, 0
spr_enb0:                ; odd enemies: a scorpion, claws up,
    !byte %11000011, 0, 0    ; the tail swinging right...
    !byte %01100110, 0, 0
    !byte %00111100, 0, 0
    !byte %01111110, 0, 0
    !byte %00111100, 0, 0
    !byte %00011000, 0, 0
    !byte %00001100, 0, 0
    !byte %00011110, 0, 0
    !fill 40, 0
spr_enb1:                ; ...and left
    !byte %11000011, 0, 0
    !byte %01100110, 0, 0
    !byte %00111100, 0, 0
    !byte %01111110, 0, 0
    !byte %00111100, 0, 0
    !byte %00011000, 0, 0
    !byte %00110000, 0, 0
    !byte %01111000, 0, 0
    !fill 40, 0

SPR_RUN   = spr_run0 DIV 64
SPR_SHOT  = spr_shot0 DIV 64
SPR_CUR   = spr_cur0 DIV 64
SPR_STING = spr_sting0 DIV 64
SPR_ENA   = spr_ena0 DIV 64
SPR_ENB   = spr_enb0 DIV 64

!if spr_run0 < $2000 { !error "sprite data slid under $2000: the VIC sees the char ROM shadow there" }
!if * > CHARSET { !error "the program ran into the charset at $3800" }

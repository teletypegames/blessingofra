# Blessing of Ra

**Blessing of Ra** - a two-player pyramid escape for the Commodore 64
(ACME + VICE), in the same spirit as [rabbitc64](../rabbitc64).

The legend: when the great pyramid rose, a worker was sealed in its
peak. He prayed to Ra until the sun god took pity - now Ra bends the
pyramid's labyrinth walls to lead him out.

**Player 1** (joystick 2, or `w a s d`) is the worker, running the
corridors toward the green exit portal. **Player 2** (joystick 1, or
`i j k l`) is Ra: a bracket cursor rides the corners of the walls -
fire (or `return`) spins the four wall pieces around the cursor by
90 degrees, reshaping the maze in real time. A spin is denied while
anyone is standing in one of the four slots (the border blips red);
the spun pieces flash white.

Eight levels, each maze one cell bigger than the last: a square that
starts at 4x4 cells and grows to 11x11 - the tallest square lattice
the screen fits - always centered on screen. One more enemy joins
each level (up to four): the cyan **scarabs** roam the corridors,
and the light-red **scorpions** also spit a venom sting whenever
they line up with the worker - the purple drop flies down the
corridor until a wall swallows it.

The look: a desert palette of sandstone walls and brown pivot posts
from a custom RAM charset, every actor (worker, cursor, bullet,
sting, enemies) a hardware sprite gliding smoothly between the
cells, an animated exit portal, a raster color band behind the
status row, and a fade to black between all screens. The menu floats
over a dark maze backdrop under the big gold-washed title.

Under it all runs the song of the pyramid: a two-voice SID score in
the hijaz scale - the half step over the root and the step and a half
above it - the sound the old desert asks for. Voice 2 carries the
drone and a maqsum hand drum, voice 3 the reedy melody with its slow
vibrato; voice 1 stays free for the sound effects. Four tunes take
turns: the slow title song over the whole front end (it runs unbroken
from the TTG logo to the menu), the drum groove under the levels, a
climbing escape song and a dirge for the game over. The options screen
switches the music off and on; the sound effects stay either way.

The options screen adds three optional twists:

- **worker gun** - player 1 shoots a bullet with fire/`space`; a hit
  enemy respawns on a random cell after a pause.
- **spin cooldown** - each spin starts a recharge; further spins are
  denied until the bar on the status row drains (pixel by pixel) and
  the readout flips back from *wait* to *ready* (the cursor also
  turns red while recharging).
- **relic order** - numbered relics lie scattered over the corridors
  and the worker has to gather them *in order*, 1 first, then 2, and
  so on, before the portal will take him. Until the last one is his
  the exit stays sealed (a dull grey, and bumping into it blips the
  border red); the relic he is after next pulses white, and the
  status row counts them off next to the portal glyph. Every level
  adds one more: two on level 1 up to nine on level 8.

Screens: TTG intro (ported from rabbitc64) -> pyramid title card
(the pyramid, the trapped worker and the pulsing sun of Ra) -> main
menu (play / options / story / credits) -> game -> next level, and
after the last one the escape screen (back to the menu); game over
lets fire retry the same level with a fresh maze, `m` backs out to
the menu. The story screen tells the legend and lists who steers
what.

## Build & run

```
make deps       # macOS: brew install acme vice
make build      # -> blessingofra.prg
make run        # build + launch in x64sc
```

Test builds can boot straight into one state:

```
acme -DAUTOPLAY=1 -f cbm -o blessingofra.prg main.asm
# also: AUTOOPTIONS, AUTOSTORY, AUTOPYRAMID, AUTOCREDITS,
# AUTOWIN, AUTOLOSE; add -DFORCEOPTS=1 to start with all
# three options turned on
```

## Files

- `main.asm` - entry point, BASIC stub, per-frame state machine,
  the border/status-band raster work
- `defs.asm` - registers, constants, zero page, macros
- `intro.asm` - TTG boot logo with the gold color wash
- `pyramid.asm` - title card: the pyramid, the worker, the sun of Ra
- `menu.asm` - main menu card over a dark maze backdrop
- `options.asm` - the optional extras and their toggle screen
- `story.asm` - the legend of the worker and Ra + the controls
- `credits.asm` - the crew
- `play.asm` - maze geometry + generation (recursive backtracker,
  animated) + the game and its eight growing levels
- `win.asm` / `over.asm` - end screens
- `common.asm` - shared routines: printing, big block font, the
  title wash, input, RNG
- `sound.asm` - single-voice SID SFX driver
- `music.asm` - two-voice music player on SID voices 2 and 3:
  the driver, the four tunes and their patterns
- `gfx.asm` - RAM charset with the custom tiles, the sprite engine,
  the portal animation and the fade-to-black transition

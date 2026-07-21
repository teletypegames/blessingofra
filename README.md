# labyrintwo (LabyrinTwo)

**LabyrinTwo** - a two-player maze duel for the Commodore 64
(ACME + VICE), in the same spirit as [rabbitc64](../rabbitc64).

A fresh maze carves itself on screen at the start of every round on
a 39x23 lattice where the walls are exactly as wide as the corridors.
**Player 1** (joystick 2, or `w a s d`) runs the corridors toward the
green exit portal while dodging the roaming enemies. **Player 2**
(joystick 1, or `i j k l`) rides the corners of the walls with a
bracket cursor - fire (or `return`) spins the four wall pieces around
the cursor by 90 degrees, reshaping the maze in real time. A spin is
denied while anyone is standing in one of the four slots (the border
blips red); the spun pieces flash white.

The look: brick walls and bolted pivot posts from a custom RAM
charset, every actor (runner, cursor, bullet, enemies) a hardware
sprite gliding smoothly between the cells, an animated exit portal,
a raster color band behind the status row, and a fade to black
between all screens. The menu floats over a dark maze backdrop.

The options screen adds two optional twists:

- **runner gun** - player 1 shoots a bullet with fire/`space`; a hit
  enemy respawns on a random cell after a pause.
- **spin cooldown** - each spin starts a recharge; further spins are
  denied until the bar on the status row drains (pixel by pixel) and
  the readout flips back from *wait* to *ready* (the cursor also
  turns red while recharging).

Screens: TTG intro (ported from rabbitc64) -> main menu
(play / options / rules / controls / credits) -> game -> win (back
to the menu) or game over (fire retries with a fresh maze, `m` backs
out to the menu).

## Build & run

```
make deps       # macOS: brew install acme vice
make build      # -> labyrintwo.prg
make run        # build + launch in x64sc
```

Test builds can boot straight into one state:

```
acme -DAUTOPLAY=1 -f cbm -o labyrintwo.prg main.asm
# also: AUTOOPTIONS, AUTORULES, AUTOCONTROLS, AUTOCREDITS,
# AUTOWIN, AUTOLOSE; add -DFORCEOPTS=1 to start with both
# options turned on
```

## Files

- `main.asm` - entry point, BASIC stub, per-frame state machine,
  the border/status-band raster work
- `defs.asm` - registers, constants, zero page, macros
- `intro.asm` - TTG boot logo with the gold color wash
- `menu.asm` - main menu card over a dark maze backdrop
- `options.asm` - the optional extras and their toggle screen
- `rules.asm` - how to play
- `controls.asm` - joystick + keyboard mappings
- `credits.asm` - the crew
- `play.asm` - maze generation (recursive backtracker, animated)
  + the game
- `win.asm` / `over.asm` - end screens
- `common.asm` - shared routines: printing, big block font, input, RNG
- `sound.asm` - single-voice SID SFX driver
- `gfx.asm` - RAM charset with the custom tiles, the sprite engine,
  the portal animation and the fade-to-black transition

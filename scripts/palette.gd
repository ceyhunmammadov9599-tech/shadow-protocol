class_name Palette
extends RefCounted
## Shadow Protocol - NEON NOIR / TACTICAL STEALTH design system.
##
## Single source of truth for the visual upgrade iteration. Existing
## gameplay scripts keep their (aligned) local constants; NEW visual
## components (beacon, overlay, warnings, touch styling) read from here
## so the whole game shares one palette and one spacing scale.

# --- Environment -----------------------------------------------------------
const BG_SITE := Color(0.035, 0.045, 0.07)          # beyond-bounds site grounds
const FLOOR := Color(0.075, 0.095, 0.13)           # graphite navy floor
const FLOOR_SEAM := Color(0.05, 0.065, 0.09, 0.55) # panel seams
const FLOOR_LIT := Color(0.99, 0.86, 0.55, 0.19)   # lit floor overlay
const WALL := Color(0.16, 0.19, 0.25)              # muted blue-gray structure
const WALL_TOP := Color(0.32, 0.38, 0.47)          # top edge highlight
const WALL_SHADOW := Color(0.045, 0.055, 0.075)    # bottom inner shadow
const BOUNDS_FRAME := Color(0.17, 0.20, 0.26)

# --- Actors ----------------------------------------------------------------
const PLAYER := Color(0.24, 0.78, 0.85)           # controlled cyan/teal
const PLAYER_CROUCH := Color(0.16, 0.52, 0.58)
const PLAYER_SPRINT := Color(0.45, 0.95, 1.0)
const ENEMY_SLATE := Color(0.52, 0.56, 0.66)       # guard neutral
const ENEMY_ALERT := Color(0.92, 0.25, 0.28)       # alarm red

# --- Semantics -------------------------------------------------------------
const INTERACTIVE := Color(0.98, 0.72, 0.28)       # warm amber (terminals)
const INTERACTIVE_DIM := Color(0.62, 0.45, 0.18)
const EXTRACTION := Color(0.32, 0.85, 0.45)        # green (extraction)
const EXTRACTION_LOCKED := Color(0.28, 0.45, 0.34)
const SUCCESS := Color(0.32, 0.85, 0.45)
const FAILURE := Color(0.92, 0.28, 0.30)
const ZONE_FILL := Color(0.90, 0.62, 0.20, 0.10)   # restricted zone floor
const ZONE_BORDER := Color(0.90, 0.62, 0.20, 0.34)

# --- Interface -------------------------------------------------------------
const HUD_PANEL := Color(0.045, 0.06, 0.09, 0.82)
const HUD_TEXT := Color(0.88, 0.90, 0.94)
const HUD_ACCENT := Color(0.30, 0.85, 0.90, 0.9)   # cyan accent strip
const WARN := Color(0.92, 0.28, 0.28)              # danger screen edges
const TOUCH_FILL := Color(0.30, 0.85, 0.90, 0.14)  # touch control language
const TOUCH_RING := Color(0.55, 0.90, 0.95, 0.55)
const TOUCH_PRESSED := Color(0.45, 0.95, 1.0, 0.32)

# --- Spacing / motion ------------------------------------------------------
const PANEL_PAD := 10.0
const BAR_THICKNESS := 8.0
const EDGE_WARN_THICK := 6.0
const MOTION_FAST := 0.12                          # shortest transition (s)
const MOTION_SLOW := 0.25                          # overlay fade (s)

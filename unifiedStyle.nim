from terminal import nil
from colors import nil
import options
import sets

# TODO: Rename this module to 'stylish.nim'

# This entire module is mindless glue
# Please kill me

##[
The terminal module provides the Style type as well as the ForegroundColor
and BackgroundColor types.
This module unifies them into a single Style type which can be used with
the terminal module.

In order to make name conflicts easier, the main type in this module is
called 'Stylish'
]##

type UnifiedColorKind = enum
  uckTrueColor
  uckBackground
  uckForeground
type UnifiedColor = object
  case kind: UnifiedColorKind
  of uckTrueColor:
    colVal: colors.Color
  of uckForeground:
    fgVal: terminal.ForegroundColor
  of uckBackground:
    bgVal: terminal.BackgroundColor

func ucolor(cv: colors.Color): UnifiedColor =
  return UnifiedColor(kind: uckTrueColor, colVal: cv)
func ucolor(fg: terminal.ForegroundColor): UnifiedColor =
  return UnifiedColor(kind: uckForeGround, fgVal: fg)
func ucolor(bg: terminal.BackgroundColor): UnifiedColor =
  return UnifiedColor(kind: uckBackground, bgVal: bg)

type Stylish* = object
  textStyles: set[terminal.Style]
  background: Option[UnifiedColor]
  foreground: Option[UnifiedColor]

template initImpl(backgroundType, foregroundType) =
  func stylish*(foreground: foregroundType, background: backgroundType, textStyles: set[terminal.Style] = {}): Stylish =
    return Stylish(textStyles: textStyles, background: some(background.ucolor), foreground: some(foreground.ucolor))

initImpl(terminal.BackgroundColor, terminal.ForegroundColor)
initImpl(colors.Color            , terminal.ForegroundColor)
initImpl(terminal.BackgroundColor, colors.Color            )
initImpl(colors.Color            , colors.Color            )

func stylish*(background: terminal.BackgroundColor, textStyles: set[terminal.Style] = {}): Stylish =
  return Stylish(textStyles: textStyles, background: some(background.ucolor), foreground: none(UnifiedColor     ))
func stylish*(foreground: terminal.ForegroundColor, textStyles: set[terminal.Style] = {}): Stylish =
  return Stylish(textStyles: textStyles, background: none(UnifiedColor     ), foreground: some(foreground.ucolor))
func stylish*(textStyles: set[terminal.Style] = {}): Stylish =
  return Stylish(textStyles: textStyles, background: none(UnifiedColor     ), foreground: none(UnifiedColor     ))

let styleless* = stylish()

proc writeStylish*(text: string, stylish: Stylish) =
  if stylish.foreground.isSome:
    let ucolor = stylish.foreground.unsafeGet
    case ucolor.kind
    of uckTrueColor:
      terminal.setForegroundColor(stdout, ucolor.colVal)
    of uckForeground:
      terminal.setForegroundColor(stdout, ucolor.fgVal)
    of uckBackground:
      assert(false)

  if stylish.background.isSome:
    let ucolor = stylish.background.unsafeGet
    case ucolor.kind
    of uckTrueColor:
      terminal.setBackgroundColor(stdout, ucolor.colVal)
    of uckForeground:
      assert(false)
    of uckBackground:
      terminal.setBackgroundColor(stdout, ucolor.bgVal)

  terminal.writeStyled(text, stylish.textStyles)
  terminal.resetAttributes()

from terminal import nil
from colors import nil
import options
import sets

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

type UnifiedColor = object
  case trueColor: bool
  of true:
    colVal: colors.Color
  of false:
    # Since ``terminal`` defines the same colors for foreground
    # and background, we may encapsulate both by use of only one
    termVal: terminal.ForegroundColor

func toBackgroundColor*(fg: terminal.ForegroundColor): terminal.BackgroundColor =
  return terminal.BackgroundColor(int(fg) - 10)
func toForegroundColor*(bg: terminal.BackgroundColor): terminal.ForegroundColor =
  return terminal.ForegroundColor(int(bg) + 10)

func ucolor(cv: colors.Color): UnifiedColor =
  return UnifiedColor(trueColor: true, colVal: cv)
func ucolor(tv: terminal.ForegroundColor): UnifiedColor =
  return UnifiedColor(trueColor: false, termVal: tv)
func ucolor(tv: terminal.BackgroundColor): UnifiedColor =
  return UnifiedColor(trueColor: false, termVal: tv.toForegroundColor)

type Stylish* = object
  textStyles: set[terminal.Style]
  background: Option[UnifiedColor]
  foreground: Option[UnifiedColor]

template initImpl(backgroundType, foregroundType) =
  func stylish*(textStyles: set[terminal.Style] = {}, background: backgroundType, foreground: foregroundType): Stylish =
    return Stylish(textStyles: textStyles, background: some(background.ucolor), foreground: some(foreground.ucolor))

initImpl(terminal.BackgroundColor, terminal.ForegroundColor)
initImpl(colors.Color            , terminal.ForegroundColor)
initImpl(terminal.BackgroundColor, colors.Color            )
initImpl(colors.Color            , colors.Color            )

func stylish*(textStyles: set[terminal.Style] = {}, background: terminal.BackgroundColor): Stylish =
  return Stylish(textStyles: textStyles, background: some(background.ucolor), foreground: none(UnifiedColor     ))
func stylish*(textStyles: set[terminal.Style] = {}, foreground: terminal.ForegroundColor): Stylish =
  return Stylish(textStyles: textStyles, background: none(UnifiedColor     ), foreground: some(foreground.ucolor))
func stylish*(textStyles: set[terminal.Style] = {}): Stylish =
  return Stylish(textStyles: textStyles, background: none(UnifiedColor     ), foreground: none(UnifiedColor     ))

let styleless* = stylish()

proc writeStylish*(text: string, stylish: Stylish) =
  if stylish.foreground.isSome:
    let ucolor = stylish.foreground.unsafeGet
    case ucolor.trueColor
    of true:
      terminal.setForegroundColor(stdout, ucolor.colVal)
    of false:
      terminal.setForegroundColor(stdout, ucolor.termVal)

  if stylish.background.isSome:
    let ucolor = stylish.background.unsafeGet
    case ucolor.trueColor
    of true:
      terminal.setBackgroundColor(stdout, ucolor.colVal)
    of false:
      terminal.setBackgroundColor(stdout, ucolor.termVal.toBackgroundColor)

  terminal.writeStyled(text, stylish.textStyles)
  terminal.resetAttributes()

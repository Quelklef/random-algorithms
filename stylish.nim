from terminal import nil
from colors import nil
import options
import sets
import sugar
import sequtils
import tables

from util import `{}`, `|`

# Almost this entire module is mindless glue
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

func initUcolor(cv: colors.Color): UnifiedColor =
  return UnifiedColor(kind: uckTrueColor, colVal: cv)
func initUcolor(fg: terminal.ForegroundColor): UnifiedColor =
  return UnifiedColor(kind: uckForeGround, fgVal: fg)
func initUcolor(bg: terminal.BackgroundColor): UnifiedColor =
  return UnifiedColor(kind: uckBackground, bgVal: bg)

type Stylish* = object
  textStyles: set[terminal.Style]
  background: Option[UnifiedColor]
  foreground: Option[UnifiedColor]

template initImpl(backgroundType, foregroundType) =
  func stylish*(foreground: foregroundType, background: backgroundType, textStyles: set[terminal.Style] = {}): Stylish =
    return Stylish(textStyles: textStyles, background: some(background.initUcolor), foreground: some(foreground.initUcolor))

initImpl(terminal.BackgroundColor, terminal.ForegroundColor)
initImpl(colors.Color            , terminal.ForegroundColor)
initImpl(terminal.BackgroundColor, colors.Color            )
initImpl(colors.Color            , colors.Color            )

func stylish*(background: terminal.BackgroundColor, textStyles: set[terminal.Style] = {}): Stylish =
  return Stylish(textStyles: textStyles, background: some(background.initUcolor), foreground: none(UnifiedColor         ))
func stylish*(foreground: terminal.ForegroundColor, textStyles: set[terminal.Style] = {}): Stylish =
  return Stylish(textStyles: textStyles, background: none(UnifiedColor         ), foreground: some(foreground.initUcolor))
func stylish*(textStyles: set[terminal.Style] = {}): Stylish =
  return Stylish(textStyles: textStyles, background: none(UnifiedColor         ), foreground: none(UnifiedColor         ))

let styleless* = stylish()

proc applyForegroundBackground(stylish: Stylish) =
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

proc writeStylish*(text: string, stylish: Stylish) =
  stylish.applyForegroundBackground()
  terminal.writeStyled(text, stylish.textStyles)
  terminal.resetAttributes()


# Cool, now we get to an actual interesting part of code

# TODO: This section is naive and (presumably) slow

type StylishString* = object
  ## Encapsulates a string styled differently at different sections
  str: string
  # Section styling is encoded as the index the styling starts at
  # accompanied by the styling itself
  # Styles are kept in increasing order of index
  styles: Table[int, Stylish]

func `$`*(ss: StylishString): string =
  return ss.str

func len*(ss: StylishString): int =
  return ss.str.len

func withStyle*(s: string, stylish: Stylish): StylishString =
  ## Apply the style to the whole string
  return StylishString(
    str: s,
    styles: {0: stylish}.toTable
  )

func initStylishString*(s: string): StylishString =
  return StylishString(
    str: s,
    styles: initTable[int, Stylish](),
  )

func shift(styles: Table[int, Stylish], amt: int): Table[int, Stylish] =
  var raw: seq[(int, Stylish)]
  for key, val in styles.pairs:
    raw.add((key + amt, val))
  return raw.toTable

func `&`*(ss0, ss1: StylishString): StylishString =
  return StylishString(
    str: ss0.str & ss1.str,
    styles: ss0.styles | ss1.styles.shift(ss0.len),
  )

# TODO: func
proc getStyle(ss: StylishString, i: int): Stylish =
  for j in countdown(i, 0):
    if j in ss.styles:
      return ss.styles[j]
  return styleless

# TODO: func
proc `[]=`*(ss: var StylishString, sl: Slice[int], stylish: Stylish) =
  let styleAfter = ss.getStyle(sl.b + 1)
  for loc, stylish in ss.styles.pairs:
    if loc > sl.b:
      break
    if loc in sl:
      ss.styles.del(loc)
  ss.styles[sl.b + 1] = styleAfter
  ss.styles[sl.a] = stylish

proc writeStylish*(ss: StylishString) =
  for i, c in ss.str:
    let style = ss.getStyle(i)
    writeStylish($c, style)

func `[]`*(ss: StylishString, sl: Slice[int]): StylishString =
  return StylishString(
    str: ss.str[sl],
    styles: ss.styles.shift(sl.a),
  )
func `{}`*(ss: StylishString, sl: Slice[int]): StylishString =
  return StylishString(
    str: ss.str{sl},
    styles: ss.styles.shift(sl.a),
  )

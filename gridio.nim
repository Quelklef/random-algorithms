import options
import sugar
import sequtils
import terminal
import tables

import stylish
from util import sum, `*`, `{}`

export terminal.Style

when defined(windows):
  # Windows commandlines seem to have poor utf8 support so fallback
  # to a lamer character set
  const gfx_table = {
    # (north, east, south, west) -> string
    (true , true , true , true ): "+",
    (false, true , true , true ): "+",
    (true , false, true , true ): "+",
    (true , true , false, true ): "+",
    (true , true , true , false): "+",
    (true , true , false, false): "+",
    (true , false, true , false): "|",
    (true , false, false, true ): "+",
    (false, true , true , false): "+",
    (false, true , false, true ): "-",
    (false, false, true , true ): "+",
    (true , false, false, false): "|",
    (false, true , false, false): "-",
    (false, false, true , false): "|",
    (false, false, false, true ): "-",
    (false, false, false, false): ".",
  }.toTable
else:
  const gfx_table = {
    # (north, east, south, west) -> string
    (true , true , true , true ): "┼",
    (false, true , true , true ): "┬",
    (true , false, true , true ): "┤",
    (true , true , false, true ): "┴",
    (true , true , true , false): "├",
    (true , true , false, false): "└",
    (true , false, true , false): "│",
    (true , false, false, true ): "┘",
    (false, true , true , false): "┌",
    (false, true , false, true ): "─",
    (false, false, true , true ): "┐",
    (true , false, false, false): "╵",
    (false, true , false, false): "╶",
    (false, false, true , false): "╷",
    (false, false, false, true ): "╴",
    (false, false, false, false): "·",
  }.toTable

# tlx/tly/brx/bry: (top|bottom)-(left|right) (x|y)

type Orientation* = enum
  oVertical
  oHorizontal

func `not`*(o: Orientation): Orientation =
  case o
  of oVertical:
    return oHorizontal
  of oHorizontal:
    return oVertical

type WriteStyle* = enum
  # Each write calls for a clear followed by an overlay
  wsOverwrite
  # Each write is placed underneath the last, looping at the bottom
  wsRadar

type Gridio* = ref object
  childOrientation: Orientation
  # none() -> expand to available space
  # All boxes expand to available space in the oriection perpendicular
  # to their orientation (i.e. horizontal for oHorizontal and vertical for
  # oVertical)
  size: Option[int]
  children*: seq[Gridio]

  writeStyle*: WriteStyle

  # Calculated attributes
  tlx*, tly*, brx*, bry*: int

  # Another attribute
  prevWriteEndY: int

using
  gridio: Gridio
  ori: Orientation
  availSize: int
  tlx, tly, brx, bry: int
  stylish: Stylish

func width*(gridio): int =
  ## .fix() must be called for this to work properly
  return gridio.brx - gridio.tlx + 1
func height*(gridio): int =
  ## .fix() must be called for this to work properly
  return gridio.bry - gridio.tly + 1

func fix(gridio; ori; tlx; tly; brx; bry) =
  # Recursively calculates location
  # tlx/tly/brx/bry denote the BOUNDS

  gridio.tlx = tlx
  gridio.tly = tly

  if gridio.size.isNone:
    gridio.brx = brx
    gridio.bry = bry
  else:
    case ori
    of oVertical:
      let desiredBrx = tlx + gridio.size.unsafeGet - 1
      when compileOption("rangeChecks"):
        if desiredBrx > brx:
          raise RangeError.newException("Gridio out of bounds")
      gridio.brx = desiredBrx
      gridio.bry = bry
    of oHorizontal:
      let desiredBry = tly + gridio.size.unsafeGet - 1
      when compileOption("rangeChecks"):
        if desiredBry > bry:
          raise RangeError.newException("Gridio out of bounds")
      gridio.bry = desiredBry
      gridio.brx = brx

  # Guarantee that the next write will start at the top,
  # And the next clear will clear everything
  gridio.prevWriteEndY = gridio.bry

  var child_tlx = gridio.tlx
  var child_tly = gridio.tly
  var child_brx = gridio.brx
  var child_bry = gridio.bry

  let childFlexerCount = gridio.children.filter(c => c.size.isNone).len
  let fullSize =
    case gridio.childOrientation
    of oVertical: child_brx - child_tlx + 1
    of oHorizontal: child_bry - child_tly + 1
  let sizePerFlexer =
    if childFlexerCount == 0: 0
    else: (fullSize - (gridio.children.map(c => c.size.get(0) + 1).sum - 1)) div childFlexerCount

  case gridio.childOrientation
  of oVertical:
    for child in gridio.children.mitems:
      child_brx = child_tlx + child.size.get(sizePerFlexer) - 1
      child.fix(gridio.childOrientation, child_tlx, child_tly, child_brx, child_bry)
      child_tlx = child_brx + 2
  of oHorizontal:
    for child in gridio.children.mitems:
      child_bry = child_tly + child.size.get(sizePerFlexer) - 1
      child.fix(gridio.childOrientation, child_tlx, child_tly, child_brx, child_bry)
      child_tly = child_bry + 2

proc calculateOutline(gridio; mat: var seq[seq[bool]]) =
  # Calculate the outline for a gridio
  # Mutate a matrix of boolean values so that ``true`` represents that
  # the outline passes through that point
  for x in gridio.tlx - 1 .. gridio.brx + 1:
    mat[x][gridio.tly - 1] = true
    mat[x][gridio.bry + 1] = true
  for y in gridio.tly - 1 .. gridio.bry + 1:
    mat[gridio.tlx - 1][y] = true
    mat[gridio.brx + 1][y] = true

  for child in gridio.children.mitems:
    child.calculateOutline(mat)

func showCell(north, west, center, east, south: bool): string =
  if center == false:
    return " "
  return gfx_table[(north, east, south, west)]

proc writeBox(mat: seq[seq[bool]]; stylish) =
  template `{}`(s: seq[seq[bool]]; i, j: int): bool =
    if i < 0 or i >= s.len: false
    elif j < 0 or j >= s[i].len: false
    else: s[i][j]

  for x in 0 ..< mat.len:
    for y in 0 ..< mat[x].len:
      stdout.setCursorPos(x, y)
      writeStylish(
        showCell(
                         mat{x, y - 1},
          mat{x - 1, y}, mat{x, y    }, mat{x + 1, y},
                         mat{x, y + 1},
        ),
        stylish,
      )

proc drawOutline*(gridio; stylish = styleless) =
  ## Draw an outline of the gridio and its descendants to stdio.
  ## Call fix() first.
  # +2 for borders!
  var mat = newSeqWith(gridio.width + 2, newSeqWith(gridio.height + 2, false))
  gridio.calculateOutline(mat)
  writeBox(mat, stylish)
  stdout.flushFile

proc fix*(gridio) =
  ## Calculate the actual locations and sizes of the gridio and all
  ## child gridios. Should be called before any drawing happens.
  ## Should be called after any resizing.
  # Would expect 'em to be ``- 1``; dunno why it needs ``- 2``.
  gridio.fix(not gridio.childOrientation, 1, 1, terminalWidth() - 2, terminalHeight() - 2)

proc fix*(gridio; tlx, tly, brx, bry) =
  ## Fix gridio to terminal size
  # Adjust by 1 for borders
  gridio.fix(not gridio.childOrientation, tlx + 1, tly + 1, brx - 1, bry - 1)

func wrapY(gridio; y: int): int =
  result = y
  while result > gridio.bry:
    result -= gridio.height

func wordWrap(text: StylishString; width: int): seq[StylishString] =
  result = @[]
  var i = 0
  while i < text.len:
    result.add(text{i ..< i + width})
    i += width

proc clearLine*(gridio; y: int) =
  stdout.setCursorPos(gridio.tlx, y)
  stdout.write(" " * gridio.width)

proc clear*(gridio) =
  if gridio.writeStyle == wsRadar:
    for y in gridio.tly .. gridio.bry:
      gridio.clearLine(y)
  else:
    for y in gridio.tly .. gridio.prevWriteEndY:
      gridio.clearLine(y)
  gridio.prevWriteEndY = gridio.bry

proc writeLines(gridio; text: StylishString) =
  let lines = text.wordWrap(gridio.width)
  for i, line in lines:
    stdout.setCursorPos(gridio.tlx, gridio.wrapY(gridio.prevWriteEndY + 1 + i))
    writeStylish(line)
  stdout.flushFile
  gridio.prevWriteEndY = gridio.wrapY(gridio.prevWriteEndY + lines.len)

proc write*(gridio; text: StylishString) =
  if gridio.writeStyle == wsOverwrite:
    gridio.clear()
  if gridio.writeStyle == wsRadar:
    gridio.clearLine(gridio.wrapY(gridio.prevWriteEndY + 2))
  gridio.writeLines(text)

proc write*(gridio; text: string) =
  gridio.write(initStylishString(text))

template initImpl(name; orientation) =
  func name*(size: int, children: seq[Gridio] = @[]): Gridio =
    return Gridio(
      childOrientation: orientation,
      size: some(size),
      children: children,
    )
  func name*(children: seq[Gridio] = @[]): Gridio =
    return Gridio(
      childOrientation: orientation,
      size: none(int),
      children: children,
    )

initImpl(rows, oHorizontal)
initImpl(cols, oVertical)
# For boxes which will be used to display text and thus
# don't care about rows/cols because they will have
# no children, arbitrarily choose that they're rows.
initImpl(box, oHorizontal)

proc placeCursorAfter*(gridio) =
  ## May need to be called after all drawing is done
  ## Sets the cursor after the gridio so that the promp exiting does not
  ## overwrite it
  stdout.setCursorPos(0, gridio.bry + 2)

when isMainModule:
  let big = cols(45)

  let small = rows(30)
  let smol = box(20)
  let smol2 = box(20)

  let small2 = rows(50)
  let smol3 = box()
  let smol4 = box(10)
  small.children.add([smol, smol2])
  small2.children.add([smol3, smol4])
  big.children.add([small, small2])
  big.fix()
  big.drawOutline()

  big.write("hello!")
  smol3.write("goodbye!")

  smol3.writeStyle = wsRadar
  for i in 0 ..< 1000:
    smol3.write(withStyle($i, stylish(fgWhite, bgBlue, {styleBright})))

  placeCursorAfter(big)

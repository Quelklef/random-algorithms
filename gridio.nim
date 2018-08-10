import options
import sugar
import sequtils
import terminal

from util import sum, `*`

const
  # Directions always follow the order NESW;
  # each oriection is "gfx_NESW" with 0 or more
  # character removals
  gfx_NESW = "┼"

  gfx_ESW = "┬"
  gfx_NSW = "┤"
  gfx_NEW = "┴"
  gfx_NES = "├"

  gfx_NE = "└"
  gfx_NS = "│"
  gfx_NW = "┘"
  gfx_ES = "┌"
  gfx_EW = "─"
  gfx_SW = "┐"

# tlx/tly/brx/bry: (top|bottom)-(left|right) (x|y)

const noStyle: set[Style] = {}

proc writeBox(tlx, tly, brx, bry: int; style = noStyle) =
  let width = brx - tlx + 1

  stdout.setCursorPos(tlx, tly)
  writeStyled(
    gfx_ES & gfx_EW * (width - 2) & gfx_SW
    , style)

  for y in tly + 1 .. bry - 1:
    stdout.setCursorPos(tlx, y)
    writeStyled(gfx_NS, style)
    stdout.setCursorPos(brx, y)
    writeStyled(gfx_NS, style)

  stdout.setCursorPos(tlx, bry)
  writeStyled(
    gfx_NE & gfx_EW * (width - 2) & gfx_NW & "\n"
    , style)

type Orientation = enum
  oVertical
  oHorizontal

func `not`(o: Orientation): Orientation =
  case o
  of oVertical:
    return oHorizontal
  of oHorizontal:
    return oVertical

type Gridio = ref object
  childOrientation: Orientation
  # none() -> expand to available space
  # All boxes expand to available space in the oriection perpendicular
  # to their orientation (i.e. horizontal for oHorizontal and vertical for
  # oVertical)
  size: Option[int]
  children: seq[Gridio]

  # Calculated attributes
  tlx, tly, brx, bry: int

using
  gridio: Gridio
  ori: Orientation
  availSize: int

func fix(gridio; ori; tlx, tly, brx, bry: int) =
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

proc drawOutline*(gridio; style = noStyle) =
  writeBox(gridio.tlx - 1, gridio.tly - 1, gridio.brx + 1, gridio.bry + 1, style)
  for child in gridio.children.mitems:
    child.drawOutline(style)
  # Set the cursor because otherwise the prompt may overwrite what we've put
  stdout.setCursorPos(0, gridio.bry + 2)

proc fix*(gridio) =
  # Would expect it to be ``terminalWidth() - 1``; dunno why it needs ``- 2``.
  gridio.fix(not gridio.childOrientation, 1, 1, terminalWidth() - 2, terminalHeight() - 1)
proc fix*(gridio; tlx, tly, brx, bry: int) =
  # Adjust by 1 for borders
  gridio.fix(not gridio.childOrientation, tlx + 1, tly + 1, brx - 1, bry - 1)

func gridio(childOrientation: Orientation; size: Option[int]): Gridio =
  return Gridio(
    childOrientation: childOrientation,
    size: size,
    children: @[]
  )

func rows*(size: int): Gridio =
  return gridio(oHorizontal, some(size))
func rows*(): Gridio =
  return gridio(oHorizontal, none(int))

func cols*(size: int): Gridio =
  return gridio(oVertical, some(size))
func cols*(): Gridio =
  return gridio(oVertical, none(int))

# For boxes which will be used to display text and thus
# don't care about rows/cols because they will have
# no children, arbitrarily choose that they're rows.
func box*(size: int): Gridio =
  return rows(size)
func box*(): Gridio =
  return rows()

when isMainModule:
  let big = cols(50)

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

import options
import sugar
import sequtils
import terminal

from util import sum, `*`

const
  # Directions always follow the order NESW;
  # each direction is "gfx_NESW" with 0 or more
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

type BoxDir = enum
  bdColumns
  bdRows

func `not`(bd: BoxDir): BoxDir =
  case bd
  of bdColumns:
    return bdRows
  of bdRows:
    return bdColumns

type Gridio = ref object
  childAlignment: BoxDir
  # none() -> expand to available space
  # All boxes expand to available space in the direction perpendicular
  # to their orientation (i.e. horizontal for bdRows and vertical for
  # bdColumns)
  size: Option[int]
  children*: seq[Gridio]

using
  gridio: Gridio
  dir: BoxDir
  availSize: int

func flexes(gridio, dir): bool =
  # Will the gridio flex to take available space?
  return
    dir != gridio.childAlignment or
    gridio.size.isNone or
    gridio.children.any(c => flexes(c, gridio.childAlignment))

# The following two procs are mutually recursive
proc calculatedSize(gridio, dir, availSize): int
proc childrenAvailSizes(gridio, dir, availSize): seq[int] =
  let sizePerFlexer =
    ( availSize -
    gridio.children.map(c => c.size.get(0) + 1  # +1 for 1px border per child
                       ).sum + 1  # +1 for 1px border extre
    ) div gridio.children.filter(c => c.flexes(gridio.childAlignment)).len

  return gridio.children.map(
    child => child.calculatedSize(
      gridio.childAlignment,
      if child.flexes(gridio.childAlignment): sizePerFlexer else: child.size.unsafeGet
  ))
proc calculatedSize(gridio, dir, availSize): int =
  # 1+ / succ for borders
  if gridio.flexes(dir):
    return availSize

  return 1 + gridio.childrenAvailSizes(dir, availSize).map(x => succ(x)).sum

proc childOffsets(gridio: Gridio, dir: BoxDir, availSize: int): seq[int] =
  ## Ofset to drawing start WITH border
  if gridio.children.len == 0:
    return @[]

  var offset = 0
  result = @[]
  for i, ch in gridio.children:
    result.add(offset)
    # TODO: This line has TERRIBLE complexity
    # calculatedSize() should be memoized
    offset += ch.calculatedSize(gridio.childAlignment, gridio.childrenAvailSizes(dir, availSize)[i]) + 1  # +1 for 1px border per child

const noStyle: set[Style] = {}

proc writeBox(tlx, tly, brx, bry: int, style = noStyle) =
  # tlx/tly/brx/bry: (top|bottom)-(left|right) (x|y)
  let width = brx - tlx

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

proc drawWireframe(gridio: Gridio, dir: BoxDir, availWidth, availHeight, offsetX, offsetY: int, style = noStyle) =
  let availSize =
    case gridio.childAlignment
    of bdRows: availHeight
    of bdColumns: availWidth
  let size = gridio.calculatedSize(dir, availSize)

  case gridio.childAlignment
  of bdRows:
    writeBox(offsetX, offsetY, offsetX + availWidth, offsetY + size      )
  of bdColumns:
    writeBox(offsetX, offsetY, offsetX + size      , offsetY + availWidth)

  ## TODO: Recur onto children

proc drawWireframe(gridio: Gridio, style = noStyle) =
  # TODO: Center gridio in middle of screen
  gridio.drawWireframe(not gridio.childAlignment, terminalWidth(), terminalHeight(), 0, 0, style)

func gridio(ca: BoxDir, size: Option[int]): Gridio =
  return Gridio(
    childAlignment: ca,
    size: size,
    children: @[]
  )

func rows*(size: int): Gridio =
  return gridio(bdRows, some(size))
func rows*(): Gridio =
  return gridio(bdRows, none(int))

func cols*(size: int): Gridio =
  return gridio(bdColumns, some(size))
func cols*(): Gridio =
  return gridio(bdColumns, none(int))

when isMainModule:
  let smolBox = cols(10)
  let bigBox = rows(50)
  bigBox.children.add(smolBox)
  bigBox.drawWireframe()

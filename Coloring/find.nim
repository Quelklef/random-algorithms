import coloring
from ../util import times

proc hasMMP*(coloring, mask: Coloring): bool =
  ## MMP stands for Mask Monochromatic Position
  ## Given the coloring & a mask, can the mask be placed in some position so that the
  ## colors designated by the mask are monochromatic?
  ## The mask should be as large or smaller than the coloring.
  var fullMask = initColoring(2, coloring.N) or mask
  (coloring.N - mask.N + 1).times:
    if coloring.homogenous(fullMask):
      return true
    fullMask.shiftRight()
  return false

proc hasMMP_progression*(coloring: Coloring; maskGen: proc(d: int): Coloring): bool =
  ## Iterate through the masks given by ``maskGen`` for ``d`` from ``1`` onward
  ## until the mask is too large
  var d = 1
  while true:
    let mask = maskGen(d)
    d += 1
    if mask.N > coloring.N:
      return false
    if coloring.hasMMP(mask):
      return true

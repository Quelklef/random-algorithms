import options
import hashes
import sets
import tables

import coloring

iterator skip*[T](a, step: T, n: int): T =
  ## Yield a, a + T, a + 2T, etc., n times
  var x = a
  for _ in 0 ..< n:
    yield x
    x += step

func hasMMP*[C](coloring: Coloring[C], mask: Coloring[2]): bool =
  ## MMP stands for Mask Monochromatic Position
  ## Given the coloring & a mask, can the mask be placed in some position so that the
  ## colors designated by the mask are monochromatic?
  ## The mask should be as large or smaller than the coloring.
  var fullMask = initColoring(2, coloring.N) or mask
  (coloring.N - mask.N + 1).times:
    if coloring.homogenous(fullMask):
      return true
    fullMask >>= 1
  return false

func hasMMP_progression*[C](coloring: Coloring[C]; maskGen: proc(d: int): Coloring[2]): bool =
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

proc find_noMMP_coloring_progressive*(C: static[int], N: int, maskGen: proc(d: int): Coloring[2]): tuple[flipCount: int, coloring: Coloring[C]] =
  var col = initColoring(C, N)
  var flips = 0

  while true:
    col.randomize()
    inc(flips)

    if not col.hasMMP_progression(maskGen):
      return (flipCount: flips, coloring: col)


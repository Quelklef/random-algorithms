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

func has_MAS_correct*[C](coloring: Coloring[C], K: range[2 .. int.high]): bool =
  # Slow but almost certainly correct has_MAS implementation
  for stepSize in 1 .. (coloring.N - 1) div (K - 1):
    for startLoc in 0 .. coloring.N - (K - 1) * stepSize - 1:
      block skipping:
        let expectedColor = coloring[startLoc] # The expected coloringor for the sequence
        for i in skip(startLoc + stepSize, stepSize, K - 1):
          if coloring[i] != expectedColor:
            break skipping # Go to next start loc
        return true
  return false

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

func has_MAS*[C](coloring: Coloring[C], K: range[2 .. int.high]): bool =
  for stepSize in 1 .. (coloring.N - 1) div (K - 1):
    var mask = initColoring(2, (K - 1) * stepSize + 1)
    for i in skip(0, stepSize, K):
      mask[i] = 1
    if coloring.hasMMP(mask):
      return true
  return false

proc find_noMAS_coloring*(C: static[int], N, K: int): tuple[flipCount: int, coloring: Coloring[C]] =
  var col = initColoring(C, N)
  var flips = 0

  while true:
    col.randomize()
    inc(flips)

    if not col.has_MAS(K):
      return (flipCount: flips, coloring: col)

proc find_noMMP_coloring*(C: static[int], N: int, mask: Coloring[2]): tuple[flipCount: int, coloring: Coloring[C]] =
  var col = initColoring(C, N)
  var flips = 0

  while col.hasMMP(mask):
    col.randomize()
    inc(flips)

  return (flipCount: flips, coloring: col)

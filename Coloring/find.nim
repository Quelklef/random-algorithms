
import options

import coloring

iterator skip*[T](a, step: T, n: int): T =
  ## Yield a, a + T, a + 2T, etc., n times
  var x = a
  for _ in 0 ..< n:
    yield x
    x += step

when not defined(provisional):
  func has_MAS*[C](coloring: Coloring[C], K: int): bool =
    ## Find monochromatic arithmetic subseq of size K
    # Iterate over step sizes, which is the distance between each item in the MAS
    for stepSize in 1 .. (coloring.N - 1) div (K - 1):
      for startLoc in 0 .. coloring.N - (K - 1) * stepSize - 1:
        block skipping:
          let expectedColor = coloring[startLoc] # The expected coloringor for the sequence
          for i in skip(startLoc + stepSize, stepSize, K - 1):
            if coloring[i] != expectedColor:
              break skipping # Go to next start loc
          return true
    return false
else:
  func has_MAS*[C](coloring: Coloring[C], K: int): bool =
    for stepSize in 1 .. (coloring.N - 1) div (K - 1):
      var mask = initColoring(2, coloring.N)
      for i in skip(0, stepSize, K):
        mask[i] = 1
      for startLoc in 0 .. coloring.N - (K - 1) * stepSize - 1:
        mask >>= 1
        if coloring.homogenous(mask):
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

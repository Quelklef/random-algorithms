import options
import hashes

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

when defined(provisional):
  func has_MAS_pure*[C](coloring: Coloring[C], K: range[2 .. int.high], known: Natural = 0): bool =
    ## Find monochromatic arithmetic subseq of size K
    ## If `known` is given, assumes that there exists no MAS in the first `known` colors
    for stepSize in 1 .. (coloring.N - 1) div (K - 1):
      var mask = initColoring(2, coloring.N)
      for i in skip(coloring.N - 1, -stepSize, K):
        mask[i] = 1

      min(coloring.N - known, coloring.N - (K - 1) * stepSize).times:
        if coloring.homogenous(mask):
          return true
        mask <<= 1
    return false

  import tables

  # knownValues[(N, K)][Coloring] = has_MAS
  # TODO: Support C != 2  (how??)
  var knownValues = newTable[(int, int), TableRef[Coloring[2], bool]]()

  proc has_MAS*[C: static[int]](coloring: Coloring[C], K: int): bool =
    static: assert C == 2
    let NK = (coloring.N, K)
    if NK notin knownValues:
      knownValues[NK] = newTable[Coloring[2], bool]()

    if coloring in knownValues[NK]:
      return knownValues[NK][coloring]

    block returnn:
      if coloring.N <= 1:
        # Cannot do fancy algorithm unless N >= 2
        result = has_MAS_pure(coloring, K)
      else:
        var child = coloring
        while child.N >= 1:
          child.resize(child.N - 1)
          let CNK = (child.N, K)
          if CNK in knownValues and child in knownValues[CNK]:
            result = knownValues[CNK][child] or has_MAS_pure(coloring, K, child.N)
            break returnn
        result = has_MAS_pure(coloring, K)

    knownValues[NK][coloring] = result

else:
  func has_MAS*[C](coloring: Coloring[C], K: range[2 .. int.high]): bool =
    ## Find monochromatic arithmetic subseq of size K
    # Iterate over step sizes, which is the distance between each item in the MAS
    for stepSize in 1 .. (coloring.N - 1) div (K - 1):
      var mask = initColoring(2, coloring.N)
      for i in skip(0, stepSize, K):
        mask[i] = 1
      (coloring.N - (K - 1) * stepSize).times:
        if coloring.homogenous(mask):
          return true
        mask >>= 1
    return false

proc find_noMAS_coloring*(C: static[int], N, K: int): tuple[flipCount: int, coloring: Coloring[C]] =
  var col = initColoring(C, N)
  var flips = 0

  while true:
    col.randomize()
    inc(flips)

    if not col.has_MAS(K):
      return (flipCount: flips, coloring: col)

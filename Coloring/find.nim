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

  type ColoringPartialSet[C: static[int]] = ref object
    ## Allows inclusion like a set
    ## The `contains` method is special.
    ## It guarantees the following and ONLY the following:
    ## ``s.contains(x)`` implies that there exists some
    ## continuous subsequence of ``x`` which has been
    ## included in ``s``.
    ## (Why is this useful? Because if you only add
    ## colorings which have a MAS to ``s``, then
    ## ``x in s`` implies ``has_MAS(x)``.)
    included: bool
    branches: array[C, ColoringPartialSet[C]]

  func initColoringPartialSet[C](): ColoringPartialSet[C] =
    new(result)

  func incl[C](s: ColoringPartialSet[C], x: Coloring[C]) =
    var s = s
    for color in x:
      if s.branches[color].isNil:
        s.branches[color] = initColoringPartialSet[C]()
      s = s.branches[color]
    s.included = true

  func contains[C](s: ColoringPartialSet[C], x: Coloring[C]): bool =
    var s = s
    if s.isNil: return false
    if s.included: return true
    for color in x:
      s = s.branches[color]
      if s.isNil: return false
      if s.included: return true

  # knownValues[K][Coloring] = has_MAS
  # TODO: Support C != 2  (how??)
  var knownHasMAS = newTable[int, ColoringPartialSet[2]]()

  proc has_MAS*[C: static[int]](coloring: Coloring[C], K: int): bool =
    static: assert C == 2

    if K notin knownHasMAS:
      knownHasMAS[K] = initColoringPartialSet[2]()
    let s = knownHasMAS[K]

    let has = coloring in s
    if has:
      return true

    result = has_MAS_pure(coloring, K)
    if result:
      knownHasMAS[K].incl(coloring)

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

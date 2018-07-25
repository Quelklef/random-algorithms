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
  func has_MAS_pure*[C](coloring: Coloring[C], K: range[2 .. int.high], known: Natural): bool =
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

  func has_MAS_pure*[C](coloring: Coloring[C], K: range[2 .. int.high]): bool =
    ## Find monochromatic arithmetic subseq of size K
    ## If `known` is given, assumes that there exists no MAS in the first `known` colors
    for stepSize in 1 .. (coloring.N - 1) div (K - 1):
      var mask = initColoring(2, coloring.N)
      for i in skip(coloring.N - 1, -stepSize, K):
        mask[i] = 1

      (coloring.N - (K - 1) * stepSize).times:
        if coloring.homogenous(mask):
          return true
        mask <<= 1
    return false

  type ColoringMagic[C: static[int]] = ref object
    known: bool
    hasMAS: bool
    branches: array[C, ColoringMagic[C]]

  func newColoringMagic[C](): ColoringMagic[C] =
    new(result)

  func know[C](cm: ColoringMagic[C], x: Coloring[C], hasMAS: bool) =
    var cm = cm
    for color in x:
      if cm.branches[color].isNil:
        cm.branches[color] = newColoringMagic[C]()
      cm = cm.branches[color]
    cm.known = true
    cm.hasMAS = hasMAS

  func lookup[C](cm: ColoringMagic[C], x: Coloring[C]): tuple[pathLen: int, found: bool, hasMAS: bool] =
    var cm = cm
    template logic(pathLen) {.dirty.} =
      if cm.isNil:
        return (0, false, false)
      if cm.known:
        if cm.hasMAS:
          return (0, true, true)
        else:
          result = (pathLen, true, false)

    logic(0)
    for i, color in x:
      cm = cm.branches[color]
      logic(i + 1)

  # knownValues[K][Coloring] = has_MAS
  # TODO: Support C != 2  (how??)
  # TODO: Support multiple Ks
  #       Current implementation assumes one K is only ever used
  var cms: seq[ColoringMagic[2]] = @[]
  proc has_MAS*[C: static[int]](coloring: Coloring[C], K: int): bool =
    static: assert C == 2

    while K >= cms.len:
      cms.add(newColoringMagic[2]())
    let cm = cms[K]

    let (pathLen, found, hasMAS) = cm.lookup(coloring)
    if found:
      if hasMAS:
        return true
      result = has_MAS_pure(coloring, K, pathLen)
    else:
      result = has_MAS_pure(coloring, K)

    cm.know(coloring, result)

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

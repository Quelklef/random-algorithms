import hashes
import macros
import strutils

import coloringType
import twoColoring
import nColoring

export coloringType
export twoColoring
export nColoring

proc initColoring*(C, N: int): Coloring =
  if C == 2:
    return initTwoColoring(N)
  else:
    return initNColoring(C, N)

iterator items*(col: Coloring): int =
  for i in 0 ..< col.N:
    yield col[i]

iterator pairs*(col: Coloring): (int, int) =
  for i in 0 ..< col.N:
    yield (i, col[i])

proc initColoring*(C: int, s: string): Coloring =
  result = initColoring(C, s.len)
  for i, c in s:
    result[i] = ord(c) - ord('0')

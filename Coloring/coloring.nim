import macros
import strutils

import twoColoring
export twoColoring

proc initColoring*(C, N: int): Coloring =
  assert(C == 2)
  return initTwoColoring(N)

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

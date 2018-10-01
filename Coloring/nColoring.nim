import strutils
import sequtils
import math
import hashes
import random

#[
# NOTE:
# Since this module is not currenly used, consider it a dummy
# Most usage of this module will not even compile
]#

import coloringType

random.randomize()

type NColoring* = ref object of Coloring
  data: seq[int]

proc N*(col: NColoring): int =
  return col.data.len

proc initNColoring*(C, N: int): NColoring =
  assert(C != 2)
  result.data = @[]
  result.C = C
  for _ in 1..N:
    result.data.add(0)

proc `[]`*(col: NColoring, i: int): int =
  return col.data[i]

proc `[]=`*(col: var NColoring, i: int, val: int): void =
  col.data[i] = val

iterator items*(col: NColoring): int =
  for item in col.data:
    yield item

proc `+=`*(col: var NColoring, amt: int) =
  var overflow = amt
  for n in 0 ..< col.N:
    if overflow == 0:
      return

    let X = col[n] + overflow
    col.data[n] = X mod col.C
    overflow = X div col.C

proc `$`*(col: NColoring): string =
  assert(col.C <= 9)
  result = ""
  for item in col:
    result &= $item

proc randomize*(col: var NColoring): void =
  for i in 0 ..< col.N:
    col[i] = rand(col.C - 1)

proc extend*(col: var NColoring, amt: int): void =
  for _ in 0 ..< amt:
    col.data.add(0)

when isMainModule:
  var nc = initNColoring(4, 100)
  nc.randomize()

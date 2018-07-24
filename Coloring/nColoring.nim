import strutils
import sequtils
import math
import hashes
import random

import coloringDef

func N*[C](col: Coloring[C]): int =
  return col.data.len

func initColoring*(C: static[int], N: int): Coloring[C] =
  static: assert C != 2
  result.data = @[]
  for _ in 1..N:
    result.data.add(0)

func `[]`*[C](col: Coloring[C], i: int): range[0 .. C - 1] =
  return col.data[i]

func `[]=`*[C](col: var Coloring[C], i: int, val: range[0 .. C - 1]): void =
  col.data[i] = val

func `+=`*[C](col: var Coloring[C], amt: uint64) =
  var overflow = amt
  for n in 0 ..< col.N:
    if overflow == 0:
      return

    let X = cast[uint64](col[n]) + overflow
    col[n] = X mod C
    overflow = X div C

func `$`*[C](col: Coloring[C]): string =
  static: assert C <= 9
  result = ""
  for item in col:
    result &= $item

func randomize*[C](col: var Coloring[C]): void =
  for i in 0 ..< col.N:
    col[i] = rand(C - 1)

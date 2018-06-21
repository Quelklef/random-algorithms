
import strutils
import sequtils
import math
import hashes
import random

random.randomize()

type NColoring*[C: static[int]] = object
    N*: int
    data: seq[range[0 .. C - 1]]

proc initNColoring*(C: static[int], N: int): NColoring[C] =
    static: assert C != 2
    result.N = N
    result.data = @[]
    for _ in 1..N:
        result.data.add(0)

proc `[]`*[C](col: NColoring[C], i: int): range[0 .. C - 1] =
    return col.data[i]

proc `[]=`*[C](col: var NColoring[C], i: int, val: range[0 .. C - 1]): void =
    col.data[i] = val

iterator items*[C](col: NColoring[C]): range[0 .. C - 1] =
    for item in col.data:
        yield item

proc `+=`*[C](col: var NColoring[C], amt: uint64) =
    var overflow = amt
    for n in 0 ..< col.N:
        if overflow == 0:
            return

        let X = cast[uint64](col[n]) + overflow
        col[n] = X mod C
        overflow = X div C

proc `$`*[C](col: NColoring[C]): string =
    static: assert C <= 9
    result = ""
    for item in col:
        result &= $item

proc randomize*[C](col: var NColoring[C]): void =
    for i in 0 ..< col.N:
        col[i] = rand(C - 1)


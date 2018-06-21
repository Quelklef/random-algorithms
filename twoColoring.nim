
import strutils
import math
import hashes
import random

random.randomize()
var localRand = initRand(rand(int.high))
proc randu64(): uint64 =
    return localRand.next()

template high[T: uint64](t: typedesc[T]): uint64 = 18446744073709551615'u64
template low[T: uint64](t: typedesc[T]): uint64 = 0'u64

proc iceil(x: float32): int = return int(x.ceil)
proc iceil(x: float64): int = return int(x.ceil)

type TwoColoring* = object
    N: int  # Size of coloring
    data: seq[uint64]

proc initTwoColoring*(N: int): TwoColoring =
    result.N = N
    result.data = @[]
    for _ in 0 .. (N div 64):
        result.data.add(0'u64)

proc `==`*(colA, colB: TwoColoring): bool =
    if colA.N != colB.N:
        return false

    for i in 0 ..< colA.data.len - 1:
        if colA.data[i] != colB.data[i]:
            return false

    let tailSize = (colA.data.len * 64) mod colA.N
    let numIgnoreFromTail = 64 - tailSize
    return (colA.data[colA.data.len - 1]) shr numIgnoreFromTail ==
           (colB.data[colA.data.len - 1]) shr numIgnoreFromTail

proc `[]`*(col: TwoColoring, i: int): range[0 .. 1]
proc `$`*(col: TwoColoring): string =
    result = ""
    for i in 0 ..< col.N:
        # TODO: Optimize? `&=` is perhaps slow?
        result &= $col[i]

proc `[]`*(col: TwoColoring, i: int): range[0 .. 1] =
    return 1'u64 and (col.data[i div 64] shr (i mod 64))

proc `[]=`*(col: var TwoColoring, i: int, val: range[0 .. 1]) =
    if val == 1:
        col.data[i div 64] = col.data[i div 64] or      (1'u64 shl (i mod 64))
    else: # val == 0
        col.data[i div 64] = col.data[i div 64] and not (1'u64 shl (i mod 64))

proc `+=`*(col: var TwoColoring, amt: uint64) =
    col.data[0] += amt
    if col.data.len > 1:
        col.data[1] += (col.data[0] < amt).uint64

proc randomize*(col: var TwoColoring): void =
    ## Randomize a two-coloring
    for i in 0 ..< col.data.len:
        col.data[i] = randu64()

proc hash*(col: TwoColoring): Hash =
    # TODO: Disregard out-of-bound bits
    for ui in col.data:
        result = result !& hash(ui)
    result = !$result

when isMainModule:
    var col0 = initTwoColoring(5)
    var col1 = initTwoColoring(5)

    col0.randomize()
    col1.randomize()

    echo col0
    echo col1

    # Should give out-of-bounds but doesn't
    col0[5] = 1
    col0[6] = 1

    for i in 0..4:
        col0[i] = 0
        col1[i] = 0

    echo col0
    echo col1
    echo col0 == col1

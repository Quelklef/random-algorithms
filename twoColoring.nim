
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

proc `==`*(col0, col1: TwoColoring): bool =
    if col0.N != col1.N:
        return false

    for i in 0 ..< col0.data.len - 1:
        if col0.data[i] != col1.data[i]:
            return false

    let numIgnoreFromTail = (64 - (col0.N mod 64))
    return (col0.data[col0.data.len - 1]) shl numIgnoreFromTail ==
           (col1.data[col0.data.len - 1]) shl numIgnoreFromTail

proc `[]`*(col: TwoColoring, i: int): range[0 .. 1]
proc `$`*(col: TwoColoring): string =
    result = ""
    for i in 0 ..< col.N:
        result.add($col[i[)

proc `[]`*(col: TwoColoring, i: int): range[0 .. 1] =
    if i >= col.N:
        raise newException(IndexError, "Index $# out of bounds" % $i)
    return 1'u64 and (col.data[i div 64] shr (i mod 64))

proc `[]=`*(col: var TwoColoring, i: int, val: range[0 .. 1]) =
    if i >= col.N:
        raise newException(IndexError, "Index $# out of bounds" % $i)
    if val == 1:
        col.data[i div 64] = col.data[i div 64] or      (1'u64 shl (i mod 64))
    else: # val == 0
        col.data[i div 64] = col.data[i div 64] and not (1'u64 shl (i mod 64))

proc `+=`*(col: var TwoColoring, amt: uint64) =
    ## May overflow
    col.data[0] += amt
    if col.data.len > 1:
        col.data[1] += (col.data[0] < amt).uint64

proc randomize*(col: var TwoColoring): void =
    ## Randomize a two-coloring
    for i in 0 ..< col.data.len:
        col.data[i] = randu64()


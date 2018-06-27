
import strutils
import math
import hashes
import random

from misc import rand_u64

template high[T: uint64](t: typedesc[T]): uint64 = 18446744073709551615'u64
template low[T: uint64](t: typedesc[T]): uint64 = 0'u64

func ceildiv(x, y: int): int =
    ## Like `x div y` but instead of being eq to floor(x/y), is eq to ceil(x/y)
    result = x div y
    if x mod y != 0: result.inc

type TwoColoring* = object
    N*: int  # Size of coloring
    data*: seq[uint64]

proc initTwoColoring*(N: int): TwoColoring =
    result.N = N
    result.data = @[]
    for _ in 1 .. ceildiv(N, 64):
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
        result.add($col[i])

proc `{}`(col: TwoColoring, i: int): range[0 .. 1] =
    return 1'u64 and (col.data[i div 64] shr (i mod 64))

proc `{}=`(col: var TwoColoring, i: int, val: range[0 .. 1]) =
    if val == 1:
        col.data[i div 64] = col.data[i div 64] or      (1'u64 shl (i mod 64))
    else: # val == 0
        col.data[i div 64] = col.data[i div 64] and not (1'u64 shl (i mod 64))

proc `[]`*(col: TwoColoring, i: int): range[0 .. 1] =
    if i >= col.N:
        raise newException(IndexError, "Index $# out of bounds" % $i)
    return col{i}

proc `[]=`*(col: var TwoColoring, i: int, val: range[0 .. 1]) =
    if i >= col.N:
        raise newException(IndexError, "Index $# out of bounds" % $i)
    col{i} = val

proc `+=`*(col: var TwoColoring, amt: uint64) =
    ## May overflow
    col.data[0] += amt
    if col.data.len > 1:
        col.data[1] += (col.data[0] < amt).uint64

proc randomize*(col: var TwoColoring): void =
    ## Randomize a two-coloring
    for i in 0 ..< col.data.len:
        col.data[i] = rand_u64()

proc extend*(col: var TwoColoring, amt: int): void =
    ## Extend the coloring by the given amount

    # TODO this can be slightly faster, but it's not worth the effort rn
    # First, reset the bits that are going to be exposed
    # i.e. already exist in col.data but aren't yet in
    # bounds
    let numToExpose = min(col.data.len * 64 - col.N, amt)
    for i in 0 ..< numToExpose:
        col{col.N + i} = 0

    # How many more uints are we going to need?
    let needed_uint_c = ceildiv(col.N + amt, 64) - col.data.len
    for _ in 0 ..< needed_uint_c:
        col.data.add(0'u64)

    col.N += amt

proc fromString*(val: string): TwoColoring =
    result = initTwoColoring(val.len)
    for index, chr in val:
        result[index] = ord(chr) - ord('0')


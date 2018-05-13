
import strutils
import math

template high[T: uint64](t: typedesc[T]): uint64 = 18446744073709551615'u64
template low[T: uint64](t: typedesc[T]): uint64 = 0'u64

proc iceil(x: float32): int = return int(x.ceil)
proc iceil(x: float64): int = return int(x.ceil)

type TwoColoring*[S: static[int]] = distinct array[iceil(S / 64), uint64]
template K[S](col: TwoColoring[S]): int = iceil(S / 64) # The number of contained uint64s

template uints[S](col: TwoColoring[S]): auto =
    ## Allow for access of underlying uints
    cast[array[K(col), uint64]](col)
template muints[S](col: TwoColoring[S]): auto =
    ## Allow for mutation of underlying uints
    array[K(col), uint64](col)

proc `$`[S](col: TwoColoring[S], on = "1", off = "0"): string =
    result = ""
    var isfirst = true
    for i, ui in uints(col):
        if isfirst:
            isfirst = false
        else:
            result &= ":"
        for dig in 0 ..< 64:
            if i * 64 + dig >= S:
                break
            result &= (if 1'u64 == ((ui shr dig) and 1): on else: off)

proc initTwoColoring*[S: static[int]](): TwoColoring[S] =
    discard

proc `[]`*[S](col: TwoColoring[S], i: range[0 .. S - 1]): range[0 .. 1] =
    return col.uints[i div 64] shr (i mod 64)

proc `[]=`*[S](col: var TwoColoring[S], i: range[0 .. S - 1], val: range[0 .. 1]) =
    if val == 1:
        col.muints[i div 64] = col.uints[i div 64] or      (1'u64 shl (i mod 64))
    else: # val == 0
        col.muints[i div 64] = col.uints[i div 64] and not (1'u64 shl (i mod 64))

proc `+=`*[S](col: var TwoColoring[S], amt: uint64) =
    var overflow = amt
    for i in 0 ..< K(col):
        let prev = col.uints[i]
        col.muints[i] += overflow  # Mutating uint64 so can't use col{0}
        if overflow > uint64.high - prev: # If overflowed
            overflow = 1
        else:
            break


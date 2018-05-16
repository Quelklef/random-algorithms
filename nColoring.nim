
import strutils
import sequtils
import math
import hashes

# TODO: Make distinct?
type NColoring*[C, S: static[int]] = array[S, range[0 .. C - 1]]

proc `+=`*[C, S](col: var NColoring[C, S], amt: uint64) =
    var overflow = amt
    for n in 0 ..< S:
        if overflow == 0:
            return

        let X = cast[uint64](col[n]) + overflow
        col[n] = X mod C
        overflow = X div C

proc `$`*[C, S](col: NColoring[C, S]): string =
    assert(C <= 9)
    result = ""
    for item in col:
        result &= $item

proc hash*[C, S](col: NColoring[C, S]): Hash =
    assert false # unimplemented, fuckers


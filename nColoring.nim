
import strutils
import sequtils
import math

# TODO: Make distinct?
type NColoring*[C, S: static[int]] = array[S, range[0 .. C - 1]]

proc initNColoring*[C, S](): NColoring[C, S] =
    discard

proc `+=`*[C, S](col: var NColoring[C, S], amt: int) =
    var overflow = amt
    for n in 0 ..< S:
        if overflow == 0:
            return

        let X = col[n] + overflow
        col[n] = X mod C
        overflow = X div C

proc `$`*[C, S](col: NColoring[C, S]): string =
    assert(C <= 9)
    result = ""
    for item in col:
        result &= $item


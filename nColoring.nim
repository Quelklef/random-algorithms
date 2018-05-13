
import strutils
import sequtils
import math

type Coloring*[C, S: static[int]] = array[S, range[0 .. C - 1]]

proc initColoring*[C, S](): Coloring[C, S] =
    discard

proc `+=`*[C, S](col: var Coloring[C, S], amt: int) =
    # TODO: Should be able to return before completing full loop
    var overflow = amt
    for n in 0 ..< S:
        if overflow == 0:
            return

        let X = col[n] + overflow
        col[n] = X mod C
        overflow = X div C

proc `$`*[C, S](col: Coloring[C, S]): string =
    assert(C <= 9)
    result = ""
    for item in col:
        result &= $item


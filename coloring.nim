
import strutils
import sequtils
import math

type Coloring*[C: enum, S: static[int]] = array[S, C]

proc initColoring[C: enum, S: static[int]](): Coloring[C, S] =
    var res: array[S, C]
    return Coloring[C, S](res)

proc `+=`*[C: enum, S: static[int]](col: var Coloring[C, S], amt: int) =
    const count = C.high.ord + 1
    var overflow = amt
    for n in 0 ..< S:
        let val = col[n].ord
        col[n] = C((val + overflow) mod count)
        overflow = (val + overflow) div count

proc `$`*[C: enum, S: static[int]](col: Coloring[C, S]): string =
    result = "col["
    when S > 0:
        result &= $col[0]
    when S > 1:
        for item in col[1 ..< S]:
            result &= ", " & $item
    result &= "]"



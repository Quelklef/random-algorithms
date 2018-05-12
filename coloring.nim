
import strutils
import sequtils
import math

# Compile-time symbol `noTwoColorOptim` may be used to disable
# two-color optimizations

type Coloring*[C: enum, S: static[int]] = array[S, C]

proc initColoring*[C: enum, S: static[int]](): Coloring[C, S] =
    var res: array[S, C]
    return Coloring[C, S](res)

proc `+=`*[C: enum, S: static[int]](col: var Coloring[C, S], amt: int) =
    when C.high.ord == 1 and not defined(noTwoColorOptim): # two-colorings
        var overflow = false
        for n in 0 ..< S:
            let s = ((amt shr n) and 1) + cast[int](overflow) + col[n].ord
            col[n] = C(s mod 2)
            overflow = s >= 2
    else:
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


when isMainModule:
    import bmark

    type Col = enum c0, c1
    const len = 16 # Length of sequence
    var col = initColoring[Col, len]()

    let incsizes = toSeq(1 .. 2^len)
    let inccounts = incsizes.map(proc(incsize: int): int = return ((2^len) div incsize))
    benchmark("two-coloring", trials = 100):
        for i, incsize in incsizes:
            # Test incrementing with all values from 1 to 2^len, which is an instant overflow
            for _ in 0 ..< inccounts[i]:
                # Increment enough times for overflow
                col += incsize
            # At end, reset
            for i in 0 ..< len:
                col[i] = c0


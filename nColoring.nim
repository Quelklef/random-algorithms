
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
    # TODO: Should be able to return before completing full loop
    when C.high.ord == 1 and not defined(noTwoColorOptim): # two-colorings
        var overflow = false
        for n in 0 ..< S:
            let s = ((amt shr n) and 1) + cast[int](overflow) + col[n].ord
            col[n] = cast[C](s == 1 or s == 3)
            overflow = s > 1
    else:
        const count = C.high.ord + 1
        var overflow = amt
        for n in 0 ..< S:
            let val = col[n].ord
            col[n] = cast[C]((val + overflow) mod count)
            overflow = (val + overflow) div count

proc increment*[C: enum, S: static[int]](col: var Coloring[C, S]) =
    ## Functionally equivalent to `+= 1`, but significantly faster
    when C.high.ord == 1 and not defined(noTwoColorOptim): # two-colorings
        for n in 0 ..< S:
            col[n] = cast[C](not cast[bool](col[n]))
            if cast[bool](col[n]): return
    else:
        for n in 0 ..< S:
            if col[n] == C.high:
                col[n] = C.low
            else:
                col[n].inc
                return

proc `$`*[C: enum, S: static[int]](col: Coloring[C, S]): string =
    result = "col["
    when S > 0:
        result &= $col[0]
    when S > 1:
        for item in col[1 ..< S]:
            result &= ", " & $item
    result &= "]"


when isMainModule:
    import benchmark

    type TC = enum tce0, tce1
    const s = 16
    const trials = 1000

    var tc0 = 0.uint64
    var tc1 = initColoring[TC, s]()

    benchmark("uint64", trials = trials):
        discard
    do:
        for _ in 0 ..< 2^s:
            tc0 += 3
    do:
        tc0 = 0.uint64

    benchmark("coloring", trials = trials):
        discard
    do:
        for _ in 0 ..< 2^s:
            tc1 += 3
    do:
        for i in 0 ..< s:
            tc1[i] = tce0



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
            col[n] = cast[C](s == 1 or s == 3)
            overflow = s > 1
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
    type TwoCol = enum c0, c1
    const len = 16 # Length of sequence
    var twocol = initColoring[TwoCol, len]()

    # First, verify that behavior is correct
    import random
    randomize()

    var comp: uint64 = 0
    for _ in 0 ..< 1000:
        let val = rand(2^len)
        comp += val.uint64
        twocol += val

        # Assert that `comp` and `twoocol` match
        for i in 0 ..< len:
            assert(((comp shr i) and 1) == twocol[i].ord.uint64)
    
    # Then, benchmark
    import bmark

    let incsizes = toSeq(1 .. 2^len)
    let inccounts = incsizes.map(proc(incsize: int): int = return ((2^len) div incsize))

    benchmark("two-coloring", trials = 20):
        discard
    do:
        for i, incsize in incsizes:
            # Test incrementing with all values from 1 to 2^len, which is an instant overflow
            for _ in 0 ..< inccounts[i]:
                # Increment enough times for overflow
                twocol += incsize
    do:
        for i in 0 ..< len:
            twocol[i] = c0



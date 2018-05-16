
import math
import strutils

import coloring

proc clear*[C, S](col: var Coloring[C, S]) =
    # TODO: Should be implemented per-implementation
    for i in 0 ..< S:
        col[i] = 0

iterator skip[T](a, step: T, n: int): T =
    ## Yield a, a + T, a + 2T, etc., n times
    var x = a
    for _ in 0 ..< n:
        yield x
        x += step

proc cmas*[C, S](coloring: Coloring[C, S], K: int): bool =
    ## Contains monochromatic arithmetic subseq of size K
    var col = coloring
    for padSize in 0 .. (S - C) div (K - 1):
        for startLoc in 0 .. S - 1 - K - (K - 1) * padSize:
            block skipping:
                let expectedColor = col[startLoc] # The expected color for the sequence
                for i in skip(startLoc + padSize + 1, padSize + 1, K - 1):
                    if col[i] != expectedColor:
                        break skipping # Go to next start loc
                return true
    return false

when isMainModule:
    import benchmark

    const len = 20

    const minK = 8
    for K in minK .. len:
        var color = initColoring[2, len]()

        benchmark("K = $#" % $K, trials = 1):
            discard
        do:
            var count = 0
            for _ in 0 ..< 2^(len-1): # Only have to do half b.c after half are rotational repeats
                if not cmas(color, K):
                    count.inc
                color += 1
            count *= 2

            echo("          [K = $#]: $# colorings with no MAS ($#%)" % [$K, $count, $formatFloat(count / 2^len * 100, precision = 5)])
        do:
            discard


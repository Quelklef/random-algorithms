
import math
import strutils
import random
import options

import coloring

iterator skip[T](a, step: T, n: int): T =
    ## Yield a, a + T, a + 2T, etc., n times
    var x = a
    for _ in 0 ..< n:
        yield x
        x += step

proc has_MAS*[C](coloring: Coloring[C], K: int): bool =
    ## Find monochromatic arithmetic subseq of size K
    var col = coloring
    # Iterate over step sizes, which is the distance between each item in the MAS
    for stepSize in 1 .. (col.N - 1) div (K - 1):
        for startLoc in 0 .. col.N - (K - 1) * stepSize - 1:
            block skipping:
                let expectedColor = col[startLoc] # The expected color for the sequence
                for i in skip(startLoc, stepSize, K):
                    if col[i] != expectedColor:
                        break skipping # Go to next start loc
                return true
    return false

when isMainModule:
    import benchmark

    random.randomize()

    const K = 4
    const N = 35

    var flips = 0

    var col: Coloring[2] = initColoring[2](N)
    benchmark("K = $#, N = $#" % [$K, $N], trials=1):
        while true:
            randomize(col)
            flips.inc

            if not col.has_MAS(K):
                echo("Found coloring with no MAS($#)" % [$K])
                echo(col)
                echo(flips)
                break


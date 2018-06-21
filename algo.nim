
import math
import strutils
import random
import options

import coloring

proc clear*[C](col: var Coloring[C]) =
    # TODO: Should be implemented per-implementation
    for i in 0 ..< col.N:
        col[i] = 0

iterator skip[T](a, step: T, n: int): T =
    ## Yield a, a + T, a + 2T, etc., n times
    var x = a
    for _ in 0 ..< n:
        yield x
        x += step

proc mas*[C](coloring: Coloring[C], K: int): Option[Coloring[C]] =
    ## Find monochromatic arithmetic subseq of size K
    var col = coloring
    # Iterate over step sizes, which is the distance between each item in the MAS
    for stepSize in 1 .. (col.N - 1) div (K - 1):
        #echo("ss=$#" % $stepSize)
        for startLoc in 0 .. col.N - (K - 1) * stepSize - 1:
            block skipping:
                #echo("\t", startLoc, "..", startLoc + (K-1) * stepSize)
                let expectedColor = col[startLoc] # The expected color for the sequence
                for i in skip(startLoc, stepSize, K):
                    if col[i] != expectedColor:
                        break skipping # Go to next start loc

                # If all were expected color
                # Return a mask of the coloring
                var mask = initColoring[C]()
                for i in skip(startLoc, stepSize, K):
                    mask[i] = 1
                return some(mask)
    return none(Coloring[C])

when isMainModule:
    import benchmark

    random.randomize()

    const K = 4
    const N = 35

    # TODO: off-by-one error
    var flips = 0

    var col: Coloring[2] = initColoring[2](N)
    benchmark("K = $#, N = $#" % [$K, $N], trials=1):
        while true:
            randomize(col)
            flips.inc
            #echo(col)

            let mas = col.mas(K)
            if mas.isNone:
                echo("none!")
                echo(col)
                echo(flips)
                break


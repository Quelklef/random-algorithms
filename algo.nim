
import math
import strutils
import random
import options

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

proc mas*[C, S](coloring: Coloring[C, S], K: int): Option[Coloring[C, S]] =
    ## Find monochromatic arithmetic subseq of size K
    var col = coloring
    # Iterate over step sizes, which is the distance between each item in the MAS
    for stepSize in 1 .. (S - 1) div (K - 1):
        #echo("ss=$#" % $stepSize)
        for startLoc in 0 .. S - (K - 1) * stepSize - 1:
            block skipping:
                #echo("\t", startLoc, "..", startLoc + (K-1) * stepSize)
                let expectedColor = col[startLoc] # The expected color for the sequence
                for i in skip(startLoc, stepSize, K):
                    if col[i] != expectedColor:
                        break skipping # Go to next start loc

                # If all were expected color
                # Return a mask of the coloring
                var mask = initColoring[C, S]()
                for i in skip(startLoc, stepSize, K):
                    mask[i] = 1
                return some(mask)
    return none(Coloring[C, S])

# TODO: reimplement in twoColoring and nColoring .nim
proc randomize*[C, S](col: var Coloring[C, S]) =
    for i in 0 ..< S:
        col[i] = rand(C - 1)

when isMainModule:
    import benchmark

    random.randomize()

    const K = 4
    const N = 30

    var col = initColoring[2, N]()
    benchmark("K = $#, N = $#" % [$K, $N], trials=100):
        for n in 1..10^4:
            randomize(col)
            echo(col)

            let mas = col.mas(K)
            if mas.isNone:
                echo("none!")
                break


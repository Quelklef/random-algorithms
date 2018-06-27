
import math
import strutils
import sequtils
import random
import times
import options
import os

import coloring
import io
import misc

iterator skip*[T](a, step: T, n: int): T =
    ## Yield a, a + T, a + 2T, etc., n times
    var x = a
    for _ in 0 ..< n:
        yield x
        x += step

func has_MAS*[C](coloring: Coloring[C], K: int): bool =
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

func find_noMAS_coloring*(C: static[int], N, K: int): Coloring[C] =
    var col = initColoring(C, N)
    while true:
        col.randomize()
        if not col.has_MAS(K):
            return col

when isMainModule:
    import benchmark

    random.randomize()

    # We allow two optional command-line parameters.
    # The first specifies where we should start looping with K,
    # and the second where we should start looping with N.
    # '-' may instead be used to defer to the default start.
    var startK: Option[int]
    var startN: Option[int]

    if paramCount() < 1 or paramStr(1) == "-":
        startK = none(int)
    else:
        startK = some(parseInt(paramStr(1)))

    if paramCount() < 2 or paramStr(2) == "-":
        startN = none(int)
    else:
        startN = some(parseInt(paramStr(2)))

    # How many iterations until we cut it off?
    const iterThreshold = 10_000_000_000  # 10 billion
    const C = 2

    # Data is outputted as:
    # TIMESTAMP, DURATION, FLIPS, C, K, N, COLORING (nullable)
    let tabular = @[
        len($getTime().toUnix()),
        12,
        20,
        2,
        3,
        4,
        40,
    ]
    template printTitle(): untyped =
        echo tabular.rule()
        echo tabular.headers("Time", "Duration", "Flips", "C", "K", "N", "Coloring")
        echo tabular.rule()
    printTitle()
    let outFile = open("data.txt", fmAppend)

    loopfrom(K, startK.get(4)):
        loopfrom(N, startN.get(1)):
            var time: float
            var foundColoring = true
            var col: Coloring[C]
            var flips = 0
            benchmark(time):
                block success:
                    col = initColoring(C, N)

                    while flips < iterThreshold:
                        randomize(col)
                        flips.inc

                        if not col.has_MAS(K):
                            break success

                    # Passed threshhold
                    foundColoring = false

            let report = [
                $getTime().toUnix(),
                time.formatFloat(ffDecimal, precision = 5),
                $flips,
                $C,
                $K,
                $N,
                if foundColoring: $col else: "-"
            ]
            echo tabular.row(report)
            outFile.writeRow(report)

            if N mod 20 == 0:
                # Reprint title every 20 rows
                printTitle()

    close(outFile)


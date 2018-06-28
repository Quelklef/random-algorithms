
#import nimprof

import math
import strutils
import sequtils
import random
import times
import options
import os
import tables

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

proc find_noMAS_coloring*(C: static[int], N, K: int, iterThreshold: BiggestInt): tuple[flipCount: int, coloring: Option[Coloring[C]]] =
    var col = initColoring(C, N)
    var flips = 0

    while true:
        if flips > iterThreshold:
            return (flipCount: flips, coloring: none(Coloring[C]))

        col.randomize()
        inc(flips)

        if not col.has_MAS(K):
            return (flipCount: flips, coloring: some(col))

when isMainModule:
    when not defined(reckless):
        echo("INFO: Not running with -d:reckless.")
    when not defined(release):
        echo("WARNING: Not runnning with -d:release. Press enter to continue.")
        discard readLine(stdin)

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
    const iterThreshold: BiggestInt = 10_000_000_000  # 10 billion
    const C = 2

    # Keep track of known theoretical limits
    # Maps (K, C) to V(K, C)
    const knownLimits = {
        (4, 2): 35
    }.toTable

    template fft(x: float): string =
        ## One format to rule them all
        x.formatFloat(ffDecimal, precision = 10)

    let tabular = initTabular(
        ["Timestamp"             , "CPU Time"         , "Epoch Time"       , "Flips"            , "C", "K", "N", "Coloring"],
        [len($getTime().toUnix()), len(3600.fft & "s"), len(3600.fft & "s"), len($iterThreshold), 2  , 3  , 4  , 180       ],
    )

    let outFile = open("data.txt", fmAppend)

    proc report(values: varargs[string, `$`]) =
        echo tabular.row(values)
        outFile.writeRow(values)

    # TODO: Not quite desirable behavior when given starting N
    loopfrom(K, startK.get(4)):
        echo tabular.title()
        let limitN = knownLimits.getOption((K, C))
        block nextK:  # Break to here to go to next K
            loopfrom(N, startN.get(1)):

                if limitN.isSome and limitN.unsafeGet <= N:
                    report($getTime().toUnix(), "-", "-", "-", $C, $K, $N, "None, known")
                    break nextK
                else:
                    var cpuTimeElapsed: float
                    let epochT0 = epochTime()
                    var col: Option[Coloring[C]]
                    var flips = 0

                    benchmark(cpuTimeElapsed):
                        (flips, col) = find_noMAS_coloring(C, N, K, iterThreshold)

                    let epochTimeElapsed = epochTime() - epochT0

                    report(
                        $getTime().toUnix(),
                        cpuTimeElapsed.fft & "s",
                        epochTimeElapsed.fft & "s",
                        $flips,
                        $C,
                        $K,
                        $N,
                        if col.isNone: "None, threshold ($#)" % $iterThreshold else: $col.unsafeGet,
                    )

                    if col.isNone:
                        break nextK

                if N mod 60 == 0:
                    echo tabular.title()

    close(outFile)


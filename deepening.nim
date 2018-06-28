
import random
import options
import tables
import misc
import times
import strutils

import coloring
import find
import io

when not defined(reckless):
    echo("INFO: Not running with -d:reckless.")
when not defined(release):
    echo("WARNING: Not runnning with -d:release. Press enter to continue.")
    discard readLine(stdin)

import benchmark

random.randomize()

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
loopfrom(K, 4):
    echo tabular.title()
    let limitN = knownLimits.getOption((K, C))
    block nextK:  # Break to here to go to next K
        loopfrom(N, 1):

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


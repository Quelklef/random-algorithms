
import times
import os
import strutils
import stats

# Adapted from https://stackoverflow.com/questions/36577570/how-to-benchmark-few-lines-of-code-in-nim
template benchmark*(benchmarkName: string, trials: int, before, code, after: typed) =
    ## `before` and `after` run before and after each trial but are not timed
    var rs: RunningStat
    var total = 0.0

    for trial in 0 ..< trials:
        before
        let t0 = epochTime()
        code
        let elapsed = epochTime() - t0
        after

        total += elapsed
        rs.push(elapsed)

    echo("Benchmark [$1]: n = $2, mean = $3s, stdev = $4s, total = $5s" % [
        benchmarkName,
        $trials,
        $rs.mean().formatFloat(format = ffDecimal, precision = 5),
        $rs.standardDeviationS().formatFloat(format = ffDecimal, precision = 5),
        $total.formatFloat(format = ffDecimal, precision = 5),
    ])


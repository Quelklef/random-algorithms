
import times
import os
import strutils
import math

proc benchmark*[R](fun: proc(): R): (float, R) =
    let t0 = epochTime()
    let res = fun()
    let elapsed = epochTime() - t0
    return (elapsed, res)

template benchmarkTmpl*(name: string, code: untyped) =
    proc fun() =
        code

    let elapsed = benchmark(fun)
    echo("Benchmark [$#] took $#s." % [name, elapsed.formatFloat(format = ffDecimal, precision = 5)])

when isMainModule:
    echo(benchmark(proc() =
        for i in 0 ..< 10^6:
            echo(i) ))

    discard readLine(stdin)

    benchmarkTmpl("test"):
        for i in 0 ..< 10^6:
            echo(i)


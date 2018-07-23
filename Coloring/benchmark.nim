import times
import random
import coloring
import strutils

random.randomize()

# We abuse the unittest module to do benchmarks instead

template benchmark*(name, repititions, code: untyped): untyped =
  block:
    var timeSum: float64 = 0

    for _ in 1 .. repititions:
      let t0 = cpuTime()
      code
      let elapsed  = cpuTime() - t0
      timeSum += elapsed

    echo("Benchmark [$#]x$#: $#s" % [
      name,
      $repititions,
      timeSum.formatFloat(precision = 5),
    ])

benchmark("C=2 randomize", 10_000):
  let len = random.rand(10_000)
  var col = initColoring(2, len)
  col.randomize()

benchmark("C=2 equality", 10_000):
  let len = random.rand(10_000)
  var col1 = initColoring(2, len)
  var col2 = initColoring(2, len)
  col1.randomize()
  col2.randomize()
  let res = col1 == col2

import unittest
import random

import coloring
import twoColoring
import find
import ../util

# This module actually encapsulates both testing and benchmarking
# Run with -d:benchmark to benchmark instead of testing

proc genStringNum(base, length: int): string =
  ## Generate s string of given length that
  ## encodes a random number of the given base
  result = ""
  for _ in 1 .. length:
    result &= chr(rand(base - 1) + ord('0'))

template test(name: string, body: untyped): untyped =
  when not defined(benchmark):
    unittest.test name:
      body

template benchmark(name: string, body: untyped): untyped =
  when defined(benchmark):
    let t0 = epochTime()
    body
    let duration = epochTime() - t0
    echo("  Benchmark $#: $#s" % [
      name.alignLeft(45),
      duration.formatFloat(ffDecimal, precision = 10),
    ])

template testMany(name: string, body: untyped): untyped =
  test name:
    1000.times:
      body

template benchmarkMany(name: string, body: untyped): untyped =
  benchmark name:
    1000.times:
      body

template benchmarkTest(name: string, body: untyped): untyped =
  benchmark(name, body)
  test(name, body)

template benchmarkTestMany(name: string, body: untyped): untyped =
  benchmarkMany(name, body)
  testMany(name, body)

proc `!`(s: string): Coloring =
  var C = 2  # Minimum 2
  for c in s:
    C = max(ord(c) - ord('0'), C)

  result = initColoring(C, len(s))
  for i, c in s:
    result[i] = ord(c) - ord('0')

suite "Testing twoColoring":
  benchmarkTestMany "(C=2) initColoring / $":
    let s = genStringNum(2, rand(500))
    require($ !s == s)

  benchmarkTestMany "(C=2) []":
    let s = genStringNum(2, rand(500))
    let col = !s
    for i, car in s:
      require($col[i] == $car)

  benchmarkTestMany "(C=2) shiftRight":
    let s = genStringNum(2, 64 + rand(300))
    var col = !s
    let befor = ($col)[0 ..< ^1]
    col.shiftRight()
    let after = ($col)[1 ..< ^0]
    require(befor == after)

  benchmarkTestMany "(C=2) == / !=":
    let len = rand(1 .. 500)
    let s = genStringNum(2, len)
    var c0 = !s
    var c1 = !s
    require(c0 == c1)
    let pos = rand(len - 1)
    c0[pos] = if c0[pos] == 0: 1 else: 0
    require(c0 != c1)

  test "(C=2) homoegenous":
    require homogenous(!"010", !"101")
    require homogenous(!"101", !"010")
    require homogenous(!"11111", !"11111")
    require homogenous(!"00100", !"11011")
    require homogenous(!"10101010101", !"10101010101")
    require(not homogenous(!"00001111", !"01111100"))

  benchmarkMany "(C=2) homogenous":
    let size = rand(500)
    let col = !genStringNum(2, size)
    let mask = !genStringNum(2, size)
    let r = homogenous(col, mask)

  test "(C=2) hasMMP":
    require hasMMP(!"11111", !"101")
    require hasMMP(!"10101", !"101")
    require hasMMP(!"11001", !"011")
    require hasMMP(!"1", !"1")
    require hasMMP(!"01001000", !"10001")
    require(not hasMMP(!"101010101", !"11"))
    require(not hasMMP(!"1001001", !"111"))
    require(not hasMMP(!"100101", !"10001"))

  test "(C=2) hasMMP_progression":
    let patternStr = "1101"
    let pattern = proc(d: int): Coloring {.closure, gcSafe.} =
      result = initColoring(2, d * (patternStr.len - 1) + 1)
      for i, c in patternStr:
        if c == '1':
          result[i * d] = 1

    require hasMMP_progression(!"1101", pattern)
    require hasMMP_progression(!"1010001", pattern)
    require(not hasMMP_progression(!"1011", pattern))

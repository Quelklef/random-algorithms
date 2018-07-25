import unittest
import macros
import random
import times
import strutils

import coloring
import twoColoring
import find
from misc import times

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
    block:
      let t0 = epochTime()
      body
      let duration = epochTime() - t0
      echo("  Benchmark $#: $#s" % [
        name.alignLeft(25),
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

func `!`(s: string): Coloring[2] =
  initColoring(2, s)

suite "Testing twoColoring":
  setup:
    discard  # Run before each test
  teardown:
    discard  # Run after each test

  benchmarkTestMany "(C=2) initColoring / $":
    let s = genStringNum(2, rand(500))
    require($ !s == s)

  benchmarkTestMany "(C=2) []":
    let s = genStringNum(2, rand(500))
    let col = !s
    for i, car in s:
      require($col[i] == $car)

  benchmarkTestMany "(C=2) >>=":
    let shift = rand(1 .. 63)
    let s = genStringNum(2, 64 + rand(300))
    var col = !s
    let befor = ($col)[0 ..< ^shift]
    col >>= shift
    let after = ($col)[shift ..< ^0]
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
    require homogenous(!"11111", !"11111")
    require homogenous(!"00100", !"11011")
    require homogenous(!"10101010101", !"10101010101")
    require(not homogenous(!"00001111", !"01111100"))

  benchmarkMany "(C=2) homogenous":
    let size = rand(500)
    let col = !genStringNum(2, size)
    let mask = !genStringNum(2, size)
    let r = homogenous(col, mask)

  test "(C=2) has_MAS":
    require has_MAS(!"010", 2)
    require has_MAS(!"111111111111", 5)
    require has_MAS(!"0001000", 3)
    require(not has_MAS(!"00001111", 5))
    require(not has_MAS(!"0001000", 5))
    require(not has_MAS(!"0000111100001111", 5))

  benchmarkMany "(C=2) has_MAS":
    let s = genStringNum(2, rand(1 .. 500))
    let col = !s
    let r = col.has_MAS(rand(2 .. 30))

  benchmarkMany "(C=2) not":
    let r = not (!genStringNum(2, rand(500))).data
  benchmarkMany "(C=2) and":
    let size = rand(500)
    let r = (!genStringNum(2, size)).data and (!genStringNum(2, size)).data
  benchmarkMany "(C=2) or":
    let size = rand(500)
    let r = (!genStringNum(2, size)).data or (!genStringNum(2, size)).data

  discard  # Run once after each test

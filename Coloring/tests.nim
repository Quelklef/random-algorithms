
import unittest
import macros
import strutils
import streams
import times
import sets
import os
import terminal

import coloring
import twoColoring
import find


suite "Testing twoColoring":
  var emptyTwoColoring, randomTwoColoring, fromStringColoring1, fromStringColoring2, MAScoloring, noMAScoloring: TwoColoring

  setup:
  emptyTwoColoring = initTwoColoring(64)
  randomTwoColoring = initTwoColoring(64)
  randomize(randomTwoColoring)
  fromStringColoring1 = fromString("10110")
  fromStringColoring2 = fromString("10110")
  MAScoloring = fromString("10011010111010")
  noMAScoloring = fromString("0101101010011101100")
  teardown:
  echo "run after each test"

  test "TwoColoring fromString":
  check($fromStringColoring1 == "10110")

  test "TwoColoring ==":
  check(emptyTwoColoring == emptyTwoColoring)
  check(randomTwoColoring == randomTwoColoring)
  check(fromStringColoring1 == fromStringColoring2)
  #require(true)

  test "TwoColoring []":
  check(fromStringColoring1[0] == 1)
  check(fromStringColoring1[1] == 0)
  check(fromStringColoring1[2] == 1)
  check(fromStringColoring1[3] == 1)
  check(fromStringColoring1[4] == 0)

  test "has_MAS":
  check(has_MAS(cast [Coloring[2]](MAScoloring), 5))
  check(not has_MAS(cast [Coloring[2]](noMAScoloring), 5))

  echo "suite teardown: run once after the tests"
